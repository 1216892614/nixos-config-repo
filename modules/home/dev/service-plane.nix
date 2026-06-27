{ config, lib, pkgs, ... }:

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  Service Plane — Docker Compose + Traefik + scale-to-zero               ║
# ╠══════════════════════════════════════════════════════════════════════════╣
# ║  Architecture:                                                          ║
# ║    Traefik (always-on)     → HTTP routing + dashboard + Sablier plugin  ║
# ║    Sablier (always-on)     → HTTP scale-to-zero lifecycle manager       ║
# ║    tcp-gate (always-on)    → TCP on-demand wake + transparent proxy     ║
# ║    dragonfly (TCP s2z)     → sccache Redis backend                      ║
# ║    filebrowser (HTTP s2z)  → web file browser                           ║
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

  # ── Service registry: hostnames + backends ──────────────────────────────
  # Central definition used by Traefik routing, Unbound zone, and /etc/hosts.
  httpServices = {
    files  = { backend = "http://service-plane-filebrowser:80"; scaleToZero = true; };
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
        ${lib.concatStringsSep "\n    " (lib.mapAttrsToList (name: svc: ''
        activity_file="$ACTIVITY_DIR/${name}"
        if [ -f "$activity_file" ]; then
          last=$(stat -c %Y "$activity_file" 2>/dev/null || echo 0)
          now=$(date +%s)
          elapsed=$((now - last))
          if [ "$elapsed" -ge ${toString svc.idleTimeout} ]; then
            state=$(docker inspect --format='{{.State.Running}}' "service-plane-${name}-1" 2>/dev/null || echo "false")
            if [ "$state" = "true" ]; then
              log "${name}: idle ''${elapsed}s (>=${toString svc.idleTimeout}s), stopping"
              docker stop "service-plane-${name}-1" >/dev/null 2>&1 || true
            fi
          fi
        fi
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
        filebrowser = {
          rule = "Host(`files.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "filebrowser-sablier" ];
          service = "filebrowser";
          tls = {};
        };
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
      };
      services = {
        filebrowser.loadBalancer.servers = [
          { url = "http://service-plane-filebrowser:80"; }
        ];
        pi-agent.loadBalancer.servers = [
          { url = "http://host.docker.internal:${toString piAgentPort}"; }
        ];
      };
      middlewares.filebrowser-sablier.plugin.sablier = {
        sablierUrl = "http://service-plane-sablier:10000";
        names = "service-plane-filebrowser";
        sessionDuration = "10m";
        dynamic = {
          displayName = "FileBrowser";
          theme = "hacker-terminal";
          refreshFrequency = "5s";
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
      local-data: "plane.${localDomain}. IN A 127.0.0.1"
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

      # ── Always-on: Unbound (authoritative .local DNS) ───────────────────
      unbound = {
        image = "mvance/unbound:latest";
        container_name = "service-plane-unbound";
        restart = "unless-stopped";
        network_mode = "host";
        volumes = [
          "${planeDir}/unbound:/opt/unbound/etc/unbound:ro"
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
          "/var/run/docker.sock:/var/run/docker.sock"
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

in
{
  # ── Generated config files ──────────────────────────────────────────────
  xdg.configFile."service-plane/docker-compose.yml".source = composeContent;
  xdg.configFile."service-plane/scripts/tcp-gate.sh".source = gateScript;
  xdg.configFile."service-plane/scripts/pi-agent-entrypoint.sh".source = piAgentEntrypoint;
  xdg.configFile."service-plane/traefik/traefik.yml".source = traefikStaticYml;
  xdg.configFile."service-plane/traefik/dynamic.yml".source = traefikDynamicYml;
  xdg.configFile."service-plane/unbound/unbound.conf".source = unboundConf;

  # ── Data directories ─────────────────────────────────────────────────────
  home.activation.servicePlaneDataDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _:
      ''mkdir -p "${dataDir}/${name}"''
    ) tcpServices)}
    mkdir -p "${dataDir}/filebrowser/database"
    mkdir -p "${dataDir}/filebrowser/config"
    mkdir -p "${dataDir}/rustdesk"
  '';

  # ── systemd user service ─────────────────────────────────────────────────
  systemd.user.services.service-plane = {
    Unit = {
      Description = "Service Plane (Traefik + Sablier + TCP Gate + containers)";
      After = [ "docker.service" ];
      Requires = [ "docker.service" ];
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
