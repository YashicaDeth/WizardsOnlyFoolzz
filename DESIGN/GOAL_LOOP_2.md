# Goal loop 2: finish minutes 0-30, then build minutes 30-60

Written 24 September 2026. It follows `DESIGN/GOAL_LOOP.md`, and everything
done there is folded in here.

Greg said that once the examiner, the intake pages, the combat overhaul and
the drain threats are done, minutes 0-30 are "right enough", and work moves
on to minutes 30-60: more tutorial, and the starting stage. This list does
that.

**(rec)** marks an assistant proposal, which stays a proposal until Greg
says yes. **ASK** marks a question box, recommended option first, and the
answer goes into `DESIGN.md` the same turn.

## Paste this to start it

> /goal Work `DESIGN/GOAL_LOOP_2.md` top-down, on your own, all night:
> section 0 (destruction physics) first, then everything after it in order.
> Branch `claude/dust-to-bones-look`. Read `AGENTS.md`, `DESIGN.md` and the
> project skills first.
>
> For every item:
> - Build the smallest version a player can do in the real route.
> - Record it in WorldHistory.
> - Render it and open the PNG; anything that moves gets a clip.
> - Add one small test, and get the core suite green.
> - Merge it.
> - Send me a Windows build named `WOF-<commit>` (split zip plus JOIN
>   bat). No editor bridge; LimboAI included.
>
> After every item, improve one skill, test or tool before starting the
> next one.
>
> Ask me question boxes, recommended option first, at every ASK below, and
> record my answers in `DESIGN.md` straight away. Don't wait on me: if an
> ASK blocks an item, build the recommended option behind the question and
> move on.
>
> Report what you actually verified and what you couldn't. Go.

## How a round goes

1. **Pick** the next unticked item.
   - Run `wof-wire-before-polish` first: wire what already exists before
     writing anything new.
2. **Build** the smallest playable version.
3. **Prove it:**
   - a render, or a clip for motion
   - one test
   - `--core` green
4. **Ship it:**
   - merge
   - a versioned build
   - a line in its checklist entry
5. **Ask** that item's ASK questions.
6. **Push the limit:** one skill, test or tool made better, committed.
7. Tick the item with its commit.

Rules that always hold:
- Stage by explicit path.
- Never commit `.import` or `.uid` churn.
- Never run `git clean` without paths.
- Never skip a test to get green.
- Only use subagents when they save real time, and brief them with
  `wof-agent-brief`.

---

## Done going in (for reference)

- **Skins and exchange:** skins, cases, the Wire exchange, and the jester
  set as parts.
- **Nudity and censors:** a body-cam glitch censor, on by default.
- **Rebirth:** every killer in minutes 0-30 sends you to the rebirth vat.
- **Brain Index hub:** Carry, Combat, Brain Index, Tasks and Map.
- **Combat:**
  - tiers, telegraphs, and enemy block and parry
  - the fight readout and sparring
  - the blood-tree moves: FEINT, COMBO, RIPOSTE, HIP COUNTER, BACKSTAB
- **The intake and the lab:**
  - animated intake pages (gears, ink, blood)
  - the lab's cables
- **Recheck:** all four ways out reach the Hunt at their own point, and the
  recheck list passed (`DESIGN/RECHECK_2026-09-24.md`).
- **The Growing Floor:**
  - the examiner's workstation moved off the aisle, beside the tank
  - the other tanks can be smashed, draining their fluid and freeing their
    subject

---

## 0. TOP PRIORITY: destruction physics (Greg, 24 September)

Greg: "does the game have destruction physics yet? If not, pull them all up
on the Dust to Bones map and add them to the top priority of the checklist."

The Dust to Bones page sits in another account and can't be edited from
here, so this is the list, and the page should link it.

### What exists today

| System | What it does | Where it's wired | Test |
|---|---|---|---|
| `BodySlice`, `GoreChunks` | Limbs sever along the cut plane and fly as rigid chunks; heads burst | Every body, everywhere | body_slice, chunk, skull_burst |
| `BreakableDoor` + `WorldDebris` | Condition 0-1, break states, persistent fragments | The doctor's door, Support Unit cells | breakable_door |
| `BreakableProp` | One collider while intact, then capped rigid fragments | **Derby only** | breakable_prop, derby_breakables |
| Derby cars | Panels, doors and hoods detach as debris | Derby | derby_breakables, derby_impact |
| `StreetLight` | Four break states, shed glass | Placed by the Ashbloom generator, but **nothing hits it** | street_light |
| `WorldDamage` | Condition kept in WorldHistory, which is the rule for all of it | Streetlights and doors only | world_damage |
| `VatSmash` (new) | Growing Floor tanks crack, break, drain and free their subject | Growing Floor | vat_smash |
| Wall strikes | A blade hitting a wall jars the arm and wears the edge | Hunt | wall_strike |

