# Rime 自定义配置 + fcitx5 Forest Night 主题
# 与 rime-shuangpin-fuzhuma 合并后作为 fcitx5/rime 数据目录
# 使用 activation 复制到可写目录，避免 store 只读导致 Rime 无法写入 build/user.yaml
#
# moqi_wan_flypy.schema.yaml 存在 __include/__patch 循环依赖，
# Rime config compiler 会静默跳过 .custom.yaml 的合并。
# 因此模糊音和英文标点改用直接 patch 源文件的方式。
{ config, pkgs, ... }:
let
  rimeBase = pkgs.fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-shuangpin-fuzhuma";
    rev = "main";
    hash = "sha256-XE92YYrikT1TbfeXMCYiL9a3eo7mt/Dp3s6egiaE0R0=";
  };

  defaultCustom = pkgs.writeText "default.custom.yaml" ''
    patch:
      schema_list:
        - schema: moqi_wan_flypy
        - schema: moqi_single_xh
  '';

  # moqi_single_xh 没有循环依赖，custom 正常生效
  moqiSingleXhCustom = pkgs.writeText "moqi_single_xh.custom.yaml"
    (builtins.readFile ./moqi_single_xh.custom.yaml);

  # 全拼层面模糊音 derive 规则文件
  fuzzyQuanpinYaml = ./rime-fuzzy-quanpin.yaml;

  patchSpellerScript = ./patch-speller.py;
  patchMoqiScript = ./patch-moqi.py;
  punctuatorYaml = ./rime-punctuator.yaml;

  rimeWithCustom = pkgs.runCommand "fcitx5-rime-with-custom" {
    nativeBuildInputs = [ pkgs.python3 ];
  } ''
    mkdir -p $out
    cp -r ${rimeBase}/. $out/
    chmod -R u+w $out

    cp ${defaultCustom} $out/default.custom.yaml
    cp ${moqiSingleXhCustom} $out/moqi_single_xh.custom.yaml
    rm -f $out/moqi_wan_flypy.custom.yaml

    python3 ${patchSpellerScript} ${fuzzyQuanpinYaml} $out/moqi_speller.yaml
    python3 ${patchMoqiScript} $out/moqi.yaml ${punctuatorYaml}
  '';
in
{
  # ── fcitx5 Forest Night 主题 ──────────────────────────────────────
  # 主题文件 → ~/.local/share/fcitx5/themes/ForestNight/theme.conf
  xdg.dataFile."fcitx5/themes/ForestNight/theme.conf".source = ./fcitx5-theme-forest-night.conf;

  # ClassicUI 配置：选用 Forest Night 主题 + 竖排候选 + 光标跟随
  # PerScreenDPI 确保 HiDPI 下候选窗口大小正确
  # ForceWaylandDPI=0 让 fcitx5 使用 Wayland 报告的 scale factor
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    # 主题
    Theme=ForestNight
    # 竖排候选词（更不容易被遮挡，且视觉更紧凑）
    Vertical Candidate List=True
    # 跟随光标定位候选窗口
    PerScreenDPI=True
    # Wayland 下使用 compositor 报告的 DPI，避免候选窗口大小异常
    ForceWaylandDPI=0
    # 候选词按单行显示
    WheelForPaging=True
  '';

  # ── Rime 数据目录 ────────────────────────────────────────────────
  home.activation.copyRimeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    RIME_SRC="${rimeWithCustom}"
    RIME_DEST="${config.home.homeDirectory}/.local/share/fcitx5/rime"
    RIME_STAMP="$RIME_DEST/.nix-source-hash"
    FCITX_PROFILE="${config.home.homeDirectory}/.config/fcitx5/profile"
    $DRY_RUN_CMD mkdir -p "$RIME_DEST"

    NEW_HASH="${rimeWithCustom}"
    OLD_HASH="$(cat "$RIME_STAMP" 2>/dev/null || echo "")"
    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
      $DRY_RUN_CMD cp -rL --no-preserve=mode "$RIME_SRC"/* "$RIME_DEST"/ 2>/dev/null || true
      $DRY_RUN_CMD chmod -R u+w "$RIME_DEST" 2>/dev/null || true
      $DRY_RUN_CMD rm -rf "$RIME_DEST"/build 2>/dev/null || true
      echo "$NEW_HASH" > "$RIME_STAMP"
    fi

    # Ensure rime is in fcitx5 profile (fcitx5 strips it when Rime fails to load)
    if [ -f "$FCITX_PROFILE" ] && ! grep -q "Name=rime" "$FCITX_PROFILE" 2>/dev/null; then
      $DRY_RUN_CMD rm -f "$FCITX_PROFILE"
    fi
  '';
}
