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

**Target:** 43 commits unmerged across 5 branches -> 0

**Read this one twice before deciding it is a waste of an account.** The
number was 99 on 14 September and it was wrong twice over. An overnight pass
on 15 September took it to **43 across 5 branches** -- and of the original
count, `origin/agent-b`'s 20 commits were an ancestor of `agent-b`'s 26 and
were being counted twice. Check containment before quoting a figure:
`git merge-base --is-ancestor origin/agent-b agent-b`.

What is left is not a merging job. Every one of the five remaining branches is
blocked on the same thing: two agents built one system in two places, under one
class name, and git cannot choose between them. `MERGE_STATUS.md` states the
five questions; each needs one line from Greg, and none of them should be
answered by an agent picking a side.

This lane merges one branch at a time, runs the test suites after each, and
stops to ask when two branches disagree about a file rather than picking a side.
It is also the only lane that should ever resolve a conflict.

---

## Three rules that override every target above

1. **Never `git add -A`.** Roughly 140 `.import`/`.uid` files churn constantly,
   and two blanket adds in one day swept other agents' uncommitted work into
   unrelated commits. Stage by explicit path.

2. **`substance_objects.gd` compiled for the first time on 15 September**
   (`4ec77a6`). Before that it had never parsed, and a GDScript file that fails
   to parse makes *unrelated* test suites print nothing at all, which reads
   exactly like a pass. Every baseline taken in this repo before that commit
   was measured against silence.

   The advice that used to be here -- restore the committed copy -- could never
   have worked, because the committed copy was the broken one. If a suite
   prints nothing, do not assume it passed: run `--check-only` over the scripts
   it touches, and remember that `--check-only` does not register autoloads, so
   "Identifier not found: WorldHistory" from it is an artifact and not a break.

3. **A merge is not finished when git says it is finished.** `agent-b` merged
   `silhouette.gd` with no conflict at all and the result did not compile: its
   five-parameter `dress_vehicle` beat HEAD's six-parameter one, and the caller
   passes six. Git cannot see a signature change. Build and run the suites
   after every merge, before committing it.
