"""将形码引导键从 [ 改为 ; 并移除 semicolon 选词绑定"""
import sys

schema_path = sys.argv[1]  # moqi_wan_flypy.schema.yaml
speller_path = sys.argv[2]  # moqi_speller.yaml

# ── patch moqi_speller.yaml: derive 规则中 $1[$2 → $1;$2 ──
content = open(speller_path).read()
content = content.replace("$1[$2/", "$1;$2/")
open(speller_path, "w").write(content)

# ── patch moqi_wan_flypy.schema.yaml ──
lines = open(schema_path).readlines()
out = []
for line in lines:
    # alphabet: 把 [ 替换为 ;
    if line.strip().startswith("alphabet:") and "[" in line:
        line = line.replace("[", ";")
    # 移除 semicolon 选第2候选的绑定（与形码引导冲突）
    if "accept: semicolon" in line and "send: 2" in line:
        continue
    # key_bindings send_sequence 中的 [ → ;（Ctrl+N 补辅助码）
    if "send_sequence:" in line and "['" in line:
        line = line.replace("['", ";'")
    if "send_sequence:" in line and "}['" in line:
        line = line.replace("}['", "};'")
    # send_sequence 末尾的 [' 形式
    if "send_sequence:" in line and "[" in line and "Shift+Right" in line:
        line = line.replace("}[", "};")
    # Tab 引导辅助码注释行
    if "send: '['" in line:
        line = line.replace("send: '['", "send: ';'")
    out.append(line)

open(schema_path, "w").write("".join(out))
