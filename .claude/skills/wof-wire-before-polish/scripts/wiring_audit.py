"""List Wizards Only Fools systems that nothing in the game calls.

Run from anywhere inside the repo:  python .claude/skills/wof-wire-before-polish/scripts/wiring_audit.py
A system counts as referenced when another non-test .gd/.tscn/.tres/.godot file
names its class_name or its file name.
"""
import os
import re
import subprocess
import sys

root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
if not root:
    sys.exit("run this inside the repo")
game = os.path.join(root, "game")
files = []
for directory, _, names in os.walk(game):
    rel = os.path.relpath(directory, game).replace(os.sep, "/")
    if rel.startswith(("addons", ".godot")):
        continue
    for name in names:
        if name.endswith((".gd", ".tscn", ".tres", ".godot")):
            files.append(os.path.join(directory, name).replace(os.sep, "/"))
text = {f: open(f, encoding="utf-8", errors="ignore").read() for f in files}
is_test = lambda f: "/game/tests/" in f
orphans, test_only = [], []
for s in (f for f in files if f.endswith(".gd") and not is_test(f)):
    m = re.search(r"^class_name\s+(\w+)", text[s], re.M)
    keys = [os.path.basename(s)] + ([m.group(1)] if m else [])
    pat = re.compile("|".join(r"\b" + re.escape(k) + r"\b" for k in keys))
    prod = tests = 0
    for f, t in text.items():
        if f in (s, s[:-3] + ".tscn") or not pat.search(t):
            continue
        if is_test(f):
            tests += 1
        else:
            prod += 1
    if prod == 0:
        (test_only if tests else orphans).append((text[s].count("\n"), os.path.relpath(s, root)))
for title, rows in (("NO references anywhere", orphans), ("Referenced ONLY by tests", test_only)):
    print(f"{title} ({len(rows)}):")
    for lines, path in sorted(rows, reverse=True):
        print(f"  {lines:5}  {path}")
