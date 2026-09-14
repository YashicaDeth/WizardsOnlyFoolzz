# Orca lanes — seven agents, seven file families

Paste one lane block into each Orca workspace as its opening prompt, after the
shared brief in `AGENT_BRIEF_CURRENT.md`.

**The ownership table is the important part, not the target list.** Every
agent-on-agent problem in this project so far has been two writers in one file,
never two agents running out of work. Orca gives each task its own git worktree,
which stops two agents editing the same file at the same instant — it does *not*
stop two agents building the same system in two different places. That is what
happened with `sephiroth.gd`, where two complementary systems ended up under one
class name and one would have silently destroyed the other on merge. Only the
table below prevents that.

Percentages are measured off `CHECKLIST.md`, not estimated.

---

## Lane 1 — The body and what happens to it

**Owns:** `baseline_human.gd`, `anatomy_component.gd`, `wound_marks.gd`,
`blood_flow.gd`, `penetration.gd`, `body_mesh.gd`, `gore_chunks.gd`,
`body_mirror.gd`, `carrion_scavenger.gd`, `bone_yard_hunt.gd`, `gore_demo.gd`

**Target:** B 94% -> 100%, AN 70.3% -> 90%, O 61.4% -> 80%

Five items left in B and four of them are blocked on the quantum restart, which
does not exist anywhere in the codebase — do not build it to close them. AN's
`AN6.x` (a wound as an opening with depth you can see into, organs falling out
through it) is the real work and it builds directly on `penetration.gd`.

---

## Lane 2 — The breakable world and the frame budget

**Owns:** `silhouette.gd`, `ashbloom_world_generator.gd`, `world_look.gd`,
`arcade_vehicle.gd`, `rift_derby.gd`, `derby_ai_driver.gd`, prop and building
files, `shaders/`

**Target:** AB 2.6% -> 40%, X 0% -> 50%

Already in progress (commit `a5c90e3`: six breakable derby barricades). X is the
one with a live unsolved bug — a reported 13 FPS and a sandbox crash that could
not be reproduced from source across 600 rounds fired and 240 mixed inputs. The
tooling is already committed: F3 in-game overlay, F4 writes `perf_dump.txt` next
to the exe, and three benchmarks in `game/tests/`. **Never open a body file.**

---

## Lane 3 — Guns

**Owns:** `ballistics.gd`, `hunter_arsenal.gd`, `held_gear.gd`,
`launcher_actor.gd`, weapon models

**Target:** AF 25.9% -> 65%

The biggest single win available. `penetration.gd` just landed and reads the
`penetration` figure that `CALIBRES` has carried since it was written and that
nothing ever consumed — so AF10.1 (travel, drop, no tunnelling), AF10.3
(casings), AF10.4/10.5 (physical magazines), AF10.12 (jams and wear) are all
buildable now against a model that exists. Coordinate with Lane 1 before
touching `ballistics.gd`: it is listed in both and Lane 1 only reads it.

---

## Lane 4 — The demo

**Owns:** `P`-section scenes, the opening sequence, objective and pacing scripts

**Target:** P 0% -> 40%

**This is the most important lane and the least glamorous.** P is 0 of 45 — the
demo, what a player does in the first ten minutes and why they keep going. Every
other section is a system; this is the only one that is the game. Greg's own
words: *"there needs to be a point of the game because right now it just seems
really sandboxy."* The measurements agree with him exactly.

---

## Lane 5 — Getting in

**Owns:** `country_town_menu.gd`, `boot_splash.gd`, settings and input files,
`pause_gate.gd`, `celloutz_type.gd`, `crt_glass.gd`, `regal_frame.gd`

**Target:** Y 0% -> 60%, AM 0% -> 30%, I 50.8% -> 65%

Y is rebindable controls and a settings screen that does something — 0 of 20,
and it is the first thing anyone handed a build will touch. Thirteen screens are
still set in the engine's fallback font; `CellOutzType` now has wrapping,
alignment and clipping so converting them is mechanical rather than a layout
hazard.

---

## Lane 6 — The handheld and the brain

**Owns:** `handheld_device.gd`, `world_index.gd`, `brain_index.gd`,
`black_mirror.gd`, `wire_net.gd`

**Target:** C 66.7% -> 85%, AT 17.2% -> 50%

---

## Lane 7 — Merging

**Owns:** nothing. Writes no features.

**Target:** 99 commits unmerged across 9 branches -> 0

**Read this one twice before deciding it is a waste of an account.** There are
**99** finished commits sitting on `agent-b` (26), `origin/agent-b` (20),
`claude/b-ladder` (15), `codex/sol-agent-1` (12), `agent-c` (11) and four
others — and that number went *up* by 23 over the course of one day's work. That work is already
done and is invisible to everyone. Six more agents writing into that makes the
number grow, not shrink — authoring has never been the bottleneck here.

This lane merges one branch at a time, runs the test suites after each, and
stops to ask when two branches disagree about a file rather than picking a side.
It is also the only lane that should ever resolve a conflict.

---

## Two rules that override every target above

1. **Never `git add -A`.** Roughly 140 `.import`/`.uid` files churn constantly,
   and two blanket adds in one day swept other agents' uncommitted work into
   unrelated commits. Stage by explicit path.

2. **`substance_objects.gd` does not compile.** It makes unrelated test suites
   print nothing, which reads exactly like a pass. A baseline measured without
   swapping in the committed version of that one file is not a baseline. The
   setup script warns about this on every new worktree.
