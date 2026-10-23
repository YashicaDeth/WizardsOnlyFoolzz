# Prompt roadmap

The dispatch order. Fourteen briefs, each paste-ready, each ending in something a
player can do and a recording that shows it. Read `THE_SPINE.md`,
`THE_LADDER.md`, `THE_CAST.md`, `THE_SCREEN.md` and `STYLE_RULES.md` first — the
briefs assume them.

**Branch:** `claude/launch-latest`. **One brief, one worktree, one agent.**
**Skills to load by name:** `wof-lane-hygiene`, `wof-verify-by-looking`,
`wof-wire-before-polish`, and the engine skill the brief names.

**Done means** (the same six as `goal/SKILL.md`, unchanged): a player can do it in
the real route; the world records it; a capture was rendered, opened and
described; one small test fails without the change; `tools/run_tests.sh --core`
is green; it is merged.

**Rules that keep it honest.** Stage by path, never `git add -A` (Godot rewrites
`.import`/`.uid` on every open). Never push, merge or rebase another agent's
branch. Never invent a name, title or reason to unblock a brief — that is what
`OPEN` is for. If a brief's `EXISTS` turns out to be wrong when you get there,
stop and report; do not build around it.

---

## The order

| # | Brief | Needs first | Wave |
| ---: | --- | --- | --- |
| 1 | `ladder-seats` | — | the board |
| 2 | `scar-ledger` | 1 | the board |
| 3 | `board-screen` | 1, 2 | the board |
| 4 | `gore-g2-arterial-pulse` | pulse (built) | combat and gore |
| 5 | `combat-c5-stamina-spine` | — | combat and gore |
| 6 | `combat-c2-omnidirectional` | 5 | combat and gore |
| 7 | `combat-c3-readable-exchange` | 6 | combat and gore |
| 8 | `combat-c4-tier-duel` | 7 | combat and gore |
| 9 | `inv-90-inventory-works` | — | the v0.1 gaps |
| 10 | `cust-91-real-customisation` | — | the v0.1 gaps |
| 11 | `route-88-systems-on-the-route` | 9 | the v0.1 gaps |
| 12 | `vat-imp-66-room` | — | the v0.1 gaps |
| 13 | `fix-95-105-stability` | — | hold it up |
| 14 | `polish-50-sound-timing` | 4, 6 | hold it up |

Briefs 9–14 are the four unchecked v0.1 lines plus the two that make the demo
survive a stranger. Brief 6 is the queue's own "combat overhaul" line, cut into
four. Briefs 1–3 are the board, and they are first because everything they need
already exists and nothing else gives art and writing as much to work with.

---

## 1. `ladder-seats`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      The facility's people occupy real seats. A named guard dies, the seat
          stands empty until dawn, someone is promoted into it, and the board
          the player can open shows both facts.

EXISTS    game/systems/pyramid_society.gd — five bands with capacities 1 / 3 / 9
          / 27 / uncapped, twelve standing dimensions, eligibility gates, the
          horseshoe placement, a graveyard and resurrection. Tested by
          tests/pyramid_society_test. Called by no scene.
          game/systems/world_history.gd — the subjects, places and receipts.
          game/systems/world_clock.gd — the hour, for "at dawn".
          game/systems/facility_guard_post.gd — Hollis and the numbered guard.
          game/systems/facility_characters.gd — the guard register.
          DESIGN/THE_LADDER.md is the specification; where it and the code
          disagree, the code wins and the doc is the bug.

OWNS      New game/systems/ladder_seats.gd and tests/ladder_seats_test.gd.
          Additive calls into world_history.gd and world_clock.gd only.
          Do not edit bone_yard_hunt.gd, vat_chamber.gd or melee_driver.gd.

BUILD     One board per save. Register every named facility person into it with
          their faction and starting standing; let the bands seat them.
          A death vacates the seat and records it. At the next dawn the highest
          eligible person in the band below is promoted, and the promotion is a
          nemesis event on both subjects ("promoted into <name>'s seat").
          Empty seats are visible and carry the hour they fill.
          If DESIGN/THE_LADDER.md §5 has been answered yes by Greg, record the
          sponsor and the retinue; if it has not, build neither and say so.

