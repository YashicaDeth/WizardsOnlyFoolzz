# Game plan v2: DRAFT for Greg to review

Started by the hourly build manager, 2026-10-05 15:10. This is a draft. It does not change GAME_PLAN.html or BUILD_PLAN.html, and no v0.2 job has been queued from it. Anything not taken from Greg's recorded decisions is marked **proposal, needs Greg**.

## 0. v2: refining v0.1 into a really good demo (refreshed 9 Oct 21:10)

Greg's north star (6 Oct night): "a really enjoyable gameplay shell" he can texture himself. So v2 is not new content; it is making the START-to-daylight route play well.

- **Plays well:** the examiner fight (telegraphed, fair, keycard always drops); the one-map route with real lifts and no loading screens (min 174 fps); the vat wake through the flood; the ending (7 Oct: hands hidden through the whiteout, bigger TO BE CONTINUED card, camera tilts 8 degrees to the horizon at the title drop, dial `TITLE_LOOK_UP_DEG`); the brain screen with all 4 disciplines (dec-89); route death = 3 s vat regrowth then last checkpoint; the decluttered lab (tidy-80); the new player body (player-81); the combat test suites all green (fix-76, fix-98).
- **Plays worst:** (1) the first-person melee still reads as a pose, not a swing (feel-86 queued); (2) encounters are flat: one long tile hall per room with a guard in it (feel-87 queued); (3) lab systems (organs, X-ray, liquid, destruction) barely touch the route (route-88 queued); (4) the Black Mirror on trunk stays stuck behind the brain screen (fix-93 queued); (5) ragdoll bodies can crash the game on quit (fix-95 queued); (6) lift rides are near-black and the arcade and Lower Works look alike.
- **Capacity, 9 Oct:** no gameplay change landed today; every account was parked (Claude until 10 Oct 19:04, alt2 until 11 Oct 17:04, Codex until 22:47 tonight or 11 Oct). Codex landed three quit/teardown fixes: fix-99 (Bone Yard quit leaks), fix-103 (the full route now quits with 0 leaks, was about 11868) and fix-104 (Jolt "max jobs" warning between maps gone). fix-105 (opening-test quit leaks) waits for Codex credits. Earlier (8 Oct): fix-97/100/101 cleared the MERCY NINE sight line; fix-102 examiner fist 9 -> 15 behind the DAMAGE dial.
- **Next refinement passes, in order:** fix-95 ragdoll quit crash > fix-93 Black Mirror on trunk > feel-86 combat feel > feel-87 encounters > route-88 lab systems into the route > remaster-player-81-p1 > imp-66 vat room. Each pass ships a before/after render and keeps the route suites green.

## 1. What v0.1 "Escape" actually delivered (as of 22:10, 6 Oct)

6 of the 10 v0.1 jobs have landed on `claude/launch-latest`. Details are in DESIGN/REMASTER_LOG.md.

