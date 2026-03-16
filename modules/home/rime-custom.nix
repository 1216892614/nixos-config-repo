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
    hash = "sha256-39STMvHWcix3C11ZXUicEXg1wa8sj4KinVY3aMQHYE4=";
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
  home.activation.copyRimeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    RIME_SRC="${rimeWithCustom}"
    RIME_DEST="${config.home.homeDirectory}/.local/share/fcitx5/rime"
    $DRY_RUN_CMD mkdir -p "$RIME_DEST"
    $DRY_RUN_CMD cp -rL --no-preserve=mode "$RIME_SRC"/* "$RIME_DEST"/ 2>/dev/null || true
    $DRY_RUN_CMD chmod -R u+w "$RIME_DEST" 2>/dev/null || true
    $DRY_RUN_CMD rm -rf "$RIME_DEST"/build 2>/dev/null || true
  '';
}
