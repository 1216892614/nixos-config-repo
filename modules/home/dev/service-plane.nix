{ config, lib, pkgs, ... }:

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Service Plane — Docker Compose + Traefik + scale-to-zero               ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║  Architecture:                                                          ║
# ║    Traefik (always-on)     → HTTP routing + dashboard + Sablier plugin  ║
# ║    Sablier (always-on)     → HTTP scale-to-zero lifecycle manager       ║
# ║    portal (always-on)      → 系统主页 + 错误页 + 等待页 (nginx)        ║
# ║    tcp-gate (always-on)    → TCP on-demand wake + transparent proxy     ║
# ║    dragonfly (TCP s2z)     → sccache Redis backend                      ║
# ║    filebrowser (HTTP s2z)  → web file browser                           ║
# ║    comfyui (HTTP s2z)      → ComfyUI image gen (GPU, comfy-cli)         ║
# ║    comfyui-keepalive (on)  → queue monitor → Sablier session refresh    ║
# ║    rustdesk-hbbs (always)  → RustDesk signal server (host network)      ║
# ║    rustdesk-hbbr (always)  → RustDesk relay server (host network)       ║
# ║    pi-agent (always)       → AI assistant agent (host network)          ║
# ║                                                                         ║
# ║  Adding services:                                                       ║
# ║    TCP scale-to-zero → add to `tcpServices` attrset                     ║
# ║    HTTP scale-to-zero → add compose service + Sablier middleware        ║
# ║    Always-on → add compose service directly                             ║
# ╚══════════════════════════════════════════════════════════════════════════╝

