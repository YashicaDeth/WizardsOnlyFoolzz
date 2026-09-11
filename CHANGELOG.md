# Changelog

## 2026 09 11

- **The Allusions screen becomes a natal sigil.** `systems/natal_sigil.gd`
  draws a twelve-house wheel with hand-built sign glyphs, places the bodies
  deterministically from a birth date, draws the classical aspects between
  them, and then performs the actual chaos magick operation on the result:
  strike out every repeated meeting point and bind what is left into one closed
  mark. `DESIGN.md` §16 already put chaos magick in the world's rules and
  `world_history.gd` already reads subjects on an Ascent/Limbo/Descent axis;
  this is the drawing of both. Stated plainly on the plate and in the file:
  it is symbolic, not an ephemeris.
- Fixed the sign boundaries while building it — `SIGNS` starts at Aries, which
  is the third month, so indexing it by `month - 1` put every date three signs
  out and read 14 August as Libra. Checked against eight known dates.

## 2026 09 11

- **The game has a typeface.** Every interface in the project was set in
  `ThemeDB.fallback_font` — Godot's default UI face — which is the single
  loudest "unfinished engine project" signal there is, and Greg named it.
  `systems/celloutz_type.gd` is a stencil display alphabet built from stroke
  paths on a 6x10 cap grid, in the register of something cut through a plate
  with a torch. Nothing to licence, no atlas, scales to any size, and the
  letterforms belong to the game. Headers, numerals and stamps use it; body
  copy stays in a legible face.
- The warning card, the Living Map, the transit plate and the resolution form
  are set in it, including a double-struck out-of-register stamp for headers.
- **Derby engagement retuned.** The cap made contact too rare: a parked player
  finished thirty seconds untouched on some runs, which is the opposite failure
  to the one being fixed. The ramp starts at two hunters rather than one and
  reaches three in thirteen seconds. Measured over three consecutive runs: peak
  crowding 3, hull 97, stable.

## 2026 09 11

- **A front door.** The game opened straight onto a button column. It now opens
  on a CellOutz product liability notice in the Postal 2 register — blunt, not
  sorry — which is also where the violence tier is chosen. Those three tiers
  already existed and were buried in a settings submenu nobody opens, which is
  a strange place to keep the one setting the whole game is about. Shown once
  per install; still changeable in settings afterwards.
- **The menu is a scene now, not a backdrop.** `systems/front_door.gd` drops
  meat-industry junk past the camera — organs, tins, bone, teeth, syringes,
  paperwork — on the project's own materials, lit and tumbling. Generated
  geometry, nothing imported.

## 2026 09 11

- **Every albedo in the game was a flat colour.** `WorldLook.surface()` only
  ever set a roughness texture, so no surface in the project had any albedo
  detail at all — which is the real reason the world read as untextured
  primitives regardless of how the geometry was built. Surfaces now carry a
  generated contamination texture: blotching, vertical weeping, cellular grime,
  panel seams, posterised to seven levels and sampled unfiltered for PS1-era
  crunch. Cached hard, because a pit of twelve wreckers would otherwise build a
  thousand of them.
- **The Ashbloom region never used the material system at all.** The world
  generator had its own flat `_material()` and never touched `WorldLook`, so
  every wall, road and shell in the region was a single untextured colour. It
  routes through `WorldLook.surface()` now.
- **The region was drowning in its own fog.** 0.014 density with 0.88 ambient
  washed everything past a few metres into one flat brown haze, hiding whatever
  the materials produced. Density down to 0.005, ambient down, saturation and
  contrast up — contamination colour is supposed to be the thing you notice.

## 2026 09 11

- **Grappling.** Combat had no contact-range verb at all — everything resolved
  at sword reach or not at all, so two people standing on top of each other
  swung through one another. `C` takes hold of someone in front of you and
  starts a stamina contest: hold the strike button to press, Space to let go.
  Winning puts them in the **downed window alive** rather than killing them,
  which makes the clinch the unarmed route into the execute / spare / recruit
  decision the game is built around. Losing it hurts and throws you clear.
  Covered by `tests/grapple_test.gd` (11 checks).
- **Bruising.** Zone tint went straight from clean flesh to dark red, so a body
  took a sustained beating and showed nothing until it was nearly ruined —
  which is most of why blunt hits read as having no effect. Damage now arrives
  as bruising first and only opens into blood below 55% of a zone's health.

## 2026 09 11

- **Scene changes are no longer hard cuts.** Every transition in the game
  swapped `.tscn` files with nothing covering it, which is most of why the game
  read as a set of dev tools rather than one place. `systems/interstitial.gd` is
  autoloaded so it survives the swap it covers, and all five transitions route
  through it: menu to derby, menu to vat, vat to derby, and both derby exits
  into the Hunt Grounds.
