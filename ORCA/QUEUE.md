# Queue — bounded tasks, ready to dispatch

Each task below was **verified against the code on 16 September**, not copied
from `CHECKLIST.md`'s prose. Re-verify anyway if time has passed; see
`RULES.md` rule 6.

Ordered roughly by value. One task, one lane, one worktree.

---

## 1. Merge `codex/sol-agent-1` + `integration-check-agent-a` — lane 7

**Newly unblocked.** `DECISIONS.md` #3 answered the question that was holding
both: HEAD's `active_save_path()` / `save_path_for_slot()` owns save location.
13 commits become ordinary merge work.

- Keep HEAD's path logic in `world_history.gd`; land sol-agent-1's other
  commits on top of that shape.
- `integration-check-agent-a`'s remaining work is `P2.3`, which touches the same
  file and so folds in here.
- Its `.tscn` wants "FOOLS" over "FOOLZ" — **do not let it have it.**
- Rules 4 and 5 are not optional here. Import, then measure separately, then
  run the suites, then commit.

## 2. AD10.7 — crouch, sprint and slide as one system — lane 1 (`lane-1-body`)

**Verified: crouch already exists, slide genuinely does not.** `CHECKLIST.md`'s
own note ("no crouch or slide verb to be continuous with") is stale on the
crouch half.

- `crouching` is a real `bool` in `game/bone_yard_hunt.gd` (~`:320`), driven by
  `Input.is_action_pressed("crouch")` (~`:1444`), with a hard-coded speed `3.4`
  (~`:1467`), a capsule-height lerp (~`:1481`), already threaded into
  `hunter_body_motion.update()` (~`:1538`). Since `8b2bdb5`. **Do not rebuild.**

Scope is exactly three things:
1. Crouch's hard-coded `3.4` sits *beside* `_player_speed_scale()` (~`:991`, the
   leg-injury multiplier sprint/walk already use at `~:1477`). Fold it onto that
   path — one speed rule, not two.
2. There is no `slide` verb at all (`grep '\bslide\b' game/` hits only
   comments). Add one: short forward impulse gated by momentum, decaying.
3. Crouch has no injury gate. vault and wall-run all do
   `if player_rig.anatomy.mobility_ratio() < PLAYER_INJURY_FLOOR: return`
   (`:2540`, `:2625`, `:2688`). Crouch and slide must too — a broken leg lets
   you crouch fine today.

**Done:** new `game/tests/crouch_slide_test.gd` + `.tscn` passes, and
`wall_run_test`, `momentum_carry_test`, `anatomy_traversal_test` re-verified.

## 3. The P section — lane 4 (`lane-4-demo`)

The highest-value lane in the project. P is **7 of 45**. Build on the DEMO door
that `9c26be4` already added; do not re-litigate the menu shape.

Pick the next two or three open `P` items that give the first ten minutes a
point, rather than items that add more systems. Re-verify `demo_mode_test`
before committing.

## 4. X1.1 — get a trustworthy frame-timing number — lane 2 (`lane-2-world`)

The one live unsolved bug, and it blocks all of `X1.2`.

- A reported **13 FPS** and a sandbox crash that could not be reproduced from
  source across 600 rounds fired and 240 mixed inputs.
- X1.1's reading is **internally inconsistent** — 60fps and 37ms in the same
  breath, which cannot both be true. Every number downstream of it is fiction
  until that is fixed.
- Tooling already exists and is committed: **F3** in-game overlay, **F4** writes
  `perf_dump.txt` next to the exe, three benchmarks in `game/tests/`.

Fix the measurement first, then re-measure **on a real windowed run** — headless
will not settle this. Report the honest number. "The 13 FPS was itself an
artifact" is a perfectly good outcome. Do not go hunting a performance fix until
the number is trustworthy. **Do not start X1.2.**

## 5. A1.7 — `character_archive.gd` onto CellOutzType — lane 5

**Verified: 22 raw `draw_string()` calls, zero `CellOutzType` references.** It
is entirely on the engine fallback font.

