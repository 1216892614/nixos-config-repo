{ pkgs, lib, config, ... }:

let
  captureGroup = "nocapture";
  captureUser = "mitmuser";
  caDir = "/var/lib/mitmproxy-ca";
  caCert = "${caDir}/mitmproxy-ca-cert.pem";

  # nixpkgs mitmproxy 12.2.1 Rust 子模块构建失败 (substituteInPlace bug)
  # 使用官方预编译二进制代替
  mitmproxy-bin = pkgs.stdenv.mkDerivation rec {
    pname = "mitmproxy-bin";
    version = "11.1.3";

    src = pkgs.fetchurl {
      url = "https://downloads.mitmproxy.org/${version}/mitmproxy-${version}-linux-x86_64.tar.gz";
      sha256 = "0m68pf41qzkww7lmw4d6lyd8dfvm6ipip2a3r7dakzcwf47smygk";
    };

    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [ zlib openssl stdenv.cc.cc.lib ];

    installPhase = ''
      mkdir -p $out/bin
      cp mitmproxy mitmdump mitmweb $out/bin/
    '';

    meta = {
      description = "mitmproxy (prebuilt binary)";
      homepage = "https://mitmproxy.org";
    };
  };

  captureScript = pkgs.writeShellScriptBin "capture" ''
    set -euo pipefail

    CAPTURE_PORT=8082
    CA_DIR="${caDir}"
    CA_CERT="${caCert}"
    CAPTURE_GROUP="${captureGroup}"
    CAPTURE_USER="${captureUser}"
    MITMPROXY_PID="/run/mitmproxy-capture.pid"
    TCPDUMP_PID="/run/tcpdump-capture.pid"
    SSLKEYLOG="/tmp/sslkeys.log"
    CAPTURE_BASE="/var/lib/mitmproxy-captures"
    CAPTURE_DIR="$CAPTURE_BASE/$(date +%Y%m%d-%H%M%S)"

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    check_root() {
      if [ "$(id -u)" -ne 0 ]; then
        echo -e "''${RED}Error: must run as root (sudo capture ...)''${NC}"
        exit 1
      fi
    }

    nft_rules_exist() {
      ${pkgs.nftables}/bin/nft list table ip capture_redirect &>/dev/null 2>&1
    }

    add_nft_rules() {
      local uid gid
      uid=$(id -u ep-o1)
      gid=$(getent group "$CAPTURE_GROUP" | cut -d: -f3)

      ${pkgs.nftables}/bin/nft -f - <<EOF
    table ip capture_redirect {
      chain output {
        type nat hook output priority -100; policy accept;
        meta skgid $gid accept
        ip daddr 127.0.0.0/8 accept
        ip daddr 192.168.0.0/16 accept
        ip daddr 10.0.0.0/8 accept
        ip daddr 172.16.0.0/12 accept
        meta skuid $uid tcp dport { 80, 443 } redirect to :$CAPTURE_PORT
      }
      chain output_filter {
        type filter hook output priority 0; policy accept;
        meta skgid != $gid meta skuid $uid udp dport 443 drop
      }
    }
    EOF
      echo -e "''${GREEN}nftables redirect rules added''${NC}"
    }

    remove_nft_rules() {
      if nft_rules_exist; then
        ${pkgs.nftables}/bin/nft delete table ip capture_redirect
        echo -e "''${GREEN}nftables redirect rules removed''${NC}"
      fi
    }

    start_mitmproxy() {
      mkdir -p "$CAPTURE_DIR"
      chown "$CAPTURE_USER:$CAPTURE_GROUP" "$CAPTURE_BASE"
      chown "$CAPTURE_USER:$CAPTURE_GROUP" "$CAPTURE_DIR"

      rm -f "$SSLKEYLOG"
      touch "$SSLKEYLOG"
      chmod 666 "$SSLKEYLOG"

      ${pkgs.sudo}/bin/sudo -u "$CAPTURE_USER" \
        MITMPROXY_SSLKEYLOGFILE="$SSLKEYLOG" \
        ${mitmproxy-bin}/bin/mitmweb \
          --mode transparent \
          --listen-host 0.0.0.0 \
          --listen-port "$CAPTURE_PORT" \
          --set confdir="$CA_DIR" \
          --set block_global=false \
          --set ssl_insecure=true \
          --set connection_strategy=lazy \
          --set web_open_browser=false \
          --set web_password=capture \
          --web-host 127.0.0.1 \
          --web-port 8081 \
          --save-stream-file "$CAPTURE_DIR/traffic.flow" \
          &>"$CAPTURE_DIR/mitmproxy.log" &

      echo $! > "$MITMPROXY_PID"
      sleep 3

      if kill -0 "$(cat "$MITMPROXY_PID")" 2>/dev/null; then
        echo -e "''${GREEN}mitmweb started (PID $(cat "$MITMPROXY_PID"))''${NC}"
        echo "  Web UI: http://127.0.0.1:8081"
        echo "  Password: capture"
        echo "  Flow file: $CAPTURE_DIR/traffic.flow"
      else
        echo -e "''${RED}mitmweb failed to start:''${NC}"
        cat "$CAPTURE_DIR/mitmproxy.log"
        return 1
      fi
    }

    start_tcpdump() {
      ${pkgs.tcpdump}/bin/tcpdump \
        -i enp14s0 \
        -w "$CAPTURE_DIR/raw.pcap" \
        -U \
        'not port 22' \
        &>/dev/null &
      echo $! > "$TCPDUMP_PID"
      echo -e "''${GREEN}tcpdump started → $CAPTURE_DIR/raw.pcap''${NC}"
    }

    stop_all() {
      if [ -f "$MITMPROXY_PID" ]; then
        local pid
        pid=$(cat "$MITMPROXY_PID")
        if kill -0 "$pid" 2>/dev/null; then
          kill "$pid" 2>/dev/null || true
          sleep 1
          kill -9 "$pid" 2>/dev/null || true
          echo -e "''${GREEN}mitmproxy stopped''${NC}"
        fi
        rm -f "$MITMPROXY_PID"
      fi

      if [ -f "$TCPDUMP_PID" ]; then
        local pid
        pid=$(cat "$TCPDUMP_PID")
        if kill -0 "$pid" 2>/dev/null; then
          kill "$pid" 2>/dev/null || true
          echo -e "''${GREEN}tcpdump stopped''${NC}"
        fi
        rm -f "$TCPDUMP_PID"
      fi

      remove_nft_rules
    }

    ensure_ca() {
      if [ -f "$CA_CERT" ]; then
        return 0
      fi
      echo "CA not found, generating..."
      mkdir -p "$CA_DIR"
      chown "$CAPTURE_USER:$CAPTURE_GROUP" "$CA_DIR"

      ${pkgs.sudo}/bin/sudo -u "$CAPTURE_USER" \
        ${mitmproxy-bin}/bin/mitmdump \
          --set confdir="$CA_DIR" \
          -p 0 \
          --set shutdowndelay=0 &
      local pid=$!
      sleep 2
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true

      if [ ! -f "$CA_CERT" ]; then
        echo -e "''${RED}Failed to generate CA''${NC}"
        exit 1
      fi
      echo -e "''${GREEN}CA generated''${NC}"

      # 同步到仓库让下次 rebuild 自动信任
      local repo_cert="/home/ep-o1/nixos-config-repo/secrets/mitmproxy-ca-cert.pem"
      mkdir -p "$(dirname "$repo_cert")"
      cp "$CA_CERT" "$repo_cert"
      chown ep-o1:users "$repo_cert"
      echo -e "''${YELLOW}CA copied to repo. Run rebuild once to trust it system-wide.''${NC}"
    }

    cmd_start() {
      check_root

      if nft_rules_exist; then
        echo -e "''${YELLOW}Capture already running. Use 'capture stop' first.''${NC}"
        exit 1
      fi

      ensure_ca

      mkdir -p "$CAPTURE_DIR"
      echo -e "''${GREEN}Session: $CAPTURE_DIR''${NC}"
      echo ""

      start_mitmproxy
      start_tcpdump
      add_nft_rules

      echo ""
      echo -e "''${GREEN}═══ Capture Active ═══''${NC}"
      echo "  mitmweb UI:    http://127.0.0.1:8081"
      echo "  Flow file:     $CAPTURE_DIR/traffic.flow"
      echo "  Raw pcap:      $CAPTURE_DIR/raw.pcap"
      echo "  TLS keylog:    $SSLKEYLOG"
      echo ""
      echo "  Wireshark with TLS decryption:"
      echo "    wireshark -o tls.keylog_file:$SSLKEYLOG $CAPTURE_DIR/raw.pcap"
      echo ""
      echo -e "  Stop: ''${YELLOW}sudo capture stop''${NC}"
    }

    cmd_stop() {
      check_root
      stop_all
      echo -e "''${GREEN}═══ Capture Stopped ═══''${NC}"
    }

    cmd_status() {
      echo "=== Capture Status ==="
      echo ""

      if nft_rules_exist; then
        echo -e "nftables: ''${GREEN}ACTIVE''${NC}"
        ${pkgs.nftables}/bin/nft list table ip capture_redirect
      else
        echo -e "nftables: ''${RED}INACTIVE''${NC}"
      fi
      echo ""

      if [ -f "$MITMPROXY_PID" ] && kill -0 "$(cat "$MITMPROXY_PID")" 2>/dev/null; then
        echo -e "mitmproxy: ''${GREEN}RUNNING''${NC} (PID $(cat "$MITMPROXY_PID"))"
      else
        echo -e "mitmproxy: ''${RED}STOPPED''${NC}"
      fi

      if [ -f "$TCPDUMP_PID" ] && kill -0 "$(cat "$TCPDUMP_PID")" 2>/dev/null; then
        echo -e "tcpdump: ''${GREEN}RUNNING''${NC} (PID $(cat "$TCPDUMP_PID"))"
      else
        echo -e "tcpdump: ''${RED}STOPPED''${NC}"
      fi

      if [ -f "$SSLKEYLOG" ] && [ -s "$SSLKEYLOG" ]; then
        echo -e "SSLKEYLOGFILE: ''${GREEN}$(wc -l < "$SSLKEYLOG") keys''${NC}"
      else
        echo -e "SSLKEYLOGFILE: ''${YELLOW}empty/missing''${NC}"
      fi
    }

    case "''${1:-}" in
      start)  cmd_start ;;
      stop)   cmd_stop ;;
      status) cmd_status ;;
      *)
        echo "Usage: sudo capture {start|stop|status}"
        exit 1
        ;;
    esac
  '';
in
{
  environment.systemPackages = with pkgs; [
    mitmproxy-bin
    wireshark
    tcpdump
    nftables
    termshark
    captureScript
  ];

  users.groups.${captureGroup} = {};

  users.users.${captureUser} = {
    isSystemUser = true;
    group = captureGroup;
    home = "/var/lib/mitmproxy-ca";
  };

  users.users.ep-o1.extraGroups = [ "wireshark" captureGroup ];

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  security.pki.certificateFiles = [ ../../secrets/mitmproxy-ca-cert.pem ];

  systemd.tmpfiles.rules = [
    "d ${caDir} 0755 ${captureUser} ${captureGroup} -"
    "d /var/lib/mitmproxy-captures 0775 ${captureUser} ${captureGroup} -"
    "L+ /home/ep-o1/captures - - - - /var/lib/mitmproxy-captures"
  ];

  environment.sessionVariables = {
    SSLKEYLOGFILE = "/tmp/sslkeys.log";
  };
}
