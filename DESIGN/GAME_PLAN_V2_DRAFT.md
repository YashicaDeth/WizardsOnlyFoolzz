# Game plan v2: DRAFT for Greg to review

Started by the hourly build manager, 2026-10-05 15:10. This is a draft. It does not change GAME_PLAN.html or BUILD_PLAN.html, and no v0.2 job has been queued from it. Anything not taken from Greg's recorded decisions is marked **proposal, needs Greg**.

## 1. What v0.1 "Escape" actually delivered (as of 15:10, 5 Oct)

6 of the 10 v0.1 jobs have landed on `claude/launch-latest`. Details are in DESIGN/REMASTER_LOG.md.

| Job | Landed | What works | What is still weak |
|---|---|---|---|
| job2b rigged bodies on Jolt | yes | Every dummy stands on one rigged skeleton, with a head and ordinary shoulders. Cut limbs keep their skin. Death is a jointed ragdoll. X-ray works under the skin. | The skin reads as a checker, not flesh. Heads look like helmets. The idle is a hunched crouch. There are gaps at the ankles. `fix-job2-body-look` is pending. |
| lab-46 liquid and glass | yes | The glass cracks in stages and bursts into shards that stay. The fluid sloshes, pours, pools, drains slowly and conducts shock. | The pour is overlapping spheres, not a surface. The pool flows under obstacles. There is no sound. It was never rendered on the GPU. `remaster-lab-46-p1` is pending. |
| lab-48 organs, cybernetics, X-ray | yes (248ea0c9) | The chest opens through a wound. Organs are ripped by hand from downed or dead bodies. You can install an organ in yourself or sell it. The X-ray scans implants, organ health and loot value. Shock shorts implants, and a second shock burns them out. | Lab lighting is a flat brown wash. Every HUD line is red, which breaks "red only on danger". Debug text overlaps the scan panel. Blood pools are flat red squares. |
| lab-47 Teardown destruction | yes (c73a2e0e) | The 5 toughness tiers are one table. 15 cm voxel walls break where hit and drop loose pieces. There is a diggable dirt patch. One blast system covers the grenade, charge, drill and shovel. | Explosions have no smoke or sparks. The ground is one colour. It was never rendered on the GPU. `remaster-lab-47-p1` is queued. |
| job3 moving and fighting | yes | HOTLINE CLEAVER and PRODSTAFF work with buffer, hitstop, stagger, block and parry. Movement has sprint, crouch and roll. There is lab ADS and lock-on. The arcade guard can be cut. | The first-person swing is a pose, not an animated arm. There is no swing or hit sound. The Hunt still issues the old sword. `remaster-job3-p1` is pending. |
| job4 waking in the vat | yes | First-person wake in red liquid, real glass and a flood. | It was not rendered at landing. `remaster-job4-p1` is pending. |
| job5 one facility map | running | | Greg's top priority ("the map is the main thing"). |
| job6 examiner | pending | fix-55 moved him onto the rigged base. | The boss fight itself is not built. |
| job9 enemies | pending | | |
| job7 death, saves, HUD | pending | | |

Fixes that also landed: fix-hidden-cache-test, fix-58 (an execution on a downed body is one beat and ends with them dead), and fix-55 (the examiner no longer uses the Higgsfield skin).

## 2. What v0.1 still needs before v0.2 starts

These come from Greg's notes, in his order:
- The facility map (job5) and the examiner (job6). Without these, START to surface cannot be played.
- Enemies (job9) and death, saves and HUD (job7).
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
- **EXISTS:** the pending `v02-51-black-mirror-pickup` task, plus the phone pages already in the game.
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