PROOF     Kill the numbered guard in the Service Arcade, sleep to dawn, open the
          board: a capture before and after, the new name in the old seat, and
          the dead one in FALLEN. Open both PNGs and describe them in the commit.

TESTS     pyramid_society_test stays green; ladder_seats_test covers death →
          vacancy → dawn promotion → the promoted card carrying the seat and the
          killer's history. --core green.

OPEN      Whether seats are sponsored (THE_LADDER §5) and the retinue rule are
          Greg's. The `ashline_wreckers` double meaning (road crew vs Wrath) is
          his. Build the seat mechanics without either, and report.

OUT       The screen itself (brief 3). The surface pyramid, territories, the
          Wire. Any new name, title or faction.
```

## 2. `scar-ledger`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      A wound leaves a permanent record on the person who took it: where it
          landed, what made it, how many rounds, and which bone it reached. The
          X-ray reads it back, and the board's card quotes it in one line.

EXISTS    game/systems/anatomy_component.gd — zones and organs.
          game/systems/wound_catalog.gd, wound_marks.gd — the wound as a mark.
          game/systems/round_trails.gd — entry / exit / stop, which side, bone
          reached; the grammar already exists.
          game/systems/perfusion.gd — blood, flow, oxygen, pulse (built 23 Oct).
          game/systems/medical_monitor.gd — the body's readout.
          game/systems/pyramid_society.gd — the subject record that must hold it.

OWNS      New game/systems/scar_ledger.gd and tests/scar_ledger_test.gd.
          Additive fields on the subject record and one read call in the X-ray
          overlay. Do not edit melee_driver.gd or bone_yard_hunt.gd.

BUILD     A landed blow writes one scar candidate: zone, cause (blade, round,
          blunt, burn, shock), the round count where there is one, the bone
          reached, and the world hour. It is not a new damage number — every
          field is read from what the hit already recorded.
          The scar survives save/load with the subject.
          The X-ray on that person shows the marks at the bone they reached, and
          names the exchange that made each ("#3 · BLADE · LEFT FOREARM · 6 OCT").
          The card quotes one, the largest or the most recent, in a single line.

PROOF     Shoot the same forearm twice, open the X-ray: two marks, two lines,
          the right zone and cause on each. A capture, opened. Reload, open it
          again: still there.

TESTS     scar_ledger_test: cause and zone survive save/load and match the hit
          that made them; a body with no wounds reads empty. round_trails_test,
          medical_monitor suites and --core green.

OPEN      Whether a scar changes how a body fights (a limp, a bad arm) is Greg's
          — it is balance, not record. Build the record only.

OUT       Healing, infection, scar art beyond the X-ray mark. Any second copy of
          a wound number.
```

## 3. `board-screen`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      The board is a place. Seven rows of seats on a wall, cards that read,
          a photograph of it on the phone that is honestly one edit behind.

EXISTS    game/systems/pin_board.gd — the storyline as a wall.
          game/systems/world_history.gd — the subjects and places to draw.
          game/systems/rabbit_hole_navigator.gd — typed, reversible navigation
          shared by the Pyramid, the Wire and physical tools.
          game/systems/field_camera.gd and photo_album.gd — photographs as
          objects.
          game/systems/celloutz_type.gd — the house face (caps only, no arrows,
          no wrapping; draw_string takes a baseline, CellOutzType a top-left).
          DESIGN/THE_SCREEN.md is the specification.

OWNS      New game/systems/board_view.gd, game/scenes board scene, its capture
          and tests/board_view_test.gd. pin_board.gd and rabbit_hole_navigator.gd
          are yours to extend; everything else is read-only.

BUILD     Seven rows: the five bands, YOU, FALLEN. Seats drawn as seats, empty
          ones visibly empty with the hour they fill. A card per person with the
          fields in DESIGN/THE_CAST.md §7. Pan and zoom on the pad, Circle back,
          one press to the place they were last seen.
          The phone's BOARD page shows the last photograph of the wall, stamped
          with the hour, and says when the wall has changed since.
          No total, no level, no percentage, no marker.

