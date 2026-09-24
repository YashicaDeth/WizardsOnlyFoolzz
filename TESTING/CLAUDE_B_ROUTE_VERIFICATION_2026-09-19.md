# Claude B — Route Verification Report (first 30 minutes)

Prepared 19 September 2026, read-only pass, against `codex/game-planning` at
`e8bfc80` in worktree `strike-claude-playtest` (branch
`YashicaDeth/strike-claude-playtest`). No source files were changed to produce
this report.

## Status of the four Codex commits (checked first, per the task's read-only gate)

Per `ORCA/DEMO_30_MIN_RESET_QUEUE.md`, tonight's four implementation seats are
branches `YashicaDeth/strike-opening`, `YashicaDeth/strike-combat`,
`YashicaDeth/strike-controls`, `YashicaDeth/strike-performance`. Checked with
`git rev-list --count codex/game-planning..<branch>` for all four: **all four
return 0** — none has landed a commit yet. This report therefore documents the
*pre-strike* route as it exists on trunk right now, so the two Claude lanes and
Greg have a shared baseline to diff the four lanes' work against once they land.
Re-run the same `rev-list` check before trusting this report as "current."

## Exact commands

**Run windowed, second monitor, at the resolution the demo capture assumes:**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --path game --resolution 1280x720 --position 2240,320
```

**Any headless test** (`ATG_TEST_MODE=1` is mandatory or the scene quits with
exit code 2 and prints nothing):
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/<name>.tscn
```

**Gameplay capture harness** (writes PNGs, not a video; see caveat below):
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/gameplay_demo.tscn -- --out=P:/GameDev/Temp/demo
```
`game/tests/gameplay_demo.gd:9` defaults `out_dir` to `P:/GameDev/Temp/demo`
already; the `--out=` argument only matters if you want a different folder.
**This harness instantiates `bone_yard_hunt.tscn` and `rift_derby.tscn`
directly — it does not exercise the boot splash, menu, vat, or colosseum, so
it is a combat/HUD capture tool, not a full-route capture tool.** No section
of the repo currently captures the vat→colosseum→bone_yard handoff end to end;
see "Integration seams" below.

**Perf overlay / dump — confirm before quoting `COMMANDS.md`:** the overlay is
an autoload (`PerfProbe`, `project.godot:28`), and its own doc comment
(`game/systems/perf_probe.gd:15`) says **F10** toggles it and **F11** writes
`perf_dump.txt` beside the executable. `COMMANDS.md:76` says F3/F4. That is
stale — F3 and F4 are live keybinds inside `bone_yard_hunt.gd`
(`jump_to_mode(2)` / `jump_to_mode(3)` on the handheld, lines 1502-1503), so if
anyone actually rebinds the overlay to F3/F4 it will silently steal from the
handheld instead of erroring. Use F10/F11; flag the doc.

**Class cache rebuild after any lane adds a `class_name`:**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game --import
```

**Diagnostics gate (fails on new project-owned parse warnings/errors):**
```
./tools/verify-godot-diagnostics.ps1 -Godot P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
```

## Minute-by-minute 0–30 route, as trunk actually runs it today

Traced from `run/main_scene` in `project.godot` through each scene's own
transition calls — not from CHECKLIST.md prose.

