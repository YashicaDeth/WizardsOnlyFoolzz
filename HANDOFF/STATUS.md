# Status (as of 5 Oct 2026, midday)



---
# Source: MORNING_REPORT.md

# Morning report for Greg, Mon 5 Oct 2026

First written 09:05 by the hourly manager. Later runs add to the end.

## In short

- **Landed in the game (claude/launch-latest):** 4 of the 10 v0.1 jobs. Those are job2b (rigged bodies on Jolt), lab-46 (real fluid and glass), job3 (cleaver, staff and pistol moveset) and job4 (waking in the vat). Each one passed the test gate before and after the merge.
- **Built but not merged yet:** lab-47 (Teardown destruction) has 2 commits and its first PNGs. lab-48 (organs, cybernetics and X-ray) has 1 commit. job5 (one facility map) has 2 commits, and its core suite passed 30/30. lab-52 (Duelist and Shade) has 1 WIP commit. All four were cut off by usage limits and resume when their accounts unpark.
- **Not started:** job6 (the examiner, hit the limit at once), job9 (enemies), job7 (death, saves and HUD), art-49.
- **Higgsfield credits spent: 0.** art-49 is still pending.
- **Accounts right now:** every account is parked. claude-alt2 unparks at 10:04 and codex-allusions-team at 09:56. Claude default and alt unpark at 13:04, codex sircuteskingdom-team at 13:34 and codex allusions-plus at 14:03. codex sircuteskingdom-plus is out until 11 Oct.
- **Game plan v2 draft:** skipped. Only 4 of 10 jobs have landed, and the draft waits for a majority.

## Which build to launch first

Launch the main tree **P:/GameDev/AllusionsTooGrandeur** (branch `claude/launch-latest`, HEAD d0a973f9). It holds all four landed jobs. The two maps to open are:
- the mechanics lab: `P:/GameDev/Start-MechanicsLab.cmd`, for bodies, liquid and glass, and weapons
- the opening: `P:/GameDev/PLAY.cmd`, for the vat wake-up

Check that PLAY.cmd points at this tree before you trust it. Earlier notes say it pointed at an old worktree.

## Per job

### job2b: rigged bodies on Jolt (landed)
- **Commits:** 8bef1102 (retry, gate green). The whole project now runs on Jolt.
- **PNGs:** `P:/GameDev/Temp/job2b_retry_shots/` (`bodies_rigged.png`, `bodies.png`, `bodies_wounded.png`).
- **Works:** every dummy stands on the mannequin skeleton. A cut arm lies on the floor with its skin on. A shot dummy falls as a jointed ragdoll. X-ray under the skin is tested.
- **Weak:**
  - The skin reads as a checker pattern, not flesh.
  - The heads look like helmets with goggle eyes.
  - The idle pose is a hunched zombie crouch.
  - There are dark gaps at the ankles.
  - The station sign covers the bodies.
  - At 5 m, X-ray on looks almost the same as X-ray off.
  - `fix-job2-body-look` is queued at priority 70.
- **Dial chosen for you:** the player uses the same base body as everyone else (your decision). See question `rigged-bodies-02`.
- **Still owed:** a full `--all` test run on Jolt (vehicles and doors are unchecked), and a crash on exit seen 2 times in 12 runs of `gore_range_reset_test`.

### lab-46: real fluid and glass (landed)
- **Commit:** adf305a3. It adds `systems/glass_tank.gd` and `systems/fluid_body.gd`, shared with the vat.
- **Works:**
  - The glass cracks in stages, then bursts into 48 thick shards that stay.
  - The pour is thick and lasts about 6 s.
  - The pool persists and drains slowly to a grate.
  - Wading makes ripples, splashes and footprints.
  - The wet floor conducts the shock staff.
- **Weak:**
  - **There is no PNG yet**, so the look is unverified.
  - The pour is drawn as overlapping spheres, not a liquid surface.
  - The pool flows under the plinth.
  - There is no sound.
  - `remaster-lab-46-p1` is pending and must take the first render.
- **Dials chosen for you:** 4 blows to break the glass, 6 s pour, 60 L spill, about 8 L a minute through the drain, shock damage 14. See question `lab-46-shock-damage`.