PROOF     A capture of the wall read from across the room (shape) and one at
          arm's length (cards). A capture of the phone showing a stale
          photograph. Both opened and described.

TESTS     board_view_test: seven rows in order; an empty seat is drawn and
          carries a fill hour; the card has exactly the permitted fields; a
          stale photograph reports stale. --core green; the pad path driven by
          synthetic events.

OPEN      Where the wall is, whether it can be taken, and whether a wrong string
          is ever corrected (THE_SCREEN §7) are Greg's. Build the wall and the
          photograph; choose no location without him.

OUT       Strings as claims, pinning, publishing (slices 4–5 of THE_SCREEN).
          Any new screen that is not an object.
```

## 4. `gore-g2-arterial-pulse`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
wof-combat-fx, maximizing-game-feel.

GOAL      A severed artery sprays in beats at the pulse rate. A heart that has
          stopped sprays not at all. Blood on the floor is a consequence of the
          body's own rhythm, not an effect with a timer.

EXISTS    game/systems/perfusion.gd — flow, oxygen, volume, open vessels, and
          pulse() with its rate (built 23 Oct: 62 BPM whole, 103 bleeding, PULSE
          NONE arrested, 130 with the heart back).
          game/systems/medical_monitor.gd — prints the pulse.
          game/systems/blood_veil.gd, blood_pool.gd, blood_flow.gd — the blood
          that already exists on the lens, the floor and the body.
          game/systems/wound_marks.gd — where the wound is.
          DESIGN/GORE_AND_COMBAT_ROADMAP.md G2 is this brief.

OWNS      New game/systems/arterial_spray.gd and tests/arterial_spray_test.gd.
          Additive calls in blood_veil.gd / blood_pool.gd only.

BUILD     A severed artery (an open vessel in perfusion, at a wound the player
          made) emits beats at the pulse rate, each beat adding to the existing
          veil, pool and smear rather than to a new system.
          Arrest stops the spray on the next beat; the pool keeps growing only
          by what already fell.
          Volume lost stays the number perfusion already tracks — the spray
          reads it, it does not own it.

PROOF     A headless test counting beats a second against the rate, and the
          arrested case asserting zero. One frame of the spray in the sandbox,
          opened. A capture at t+0 and t+3 s showing the pool without the spray.

TESTS     arterial_spray_test; blood_flow_test, blood_pool_test and --core
          green.

OPEN      How much blood is too much on screen is Greg's (gore look must never
          get worse). If the beat reads as a fountain rather than a pulse, stop
          and show him the frame.

OUT       New gore systems, new decals, sound (brief 14 owns that timing).
```

## 5. `combat-c5-stamina-spine`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
maximizing-game-feel, design-action-combat.

GOAL      Pressing is a decision with a price: a landed hit returns stamina, a
          whiff does not, a parry returns most. The player can feel which one
          they just did.

EXISTS    game/systems/melee_driver.gd — light/heavy, commitment, a 0.24 s parry
          window, stamina with a 0.55 s delay, per-target poise and stagger,
          hitstop.
          game/systems/combat_stance.gd, limb_momentum.gd, impact_feel.gd.
          game/systems/souls_mover.gd — movement and its stamina drain.
          tests/impact_feel_test, combat_stance_test, sparring_test.

OWNS      melee_driver.gd, its tests, and the stamina rows in the field HUD.
          bone_yard_hunt.gd: a declaration, a new(), one call per change.

BUILD     Three rules, one commit each: a landed hit returns stamina; a whiff
          returns none and leaves the recovery long enough to be punished; a
          parry returns more than a hit. The delay stays as it is.
          The number is shown as the body's own readout (the Nerve Rig), never a
          bar.

PROOF     A duel in the sandbox: whiff, get punished; land a hit, recover;
          parry into a riposte. A short capture of the readout through all three.
          Recorded and looked at.

TESTS     melee/combat suites green, especially impact_feel_test and
          combat_stance_test; one new assertion per rule; --core green.

OPEN      The exact returns are Greg's to feel. Build the three rules with
          numbers behind dials and report the values you chose.