| Time | Scene / system | What happens | Player input |
|---|---|---|---|
| 0:00–0:20 | `boot_splash.tscn` (`boot_splash.gd`) | Three-stage brand slate (CELLOUTZ → GRANDEUR → the WOF mark), ~13.7s if uninterrupted | any key/click/button skips immediately (`_unhandled_input`, line 363) |
| 0:20–0:40 | `country_town_menu.tscn` | Front door / menu. **NEW GAME** opens a Quantum branch picker (save-slot chooser); **PLAY** resumes the active branch; **DEMO** starts `WorldHistory.begin_demo()` then the same `_start_game()` PLAY uses | mouse |
| 0:40–1:00 | `_start_game()` (`country_town_menu.gd:540`) routes by `OpeningDirector.resume_destination()`. A fresh run has reached none of `won_derby`/`entered_pit`, so it plays `DecantingPrologue` first, then travels to `vat_chamber.tscn` | none (prologue) |
| 1:00–~2:30 | `vat_chamber.tscn` — intake form (`VatIntake` / `vat_intake.gd`): character creation ("the mirror" preview, page-based sheet) plays out while the handler narrates. `filed` signal fires on submit | mouse/keys per the form |
| ~2:30–2:40 | Vat sequence starts on `filed`: `WorldHistory` records `opening_woke`, `OpeningDirector.advance("woke")`. Phase machine begins: `submerged` (3.2s, no input) → `voiding` (2.4s, no input, tank drains) → `_breach()` (glass/fluid removed, 22 shard particles, puddle) → `floor` phase (3.2s, camera rights itself, still no movement) | none |
| ~2:40–3:00+ | `aisle` phase: `can_move = true`, WASD + mouse-look live, `_player_speed_scale` scaled by a fresh body's `mobility_ratio()` (speed 2.7 baseline). Walk `AISLE_LENGTH = 22.0` units past dead-tank dressing to the pit door | WASD, mouse |
| door | `_interact()` (E, within 3.4 units of `door_marker`) | Records `opening_entered_pit`, amends player status, then `Interstitial.travel("res://underground_colosseum.tscn", ...)` | E |
| — | `underground_colosseum.tscn` | **Shares `rift_derby.gd` as its script** (`underground_colosseum.tscn:3,27`) with `is_colosseum` distinguishing behavior — e.g. exit text/lockdown flavor differs, but it is the same derby/heat system, not a separate implementation. Winning calls `OPENING.advance("won_derby")` (`rift_derby.gd:1918`) | derby controls (not inspected in this pass — owned by neither tonight's Lane 1 nor Lane 2; see seams below) |
| on win | `resume_destination()` now returns `bone_yard_hunt.tscn`, captioned "walking out into the ashbloom expanse" | — |
| entering `bone_yard_hunt.tscn` | Open-world Hunt Grounds. Contextual HUD strip + `KeysCard` (F1, closed-state hint fades after 2 opens). First combat lesson: `C` starts a clinch/grapple (`_start_grapple`, line 1524; hold check at line 6157 accepts either LMB or `KEY_C`); `V`/`X` persuade/threaten a held target; Space releases. Third person (`F`) is **locked** until `third_person_unlocked()` returns true — i.e. until `melee_body_hit` or `firearm_anatomy_hit` has fired at least once (line 6435) — and presents `third_person_refusal()` text if pressed early | C, V/X, F, WASD, mouse, Tab (handheld), M/T/P (map/tree/board panels) |
| — | Panels: `M` map, `T` tree, `P` board, `Tab`/`G` handheld. `KeysCard` (F1) shows contextual bindings only after the player asks; `GothicFieldHud` (`gothic_field_hud.gd`) carries vitals, wound regions, a transient location banner (4s) | as above |
| rest of the 30 minutes | Not scene-gated further on trunk — the Hunt Grounds is open exploration/combat from here. `DEMO` mode reaches an authored stop (`demo_wall`) after the first Hunt win beat (`_rival_retreats` → `hunt_arc_first_beat_complete` + `demo_ending_reached` events, verified by `demo_route_test.gd`); `PLAY` mode has no such wall | open |

**Read this table as "what trunk does," not "what a player should feel."**
Whether 22 aisle units, three locked phases, and a shared derby/colosseum
script produce a good ten minutes is Lane 1's and Greg's call, not this
report's.

## Progression blockers and likely integration seams

1. **No lane owns `rift_derby.gd` tonight**, but the route runs through it
   twice (`underground_colosseum.tscn` and, later, the real `rift_derby.tscn`
   if the player returns to it). `ORCA/OWNERSHIP.md` puts it under the
   standing Lane 2 ("the breakable world"), not tonight's strike Lane 2
   ("combat and perspective," `bone_yard_hunt.gd` only). If the colosseum
   stage breaks post-integration, no strike lane is responsible for it by
   scope — flag this to the integration gate explicitly.
2. **No capture or test currently exercises the full vat → colosseum →
   bone_yard handoff.** `gameplay_demo.gd` starts mid-route by instantiating
   `bone_yard_hunt.tscn` directly; `demo_route_test.gd` also starts from
   `bone_yard_hunt.tscn`. The only coverage of the opening scenes is whatever
   Lane 1 adds. Gate 5 (integration) is the first point anything will walk
   the seams between vat, colosseum and Hunt Grounds together.
3. **`COMMANDS.md`'s perf-capture keys are stale** (documents F3/F4, code
   uses F10/F11 and F3/F4 are already claimed by the handheld inside
   `bone_yard_hunt.gd`). Low risk today since nothing currently binds the
   overlay to F3/F4, but it will actively mislead anyone following the doc
   verbatim, and a careless rebind would silently break handheld mode-jump
   instead of raising a conflict.
4. **Third-person unlock is earned by combat, not traversal** — `F` refuses
   until `melee_body_hit` or `firearm_anatomy_hit` fires once. Lane 2's brief
   in `ORCA/DEMO_30_MIN_RESET_QUEUE.md` says "perspective switching works
   after the existing unlock" — confirmed as designed, not a bug, but worth
   restating since it means the first-combat playtest checklist below cannot
   verify `F` before verifying `C`.
5. **All four strike lanes are still at zero commits** as of this report;
   nothing here reflects tonight's actual changes yet. Re-verify the whole
   table above once they land, since Lane 1 owns exactly the files this
   report spent the most time in (`vat_chamber.gd/.tscn`,
   `systems/vat_intake.gd`, `systems/opening_director.gd`).

## Objective pass/fail checks

Run each with the headless command above. A suite that prints nothing has not
passed (house rule, `ORCA/QUEUE.md:173`).