### What's missing, in order (each one: build, render, test, merge, build)

- [x] **0.1 Bullets and blades break things.** *Built:* `WorldBreak` is
      the one way in. A round's world hit and a blade's wall hit both
      reach it, and it speaks each breakable's language (streetlight
      condition, prop integrity, door weapon). There's a breakable yard by
      the sparring post: two streetlights shoot down to hanging, and two
      barricades burst into fragments that stay. `world_break_test`. Route every Hunt gunshot and
      melee hit that lands on something other than a body into one
      `WorldDamage` call. Streetlights, doors and props then react to
      gunfire and blows everywhere, not only where one scene wired them.
- [x] **0.2 `BreakableProp` out of the derby.** Crates, barrels, lockers,
      jars, monitors and chairs in the Hunt, the Service Arcade, the Lower
      Works and the drains, each with its own fragments and the shared
      debris cap. *Built at `8f6559c`:* six kinds, each with its own pieces;
      34 placed across the four scenes; the breach tool breaks them in the
      facility through `WorldBreak.swing()`; every hit filed by the prop's
      own name. `breakable_props_test`, `breakable_props_gallery`.
- **Greg's answer, 25 September** (`DESIGN.md`): the world is partly
  destructible, buildings and the ground included, and "if you shoot
  downwards with a gun or if you blow up the ground there will be an impact
  hole". So, ahead of glass (rec):
- [x] **0.2b Impact holes in the ground.** A round fired into the ground
      leaves a hole where it hit, sized by the calibre, that stays and is
      recorded. 0.5's blasts then leave bigger ones through the same call.
      Built first as the cheapest honest version (a sunken mark with a rim
      and kicked-up dirt, no terrain editing); the render of it carries the
      open question below. *Built:* `GroundHole.carve()` from
      `Ballistics._mark` on anything in the `ground` group (the Hunt's
      floor), about 5.5 cm of buckshot to 19 cm of rifle; a pit drawn by
      `ground_hole.gdshader`, a dirt lip, clods in a capped debris pool, a
      dust kick, and the hole's place and size in `round_struck_world`.
      `ground_hole_test`.
  - **ASK with that render:** "Is this the kind of hole you mean, or should
    the ground itself give way, Teardown-style?" **Greg: yes, keep these**
    (25 September evening).
- [ ] **0.3 Glass.** Windows, observation glass, screens and bottles shatter
      into real, persistent shards. The vat shards become physics shards
      instead of scripted ones, landing and staying on the grating.
- [ ] **0.4 Walls and cover that give.** Plasterboard, fences and
      barricades take condition and open holes in authored stages. Greg
      wants buildings partly destructible too, and answered how (question
      boxes, 25 September morning): walls, floors and building pieces
      crack, hole and break through in authored stages with real debris,
      not Teardown-style material removal. `DESIGN/DESTRUCTION.md`'s "no
      voxel fracture" scope stands.
- [ ] **0.5 Explosions.** Canisters, gas lines or a grenade: one impulse
      that pushes debris and bodies, damages everything in range through
      `WorldDamage`, and records it.
- [ ] **0.6 Vehicles outside the derby.** Hunt cars take the derby's panel
      damage, detaching parts and denting condition.
- [ ] **0.7 The world remembers.** Broken things stay broken across scene
      loads, and whoever owns a holding repairs it over game time.
- [ ] **0.8 Budget and feel.** A frame-cost cap per scene for live debris,
      hitstop on breaks (`wof-combat-fx`), and a sound for each material.
- **ASK after 0.1-0.3:** "Enough breakage, too much, or which things should
  break next?"

## A. Close out minutes 0-30

- [ ] **The personality test in the intake (rec).** Greg singled out "the
      personality test part" of the New Vegas opening (25 September). Ours
      is already written and scored (`CharacterSheet.ITEMS`,
      `score_instrument`, `aptitude_verdict`) and nothing calls it: picking
      INSTRUMENT on the intake form does nothing. Wire it in: the examiner
      asks the items, the subject answers the only way a tubed body can,
      his verdict is stamped on the sheet, and the scores set the stats.
      CHART is unwired the same way.
  - **ASK before building:** "Does the examiner read the questions aloud,
    or do they print on the intake pages for you to mark?"