OUT      New moves, new weapons, poise changes, hitstop changes.
```

## 6. `combat-c2-omnidirectional`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
maximizing-game-feel, design-action-combat.

GOAL      Third person: the blow goes where you push, in eight directions, and
          the hunter turns into it. First person keeps precise aim.
          Direction is a skill, not a skin.

EXISTS    game/systems/strike_heading.gd — PUSH_THRESHOLD 0.2, the seed.
          game/systems/sword_moveset.gd — authored arcs.
          game/systems/hunter_body_motion.gd — the poses.
          bone_yard_hunt.gd — STRIKE_FACE_SECONDS 0.35 and the selection cone
          aim_dot >= 0.32.
          DESIGN/COMBAT_LOOP_GOAL.md is the quality bar.

OWNS      strike_heading.gd, sword_moveset.gd, hunter_body_motion.gd (poses
          only), their tests. bone_yard_hunt.gd: small edits only.

BUILD     Eight directions on the stick, each with its own commitment and
          recovery, each turning the body into the arc rather than at the end of
          it. The neutral direction keeps today's behaviour.
          The selection cone follows the direction, so the nearest valid target
          inside the arc is the one struck, and nothing outside it is.

PROOF     The strike gallery: eight distinct arcs, captured as a strip and
          opened. A hit landing behind the player in the Hunt, recorded.

TESTS     sword_moveset_test across eight directions; strike/heading suites;
          --core green. One regression asserting a target outside the arc is
          never selected.

OPEN      How far the camera pulls back, and whether the eight directions are
          eight or four-plus-diagonals, are Greg's. Build eight; make it a
          constant.

OUT      New weapons, damage numbers, the third-person camera rig itself.
```

## 7. `combat-c3-readable-exchange`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
maximizing-game-feel.

GOAL      After an exchange the player can say what decided it: a hit, a block,
          a parry or a stagger. A loss teaches something.

EXISTS    game/systems/block_tracker.gd — blob tracking and awareness boxes.
          game/systems/impact_feel.gd — the states of contact.
          game/systems/lock_readout.gd — the body, never a bar.
          game/systems/medical_monitor.gd — the body's readout.
          The four outcomes already exist as states; nothing prints which one
          decided the exchange.

OWNS      block_tracker.gd, lock_readout.gd, their tests. One read-only call in
          melee_driver.gd.

BUILD     On the frame an exchange resolves, the tracker records which state
          decided it and prints it in the house register on the locked body's
          card, for about a second: PARRY · RIPOSTE OPEN, WHIFF · PUNISHED,
          BLOCKED · STAMINA SPENT, STAGGERED · OPEN.
          No score, no combo counter, no reward. It is a fact, not a treat.

PROOF     A capture of each of the four states, opened and described. A duel
          where the player loses and the readout names why.

TESTS     One test per outcome; the printout is asserted, not just the state.
          --core green.

OPEN      How long the line stays is feel, Greg's. Default one second.

OUT      Damage numbers, hit counters, slowdown.
```

## 8. `combat-c4-tier-duel`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
design-action-combat, tune-enemy-ai.

GOAL      Three enemy competences that are actually different: a scavenger
          telegraphs long, a captain feints, an elite punishes a whiff — and the
          same scripted player beats the first and loses to the third.

EXISTS    game/systems/fighter_tier.gd — scavenger / hunter / captain / elite,
          side and feint data (feints at 0.82 of the wind-up).
          game/systems/rival_tactics.gd — tactic adaptation on LimboAI.
          tests/sandbox_duel_test, sparring_test, third_person_sandbox_test.

OWNS      fighter_tier.gd, rival_tactics.gd, the sandbox encounter data, their
          tests.

BUILD     Tune the tiers by behaviour, never by health: telegraph length, feint
          probability, punish window, spacing, and whether they call for help.
          Write the deterministic duel: one scripted player, three opponents,
          the same inputs, the expected win/loss/draw per tier.

PROOF     The duel run twice for stability, and a capture of each tier's
          telegraph at the moment it starts. Opened.

TESTS     sandbox_duel_test extended to the three tiers; the duel is the
          assertion. --core green.

OPEN      Whether four tiers or three ship is Greg's. Build three; keep the
          fourth behind the same table.

OUT      Health multipliers (a guard test should fail if one appears), new
          enemy types, boss phases.
```

