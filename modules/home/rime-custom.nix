# Rime 自定义：模糊音 + 中文模式下默认英文标点
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

  # 全拼层面模糊音（用于小鹤/自然码等双拼方案，在双拼转换前派生）
  # 仅保留常用：平翘舌、前后鼻音 an/ang en/eng in/ing ian/iang uan/uang、ong/iong、n/l
  fuzzyPinyinYaml = pkgs.writeText "fuzzy_pinyin.yaml" ''
    # 模糊音规则（全拼），供各 schema 的 custom 通过 __include 引用
    fuzzy_rules:
      # 平翘舌 z/zh, c/ch, s/sh
      - derive/^([zcs])h/$1/
      - derive/^([zcs])([^h].*)$/$1h$2/
      # 前后鼻音 an/ang, en/eng, in/ing, ian/iang, uan/uang
      - derive/ang$/an/
      - derive/an$/ang/
      - derive/eng$/en/
      - derive/en$/eng/
      - derive/ing$/in/
      - derive/in$/ing/
      - derive/ian$/iang/
      - derive/iang$/ian/
      - derive/uan$/uang/
      - derive/uang$/uan/
      # ong/iong
      - derive/ong$/iong/
      - derive/iong$/ong/
      # 声母 n/l
      - derive/^l/n/
      - derive/^n/l/
  '';

  # 小鹤键位空间模糊音（仅用于 moqi_single_xh 顶屏版，该方案 algebra 已是键位）
  fuzzyFlypyKeyYaml = pkgs.writeText "fuzzy_flypy_key.yaml" ''
    fuzzy_flypy_key:
      - derive/^z([a-z])/v$1/
      - derive/^c([a-z])/i$1/
      - derive/^s([a-z])/u$1/
      - derive/^v([a-z])/z$1/
      - derive/^i([a-z])/c$1/
      - derive/^u([a-z])/s$1/
  '';

  # 各方案 custom：默认英文标点 (ascii_punct reset: 1) + 模糊音
  # __include 合并后 switches 在 schema 根，ascii_punct 为第 8 项 (0-based: 7)
  moqiWanFlypyCustom = pkgs.writeText "moqi_wan_flypy.custom.yaml" ''
    patch:
      "switches/7/reset": 1
      "speller/algebra":
        - __include: fuzzy_pinyin:/fuzzy_rules
        - __include: moqi_speller.yaml:/flypy_speller
        - __include: moqi_speller.yaml:/moqi_aux
        - __include: moqi_speller.yaml:/common_aux
  '';

  moqiWanZrmCustom = pkgs.writeText "moqi_wan_zrm.custom.yaml" ''
    patch:
      "switches/7/reset": 1
      "speller/algebra":
        - __include: fuzzy_pinyin:/fuzzy_rules
        - __include: moqi_speller.yaml:/zrm_speller
        - __include: moqi_speller.yaml:/zrm_aux
        - __include: moqi_speller.yaml:/common_aux
  '';

  # 顶屏版：algebra 已是小鹤键位，只追加键位模糊音 + 英文标点
  moqiSingleXhCustom = pkgs.writeText "moqi_single_xh.custom.yaml" ''
    patch:
      "switches/7/reset": 1
      "speller/algebra/+":
        - __include: fuzzy_flypy_key:/fuzzy_flypy_key
  '';

  moqiWanFlypymoCustomFile = pkgs.writeText "moqi_wan_flypymo.custom.yaml" ''
    patch:
      "switches/7/reset": 1
      "speller/algebra":
        - __include: fuzzy_pinyin:/fuzzy_rules
        - __include: moqi_speller.yaml:/flypy_speller
        - __include: moqi_speller.yaml:/moqi_aux
        - __include: moqi_speller.yaml:/common_aux
  '';

  rimeWithCustom = pkgs.runCommand "fcitx5-rime-with-custom" { } ''
    mkdir -p $out
    cp -r ${rimeBase}/. $out/
    cp ${fuzzyPinyinYaml} $out/fuzzy_pinyin.yaml
    cp ${fuzzyFlypyKeyYaml} $out/fuzzy_flypy_key.yaml
    cp ${moqiWanFlypymoCustomFile} $out/moqi_wan_flypymo.custom.yaml
    cp ${moqiWanFlypyCustom} $out/moqi_wan_flypy.custom.yaml
    cp ${moqiWanZrmCustom} $out/moqi_wan_zrm.custom.yaml
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