- [ ] **Stopwatch every route (rec).** A route replay test times each of the
      four ways out, from the first frame to the Hunt. It writes a table
      into `FIRST_30_REBUILD.md`, so pacing changes show up as numbers.
  - **ASK:** "Which route felt longest, and was that good or bad?"
- [ ] **Threats in the old drains.** The drain stalker is there; give the
      drains a second threat, or a chase, so the second route costs
      something.
  - **ASK:** "Chase, ambush, or something that hunts by sound?"
- [ ] **A better 3D examiner:** an authored model, or a credited CC-BY one,
      instead of the rig head. He needs an ordinary face and a bloodied
      coat.
  - **ASK, with side-by-side renders:** "Which examiner?"
- [ ] **Use the intake's blank space** (Walkthrough 2): the empty paper
      under short pages gets the subject photo, stamps, or the procedure
      log.
  - **ASK:** "What goes in the blank space?"
- [ ] **The breakthrough reads as your soul seizing the implant:** wetwire
      feedback, and the chaos-magick interface waking at GET REVENGE.
  - **ASK first:** "The exact beat, and does third person unlock here?"
- [ ] **Carry icons:** a real icon for every item kind, including skins,
      cases, garments, guns and smokeables. No placeholder boxes left.
- [ ] **Breach-tool melee.** The ram swings, blocks and parries under the
      same tier rules as the cleaver.
- [ ] **More cameras, and doors that answer.** Every door you can reach in
      minutes 0-30 does something when used: opens, is locked with a
      reason, or can be broken. More cameras on the lab and the arcade.
  - **ASK with renders:** "Is this the wiring and camera density you
    meant?"
- [ ] **The derby's slow-motion kill cam,** on the real body.
  - **ASK after the first one plays:** "How slow, how long, how often?"
- [ ] **Rooms for the other claimants' vats** (a rival, a cult).
  - **ASK first:** "Who are the rival and the cult, and what does their vat
    room look like?"
- [ ] **Clean-ups:**
  - retire or rename `RunLifecycle`
  - replace `OpeningDeath` with `VatRebirth`
  - confirm `BlackMirrorCamera` is called in the route
- [ ] **The Handheld:** carry gets its own key, and it's made clear what I
      and U open.

## B. The first minute on the surface

- [ ] **The first thing you meet up top:** a person, a job poster or a
      threat, within 60 seconds of arriving by any of the four routes.
  - **ASK first:** "Who or what is the first thing you meet up top?"
- [ ] **A reason to go somewhere:** the stamped objective points at one
      place, and the map marks it.
- [ ] **The first fight is a readable tier.** A scavenger, telegraphing,
      where the Nix sparring post can teach it first.

## C. Minutes 30-60: the tutorial and the starting stage

Greg: "furthering the tutorial and the starting stage". Each item is the
smallest playable version first.

- [ ] **Write the 30-60 spine** in `DESIGN/THIRTY_TO_SIXTY.md`: beats,
      places and what each one teaches. A proposal for Greg.
  - **ASK before building:** "Does this spine match the game in your
    head? What's missing?"
- [ ] **The first job:** taken from a person or a poster, done in the Hunt,
      and paid in scrip. It's recorded in the ledger and the world
      remembers it.
- [ ] **Teach by doing:** each system the player hasn't touched yet
      (exchange, blood tree, sparring, smokeables, the handheld) gets one
      diegetic prompt the first time it matters, never a tutorial screen.
- [ ] **The first real death in the Hunt** goes through the rebirth vat.
      Your body stays on the surface, and you can walk back to it.
  - **ASK after:** "Did the walk back feel like a cost or a chore?"
- [ ] **A first home or safe place:** somewhere to sleep, stash things and
      change clothes (the wardrobe), and a place the Brain Index hub
      belongs to.
  - **ASK:** "Where is home: a shed, a squat, the doctor's bay, or a
    vat?"
- [ ] **The first case drop and the first sale** happen by minute 45,
      paced by drops, not handed out.
- [ ] **The first rival:** a named hunter who remembers you, and turns up
      again (the rival registry and return already exist; wire them into
      the first hour).
- [ ] **A second place on the map** worth walking to, with its own
      threat, loot and one secret.
- [ ] **An end to the first hour:** a clear moment that says the tutorial
      is over (a card, a call, or a door opening), recorded in the world.
  - **ASK:** "What ends the first hour?"

## D. Feel, sound and speed

- [ ] **A sound pass per beat** (law 15): the vat draining, the wires, the
      glass, Hollis's warning shot, the gate, the lift, a case opening, gold
      dropping.