let
  envPath =
    if builtins.pathExists ../../../env.nix then
      ../../../env.nix
    else
      ../../../env.nix.example;
  env = import envPath;

  planeDir = "${config.home.homeDirectory}/.config/service-plane";
  dataDir = "${config.home.homeDirectory}/.local/share/service-plane";
  username = env.username or "ep-o1";

  # ── Ports from env ──────────────────────────────────────────────────────
  fileBrowserPort = env.fileBrowserPort or 8080;
  piAgentPort = env.piAgentPort or 3001;
  rustdeskRelayPort = env.rustdeskRelayPort or 21117;
  searxngPort = env.searxngPort or 18980;

  # ── Service registry: hostnames + backends ──────────────────────────────
  # Central definition used by Traefik routing, Unbound zone, and /etc/hosts.
  httpServices = {
    plane  = { backend = "http://service-plane-portal:80"; scaleToZero = false; };
    files  = { backend = "http://service-plane-filebrowser:80"; scaleToZero = true; };
    comfyui = { backend = "http://service-plane-comfyui:8188"; scaleToZero = true; };
    agent  = { backend = "http://host.docker.internal:${toString piAgentPort}"; scaleToZero = false; };
    traefik = { backend = "http://127.0.0.1:8080"; scaleToZero = false; };  # Traefik API (internal)
  };

  localDomain = "local";  # *.local

  # ── TCP services (scale-to-zero via tcp-gate) ───────────────────────────
  tcpServices = {
    dragonfly = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:latest";
      hostPort = 6399;
      containerPort = 6379;
      volumes = [ "${dataDir}/dragonfly:/data" ];
      command = [ "--maxmemory" "2G" "--dbfilename" "dump.rdb" "--save_schedule" "*:*" ];
      healthCheck = "redis-cli -h dragonfly -p 6379 ping";
      idleTimeout = 600;
    };
    searxng = {
      image = "searxng/searxng:latest";
      hostPort = searxngPort;
      containerPort = 8080;
      volumes = [ "${planeDir}/searxng/settings.yml:/etc/searxng/settings.yml:ro" ];
      command = [ ];
      healthCheck = "wget -q --spider http://searxng:8080";
      idleTimeout = 300;
      # 只要主机上有 omp 进程就保持 searxng 存活（检查 /proc/*/exe → omp）
      keepAliveCheck = "ls -l /host-proc/[0-9]*/exe 2>/dev/null | grep -q '/omp'";
    };
  };

  # ── tcp-gate.sh: socat listeners + idle reaper ──────────────────────────
  gateScript = pkgs.writeText "tcp-gate.sh" ''
    #!/bin/sh
    set -eu

    ACTIVITY_DIR="/tmp/gate-activity"
    mkdir -p "$ACTIVITY_DIR"

    log() { echo "[tcp-gate] $(date '+%H:%M:%S') $*"; }

    idle_reaper() {
      while true; do
        sleep 30
        ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (name: svc:
          let
            hasKeepAlive = svc ? keepAliveCheck;
            stopBlock = ''
              last=$(stat -c %Y "$activity_file" 2>/dev/null || echo 0)
              now=$(date +%s)
              elapsed=$((now - last))
              if [ "$elapsed" -ge ${toString svc.idleTimeout} ]; then
                if [ "$state" = "true" ]; then
                  log "${name}: idle ''${elapsed}s (>=${toString svc.idleTimeout}s), stopping"
                  docker stop "service-plane-${name}-1" >/dev/null 2>&1 || true
                fi
              fi'';
          in ''
        activity_file="$ACTIVITY_DIR/${name}"
        state=$(docker inspect --format='{{.State.Running}}' "service-plane-${name}-1" 2>/dev/null || echo "false")
        ${if hasKeepAlive then ''
        if ${svc.keepAliveCheck}; then
          # omp 活跃 → 保持服务存活
          touch "$activity_file"
          if [ "$state" != "true" ]; then
            log "${name}: omp active, waking..."
            docker start "service-plane-${name}-1" >/dev/null 2>&1 || true
          fi
        elif [ -f "$activity_file" ]; then
          ${stopBlock}
        fi'' else ''
        if [ -f "$activity_file" ]; then
          ${stopBlock}
        fi''}
        '') tcpServices)}
      done
    }
    idle_reaper &
    REAPER_PID=$!
    trap "kill $REAPER_PID 2>/dev/null; wait" EXIT

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: svc: ''
    cat > /tmp/handle-${name}.sh << 'HANDLER'
    #!/bin/sh
    ACTIVITY_DIR="/tmp/gate-activity"
    touch "$ACTIVITY_DIR/${name}"
    state=$(docker inspect --format='{{.State.Running}}' "service-plane-${name}-1" 2>/dev/null || echo "false")
    if [ "$state" != "true" ]; then
      echo "[tcp-gate] ${name}: waking..." >&2
      docker start "service-plane-${name}-1" >/dev/null 2>&1 || true
      i=0; while [ $i -lt 60 ]; do
        if ${svc.healthCheck} >/dev/null 2>&1; then break; fi
        sleep 0.5; i=$((i+1))
      done
      if [ $i -ge 60 ]; then
        echo "[tcp-gate] ${name}: health check timed out" >&2
        exit 1
      fi
      echo "[tcp-gate] ${name}: ready (''${i}x0.5s)" >&2
    fi
    touch "$ACTIVITY_DIR/${name}"
    exec socat - "TCP:${name}:${toString svc.containerPort}"
    HANDLER
    chmod +x /tmp/handle-${name}.sh
    '') tcpServices)}

    log "Starting TCP listeners..."
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: svc: ''
    socat "TCP-LISTEN:${toString svc.containerPort},reuseaddr,fork" "EXEC:/tmp/handle-${name}.sh" &
    log "${name}: listening on :${toString svc.containerPort}"
    '') tcpServices)}

    log "All listeners active."
    wait
  '';

  # ── Traefik static config ───────────────────────────────────────────────
  traefikStaticYml = pkgs.writeText "traefik.yml" (builtins.toJSON {
    api = { insecure = true; dashboard = true; };
    log.level = "WARN";
    entryPoints = {
      web = {
        address = ":80";
        http.redirections.entryPoint = {
          to = "websecure";
          scheme = "https";
          permanent = true;
        };
      };
      websecure = { address = ":443"; };
    };
    providers = {
      docker = {
        endpoint = "unix:///var/run/docker.sock";
        exposedByDefault = false;
        network = "service-plane_default";
      };
      file = { filename = "/etc/traefik/dynamic.yml"; watch = true; };
    };
    experimental.plugins.sablier = {
      moduleName = "github.com/sablierapp/sablier-traefik-plugin";
      version = "v1.3.0";
    };
  });

  # ── Traefik dynamic config (Host-based routing) ─────────────────────────
  # Each service gets a hostname: files.local, agent.local, traefik.local
  # All routers use TLS with the local CA wildcard cert.
  # FileBrowser uses Sablier for scale-to-zero; others route directly.
  traefikDynamicYml = pkgs.writeText "traefik-dynamic.yml" (builtins.toJSON {
    tls = {
      certificates = [
        { certFile = "/certs/server.crt"; keyFile = "/certs/server.key"; }
      ];
      stores.default.defaultCertificate = {
        certFile = "/certs/server.crt";
        keyFile = "/certs/server.key";
      };
    };
    http = {
      routers = {
        # ── Portal (主页仪表板) ──────────────────────────────────────────
        portal = {
          rule = "Host(`plane.${localDomain}`)";
          entryPoints = [ "websecure" ];
          service = "portal";
          tls = {};
          priority = 10;
        };
        # ── Scale-to-zero services ──────────────────────────────────────
        filebrowser = {
          rule = "Host(`files.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "filebrowser-sablier" ];
          service = "filebrowser";
          tls = {};
        };
        comfyui = {
          rule = "Host(`comfyui.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "comfyui-sablier" ];
          service = "comfyui";
          tls = {};
        };
        # ── Always-on services ──────────────────────────────────────────
        pi-agent = {
          rule = "Host(`agent.${localDomain}`)";
          entryPoints = [ "websecure" ];
          service = "pi-agent";
          tls = {};
        };
        dashboard = {
          rule = "Host(`traefik.${localDomain}`)";
          entryPoints = [ "websecure" ];
          service = "api@internal";
          tls = {};
        };
        # ── Catch-all: 未注册的 *.local → portal 404 ────────────────────
        catchall = {
          rule = "HostRegexp(`.+\\.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "portal-errors" ];
          service = "portal";
          tls = {};
          priority = 1;
        };
      };
      services = {
        portal.loadBalancer.servers = [
          { url = "http://service-plane-portal:80"; }
        ];
        filebrowser.loadBalancer.servers = [
          { url = "http://service-plane-filebrowser:80"; }
        ];
        comfyui.loadBalancer.servers = [
          { url = "http://service-plane-comfyui:8188"; }
        ];
        pi-agent.loadBalancer.servers = [
          { url = "http://host.docker.internal:${toString piAgentPort}"; }
        ];
      };
      middlewares = {
        # ── Sablier: FileBrowser 自动唤醒 + 自定义等待页 ────────────────
        filebrowser-sablier.plugin.sablier = {
          sablierUrl = "http://service-plane-sablier:10000";
          names = "service-plane-filebrowser";
          sessionDuration = "10m";
          dynamic = {
            displayName = "FileBrowser";
            customThemesPath = "/portal/waiting.html";
            refreshFrequency = "5s";
          };
        };
        # ── Sablier: ComfyUI 自动唤醒 + 自定义等待页 ───────────────────
        comfyui-sablier.plugin.sablier = {
          sablierUrl = "http://service-plane-sablier:10000";
          names = "service-plane-comfyui";
          sessionDuration = "30m";
          dynamic = {
            displayName = "ComfyUI";
            customThemesPath = "/portal/waiting.html";
            refreshFrequency = "5s";
          };
        };
        # ── 错误页中间件: 后端异常时由 portal 返回错误页 ────────────────
        portal-errors.errors = {
          status = [ "404-499" "500-599" ];
          service = "portal";
          query = "/{status}.html";
        };
      };
    };
  });

  # ── Pi Agent entrypoint ─────────────────────────────────────────────────
  piAgentEntrypoint = pkgs.writeText "pi-agent-entrypoint.sh" ''
    #!/bin/sh
    set -eu
    export PATH="/nix-system/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    export HOME="/home/${username}"
    cd "$HOME"
    exec /nix-system/bin/opencode serve --hostname 0.0.0.0 --port 3000
  '';

  # ── ComfyUI entrypoint (comfy-cli based) ──────────────────────────────
  comfyuiEntrypoint = pkgs.writeText "comfyui-entrypoint.sh" ''
    #!/bin/bash
    set -eu
    export HOME="/home/user"
    export PATH="$HOME/.local/bin:$PATH"

    # 首次启动：安装 comfy-cli + ComfyUI
    if [ ! -f "$HOME/comfy/.installed" ]; then
      echo "[comfyui] 首次启动，安装 comfy-cli..."
      pip install --user comfy-cli
      echo "[comfyui] 通过 comfy-cli 安装 ComfyUI..."
      comfy --workspace="$HOME/comfy" install --nvidia --skip-manager
      touch "$HOME/comfy/.installed"
    fi

    echo "[comfyui] 启动 ComfyUI..."
    exec comfy --workspace="$HOME/comfy" launch -- --listen 0.0.0.0 --port 8188
  '';

  # ── ComfyUI keepalive: 队列有任务时刷新 Sablier session ─────────────────
  comfyuiKeepalive = pkgs.writeText "comfyui-keepalive.sh" ''
    #!/bin/sh
    set -eu
    COMFYUI_URL="http://service-plane-comfyui:8188"
    SABLIER_URL="http://service-plane-sablier:10000"
    SESSION_DURATION="30m"
    CHECK_INTERVAL=15

    log() { echo "[keepalive] $(date '+%H:%M:%S') $*"; }

    while true; do
      sleep "$CHECK_INTERVAL"

      # 容器未运行时跳过
      if ! curl -sf "$COMFYUI_URL/api/prompt" >/dev/null 2>&1; then
        continue
      fi

      # 检查队列：queue_running 或 queue_pending 非空 = 有活跃任务
      queue=$(curl -sf "$COMFYUI_URL/api/prompt" 2>/dev/null || echo '{}')
      running=$(echo "$queue" | grep -o '"queue_running":\[[^]]*\]' | grep -c '"' || true)
      pending=$(echo "$queue" | grep -o '"queue_pending":\[[^]]*\]' | grep -c '"' || true)

      if [ "$running" -gt 2 ] || [ "$pending" -gt 2 ]; then
        log "队列活跃 (running=$running, pending=$pending)，刷新 session"
        curl -sf -X PUT \
          "$SABLIER_URL/api/sessions/comfyui" \
          -H "Content-Type: application/json" \
          -d "{\"duration\":\"$SESSION_DURATION\"}" \
          >/dev/null 2>&1 || true
      fi
    done
  '';

  # ── Unbound config: authoritative .local zone ───────────────────────────
  # Resolves *.local → 127.0.0.1 for LAN clients querying this DNS.
  # Host itself uses /etc/hosts (local-dns.nix) which is more reliable with
  # Clash TUN, but containers and LAN devices can query Unbound on :5353.
  unboundConf = pkgs.writeText "unbound.conf" ''
    server:
      interface: 0.0.0.0@5353
      access-control: 127.0.0.0/8 allow
      access-control: 172.16.0.0/12 allow
      access-control: 192.168.0.0/16 allow
      access-control: 10.0.0.0/8 allow
      do-not-query-localhost: no
      local-zone: "${localDomain}." static
      ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: _:
        ''local-data: "${name}.${localDomain}. IN A 127.0.0.1"''
      ) httpServices)}
  '';

  # ── docker-compose.yml ──────────────────────────────────────────────────
  composeContent = pkgs.writeText "docker-compose.yml" (builtins.toJSON {
    services = {
      # ── Always-on: Traefik ───────────────────────────────────────────────
      traefik = {
        image = "traefik:v3.6";
        container_name = "service-plane-traefik";
        restart = "unless-stopped";
        ports = [
          "127.0.0.1:80:80"      # HTTP → redirect to HTTPS
          "127.0.0.1:443:443"    # HTTPS entrypoint (*.local)
          "127.0.0.1:8070:8080"  # dashboard API (insecure, internal only)
        ];
        extra_hosts = [ "host.docker.internal:host-gateway" ];
        volumes = [
          "${planeDir}/traefik/traefik.yml:/etc/traefik/traefik.yml:ro"
          "${planeDir}/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro"
          "${planeDir}/portal/waiting.html:/portal/waiting.html:ro"
          "/etc/service-plane/server.crt:/certs/server.crt:ro"
          "/etc/service-plane/server.key:/certs/server.key:ro"
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ];
      };

      # ── Always-on: Sablier ──────────────────────────────────────────────
      sablier = {
        image = "acouvreur/sablier:1.8.0";
        container_name = "service-plane-sablier";
        restart = "unless-stopped";
        command = [ "start" "--provider.name=docker" ];
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      };

      # ── Always-on: Portal (系统主页 + 错误页 + 等待页) ──────────────────
      portal = {
        image = "nginx:alpine";
        container_name = "service-plane-portal";
        restart = "unless-stopped";
        volumes = [
          "${planeDir}/portal:/usr/share/nginx/html:ro"
          "${planeDir}/portal/nginx.conf:/etc/nginx/conf.d/default.conf:ro"
          "/nix/store:/nix/store:ro"
        ];
      };

      # ── Always-on: Unbound (authoritative .local DNS) ───────────────────
      unbound = {
        image = "mvance/unbound:latest";
        container_name = "service-plane-unbound";
        restart = "unless-stopped";
        network_mode = "host";
        volumes = [
          "${planeDir}/unbound:/opt/unbound/etc/unbound:ro"
          "/nix/store:/nix/store:ro"
        ];
      };

      # ── Always-on: TCP Gate ─────────────────────────────────────────────
      tcp-gate = {
        image = "docker:27-cli";
        container_name = "service-plane-tcp-gate";
        restart = "unless-stopped";
        entrypoint = "sh";
        command = [ "-c" "apk add --no-cache socat >/dev/null 2>&1 && exec sh /scripts/tcp-gate.sh" ];
        ports = lib.mapAttrsToList (_: svc:
          "127.0.0.1:${toString svc.hostPort}:${toString svc.containerPort}"
        ) tcpServices;
        volumes = [
          "${planeDir}/scripts:/scripts:ro"
          "/nix/store:/nix/store:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/proc:/host-proc:ro"
        ];
        depends_on = lib.mapAttrs' (name: _:
          lib.nameValuePair name { condition = "service_started"; }
        ) tcpServices;
      };

      # ── Scale-to-zero (HTTP): FileBrowser ────────────────────────────────
      filebrowser = {
        image = "filebrowser/filebrowser:latest";
        container_name = "service-plane-filebrowser";
        restart = "no";
        volumes = [
          "/home/${username}:/srv:ro"
          "${dataDir}/filebrowser/database:/database"
          "${dataDir}/filebrowser/config:/config"
        ];
        labels = {
          "sablier.enable" = "true";
          "sablier.group" = "filebrowser";
        };
      };

      # ── Scale-to-zero (HTTP): ComfyUI (GPU, Sablier + queue keepalive) ──
      comfyui = {
        image = "nvidia/cuda:12.8.1-runtime-ubuntu24.04";
        container_name = "service-plane-comfyui";
        restart = "no";
        entrypoint = [ "bash" "/scripts/comfyui-entrypoint.sh" ];
        volumes = [
          "${dataDir}/comfyui:/home/user/comfy"
          "${planeDir}/scripts/comfyui-entrypoint.sh:/scripts/comfyui-entrypoint.sh:ro"
        ];
        environment = {
          NVIDIA_VISIBLE_DEVICES = "all";
        };
        deploy.resources.reservations.devices = [
          { driver = "nvidia"; count = "all"; capabilities = [ "gpu" ]; }
        ];
        labels = {
          "sablier.enable" = "true";
          "sablier.group" = "comfyui";
        };
      };

      # ── Always-on: ComfyUI keepalive (queue monitor → Sablier refresh) ──
      comfyui-keepalive = {
        image = "docker:27-cli";
        container_name = "service-plane-comfyui-keepalive";
        restart = "unless-stopped";
        entrypoint = "sh";
        command = [ "-c" "apk add --no-cache curl >/dev/null 2>&1 && exec sh /scripts/comfyui-keepalive.sh" ];
        volumes = [
          "${planeDir}/scripts/comfyui-keepalive.sh:/scripts/comfyui-keepalive.sh:ro"
        ];
      };

      # ── Always-on: RustDesk hbbs (host network for UDP NAT) ─────────────
      rustdesk-hbbs = {
        image = "rustdesk/rustdesk-server:latest";
        container_name = "service-plane-rustdesk-hbbs";
        restart = "unless-stopped";
        network_mode = "host";
        command = [ "hbbs" "-r" "127.0.0.1:${toString rustdeskRelayPort}" ];
        volumes = [ "${dataDir}/rustdesk:/root" ];
        depends_on = [ "rustdesk-hbbr" ];
      };

      # ── Always-on: RustDesk hbbr (host network) ─────────────────────────
      rustdesk-hbbr = {
        image = "rustdesk/rustdesk-server:latest";
        container_name = "service-plane-rustdesk-hbbr";
        restart = "unless-stopped";
        network_mode = "host";
        command = [ "hbbr" ];
        volumes = [ "${dataDir}/rustdesk:/root" ];
      };

      # ── Always-on: Pi Agent (host network for full access) ──────────────
      pi-agent = {
        image = "debian:bookworm-slim";
        container_name = "service-plane-pi-agent";
        restart = "unless-stopped";
        network_mode = "host";
        entrypoint = [ "sh" "/entrypoint/pi-agent-entrypoint.sh" ];
        volumes = [
          "/nix/store:/nix/store:ro"
          "/run/current-system/sw:/nix-system:ro"
          "/home/${username}:/home/${username}"
          "/var/run/docker.sock:/var/run/docker.sock"
          "${planeDir}/scripts/pi-agent-entrypoint.sh:/entrypoint/pi-agent-entrypoint.sh:ro"
        ];
        environment = {
          HOME = "/home/${username}";
          USER = username;
          TERM = "xterm-256color";
        };
      };
    }
    # ── Scale-to-zero (TCP): backend containers ────────────────────────────
    // (lib.mapAttrs (name: svc: {
      image = svc.image;
      container_name = "service-plane-${name}-1";
      restart = "no";
      command = svc.command;
      volumes = svc.volumes;
      labels = {
        "service-plane.managed" = "true";
        "service-plane.idle-timeout" = toString svc.idleTimeout;
      };
    }) tcpServices);
  });

  # ── SearXNG settings (disable limiter for local API access) ─────────────
  searxngSettings = pkgs.writeText "searxng-settings.yml" ''
    use_default_settings: true
    server:
      secret_key: "sp-searxng-local-only"
      image_proxy: true
      limiter: false
    search:
      formats:
        - html
        - json
  '';

