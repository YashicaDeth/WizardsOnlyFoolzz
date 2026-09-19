# START HERE — Lane 4

This worktree is lane 4. Read this file, then begin.
Your branch is `lane-4-demo`. Stay inside the file family below.

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

## Two rules that override every target above

1. **Never `git add -A`.** Roughly 140 `.import`/`.uid` files churn constantly,
   and two blanket adds in one day swept other agents' uncommitted work into
   unrelated commits. Stage by explicit path.

2. **`substance_objects.gd` does not compile.** It makes unrelated test suites
   print nothing, which reads exactly like a pass. A baseline measured without
   swapping in the committed version of that one file is not a baseline. The
   setup script warns about this on every new worktree.

---

# What every agent needs before touching this repo

Written 2026-09-14 after a long session on `codex/game-planning`. `AGENT_SPLIT_6.md`
still governs **who owns what**. This is the shorter, more urgent thing: **what will
waste your time or make you draw a confidently wrong conclusion.**

Read this, then your lane row in `AGENT_SPLIT_6.md`, then start.

---

## 1. Captures used to lie about the time of day. Check the hour line.

The worst trap in this repo, and it cost a whole pass.

`tests/capture_scene.gd` settles in **frames**. A heavy scene spends real seconds
on each one generating a region and compiling shaders. `WorldClock` advances at
one game-minute per real second, and `WorldHistory.world_minute` **persists
between runs**. So a 240-frame settle on the Hunt Grounds burned about 3.5 real
minutes and walked the world **3.5 hours** into dusk before taking the shot.

The Hunt Grounds came back black. It was written up as an Ashbloom lighting bug.
It was not one — the shot was taken at 19:52 with the sun at 0.35 energy. There
is **no Ashbloom lighting bug and no derby lighting bug.** Do not re-open that.

Fixed in `c27004f`: both harnesses now pin the clock to `WorldClock.OPENING_MINUTE`
and **every capture prints the hour, phase and daylight it actually shot at**.

> **Check that line on every capture.** If it does not say what you expected,
> your screenshot is of a different time of day than your conclusion.

`--hour=N` overrides it. `tests/hunt_light_test.gd` measures the mean luminance of
the frame that actually reaches the player — the only number that speaks for them.

## 2. Verify visual claims by opening the PNG. Every time.

This project has shipped several "it looks X" claims that were wrong. The rule that
works: **capture it, open it, say what is in it.** If you cannot open it, say so in
the commit rather than claiming the result — one commit here is deliberately titled
`[NOT YET SEEN RENDERED]`, and that caution was correct: the script it shipped did
not compile at all.

## 3. Built-and-never-wired is the most common bug class here

Not missing systems — *finished systems nobody connected*. Confirmed cases:

- `DamagePortrait` — a complete 3D driver bust that bloodies and sheds an arm.
  **Zero references in the project.** The DRIVER bezel drew an empty frame in every
  run ever played. Now wired (`ef5ef8e`).
- `cab_screens.gd` — **zero references anywhere.** Do not spend time restyling it;
  no player can reach it.
- The derby gun worked the whole time. The camera was at the **world origin** for
  the entire countdown, 22m from the car, so the cab, wheel, binnacle and round
  count were all behind you (`b5afadb`).

**Before improving a system, `grep` for its references.** If nothing calls it, wiring
it in is worth more than polishing it.

## 4. The combat rework is one boolean away

`game/bone_yard_hunt.gd` — `var momentum_damage := false`

The whole AN rework — *"the blow is something the player performs, not something
they request"* — is built, calibrated (flick 0.48, committed sweep 1.00) and
**switched off**. `bb1b4c0` already guarded the flip against firearms. Checklist
items **O5.1** and **O5.2** close when it flips. Combat has been reworked four
times; the fifth is a flag. Do not rebuild it — ask Greg whether to flip it.

## 5. Nothing is merged, and that is the biggest risk to the project

Across all branches: **1,670 distinct checklist items, 639 done somewhere, ~1,013
open everywhere.** But **167 items are ticked on a lane and still open on main**,
and there were **132 unmerged commits**. A quarter of the finished work exists only
on branches nobody has pulled — invisible to every other agent and to any build
made from main.

- Lane 5 (`codex/sol-agent-2`) merged clean: 14 commits, 129 tests green.
- Lane 1 (`agent-a-help`, 50 commits) **does not merge.** Main and lane 1 have each
  built a *different save-slot system* — `snapshot()`/`restore_snapshot()` versus
  `list_slots()`/`create_slot()`. That is a design decision for Greg, not a text
  conflict to force. It was aborted deliberately.

