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

## lab-47 teardown destruction, 2026-10-05

- Built: Greg's five tiers as one table (`systems/material_toughness.gd`), 15 cm voxel walls/crates/bunker that break where hit and drop unsupported pieces as their own breakable bodies (`voxel_structure.gd`), a 6 x 6 x 3 m diggable dirt patch (SDF + naive surface nets, chunked, cuts replayable from a save: `dig_terrain.gd`), one explosion for voxels, soil, props and bodies (`blast.gd`). WorldBreak routes every existing weapon into them. Lab: brick and concrete voxel walls replace the panel wall; breach corner (tier 4 bunker front, tier 5 shell, lit crate inside; buried tier 3 hatch over a pocket); NEXT now steps on to grenade, charge, thermal drill, shovel.
- Library: in-house GDScript, not Voxel Tools. Its GDExtension (1.7, MIT) would be a native binary loaded by every lane's headless suite and is marked less tested than the module build; the lab patch costs 17 ms for a grenade crater remesh in GDScript, which is fine here and not for kilometres of map. Voxel Tools stays the upgrade path for the real map.
- Dials (defaults, for Greg): per-material hp per voxel (brick 18, concrete 30, bunker 60, sealed 120); loose cubes 96 and falling pieces 16, oldest recycled; grenade r 1.1 m / 260, charge r 0.85 m / 520 (fuses 2.2 s / 3 s); drill 55 hp/s r 0.3 m (about 12 s through 60 cm of bunker); ramming 35 kJ per tier (a 1.2 t car at 50 km/h beats tier 3); chaos magick tiers per metre of altitude 0 (off until the spell exists).
- Measured headless (CPU only): 17 pistol rounds 1.7 ms total; charge on brick 8 ms (203 cells); grenade crater 17 ms; drill 0.16 ms a frame; debris settled with 83 cubes: physics 1.0 ms, process 2.2 ms a frame.
- Not looked at: no render_one.cmd, so no PNGs (`tests/destruction_capture.tscn -- --shots=DIR` takes all six) and no real-GPU fps.
- Weak: falling pieces collide as their convex hull; voxel faces are not greedy-merged; the dig patch draws one vertex colour, no texture; explosions are a light flash and the debris, no smoke or sparks yet.

## Manager notes, 2026-10-05 15:10

- **Merged since 10:33:**
  - lab-48 organs, cybernetics and X-ray (248ea0c9)
  - lab-47 Teardown destruction (c73a2e0e)
  - fix-58 execution on a downed body (61c323f3)
  - fix-55 examiner on the rigged base (c75be73a)
- **Landed so far:** 6 of 10 v0.1 jobs.
- **Running:** job5 (the facility map) on claude-alt2 since 15:07. Every other account is parked: Claude default and alt until 18:04; codex until 15:11, 20:30 and 20:33, and sircuteskingdom-plus until 10-11.
- **Rendering:** not done. Two Godot processes are running under the job5 builder, so the one-window rule applies. I reviewed the existing PNGs instead.
- **Weak in the lab-48 PNGs** (`P:/GameDev/Temp/lab48/contact_sheet.png`):
  - The whole lab is one flat brown-red wash.
  - Every lab HUD line is printed red, which breaks Greg's "red only on danger" rule.
  - The `ACID ON YOU` line still shows, although acid is off.
  - Debug text overlaps the X-ray scan panel.
  - Blood pools are flat red squares.
  - What reads well: the heart in hand, the X-ray scan panel, and the shorted-implant sparks.
- **Weak in the fix-55 PNGs** (`P:/GameDev/Temp/examiner_*.png`): the green mood is right. But a blurred grid of squares covers the whole office frame, the head reads as stacked boxes, and one arm is bare white.
- **Priorities:** lab-53 (98) and v02-51 (90) sit above the v0.1 jobs. Greg bumped them at midday, so I left them.
- **Failures:** none new. job2 and job2b are superseded. lane-exit-routes is an old task.
- **Game plan v2:** the draft is started at `DESIGN/GAME_PLAN_V2_DRAFT.md`, because 6 of 10 jobs have landed. Nothing was queued from it.
- **Top three:**
  1. Queued `remaster-lab-47-p1` (70, claude). It covers the GPU render, explosion smoke and sparks, soil texture, a lab HUD that keeps red for danger only, and hiding the acid line.
  2. job5 lands, then the examiner office overlay blur goes into job6.
  3. Get a real-GPU fps number for lab-46, lab-47 and lab-48. None exists yet against the 144 fps target.

