{ config, lib, pkgs, ... }:

# Clash Verge Rev — 首次播种 GUI 可编辑的默认配置
#
# 目标：开箱即默认开启 TUN / 系统代理 / 局域网 / ipv6 / 开机启动，
#       但这些仍是普通可变文件，用户随时能在图形界面里改（不写死、不只读）。
#
# 做法：用 home-manager 的 activation 脚本，在「文件不存在时」才写入默认值；
#       一旦文件存在（即用户/GUI 已写过），就完全不动它，避免覆盖用户改动。
#
# 涉及两个文件（位于 clash-verge-rev 的数据目录）：
#   verge.yaml   —— 应用级开关（TUN / 系统代理 / 静默启动 / 开机自启 / 端口）
#   config.yaml  —— clash 核心覆盖项（局域网 allow-lan / ipv6 / 混合端口）
#
# 数据目录：~/.local/share/io.github.clash-verge-rev.clash-verge-rev/

let
  yamlFormat = pkgs.formats.yaml { };
  appDir = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
  mixedPort = 7897;

  # 应用级默认开关（对应 IVergeConfig）
  vergeDefaults = {
    enable_tun_mode = true;       # 默认开启 TUN
    enable_system_proxy = true;   # 默认开启系统代理
    enable_silent_start = true;   # 静默启动到托盘，不弹主窗口
    enable_auto_launch = true;    # GUI 中标记为开机自启（实际开机由 niri 拉起）
    verge_mixed_port = mixedPort; # 混合端口（与防火墙放行端口一致）
    enable_random_port = false;
  };

  # clash 核心覆盖项默认值（对应 Clash 设置页：局域网 / ipv6）
  clashDefaults = {
    "allow-lan" = true;           # 默认允许局域网代理
    ipv6 = true;                  # 默认开启 ipv6
    "mixed-port" = mixedPort;
  };

  vergeYaml = yamlFormat.generate "verge.yaml.default" vergeDefaults;
  configYaml = yamlFormat.generate "config.yaml.default" clashDefaults;
in
{
  home.activation.seedClashVergeConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _appdir="${appDir}"
      run mkdir -p "$_appdir"

      # 仅在目标文件不存在时播种，已存在则保留用户/GUI 的改动
      if [ ! -e "$_appdir/verge.yaml" ]; then
        run cp ${vergeYaml} "$_appdir/verge.yaml"
        run chmod 644 "$_appdir/verge.yaml"
        echo "clash-verge: seeded default verge.yaml"
      else
        echo "clash-verge: verge.yaml exists, leaving GUI-managed config untouched"
      fi

      if [ ! -e "$_appdir/config.yaml" ]; then
        run cp ${configYaml} "$_appdir/config.yaml"
        run chmod 644 "$_appdir/config.yaml"
        echo "clash-verge: seeded default config.yaml"
      else
        echo "clash-verge: config.yaml exists, leaving GUI-managed config untouched"
      fi
    '';
}
