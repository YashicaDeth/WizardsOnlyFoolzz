# Cross-lane design and integration audit — first-30-minute strike

Read-only review for `run_6da4e5a9677d` per `ORCA/DEMO_30_MIN_RESET_QUEUE.md`.
No gameplay files were modified. Sources inspected: `CHECKLIST.md` (~6998
lines, grepped and targeted-read), `DESIGN.md`, `ARCHITECTURE/SYSTEM_MAP.md`,
`DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`,
`ORCA/DEMO_30_MIN_RESET_QUEUE.md`, and the current code at HEAD `1df285b`
(`codex/game-planning`, same commit as all four `YashicaDeth/strike-*`
worktrees — they have zero commits ahead of this base, so this audit is
exactly the code each lane will start from):

- `game/vat_chamber.gd` (524 lines) — full read
- `game/systems/vat_intake.gd` (502 lines) — full read
- `game/systems/opening_director.gd` (53 lines) — full read
- `game/bone_yard_hunt.gd` (8583 lines) — targeted grep + reads (grapple/clinch
  ~L6090-6190, third-person unlock/refusal ~L6429-6494, exit transition
  ~L5730-5754, keys-card build ~L6506-6560, doc header ~L1-45)
- `game/systems/keys_card.gd` (181 lines) — full read
- `game/tests/gameplay_demo.gd` (104 lines) — full read
- `game/systems/gothic_field_hud.gd` — spot-checked for corner-layout claims
- `game/tests/` directory listing for the relevant suites
- `COMMANDS.md` for the real test-invocation form

## 1. The intended 0–30 minute route, as built today vs. as directed

**Directed** (`PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`): splash → creation
distributed through an authored *examination* by a senior visiting doctor who
records/exposes answers → soul/chaos-magick breakthrough breaks containment →
player emerges naked/wounded → physical acquisition teaching sequence
(restraint/tool, humiliation clothing, biometric guard encounter, scarce
firearm, stolen Black Mirror) → a large connected facility with **several
valid exits** (stealth, exploration, cooperation/betrayal, direct assault,
*optional* recapture into the derby, mastery route avoids the derby) → surface
handoff with route-dependent starting position.

**Built today** (`vat_chamber.gd` + `vat_intake.gd` + `opening_director.gd`):

1. `country_town_menu.gd` → `vat_chamber.tscn`, phase `"intake"`.
2. `VatIntake` (a 2D clipboard overlay) runs character creation as a
   generic **"HANDLER"** filling in a form — not the named-office senior
   doctor, no recorded/exposed-answers framing, no cruelty/sympathy beats, no
   mention of an examination at all. Pressing `F` fires `filed` immediately.
3. `_on_intake_filed()` sets `phase = "submerged"` and the scene plays a
   **scripted, non-interactive** submerge → void → glass-breach → floor
   sequence (`_update_sequence`). There is no player agency here and **no
   soul/chaos-magick breakthrough beat at all** — the glass just breaks on a
   timer (`_breach()`), narrated only by `BEATS` subtitle strings.
4. Player walks a 22-unit aisle (`AISLE_LENGTH`) to a door. The subtitle at
   9.0s reads `"OBJECTIVE // ESCAPE THE FACILITY"` and the on-screen prompt
   says `"OBJECTIVE: ESCAPE THE FACILITY // WASD MOVE  MOUSE LOOK"`.
5. Reaching the door and pressing `E` calls `_record_pit_entry()`, which sets
   `WorldHistory` status to `"racked for a heat"` and
   `Interstitial.travel("res://underground_colosseum.tscn", ...)`.

**The gap:** the only interactive thing the opening currently does after
creation is walk down one corridor to one door that is captioned "ESCAPE THE
FACILITY" but actually **racks the player for the derby** — there is no
acquisition sequence (no restraint/tool, no clothing, no biometric guard, no
firearm, no Black Mirror theft) before it, and no facility to move through.
The derby is the *only* path out of `vat_chamber.tscn`; nothing here offers
stealth, exploration, cooperation or direct assault as alternatives. This
directly contradicts the interview's explicit, confirmed line: *"The
underground derby is one possible route after capture, not the mandatory
route for every play style."* Winning the derby (`OpeningDirector` stage
`won_derby`) does hand off to `bone_yard_hunt.tscn`, which the file's own
header identifies as the Ashbloom Expanse open world — so the **surface
handoff itself is real and structurally sound**; it is everything between
"file the sheet" and "enter the pit" that does not yet exist.