### job3: moving and fighting (landed)
- **Commits:** f4a4f790 and 2170f4e2, merge d2edfaa2.
- **Works:**
  - HOTLINE CLEAVER, PRODSTAFF and MERCY NINE with aim down the barrel, in the lab.
  - The carried cleaver fights the numbered guard in the Service Arcade on R1/R2/L1/L2.
  - Block, parry, hitstop, stagger and heat.
- **Weak:**
  - No PNG.
  - The arcade still uses its own movement, so there is no roll on the route.
  - The staff and the pistol exist only in the lab.
  - The Hunt still gives you the old sword.
  - Swings and hits make no sound.
  - The first-person swing is a pose offset, not an animated arm.
  - `remaster-job3-p1` is pending.
- **Dials chosen for you:** the cleaver's heat costs nothing (`heat_cost = "none"`; an "overheat" option is built). World hitstop is on. The parry window is 0.24 s. The staff moveset uses the defaults. See questions `moving-and-fighting-01` and `-02`.

### job4: waking in the vat (landed)
- **Commits:** cc588c60, merge 7795e103.
- **Works:**
  - The vat opens with the controller.
  - The glass and the flood use the real GlassTank and FluidBody.
  - The brain screen picks your 2 disciplines.
  - There is no belt.
  - Your eyes open slowly on the hand-over.
- **Weak:**
  - No PNG.
  - The broken tank stub has no collision, so you walk through it.
  - The room is not decluttered.
  - Frame rate in the vat room is not measured.
  - The old line "THE WATER'S GOING" no longer shows.
  - `remaster-job4-p1` is pending.
- **Waiting on you:** `waking-vat-02`, your own line for each vat beat. Current lines are from 28 Sep.
- **Dial chosen for you:** the discipline pair has no effect yet (`PAIR_RULES`). See question `waking-vat-01`.

### lab-47: Teardown destruction (built, not merged)
- **Commits on hub/lab-47-teardown-destruction:** dfdbe4cc and d8e5be56. They add tiered voxel destruction, diggable ground and a breach corner.
- **PNGs:** `P:/GameDev/Temp/lab47/` (1_intact to 6_settled).
- **What I saw:**
  - Digging works: there is a smooth trench with a lip and cube debris.
  - The walls show bullet holes and a small crumble of cubes.
- **Weak:**
  - After a charge the HUD still says `BROKEN 0/11`. The counter or the break looks wrong.
  - The charge only knocked a small notch out of the wall.
  - The dug ground is flat beige with no texture.
  - The big "DESTRUCTION REBUILD" sign covers the shot.
  - The HUD still shows the acid line, although acid is meant to be a lab demo only.
- **Resumes** when claude-default unparks at 13:04, or on alt2 at 10:04 after lab-48.

### lab-48: organs, cybernetics and X-ray (built, not merged)
- **Commit:** 71b76e38 (OrganSystem).
- **Works:**
  - Wounds open the chest.
  - You can rip organs out by hand, through a wound only.
  - Each organ fails its own way.
  - The staff shorts out implants.
  - The X-ray scan shows organs and implants.
  - You can swap organs into yourself or sell them.
- **Waiting on you:** `lab-48-organs-implant-effects` (what each implant does). The proposals are behind dials.
- **Next:** priority 98, first in line on claude-alt2 at 10:04.

### job5: one facility map (built, not merged)
- **Commits:** f65fd072 and 9a9e7dc5. The map is one continuous level with the authored arcade and Lower Works embedded.
- **Tests:** the core suite passed 30/30.
- **Stopped because** the Codex workspace ran out of credits. It is pending and is likely to resume on codex-allusions-team at 09:56.

### job6: the examiner. job9: enemies. job7: death, saves and HUD.
Not started. job6 hit the session limit as soon as it launched. They are queued at priorities 94, 93 and 92.

### art-49: Higgsfield art
Pending. It runs only on claude-alt2, after lab-48. **0 of 150 credits spent.**

