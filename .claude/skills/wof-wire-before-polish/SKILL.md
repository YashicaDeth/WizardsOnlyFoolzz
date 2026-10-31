---
name: wof-wire-before-polish
description: Before improving, restyling or rebuilding any system in Wizards Only Fools, find out whether anything calls it, and list finished-but-unwired systems. Use when starting work on a system, when a feature "does nothing in game", when planning what to build next, or when asked what is built but unused.
metadata:
  project: AllusionsTooGrandeur
---

# Wire before you polish

The most common bug class here is not a missing system — it is a **finished
system nobody connected**. `DamagePortrait` drew an empty frame in every run
ever played; `cab_screens.gd` has no callers; the biometric door, the guard's
gun, the honest opening death and the mosaic option were all written and
tested while the facility route that needs them had zero items ticked.

## Before touching a system

1. `grep -rn "ClassName\|file_name.gd" game --include=*.gd --include=*.tscn`
   excluding `game/tests/` and `game/addons/`.
2. No production caller? Wiring it in is worth more than any polish. Find the
   scene or system that should own it (check `ARCHITECTURE/SYSTEM_MAP.md` and
   the owning lane in `AGENT_SPLIT_6.md`) and connect it first.
3. Only callers are tests? It is built and proven but unplaced — the cheapest
   progress in the project.

## Audit the whole game

```bash
python .claude/skills/wof-wire-before-polish/scripts/wiring_audit.py
```

Prints every system under `game/` with no production reference, split into
"no references anywhere" and "referenced only by tests". Scenes launched
directly by a `Start-*.ps1` (the labs, the splash) show up as unreferenced;
that is expected.

## Before rebuilding

Check the checklist and the flag first. Combat was reworked four times; the
fifth was a boolean (`momentum_damage`). If a finished version exists behind a
flag or on a branch, the job is to switch or merge it, not to write a sixth.
