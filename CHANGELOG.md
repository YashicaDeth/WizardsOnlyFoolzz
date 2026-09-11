# Changelog

## 2026 09 11

- **One baseline human rig** (`systems/baseline_human.gd`) owns the zone vocabulary, hit geometry and anatomy for every person in the world. Fixes a silent defect: zone names that AnatomyComponent did not recognise resolved to `torso`, so the derby's `legs` hitbox and the hunt's `left arm` wounds were being recorded as chest wounds. Hits now resolve to where they landed rather than to a round-robin.
- Derby drivers run the rig instead of a `driver_health` integer, and their injuries persist on their subject — a wrecker rebuilt after taking a leg wound still has it. "Bodies remember" now applies to a procedurally spawned nobody, not only to hand-authored characters.
- **Gore on the rig**: blood scaled by damage and by whether the weapon cuts or breaks, permanent compound fractures, organs spilling from a destroyed chest, exposed bone at a severed joint. Capped globally and spawned into world space so a driver's blood does not ride inside a moving cab.
- Gore moved out of the `[V]` hotkey into **Settings** as FULL / REDUCED / OFF, stored as a `WorldHistory` subject so every scene agrees.
- **The derby had never worked as a fight.** The chassis scales steering authority by speed, so a stationary car cannot turn, while the AI set throttle to zero whenever a car was side-on to its target — a permanent deadlock. The nearest wrecker sat at 12.6m for thirty seconds and the player took no damage. Also removed the charge falloff that had wreckers arriving at walking pace, below the impact threshold.
- **Menu fixed.** It rendered near-black from a hand-rolled Environment with a flat 0.5 ambient and a single spotlight; migrated to `WorldLook` with a key light. The colour setting had never visibly worked because it wrote `ambient_light_color` on a sky-sourced environment; it now swaps presets. Buttons were centring labels inside differing widths, which is what made the column read as broken.
- **HUD readouts** given a shared notched plate with a substrate, so live data no longer floats unreadable on the sky. The grudge meter shows grudge; it previously drew `(grudge + index * 13) % 17`, which was motion shaped like data. Removed the control ribbon's collision with the mode label, and a scanning line that carried no information.
- Fixed the derby audio boom on boot: engine layers started at driving volume while `update_engine` only runs once the round is active, so the whole countdown played a full-level 41Hz rumble. They fade up to idle.
- Added `tests/baseline_human_test.gd` (27 checks) and `tests/derby_balance_test.gd` (which caught the inert pit). Suites total 61 checks across four scenes, all passing. Verified the opening cutscene still plays by capture.

- **Tier 1a impact feel.** Fixed the three causes of weightless rams in `arcade_vehicle.gd`: an uncapped lateral grip force that cancelled side impacts inside one frame (the dominant cause, and not the one originally diagnosed), sustained drive force turning contact into a shove, and nothing able to break a two-car stalemate. Grip is now a friction limit, drive and steering cut briefly on impact, and a sustained press kicks the pair apart as a discrete event with a slew.
- Impacts now carry a `self_share`, so the car that drove into the other wears the damage rather than both splitting it evenly.
- Destruction scales with the square of closing speed: a committed ram strips panels on the first contact. Added camera shake, panel debris and an asymmetric shell fold toward the hit.
- **Removed the need for a reset key.** A car that cannot make progress backs itself out and swings clear, and the heat resolves on a visible count instead of waiting on ENTER. `R` still works during development but is no longer advertised in the HUD.
- Added `tests/impact_test.gd` — 10 checks covering separation bounds in both directions, the grip cap, the contact lockout, the blame split, grind breakup and wall unstick.
- Fixed `opening_test.gd` calling `_process` on the derby, which only defines `_physics_process`. It errored out and silently skipped its last three checks; all 19 now run and pass.
- Captured from Greg: guns, and one baseline human rig for every NPC. The rig gates persistent injury, prosthetics, zone-matched gore and proximity voice, and is scheduled before the limb/organ work rather than after.
- Added `web/index.html`, the CellOutz storefront for celloutz.xyz. No payment details are collected on the page by design; checkout belongs on a processor's own domain, and the order links are marked swap points.

- Added exterior AStar routing around generated building footprints; encounter actors now use CharacterBody3D collision and route refresh intervals, including wounded flight.
- Added timed close-range hostile attacks and dodge avoidance for encounter actors.
- Added E interactions for friendly healing/bonds, currency-consuming trade and collectible testimony; persisted encounter resolutions and a 15-second encounter dispatch cooldown.
- Expanded isolated behavioral validation to 18 passing assertions, including exterior obstacle avoidance, friendly resolution, trade, escaped-actor suppression and derby countdown/result transitions.
- Navigation remains exterior-only and does not yet represent doors, furnishings or arbitrary terrain props. Visual/feel verification and production assets remain outstanding.