## 9. `inv-90-inventory-works`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
build-game-inventory.

GOAL      A Souls-style grid in Pause plus d-pad quick slots. Equip a weapon, an
          organ or an implant; pick something up on the route and find it there.

EXISTS    game/systems/field_inventory.gd — a direct view of the Carry model.
          game/systems/carry.gd — items as things with mass.
          game/systems/pause_gate.gd — the pause menu and its pages.
          game/systems/field_meds.gd — hold-4 and dressings.
          tests/field_inventory_test, field_inventory_capture.

OWNS      field_inventory.gd, a new grid view, pause_gate.gd's INVENTORY page,
          their tests. carry.gd: additive only.

BUILD     A grid, drawn in the house frame, with slots that hold what Carry
          holds. Select, inspect, equip, drop. Equipping writes to the same
          arsenal/hand path the world already uses; nothing duplicates state.
          Quick slots on the d-pad mirror the grid, and the HUD shows what is in
          them.

PROOF     Pick up the guard's BREACH NINE, open Pause, find it, equip it, close,
          fire it. A capture of the grid before and after, opened.

TESTS     field_inventory_test and a new grid test for move/equip/drop with no
          duplication; inventory and arsenal suites; --core green.

OPEN      Grid size and whether organs and implants share the grid with weapons
          are Greg's. Recommended: weapons and organs share it; implants get a
          body page.

OUT      Crafting, weight limits, sorting by generated names.
```

## 10. `cust-91-real-customisation`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      Character creation feels like shaping a body: face sliders on real
          shape keys, build and height, skin, scars, grime and hair, and a
          couple of choices that change how you play.

EXISTS    game/systems/face_model.gd — the face.
          game/systems/character_sheet.gd — who you are, as data.
          game/systems/character_presets.gd — presets.
          game/systems/vat_body_preview.gd — the body witness.
          game/systems/vat_intake.gd and intake pages — the form.
          tests/intake_body_test, character_presets_test, face_model_test.

OWNS      face_model.gd, character_sheet.gd, vat_body_preview.gd, the intake's
          FACE tab, their tests. vat_chamber.gd: additive only.

BUILD     Sliders move real shape keys on one face, one at a time, and the body
          in the vat changes with them. Build, height, skin, scars, grime and
          hair are sheet fields with visible consequences on the preview.
          Two sheet choices carry a small gameplay effect, and the sheet says
          which. Whatever the sheet holds is what the route spawns.

PROOF     A capture of a face changed by one slider, before and after, and the
          same body standing in the arcade afterwards. Opened.

TESTS     intake_body_test and face_model_test extended; a preset round-trip;
          --core green.

OPEN      Which two choices carry an effect is Greg's. Do not choose mechanics
          for him; build the plumbing behind a dial and report.

OUT      New races, new traits, the natal chart, costume.
```

## 11. `route-88-systems-on-the-route`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      The lab's best systems are in the route: the X-ray reads the arcade
          guards, organs can be ripped from a body you opened, and Duelist and
          Shade have their verbs where the player actually fights.

EXISTS    game/systems/organ_system.gd — wounds open the chest, rip, install,
          sell; lab only.
          game/systems/xray_scan_overlay.gd, world_xray.gd — the scan.
          game/systems/facility_guard_post.gd — the guards on the route.
          game/systems/examiner_fight.gd.
          game/systems/combat_input_layer.gd — discipline verb overrides.
          tests/first_thirty_route_test, facility_one_map_walk_test.

OWNS      organ_system.gd, xray_scan_overlay.gd, combat_input_layer.gd, the
          route's encounter data, their tests. bone_yard_hunt.gd and
          vat_chamber.gd: no edits.

BUILD     A route guard can be scanned before the fight, and after it can be
          opened and relieved of an organ through a wound the player made.
          Duelist and Shade verbs work on the route's guards: parry → riposte,
          and the rear takedown with its own tell.
          Everything writes through the systems that already own the numbers.

PROOF     A short route recording: scan a guard, fight him, open him, take the
          organ. A capture of the X-ray on a route guard, opened.

