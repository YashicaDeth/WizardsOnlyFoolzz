# Rework queue — 31 October 2026

A queue of work for **this** version of the game (Godot 4.7.2, `Wizards Only
Fools`), taken from the shipped state rather than from ambition. Nothing here
is implemented yet except the item marked DONE.

Ground rules, unchanged: `ORCA/RULES.md` (exit code is the authority, a silent
suite has not passed, never measure in the same breath as `--import`,
`CHECKLIST.md` tick boxes are trustworthy and its prose is not). Suite names
below were checked against `game/tests/` — 568 `*_test.tscn` scenes exist. Run
any of them with:

```bash
cd P:/GameDev/AllusionsTooGrandeur && bash tools/run_tests.sh <suite> [<suite>...]
```

`tools/run_tests.sh` now kills its engine on a timeout and on abort, so a hung
suite no longer locks `game/.godot` for the rest of the run.

---

## Tier 0 — certify the escape route (do these before anything else)

The v0.1 demo is one route. It is not certified end to end, so every other
item is polish on an uncertified thing.

1. **DONE — keycard / staff door.** `first_run_lessons_test` asserted the
   two-map wording ("PIT DOOR") after `facility.gd` `V01_ONE_MAP := true`
   sealed the pit route. The game was right; the assertion was stale. Now
   branches on `V01_ONE_MAP`, same as `first_run_walk_test`. Both green.
2. **DONE — staff door → ending, in route.** `first_run_walk_test` stopped at
   "the surface is waiting for you" and `exit_reveal_test` proved the arrival
   from a synthetic handoff, so nothing joined them. `route_end_to_end_test`
   now walks the real scenes in order — vat, examiner, his card, staff door,
   arcade crawlway, fuse, heat elevator, and the live handoff the lift leaves
   into the Hunt's reveal — 22 checks. It was flaky on first writing (the
   reveal exists before it begins, so asserting on the pause raced the
   white-out); it now waits for the world to actually be held.
3. **Examiner fight integrity.** Telegraphs, parry window, desperate phase,
   keycard drop. `examiner_fight_test`.
4. **First real death goes through the vat.** `vat_rebirth_test`.
5. **Intake is readable.** The pointer and the continuation line.
   `intake_body_test`.
6. **Pad playtest, start to finish, by Greg** — then fix the five worst and
   tag `v0.1-escape`. This is the actual milestone gate and it is manual. No
   suite can close it.

## Tier 1 — rework what already exists

These are reworks, not new systems: the thing is shipped and weak.

7. **HUD top-right overload** (F-28, explicit Greg request). A capture shows
   three organ monitors, a large oscilloscope, a STEADY readout *and* a tall
   brain-spine column in one corner. Consolidate into one readable cluster.
   `hud_transience_test` + a capture.
8. **Inventory list → Souls-style grid** (the checklist item is still
   unchecked). Four slices: grid, equip weapon, equip organ/implant, route
   pickups land in it. `field_inventory_test` each slice.
9. **First-person arms** — the checklist calls them stand-ins. Rebuild or
   restyle the sleeve/glove/cleaver so they stop reading as placeholders.
   Capture gallery, look at it.
10. **Third-person combat camera** to first-person parity. Currently the
    weaker mode. `fight_sandbox_test` + capture.
11. **Recovery sigil** — a dark pulsing organ-sigil instead of the orange
    ghost. `blood_sigil_capture`, and look at the PNG.
12. **The pale capsule in the Hunt.** A capture of the live Hunt shows an
    untextured pale column standing in the playfield. Replace it with the
    intended prop or remove it. Capture before/after.
13. **Cleaver heat and staff charge as real resources** (Greg's call, still
    open). `sword_moveset_test`.
14. **Off-hand guns, 1H/2H/dual, weapon wheel** (Bloodborne approach).
    The three-weapon list exists; the wielding model does not. `fight_sandbox_test`.
