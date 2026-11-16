import json, sys
with open(sys.argv[1]) as f:
    p = json.load(f)
if p.get('tab_strip', {}).get('tab_strip_layout_type') is not None:
    sys.exit(1)
p.setdefault('tab_strip', {})['tab_strip_layout_type'] = 1
with open(sys.argv[1], 'w') as f:
    json.dump(p, f)