- [ ] **A frame-time budget per scene,** measured in Forward+ and written
      down, with the worst scene fixed first.
- [x] **One controls sheet:** the pause menu's KEYS page reads the current
      scene's own keys card (or `keys_groups()`); the vat room has its own list.
      Still open: the `ControlBindings` decision. the same key caps in every scene, and a
      decision on the `ControlBindings` branch.
- [ ] **Hitstop and camera on the blood-tree moves:** a feint, a backstab
      and a hip counter each land with their own feel (`wof-combat-fx`).

## E. Tools that make every round faster

- [ ] **A `wof-build` skill:** one command that exports, versions, zips,
      splits, writes release notes and drafts the GitHub Release.
- [ ] **A `wof-playtest` skill:** logs narrated playtests into
      `playtests/<date>.md` and turns them into checklist lines.
- [ ] **A `wof-footage` skill:** the movie-writer reels, the 9:16 Reel and
      the 4:5 carousel, as one command.
- [ ] **Stale briefs:** `START_HERE.md` brought up to date.
- [ ] **Before merging anything visual,** a clip of it in the real route,
      not only a still.

## F. The site and the community

- [ ] **Make wizardsonlyfoolz.net go live.** These steps are Greg's: turn on
      Pages from `/docs`, and point DNS at it. Claude checks it afterwards.
- [ ] **Every build becomes a GitHub Release,** and the site's download
      button finds the latest one.
- [ ] **New footage on the site** after every item that moves.

## G. Question checkpoints while Greg plays

| When | What to ask |
|---|---|
| Before | What to try first, and what still bugs him from last time |
| After the intake | Did the pages and the examiner hold his attention? Is the blood too much or right? |
| At the breakout | Did tearing the wires feel like his choice? |
| At Hollis | Coerce or kill, and why? |
| First death | Did waking in the vat read? Did he care what he lost? |
| Route choice | Why that route? Did he know the others existed? |
| First fight | Were the telegraphs readable? Did he find a move? Which tier felt unfair? |
| The surface | What did he want to do first? |
| The exchange | Was the case worth opening? Sell or keep? |
| End of session | His top 3 fixes, in order. They go to the top of this list |

## H. Waiting on Greg

- Hollis's model.
- The examiner model.
- The doctor's name, history and vehicle.
- The anatomy downloads.
- When third person unlocks, and the breakthrough beat.
- Where the Board lives.
- The blade for Hollis's hand.
- The sky agency.
- How humiliating the jester outfit is.
- The map glitching (Walkthrough 2).
## I. For the Dust page


The Dust to Bones goal page lives in another account and cannot be edited from
this repo. Copy this row across when it next opens.

| Done | What | Proof |
|---|---|---|
| 26 Sep | **Base model kit for the opening, and the examiner's terminal moved to his end of the desk.** A shared low-poly base kit (`OpeningBaseModelKit`) with a gallery to judge it in (`opening_base_model_gallery`), so the examiner, the doctor and the guard stop being separate blocky placeholders. The terminal was 2.06 m from the man who uses it — a man beside a computer rather than at one — and now sits 0.93 m away at his end of the desk. **The desk itself did not move.** | `vat_station_clearance_test` measures it rather than eyeballing it: monitor clearance in world space, operator reach in the station's own local space. It fails on the old layout (2.06 m) and passes on the new (0.93 m), so it discriminates. `station_placement_test`, `opening_greeting_test`, `opening_handoff_test`, `opening_direction_test` and `captivity_procedure_test` all still green, so the doctor's walk to the glass is unchanged. |
| 26 Sep | **The earlier desk/terminal values were wrong for this branch and were re-derived.** A rescue pass had moved the desk to x -0.80 and the monitor to x -1.15, computed against an older `vat_chamber.gd` where the examiner stood at x -0.16. On the current file he stands at x -1.45, so those values put the monitor *inside his body* — measured overlap on all three axes. Kept the intent, dropped the desk move, re-derived the monitor position. | Both value sets were run through `vat_station_clearance_test`: the rescue's fail on overlap (`-0.53, -0.68, -0.34` per-axis gap), the new one passes. |
| Open | The station has **no visual proof yet.** `vat_station_sightline` runs and writes PNGs but every angle tried returns near-black, so the move is proven by measurement only. Someone still has to look at the room and confirm the screen reads well from inside the tank. | Harness and its known issue are documented in the file's header. |
| Open | The kit is geometry-only: no authored art has replaced it yet, and the examiner model still waits on the Higgsfield M1 sheet. | |