TESTS     first_thirty_route_test and facility_one_map_walk_test stay green;
          organ and discipline suites green; one route test asserting the scan
          reads a route guard. --core green.

OPEN      Which organs are worth having on the route (balance) is Greg's.

OUT      The lab stations, new organs, the examiner's fight balance.
```

## 12. `vat-imp-66-room`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish.

GOAL      The vat room is a place you wake in, not a set: decluttered, lit, and
          the broken tank is a thing you cannot walk through.

EXISTS    game/vat_chamber.gd — the room, the tank, the breakout.
          game/systems/tank_view.gd, vat_horror.gd, glass_tank.gd,
          fluid_body.gd, vat_float.gd.
          game/systems/room_lights.gd — per-room light.
          tests/hands_on_breakout_test.

OWNS      vat_chamber.gd (this brief owns it), room_lights.gd, their tests.

BUILD     Give the broken tank stub a real collision shape so the player cannot
          walk through glass that is still there.
          Remove the set dressing that has no job, and give what remains a
          reason: the drain, the gurney, the camera, his chair.
          Light the room as one place — a source, a bounce, a shadow — rather
          than a flat fill.
          Measure the room's frame cost before and after.

PROOF     Two captures: waking, and standing after the breakout beside the stub,
          opened. The frame cost in the commit message.

TESTS     hands_on_breakout_test and the vat suites green; a new assertion that
          the stub blocks the player. --core green.

OPEN      The room's final art is Greg's; build the collision, the declutter and
          the light, not new furniture models.

OUT      New props, new vat mechanics, the intake UI.
```

## 13. `fix-95-105-stability`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking.

GOAL      The route quits cleanly and does not crash. A build can be handed to
          someone without a caveat.

EXISTS    ragdoll bodies can crash the game on quit (tracked as fix-95).
          The opening test reported quit-time leaks (fix-105).
          The Hunt's Jolt job pool was fixed in fix-103 / fix-104; the route
          harnesses now cross one physics step after freeing a map.
          tests/first_thirty_route_test, demo_route_test, first_run_walk_test,
          body_restart_test, chunk_test.

OWNS      ragdoll_body.gd and whatever owns the quit path it touches; the route
          harnesses; their tests.

BUILD     Reproduce the ragdoll quit crash, find the root cause (a freed body
          still referenced by a queued callback or a static), fix it there.
          Clear the remaining exit-time object and RID counts the route
          harnesses report, or state per item why they cannot be cleared.
          No suppressions, no skipped assertions, no test weakened to pass.

PROOF     Run each affected suite five times: same result, exit code 0, no crash.
          The counts before and after in the commit message.

TESTS     first_thirty_route_test, demo_route_test, first_run_walk_test,
          body_restart_test and --core green, five runs each.

OPEN      none.

OUT      Performance work (that is measured separately), new content.
```

## 14. `polish-50-sound-timing`

```text
Load skills: wof-lane-hygiene, wof-verify-by-looking, wof-wire-before-polish,
build-game-audio-feedback.

GOAL      Every blow, every cut and every step is heard, and heard at the frame
          it happens. Greg can listen to a checklist and answer yes or no.

EXISTS    game/systems/strike_audio.gd — two synthesized swing voices.
          game/systems/audio_bus.gd — the bus graph.
          game/systems/strike_trail.gd, impact_feel.gd — the timing to match.
          game/systems/ambient_audio.gd, opening_audio.gd — the rooms' beds.
          DESIGN/STYLE_RULES.md §8: a sound without a source is an effect.

BUILD     Swing, contact, block, parry, sever, glass, liquid and footstep each
          have one voice, routed through the bus, started on the frame the
          event resolves, and audible over the room bed.
          Nothing plays on a guessed delay; every start reads the same number
          the visual does.
          A listening pass, written as a checklist Greg can run: ten sounds,
          where to stand, what to do.

PROOF     The checklist, and a recording of one fight with each sound named in
          the commit. Say plainly which sounds you could not judge by ear.

TESTS     audio suites green; one assertion that each event fires a player at
          the same frame as its visual. --core green.