## Decisions waiting for you
All of these are in `P:/GameDev/AgentHub/queue/questions/`:
- `waking-vat-02`: your lines for each vat beat, including one for the brain screen. **Only you can answer this one.**
- `lab-48-organs-implant-effects`: what each implant does.
- `lab-46-shock-damage`: how hard the wet-floor shock hits.
- `moving-and-fighting-01` and `-02`: does cleaver heat cost anything, and the staff's extra moves.
- `waking-vat-01`: does the discipline pair matter? I suggest it waits until there are 3 disciplines.
- `rigged-bodies-01` and `-02`: you already answered both (Jolt, one shared body). They can be closed.
- In the 05:33 notes, the manager committed your 01:48 edit to the Destruction card in GAME_PLAN.html, which had not been committed. Revert it if the wording is not yours.

## Known infrastructure issues
- Windowed Godot PID 28648 (the editor) has been open all night. That blocks the manager's own renders, because only one window may be open at a time.
- `render_one.cmd` was added at 08:35. Builders before then skipped their PNGs, so lab-46, job3 and job4 have no images.
- `hidden_cache_test` fails 2 checks on trunk. This was already failing before tonight's work.

## Update 10:03
- Nothing new has merged since 09:05. The last merge was job4 (7795e103).
- **Accounts:** claude-default and claude-alt are parked until 13:04, and claude-alt2 until 10:04. lab-48 (priority 98) runs on claude-alt2 next, then art-49. Codex: codex-allusions-team is ready, so job5 (priority 95) should restart at the 10:07 tick. The other Codex accounts are parked until 13:34, 14:03, and 10-11 for sircuteskingdom-plus.
- **Game plan v2 draft: skipped.** Only 4 of the 10 v0.1 jobs have landed (job2b, lab-46, job3, job4). It needs 6.
- **Launch first:** P:/GameDev/PLAY.cmd on claude/launch-latest. It includes job3 (cleaver fights in the arcade) and job4 (vat wake, real glass and flood).

## Update 10:33
- **Landed:** fix-hidden-cache-test (e93bc8d0). The old `hidden_cache_test` failure on trunk is fixed, so that line under Known infrastructure issues no longer applies.
- **Running:** lab-48 (organs, cybernetics and X-ray) on claude-alt2 since 10:07.
- **job5** hit the Codex limit again after its 10:07 restart. It resumes when a Codex account unparks (earliest 13:34).
- **Still 4 of 10 v0.1 jobs landed.** The game plan v2 draft stays skipped. Launch PLAY.cmd first, as before.


---
# Source: REMASTER_LOG.md

# Remaster log