## Manager notes, 2026-10-05 16:10

- **Merged since 15:10:** job5 the facility, one map (d5a224af, merged 70430fe8); fix-57 wizard eyes in the house palette (1e344b86).
- **Landed so far:** 7 of 10 v0.1 jobs. Still to land: job6 examiner, job9 enemies, job7 death/saves/HUD (all pending; job7 bounced off a codex limit at 15:37).
- **Running:** fix-56 ADS sights and VATS killcam on claude-alt2 since 15:37. Every other account is parked (Claude until 18:04, codex until 20:16-20:33, sircuteskingdom-plus until 10-11).
- **Rendering:** skipped; the fix-56 builder has Godot running. Reviewed job5's own PNGs (`P:/GameDev/Temp/job5_sheet5.png`, `P:/GameDev/Temp/job5-facility-one-map/`).
- **Good in job5:** the green-white pools on the floor are the right mood; the zone stamp in the body-cam OSD and objective box read well; capture runs 330-357 fps at 1280x720.
- **Weak in job5:**
  - Arcade and Lower Works are black voids: floor pools only, no walls, ceiling or props visible between them. The story-prop frames show one or two dark boxes.
  - Bright unlit white rectangles float in mid-air (arcade right edge, transit, surface gate).
  - Lift rides show a flat white bar and red "DOWN"/"UP" lettering clipped off the frame; red is not danger there.
  - A flat green guide stripe runs down every floor and reads as a debug line.
- **Failures:** none new.
- **Top three:**
  1. Queued `remaster-job5-p1` (70, claude): walls and story props, the floating quads and lift signage, the guide stripe behind a dial.
  2. job6 must fix the examiner-office overlay blur when it runs (carried from 15:10).
  3. A real-GPU fps number for lab-46, lab-47 and lab-48 (carried).

## Manager notes, 2026-10-05 17:08