in
{
  # ── Generated config files ──────────────────────────────────────────────
  xdg.configFile."service-plane/docker-compose.yml".source = composeContent;
  xdg.configFile."service-plane/scripts/tcp-gate.sh".source = gateScript;
  xdg.configFile."service-plane/scripts/pi-agent-entrypoint.sh".source = piAgentEntrypoint;
  xdg.configFile."service-plane/scripts/comfyui-entrypoint.sh".source = comfyuiEntrypoint;
  xdg.configFile."service-plane/scripts/comfyui-keepalive.sh".source = comfyuiKeepalive;
  xdg.configFile."service-plane/traefik/traefik.yml".source = traefikStaticYml;
  xdg.configFile."service-plane/traefik/dynamic.yml".source = traefikDynamicYml;
  xdg.configFile."service-plane/unbound/unbound.conf".source = unboundConf;
  xdg.configFile."service-plane/searxng/settings.yml".source = searxngSettings;
  xdg.configFile."service-plane/portal/index.html".source = ./portal/index.html;
  xdg.configFile."service-plane/portal/404.html".source = ./portal/404.html;
  xdg.configFile."service-plane/portal/error.html".source = ./portal/error.html;
  xdg.configFile."service-plane/portal/waiting.html".source = ./portal/waiting.html;
  xdg.configFile."service-plane/portal/nginx.conf".source = ./portal/nginx.conf;

  # ── Data directories ─────────────────────────────────────────────────────
  home.activation.servicePlaneDataDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _:
      ''mkdir -p "${dataDir}/${name}"''
    ) tcpServices)}
    mkdir -p "${dataDir}/filebrowser/database"
    mkdir -p "${dataDir}/filebrowser/config"
    mkdir -p "${dataDir}/rustdesk"
    mkdir -p "${dataDir}/comfyui"
  '';

  # ── systemd user service ─────────────────────────────────────────────────
  systemd.user.services.service-plane = {
    Unit = {
      Description = "Service Plane (Traefik + Sablier + TCP Gate + containers)";
      # docker.service 是系统级 unit，用户级无法 Requires。
      # 改用 ConditionPathExists 确保 docker socket 存在后再启动。
      After = [ "default.target" ];
      ConditionPathExists = "/var/run/docker.sock";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = planeDir;
      ExecStart = pkgs.writeShellScript "service-plane-up" ''
        set -euo pipefail
        cd "${planeDir}"
        ${pkgs.docker}/bin/docker compose pull --quiet 2>/dev/null || true
        ${pkgs.docker}/bin/docker compose up -d --remove-orphans
        # Stop scale-to-zero backends (created but should idle)
        ${pkgs.docker}/bin/docker stop service-plane-filebrowser 2>/dev/null || true
        ${pkgs.docker}/bin/docker stop service-plane-comfyui 2>/dev/null || true
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
          ${pkgs.docker}/bin/docker stop "service-plane-${name}-1" 2>/dev/null || true
        '') tcpServices)}
      '';
      ExecStop = pkgs.writeShellScript "service-plane-down" ''
        cd "${planeDir}"
        ${pkgs.docker}/bin/docker compose down --timeout 10
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── sccache → Dragonfly via service plane ────────────────────────────────
  home.sessionVariables = {
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
    CMAKE_C_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
    CMAKE_CXX_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
    SCCACHE_REDIS = "redis://127.0.0.1:${toString tcpServices.dragonfly.hostPort}";
    SCCACHE_CACHE_SIZE = "10G";
    SCCACHE_IDLE_TIMEOUT = "0";
  };
}
