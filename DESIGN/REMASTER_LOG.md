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
