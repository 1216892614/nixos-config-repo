# Rime 自定义配置
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
  patchWanFlypyScript = ./patch-wan-flypy.py;
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
    python3 ${patchWanFlypyScript} $out/moqi_wan_flypy.schema.yaml
  '';
in
{
  home.activation.copyRimeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    RIME_SRC="${rimeWithCustom}"
    RIME_DEST="${config.home.homeDirectory}/.local/share/fcitx5/rime"
    RIME_STAMP="$RIME_DEST/.nix-source-hash"
    FCITX_PROFILE="${config.home.homeDirectory}/.config/fcitx5/profile"
    $DRY_RUN_CMD mkdir -p "$RIME_DEST"

    NEW_HASH="${rimeWithCustom}"
    OLD_HASH="$(cat "$RIME_STAMP" 2>/dev/null || echo "")"
    if [ "$NEW_HASH" != "$OLD_HASH" ]; then
      # Preserve user data: *.userdb/ (word frequency), user.yaml, user.custom.dict*
      $DRY_RUN_CMD ${pkgs.rsync}/bin/rsync -rL --chmod=u+w \
        --exclude='*.userdb' --exclude='*.userdb/**' \
        --exclude='user.yaml' \
        --exclude='user.custom.dict*' \
        --exclude='.nix-source-hash' \
        "$RIME_SRC"/ "$RIME_DEST"/
      $DRY_RUN_CMD rm -rf "$RIME_DEST"/build 2>/dev/null || true
      echo "$NEW_HASH" > "$RIME_STAMP"
    fi

    # Ensure rime is in fcitx5 profile (fcitx5 strips it when Rime fails to load)
    if [ -f "$FCITX_PROFILE" ] && ! grep -q "Name=rime" "$FCITX_PROFILE" 2>/dev/null; then
      $DRY_RUN_CMD rm -f "$FCITX_PROFILE"
    fi
  '';
}
