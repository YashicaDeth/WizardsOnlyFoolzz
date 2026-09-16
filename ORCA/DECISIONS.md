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
in both directions. **P stopped being 0 of 45.** It was 7 of 45 when that
landed; it measured **23 of 45** on 16 September.

Its `.tscn` still wants "FOOLS" over "FOOLZ" and should not get it.

### 5. Is `codex/controls-ui-repair` still wanted? → **redo it fresh on trunk**

4 commits, a literal `WIP:` tip, 32 conflict hunks across 13 files because the
branch is from 13 September and trunk has moved under it. One of the four is a
merge commit, so cherry-picking is not clean either.

**Greg's call: the branch is dead as a merge source, the work is still wanted.**
Do not merge or cherry-pick it. Re-do the controls-UI repair as a new task
against current HEAD. See `QUEUE.md`.

---

## Answered, second round — 16 September, afternoon

### The three that change how everything is scheduled

**1. The eight zero sections get lanes.** S, H, AW, AP, AO, AM, AK, AA — 234
items, 23% of all open work, and no lane owned any of them. Greg: *"they 100%
matter to me."* They are not deprioritised, they were simply never assigned.
Every one gets a real owner in `OWNERSHIP.md`.

**2. Destructible surfaces WILL be built** — `A10.11` and everything downstream
of it. Greg: *"build it once its possible and you have made all the synergising
building blocks."* So this is approved but **sequenced**: build its prerequisites
first, then it. It is not a free-standing task and must not be started as one.

**3. THE DESCENT IS NO LONGER ALPHABETICAL.** This supersedes the earlier
A -> B -> C -> D instruction. Greg, verbatim:

> *"screw the alphabetical, do it most efficiently most logical, work on
> everything in order of it working in conjunction with every other feature
> instead of binding you to work on mechanics that need 10 other edits on things
> down the line"*

Work is ordered by DEPENDENCY, not by letter. Free wins first (items whose
blocker now exists), then foundations ranked by how much each unblocks, then
leaf clusters grouped by file family. Alphabetical order is arbitrary and forces
work on mechanics that need ten other things first.

### The small ones

| # | Question | Greg's call |
|---|---|---|
| `J1.3`/`X1.3` | Delete `game/addons/fmod/`? | **Deleted.** 239MB reclaimed, 16 Sep. It was untracked, gitignored, and referenced by exactly one line — `game/tests/plugin_probe.gd:9`, a `ClassDB.class_exists()` probe that only *reports* whether it is installed. Greg's reasoning: it is middleware you would reinstall fresh, not resurrect from a stale copy. |
| `const GOLD` | Trunk's `f0c85a` or b-ladder's `d9b43c`? | **b-ladder's `d9b43c`**, the deeper tone. Its rationale stands: the seal arrives in copper and leaves in gold, and that is how you read that it went *in*. |
| menu doors | Wire `_build_locked_doors()`/`_build_support_row()` in, or delete? | **Wire them in** to the new door shape. Greg wants the feature; they are not dead weight. |
| motherboard | Unify `begin_full_sequence()` and `begin_procession()`? | **Unify them.** Two parallel ideas under different names. |
| rescued files | Are `night_vision.gd` and `black_mirror_camera.gd` + the HUD settings suite wanted? | **Wanted.** Land them on trunk rather than leaving them on their rescue branches. |

## Open — waiting on Greg. Do not act.

### `G7.1` — is the spawn meant to be this dark?

Greg has said he does not understand this one yet, so it stays open until he
does. It is **purely an art call and nothing is broken**, which is the part that
was never made clear to him:

`G7.2` already fixed the *readability* half and is closed. The ground was going
solid black — `"dirt"` is a 0.03-0.09 albedo material at 0.97 roughness, and a
flat plane facing away from a low sun with a dark zenith has nothing to reflect.
It got the same rim trick `"flesh"` already uses, so grazing angles now pick up
the horizon glow and the near field reads as a lit surface with a gradient
instead of a hole. **Global exposure and ambient were deliberately left
untouched, so nothing else in frame changed.**

So the only question left is taste: **is spawning into near-darkness the
intended mood, or should the whole scene be brighter?** Nothing is blocked
either way. Raising exposure would change every other thing in frame, which is
why it was not done on an agent's initiative.

### Superseded — kept for the record

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