- Follow the pattern already proven in `body_inspector.gd` and `world_index.gd`.
- **The trap:** `draw_string` takes a *baseline*, `CellOutzType` takes
  *top-left*. Lift by cap height or every converted line lands low.
- `game/tests/type_layout_test.gd` already lists this file in its `SCREENS`
  glyph-coverage set and must still pass.
- Take a windowed capture (`--position 2240,320`) and **open it**. Do not claim
  it.
- `gothic_field_hud.gd` is listed as outstanding in `AGENT_BRIEF_CURRENT.md` and
  is **already fully converted**. Don't redo it.

## 6. AF10.10 — weapon customisation lives on the weapon — lane 3 (`lane-8-guns`)

`CHECKLIST.md:3644`. Open. Customisation should live on the weapon's own data
the way `condition` does, read by whoever holds it — not in the holder.

**`setup/ORCA_LANES.md` is stale here.** It calls AF10.1, AF10.3, AF10.4,
AF10.5 and AF10.12 "buildable now"; all five are closed. Still open in AF10:
10.2, 10.6, 10.8, 10.9, **10.10**, 10.13, 10.15.

Use `lane-8-guns`, not `lane-3-guns` (stale, 43 behind).

## 7. Commit the orphaned V1.1 test + colosseum work — main worktree

`vehicle_condition_test.gd` / `.tscn` are untracked in the main worktree. They
are the test suite for **V1.1, whose implementation already shipped** —
`arcade_vehicle.gd` has `condition`, `_condition_scale()` (`:207`) and
impact-driven degradation (`:432`), all committed. The feature went in without
its test.

Run the suite against the committed implementation. **If it fails, do not touch
`arcade_vehicle.gd` — report it**, because that means shipped V1.1 is wrong.
Also land `underground_colosseum.tscn` and `ringmaster_card.gd`.

Explicit-path staging matters more here than anywhere: this is the shared
worktree.

## 8. Redo the controls-UI repair on trunk — lane 5

Per `DECISIONS.md` #5. `Y` is rebindable controls and a settings screen that
does something — **0 of 20**, and the first thing anyone handed a build will
touch. Do not merge or cherry-pick `codex/controls-ui-repair`; build it fresh.

## 9. Housekeeping

- **19 worktrees.** Nine `P:/GameDev/atg-*` are left over from old rounds.
  `lane-3-guns` is superseded by `lane-8-guns`. Prune.
- Dead code from the b-ladder merge — see `DECISIONS.md`.
- `AD10.13/14/15` read open but their notes point at `AD3.2`/`AD3.3`, which are
  closed with full verification. A stale cross-reference, not real work — worth
  a checklist-only fix.

---

# Dispatch template

Paste and fill. The boundaries section is not padding — it is the part that
stops the failure in `OWNERSHIP.md`.

```
TASK ASSIGNMENT — <item id and one-line summary>.

Work ONLY in worktree <absolute path>, which is clean and at trunk <sha>.
Do NOT work in P:\GameDev\AllusionsTooGrandeur — other agents are live there.

FIRST: if a permission dialog is blocking you, Shift+Tab to "Bypass
permissions". Session mode does not inherit from settings.json.

SCOPE — verified against the code on <date>, not against CHECKLIST.md's prose:
<what already exists and must not be rebuilt>
<what is actually missing — this is the whole job>

FILES YOU OWN: <explicit list>

HARD BOUNDARIES — other lanes are mid-task in these, do not edit:
<explicit list>
If you need a call site in one of them, STOP and message me; I will sequence it.

DONE MEANS: <success criteria, including which existing suites re-verify clean>

TEST COMMAND:
TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/<suite>.tscn

HOUSE RULES (see ORCA/RULES.md — they override everything above):
- NEVER `git add -A`. Stage by explicit path.
- A suite that prints NOTHING has not passed.
- Never measure in the same breath as `--import`.
- Commit early by explicit path; do not leave work untracked.
- Tick CHECKLIST.md as your LAST commit, touching ONLY CHECKLIST.md.

Report to <session name> via SendMessage when done or blocked.
```
