{ config, lib, pkgs, ... }:

# Clash Verge Rev — 首次播种 GUI 可编辑的默认配置 + 关键 bug workaround
#
# 目标：开箱即默认开启 TUN / 系统代理 / 局域网 / ipv6 / 开机启动，
#       但这些仍是普通可变文件，用户随时能在图形界面里改（不写死、不只读）。
#
# 做法：用 home-manager 的 activation 脚本，在「文件不存在时」才写入默认值；
#       一旦文件存在（即用户/GUI 已写过），就完全不动它，避免覆盖用户改动。
#       例外：enable_auto_light_weight_mode 必须始终强制关闭（v2.5.x bug workaround）。
#
# 涉及两个文件（位于 clash-verge-rev 的数据目录）：
#   verge.yaml   —— 应用级开关（TUN / 系统代理 / 静默启动 / 开机自启 / 端口）
#   config.yaml  —— clash 核心覆盖项（局域网 allow-lan / ipv6 / 混合端口）
#
# 数据目录：~/.local/share/io.github.clash-verge-rev.clash-verge-rev/
#
# ── Bug workaround ──────────────────────────────────────────────────
# v2.5.x 的「轻量模式」(lightweight mode) 在从托盘恢复窗口时会失败：
#   ERROR [Window] 轻量模式退出失败，无法恢复应用窗口
# 导致 webview 无法渲染，Proxy 菜单显示空白。
# 解决：强制 enable_auto_light_weight_mode = false，每次 rebuild 都确保该字段正确。

let
  yamlFormat = pkgs.formats.yaml { };
  yq = "${pkgs.yq-go}/bin/yq";
  appDir = "${config.home.homeDirectory}/.local/share/io.github.clash-verge-rev.clash-verge-rev";
  mixedPort = 7897;

  # 应用级默认开关（对应 IVergeConfig）
  vergeDefaults = {
    enable_tun_mode = true;                   # 默认开启 TUN
    enable_system_proxy = true;               # 默认开启系统代理
    enable_silent_start = false;              # 禁用静默启动（触发轻量模式导致 GUI 空白）
    enable_auto_launch = true;                # GUI 中标记为开机自启
    verge_mixed_port = mixedPort;             # 混合端口（与防火墙放行端口一致）
    enable_random_port = false;
    enable_auto_light_weight_mode = false;    # 禁用轻量模式（v2.5.x bug workaround）

    # 主题：透明背景，露出窗口的液态玻璃效果
    theme_setting = {
      css_injection = ''
        html, body, #root, #app {
          background: transparent !important;
        }
        .MuiPaper-root, .MuiDrawer-paper, .layout__left,
        .base-page, [class*="layout"], [class*="Layout"] {
          background: transparent !important;
        }
        .MuiAppBar-root {
          background: transparent !important;
          backdrop-filter: none !important;
        }
      '';
    };
  };

  # clash 核心覆盖项默认值（对应 Clash 设置页：局域网 / ipv6）
  clashDefaults = {
    "allow-lan" = true;           # 默认允许局域网代理
    ipv6 = true;                  # 默认开启 ipv6
    "mixed-port" = mixedPort;
    mode = "rule";                # 默认规则模式（不能用 direct，否则代理不工作）
  };

  vergeYaml = yamlFormat.generate "verge.yaml.default" vergeDefaults;
  configYaml = yamlFormat.generate "config.yaml.default" clashDefaults;

  # 单独生成 theme_setting 片段，用于强制合并到已有 verge.yaml
  themeSnippet = yamlFormat.generate "theme-snippet.yaml" {
    theme_setting = vergeDefaults.theme_setting;
  };
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

      # ── 强制修补：禁用轻量模式（无论新旧文件都执行） ──
      # 使用 sed 原地替换；如果字段不存在则追加
      if grep -q "enable_auto_light_weight_mode" "$_appdir/verge.yaml"; then
        run ${pkgs.gnused}/bin/sed -i \
          's/^enable_auto_light_weight_mode:.*/enable_auto_light_weight_mode: false/' \
          "$_appdir/verge.yaml"
      else
        echo "enable_auto_light_weight_mode: false" >> "$_appdir/verge.yaml"
      fi

      # ── 强制修补：透明主题 CSS 注入（无论新旧文件都执行） ──
      run ${yq} eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
        "$_appdir/verge.yaml" ${themeSnippet} > "$_appdir/verge.yaml.tmp"
      run mv "$_appdir/verge.yaml.tmp" "$_appdir/verge.yaml"
      echo "clash-verge: force-patched theme_setting (transparent CSS)"

      if [ ! -e "$_appdir/config.yaml" ]; then
        run cp ${configYaml} "$_appdir/config.yaml"
        run chmod 644 "$_appdir/config.yaml"
        echo "clash-verge: seeded default config.yaml"
      else
        echo "clash-verge: config.yaml exists, leaving GUI-managed config untouched"
      fi
    '';

  # 注册 .desktop 文件，供 mimeApps 引用（解决 init_scheme() 写只读 mimeapps.list 的 EROFS 错误）
  xdg.desktopEntries.clash-verge-rev = {
    name = "Clash Verge Rev";
    genericName = "Proxy Client";
    comment = "A Clash Meta GUI based on Tauri";
    exec = "${pkgs.clash-verge-rev}/bin/clash-verge %u";
    terminal = false;
    icon = "clash-verge";
    categories = [ "Network" ];
    mimeType = [ "x-scheme-handler/clash" ];
  };
}
