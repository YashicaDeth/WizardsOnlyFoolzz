# Code map

Godot 4.7, GDScript. Project root: `game/`. Scenes in `game/`, systems in `game/systems/`, tests in `game/tests/`.

## Scenes
- `blood_waterfall_exit.tscn`
- `bone_yard_hunt.tscn`
- `boot_splash.tscn`
- `buried_city.tscn`
- `country_town_menu.tscn`
- `derby_tunnels.tscn`
- `doctor_vehicle_bay.tscn`
- `facility.tscn`
- `facility_tunnel_network.tscn`
- `gore_demo.tscn`
- `npc_conversation_lab.tscn`
- `old_drains.tscn`
- `psy_lab.tscn`
- `rift_derby.tscn`
- `service_arcade.tscn`
- `support_unit.tscn`
- `underground_colosseum.tscn`
- `vat_chamber.tscn`

## Systems (first doc line of each file)

| File | What it is |
|---|---|
| `systems/aim_down_sights.gd` | Greg, 4 October: "fix the aiming so we're actually aiming down a barrel ... |
| `systems/alarm_director.gd` | Facility alertness for one place (Greg, 24 September): "a alarm and |
| `systems/alarm_xray_flash.gd` | The moment the facility has you (Greg, 24 September): "the depth map like |
| `systems/algiz_reticle.gd` | Greg: *"the cursor should be the algiz that is used in the logo and it should |
| `systems/ambient_audio.gd` | Greg, 28 September (question boxes): the sound pass for minutes 0-30. |
| `systems/ambient_bed.gd` | Greg, 28 September (question boxes): every opening room gets its own |
| `systems/anatomy_component.gd` | Defeated but not dead. Every resolution the player can choose — execute, |
| `systems/anatomy_presentation.gd` | AX1.6. "Explicit anatomy and the mosaic/censorship presentation are equally |
| `systems/arcade_vehicle.gd` | Upright arcade chassis. Solver contacts handle momentum and restitution; |
| `systems/art_gallery.gd` | Greg, 29 September: "an in-game art gallery ... from posters and business |
| `systems/art_set.gd` | G1.3–G1.5. The bridge between Greg's own artwork and the running game. |
| `systems/ascent_entities.gd` | E5. "Ascent entities are not a shop. They are the lower ranks of the thing |
| `systems/ashbloom_holdings.gd` | Persistent surface holdings derived from the five settlements that already |
| `systems/ashbloom_pathfinder.gd` |  |
| `systems/ashbloom_seals.gd` | E2.3. Marks that belong to Ashbloom rather than to a borrowed occult |
| `systems/ashbloom_world_generator.gd` | The five settlements. Named here rather than inside `generate()` so anything |
| `systems/asset_network.gd` | F6. The handheld's coercive personnel channel. An asset is an existing |
| `systems/audio_bus.gd` | G5.1. The bus graph, in one place, because it was not in any place. |
| `systems/audio_reactive.gd` | The radio drives the picture. |
| `systems/ballistics.gd` | AF1. A round is a thing that travels. |
| `systems/baseline_human.gd` | One rig for every person in the world. |
| `systems/bingyang_cell.gd` | One cell of the Mental and Physical Support Unit's ward (DESIGN/BINGYANG.md: |
| `systems/bingyanger.gd` | A bingyanga held in the Support Unit, and the bingyanger it becomes when the |
| `systems/biometric_barrier.gd` | The facility authenticates tissue, not consent. A guard's body remains a |
| `systems/black_mirror.gd` | I0.5. The handheld's shell, re-specified by Greg: *"the internet portal |
| `systems/black_mirror_camera.gd` | Which of the phone's cameras is up: the low-light sensor, or the LiDAR-style |
| `systems/black_mirror_transition_audio.gd` | Three temporary sound sketches for the Black Mirror comparison. They share |
| `systems/blade_read.gd` | Which way a blade is coming, and whether what you are holding up meets it. |
| `systems/block_tracker.gd` | Blob tracking over the fight, in the TouchDesigner register (Greg, |
| `systems/blood_flow.gd` | Greg: *"even add in blood to there body as a fluid start working on the fluid |
| `systems/blood_ledger.gd` | Blood: the experience each weapon and fighting style earns by being used |
| `systems/blood_pool.gd` | Blood pooling: what per-drop splats never become. |
| `systems/blood_readout.gd` | "+N BLOOD // <WEAPON>": the moment a weapon learns something. Pops beside the |
| `systems/blood_tree_view.gd` | The four style trees side by side: what each style has earned, what it |
| `systems/blood_trees.gd` | Greg, 24 September 2026: "each style or weapon earns its own experience, |
| `systems/blood_veil.gd` | AG4.2. Blood on the lens. |
| `systems/body_cam_feel.gd` | Greg, 28 September (question boxes): the opening felt floaty. He asked for |
| `systems/body_cam_osd.gd` | The in-game HUD as body-cam footage (Greg, 24 September): a REC dot and a |
| `systems/body_forms.gd` | Nudity and its censor (Greg, 24 September: "then from there we can make |
| `systems/body_inspector.gd` | Point at a part of a body, and that part leaves the diagram and turns. |
| `systems/body_mesh.gd` | Geometry factory for the baseline human. Kept apart from `baseline_human.gd` |
| `systems/body_mirror.gd` | B9.1 / B9.2 / B10.10 / AH1.5. The mirror in the room shows your body, current. |
| `systems/body_slice.gd` | Cutting a body somewhere the rig did not plan for. |
| `systems/boons.gd` | E4. "Boosts are always temporary. The cost should be paid in the body or in |
| `systems/brain_chip_flash.gd` | The chip in an alerted character's skull, flashing on their model (Greg, |
| `systems/brain_crt_display.gd` | Live phosphor face fitted to the cortex specimen in `PartViewer`. |
| `systems/brain_hack.gd` | Beat 10 of `DESIGN/OPENING_TORTURE_INTAKE.md`, steps 1-4 in Greg's order |
| `systems/brain_index.gd` | AT. WETWIRE — the brain, the chip and the index. `DESIGN/THE_BRAIN.md`. |
| `systems/brain_index_hub.gd` | The Brain Index hub (Greg, 2026-09-24): one large overlay on Tab. Your real |
| `systems/brain_screen.gd` | The brain screen (Job 4, BUILD_PLAN v0.1 "Escape": "Brain screen: pick 2 |
| `systems/breakable_door.gd` | Destruction, first real case: the door the doctor left through, which Greg |
| `systems/breakable_prop.gd` | A piece of the world that can take a hit without turning every wall into a |
| `systems/broken_web.gd` | I2. The surviving internet as many worlds rather than one feed. |
| `systems/cab_reticle.gd` | Greg: *"you still cant shoot"*. |
| `systems/cab_screens.gd` | Dash screens bolted into the cab: a hull schematic showing which panels have |
| `systems/calling.gd` | Calling and summoning people (Greg, 24 September, DESIGN/ESCAPE_ROUTES.md): |
| `systems/carrion_scavenger.gd` | B4.10v2. Rot is a summons, not a particle effect. This modest world actor |
| `systems/carry.gd` | What you are carrying, as things rather than as a list of nouns. |
| `systems/case_menu.gd` | The Wire exchange: cases, skins and the wardrobe on one screen (Greg, 24 |
| `systems/cast_names.gd` | Names, generated per save. |
| `systems/cavity.gd` | Opening a body, rather than running a timer over a closed one. |
| `systems/celloutz_branding.gd` | K1.2. CellOutz's product language is the public face of the faction below. |
| `systems/celloutz_grunge.gd` | Surface damage for interfaces, drawn rather than textured. |
| `systems/celloutz_hud.gd` | The derby windscreen. |
| `systems/celloutz_menu_fx.gd` | Greg: *"make the sigil have effects through designer and be on a red cpu with |
| `systems/celloutz_motion.gd` | Nothing in this game snaps. |
| `systems/celloutz_type.gd` | The project's display face, drawn rather than loaded. |
| `systems/chaos_sigil.gd` | AJ1. "The magic system using sigils and the new and improved chaos magick |
| `systems/character_archive.gd` | The derby captain is generated per save (`cast_names.gd`), so this panel |
| `systems/character_presets.gd` | AX1.3 / AX1.5. "Reusable presets", and "a saved preset gives repeat players |
| `systems/character_sheet.gd` | Who you are, as data rather than as a hardcoded dictionary. |
| `systems/clinch.gd` | F7. Having hold of somebody is a conversation you are winning, not just a |
| `systems/clothing.gd` | AS3. Layers as a world system rather than a paperdoll. |
| `systems/clothing_shell.gd` | Clothes, as the layer a blow meets before skin. |
| `systems/code_rain.gd` | I1. Code as a material rather than a backdrop. |
| `systems/combat_input_layer.gd` | Physical pad controls are stable; a discipline supplies only verb overrides. |
| `systems/combat_response.gd` | Converts a body's real condition and the force of a real hit into combat |
| `systems/combat_stance.gd` | The poses a fight is made of, as numbers rather than as an animation. |
| `systems/contact_entities.gd` | AU5/AV. Who is on the other side of the door, and what a storyboard artist |
| `systems/contact_menu.gd` | The people you carry, the things that noticed you, and the cabinet where |
| `systems/contaminated_air.gd` | A9.1 / A9.2. The air between the player and everything else, which for nine |
| `systems/corpse_contents.gd` | What is on a body, and how much of it you can actually reach. |
| `systems/cosmology_factions.gd` | K1.2 / K1.3 / K4.1 / K4.2 — CellOutz and wizardsonlyfoolz made real, and the |
| `systems/crt_glass.gd` | The curved glass the cold open is seen through. |
| `systems/crystal_ball.gd` | B5.1. A crystal ball, carried in the arm or the pocket, and functional. |
| `systems/curiosity_bot.gd` | A player that is interested in the game (Greg, 24 September: "make an ai |
| `systems/damage_portrait.gd` | A live 3D bust of the driver in the HUD corner, turning slowly and taking the |
| `systems/dash_cluster.gd` | M2.6 / AG3.1. The instruments. |
| `systems/death_beat.gd` | Greg's playtest: dying cut straight to a loading plate, so you did not know |
| `systems/decanting_prologue.gd` | Greg: *"the starting cutscne needs to be lore accurate then have the part |
| `systems/defeat_router.gd` | F5. Defeat changes ownership and position in the world; it is not a reload. |
| `systems/demo_wall.gd` | P3. The demo's authored stop, presented as the institution closing an |
| `systems/demon_ambition.gd` | K5.1 v2. "Lesser demons are rivals reread; they should eventually want |
| `systems/demon_hierarchy.gd` | K4.3/K4.5. A read-only classifier over subjects that already exist — |
| `systems/derby_ai_driver.gd` | Drives an ArcadeVehicle the same way the player does: by setting throttle and |
| `systems/dev_affordances.gd` | Single gate for controls and command-line hooks that exist to exercise a |
| `systems/doctor_examination.gd` | AX1.1 / AX1.2 / AX2.1. The examination is the character creation. |
| `systems/doctor_route.gd` | The way on is through his door (Greg, 24 September 2026): "you can go back |
| `systems/downed_resolution.gd` | The downed-enemy resolution window. Not a menu: the world keeps running |
| `systems/drain_stalker.gd` | The threat in the old drains (Greg, 24 September): "something that hunts |
| `systems/dropped_handheld.gd` | C1.7. The Black Mirror after it leaves the HUD: the same identified object |
| `systems/dust_puff.gd` | Ash kicked up by a committed movement — a dodge, a hard landing. A burst of |
| `systems/event_director.gd` | Plays the overworld's random events (DESIGN/OVERWORLD_EVENTS.md): picks one |
| `systems/event_generator.gd` | Combines `OverworldEventParts` (who, what they want, where, what they do, |
| `systems/event_parts.gd` | The written parts the overworld random events are generated from. |
| `systems/examiner_feed.gd` | The examiner, live, on the camera that watches the tank. Greg on first launch |
| `systems/examiner_fight.gd` | Greg, 26 September (question boxes): an optional fight, revenge or escape, |
| `systems/examiner_look.gd` | Greg, 26 September (question boxes): the examiner is tall and gaunt, in a |
| `systems/exit_reveal.gd` | The arrival reveal (DESIGN/OVERWORLD_EVENTS.md, decided): "Every exit gets |
| `systems/extraction.gd` | B5. Taking a part off a body that has not shed it yet — the deliberate |
| `systems/eye_glare.gd` | The red cross-glare on the eye in Greg's room photograph. |
| `systems/face_model.gd` | AX1.3. "Direct body/face/proportion customisation." |
| `systems/facility_characters.gd` | The people CellOutz puts in a room with you, written down once. |
| `systems/facility_elevator.gd` | A real lift (Greg, 4 October): "you step in, the doors close, the cab |
| `systems/facility_guard_loadout.gd` | One physical guard owns both answers to the encounter: their biometric |
| `systems/facility_guard_post.gd` | AX route beat 5: the barrier and the gun, placed. |
| `systems/facility_routes.gd` | Persistent authority for travel through and out of Sublevel 0C.  This is a |
| `systems/facility_territory.gd` | One persistent account of the opening facility.  Scenes report authored |
| `systems/facility_tunnel_door.gd` | The tunnel kit's in-world door: a bulkhead across the cell with a doorway, |
| `systems/facility_tunnel_kit.gd` | The facility tunnel kit (art-tunnels-07): modular pieces on the 4 m grid of |
| `systems/field_camera.gd` | C3. A camera on the handheld, and photographs that are objects rather than |
| `systems/field_inventory.gd` | A direct field view of the same Carry model the Black Mirror exposes. This |
| `systems/field_lens.gd` | The permanent, very slight bow in the field view. Kept separate from the |
| `systems/field_meds.gd` | Greg, 26 September (question boxes): meds go on hold-4, and a dressing heals |
| `systems/fighter_tier.gd` | Difficulty is who you fight (Greg, 24 September: "tiers are who you fight", |
| `systems/fluid_body.gd` | A body of spilled fluid on a floor: the pour through the air, the pool it |
| `systems/footprints.gd` | Bloody footprints: the trail walking out of the stain. |
| `systems/front_door.gd` | The front end, built to the register Greg pointed at across Postal 2, |
| `systems/gallery_view.gd` | The Brain Index's art gallery: a wall of frames. Hornee's card first (you |
| `systems/garments.gd` | B7.1 / B7.2. What somebody is wearing, as a layer on a zone rather than a |
| `systems/generated_model.gd` | Greg's generated models (Higgsfield, 29 September) arrive as a unit box in |
| `systems/glass_tank.gd` | A glass tank of fluid that cracks, bursts and empties into a FluidBody. |
| `systems/glitch_spider.gd` | PiFrac-DEV Studio's "Glitch Spider particle system" reference — a burst of |
| `systems/godhead.gd` | AQ. The one true godhead. |
| `systems/gods.gd` | A7.1 / A7.2. THE_REWORK §1: *"the gods for each planet and moon and sun |
| `systems/goetic_seals.gd` | E2.2/E2.3. "The 72 seals of the Ars Goetia, from the Lesser Key of |
| `systems/gore_cam.gd` | Greg, Walkthrough 2 (24 September): the derby's kill cam "as a slow-motion |
| `systems/gore_chunks.gd` | Pieces of people, as physical objects that know what they are. |
| `systems/gothic_field_hud.gd` | Whoever the captain is this save. Set from the record by whoever drives |
| `systems/gothic_frame.gd` | Drawn furniture for full panels: a wooden reliquary cabinet with iron corner |
| `systems/ground_hole.gd` | Greg, 25 September: "if you shoot downwards with a gun or if you blow up the |
| `systems/handheld_device.gd` | The one object the interface lives inside. |
| `systems/held_gear.gd` | What is actually in your hands, in first person. |
| `systems/held_item_reliquary.gd` | Bottom-right presentation for anything the hands can own. It copies only |
| `systems/hidden_cache.gd` | Greg, 26 September (question boxes): hidden things in the first 30 minutes |
| `systems/hit_flash.gd` | The instant a blow lands: a white-hot core and a spray of sparks thrown on |
| `systems/hologram_call.gd` | The doctor's 3D call (Greg, 24 September): "he projects you a 3d call of |
| `systems/hornee_card.gd` | Greg, 24 September: "Hornee the zombie mutant, your handmade plush: a |
| `systems/house_look.gd` | The Dust to Bones look, applied to every scene's 3D view (autoload |
| `systems/hunt_contracts.gd` | F10.8/F10.9 / AR2. A contract is not a menu promise or a second money |
| `systems/hunt_memory.gd` | F10.15. The world that produced a hunter is allowed to end; the fact that |
| `systems/hunter_appearance.gd` | Greg: *"the gore in the gore sandbox is not up to date with the gore in the |
| `systems/hunter_arsenal.gd` | One combat vocabulary for held weapons. The arsenal decides timing, spread, |
| `systems/hunter_body_motion.gd` | Procedural placeholder animation for the gameplay body. It poses the visible |
| `systems/hunter_motor.gd` | Shared camera-relative movement for the Hunt Grounds and its movement lab. |
| `systems/impact_feel.gd` | O2.2. The moment of contact. |
| `systems/implant_boot_hud.gd` | "then you get up get some ui cause of your brain implant being hacked" |
| `systems/implant_catalog.gd` | Authored hardware definitions. Names are identifiers, never parsing input: |
| `systems/input_profile.gd` | The one native InputMap used by the opening route, the Hunt and menus. |
| `systems/intake_direction.gd` | D3.4 and D8.3. How the intake is *delivered*, kept apart from what the intake |
| `systems/intake_page_motion.gd` | The intake's pages, animated (Greg, 24 September: "animated, skeuomorphic |
| `systems/intake_watchers.gd` | Beat 3 of `DESIGN/OPENING_TORTURE_INTAKE.md`. Greg: "he says hurry up now, |
| `systems/interactive_allusions_artwork.gd` |  |
| `systems/interstitial.gd` | The seam cover. Every scene change in the game was a hard cut straight from |
| `systems/jump_climb.gd` | Greg, 26 September: "jump and climb everywhere". The drains had it first |
| `systems/key_hints.gd` | Greg, 28 September: friends who know nothing get each new key once, |
| `systems/keys_card.gd` | What can be pressed, on demand, in the game's own face. |
| `systems/kill_cam.gd` | Slow-motion anatomical kill camera. On a lethal impact the world drops into |
| `systems/kill_shot.gd` | Which shots are worth stopping the world for. |
| `systems/knockback.gd` | Deterministic, owner-driven knockback. The system computes the shove; the |
| `systems/lab_cables.gd` | The lab's cables (Greg, walkthrough: "intricate Lain / Evangelion wiring, |
| `systems/lab_dressing.gd` | What turns a tunnel into somewhere people worked, and then died in. |
| `systems/lab_surface.gd` | The facility's real surfaces. Greg on first launch (2026-09-24): the lab's |
| `systems/lab_vat.gd` | One growth vat, built the same way wherever the facility needs one. Greg on |
| `systems/launcher_actor.gd` | AD3.1. "A melee build can close on a launcher and live — the distance is |
| `systems/light_warp.gd` | A3.2. The air around one light, bending. |
| `systems/limb_momentum.gd` | AN1. The arm has mass. |
| `systems/live_body_mirror.gd` | A physical B9 mirror.  Its image comes from a second camera in the same |
| `systems/living_map.gd` | The Living Map. It used to be five lines of hardcoded prose behind `M`, |
| `systems/local_law.gd` | AE. "assassination, executing and sneaking systems with the hostile and |
| `systems/lock_readout.gd` | What you are fighting, read off their body — never a health bar (FINAL_V |
| `systems/lock_ring.gd` | Live-wire rings on the ground under whoever the player is locked on to. |
| `systems/logo_audio.gd` | The logo's sounds (Greg, 24 September: more detail on the logo), generated |
| `systems/logo_embers.gd` | Embers rising off the logo (Greg, 24 September: more detail on the logo at |
| `systems/look_settings.gd` | How the mouse and camera feel, from the pause menu's CAMERA page (Greg's |
| `systems/loot_cache.gd` | Greg pointed at an orange box in the Hunt Grounds with "LOOT // gate scrip, |
| `systems/loot_case.gd` | Digital cases from the dead cloud: a slot-machine box that sells the archive |
| `systems/meditation.gd` | E8. "With the stamina and health a meditation or psychedelic drug part |
| `systems/melee_driver.gd` | Job 3 (v0.1 "Escape"): a held melee weapon swung from the eye, for any |
| `systems/menu_blood.gd` | Blood under the menu item you're on (Greg, 24 September: menus to match |
| `systems/menu_plate.gd` | Greg: *"make the settings and contuine have design and ui instead of looking |
| `systems/mesh_budget.gd` | Greg, 26 September: *"fix performance, 60 fps to 160 fps"*. Measured first: |
| `systems/mic_level.gd` | Live microphone amplitude, for the waveform on the dialogue screen. |
| `systems/mirror_body_state.gd` | B9's contract with the room mirror.  A mirror must read the gameplay rig, |
| `systems/mission_card.gd` | The mission indicator Greg asked for: a task title "in massive celloutz |
| `systems/model_skin.gd` | ModelSkin: Greg's generated, rigged examiner (Higgsfield / Meshy from his M1 |
| `systems/modern_gods.gd` | AJ3/AJ5. "The gods of this world are what is actually worshipped: markets, |
| `systems/motherboard.gd` | E2.4/E2.5. Greg: *"burn and bind seals should have their own animation |
| `systems/natal_sigil.gd` | The Allusions screen as a natal wheel collapsed into a sigil. |
| `systems/nerve_rig.gd` | The player's vitals as one piece of anatomy wired into the frame, not a set of |
| `systems/npc_action_validator.gd` | AI NPC Communication & Relationship System, section 5 and the MVP acceptance |
| `systems/npc_conversation_component.gd` | AI NPC Communication & Relationship System, sections 4 and 8. |
| `systems/npc_debug_hud.gd` | AI NPC Communication & Relationship System, engineering requirements: |
| `systems/npc_dialogue_brain.gd` | AI NPC Communication & Relationship System, sections 2 and 7, plus the |
| `systems/npc_dialogue_contract.gd` | AI NPC Communication & Relationship System, section 5. |
| `systems/npc_dialogue_ui.gd` | The conversation screen, in the register Greg asked for: a Fallout 3 style |
| `systems/npc_ollama_brain.gd` | A real language model behind the examiner, running on this machine. |
| `systems/npc_relationship.gd` | AI NPC Communication & Relationship System, section 3. |
| `systems/npc_speech_output.gd` | AI NPC Communication & Relationship System, section 2's output pipeline and |
| `systems/offscreen_hunts.gd` | F10.11. A hunt belongs to WorldHistory and WorldClock, not to the scene |
| `systems/opening_audio.gd` | G6.2. The Growing Floor has its own sound grammar: a wet electrical room |
| `systems/opening_base_model_kit.gd` | Modular placeholder geometry for the first 30 minutes. |
| `systems/opening_death.gd` | AX4.5. "Until the player's death fiction is authored, opening death uses an |
| `systems/opening_director.gd` | Tracks the opening run as world state rather than as scene-local flags, so |
| `systems/organ_meshes.gd` | The organs as shapes, rather than as seven spheres of different colours. |
| `systems/organ_system.gd` | Organs, cybernetics and the X-ray as ONE system (lab-48). |
| `systems/osc_bridge.gd` | FINAL_V.md §16, "What to build first", item 3: the live link. |
| `systems/outfit.gd` | Clothing as parts you put on (Greg, 24 September: "make the jester outfit |
| `systems/pad_bridge.gd` | Compatibility bridge for detached labs and other unmigrated scenes. The |
| `systems/pad_keyboard.gd` | An on-screen keyboard for the pad (Job 4: "Rename by an on-screen pad |
| `systems/parry_spark.gd` | A parry is steel meeting steel, and it has to read as that at a glance: a |
| `systems/part_viewer.gd` | One body part, turning in place, at whatever scale it happens to be. |
| `systems/particle_portrait.gd` | The "image/mesh to particle cloud" technique — Greg's own references: |
| `systems/pause_gate.gd` | Escape, from anywhere. The game had no pause at all — Escape released the |
| `systems/penetration.gd` | Greg, on what a bullet should actually do to a body: |
| `systems/perception.gd` | AE1.1. "Unseen is a real state with real inputs — light, noise, cover, |
| `systems/perf_probe.gd` | Greg: *"gore sandbox is just m,ad laggy"*, *"13 FPS"*. This session measured |
| `systems/photo_album.gd` | The photo album the Brain Index shows (item 6, Greg 2026-09-24: photos |
| `systems/photo_mode.gd` | Photo mode (item 6, Greg 2026-09-24). F10 in the Hunt freezes the world and |
| `systems/pin_board.gd` | L1. The storyline, as a wall. |
| `systems/pit_radio.gd` | The cab speaker. Every driver in the heat is on the same open channel and |
| `systems/plane_ladder.gd` | Renamed on merge, and the reason is worth keeping. |
| `systems/plane_voices.gd` | AV3.2-AV3.7. "They remember you." |
| `systems/player_action_ledger.gd` | One inexpensive receipt path for concrete player acts. Existing event names |
| `systems/player_faction.gd` | U. "How you can persuade them to join your ranks - your own faction that |
| `systems/point_cloud.gd` | Five of Greg's six TouchDesigner tutorials, as one thing. |
| `systems/procedural_derby_audio.gd` | Positional derby audio. Every player here was previously a non-positional |
| `systems/proximity_voice.gd` | Local push-to-talk transport for conversations with nearby people. |
| `systems/psychedelic_osc.gd` | DESIGN/FINAL_V.md §16, Path C: a live link so a TouchDesigner patch can |
| `systems/psychedelic_rig.gd` | FINAL_V.md §16, "What to build first," items 1 and 2: one shader with six |
| `systems/pulmonary_diagnostic.gd` | A held, rotatable expansion of the contextual lung X-ray. |
| `systems/pyramid_society.gd` | Canonical, presentation-independent model for social standing, dossiers, |
| `systems/quantum_saves.gd` | Three named worlds the player can preserve and return to. They are copies, |
| `systems/rabbit_hole_navigator.gd` | Typed, reversible navigation shared by the Pyramid, Wire and physical tools. |
| `systems/radial_menu.gd` | Hold, sweep, release. The selection grammar for everything the player picks. |
| `systems/radio_audio.gd` | What the radio actually sounds like, and how badly. |
| `systems/ragdoll_body.gd` | Turns the exact rendered BaselineHuman zones into a restrained corpse rig. |
| `systems/reality_misfire_director.gd` |  |
| `systems/rebirth_site.gd` | A place that can kill you (Greg, 24 September: every killer in minutes 0-30 |
| `systems/regal_frame.gd` | The visceral-but-regal border around the cold open, and the thing that stops |
| `systems/resonance_readout.gd` | The compact, truthful payload for a future handheld resonance page.  It is |
| `systems/restricted_storage.gd` | AX3.5. "The Black Mirror is stolen from restricted technology storage as a |
| `systems/rigged_body.gd` | RiggedBody: a rigged, animated low-poly humanoid under a BaselineHuman. |
| `systems/ringmaster_card.gd` | AP1.6. The exchange after the colosseum. Same house register |
| `systems/ritual_app.gd` | E3. "The camera is the ritual instrument... rituals are completed by |
| `systems/ritual_ledger.gd` | E3. A rite is evidence the world can check, never a dialogue option with a |
| `systems/rival_registry.gd` | F4. A rival is a conclusion drawn from the world's record, never a cast |
| `systems/rival_tactics.gd` | F4.2 / J3.1. Tactic adaptation, on LimboAI. |
| `systems/roamer_detail.gd` | AX5.3, the distant half. "Nearby population stays inside the 5-20 fully |
| `systems/room_lights.gd` | Greg, 28 September (question boxes, late): the vat room, the Service Arcade, |
| `systems/room_mirror_view.gd` | Compatibility is intentional: the freestanding BodyMirror follows a body, |
| `systems/route_endings.gd` | E7. "Run it far enough and Greg's endpoint applies: you turn into one, and |
| `systems/run_card.gd` | The end-of-run card (Greg, 26 September): shown once, when you surface |
| `systems/run_lifecycle.gd` | T1.2. "Death is an event in the world rather than a reload." Deliberately |
| `systems/run_timer.gd` | Greg, 26 September (question boxes): the first 30 minutes are timed. The |
| `systems/sandbox_avatar.gd` | The sandbox's player, with a body (Greg, 30 September: the sandbox is where |
| `systems/satellite_view.gd` | A10. The map, as the world seen from above. |
| `systems/script_cost.gd` | Which function is eating the frame. |
| `systems/security_camera.gd` | A CellOutz camera in the Support Unit's hallways (Greg, 24 September: "the |
| `systems/sephiroth.gd` | AR1 / AV1. "The tree of life you are drawing IS the plane ladder — same |
| `systems/service_ring_relay.gd` | A CellOutz surveillance relay in one of the colosseum's three real tunnel |
| `systems/shed.gd` | AU3.1. "A shed, not a void — enclosed, dingy, lit by what is in it." |
| `systems/sight_audio.gd` | Greg, 26 September (question boxes): K = a low choir hum that swells with |
| `systems/signal_field.gd` | Whether you have signal, and why, decided by where you are standing. |
| `systems/signal_sight.gd` | Greg, 26 September: the cameras send invisible signals "that you can only |
| `systems/silhouette.gd` | G4. Why the world still reads as boxes after a texture pass. |
| `systems/silhouette_rim.gd` | Greg, 29 September (question box): in the dark rooms enemies keep a faint |
| `systems/skin_case.gd` | Skin cases: a CS-style case with the game's own rarity ladder (Greg, 24 |
| `systems/skin_loadout.gd` | Which skin is on what. Applying a skin takes it out of the bag and puts it |
| `systems/skin_market.gd` | The Wire's skin market (Greg, 24 September: "make it sellable on economy |
| `systems/skull_burst.gd` | When a head comes apart, and what is left of it when it does. |
| `systems/smokeables.gd` | AU1.8. "Smoking is a real act: cigarettes, vapes, joints, spliffs, blunts, |
| `systems/soul_breakthrough.gd` | AX2.2 / AX2.3. The breakthrough, and who it belongs to. |
| `systems/souls_mover.gd` | Job 3: first-person movement on the Souls pad base, for any owner with a |
| `systems/souls_pad.gd` | A PS4 pad (or any SDL-mapped pad) in the sandbox, laid out like Bloodborne |
| `systems/souls_roll.gd` | A deterministic, owner-driven Souls roll. The caller supplies a direction |
| `systems/spirit_vision.gd` | A spirit the splinter monks invoke (DESIGN/OVERWORLD_EVENTS.md): shown as a |
| `systems/splash_backdrop.gd` | Greg: *"the splash screen fades in with this as the backround image and then |
| `systems/splinter_monk_look.gd` | How the splinter monks look (DESIGN/OVERWORLD_EVENTS.md, decided by Greg): |
| `systems/spoken_contact.gd` | Speaking to somebody in the world, and being understood. |
| `systems/storm_weather.gd` | AS4. Storms are a readout of how much magick is loose, not ambience. |
| `systems/street_light.gd` | AB1.2. `DESIGN/DESTRUCTION.md` step two: one object class, all the way |
| `systems/strike_audio.gd` | What a swing sounds like. Two voices, synthesized once into sample streams |
| `systems/strike_heading.gd` | Which way a melee strike goes. First person aims where you look — that view |
| `systems/strike_smear.gd` | Afterimages of the weapon on a committed swing: the blade leaves a few |
| `systems/strike_trail.gd` | What a swing leaves in the air. Two ribbons from the held weapon's real |
| `systems/subject_icon.gd` | A person's head, turning in place, with an X-ray state. |
| `systems/substance_experience.gd` | AU4. What a state actually looks like. |
| `systems/substance_objects.gd` | AU1.2. "A drug is an object — a baggie, a blister, a tab, a weight." |
| `systems/substance_station.gd` | AU3.2/AU3.5/AU3.6. Everything takeable, in one droppable object. |
| `systems/substances.gd` | E6. "Substances are the access verb for the entity layer... every |
| `systems/support_guard.gd` | A CellOutz guard in the Support Unit. The body is the game's own |
| `systems/support_mail.gd` | Y4. Mail out of the game, to a person. |
| `systems/surfacing.gd` | Greg, 28 September: surfacing into the Hunt is the payoff of the first |
| `systems/sword_moveset.gd` | Authored third-person sword attacks. Mouse motion never enters this class: |
| `systems/tank_body_marks.gd` | Greg's checklist: body horror on your grown body, from your intake answers. |
| `systems/tank_view.gd` | Greg, 28 September (question boxes): inside the tank you should see and |
| `systems/the_four_horsemen.gd` | K2. "Recurring bosses across the whole game, who take turns leading the |
| `systems/the_room.gd` | AH1. The room you remember the Cloud from. |
| `systems/thermal_print.gd` | A rect that re-prints whatever is drawn under it on paper (item 5, Greg |
| `systems/threat_compass.gd` | Where the next blow is coming from. Every enemy winding up a strike reports |
| `systems/torture_load_in.gd` | Greg, 25 September: "when you are loading into the game make it you're |
| `systems/transition_kit.gd` | A full-screen wipe drawn by `transition_kit.gdshader`. `cover()` runs the |
| `systems/undying_flame.gd` | A8.1 / A8.2. The spirit, burning on the body, and the frame coming apart |
| `systems/vat_body_preview.gd` | A body witness for the intake form.  It is deliberately constructed from |
| `systems/vat_float.gd` | Slow, bounded buoyancy for a BaselineHuman suspended in a growth vat. |
| `systems/vat_horror.gd` | Greg, 28 September (question boxes): the vat opening doesn't hit hard |
| `systems/vat_intake.gd` | The intake form, filled in about you while you float in it. |
| `systems/vat_rebirth.gd` | Death is rebirth in a vat (Greg, 24 September 2026, DESIGN.md). |
| `systems/vat_smash.gd` | Smashing the other tanks on the Growing Floor (Greg, 24 September: "make |
| `systems/vats_overlay.gd` | What aimed X-ray shows on the glass: every part of one body that can be |
| `systems/vats_targeting.gd` | Aimed X-ray: slowed time, one body, its parts as targets. |
| `systems/vehicle_driver.gd` | The player's hands on an arcade chassis (`arcade_vehicle.gd`) outside the |
| `systems/vehicle_interior.gd` | M2. Inside the car. |
| `systems/vitality_signal.gd` | I4. How badly the interface is doing, derived entirely from how badly the |
| `systems/voice_input.gd` | AI NPC Communication & Relationship System, section 2's input pipeline: |
| `systems/wall_poster.gd` | A piece of Greg's art in the world (ArtGallery). A poster hangs on a wall |
| `systems/warning_card.gd` | The card that comes up before anything else. Greg asked for the Postal 2 |
| `systems/weapon_body.gd` | O6/O7. Everything you can swing is the same object with a different mass. |
| `systems/weapon_skins.gd` | Skins for what you hold and wear (Greg, 24 September: "a csgo case type |
| `systems/wire_browser.gd` | Every physical subject receives a distinct online body without becoming a |
| `systems/wire_net.gd` | The surviving internet, as a simulation rather than a screen. |
| `systems/wire_radio.gd` | A tunable radio, and a second transmission channel for the world. |
| `systems/wire_site_catalog.gd` | Authored places on the Wire. These are content descriptors, not UI panels: |
| `systems/witness_ledger.gd` | Who saw it, whether they lived to say so, and what the world ended up |
| `systems/wof_lockup.gd` | The store lockup: the seal, the name, and sigils woven through the letters. |
| `systems/wof_mark.gd` | The Wizards Only Fools seal. |
| `systems/world_break.gd` | One way into everything breakable (Greg, 24 September: destruction physics |
| `systems/world_clock.gd` | W1.1. The hour. |
| `systems/world_damage.gd` | AB2.1/AB2.2/AB2.3. `DESIGN/DESTRUCTION.md` scopes destruction down from |
| `systems/world_debris.gd` | AB1.3/AB1.4. Physical debris as an identified, capped, persistent object — |
| `systems/world_history.gd` | AG5.11. Several worlds, not one. `SAVE_PATH` above is the save this file has |
| `systems/world_index.gd` | L2.1. Something on this page is worth putting on the wall. |
| `systems/world_look.gd` | One look system for every scene. Each scene previously built its own |
| `systems/world_weather.gd` | W1.2. Contamination has weather — it moves, it settles, it gets worse. |
| `systems/world_xray.gd` | B3.3/B3.4. The X-ray stops being a page in the index and becomes something |
| `systems/wound_catalog.gd` | Authored legacy/story wounds. Combat wounds already arrive as dictionaries |
| `systems/wound_marks.gd` | Greg: *"i want you to begin working on the body and skin models taking wound |
| `systems/xray_cursor.gd` | The cursor is a tool, and one of its buttons sees through people. |
| `systems/xray_scan_overlay.gd` | The X-ray's pre-fight read of one body (lab-48). Greg: *"X-ray is how you |
| `systems/xray_specimen.gd` | The loading screen's body, in actual 3D. |