- **Merged since 16:10:** fix-56 ADS sights small and centred, hands seated on the pistol and 12G (8532801d); RoundCam: the killing round replayed slowed into the X-ray (15c3a1f0); merged 267b2107, gate green.
- **Running:** lab-53 BeamNG-style vehicles on claude-alt2 since 16:47 (priority 98, Greg's bump). Claude accounts parked until 18:04, codex until 20:16-20:33, sircuteskingdom-plus until 10-11.
- **Rendering:** skipped; lab-53 has Godot running. The ADS check is `res://tests/aim_down_sights_capture.tscn`; render it next run.
- **Queue order fix:** Greg said at midday that the facility map is the top priority, but `remaster-job5-p1` was at 70, behind job6/job9/job7/v02-51/art-49. Raised it to 96, so the first Claude account to unpark at 18:04 gets it. lab-53 stays at 98 (Greg's number).
- **Covered from Greg's midday notes:** examiner reskin (fix-55 done), ADS/VATS (fix-56 done), eyes (fix-57 done), execution (fix-58 done), Black Mirror and depth map (in v02-51 pending).
- **Open question for Greg:** `queue/questions/execution-58-01.md`. Should executed bodies in the Hunt and the arcade ragdoll? Default for now: no change, so they stay in the stiff downed pose.
- **Failures:** none new.
- **Top three:**
  1. remaster-job5-p1 at 18:04 (walls, story props, floating quads, lift signage).
  2. job6 must fix the examiner-office overlay blur (carried).
  3. Render the fix-56 ADS capture and check that the sights no longer fill the screen.

## remaster-job5-p1, 2026-10-05: the facility halls show their walls

- **Walls and props:** the Service Arcade (6 rows) and Lower Works (8 rows) get a caged wall lamp on each long wall at every pool row, washing the wall face, plus one service prop in that wash on alternating sides: the kit's pipe runs and vent, drum clusters, crate stacks, a fuse cabinet with conduit to the ceiling (`facility.gd` `_dress_walls`). Nothing named or written on. Tanks, consoles, ducts, drums and crates now wear the kit's ambientCG painted-metal / metal-plate grime instead of flat colour.
- **Floating quads:** the "white rectangles" in the arcade and Lower Works were the service-monitor screens (1.8x emission) seen at the frame edge; now a dim banded CRT (0.12x) with a close, low spill on its cabinet. The surface-gate white-out moved to just past the threshold (no shadow) so it fills the doorway to the floor instead of hanging over a dark strip; a daylight spill lights the jambs.
- **Lift rides:** shaft strips 5x -> 0.6x, thinner, so they read as lit tubes rather than a flat white bar; floor indicators in the house bone/amber (`c8a070`), about half the size, plus a readout over each side slot so a rider watching the shaft reads the floor in frame. The lintel indicator still runs off the top edge when you look out of the slot (it is above the door).
- **Dials (Greg can flip):** `facility.gd` `ROUTE_LINE` = `"worn"` (default: broken, scuffed painted dashes on the concrete texture, muted) or `"off"`; `WALL_WASH_ENERGY` = 7.0 (0 turns the wall lamps off).
- **Proof:** `render_one.cmd facility_one_map_capture`, before `P:/GameDev/Temp/job5-p1-before/`, after `P:/GameDev/Temp/job5-p1-after/` (sheet `job5_p1_after_sheet.png`). fps 1280x720: average 313, min 5 (first-frame shader compile).

## Manager notes, 2026-10-05 19:08

- **Merged since 17:08:** remaster-job5-p1. The facility halls now show walls, caged wall lamps, service props and grimy materials. The floating white quads are gone. Merged e7fd15dd (18:38), gate green.
- **Running:** nothing. Every account is parked: claude-default and claude-alt until 23:04, claude-alt2 until 20:04, codex until 20:16-20:33, sircuteskingdom-plus until 10-11. 14 tasks are pending, so no idle fills were needed.
- **Rendering:** I didn't launch a render. I opened the builder's after-shots in `P:/GameDev/Temp/job5-p1-after/` instead.
- **Still weak (job5):** in the lift ride (04), the floor readout is a big curved "DOWN 0C SERVICE ARCADE" floating in the black. The lintel text overlaps the HUD objective box, and the shaft strip is still one flat green bar. The arcade (03b) is mostly empty floor and black, with one drum and one pipe run as its whole story. The `worn` route dashes still read as a debug stripe.
- **Failures:** none new (job2, job2b and lane-exit-routes are old ones).
- **Top three:**
  1. Queued `remaster-job5-p2` (70, claude) to fix the lift readout and HUD overlap, add story clusters and pool light in the arcade, and default the route line to "off" (dial kept).
  2. job6 must fix the examiner-office overlay blur (carried).
  3. Render the fix-56 ADS capture, and get a real-GPU fps number for lab-46/47/48 (carried).

## lab-53: BeamNG-style vehicles on the lab's vehicle pad (2026-10-05)

- **Built:** two drivable cars on the mechanics lab's vehicle pad (Kenney CC0 sedan and SUV, regraded to rust/bone/old blood), a 1.2 m ramp, and a concrete voxel crash wall. `game/systems/vehicle_damage.gd` + `game/lab/stations/vehicle_station.gd`.
- **Why not a real soft body:** BeamNG-style node-beam (mass-spring lattice at ~2 kHz) needs native code; two cars of it in GDScript cannot hold 144 fps and there is no maintained Godot 4 port. Jolt's SoftBody3D is cloth-like and cannot carry a suspension. So the existing raycast chassis (`arcade_vehicle.gd`: per-wheel springs, load-based grip, real weight transfer) drives, and damage is applied where each impact lands: the body mesh's vertices are pushed in (one ~1k-vertex pass per impact, never per frame), parts come off as rigid bodies, and the engine loses power.
- **Toughness tiers:** parts carry `MaterialToughness` materials (bodywork `steel_sheet` tier 3, new `glass` tier 1). A part comes off only when the blow's source beats its tier. For a ram the tier comes from kinetic energy (`ram_joules_per_tier`), so a 1.1 t car bends on a slow knock and sheds steel from about 14 m/s (50 km/h). Melee dents a car and breaks its glass but cannot take a steel door off; guns can. A car ramming a voxel wall hits the wall with the `vehicle` source.
- **Bodies inside:** a seated `BaselineHuman` takes each crash in the zone nearest the contact, with the derby's rule: once the bumper and hood are gone, a fast front hit lands on the chest as shear.
- **Dials (defaults I chose; Greg has not set these):** `VehicleDamage.crumple` 1.0 (global crumple strength); `DENT_PER_MS` 0.045 m per m/s, `MAX_CRUSH` 0.6 m; `ENGINE_PER_MS` 0.04 with a floor of 0.25 (a wrecked engine limps at ~6 m/s rather than stopping); `PART_DAMAGE` 2.5. Crush is shared about equally in a car-to-car hit (0.7 + 0.3 x own share of the closing speed). The derby is unchanged: its cars do not use `VehicleDamage`.
- **Controls:** R2 throttle, L2 brake then reverse, left stick steers; W/S/A/D on keyboard. USE on the plinth or beside a car gets in; USE gets out (refused above 5 m/s).
- **Measured (lab-53 capture, RTX 2060 SUPER, vsync off, ~7 other Godot processes running):** 282 fps mean and 236 minimum, per-second averages, over the wall hit and the SUV ram with both cars moving. One crumple pass costs 2.9-3.5 ms on the impact frame (the kit body is split once into 4x faces so creases show). That fits inside a 144 fps frame, but it is a one-frame spike the per-second counter hides. PNGs: `P:/GameDev/Temp/lab53/1_before.png`, `2_after_wall.png`, `3_after_ram.png`, `4_pad_wide.png`, `fps.txt`.
- **Limits:** the crumple reads as a flattened, shortened nose with a wrinkle, not BeamNG's folded metal. The pad gives a 13 m run-up, too short to reach steel's ram tier, so the capture starts each car at 15 m/s. In play, take a lap of the yard first. **lab53b:** the pad is now a ~24 m lane on the yard's east side (start line by the south wall, crash wall under the roof); full throttle from parked reaches the wall at 15.5 m/s (steel needs 13.8 for the sedan) and the front bumper comes off (`mechanics_lab_test`). The menu teleport now takes you out of the car at any speed, and melee on a car counts as melee (dents, breaks glass, never takes steel off). Doors only come off from side hits or gunfire.

## job6: the examiner, a real boss; his keycard always drops and opens the staff door (2026-10-05)

- **Fight** (`systems/examiner_fight.gd`): about 30 s for a human with the cleaver. A LimboAI behaviour tree picks his moves when the plugin is on disk (built in code by name, as `rival_tactics.gd`), and the same five-branch selector runs in GDScript when it is not (`ExaminerFight.decide`). The scalpel wind-up glints bone-white and can be parried (PARRY: X / L2) into a 1.6 s opening with one double-damage riposte. The syringe glints sick green, lunges from 2.6 m, slows you 6 s and cannot be parried, only stepped out of. Poise is 3 calm / 4 desperate; a reel only interrupts a calm scalpel wind-up. Every third blow that catches him at rest is turned aside (20% damage) and answered with a quick parryable cut, so spamming him is punished. Under half health he is DESPERATE: quicker wind-ups, a follow-up cut, shorter rests, and the bar says so. A cold overhead pool lights his room during the fight. His rig takes every wound but never drops before the fight is won.
- **Head breaking after two hits:** the screenshot (`greg_playtest_c_screenshot_2026-10-04`) shows the old Higgsfield ModelSkin coming apart zone by zone. fix-55 removed that skin; `examiner_keycard_test` asserts his head stays on through every seeded fight (three by default since land-job6; `--runs=10` for the full sweep).
- **Click-spam kill:** blows at him skipped the weapon cooldown, so a fast clicker killed him in about a second. They now keep the weapon's own rhythm (axe 0.7 s), and they go through the InputMap actions, so R1 / L2 / R2 work on the pad.
- **Keycard:** falls to his floor beside him as a lit pickup (use it, or walk over it once you have stepped clear), and is restored there on reload until taken. `ExaminerFight.has_keycard()` is the one check, and the staff door uses it. The door's prompt names the card and where it is (his office, or his office floor).
- **Staff door (one map):** the shut leaf was a 1.4 m plate with no collision in a 3 m opening, so you could walk round it, and the old 1.55 m frame box stood in the middle of the opened doorway. The leaf now fills the opening with collision and a red reader that goes pale when it opens. The frame is two jambs and a head. His cupboard (2 field dressings, 8 rounds) stands on the artery wall instead of across the doorway. With the card in hand, the objective now says the staff door, not the sealed pit door.
- **"Examiner office overlay blur" (carried in the manager notes):** that fix-55 shot was taken with the player still in the tank, so the blurred squares and bubbles are the in-tank medium seen through a separate capture camera. From the player's own view in his office there is no blur (`P:/GameDev/Temp/job6/shots/`).
- **Dials (defaults I chose; Greg has not set these):** `HEALTH` 260; `PARRY_WINDOW` 0.3 s; `PARRIED_STAGGER` 1.6 s; `RIPOSTE` x2; `POISE` [3, 4]; `GUARD_EVERY` 3 at `GUARDED_SHARE` 0.2; `PHASE_TWO_AT` 0.5; wind-ups scalpel [0.6, 0.45] s, syringe [0.95, 0.75] s, follow-up 0.38 s; `COOLDOWN` [1.1, 0.7] s; `ARENA_LIGHT_ENERGY` 2.4 (0 turns it off). His lines and his final model stay OPEN (Greg's).
- **Proof:** `render_one.cmd examiner_boss_capture --out=P:/GameDev/Temp/job6/shots`: 1 scalpel telegraph, 2 syringe telegraph, 3 desperate, 4 keycard on floor, 5 staff door shut, 6 staff door open onto the artery, 7 cupboard.

## land-job6: the examiner merged onto claude/launch-latest (2026-10-06)

- **Conflicts:** only this log (job6's section and the 21:08 / 23:10 manager notes; both kept). `vat_chamber.gd` auto-merged: job7's field inventory, rebirth site and facility checkpoints sit beside job6's staff door, keycard and cupboard.
- **Fixed, caused by job6 (also red on hub/job6-the-examiner alone, green on the base):** `first_run_walk_test` still expected the card to go straight into the inventory and the pit door to be the way on. It now takes the card off his floor and opens the staff door (pit door kept for the two-map cut).
- **Gate time:** `examiner_keycard_test` ran ten ~40 s fights (about 7 min), over `run_tests.sh`'s 200 s ceiling, so the gate timed it out. It now runs three by default; `--runs=10` (after `--`) gives the full sweep, which passed in 6 min 54 s on the merged tree.
- **Tests (merged tree, headless, own APPDATA, `tools/run_tests.sh`):** all green: baseline_human, body_cut, opening_handoff, first_run_walk, first_thirty_route, examiner_fight, examiner_keycard (3 runs), examiner_feed, death_save_screen.
- **Proof:** `render_one.cmd examiner_boss_capture --out=P:/GameDev/Temp/land-job6/shots` (7 PNGs, same framing as job6's `P:/GameDev/Temp/job6/shots`). Opened them all: rigged low-poly BaselineHuman body with the doctor's coat (no Higgsfield skin), wind-ups readable, DESPERATE on the bar under half health, the card lit on his floor, staff door shut then open onto the Service Artery, cupboard on the artery wall. His office from the player's view is sharp, no overlay blur. Lighting is dark with green-white pools.
- **Limits:** his head still reads as stacked boxes (placeholder; his model and lines are Greg's). A warm red lamp washes the floor and left wall at the staff door (shots 5 and 6), which is not a danger cue; I left it alone. Shot 4 shows "CALL THE LIFT" because the capture camera stands on the lift landing; the card prompt wins in reach (`examiner_keycard_test`). No fps number. The glints are small at the capture distance, so the telegraph is judged from the test, not the PNG.

## Manager notes, 2026-10-05 21:08

- **Merged since 19:08:** lab53b-land-vehicles (9a2df731: 24 m run-up lane, car exits on menu teleport, melee counts as melee) and job7-death-saves-screen (8c6c3e45: persisted subtitles/censor/graphics settings, device-aware inventory hints, blood-sigil capture; blood-fragment spending made a dial in e1031994). Both gates green.
- **Running:** job6-the-examiner on claude-alt2 (since 20:32). Every other account is parked (claude-default and claude-alt until 23:04, codex until 10-06 02:51 or later). 12 tasks pending, so no idle fills were needed.
- **Rendering:** a windowed Godot ("Current Version") is already open, so I didn't launch one. I opened the builder's `P:/GameDev/Temp/job7-death-saves-screen/blood_sigil.png` instead.
- **Still weak (job7):** the bloodstain is a glowing, translucent orange ghost body with two floating red discs and an orange ring. It sits on a bare plane under warm brown fog, which is off-palette and doesn't read as a bloodstain. A floating "YOUR OLD BODY" label hangs over it like debug text. The capture isn't in facility light.
- **Failures:** none new (job2, job2b and lane-exit-routes are old ones).
- **Top three:**
  1. Queued `remaster-job7-p1` (70, claude) to make the sigil a dark pooled blood decal, swap the floating label for an in-reach prompt (or a dial that defaults to off), and re-render it in facility light.
  2. job6 must fix the examiner-office overlay blur and use the low-poly base for the examiner, not the Higgsfield skin (carried; it's running now).
  3. Render the fix-56 ADS capture, and get a real-GPU fps number for lab-46/47/48 (carried).

## Manager notes, 2026-10-05 23:10

- **Merged since 21:08:** nothing (76f8f0c1 is only a brief tweak).
- **job6 built but did not land:** hub/job6-the-examiner has the finished boss (d212548a, 448141ec), but its merge into claude/launch-latest conflicted, and the hub put the full job back in pending to be rebuilt. I moved that rebuild to `queue/held/job6-the-examiner.md` and queued `land-job6-examiner` (priority 101, claude): merge the base into the kept branch, resolve the conflicts, rerun the gate, and render once. The builder's own notes say his head still reads as stacked boxes (a placeholder until Greg draws him), there's no fps number yet, and `blood_pool.gd` prints "cast a freed object" when a second test world loads.
- **Priority order was broken:** imp-64/67/60/68 (98-95) were outranking job6 (94) and job9 (93), and those four are now running on claude-default and claude-alt. Pending headers are now job9 99; imp-61 90, 62 89, 63 88, 66 87, 65 86; art-69 85, art-49 84; v02-51 dropped to 40 (backlog).
- **Rendering:** skipped. Nothing new merged, and every Claude slot is building.
- **Failures:** job6, a merge conflict (see above). job2, job2b and lane-exit-routes are old.
- **Top three:**
  1. Land job6 (queued, 101).
  2. job9 enemies next (99).
  3. Render the fix-56 ADS capture, and get a real-GPU fps number for lab-46/47/48 and for job6 (carried).

## Manager notes, 2026-10-06 02:10
- **Merged:** land-job6 (793c8dcc, merge 39782473, gate green). The examiner boss, the keycard drop and the staff door are now on claude/launch-latest. 8 of 10 v0.1 jobs have landed; job9 enemies is building on claude-alt2 (since 01:42). Every other account is parked until 04:04 or later.
- **Looked at** `P:/GameDev/Temp/examiner_boss_2_syringe_telegraph.png` and `_6_staff_door_open.png`.
  - The telegraph reads: his hand flares white before the syringe. But the syringe itself can't be seen.
  - Weak: the "open" staff door shot is a flat dark slab with a warm smear on it. It doesn't read as an opening onto the Service Artery.
  - Weak: red lamps wash the walls and the floor near the door. Greg's rule is "red only on danger".
  - Weak: the objective says "HIS CARD OPENS THE PIT DOOR" (`game/vat_chamber.gd:1651`), but the caption says "STAFF DOOR". The player is told two different door names for one door.
  - Still Greg's: the examiner's box head and his lines.
- **Top 3:**
  1. Make the staff door read as a real opening, take the non-danger red out at the door, and use one door name in the objective. Queued as `fix-72-staff-door-read`.
  2. Make the syringe and scalpel visible in his hand during the telegraph (job6 remaster pass).
  3. Measure fps in the examiner office on the RTX 2060 SUPER (none measured yet).
- **Failures:** no new ones (job2, job2b and lane-exit-routes are old ones, already handled).

## Job 9 (v0.1 enemies), 2026-10-06: dials and defaults

None of these are Greg's decisions; all are defaults behind constants, tuned so the headless duel bots (careful play) win with each weapon and mashing loses.
- **Guards** (`systems/v01_guard.gd`): health staff 230 / pistol 170; staff pattern light, light_2, heavy, light, shock; blood share per hit 7% light, 11% heavy, 14% shock, 9% shot; block 3 stamina, regenerates every 3 s; he parries after 2 lights in a row; pistol aim 1.05 s, locks at 72%, 5-round magazine, 1.7 s reload.
- **Freed subject** (`systems/v01_freed_subject.gd`): health 130; pounce windup 0.62 s (red); claw flurry of 3 (copper, 4% each); dazed 1.8 s after breaking out.
- **Sentinel** (`systems/v01_sentinel.gd`): health 320; ram windup 1.0 s (red), 17%, then 2 s vent; slam 0.85 s (copper, blockable), 11%; light blows chip plates x0.35, heavies x1.2; core x2.0 melee, x2.5 shot; staff shock stuns 2.6 s; an eye shot blinds 3 s.
- **Measured** (render_one, RTX 2060 SUPER, 1280x720, vsync off, across three runs): growing floor with the subject loose 110-125 fps; service arcade with three guards awake 116-142; lower works with the sentinel awake 111-200. One 72 ms spike on the growing floor in one run.

## Manager notes, 2026-10-06 05:10
- **Merged:** job9 enemies (a607fd89, merge 2efeed7b, gate green). The guards, the freed subject and the sentinel are on the one map. 9 of 10 v0.1 jobs have landed; only job7 is left. Every account is parked (Claude until 09:04, alt2 until 06:04, Codex 05:38-10-11).
- **Looked at** the job9 proof PNGs from the merged run (`P:/GameDev/Temp/job9_shots/v01_guard_2_staff_shock_telegraph.png`, `v01_sentinel_1_ram_telegraph.png`, `v01_subject_1_pounce_telegraph.png`). I didn't do a fresh render because these came from the merged commit.
  - Weak: in the shock wind-up the guard has his back to the player. The red glint is on the staff tip, low on the floor, and his body tells you nothing.
  - Weak: from range, the sentinel's ram telegraph is a small orange square and one red dot. The machine is a dark box on wheels that blends into the floor.
  - Weak: "CELLOUTZ 47 IS DOWN" (from the arcade) is still on screen in the Lower Works. The subtitle never clears.
  - Weak: in the red-lit growing floor the freed subject is a small crouched figure, red on red. Its pounce telegraph is red too, so it gets lost. The room's red is not a danger cue.
  - Weak: the guards are still mannequins with a red blob head (imp-60 body look is pending).
  - Unknown: `v01_weapons_test` has 6 failures ("back round to the cleaver"). The job9 builder thinks lab-53 caused them. Nobody has checked on trunk.
- **Top 3:**
  1. Fix the enemy reads (guard faces the player while winding up, a sentinel telegraph you can see from range, the subtitle clears, the subject stands out in the vat room) and find out what is failing in v01_weapons_test. Queued as `fix-73-enemy-reads` (priority 70, claude).
  2. job7 death, saves and HUD is the last v0.1 job (remaster-job7-p1 pending, keep it next).
  3. imp-60 body look: the mannequin guards undercut every enemy telegraph.
- **Failures:** no new ones.

## car-71: GTA-style car door entry (2026-10-05)

- **Wired:** the mechanics-lab cars now prompt only at the driver's handle. USE walks the real lab body to the handle, swings the damage part on its hinge, turns and seats the body, closes the same door, and eases the live first-person camera into the existing cab. Exit reverses that route and resolves beside the door. A detached door skips the swing but not entry; a damaged/jammed door takes three pulls, ending in a kick. Taking damage interrupts entry.
- **Driving:** R2/L2 throttle/brake, left stick steer, R1 handbrake, Triangle cab/chase toggle, Cross horn (keyboard W/S/A/D, Space, F, H). Exiting over `VehicleDriver.GET_OUT_SPEED` (5 m/s) is a moving bail with inherited velocity, outward shove and roll request rather than a refusal.
- **Dials (defaults chosen here; Greg has not set them):** `VehicleDriver.ENTRY_SECONDS = 1.18`, `EXIT_SECONDS = 1.05`, `GET_OUT_SPEED = 5.0`, `REACH_TO_GET_IN = 1.05`; `VehicleDamage.door_jammed()` begins below 68% door HP and clears on pull 3. `VehicleStation.ALLOW_SEAT_DRAG = false`: enemy/sparring-partner dragging remains a stretch dial because its combat ownership and reactions are not yet authored. Passenger entry/exit is available through `VehicleDriver.DOOR_RIGHT`.
- **Animation source:** procedural body/camera interpolation over the project's existing Quaternius CC0 rig, credited in `CREDITS.md`; no uncredited Mixamo download was added.
- **Follow-up (2026-10-06):** a moving exit is now a `bail` phase: the body keeps the car's speed, the eyes roll through a full turn and then stumble, and control returns where the body lands (`VehicleDriver.BAIL_ROLL_SECONDS = 0.45`, `BAIL_SECONDS = 0.85`, defaults chosen here). The lab offers whichever handle is nearest, driver or passenger. The player's own body (walking and seated) is drawn on visual layer `VehicleDriver.OWN_BODY_LAYER = 5`, which the first-person eyes and the cab camera skip; before this the cab view rendered the inside of the seated body's head. Proof PNGs: `P:/GameDev/Temp/car-71-gta-door-entry/01..08`.
