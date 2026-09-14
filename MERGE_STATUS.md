# Merge status — 15 September 2026, overnight

Integration pass run while nobody was awake. This file is the handover: what
landed, what did not, and the five questions that have to be answered before
the rest can.

## Where the number went

**77 unmerged commits across 10 branches -> 43 across 5.** Plus one
branch that did not exist when this started: `lane-4-demo`, merged at
`9c26be4`.

The 77 was also inflated: `origin/agent-b`'s 20 commits are an ancestor of
`agent-b`'s 26, so they were being counted twice. Check containment before
quoting a branch count again:

    git merge-base --is-ancestor origin/agent-b agent-b

## What landed on `codex/game-planning`

| Commit | What |
|---|---|
| `4ec77a6` | `substance_objects.gd` compiles. It never has. See below. |
| `eae7914` | Thirteen files that existed only in someone's working tree |
| `8e5fd15` | `origin/codex/sol-agent-1` — 4 commits, clean |
| `fbcd51f` | `codex/sol-agent-2` — 1 commit, clean |
| `fc3615a` | `agent-a-help` — 2 commits, 2 conflicts |
| `3385e78` | `agent-b` — 26 commits, 8 conflicts, and one silent break |
| `65708e2` | `Z1.1` export presets |
| `225c848` | `P5.2` reports no longer ship inside the build (96K of them) |

Every conflict resolution was decided from the code and then **verified by
running the suites, not by reading the diff**: arm_wired 15/15,
derby_breakables 2/2, derby_budget 3/3.

### The one worth reading twice

`agent-b` merged *cleanly* into `silhouette.gd` and the result did not
compile. Its five-parameter `dress_vehicle` won the auto-merge over HEAD's
six-parameter version, and `rift_derby.gd` calls it with six. Git cannot see
a signature change as a conflict — there is no marker to resolve, the merge
reports success, and the build is broken.

**A merge is not finished when git says it is finished. It is finished when
the project compiles and the suites print something.**

## The file that was silencing the tests

`substance_objects.gd` called `_blob`, `_taper`, `_build_graft` and
`_build_cone`, none of which were ever written, plus `_build_blister` with an
argument it does not take. It has not compiled since `58c8cc2` added it.

A GDScript file that fails to parse makes **unrelated** suites print nothing,
which reads exactly like a pass. Every baseline in this repo since that commit
was measured against silence.

Both `setup/ORCA_LANES.md` and `setup/orca_worktree_setup.ps1` told an agent
to fix it by restoring the committed copy. The committed copy was the broken
one, so that advice could never have worked. Fixed in `4ec77a6`; both
documents corrected.

## The five decisions. Nothing else merges until these are answered.

Each is the same failure: **two agents built one system in two places.** Git
cannot choose, and neither should an agent. One line from you unblocks each.

### 1. `claude/b-ladder` — 15 commits — two `BodyMirror` classes
Both branches wrote `game/systems/body_mirror.gd` from nothing. HEAD's
`extends Node3D` and is built on "do not build a second body". b-ladder's
`extends SubViewport` and renders the rig live using A10's technique pointed
sideways. Same `class_name`, incompatible architectures.
**Question: which mirror is the mirror?**

### 2. `agent-c` — 11 commits — two `Sephiroth` classes
The one ORCA_LANES.md already names. Both `class_name Sephiroth extends
RefCounted`; HEAD is AR1/AV1 "the tree IS the plane ladder", agent-c is AV
"ten sephiroth plus the one not on the map, and four worlds". The lane doc
says these are *complementary*, which means the answer is probably neither
side but a union — real design work, not a merge.
**Question: are these one system or two, and if one, whose shape?**

### 3. `codex/sol-agent-1` — 8 commits — two save-slot systems
`world_history.gd` has grown `active_save_path()` / `save_path_for_slot()` /
`_active_save_slot` on one side and `_current_path()` / `active_slot_id` /
the AG5.11 slot manifest with quantum snapshots on the other. Both real, both
wired.
**Question: which one owns where a save file lives?**

### 4. `integration-check-agent-a` — 4 commits left — ANSWERED, mostly
**Resolved in practice by `9c26be4`.** The lane-4 agent's scheduled 03:45 run
refused the premise: instead of rewiring PLAY into two doors, it added DEMO as
its own door beside it, so the continue-runs screen survives and the demo
still gets in. PLAY // SURVIVING WORLDS, DEMO // THE BEST HALF HOUR, NEW GAME,
GORE SANDBOX. Merged clean, `demo_mode_test` 9/9 on the save isolation in both
directions.

**P is no longer 0 of 45. It is 7 of 45.**

What is left on the branch is `P2.3`, which touches `world_history.gd` and so
folds into decision 3. Its `.tscn` still wants "FOOLS" over "FOOLZ" and should
not get it.

### 5. `codex/controls-ui-repair` — 4 commits — a WIP tip
32 conflict hunks across 13 files for four commits, because the branch is from
13 September and trunk has moved under it. Its tip is literally `WIP:` and one
of the four is a merge commit, so cherry-picking is not clean either.
**Question: is this branch still wanted, or is it abandoned?**

## What is running

- `lane-7-merge` ran a Claude agent overnight. It stopped to ask about the
  same `contaminated_air` conflict resolved in `3385e78`, which is the rule
  working correctly. It landed nothing.
- `ATG-lane4-demo` is a Windows scheduled task for 03:45, because all four
  Codex accounts were out of quota at 02:50. Three are exhausted; the fourth
  refills Sep 19.
- Seven lane worktrees exist under `C:\Users\Greg\orca\workspaces\`, each with
  a built class cache and a `START_HERE.md`.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