| Job | Landed | What works | What is still weak |
|---|---|---|---|
| job2b rigged bodies on Jolt | yes | Every dummy stands on one rigged skeleton, with a head and ordinary shoulders. Cut limbs keep their skin. Death is a jointed ragdoll. X-ray works under the skin. | The skin reads as a checker, not flesh. Heads look like helmets. The idle is a hunched crouch. There are gaps at the ankles. `fix-job2-body-look` is pending. |
| lab-46 liquid and glass | yes | The glass cracks in stages and bursts into shards that stay. The fluid sloshes, pours, pools, drains slowly and conducts shock. | The pour is overlapping spheres, not a surface. The pool flows under obstacles. There is no sound. It was never rendered on the GPU. `remaster-lab-46-p1` is pending. |
| lab-48 organs, cybernetics, X-ray | yes (248ea0c9) | The chest opens through a wound. Organs are ripped by hand from downed or dead bodies. You can install an organ in yourself or sell it. The X-ray scans implants, organ health and loot value. Shock shorts implants, and a second shock burns them out. | Lab lighting is a flat brown wash. Every HUD line is red, which breaks "red only on danger". Debug text overlaps the scan panel. Blood pools are flat red squares. |
| lab-47 Teardown destruction | yes (c73a2e0e) | The 5 toughness tiers are one table. 15 cm voxel walls break where hit and drop loose pieces. There is a diggable dirt patch. One blast system covers the grenade, charge, drill and shovel. | Explosions have no smoke or sparks. The ground is one colour. It was never rendered on the GPU. `remaster-lab-47-p1` is queued. |
| job3 moving and fighting | yes | HOTLINE CLEAVER and PRODSTAFF work with buffer, hitstop, stagger, block and parry. Movement has sprint, crouch and roll. There is lab ADS and lock-on. The arcade guard can be cut. | The first-person swing is a pose, not an animated arm. There is no swing or hit sound. The Hunt still issues the old sword. `remaster-job3-p1` is pending. |
| job4 waking in the vat | yes | First-person wake in red liquid, real glass and a flood. | It was not rendered at landing. `remaster-job4-p1` is pending. |
| job5 one facility map | landed; map-84 pass (5c18d817, 6 Oct) | One map: vat floor, examiner office, service artery, arcade, transit lift, Lower Works, heat lift, surface gate. Real lifts with lit floor-readout panels; arcade cover the guards path round; Lower Works lit; min 174 fps on the 2060 SUPER. | Lift cab rides are near-black; arcade and Lower Works still read as the same green tile room. |
| job6 examiner | landed (39782473, 6 Oct) | A fair, telegraphed boss on the rigged base body. His keycard always drops and opens the staff door. | His head is still a placeholder (Greg's call). The open doorway reads flat, and there is red light that isn't a danger cue (fix-72 queued). |
| job9 enemies | landed (2efeed7b, 6 Oct) | 2-3 CellOutz guards (staff and pistol; block, parry, call each other), the freed vat subject and the Lower Works sentinel (X-ray plates, weak core). Each one has a telegraph and a headless duel test, and a careful player wins with every weapon. 110-200 fps per room. | A guard turns his back to you during the shock wind-up. The sentinel's ram telegraph is faint from range. A kill subtitle stays up between rooms. The subject is lost in the red vat room. v01_weapons_test has 6 failures (cause unknown). fix-73 queued. |
| job7 death, saves, HUD | pending | | |
| imp-60 body look | landed (2bd20958, 6 Oct) | Every body is a low-poly human with flesh and cloth shaders, faces, eyes and brows; 470 fps with five bodies. | Faces render smeared with no readable features, the neckline is jagged, the guard vest is a box (fix-74 queued). Face sliders no longer show on a healthy head (question for Greg). |
| imp-68 HUD face and vials | landed (ffe07171, 6 Oct) | The face portrait is a third CRT with three looks behind a dial (xray skull by default, live bodycam, mask). The vials become specimen tags hung on the spine. | The bodycam frames the cap instead of the face, a wound label overlaps BLEED, and the pocket slots read weakly (remaster-imp-68-p1 queued). |
| imp-61 liquid surface and sound | landed (ee4668d9, 6 Oct) | The pour is drawn as one screen-space liquid surface, not spheres (spheres kept as a graphics fallback). The pool flows round solid props. Glass cracks, bursts, pours, splashes and wading all have synthesised sounds. | The pour still beads up, the pool is a flat matte stain, and wade ripples aren't visible (remaster-imp-61-p1 queued). Nobody has listened to the sounds yet. |
| lab-52 Duelist and Shade | landed (ef93a996, 6 Oct) | Lab-only station 6: Duelist (strike, heavy, block, parry into a doubled riposte, lock, roll) and Shade (rear takedown, physical throwable, darkness, stalking crouch) on their own pad layers. Off by default; not in the facility. | No visual identity yet (no stance, trail or swap flash; imp-65 does that). Shade still holds the cleaver. v01_weapons_test and souls_pad_test are red on the base (fix-76 queued). |
| intake-29 pad-first intake | landed (42fdbd02, 6 Oct) | NEURAL INTAKE is fully playable on a PS4/PS5 pad: L1/R1 tabs, D-pad rows, face-button actions, device-aware hints, push-to-talk on R3 with a text fallback, on-screen rename. | Header overlaps the tabs, labels run off the edge, the subject preview is still the checker body (fix-77 queued). Not tried on a real pad. |
| v01-75 ending | landed (9cf16860, merge 8d4089fd, 6 Oct) | At the Surface Gate: whiteout, eyes adjust, hum to silence then wind, WIZARDS ONLY FOOLS burns in over the first view, TO BE CONTINUED with the per-area run card, back to the title. Skippable after first view. | The held weapon stays on screen over the title drop; the first view is bare pillars on flat ground; the card text is small at 720p; gamepad Start not tested (fix-78 queued). |

Fixes that landed 7 Oct (Codex, all gate green): fix-85 old-body label, fix-92 thought line, fix-94 guard tag, fix-82 menu support row, fix-78 ending first view, fix-76 combat tests, fix-96 horizon tilt, fix-98 test quit leaks. Also landed 7 Oct: player-81 player model redo (e98c9457) and dec-89 Greg's 6 Oct answers (23c53034).

Earlier fixes: fix-hidden-cache-test, fix-58 (an execution on a downed body is one beat and ends with them dead), and fix-55 (the examiner no longer uses the Higgsfield skin).

## 2. What v0.1 still needs before v0.2 starts

These come from Greg's notes, in his order:
- The facility map (job5) and the examiner (job6). Without these, START to surface cannot be played.
- Death, saves and HUD (job7). Enemies (job9) landed 6 Oct.
- Job 8 "play it, fix it" with Greg on the pad, then the `v0.1-escape` tag.
- Pending fixes Greg asked for: ADS sights blocking the screen plus the VATS kill cam (fix-56), and the wizard-eyes colour (fix-57).
- Nothing has been checked against the 144 fps target on the RTX 2060 SUPER yet. There is no GPU number for any lab system.

## 3. Proposed v0.2 build plan

**Scope in.** This list comes from BUILD_PLAN.html "After v0.1" and Greg's notes of 5 Oct, 02:10 and midday:
- the Support Unit and freed subjects (placeholder internal ids only, no lore or on-screen names)
- the drains route
- the doctor chase
- the Black Mirror phone as one working device
- two more disciplines (Duelist and Shade, as lab-52 started)
- systems that combine (lab-54)
- BeamNG-style vehicles on our destruction (lab-53)
- a sound pass (polish-50)

**Scope out.** This list comes from BUILD_PLAN.html "switched off until v0.2+" and stays off unless Greg moves it:
- the Wire, the Board, the pyramid, territories, money
- the Derby
- drugs, cases and skins, voice NPCs, planes
- the surface hour (that is v0.3)
- any lore or names. Greg writes those.

**Order. Proposal, needs Greg.** It follows the BUILD_PLAN v0.2 line, with the vehicle and phone work Greg already queued.

### v2-1 Black Mirror, one working device
- **GOAL:** "one working device": raise and lower it; navigate its pages (MAP, camera with night vision, inventory link) on the pad; one consistent look; no broken pages. (Greg, 5 Oct midday)
- **EXISTS:** v02-51 landed (4a68600c): phone on the examiner's desk, night and depth camera, MAP and CARRY underground; plus the phone pages already in the game.
- **BUILD:** finish v02-51. Add the depth-map camera mode in Greg's TouchDesigner look: a LiDAR grey-to-white point look, block-tracked boxes, depth contours and sweeping scan lines, built as a Godot shader.
- **PROOF:** a PNG of every page; a pad-only navigation test.

### v2-2 Support Unit and freed subjects (placeholder ids)
- **GOAL:** the BUILD_PLAN v0.2 line. Behaviour only, using the same rigged base as everyone else.
- **EXISTS:** the job9 enemy framework, once it lands.
- **BUILD:** the hostile and neutral behaviours. The look and the names wait for Greg. **Proposal, needs Greg:** what each one does.
- **PROOF:** an encounter capture and a behaviour test.

### v2-3 Drains route and doctor chase
- **GOAL:** the two v0.2 routes named in BUILD_PLAN.
- **EXISTS:** the job5 facility map, once it lands.
- **BUILD:** **proposal, needs Greg.** The layout and the chase beats are not recorded anywhere.
- **PROOF:** a playthrough capture with no loading screens.

### v2-4 Duelist and Shade disciplines
- **GOAL:** Greg's list: "more disciplines (Duelist, Shade) in the lab".
- **EXISTS:** the lab-52 WIP commit.
- **BUILD:** the movesets in the lab first, then on to the map.
- **PROOF:** lab PNGs and sparring tests.

### v2-5 Systems combine
- **GOAL:** Greg's flag example: wind × cloth × bullets × destruction × fire × liquid.
- **EXISTS:** lab-54 (pending), the flag, the lab-46 fluid and the lab-47 voxels.
- **BUILD:** one interaction table and the pairs in it. Liquid conducts shock already works.
- **PROOF:** a PNG per pair.

### v2-6 BeamNG-style vehicles
- **GOAL:** "real crumple, parts that bend and come off, engine damage" on our destruction. (Greg, 5 Oct 02:25)
- **EXISTS:** lab-53 (pending, priority 98 by Greg), the lab vehicle pad, and the lab-47 ramming tier (35 kJ per tier).
- **BUILD:** one vehicle in the lab.
- **PROOF:** crash PNGs and an fps number.

### v2-7 Sound pass
- **GOAL:** footsteps, hits, ambience, and a placeholder examiner voice. (Greg, 5 Oct 02:10)
- **EXISTS:** polish-50 (pending).
- **PROOF:** a listening checklist.

## 4. Questions for Greg
1. Is the v0.2 order above right? Phone first, or the routes first?
2. Should the vehicles stay in v0.2 or move to the lab backlog?
3. Which kind of 144 fps proof do you want before the v0.1 tag: the full map, or each lab system?