This matches what Lane 1 was scoped to build (examination/creation → breakout
→ control → legible escape objective, teaching acquisition through existing
inventory/anatomy/ledger/history primitives) — the lane's premise is
accurate, not stale, and the work is substantial rather than a light touch.

Combat, grapple and perspective (Lane 2's scope) are real and further along:
`bone_yard_hunt.gd` has a working clinch (`KEY_C`, `_start_grapple`, the
walk/press/break loop at ~L6090-6190), a real third-person unlock gated on
`melee_body_hit`/`firearm_anatomy_hit` history events (not a save flag,
~L6435), an explicit refusal string for pressing the unlock key early
(`third_person_refusal()`), and a real exit transition out of the Hunt scene
(`_leave_demo_wall()` → `Interstitial.travel(... "country_town_menu.tscn")`,
L5752) gated on defeating the Ashline captain via `_rival_retreats()`. That
exit is a **demo-wall/menu return**, not a narrative "Derby/surface handoff"
in the interview's sense — it is a separate, already-shipped mechanic (P3)
layered on top of the same scene the interview's surface handoff also uses.

## 2. Cross-lane shared-file and state hazards

- **`bone_yard_hunt.gd` is single-owner (Lane 2) but everything else reads
  or writes state that lane produces.** Lane 3's `gothic_field_hud.gd` and
  `keys_card.gd` render contextual strips/cards built from data
  `bone_yard_hunt.gd` supplies (`_build_keys_card()` at L6506, the contextual
  strip's verb list). Lane 3 must not edit `bone_yard_hunt.gd` (per the
  queue) but any new binding Lane 2 adds (grapple/perspective) needs a
  corresponding keys-card row or Lane 3's own tests will pass against a card
  that is now missing a row — the same defect P5.4 already found and fixed
  once for `B`/`K`/`Q`. Recommend Lane 2 add its own keys-card rows inside
  `bone_yard_hunt.gd` (its own file, no conflict) rather than leaving that to
  integration.
- **`WorldHistory` / `PlayerActionLedger` / `OpeningDirector` stage subject
  (`opening_run`) is the one piece of shared mutable state all four lanes
  touch.** Lane 1 extends the opening stage machine (new stages between
  `woke` and `entered_pit`); Lane 2 and Lane 4 only *read* history counts
  (`event_count("melee_body_hit")`, etc.); nobody but Lane 1 should call
  `OpeningDirector.advance()`. `resume_destination()` (opening_director.gd:34)
  is a single chokepoint every lane's changes must keep valid — if Lane 1
  inserts new stages, `resume_destination()`'s three-branch `if` needs a
  fourth branch or a resumed run will skip the new content silently. This is
  the single highest-risk shared touchpoint for silent breakage.
- **Demo-mode territory gate (`_enforce_demo_territory()`, P2b) lives inside
  `bone_yard_hunt.gd`** and is keyed off `WorldHistory.is_demo()`. Lane 4's
  performance work must not disturb this function's per-physics-frame call
  even while trimming the physics tick cost, since it is one of only two
  call sites of `is_demo()`/`run_mode` outside tests project-wide (per
  `DESIGN.md`/checklist P10.2's own audit) — an easy accidental casualty of a
  "silence rigs to save ms" pass if it gets miscategorized as a per-actor rig
  cost.
- **Two stale sibling worktree sets exist on disk**: `demo-opening-ax`,
  `demo-combat-traversal`, `demo-controls-ui` (all pinned at `a4fd69e`, an
  older base than `1df285b`) alongside the four `YashicaDeth/strike-*`
  worktrees this queue actually dispatches (all at `1df285b`, zero commits).
  Both sets have overlapping/near-duplicate names and purposes. If a
  coordinator or a lane worker targets the wrong worktree by name, it will
  build on stale base `a4fd69e` and produce a conflicted or silently-missing
  merge. Recommend deleting or clearly relabelling the `demo-*` set before
  dispatch, or the integration gate should refuse any SHA whose merge-base
  with `codex/game-planning` isn't `1df285b`.
- **Test-file collisions are unlikely but naming overlap exists**: Lane 1 and
  Lane 3 both plausibly touch `demo_route_test.gd`/`.tscn` (Lane 1's "opening
  handoff evidence", Lane 3's "demo-route tests" are explicitly named in the
  queue as Lane 3's scope). Confirm ownership of this one file pair explicitly
  before dispatch — the queue's Lane 1 text doesn't list it, but its "narrowly
  related opening tests/captures" clause is loose enough to collide with
  Lane 3's explicit ownership.
- **Lane 4 has no exclusive file list**, only "profiling and tightly scoped
  fixes... avoid files owned by lanes 1-3 unless a conflict is reported
  first." Given `X1.2`'s own finding that the frame cost is simulation-bound
  in the Hunt's 60 Hz physics tick and specifically in `bone_yard_hunt.gd`'s
  22 character rigs, Lane 4's most likely real fix target is exactly the file
  Lane 2 owns exclusively. This is the one lane pairing most likely to need a
  reported conflict rather than clean parallelism — flag it to the
  coordinator now rather than after both lanes report done.

## 3. Feedback gates requiring Greg, not agent judgment

- **The derby-as-mandatory-only-exit contradiction (§1) is a design
  decision, not a bug.** Whether the rough-bones slice should (a) keep the
  derby as the only exit for this pass and treat "several escape approaches"
  as future work, or (b) add at least one second exit now, changes Lane 1's
  scope materially. The queue's Lane 1 text ("acquisition through existing
  inventory, anatomy, ledger, and history primitives... do not invent... the
  full facility map") reads as option (a), but that reading directly
  contradicts the interview's confirmed line quoted in §1. This is exactly
  the kind of "genuine contradiction" `ARCHITECTURE/SYSTEM_MAP.md`'s
  non-negotiable rule 5 says to report rather than resolve by invention.
- **The examiner's identity, cruelty/sympathy register, and the exact
  breakthrough vision/memory/ability are explicitly open** in the interview
  ("full screenplay... remain open," "exact breakthrough remain open"). Any
  dialogue Lane 1 writes for the doctor is provisional prose, not lore — the
  interview says the provenance discipline (`Confirmed`/`Working
  recommendation`/`Open`) must be preserved, and a rough-bones pass writing a
  full doctor voice risks quietly promoting invented lore the way `DESIGN.md`
  warns against ("do not silently promote an assistant's suggestions into
  requirements").
- **Death/revival during the opening is explicitly unresolved** ("until the
  game's death fiction is authored, ordinary reload is the honest
  implementation"). If Lane 1 or Lane 2's regression work touches what
  happens on player death mid-opening, that must stay ordinary reload; a gate
  for Greg only if any lane's acceptance test implies otherwise.
- **HUD corner layout** — the interview's "Working recommendation for the
  next structural pass" (top-right portrait/resources, top-left anatomy,
  bottom-left map, bottom-right carried item, centre empty) is explicitly
  *not confirmed*, and `DESIGN.md`'s own prose describes a similar-but-not-
  identical layout as settled ("top-right... mood reliquary... lower-right is
  ultimately the scuffed Black Mirror... lower-left belongs consistently to
  its live satellite/radar feed"). Lane 3 should not silently pick one
  reading over the other for anything beyond what's already built — file a
  gate if the "overwhelming F1 wall" work requires deciding between them.
- **P1.3 ("generous rather than careful") and P4.4 ("one moment engineered to
  be the thing a player describes to somebody else")** are open, subjective
  checklist items with no objective acceptance criterion. Nobody should tick
  these from agent judgment; they need Greg's own playtest reaction (matches
  `PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`'s "Evidence still requested"
  section, which is itself written as a narrated-playtest questionnaire, not
  a spec).

## 4. Safest commit integration order and relevant Godot tests

Test invocation form (from `COMMANDS.md`):
`TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp ATG_TEST_MODE=1 "P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe" --headless --path game res://tests/<name>.tscn`

Recommended integration order, dependency-first (matches
`ARCHITECTURE/SYSTEM_MAP.md`'s critical path: data contracts → character
record → embodied acquisition → biometric encounter → facility branches →
surface handoff, and its rule to fast-forward every worktree to the same
integration commit):

1. **Lane 1 (opening)** first — it is upstream of everything else in the
   route (`opening_director.gd`'s stage machine gates `resume_destination()`,
   which every other scene's "where do I resume" logic reads). Run
   `opening_test.gd`, `opening_direction_test.gd`, `opening_stage_wiring_test.gd`,
   `vat_containment_test.gd`, `vat_route_ledger_test.gd`, `intake_body_test.gd`,
   `intake_direction_test.gd`, `intake_variance_test.gd`, `demo_mode_test`
   equivalents, and `loop_smoke_test.gd` (the scene-graph reachability check).
2. **Lane 2 (combat/perspective)** second, rebased onto Lane 1's landed
   commit only if Lane 1 touched files Lane 2 reads (it shouldn't need to —
   Lane 2 doesn't own opening files) — otherwise integrate independently.
   Run `grapple_test.gd`, `grapple_mass_test.gd`, `grapple_playability_test.gd`,
   `grapple_zone_test.gd`, `clinch_test.gd`, `clinch_control_test.gd`,
   `clinch_limb_test.gd`, `clinch_pressure_test.gd`, `perspective_unlock_test.gd`,
   `third_person_dodge_test.gd`, `zone_precision_test.gd`,
   `field_hud_third_person_capture.gd`.
3. **Lane 3 (controls/HUD)** third — it reads whatever keys-card rows Lane 2
   may have added to `bone_yard_hunt.gd`, so integrating after Lane 2 avoids
   reviewing a keys-card change against a stale row set. Run
   `keys_card_test.gd`, `hud_transience_test.gd`, `hud_settings_test.gd`,
   `hud_capture.gd`, `controls_recovery_capture.gd`, `demo_route_test.gd`,
   `shipping_controls_test.gd`.
4. **Lane 4 (performance/audio)** last, after the other three land, since its
   own acceptance criterion (60 FPS on the real route) has to be measured
   against the actual integrated scene, not a lane's isolated worktree. Run
   `tests/frame_bound_test` (with `--soak` and `--breakdown` per its existing
   X1.2 usage), `perf_probe_test.gd`, `sandbox_perf_test.gd`,
   `derby_budget_test.gd`, `map_perf_test.gd`, `audio_test.gd`,
   `audio_reactive_test.gd`.
5. **`loop_smoke_test.gd` re-run once more after all four are merged** — it
   is the one test that walks the whole `Interstitial.travel` scene graph
   from source and would catch a lane accidentally orphaning a transition.

## 5. Stale instructions / acceptance criteria vs. current code

- **`CHECKLIST.md`'s own top-of-file note (L89-94) claims `bone_yard_hunt.gd`
  "has no exit transition of any kind."`** This is stale: `_leave_demo_wall()`
  (L5752-5753) calls `Interstitial.travel("res://country_town_menu.tscn", ...)`
  and is wired to a real player-reachable outcome (`_rival_retreats()` on
  defeating the Ashline captain). The note appears to predate the P3 "demo
  wall" work; it should be corrected or removed rather than trusted as
  current state.
- **`CHECKLIST.md` G6 ("The opening, directed") shows G6.1-G6.3 struck
  through as done** ("Pacing and camera", "Sound design", "The handler's
  delivery"), which reads as though the opening sequence is finished. Against
  current code, this is true only for the narrow scripted submerge/breach
  sequence and the handler's *intake-form* dialogue — it is not true of the
  interview's examination/doctor/breakthrough/acquisition direction, which
  postdates G6 by a week and supersedes it per `DESIGN.md`'s own routing
  note ("supersedes older prose where that prose treats a map area as merely
  a 'holding'... or presents the J birthday/resonance screen as an
  established ordinary-play action" — the opening is not literally named in
  that supersession clause, but the interview document's own header states
  it "is authoritative for the direction below" and G6 does not implement
  that direction). Lane 1 should treat G6's checkmarks as stale for the
  purposes of this task, not as "already built."
- **Lane 3's queue framing ("Replace the overwhelming F1 wall with readable
  contextual groups or pages") undersells current code.** `keys_card.gd`
  already implements grouped, paged rendering (`GROUPS_PER_PAGE = 2`,
  `page_count()`, `change_page()`), and `bone_yard_hunt.gd::_build_keys_card()`
  (L6506) already organizes bindings into four named groups (MOVING,
  FIGHTING, HANDS ON, WHAT YOU CARRY) across two pages — this is the fix for
  `AG2.1-AG2.4`, already ticked in the checklist (`AG2.1` struck through,
  `AG2.4` partially). The literal "wall" complaint (one undifferentiated F1
  dump) does not match current code. The real remaining gap, per `AD10.10`
  (open) and `AG2.4` (partial), is narrower: the *contextual strip*
  (`gothic_field_hud.gd`) does not announce a newly-available verb the moment
  it becomes available — that's a legitimate, smaller target than "replace
  the wall." Recommend Lane 3 be told the wall is already fixed and the real
  target is the new-affordance announcement plus the objective/prompt
  overlap the queue also names.
- **`gameplay_demo.gd` does not exercise real input.** It drives the scene
  by calling internal methods directly (`hunt.call("apply_look", ...)`,
  `hunt.call("_attack", true)`, `hunt.call("_toggle_panel", "map")`) rather
  than synthesizing `InputEvent`s through the actual keybindings. The queue's
  instruction to "make the gameplay-demo harness exercise the same controls
  and route as the real game" is accurate and not stale — this is a real gap,
  not already covered by an existing test.
- **`DESIGN.md`'s HUD corner description and the interview's "Working
  recommendation" partially disagree** (see §3) — neither is stale exactly,
  but treating either alone as settled would be wrong; both are prose, not
  code, so this is a documentation consistency gap worth a one-line fix in
  `DESIGN.md` pointing at the interview as authoritative, the way it already
  does for the holding/derby/J-panel corrections.

## Integration checklist (for Gate 5)

- [ ] Confirm all four `YashicaDeth/strike-*` worktrees still share merge-base
      `1df285b` before accepting any commit (see §2, stale-worktree hazard).
- [ ] Land Lane 1; run its suite plus `loop_smoke_test.gd`.
- [ ] Verify `OpeningDirector.resume_destination()` still round-trips every
      stage Lane 1 added (no silent resume-skip).
- [ ] Land Lane 2; run its suite; confirm no new keybinding is missing from
      `bone_yard_hunt.gd::_build_keys_card()`.
- [ ] Land Lane 3; run its suite against the now-current keys-card row set.
- [ ] Land Lane 4 last; re-run `frame_bound_test --soak --breakdown` against
      the fully-integrated tree, not an isolated worktree; confirm
      `_enforce_demo_territory()` is untouched.
- [ ] Final `loop_smoke_test.gd` pass on the merged tree.
- [ ] Exercise the real 1280×720 route once end to end and capture evidence
      per the queue's Gate 5 instructions.
- [ ] File a Greg-facing gate for the derby-mandatory-exit contradiction
      (§3) before Lane 1's acquisition-sequence scope is treated as final.

## Honest gaps in this audit

- `bone_yard_hunt.gd` (8583 lines) was not read start to end — only the
  regions relevant to exit transitions, grapple/clinch, and third-person
  unlock were inspected directly; other combat/traversal code in that file
  is taken on the checklist's word plus the targeted greps above.
- No Godot tests were executed (read-only audit, no code run) — the test
  list in §4 is derived from file inventory and checklist cross-references,
  not from a live pass/fail run.
- `gothic_field_hud.gd` (808 lines) was spot-checked, not fully read; the
  HUD-corner consistency question in §3/§5 is based on `DESIGN.md`/interview
  text plus a targeted grep, not a full audit of the HUD's current draw code.
