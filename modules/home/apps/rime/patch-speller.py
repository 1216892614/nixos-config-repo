import sys

fuzzy_path, speller_path = sys.argv[1], sys.argv[2]
fuzzy_lines = open(fuzzy_path).readlines()
rules = [("  " + l) for l in fuzzy_lines if l.startswith("  - ")]

speller = open(speller_path).read()
marker = "flypy_speller:\n"
idx = speller.index(marker) + len(marker)
patched = speller[:idx] + "".join(rules) + speller[idx:]
open(speller_path, "w").write(patched)
