{ config, lib, pkgs, env, ... }:

let
  tpl = import ../../../../lib/template.nix;
  keepSearxngAliveWhileOmpRuns = "ls -l /host-proc/[0-9]*/exe 2>/dev/null | grep -q '/omp'";
  dockerSocketConditionForUserUnit = "/var/run/docker.sock";

  planeDir = "${config.home.homeDirectory}/.config/service-plane";
  dataDir = "${config.home.homeDirectory}/.local/share/service-plane";
  username = env.username or "ep-o1";
  rustdeskRelayPort = env.rustdeskRelayPort or 21117;
  searxngPort = env.searxngPort or 18980;
  httpServices = {
    plane  = { backend = "http://service-plane-portal:80"; scaleToZero = false; };
    comfyui = { backend = "http://service-plane-comfyui:8188"; scaleToZero = true; };
    llm    = { backend = "http://service-plane-llm:8080"; scaleToZero = true; };
    traefik = { backend = "http://127.0.0.1:8080"; scaleToZero = false; };  # Traefik API (internal)
  };

  localDomain = "local";  # *.local
  tcpServices = {
    dragonfly = {
      image = "docker.dragonflydb.io/dragonflydb/dragonfly:latest";
      hostPort = 6399;
      containerPort = 6379;
      volumes = [ "${dataDir}/dragonfly:/data" ];
      command = [ "--maxmemory" "2G" "--dbfilename" "dump" "--snapshot_cron" "* * * * *" "--proactor_threads" "4" "--force_epoll" ];
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
      keepAliveCheck = keepSearxngAliveWhileOmpRuns;
    };
  };
  gateScript = pkgs.writeText "tcp-gate.sh" (tpl ./tcp-gate.sh {
    idleServices = lib.concatStringsSep "\n    " (lib.mapAttrsToList (name: svc:
      let
        stopBlock = tpl ./tcp-idle-stop.sh {
          inherit name;
          idleTimeout = toString svc.idleTimeout;
        };
        activityCheck = if svc ? keepAliveCheck then tpl ./tcp-keepalive.sh {
          inherit name stopBlock;
          keepAliveCheck = svc.keepAliveCheck;
        } else ''
          if [ -f "$activity_file" ]; then
            ${stopBlock}
          fi'';
      in tpl ./tcp-idle-service.sh { inherit name activityCheck; }
    ) tcpServices);
    handlers = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: svc:
      tpl ./tcp-handler.sh {
        inherit name;
        healthCheck = svc.healthCheck;
        containerPort = toString svc.containerPort;
      }
    ) tcpServices);
    listeners = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: svc: ''
      socat "TCP-LISTEN:${toString svc.containerPort},reuseaddr,fork" "EXEC:/tmp/handle-${name}.sh" &
      log "${name}: listening on :${toString svc.containerPort}"
    '') tcpServices);
  });
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
        portal = {
          rule = "Host(`plane.${localDomain}`)";
          entryPoints = [ "websecure" ];
          service = "portal";
          tls = {};
          priority = 10;
        };
        comfyui = {
          rule = "Host(`comfyui.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "comfyui-sablier" ];
          service = "comfyui";
          tls = {};
        };
        llm = {
          rule = "Host(`llm.${localDomain}`)";
          entryPoints = [ "websecure" ];
          middlewares = [ "llm-sablier" ];
          service = "llm";
          tls = {};
        };
        dashboard = {
          rule = "Host(`traefik.${localDomain}`)";
          entryPoints = [ "websecure" ];
          service = "api@internal";
          tls = {};
        };
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
        comfyui.loadBalancer.servers = [
          { url = "http://service-plane-comfyui:8188"; }
        ];
        llm.loadBalancer.servers = [
          { url = "http://service-plane-llm:8080"; }
        ];
      };
      middlewares = {
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
        llm-sablier.plugin.sablier = {
          sablierUrl = "http://service-plane-sablier:10000";
          names = "service-plane-llm";
          sessionDuration = "5m";
          dynamic = {
            displayName = "LLM (Qwen3 4B)";
            customThemesPath = "/portal/waiting.html";
            refreshFrequency = "2s";
          };
        };
        portal-errors.errors = {
          status = [ "404-499" "500-599" ];
          service = "portal";
          query = "/{status}.html";
        };
      };
    };
  });

  comfyuiEntrypoint = pkgs.writeText "comfyui-entrypoint.sh" (builtins.readFile ./comfyui-entrypoint.sh);
  comfyuiKeepalive = pkgs.writeText "comfyui-keepalive.sh" (builtins.readFile ./comfyui-keepalive.sh);
  unboundConf = pkgs.writeText "unbound.conf" (tpl ./unbound.conf {
    inherit localDomain;
    localRecords = lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: _:
      ''local-data: "${name}.${localDomain}. IN A 127.0.0.1"''
    ) httpServices);
  });
  composeContent = pkgs.writeText "docker-compose.yml" (builtins.toJSON {
    services = {
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
      sablier = {
        image = "acouvreur/sablier:1.8.0";
        container_name = "service-plane-sablier";
        restart = "unless-stopped";
        command = [ "start" "--provider.name=docker" ];
        volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
      };
      portal = {
        image = "nginx:alpine";
        container_name = "service-plane-portal";
        restart = "unless-stopped";
        entrypoint = [ "sh" "-c" "rm -f /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'" ];
        volumes = [
          "${planeDir}/portal:/usr/share/nginx/html:ro"
          "${planeDir}/portal/nginx.conf:/etc/nginx/nginx.conf:ro"
          "/var/run/docker.sock:/var/run/docker.sock"
          "/nix/store:/nix/store:ro"
        ];
      };
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
      };
      comfyui = {
        image = "pytorch/pytorch:2.11.0-cuda12.8-cudnn9-runtime";
        container_name = "service-plane-comfyui";
        restart = "no";
        entrypoint = [ "bash" "/scripts/comfyui-entrypoint.sh" ];
        ports = [ "127.0.0.1:8188:8188" ];
        volumes = [
          "${dataDir}/comfyui:/home/user/comfy"
          "${planeDir}/scripts/comfyui-entrypoint.sh:/scripts/comfyui-entrypoint.sh:ro"
        ];
        environment = {
          NVIDIA_VISIBLE_DEVICES = "all";
        };
        devices = [ "nvidia.com/gpu=all" ];
        labels = {
          "sablier.enable" = "true";
          "sablier.group" = "comfyui";
        };
      };
      llm = {
        image = "ghcr.io/ggml-org/llama.cpp:server-cuda";
        container_name = "service-plane-llm";
        restart = "no";
        volumes = [
          "${dataDir}/llm/models:/models:ro"
        ];
        command = [
          "--model" "/models/qwen3-4b-q4_k_m.gguf"
          "--port" "8080"
          "--host" "0.0.0.0"
          "--ctx-size" "2048"
          "--n-gpu-layers" "99"
          "--flash-attn"
        ];
        devices = [ "nvidia.com/gpu=all" ];
        labels = {
          "sablier.enable" = "true";
          "sablier.group" = "llm";
        };
      };
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
      rustdesk-hbbs = {
        image = "rustdesk/rustdesk-server:latest";
        container_name = "service-plane-rustdesk-hbbs";
        restart = "unless-stopped";
        network_mode = "host";
        command = [ "hbbs" "-r" "127.0.0.1:${toString rustdeskRelayPort}" ];
        volumes = [ "${dataDir}/rustdesk:/root" ];
        depends_on = [ "rustdesk-hbbr" ];
      };
      rustdesk-hbbr = {
        image = "rustdesk/rustdesk-server:latest";
        container_name = "service-plane-rustdesk-hbbr";
        restart = "unless-stopped";
        network_mode = "host";
        command = [ "hbbr" ];
        volumes = [ "${dataDir}/rustdesk:/root" ];
      };

    }
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

  searxngSettings = pkgs.writeText "searxng-settings.yml" (builtins.readFile ./searxng-settings.yml);

in
{
  xdg.configFile."service-plane/docker-compose.yml".source = composeContent;
  xdg.configFile."service-plane/scripts/tcp-gate.sh".source = gateScript;
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
  home.activation.servicePlaneDataDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _:
      ''mkdir -p "${dataDir}/${name}"''
    ) tcpServices)}
    mkdir -p "${dataDir}/rustdesk"
    mkdir -p "${dataDir}/comfyui"
    mkdir -p "${dataDir}/llm/models"
  '';
  systemd.user.services.service-plane-llm-model = {
    Unit = {
      Description = "Download Qwen3-4B GGUF model for service-plane LLM";
      ConditionPathExists = "!${dataDir}/llm/models/qwen3-4b-q4_k_m.gguf";
    };
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "service-plane-llm-model" (tpl ./download-llm-model.sh {
        inherit dataDir;
        curl = "${pkgs.curl}/bin/curl";
      }));
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.service-plane = {
    Unit = {
      Description = "Service Plane (Traefik + Sablier + TCP Gate + containers)";
      After = [ "default.target" ];
      ConditionPathExists = dockerSocketConditionForUserUnit;
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStopSec = 30;
      WorkingDirectory = planeDir;
      ExecStart = pkgs.writeShellScript "service-plane-up" (tpl ./service-plane-up.sh {
        inherit planeDir;
        docker = "${pkgs.docker}/bin/docker";
        stopTcpBackends = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _: ''
          ${pkgs.docker}/bin/docker stop "service-plane-${name}-1" 2>/dev/null || true
        '') tcpServices);
      });
      ExecStop = pkgs.writeShellScript "service-plane-down" ''
        cd "${planeDir}"
        ${pkgs.docker}/bin/docker compose down --timeout 10
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };
  home.sessionVariables = {
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
    CMAKE_C_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
    CMAKE_CXX_COMPILER_LAUNCHER = "${pkgs.sccache}/bin/sccache";
    SCCACHE_REDIS = "redis://127.0.0.1:${toString tcpServices.dragonfly.hostPort}";
    SCCACHE_CACHE_SIZE = "10G";
    SCCACHE_IDLE_TIMEOUT = "0";
  };
}