**If your lane has finished work, say so and get it merged.** Do not let it pile up.

## 6. Cross-lane collisions, measured

Only 18 files are touched by more than one branch, so the split mostly works. The
exceptions:

| File | Branches | Note |
| --- | --- | --- |
| `CHECKLIST.md` | 7 | Guaranteed conflict. Tick only your own lines. |
| `world_history.gd` | 4 | `AGENT_SPLIT_6` says **"nobody but Lane 4 adds fields."** Lanes 1, 2 and 6 are in it anyway. |
| `bone_yard_hunt.gd` | 4 | Lane 1's, 20 commits deep on their branch. |
| `handheld_device.gd` | 4 | Lane 5's. |

`codex/controls-ui-repair` appears in 9 of the 18 — it reaches into everyone's files.

**Two agents are committing to `codex/game-planning` simultaneously.** The same cold-open
fix was done twice by two agents within an hour. Before starting, `git log --oneline -15`
and check nobody just did it.

## 7. There is no font. `CellOutzType` is the house voice.

`find game -iname "*.ttf" -o -iname "*.otf"` returns **nothing**. `CellOutzType` is
procedural stroke glyphs drawn onto a CanvasItem — a `Button` **cannot** be themed to
use it. `systems/menu_plate.gd` solves this: the control keeps hit-testing, focus and
signals, its font is made transparent, and the plate draws over it in house type.

It is a **caps** alphabet with no arrows and **no wrapping**. Mixed case reads as
missing glyphs. `living_map.gd` has a `_wrap_condensed` helper if you need wrapping —
`broken_web.gd` (11 calls that depend on wrap widths) needs it before it can be touched.

Still on the engine fallback font: `downed_resolution` (22), `world_index` (12),
`character_archive` (8), `body_inspector` (5), `gothic_field_hud` (4).

## 8. House rules that keep being broken

1. **Your own worktree.** Working directly in `P:\GameDev\AllusionsTooGrandeur`
   has broken the build three times.
2. **Never `git add -A`.** Every tree shows 120-143 dirty `.import` files that Godot
   rewrites on open. A blanket add sweeps them plus whatever another agent left in
   flight. **Stage by path, always.**
3. **Never claim a visual result you have not looked at.** See §2.
4. `draw_string` takes a **baseline**; `CellOutzType` takes a **top-left**. Lift by
   the cap height or every converted line lands low.
5. GDScript cannot infer a type from `event.pressed` off a base `InputEvent`. Use
   `var x: bool = ...` and cast, or the whole file silently fails to compile.

## 9. `addons/limboai/` is gitignored and a fresh worktree does not have it

`rival_tactics.gd` hard-`preload()`s the LimboAI GDExtension, and
`bone_yard_hunt.gd` hard-`preload()`s `rival_tactics.gd` — so a worktree
missing the addon fails to compile the Hunt scene, the core of the demo, while
tests that do not happen to instantiate it still print `PASS`. It cost real
time here: `loop_smoke_test` reported `failures=0` with `bone_yard_hunt.gd`
silently failing to load underneath it.

`game/addons/limboai/` is in `.gitignore` (a ~150MB compiled binary), so
`git worktree add` never brings it along. Same story for `game/addons/terrain_3d/`
(~100MB, listed in `project.godot`'s `enabled` plugins, spams a plugin-load
warning without it — does not break compilation, nothing preloads it).
`setup/orca_worktree_setup.ps1` now copies both from
`P:\GameDev\AllusionsTooGrandeur\game\addons\` on every new worktree. If a
worktree predates this fix, copy them by hand and rebuild the class cache
(`--headless --path game --import`) before trusting any suite that touches
the Hunt.

## Blocked on Greg — do not guess these

1. The four **Horsemen's names** (blocks K2).
2. **Cast display names** (blocks I0.9).
3. **celloutz.xyz**: mirror the real site or fictionalise it (blocks I3).
4. **What persists between runs** — and now also *which save system wins*, given
   main and lane 1 built two.
5. **AC1.1**: simulated fluid, or painted fluid done well.
6. Is the **Board** a physical wall, or on the black mirror.
7. The **Instagram and forum URLs** for the celloutz site.
8. Whether to flip **`momentum_damage`** (§4).
