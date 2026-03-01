# Rime 自定义：模糊音 + 中文模式下默认英文标点
# 与 rime-shuangpin-fuzhuma 合并后作为 fcitx5/rime 数据目录
{ pkgs, ... }:
let
  rimeBase = pkgs.fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-shuangpin-fuzhuma";
    rev = "main";
    hash = "sha256-39STMvHWcix3C11ZXUicEXg1wa8sj4KinVY3aMQHYE4=";
  };

  # 全拼层面模糊音（用于 flypy / zrm 等方案，在双拼转换前派生）
  fuzzyPinyinYaml = pkgs.writeText "fuzzy_pinyin.yaml" ''
    # 模糊音规则（全拼），供各 schema 的 custom 通过 __include 引用
    fuzzy_rules:
      # 平翘舌 zh/ch/sh <-> z/c/s
      - derive/^([zcs])h/$1/
      - derive/^([zcs])([^h].*)$/$1h$2/
      # 前后鼻音
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
      # n/l, f/h, r/l, k/g
      - derive/^l/n/
      - derive/^n/l/
      - derive/^f/h/
      - derive/^h/f/
      - derive/^r/l/
      - derive/^l/r/
      - derive/^k/g/
      - derive/^g/k/
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
  # switches 中 ascii_punct 在 moqi.yaml 里是第 8 项 (0-based: 7)
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
  # recursive = true：目标为可写目录+文件链接，Rime 需在此目录写入 build/、user.yaml 等，否则无候选窗、仅出拉丁字母
  home.file.".local/share/fcitx5/rime" = {
    source = rimeWithCustom;
    recursive = true;
  };
}