15. **Combat read pass**: hitstop, stagger and riposte windows measured
    rather than felt. `blade_read_test`, `stamina_loop_test`.
16. **Bleeding and wounds on the route**, not just the lab, without taking
    control away. `blood_flow_test`, `body_cut_test`.
17. **Organ / X-ray system on route guards and the examiner** — currently
    lab-only. `baseline_human_test`.
18. **Duelist and Shade verbs in the route** — presently lab-station only.
    `combat_stance_test`.

## Tier 2 — the living world (F-36, your stated priority)

"An active world with enough ongoing activity to feel alive, before the
distinctive mechanical layers." The Hunt frame shows why this is open: ground,
boxes, and nothing happening.

19. **Inhabitants in the Hunt** — bodies that walk, work and react.
20. **Generated towns** (F-24) — inhabitants, interiors, routes.
21. **Route destruction** — one weak wall to a stash, one armoured door that
    needs a charge. Everything voxel is lab-only today.
    `destruction_fx_test`, `world_break_test`, `destruction_cost_test`.
22. **Systems combine** — cloth flag torn by bullets, liquid puts out fire,
    wet floors change footsteps. This is the item that makes the sandbox read
    as a world instead of a set of demos.
23. **Consequence:** local reactions and lasting faction standing (F-25).
    `ashbloom_holdings_test`, `rail_click_test`.

## Tier 3 — presentation, performance, shipping

24. **Sound pass** — swings, hits, liquid, glass, ambience, mixed and heard.
    Never signed off.
25. **Frame budget written down and measured** in Forward+.
    `route_frame_budget_test`, `map_perf_test`.
26. **The 60 FPS gate** (F-32/F-33) — and reconcile it with the older 144 FPS
    ambition rather than letting either silently override the other. `--perf`.
27. **The `pck` is 340 MB** (was 49 MB in September). Audit the largest
    contributors; texture compression and dead-art pruning before any
    distribution talk.
28. **`build/windows/` holds ~1 GB of `~RF*.TMP`** leftovers from Overture
    copies. Safe to delete; nothing depends on them.
29. **C# noise in every export** — `dialogue_manager` ships .NET variants that
    cannot load without a .NET toolchain. Exclude the `.cs`/`*Balloon` pairs
    from the preset so the log is readable again.
30. **Mechanics lab declutter** (`tidy-80`) — labelled bays, a teleport per
    bay, short neutral text.

## Two versions, from this one tree

Both already exist as scenes; the work is separating them cleanly and shipping
each as a deliberate build rather than one build that is everything.

- **A — ESCAPE SLICE.** `country_town_menu` → intake → vat → examiner → staff
  door → daylight → title drop. Ten to fifteen minutes. This is the version
  the Tier 0 gate certifies, and the one to put in front of someone cold.
- **B — HUNT SANDBOX.** The bone yard and the living map, no route. Where
  Tier 1 and Tier 2 land while A is being certified, and the honest answer to
  "is the world alive yet".

Keeping both buildable from one tree is cheap (a preset plus a main-scene
flag). Keeping them *coherent* is the hard part and is why A is certified
first.

## On Unreal Engine

Not doing it, and not because it is hard. This tree is roughly a hundred
thousand lines of working Godot systems — Jolt ragdolls and body cutting, the
organ/X-ray layer, LimboAI, Terrain3D, the anatomical hiring rig — plus 568
suites that currently guard them. A port does not move any of that; it
discards it and rebuilds the parts that already work, at the exact moment the
weakest part is *content*, not tech. Unreal would not fix "the Hunt is empty",
and would replace it with "the Hunt is empty and nothing compiles".

If there is a real engine question behind this, the bounded way to answer it is
a one-room, one-enemy slice in Unreal built *beside* this tree — same art, same
combat timing, same HUD — judged on feel and frame time against the Godot
build. That is a day of work and produces a decision. A full port produces a
second unfinished game.
