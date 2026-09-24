# Morning brief — 15 September 2026

One bounded task per lane, picked from `MERGE_STATUS.md` (overnight) and
`AGENT_BRIEF_CURRENT.md`, verified against current code rather than trusting
either doc — both are already stale in places (`momentum_damage` is already
`true`, O5.1/O5.2 already closed; the font-fallback counts in
`AGENT_BRIEF_CURRENT.md` no longer match `gothic_field_hud.gd`, which is now
fully converted).

**Re-verified 2026-09-15, second pass, against HEAD `c240fe1`** (the
lane-4-demo merge landed after this doc's first draft): three of the four
lane briefs below checked out as written. The fourth — body/combat's AD10.7 —
did not: `CHECKLIST.md`'s own note ("no crouch or slide verb") is itself
stale, same pattern as `[[checklist-truth-lives-in-lane-worktrees]]`. Crouch
already exists in `bone_yard_hunt.gd` (since `8b2bdb5`); only slide, the
speed-scale unification, and the injury gate are actually missing. That
section below has been corrected in place. The world/performance test command
was also wrong (pointed at a non-existent `.tscn`) and has been fixed to
`plugin_probe.tscn`.

This is a **planning pass, not a dispatch** — four briefs below, not four
agents started. Each is scoped to one owner's files, so they don't collide if
picked up separately. Own worktree, stage by path, never `git add -A` — house
rules from `AGENT_SPLIT_6.md` still apply to whoever picks these up.

---

## Lane: body/combat

**Task — AD10.7: crouching, sprinting and sliding as one continuous system**

Checklist: `AD10.7` (open, `CHECKLIST.md`) — but its own note ("no crouch or
slide verb to be continuous with") is **stale**, same failure mode as
[[checklist-truth-lives-in-lane-worktrees]]. Re-verified directly against
`bone_yard_hunt.gd` at current HEAD (`c240fe1`), not the checklist prose:
- `crouching` already exists and has since `8b2bdb5` ("Make the map a map, and
  third person a fight") — a real `bool` (`bone_yard_hunt.gd:320`), driven by
  `Input.is_action_pressed("crouch")` (`:1444`), with its own hard-coded speed
  (`3.4`, `:1467`) and capsule-height lerp (`:1481`), and it's already threaded
  into `hunter_body_motion.update()` (`:1538`).
- **What's actually missing:** (1) crouch's speed is a hard-coded `3.4`
  sitting *beside* `_player_speed_scale()` (`:991`, the leg-injury multiplier
  Sprint/PLAYER_SPEED already run through at `:1477`) rather than unified with
  it — two parallel speed rules, not one system; (2) there is no `slide` verb
  at all — grep for `\bslide\b` across `game/` matches only comments; (3)
  crouch has no `mobility_ratio()` gate the way vault/wall-run do (compare
  `:2540`, `:2625`, `:2688` — all `if player_rig.anatomy.mobility_ratio() <
  PLAYER_INJURY_FLOOR: return`) — a broken leg still lets you crouch fine today.

So this is **not** a from-scratch build — scope is: fold crouch's speed into
the shared scale path, add the slide verb, and add the missing injury gate.

**Files it owns**
- `game/bone_yard_hunt.gd` — crouch speed unification, new slide verb, injury gate
- `game/hunter_motor.gd`, `game/hunter_body_motion.gd` — collision height /
  movement physics, only if the slide verb needs to touch them

**Success criteria**
- Crouch's speed comes from the same `_player_speed_scale()` path sprint/walk
  already use, not a second hard-coded branch — one system, not two
- A slide verb exists: short forward impulse gated by momentum, decays over time
- Both crouch and slide check `mobility_ratio() < PLAYER_INJURY_FLOOR` and
  refuse, the same pattern already used at `:2540`/`:2625`/`:2688` for
  vault/wall-run
- New test suite `game/tests/crouch_slide_test.gd` (+ `.tscn`), sibling to
  `momentum_carry_test.gd`; existing `wall_run_test.gd`,
  `momentum_carry_test.gd`, `anatomy_traversal_test.gd` re-verified clean
- Tick `AD10.7` in `CHECKLIST.md` with the verification numbers, in your own
  commit — and correct its note, since the current text ("no crouch or slide
  verb") will be wrong on both counts once this lands

**Test command**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/crouch_slide_test.tscn
```
(then re-run `wall_run_test.tscn`, `momentum_carry_test.tscn`,
`anatomy_traversal_test.tscn` the same way)

---

## Lane: world/performance

**Task — J1.3 / X1.3: remove the FMOD plugin outright**

Checklist: `J1.3` and `X1.3` (paired, both open). Verified directly, not from
the doc's claim: `game/addons/fmod/` is **239MB on disk, already
`.gitignore`d (line 3, untracked), and referenced by zero real game script** —
the earlier grep hits on "fmod" in `bone_yard_hunt.gd` etc. are the unrelated
math function `fmod()`, not the SDK. Only `game/tests/plugin_probe.gd`
references the real `FmodServer`/`FmodBank` classes, as an installation probe.
`J1.1` already disabled the extension; `J5.1` already added an empty
`game/addons/fmod/.gdignore` to stop the 14 tool scripts re-parsing locally —
but that fix is local-only per J5.1's own note, since the addon itself never
travels through git either way.

**Files it owns**
- `game/addons/fmod/` — delete the directory (disk only; it is not tracked)
- `ROADMAP.md` — already documents the drop per J1.2; confirm no stale
  reference needs updating once the directory is gone

**Success criteria**
- `game/addons/fmod/` no longer exists on disk (239MB reclaimed)
- Godot opens the project headless with no missing-extension / missing-class
  errors (confirms nothing outside `plugin_probe.gd` needed it)
- `plugin_probe.gd` (`game/tests/plugin_probe.gd` + `.tscn`) updated to expect
  FMOD **absent**, since it just prints
  `ClassDB.class_exists("FmodServer") or ...("FMODStudioModule")` today rather
  than asserting — correction to the original brief: `game/tests/tooling/
  plugin_installation_test.gd` is a GdUnit suite with **no FMOD reference at
  all** (Blackboard/Terrain3D/dialogue/scatter only) and has no `.tscn`, so
  it's not part of this lane's test surface — don't chase it
- Full headless suite run shows no new failures and the 46 parse-error debugger
  entries from FMOD's tool scripts (`J5.1`) are gone, not just suppressed
- Tick `J1.3` and `X1.3` in `CHECKLIST.md`, noting the plugin was untracked so
  there is no git diff for the deletion itself — only for the checklist and
  any probe-test update

**Test command**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/plugin_probe.tscn
```
(then a full-suite pass per `COMMANDS.md`'s test runner to confirm nothing else broke)

---

## Lane: UI

**Task — A1.7 family: bring `character_archive.gd` onto `CellOutzType`**

Checklist: covered by the `A1.7` glyph-coverage rule and the "no `Button`/
default-font screen" standard `menu_plate.gd` and `celloutz_type.gd` establish
project-wide. Verified directly: `character_archive.gd` has **zero**
`CellOutzType` references and **22** raw `draw_string()` calls — it is
entirely on the engine fallback font. (`gothic_field_hud.gd`, listed as
outstanding in `AGENT_BRIEF_CURRENT.md`, is actually already fully converted —
12 `CellOutzType` refs, 0 `draw_string`; that doc is stale on this point, don't
redo it.)

**Files it owns**
- `game/systems/character_archive.gd` — convert its 22 `draw_string()` call
  sites to `CellOutzType`, following the pattern already proven in
  `game/systems/body_inspector.gd` and `game/systems/world_index.gd`

**Success criteria**
- Every `draw_string()` call in `character_archive.gd` is replaced with the
  `CellOutzType` equivalent, remembering house rule 4: `draw_string` takes a
  baseline, `CellOutzType` takes top-left — lift by cap height or the
  converted lines land low
- `game/tests/type_layout_test.gd` still passes (it already lists
  `character_archive.gd` in its `SCREENS` glyph-coverage set — every character
  the file draws must still be settable in the face)
- A windowed capture of the dossier screen taken and **opened**, not claimed —
  confirms house type renders instead of the fallback font, per house rule 2
- Tick the relevant `CHECKLIST.md` line(s) referencing this file's font state,
  if any exist beyond `A1.7`, in your own commit

**Test command**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/type_layout_test.tscn
```
(plus a windowed capture — `--position 2240,320` — of the character archive
screen, opened and checked by eye)

---

## Lane: vehicle

**Task — V1.1: a car is a thing with a condition, not a state you are in**

Checklist: `V1.1` (open, `CHECKLIST.md`, section `V — The road`). Verified
directly: `game/systems/arcade_vehicle.gd` has no `condition`/`health` field
at all today — only `fuel` (`V1.3`, just closed) follows this simple
`var x := 1.0` + per-second-burn pattern. Impact tracking already exists to
degrade it from: `max_contact_closing` and `max_vehicle_contact_closing` are
already sampled on every collision. This is the foundational item V1.2
(visible damage that changes handling) and V1.4 (repair) both sit on top of —
scope this task to **V1.1 only**, not V1.2's visuals or V1.4's repair verb.

**Files it owns**
- `game/systems/arcade_vehicle.gd` — add the `condition` field and degrade it
  from existing impact-closing-speed tracking

⚠ Do not touch `game/rift_derby.gd` chassis/visual logic or
`game/systems/silhouette.gd` — those are Lane 2's ("the look") per
`AGENT_SPLIT_6.md`; V1.1 is the data model only, not the dressing.

**Success criteria**
- `arcade_vehicle.gd` has a persistent `condition: float` (1.0 = pristine),
  clamped 0..1, that only moves in response to real impacts — no scripted or
  timer-based decay
- Degradation is driven off the impact-closing-speed values already sampled
  per collision (`max_contact_closing` / `max_vehicle_contact_closing`), above
  some real threshold — not every micro-bump
- `condition` is queryable by other systems (a plain getter), so V1.2 has
  something to read from later without touching this file again
- New test suite `game/tests/vehicle_condition_test.gd` (+ `.tscn`), sibling to
  `vehicle_fuel_test.gd`: a hard impact drops condition measurably, a soft
  contact doesn't, it never goes below 0 or above 1
- Existing derby suites re-verified clean: `derby_breakables_test.tscn`,
  `derby_budget_test.tscn`
- Tick `V1.1` in `CHECKLIST.md` with the verification numbers, in your own commit

**Test command**
```
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/vehicle_condition_test.tscn
```
(then re-run `derby_breakables_test.tscn` and `derby_budget_test.tscn` the same way)

---

## Explicitly not picked, and why

- **AD10.13/14/15** (body/combat) read `[ ]` open but their own notes point at
  `AD3.2`/`AD3.3`, which are already `[x]` closed with full verification — a
  stale cross-reference, not a real open task. Worth a checklist-only fix
  later; not this morning's build task.
- **Flipping `momentum_damage`** — already done (`ba564ec`, per Greg, 2026-09-14).
  `AGENT_BRIEF_CURRENT.md` still lists it as pending; it isn't.
- **`G7.1`** (world/look, exposure at spawn) — explicitly "still Greg's call,
  not touched." Not an agent task.
- **MERGE_STATUS decisions 1, 3, 5** (BodyMirror shape, save-slot ownership,
  whether `codex/controls-ui-repair` is abandoned) — all three are one-line
  calls for Greg, not bounded build tasks. Flagging here so they don't get
  silently dropped: someone should ask him directly.
- **`X1.2`** (frame budget) — explicitly blocked on `X1.1`'s frame-timing
  numbers being untrustworthy (internally inconsistent 60fps/37ms reading);
  not actionable until that's re-measured on a real windowed run.