One entry per remaster pass (see the dispatcher's remaster loop). Newest last.
Each entry: date, job, pass, the three gaps seen, what changed, PNG paths, what is still weak.

## 2026-10-05, Job 1 (mechanics lab), look before pass 1 (Claude, Opus)
Rendered with `tests/mechanics_lab_capture.tscn`, PNGs in `P:/GameDev/Temp/mechanics_lab/`.
- Works: all five stations load; the tank breaks and pools (16 pools); rain, wind, etch and the covered/open acid test run; ground holes and broken crates show.
- Weak: the liquid is a flat red decal plus loose red beads, not liquid (no surface, no flow, no splash; SPLASHES 0); no visible glass tank after the break; the weather shot reads as white streaks on a dark box; the yard is an untextured brown tray; placeholder text HUD in the corner; the held weapon is not visible; the melee is a camera ray, not the moveset (job 3 replaces it).

## Manager notes, 2026-10-05 02:18

- Merged since last entry: nothing. Running: 0. Every Claude account parked until 03:04 (alt2 04:54); codex-allusions-team 04:42, -plus 07:51, sircuteskingdom-team 07:14 (out of credits).
- Weak spot: `codex-sircuteskingdom-plus` shows "ready" in `hub.py status`, but its job5 log (01:14) says its usage limit lasts until **Oct 11, 12:21 PM**. The hub has handed job5 to it three times; the limit text ("Oct 11th, 2026 12:21 PM") seems not to be parsed into a park. Greg: check the park-time parser in hub.py (manager does not edit hub.py).
- Failures: `job2-rigged-bodies` superseded by pending `job2b-land-rigged-bodies` (priority 100). `lane-exit-routes` is an old lane task, left alone.
- Priority headers match the order (job2b 100 > lab-46 99 > lab-48 98 > lab-47 97 > job3 96 > job4/job5 95 > job6 94 > job9 93 > job7 92 > art-49 85 > backlog 40-46). No new task queued: pending already covers every account.
- Top three: (1) land job2b first when Claude accounts unpark at 03:04; (2) fix the codex park parser so job5 stops burning attempts; (3) job5/job7 are the only codex work, so with codex mostly parked until ~07:00 the facility map may slip; consider flipping job5 to `agent: any` if still pending at 07:00.

## 2026-10-05, Job 3 (moving and fighting), build pass (Claude, Opus)
Not rendered: `render_one.cmd` is not on this machine. `tests/v01_weapons_capture.tscn` is ready (writes held_*.png, cleaver_swing_NN, cleaver_hot, staff_shock_NN, pistol_ads, sparring_NN into `--shots=`).
- Built: HOTLINE CLEAVER and PRODSTAFF (Greg's working names) in `HunterArsenal`, `SwordMoveset` and `HeldGear`; `MeleeDriver` (buffer, hitstop, kick, stagger, heat, shock, block/parry); `SoulsMover` (tilt walk/run, sprint, crouch, roll); lab ADS and R3 lock-on; a sparring partner; the Growing Floor's fire axe is the cleaver.
- Dials (Greg's to decide, defaults mine): `MeleeDriver.heat_cost = "none"` ("overheat" built); `MeleeDriver.world_hitstop = true`; staff running/roll moves; parry window 0.24 s. Questions: `AgentHub/queue/questions/moving-and-fighting-01.md`, `-02.md`.
- Still weak: models are built in code, not CC0 downloads; the Hunt still issues the old `sword` (labelled ASHLINE CLEAVER) in its slot; the facility route has the cleaver in hand for the door but no melee fight wired yet (jobs 5/6 own those rooms; `MeleeDriver` is the piece to use); no sound on swings or hits; first-person swing is a pose offset, not an animated arm.
- Wired (second pass): a carried HOTLINE CLEAVER is now the Service Arcade's melee weapon through `MeleeDriver` (R1/R2/L1/L2); it cuts the numbered guard via `FacilityGuardPost.land_blow` (same history as the ram, event `facility_guard_cut`). The breach ram moves to the off hand beside it and still forces the gate. Arcade movement is still the arcade's own (sprint, slide), not `SoulsMover`. Test: `arcade_cleaver_test`.

## Manager notes, 2026-10-05 05:33

- Merged since last entry: nothing. Running: 0. Claude default/alt parked to 08:04; codex team 07:14, allusions-plus 07:51, allusions-team 09:56, sircuteskingdom-plus to 10-11 (park parser now works). claude-alt2 ready.
- Blocker found: `job2b-land-rigged-bodies` passed its Jolt gate (7/7, hub/job2b at 4d8900c2) but the merge was deferred every retry because `DESIGN/GAME_PLAN.html` was dirty in this worktree (01:48 edit of the Destruction card). The edit restates Greg's 10-05 decision (Teardown voxels, diggable ground, five tiers, melee 1-2 / guns 1-3 / explosives 1-4), so the manager committed it as is rather than discard it. Greg: revert that commit if the wording is not yours.
- Failures: `job2b-land-rigged-bodies` requeued to pending (cause: merge deferred, dirty worktree, now fixed). `job2-rigged-bodies` superseded; `lane-exit-routes` old lane task, left alone.
- Still open from the job2b run: `gore_range_reset_test` crashed on exit (139) in 2 of 12 Jolt runs after failures=0; full `--core`/`--all` not yet run on Jolt (vehicles, doors unchecked); nothing rendered.
- Top three: (1) land job2b on the next tick (claude-alt2) and render bodies on Jolt; (2) a follow-up task for the Jolt exit crash and full-suite run on Jolt, queued below; (3) lab-46 liquid and glass next when Claude accounts unpark at 08:04.

## 2026-10-05, Job 2b retry (rigged bodies on Jolt), look after landing (Claude, Opus)
Rendered once with `tests/mechanics_lab_capture.tscn` (one window, `--position 2240,320`, 1600x900), PNGs in `P:/GameDev/Temp/job2b_retry_shots/`: `bodies_rigged.png` (new: four untouched rigged dummies up close), `bodies.png` (arm cut, one shot dead into its ragdoll, X-ray on), `bodies_wounded.png` (new: same, X-ray off, close). The other station shots were rendered too and not reviewed for this job.
- Works: all four dummies stand on the mannequin skeleton with heads and ordinary shoulders; the cut arm lies on the floor wearing its skin; the shot dummy is down as a jointed ragdoll by the plinth, not loose boxes; blood marks on floor and back wall. X-ray under a skin is now tested (`rigged_body_test`: skin hides, zones go see-through, organs show, skin returns).
- Weak: the skin texture reads as a fine checker/crosshatch at mid range, not flesh; heads read as helmets with goggle eyes; the idle is a hunched zombie crouch, arms hanging; dark gaps at the ankles/soles on every dummy; at 5 m the X-ray shot looks almost the same as X-ray off (organs too small to read at that framing); the station's "BODIES / X-RAY ON / OFF" sign is huge and covers the bodies in every close shot; placeholder HUD text in the corner.

## 2026-10-05, lab-46 real fluid and glass (Claude, Opus)
Greg: "it shouldn't instantly dissipate and it should be an actual fluid as well as an actual glass."
- New shared pair for the lab and the opening vat (Job 4): `systems/glass_tank.gd` (refracting tinted glass with fresnel edge and two skins for thickness; cracks in stages per blow; burst at the last blow into 48 runtime-split thick shards thrown out by the fluid's head; shards physics, shared cap 96, oldest recycled, kickable; tank surface sloshes on hits and bumps, ripples, drains Torricelli-style to the jagged stub; a floater bobs in it) and `systems/fluid_body.gd` (CPU SPH-lite pour of up to 260 blobs, ray-colliding, drawn as stretched overlapping spheres; a depth-grid pool that keeps a 3 mm film, creeps to a floor grate and drains; ripples; wading splashes and prints via Footprints; floaters drift; shock floods the connected wet cells and hits whoever stands in them, with arcs and a flash).
- Dials: GlassTank blows/pour_seconds/pressure/spill_volume; FluidBody viscosity/drain_rate/film/shock_damage/shock_impulse/shock_seconds. Defaults: 4 blows, 6 s pour, 60 L to the floor, ~8 L to the grate per minute, shock 14.
- Shards: runtime split, not Blender cells: fits any tank size with no asset, and the break line is shared exactly with the standing stub.
- Measured headless: fluid sim worst 1.2 ms a frame at ~110 airborne blobs (CPU only).
- Not looked at: no render_one.cmd exists, so the PNG sequence (`tests/fluid_glass_capture.tscn`) and the real-GPU fps are not taken. Shaders are not compiled by the headless dummy renderer, so a shader error would only show in a windowed run.
- Weak: the pour is overlapping spheres, not a screen-space surface; the pool sheet ignores obstacles (flows under the plinth); no sound yet.

## Manager notes, 2026-10-05 06:54

- Merged since last entry: `job2b-land-rigged-bodies-retry` (8bef1102, bodies on Jolt, gate green) and `lab-46-real-fluid-and-glass` (adf305a3, GlassTank + FluidBody, ran 06:37-06:52). Running: `lab-48-organs-cybernetics-xray` on claude-alt2 since 06:52. Every other account parked (Claude default/alt 08:04; codex team 07:14, allusions-plus 07:51, allusions-team 09:56, sircuteskingdom-plus to 10-11).
- Not rendered this run: a windowed Godot (plain editor/project manager, PID 28648, no args) is already open, so the lab-46 capture was skipped. lab-46 itself never took its PNGs, so its look is still unverified.
- Weak (from the job2b retry shots): the skin reads as a fine checker, not flesh; heads read as helmets with goggle eyes; hunched zombie idle; dark gaps at the ankles; the station sign covers the bodies; X-ray at 5 m is almost the same as X-ray off. lab-46 (from its own log): the pour is overlapping spheres, the pool flows under the plinth, no sound.
- Failures: `job2b-land-rigged-bodies` superseded by the landed retry; `job2-rigged-bodies` superseded; `lane-exit-routes` old lane task, left alone. Nothing new.
- Top three: (1) fix the body look (queued `fix-job2-body-look`, priority 70, claude, Job 2); (2) lab-46 remaster pass 1 with its first real render (queued `remaster-lab-46-p1`, priority 60, a fast finisher); (3) once Claude accounts unpark at 08:04, keep lab-47 (97) and job3 (96) flowing; still owed: a full `--all` run on Jolt (vehicles, doors).

## Manager notes, 2026-10-05 07:33

- Merged since last entry: nothing. Running: `job5-facility-one-map` on codex-sircuteskingdom-team since 07:22. Claude default/alt parked to 08:04; allusions-plus 07:51, allusions-team 09:56, sircuteskingdom-plus to 10-11. claude-alt2 ready.
- Lost run: `lab-48-organs-cybernetics-xray` on claude-alt2 (06:52) exited after "Still running; I'll be notified" — the agent backgrounded a command and the headless session ended with it. Hub put it back in pending; the manager appended a foreground-only run note to its prompt so the retry (next tick, claude-alt2) does not repeat it.
- `lab-52-duelist-shade` (codex team) wrote a final report but sits in pending again; its own note: no PNGs because `render_one.cmd` does not exist. Dials left provisional (1.0 s riposte, x2 damage, 2.15 m takedown, 8 s darkness, 13 m/s throw).
- Repeated gap: lab-46 and lab-52 both looked for a missing `render_one.cmd`, so neither verified its look. Briefs should name the capture command directly: `Godot_v4.7.2-stable_win64.exe --path game --position 2240,320 res://tests/<name>_capture.tscn`.
- Failures: unchanged (job2/job2b superseded, lane-exit-routes old). Nothing new.
- Top three: (1) lab-48 retry lands on claude-alt2 next tick; (2) at 08:04 Claude default/alt pick up lab-47 (97), job3 (96), then `fix-job2-body-look` and `remaster-lab-46-p1`, which must take the first real fluid/glass PNGs; (3) a full `--all` run on Jolt is still owed.

## Manager notes, 2026-10-05 08:35

- Merged since last entry: `job3-moving-and-fighting` (f4a4f790, merge d2edfaa2, gate green, ~25 min). The HOTLINE CLEAVER now fights in the Service Arcade (R1/R2/L1/L2, blows land on the numbered guard). Its own verdict: PARTIAL.
- Weak (concrete): no PNG taken, so held weapon, swing and hit feedback are unseen; the arcade keeps its own walk/sprint/slide instead of SoulsMover (no roll in the route); PRODSTAFF and MERCY NINE are lab-only; The Hunt still issues the old `sword`; no swing/hit sounds; weapon meshes built in code with no CREDITS lines.
- Not rendered by the manager this run: a Godot Project Manager window was already open (one-window rule).
- Fixed the repeated gap: `P:/GameDev/AgentHub/render_one.cmd` did not exist although the hub's builder rules point at it (lab-46, lab-52, job3 all skipped their looks). Added it: `render_one.cmd <capture_name> [args]`, one window at a time via a lock dir in P:/GameDev/Temp, `RENDER_REPO` picks the worktree.
- lab-47 (claude-default) wrote a full report (voxel tiers, diggable patch, timings) but was requeued by the hub; branch hub/lab-47-teardown-destruction holds 2 commits and the retry resumes it. Running: job4 and lab-48 on claude-alt.
- Failures: unchanged (job2, job2b superseded; lane-exit-routes old). `hidden_cache_test` fails 2 checks on trunk before job3 (stash registry, 9 hidden things vs 5-8): pre-existing.
- Top three: (1) queued `remaster-job3-p1` (70, claude): render via render_one.cmd, SoulsMover in the arcade, staff and pistol in the route, Hunt sword to cleaver; (2) lab-47 retry must take its first PNGs now that render_one.cmd exists, and fix the old `Wall_*` lookup in mechanics_lab_capture.gd; (3) a small codex fix for `hidden_cache_test` once a codex account unparks.

## Manager notes, 2026-10-05 08:54

- Merged since last entry: `job4-waking-in-the-vat` (cc588c60, merge 7795e103, gate + post-merge gate green, ~34 min). Vat opens on the pad, real GlassTank/FluidBody glass and flood, brain screen, no belt, eyes open slowly on the hand-over.
- Weak (concrete, from its report): no PNG taken; the broken tank stub has no collision (walk-through); brief item 7 (declutter/enlarge the room) not done; vat-room fps unmeasured; Hunt does not start in third person; old "THE WATER'S GOING" line gone. Questions filed for Greg: `waking-vat-01` (mismatched discipline pair, default no effect, dial `PAIR_RULES`), `waking-vat-02` (his own lines per beat).
- Not rendered by the manager: windowed Godot PID 28648 still open (one-window rule).
- Every account parked: Claude default/alt to 13:04 (session limit hit by lab-47, lab-48), claude-alt2 to 10:04, codex allusions-team 09:56, sircuteskingdom-team 13:34, allusions-plus 14:03, sircuteskingdom-plus to 10-11. lab-47 and lab-48 were cut off and sit in pending to resume.
- Failures: unchanged (job2, job2b superseded; lane-exit-routes old).
- Top three: (1) queued `remaster-job4-p1` (70, claude): render the vat, collide the stub, declutter the room; (2) lab-48 (98) and lab-47 (97) resume first when claude-alt2 unparks at 10:04; (3) a codex fix for `hidden_cache_test` when allusions-team unparks at 09:56.

## Manager notes, 2026-10-05 09:05

- **Merged since last entry:** nothing. Running: 0. Every account is parked: claude-alt2 until 10:04, Claude default/alt until 13:04; codex allusions-team 09:56, sircuteskingdom-team 13:34, allusions-plus 14:03, sircuteskingdom-plus until 10-11.
- **Unmerged work waiting to resume:**
  - lab-47: 2 commits plus PNGs in `P:/GameDev/Temp/lab47/`.
  - lab-48: 1 commit.
  - job5: 2 commits, `--core` 30/30. Codex ran out of credits mid-run.
  - lab-52: a WIP commit.
- **Weak (lab-47 PNGs):**
  - After the charge the HUD still reads `BROKEN 0/11`.
  - The charge only notches the brick wall.
  - The dug ground is flat beige.
  - The "DESTRUCTION REBUILD" sign covers the shot.
  - The `ACID ON YOU` line shows although acid is meant to be off.
  - These notes were appended to the pending lab-47 task.
- **Not rendered:** windowed Godot PID 28648 is still open (one-window rule).
- **Failures:** unchanged. job2 and job2b are superseded; lane-exit-routes is an old task.
- **Morning report:** written to `P:/GameDev/AgentHub/MORNING_REPORT.md`. Game plan v2 skipped: 4 of 10 v0.1 jobs have landed.
- **Top three:**
  1. Queued `fix-hidden-cache-test` (70, codex) for when codex unparks.
  2. lab-48, then lab-47 with the PNG notes, on claude-alt2 from 10:04.
  3. job5 lands on codex-allusions-team at 09:56. Then job6, job9 and job7 at 13:04.

## Manager notes, 2026-10-05 10:03
- Nothing has merged since 09:05. No builders are running. All Claude accounts are parked (alt2 frees at 10:04, the others at 13:04). codex-allusions-team is ready and job5 is pending at priority 95, so no new task was queued.
- No new merge, so nothing was rendered. The 09:05 recommendations still stand: lab-48 next, fix-hidden-cache-test, then remaster passes on job3 and job4.
- Failed queue is unchanged (job2, job2b originals, lane-exit-routes). All of them were superseded by tasks that later landed.
- v0.1 landed 4 of 10, so the game plan v2 draft waits.

## Manager notes, 2026-10-05 10:33
- Merged: fix-hidden-cache-test (e93bc8d0, fec30a43). The test now accepts the ninth hidden route item, so trunk's pre-existing hidden_cache failure is gone. This was a test-only change, so nothing was rendered.
- job5 restarted on codex-allusions-team at 10:07 and hit the Codex limit again. That account is parked until 15:11 and job5 stays pending. lab-48 has been running on claude-alt2 since 10:07. Every other account is parked (Claude until 13:04, Codex 13:34 and later), so no new task was queued.
- Failed queue is unchanged. v0.1 is still 4 of 10 landed, so the v2 draft waits.
- Top three: (1) lab-48 lands on alt2; (2) at 13:04 lab-47 (with the PNG notes) and job6 go to the Claude accounts; (3) job5 resumes on the first Codex account to unpark (sircuteskingdom-team at 13:34).

## lab-48: organs, cybernetics and the X-ray as one system (2026-10-05)

Spec: Greg 5 Oct ~02:05 in `AgentHub/data/greg_playtest_b_2026-10-05.md`. Code: `game/systems/organ_system.gd`.
Proven at the mechanics lab's bodies station. Proof PNGs are in `P:/GameDev/Temp/lab48/` (`tests/organ_system_capture.tscn`).

Defaults set behind dials, all in `OrganSystem` unless named. None of these is Greg's decision.
- `HEART_DEATH_SECONDS` 6. A burst heart with nothing pumping for it kills in 6 s.
- `SLOW_BLEED_FLOOR` 6 ml/s. This is the lowest internal bleed for a burst liver, gut, stomach or kidney. The rupture itself already bleeds ~13-25 ml/s, so death takes about 2-3 minutes.
- Lungs: one burst lung with nothing breathing for it means breathless (pace 0.6) and no sprint (`SoulsMover.winded`).
- Brain: the existing fatal rupture drops the body (for the undying player, the body fails).
- `SHORT_SECONDS` 6 and `SHORT_WEAR` 0.12. A second shock while an implant is shorted overloads it and burns it out for good. Plates (sternum, spine cage, clavicle rail) conduct but never short.
- Implant roles:
  - lung bellows breathes for a lung.
  - Regulator and pulse cage keep a burst heart going.
  - Blackbox liver covers a burst liver.
  - A shorted part stops doing its job, and limb hardware loses its capabilities while shorted.
- Rip:
  - `RIP_SECONDS` 1.5 at full grip, pulled in tugs at `TUG_RATE` 2.2/s. If you let go it slips back at `RIP_SLIP_PER_SECOND` 0.7.
  - Bare hands cost `HAND_DAMAGE` 0.1 condition.
  - Reach is `RIP_REACH` 2.4 m.
  - Allowed only on a downed or dead body through an opening: `Cavity` OPEN_MARK, or a wound cut to the organ layer. X-ray visibility is not an opening.
  - A burst organ is refused ("BURST"), because it already spilled out.
  - A heart or brain ripped from a living downed body kills it (the finisher). Any other organ adds an internal bleed.
- Chest opening: a cut, puncture, shear or ballistic torso hit opens the chest once the zone is cut to bone (`OPEN_AT_LAYER`) and is at or under 75% health (`OPEN_AT_HEALTH`).
- X-ray look:
  - Skin becomes `xray_shell.gdshader`.
  - Organs glow at `XRAY_ORGAN_GLOW` 0.85, and hot when damaged.
  - Hardware is 40% see-through.
  - The chest and buttock censors and forms hide under the X-ray (`XRAY_HIDES_CHEST_CENSOR`). The groin censor stays.
  - An opened chest loses its chest censor.
- Scan loot estimate: `Carry.sale_value()`'s base (organ 12, cybernetic 24) × condition. The scan has no market, buyer or spoil clock.
- Lab controls (assistant default):
  - Hold USE (E / pad X) on an organ you can see to rip it.
  - With an organ in hand, RELOAD (R / Y) installs it into you and DRESS WOUND (4 / d-pad left) sells it.
- Station dummies carry hardware from the catalogue (`BodiesStation.LOADOUTS`). The lab player carries the decanting loadout.
- Anatomy fix: the organ layout and skeleton had the spine in front of the heart. The rig faces -Z, as `BodyForms` says. They have been turned round.
- New organs: stomach and two kidneys.
- Open question: `AgentHub/queue/questions/lab48_reflex_booster.md`.
