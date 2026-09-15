# Decisions

Some questions are not an agent's to answer. When two branches have each built a
real system in the same place, git cannot choose and **neither should an agent** —
picking a side silently destroys somebody's work and looks like a successful
merge.

This file is where those calls get recorded, so the next session reads the
answer instead of re-running the argument.

---

## Answered — settled, do not reopen

Asked directly and answered by Greg on **16 September 2026**.

### 1. Which `BodyMirror` is the mirror? → **HEAD's `Node3D`**

Both branches wrote `game/systems/body_mirror.gd` from nothing, under the same
`class_name`, with incompatible architectures. HEAD's `extends Node3D` and is
built on *"do not build a second body"*. `claude/b-ladder`'s `extends
SubViewport` and renders the rig live using A10's technique pointed sideways.

**Greg's call: HEAD's.** b-ladder's other 14 commits landed anyway; only the
mirror and its four test files were held to HEAD. Merged at `642e1b5`.

### 2. Are the two `Sephiroth` classes one system or two? → **moot**

`agent-c` is fully merged (0 unmerged). The question no longer blocks anything.

### 3. Which system owns where a save file lives? → **HEAD's**

`world_history.gd` grew two save-slot systems: HEAD's `active_save_path()` /
`save_path_for_slot()` / `_active_save_slot`, and `codex/sol-agent-1`'s
`_current_path()` / `active_slot_id` / the AG5.11 slot manifest with quantum
snapshots. Both real, both wired.

**Greg's call: HEAD's owns the path logic.** sol-agent-1's other commits can
land on top of HEAD's shape. This also unblocks `integration-check-agent-a`'s
`P2.3`. **Neither branch has actually been merged yet — this is now ordinary
merge work, not a blocked decision.**

### 4. `integration-check-agent-a` → resolved in practice

Settled by `9c26be4`. The lane-4 agent refused the premise: instead of rewiring
PLAY into two doors it added DEMO as its own door beside it, so the continue-runs
screen survives and the demo still gets in. PLAY // SURVIVING WORLDS, DEMO // THE
BEST HALF HOUR, NEW GAME, GORE SANDBOX. `demo_mode_test` 9/9 on save isolation
in both directions. **P stopped being 0 of 45 and became 7 of 45.**

Its `.tscn` still wants "FOOLS" over "FOOLZ" and should not get it.

### 5. Is `codex/controls-ui-repair` still wanted? → **redo it fresh on trunk**

4 commits, a literal `WIP:` tip, 32 conflict hunks across 13 files because the
branch is from 13 September and trunk has moved under it. One of the four is a
merge commit, so cherry-picking is not clean either.

**Greg's call: the branch is dead as a merge source, the work is still wanted.**
Do not merge or cherry-pick it. Re-do the controls-UI repair as a new task
against current HEAD. See `QUEUE.md`.

---

## Open — waiting on Greg. Do not act.

### Deleting `game/addons/fmod/` (`J1.3` / `X1.3`)

239MB on disk, already `.gitignore`d and untracked, referenced by **zero real
game script** — the grep hits on "fmod" in `bone_yard_hunt.gd` and friends are
the unrelated math function `fmod()`, not the SDK. Only
`game/tests/plugin_probe.gd` touches the real `FmodServer`/`FmodBank` classes,
as an installation probe.

**Asked on 16 September and deliberately deferred.** Greg was not sure what the
directory was and did not want game content deleted on a guess. It is audio
middleware, not authored content — but the call is his and he has not made it.

**Leave the directory alone.** It is untracked, so git cannot restore it; the
only undo is a re-download.

### Two small ones left by the b-ladder merge

- `_build_locked_doors()` and `_build_support_row()` in `country_town_menu.gd`
  are now **dead code** — defined, compiling, unreferenced, and pulling in
  `systems/support_mail.gd`. Wire them into the new door shape or delete them.
- `begin_full_sequence()` (HEAD) and `begin_procession()` (b-ladder) in
  `motherboard.gd` are suspiciously parallel ideas under different names. Both
  compile, both are tested, nothing is lost today — but they may want unifying.
- `const GOLD` was declared on both sides with different values. Trunk's
  `f0c85a` stands; b-ladder argued for `d9b43c`. **An art call, not a merge
  call.**

### `G7.1` — exposure at spawn

Explicitly Greg's, explicitly not an agent task.
