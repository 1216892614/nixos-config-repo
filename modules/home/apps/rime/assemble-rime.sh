mkdir -p $out
cp -r @rimeBase@/. $out/
chmod -R u+w $out

cp @defaultCustom@ $out/default.custom.yaml
cp @moqiSingleXhCustom@ $out/moqi_single_xh.custom.yaml
rm -f $out/moqi_wan_flypy.custom.yaml

python3 @patchSpellerScript@ @fuzzyQuanpinYaml@ $out/moqi_speller.yaml
python3 @patchMoqiScript@ $out/moqi.yaml @punctuatorYaml@

# AI 候选词: filter + moqi.yaml 注册
cp @aiImeFilter@ $out/lua/ai_ime.lua
python3 @aiImePatchScript@ $out/moqi.yaml

# rime.lua: 确保模块被加载（librime-lua 自动发现需要此文件存在）
cat > $out/rime.lua << 'RIMEEOF'
-- Rime lua 模块入口
-- librime-lua 通过 @* 语法自动匹配 lua/ 目录下同名文件
-- 此文件确保 rime 加载 lua 环境
RIMEEOF