- Audited previous completion claims and distinguished startup smoke checks from gameplay validation.
- Added CharacterBody3D hunter movement, physical floor, collision-aware dodge, melee windup, attack cooldown and hidden-Mara hit rejection.
- Moved artwork to J; menu input now suppresses attacks and releases the pointer.
- Made loot collectible once into persistent inventory; added anatomy restoration and suppressed respawning dead/escaped actors.
- Replaced random overlapping building positions with deterministic spaced lots; regeneration clears owned geometry.
- Added visible derby countdown and stopped gameplay updates after terminal results.
- Added isolated opening_test.tscn behavioral checks. Eleven assertions passed, including wall/door traversal, loot uniqueness, migration and bleeding treatment/death. Tests use ATG_TEST_MODE=1 and do not access campaign saves.

## 2026 09 10

- Named the first Limbo region **The Ashbloom Expanse** while retaining World Zero as the production milestone.
- Added the Living Kinship Web: a zoomable/pannable relationship graph with ten seed subjects, procedural faces, faction links, ELO ranks and simultaneous Vessel/Deep X-ray dossiers.
- Added save-safe subject schema migration so new anatomy and relationship fields do not erase old grudges, wounds, bonds or memories.
- Added a reusable anatomy simulation foundation: zone health, blood volume, bleed rate, pain, consciousness, treatment, cybernetic armor, critical state and death snapshots.
- Added hostile panic/escape/chase/loot behavior. Critical NPCs flee, continue bleeding, persist an escaped or dead state and drop a visible loot cache when caught.
- Added stylised limb-disable debris and persistent severing events as a mechanical prototype; final anatomical meshes, constraints and animation remain an authored-art task.
- Added deterministic Ashbloom generation with five settlement districts, collision-built enterable shells and more than forty interiors, plus crossing roads.
- Added 18 seeded **Reality Misfires** with friendly, social, trade, mystery, bond, hostile and boss categories.
- Added selective trimesh collision generation for major authored Bone Yard surfaces and structures.
- Added 64 reactive crowd silhouettes, driver head/torso/leg hit areas, staged vehicle-part shedding and physics-driven detached doors, hood, bumpers and wheels.
- Added derby victory/defeat states and an Enter-to-exit result flow.
- Added runtime placeholder engine, collision, crowd and Ashbloom wind audio so the audio event path is functional before production recordings are selected.
- Added Mara's conditional second encounter, rebuilt Wrecker, visible industrial prosthetic, increased health and two Ashline reinforcements.
- Added a result-reactive CellOutz Wire report and history/grudge-reactive interactive Allusions artwork, opened with `A`.
- Replaced the derby's static box HUD with a responsive CellOutz vector interface: animated edge framing, live speed arc, hull bar, score interpolation, Hunt signal waveform, impact shock-rings, kinetic event notices and a scalable control ribbon.
- Added a restrained full-screen treatment with procedural grain, scanlines, vignette and chromatic separation. It reads the rendered scene directly and requires no copied texture assets.
- Added a reusable animated main-menu layer with a living Tree motif, orbiting archive nodes, scanning title signal, pulse footer and eased button hover transitions.
- Validated the main menu, derby and Bone Yard Hunt scenes after the UI pass with no scene, script or shader runtime errors.
- Replaced the derby's generated empty-circle presentation with the first authored Bone Yard environment kit: 233 named Blender meshes covering the quarry bowl, oval lanes, grandstands, mechanic bays, faction banners, barriers, ramps, freight containers, salvage silhouettes, floodlight towers and the exit gate.
- Added reproducible Blender source, an editable `.blend`, a Godot-ready GLB export and a 1280x720 review render. Integrated and validated the imported environment in the live derby scene.
- Added the playable Bone Yard Outskirts transition: leave the derby vehicle with `E` and enter an explorable Hunt Grounds scene.
- Added the first connected combat/Hunt Arc component: third/first-person camera, sprint stamina, melee range/facing checks, body-zone injuries, dodge, prosthetic surge, stylised blood debris, a friendly bond interaction, Mara's canonical first encounter and her persistent escape state.
- Added three live data views to the Hunt Grounds: World Index (`Tab`), Living Map (`M`) and Character Tree (`T`). Each reads the same persistent world history rather than a separate quest state.
- Added the first World Zero Hunt Arc: Bone Yard Captain Mara Voss now has a persistent identity, ELO, injury, grudge and encounter memory. Damaging her derby car writes a named consequence into world history.
- Extended `WorldHistory` from an event log into a persistent subject ledger, suitable for characters, factions and later businesses to expose state without hard-wired dependencies.
- Added the in-game World Index overlay (`I`) to inspect Mara's live record and recent history during the derby.
- Fixed empty runtime mesh naming in the derby scene, removing the repeated Godot runtime errors during vehicle construction.
- Added the original Rift Derby demolition prototype.
- Added Forward Plus remaster presentation settings.
- Restored verified Dialogue Manager, gdUnit4, Terrain3D, Proton Scatter and Codex bridge editor registration.
- Added the persistent `WorldHistory` event service and recorded derby session, collision and reset events.
- Reworked the derby from neon occult presentation to a rusted scrapyard tone with restrained lighting and dark-red impact debris.
- Added active oval-track wrecker movement and converted the player vehicle into a wheeled demolition car.
