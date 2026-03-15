# Rime 自定义配置
# 与 rime-shuangpin-fuzhuma 合并后作为 fcitx5/rime 数据目录
# 使用 activation 复制到可写目录，避免 store 只读导致 Rime 无法写入 build/user.yaml
{ config, pkgs, ... }:
let
  rimeBase = pkgs.fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-shuangpin-fuzhuma";
    rev = "main";
    hash = "sha256-39STMvHWcix3C11ZXUicEXg1wa8sj4KinVY3aMQHYE4=";
  };

  # 默认只启用摩奇小鹤相关方案，首选小鹤晚（moqi_wan_flypy）
  defaultCustom = pkgs.writeText "default.custom.yaml" ''
    patch:
      schema_list:
        - schema: moqi_wan_flypy
        - schema: moqi_single_xh
        - schema: quanpin
  '';

  # 墨奇+小鹤双拼·鹤形 自定义配置（模糊音+英文符号）
  moqiWanFlypyCustom = pkgs.writeText "moqi_wan_flypy.custom.yaml" (builtins.readFile ./moqi_wan_flypy.custom.yaml);

  # 墨奇单字+小鹤双拼 自定义配置（模糊音+英文符号）
  moqiSingleXhCustom = pkgs.writeText "moqi_single_xh.custom.yaml" (builtins.readFile ./moqi_single_xh.custom.yaml);

  rimeWithCustom = pkgs.runCommand "fcitx5-rime-with-custom" { } ''
    mkdir -p $out
    cp -r ${rimeBase}/. $out/
    cp ${defaultCustom} $out/default.custom.yaml
    cp ${moqiWanFlypyCustom} $out/moqi_wan_flypy.custom.yaml
    cp ${moqiSingleXhCustom} $out/moqi_single_xh.custom.yaml
  '';
in
{
  # 复制到可写目录（activation 以当前用户运行，不 rm 避免删不动 root 所属文件）
  home.activation.copyRimeConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    RIME_SRC="${rimeWithCustom}"
    RIME_DEST="${config.home.homeDirectory}/.local/share/fcitx5/rime"
    $DRY_RUN_CMD mkdir -p "$RIME_DEST"
    $DRY_RUN_CMD cp -rL "$RIME_SRC"/* "$RIME_DEST"/ 2>/dev/null || true
    $DRY_RUN_CMD rm -rf "$RIME_DEST"/build 2>/dev/null || true
  '';
}