- The plate is the interstitial register `ART-DIRECTION.md` and Tier 2.6 already
  specified: a procedural skeleton turning on the spot — ribcage, skull with jaw
  and sockets, clavicles, pelvis and jointed limbs — with its organs lighting
  and naming themselves one at a time, over deadpan CellOutz transit paperwork
  and a progress bar that admits it knows nothing. Drawn in code from the same
  body plan the dossier, the resolution form and the kill cam use, so the
  anatomy on the loading screen is the anatomy of the world.
- The first version photographed as a scarecrow: centred rib arcs close into
  hoops once the body turns face-on, and the limbs floated beside the spine
  rather than hanging off it. Caught by looking at the capture.

## 2026 09 11

- **Gore now reads in play, and the floor remembers the fight.** Three separate
  causes. The Hunt Grounds **never applied the GORE setting at all** — that code
  lived only in the derby, so OFF did nothing once the player left the pit and
  REDUCED leaked across as a static the hunt never reset. Blood **evaporated**
  after about two seconds, so nothing ever accumulated. And a 24-damage sword
  hit threw **four drops**.
- Blood that lands is now a persistent spatter mark rather than a drop that
  disappears: airborne blood stays capped for the frame rate, landed blood is a
  flat mark with no simulation attached, capped at 420 and recycled
  oldest-first. "Heaps of gore" is a property of the floor, not of the air.
- The spatter is a ragged jittered fan with thrown fingers, not a quad. The
  first version used quads and photographed as red confetti — four hard corners
  and a straight edge read as tiles from every angle. The second version had no
  vertex normals, so it had no defined lighting and rendered black under the
  Ashbloom fog: a floor covered in blood that was invisible. Both were caught by
  looking at the capture, not by a test.
- Both scenes now read the setting through one shared
  `BaselineHuman.apply_gore_setting()`, so the derby and the Hunt Grounds cannot
  disagree about it again.
- Added `tests/gore_test.gd` — 10 checks covering spray volume, blood landing
  and persisting, both caps holding, and FULL/REDUCED/OFF actually meaning what
  they say in the Hunt Grounds. Ten suites now pass.

## 2026 09 11

- **The derby no longer piles onto the player.** Measured first: five cars
  inside nine metres by twenty seconds, eight of twelve wedged motionless. Two
  thirds of the pit hunted the player permanently with no cap and no ramp, and
  the "duellists" chased the nearest vehicle — which in a scrum is the player
  again. At most three wreckers may now engage, the cap ramps in over the first
  twenty-two seconds, roles rotate every 2.6s, two cars circle at range and the
  rest are paired off against each other. Peak crowding 5 -> 2, cars moving
  7-10 of 12 instead of wedging, and the pit hits *harder* (hull 83 vs 90)
  because cars arrive with speed instead of grinding.
- **Fixed a permanent three-point-turn deadlock in the derby AI.** A car pointed
  away from its target alternated reverse and creep-forward at full lock, both
  at about one metre per second, indefinitely: the nearest wrecker held 8.2m
  from a parked player for thirty seconds while the player took no damage at
  all. Reversing now commits for a minimum time with hysteresis on the exit, and
  a slow car that needs to turn is given more throttle rather than less, because
  the chassis scales steering authority by speed. This is the third instance of
  that same root cause and it should be the first suspect next time.
- **Wreckers break off instead of leaning.** A driver that stalls against its
  target for two seconds peels away and comes back round, so contact reads as
  discrete passes. The break-off triggers on an actual grind — close and slow —
  not on mere proximity; an earlier six-metre threshold aborted runs before
  contact and left a parked player finishing a heat on a full hull.
- `tests/derby_balance_test.gd` now bounds crowding from both directions: never
  more than four cars on the player, never zero. Attempts to enlarge the arena
  by raising `ARENA_SCALE` were measured, found to empty the heat, and reverted;
  the numbers and the reason are recorded in ROADMAP.md.

## 2026 09 11

- **The Living Map is an actual map.** `M` opened five lines of hardcoded prose
  describing districts that the player could not locate, reach or use. Replaced
  with `systems/living_map.gd`, which draws the region that was really
  generated: the three road spines, every building footprint from
  `AshbloomWorldGenerator.lots`, the seeded Reality Misfires, live contacts
  coloured by disposition, loot caches and the player's own heading cone.
  Pan, zoom, recentre and a metre-accurate scale bar.