OPEN      Whether any of it is music is Greg's; this brief is effects and beds.

OUT      New music, voice acting, the radio.
```

---

## Superseded

These are dead as dispatch sources. They stay for their reasoning.

| Document | Why it is superseded |
| --- | --- |
| `DESIGN.md` §"the pyramid becomes 33 tiers" (24 Sep) | Never built. The ladder is five bands with 40 seats (`THE_LADDER.md`) |
| The Dust to Bones plate's §X briefs | Vertebra 5 shipped as `FacilityGuardPost`; the plate's count of branches and its worktree are both stale |
| `OVERNIGHT_GOALS.md` (29 Sep) | Run complete; every item is DONE, ALREADY, BLOCKED or LEFT, with reasons |
| `DESIGN/BUILD_BRIEFS.md` (v0.1 jobs 1–8) | All eight landed |
| `DESIGN/CODEX_BRIEFS_2026-09-29.md` | Brief B landed as the styles work; Brief A's frame target is measured, not queued |
| `DESIGN/GAME_PLAN_V2_DRAFT.md` §3 | Its v0.2 order is real work but no longer the queue; it follows the tag |
| `goal/SKILL.md` "combat overhaul" line | Cut into briefs 5–8 |

## After the fourteen

In order, and only after the tag: the rest of combat (G3 fragments, G4 dragging a
body, G5 one clock for gore, C6 clinch, C7 movement into a strike, C8 no health
multipliers); then the v0.2 list from `GAME_PLAN_V2_DRAFT.md` — the Black Mirror
as one device, the Support Unit, the drains route, the doctor chase, more
disciplines, vehicles, the Wire.

## Appendix: enRAGE, what is inside it

Read from `NemesisMod.dll`'s metadata on 23 October 2026. The mod's licence
permits decompiling to learn from it; re-sharing its source does not.

**The person it simulates:** `Rank`, `RankXp`, `RankYears`, `Scars`,
`LastScaredMin`, `PresumedDead`, `GrudgeSettled`, `CrippleLevel`,
`ActiveSurrendered`.

**The scar:** typed by cause (`BladeScars`, `ArrowScars`, `BurnScars`,
`BeatingScars`, `ClawScars`), produced by `ScarFromWound` → `PickScar` →
`ApplyScars`, and queried per person as `ScarredByYou`.

**The hierarchy:** `DrawHierarchy`, `PromoteWithinTiers`,
`BackfillFallenLeaders`, `ArchiveFallen`, `AssignChain`, `RankOfId`,
`ApplyRankStats`, `CheatDeathPerRank`.

**The standing:** `AddNotoriety`, `AddYourNotoriety`, `NotorietyBand`,
`DrawGrudgeMeters`, `AddGrievance`, `AddRegard`, `AddHate`, `AddFear`,
`AddVerdicts`, `AddFatePast`.

**The world around it:** `AmbushChancePercent`, `AmbushIntervalSeconds`,
`AgendaWarMult`, `AgendaAmbushMult`, `AddPurse`, `AddSupplies`, `AddCampHere`,
`TownWarTier`, `TownTierPercent`, `MaybeSpawnSurvivors`, `SurvivorRole`.

**The X-ray log:** `DrawXRay`, `WoundTrack`, `InjuryList`, `LatestWound`,
`MarkWounded`, `BonePoint`, `BoneColor`, `BoneThickness`, `AllBones`,
`MoveForeignXRays`.

**Taken:** the grammar only — seats that refill, scars as typed records of a
specific wound, tenure and XP on a rank, cheat-death scaling with rank, a
notoriety band with a stated aim, and standing split into grievance, regard,
hate and fear rather than one number. All of it maps onto systems this repo
already owns: `pyramid_society.gd`, `world_history.gd`, `hunt_contracts.gd`,
`medical_monitor.gd`, `round_trails.gd`, `wound_marks.gd`.

**Not taken:** its names, numbers, assets, code or content. This is a reference
for what to build in Godot, not a source to port.

**Limit of this reading:** metadata and strings, not IL. A decompiler pass
(`ilspycmd` or `dnSpy`) belongs with brief 2 if the scar model needs more
detail than the above.