| Check | Command target | What "pass" means |
|---|---|---|
| Demo/Play save isolation | `res://tests/demo_mode_test.tscn` | DEMO and PLAY never leak history into each other; both load/resume correctly |
| Demo ends at the authored wall | `res://tests/demo_route_test.tscn` | First Hunt win records `hunt_arc_first_beat_complete` + `demo_ending_reached` exactly once, wall shows, tree pauses, and resuming an ended demo keeps it paused |
| Demo route/launch timing | `res://tests/demo_launch_timing_test.tscn`, `res://tests/demo_border_test.tscn`, `res://tests/demo_wall_test.tscn` | Route timing and the demo border/wall render without the old stall |
| Keys card | `res://tests/keys_card_test.tscn` | Card opens/closes, pages correctly, hint fades after 2 opens |
| Grapple / clinch | `res://tests/grapple_test.tscn`, `grapple_playability_test.tscn`, `grapple_zone_test.tscn`, `grapple_mass_test.tscn` | `C` (or LMB) acquires, hold math and release are stable, no frozen velocity/collision exceptions |
| Third-person unlock + HUD | `res://tests/third_person_dodge_test.tscn`, `res://tests/hud_transience_test.tscn`, `res://tests/hud_settings_test.tscn` | Perspective toggles only after unlock; HUD panels never permanently obscure objective/interaction prompts |
| Movement/traversal | `res://tests/anatomy_traversal_test.tscn`, `res://tests/momentum_carry_test.tscn`, `res://tests/wall_run_test.tscn` | Injury gates (`mobility_ratio() < PLAYER_INJURY_FLOOR = 0.55`) apply consistently across vault/wall-run and (once Lane 1 adds it) crouch/slide |
| Frame budget | `res://tests/frame_profile.tscn`, `res://tests/map_perf_test.tscn`, `res://tests/sandbox_perf_test.tscn` | ms/frame, draw calls, node counts printed; compare against Lane 4's before/after |
| Perf overlay itself | `res://tests/perf_probe_test.tscn` | Confirms F10/F11 behavior in isolation |
| Editor diagnostics | `tools/verify-godot-diagnostics.ps1` | No new project-owned parse warning/error |

No test in this list currently proves the vat→colosseum→bone_yard handoff
itself (see seam #2) — that gap is Gate 5's, not a single lane's, to close.

## Four feedback gates for Greg

Concise, single-question checkpoints — meant to be asked once each lane's
work is actually playable, not asked blind against trunk today.

1. **The aisle (vat exit).** After decanting, does the walk to the pit door
   feel like the right length now, or still too long/short? (Comment already
   on file at `vat_chamber.gd:23-26`: it was cut from 34.0 to 22.0 units
   specifically against a "too long" complaint — confirm the cut landed.)
2. **The colosseum handoff.** Does entering `underground_colosseum.tscn`
   read as a distinct beat ("racked for the tunnel heat"), or does it feel
   like the same derby scene reappearing under a new name?
3. **The combat lesson.** Is `C` (clinch) discoverable as the first combat
   verb without the keys card, and does third person unlocking *after* first
   contact read as earned or as a withheld feature?
4. **The thirty-minute shape.** Once all four lanes land, does the full
   splash→menu→vat→colosseum→Hunt route feel like "about thirty minutes and
   not truncated" (`CHECKLIST.md` P10.8), or does it stall somewhere this
   report didn't catch?

## Correction-task template

Forwards Greg's own words verbatim into a scoped task. No interpretation is
added at capture time — only at dispatch, and only by whoever files it.

```
CORRECTION TASK — <one-line pointer to the moment, not a diagnosis>

GREG SAID (verbatim, unedited):
"<exact quote, nothing paraphrased>"

WHEN / WHERE: <scene, timestamp in a capture if one exists, or route step from
the table above>

WHAT WAS OBSERVED (mechanical facts only — what happened on screen, what key
was pressed, what the code did): <no adjectives, no "should," no fix idea>

NOT YET DECIDED: <name the open question rather than answering it, e.g. "is
this the aisle length, the camera lock duration, or both?">

OWNER: <lane / file(s) per ORCA/OWNERSHIP.md — stop and ask before crossing a
boundary>

DONE MEANS: <a re-run of Greg's own words is no longer true, verified by
playthrough or capture — not by a headless test alone if the complaint was
about feel>
```

## Honest unknowns (this pass did not check)

- Did not launch the editor or a windowed build — every route claim above is
  from static reading of `.gd`/`.tscn` files and doc comments, not a live
  playthrough. No capture was taken in this pass, per the task's instruction
  not to run expensive captures before integration.
- Did not read `rift_derby.gd`/`underground_colosseum.tscn` in depth (only
  enough to confirm the shared-script fact and the `won_derby` trigger) —
  Lane 2's standing ownership, not tonight's strike scope.
- Did not verify controller/gamepad bindings, only keyboard.
- Did not check whether `P:/GameDev/build/windows/WizardsOnlyFools.exe` (the
  exported build referenced in `COMMANDS.md`) is current against trunk.
- Four strike branches are at zero commits as of this report — everything
  above is the pre-strike baseline, explicitly not a verification of any
  lane's actual work.