- **The map is surveyed rather than given.** Walking charts the ground around
  you; unwalked cells stay hatched and withhold the buildings and district names
  on them. The survey persists through `WorldHistory` as `ashbloom_survey`, so
  the chart a returning player opens is the one they earned. An unidentified
  signal shows as a mark, not as the words "UNIDENTIFIED SIGNAL" repeated
  eleven times across the sheet.
- **Lock-on.** Third-person combat had no way to commit to a target, so a swing
  at anyone circling you was guesswork — the "combat doesn't work" complaint.
  `Z` or middle mouse locks the best candidate in front of the player, the wheel
  cycles, the camera steers to hold the pair, the body turns to face them, a
  reticle marks them, and **a locked target wins the strike over a nearer body**.
  Lock breaks on death, distance or a second press.
- **Third-person camera rebuilt to a Souls register.** It was parked 6.5 m dead
  behind the head, unsmoothed, and aimed *at* the player — which cancelled any
  shoulder offset and re-centred the body every frame, so it read as an RTS
  chase cam. Now spring-damped, closer, over one shoulder, aimed parallel to the
  look heading, and widening when locked so backing off a target frames both.
- **The camera no longer ends up inside walls.** The obstruction test ran on the
  *target* position and the smoothing then blended toward it, so the camera sat
  inside geometry for every frame of the blend. The test now runs last, on the
  position actually used.
- **Melee aim landed on the wrong limb.** The hit resolved against a free
  world-space point projected from the player, so the zone opened depended on
  how far off-axis the target had drifted and how much higher it was standing —
  a level swing at someone on a kerb opened an arm. Aim now selects *where on
  the target's body* the blow lands. This was a real defect, found by
  instrumenting the failing `opening_test` check rather than by reading it.
- **Full-sheet panels own the screen.** The map, dossier and artwork were drawn
  under the live field HUD, so every one of them read as a debug overlay with
  the crest and control ribbon printed through it.
- Added lock-on coverage to `tests/combat_integration_test.gd`, including the
  case that matters: a body standing nearer than the locked one does not steal
  the swing. Added `--trigger=map_walked`, `--trigger=walk` and
  `--trigger=lock` to `tests/capture_scene.gd`. All nine suites pass.

## 2026 09 11

- Added a three-slot hunter arsenal: Ashline cleaver, five-shell Bone Yard 12G
  and ten-round Mercy Nine. Number keys equip real procedural models on the
  BaselineHuman right arm; firearms own magazines, reserve ammunition,
  deterministic spread, cooldown and timed reloads.
- Integrated firearm raycasts into the live Hunt. World geometry occludes fire;
  pellets resolve against the struck NPC rig, apply zone/organ injury,
  knockback, critical flight/downing/death, persistent anatomy and history.
  Shotgun pellet accumulation can cross the existing limb-loss threshold—the
  weapon does not fake a separate dismemberment effect.
- Added compact HUD weapon/ammunition marks, dry/reload feedback,
  `arsenal_test.gd` (11 checks) and `combat_integration_test.gd` (4 checks).

- Repaired Hunt Grounds WASD at the convention boundary: Godot reports W as
  negative input Y, while the prior controller added that value to camera
  forward and therefore drove the hunter backward. A shared `HunterMotor` now
  owns camera-relative direction, normalized diagonals, grounded acceleration,
  air control, braking, gravity, floor snap and slope limits.
- Directional dodge now follows held movement input, with a backward fallback.
  First/third-person switching updates in the input frame, and the chase camera
  ray-clamps toward the hunter around walls and concave corners.
- Added the playable `movement_lab.tscn` course (door, curb, ramp and snag
  corner) plus 11 automated checks covering direction, yaw, diagonal speed,
  grounding, camera obstruction and physical forward travel.

- Added the live downed-person confrontation: an obstruction-aware shoulder
  camera, compact choices tethered to the subject, and execute/spare/recruit
  outcomes while other actors and blood loss keep running.
- Added consent-gated recruitment, persistent survivor memories, unique
  resolution events, non-hostile spared/recruited states and single-drop
  execution loot.
- Connected execution to the real BaselineHuman anatomy snapshot. KillCam now
  distinguishes all seven internals, highlights actual ruptures and restores
  global time on completion, cancellation or removal while preserving its
  existing derby call.
- Added local hold-V proximity voice capture inside the confrontation. Raw
  samples remain transient; duration/contact history persists and the reply
  acknowledgement originates at the subject's head with an in-world subtitle.
- Added `resolution_test.gd`: 30 checks for lifecycle, input, consent, voice,
  world continuity, history, loot and kill-camera compatibility/time cleanup.

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
