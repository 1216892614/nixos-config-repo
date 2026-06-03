{ pkgs, lib, ... }:

let
  envPath =
    if builtins.pathExists ../../env.nix then
      ../../env.nix
    else
      ../../env.nix.example;
  env = import envPath;

  fetchConfig = pkgs.writeShellScript "fetch-mihomo-config" ''
    mkdir -p /etc/mihomo
    # 判断是否为有效 YAML（非 HTML 且 yq 可解析）
    is_valid_yaml() {
      local f="$1"
      [ -f "$f" ] && [ -s "$f" ] || return 1
      if ${pkgs.gnugrep}/bin/grep -qE '^\s*<!DOCTYPE|^\s*<html|^<\?xml' "$f" 2>/dev/null; then
        return 1
      fi
      ${pkgs.yq-go}/bin/yq eval '.' "$f" >/dev/null 2>&1
    }
    add_fake_ip_filter() {
      file="$1"
      for d in "+.qq.com" "+.qq.com.cn" "+.tencent.com" "+.wechat.com" "+.weixin.qq.com" "+.wx.qq.com" "+.tim.qq.com"; do
        if ! ${pkgs.gnugrep}/bin/grep -q "^[[:space:]]*- $d\$" "$file"; then
          ${pkgs.gnused}/bin/sed -i "/^  fake-ip-filter:/a\\    - $d" "$file"
        fi
      done
    }
    # Ensure DNS listens on localhost:53 so system resolv.conf works.
    ensure_dns_listen_localhost() {
      file="$1"
      if ! [ -f "$file" ] || ! [ -s "$file" ]; then return 0; fi
      ${pkgs.yq-go}/bin/yq eval '
        .dns = ((.dns | select(tag == "!!map")) // {})
        | .dns.enable = true
        | .dns.listen = "127.0.0.1:53"
      ' -i "$file"
    }
    # TUN 与系统代理排除：localhost/127.0.0.1/::1 不走代理，避免本地服务（如 Vite/miniflare）write EPIPE
    add_tun_exclude_localhost() {
      file="$1"
      if ! [ -f "$file" ] || ! [ -s "$file" ]; then return 0; fi
      ${pkgs.yq-go}/bin/yq eval '
        .tun = ((.tun | select(tag == "!!map")) // {})
        | .tun.enable = true
        | .tun["route-exclude-address"] = ((.tun["route-exclude-address"] // []) + ["127.0.0.0/8", "::1/128"])
        | .tun["route-exclude-address"] |= unique
      ' -i "$file"
    }
    tmp=$(mktemp)
    cleanup() { rm -f "$tmp"; }
    trap cleanup EXIT
    use_fetched=
    if ${pkgs.curl}/bin/curl -sL -o "$tmp" --connect-timeout 15 "${env.mihomoSubscribeUrl}" 2>/dev/null && [ -s "$tmp" ]; then
      if is_valid_yaml "$tmp"; then
        ensure_dns_listen_localhost "$tmp"
        add_fake_ip_filter "$tmp"
        add_tun_exclude_localhost "$tmp"
        cp "$tmp" /etc/mihomo/config.yaml
        use_fetched=1
      fi
    fi
    if [ -z "$use_fetched" ]; then
      if [ -f /etc/mihomo/config.yaml ] && [ -s /etc/mihomo/config.yaml ] && is_valid_yaml /etc/mihomo/config.yaml; then
        ensure_dns_listen_localhost /etc/mihomo/config.yaml
        add_fake_ip_filter /etc/mihomo/config.yaml
        add_tun_exclude_localhost /etc/mihomo/config.yaml
      else
        # 无有效配置：停用 mihomo，切换直连
        echo "nameserver 223.5.5.5" > /etc/resolv.conf
        systemctl stop mihomo.service || true
      fi
    fi
    exit 0
  '';
in
{
  # fetch 脚本用 yq 写 TUN exclude；保证运行时可执行
  environment.systemPackages = [ pkgs.yq-go ];

  services.mihomo = {
    enable = true;
    tunMode = true;
    configFile = "/etc/mihomo/config.yaml";
    webui = pkgs.metacubexd;
  };

  systemd.services.mihomo.serviceConfig = {
    AmbientCapabilities = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
    CapabilityBoundingSet = lib.mkForce "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
  };

  systemd.services.mihomo-fetch-config = {
    description = "Fetch mihomo config from subscribe URL";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [ "mihomo.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = fetchConfig;
      RemainAfterExit = true;
    };
  };

  systemd.timers.mihomo-fetch-config = {
    description = "Periodically update mihomo config (every hour)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* *:00:00";
      Persistent = true;
    };
  };

  networking.firewall = {
    # mihomo tun interface is usually named "Meta"; keep "Mihomo" for compatibility.
    trustedInterfaces = [ "Meta" "Mihomo" ];
    extraReversePathFilterRules = ''
      iifname "Meta" accept
      iifname "Mihomo" accept
    '';
    allowedTCPPorts = [ env.mihomoMixedPort env.mihomoApiPort ];
    allowedUDPPorts = [ env.mihomoMixedPort ];
  };

  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  # 全系统代理环境变量（走本机 mihomo）
  environment.sessionVariables = {
    http_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    HTTP_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    https_proxy = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    HTTPS_PROXY = "http://127.0.0.1:${toString env.mihomoMixedPort}";
    all_proxy = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
    ALL_PROXY = "socks5://127.0.0.1:${toString env.mihomoMixedPort}";
    no_proxy = "localhost,127.0.0.1,::1";
    NO_PROXY = "localhost,127.0.0.1,::1";
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
