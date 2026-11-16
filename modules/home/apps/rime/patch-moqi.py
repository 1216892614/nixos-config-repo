import sys

moqi_path = sys.argv[1]
punct_path = sys.argv[2] if len(sys.argv) > 2 else None

lines = open(moqi_path).readlines()
out = []
for line in lines:
    out.append(line)
    if "name: ascii_punct" in line:
        out.append("      reset: 1\n")

if punct_path:
    punct_lines = open(punct_path).readlines()
    half_shape_lines = []
    full_shape_lines = []
    current = None
    for pl in punct_lines:
        if pl.strip().startswith("half_shape:"):
            current = "half"
            continue
        elif pl.strip().startswith("full_shape:"):
            current = "full"
            continue
        elif pl.strip() and not pl.startswith(" ") and not pl.startswith("#"):
            current = None
        if current == "half" and pl.startswith("    "):
            half_shape_lines.append(pl)
        elif current == "full" and pl.startswith("    "):
            full_shape_lines.append(pl)

    content = "".join(out)
    content = content.replace(
        "    half_shape:\n      __include: default:/punctuator/half_shape  # 从 default.yaml 导入配置\n",
        "    half_shape:\n" + "".join("  " + l for l in half_shape_lines),
    )
    content = content.replace(
        "    full_shape:\n      __include: default:/punctuator/full_shape  # 从 default.yaml 导入配置\n",
        "    full_shape:\n" + "".join("  " + l for l in full_shape_lines),
    )
    out = content.splitlines(True)

open(moqi_path, "w").write("".join(out))
