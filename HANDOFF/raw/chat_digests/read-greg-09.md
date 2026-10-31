# Greg chunk 09 notes

## 1. REQUIREMENTS

### Playable route and opening

- **2026-09-20** — Work toward the detailed first 30 minutes, broadly in story order: “trying to do this in canonical order as much as is viable”. Character creation precedes personality work: “character customisation, then the personality then the ect ect”.
- **2026-09-20** — The consolidated demo must retain the route work, not become only an opening mock-up: “then all the different routes and remade character custopmisation”. This chunk does not specify the tunnel/exits individually.
- **2026-09-20** — Front-door order: “Demo larger in the font at the start and then Full Game Underneath is locked, And then Psychofrenia Sandbox”. He also said “and not the starting splash screen”.
- **2026-09-20** — Demo entry is the vat: “it just starts with red bloody vat water” while the player looks into a 3D laboratory.
- **2026-09-20** — The opening has “only the 1 doctor / handler whos name is unkown”, at a laboratory computer whose code/text monitor is visible through the vat.
- **2026-09-20** — The intake uses “your model on the right of the screen” and exposes “customisation ooptions size sliders ect race sex name ect ect alll listed characteristic”. The current body supplies the base, with a new face.
- **2026-09-20** — After intake, the doctor walks through a closing door, the view returns to first person, and “then you break out of the glass visivly”.
- **2026-09-20** — The player vat and surrounding tanks need current game bodies: “the vats still dont haver the current overwoirld player models in it”. Subjects can be mutilated, intact/alive, cradled or fetal.
- **2026-09-20** — The examiner stands left of the workstation rather than blocking it: “more to the left of the lab and not directly infront of it”. His clothing needs “a goverment style esoteric sigil outfit”.

### Body, anatomy, weapons and combat

- **2026-09-21** — X-ray, body inspection, Index and sandbox must share canonical anatomy: “all the- all the organs in the x-ray in the body should be like the real models.”
- **2026-09-21** — Anatomy should change visibly with play: “We should update it live-logs in the game”.
- **2026-09-21** — Replace the failing character mesh with “simplified low poly topology” suitable for stable cutting and destruction.
- **2026-09-21** — Organs may be technically simple but must be anatomically faithful: “organ systems that are really simple, um, but like really o-accurate to a human anatomy”.
- **2026-09-21** — Damage must support “teardown style destruction gore, and gore physics”, clean severing, bullet-by-bullet wounds and destructible body layers.
- **2026-09-21** — Death and pain need physical reactions: “accurate, like pain and ragdoll system, like maybe example like Red Dead or something”. Bodies should not instantly face-plant.
- **2026-09-21** — The grounded system can be exaggerated: “it shoots out blood, like spurts out like an old Japanese game, or like in Postal 2”.
- **2026-09-21** — Hands and equipment must use the best shared models: “all the hand models, they aren't the like current good, better hand models”.
- **2026-09-21** — Weapon props require authored-looking geometry: “all the models for the weapons, need to actually have like proper modeling”. This includes the Ashline cleaver, guns and breach/grenade launcher.

### Phone, map, HUD and interaction

- **2026-09-21** — The device must read physically as “the phone in the hand thing”, not a detached G overlay.
- **2026-09-21** — Its map is a live satellite map: “G devices map is not the satellite map” was the failure report.
- **2026-09-21** — Map input must work through keyboard and pointer: “you can't even click around with tab, or G, or arrow keys, or your mouse”. It must not remain stuck on the underground facility.
- **2026-09-21** — F1 opens a styled control reference: “when you press F1, it has like a customized UI”. It must show “all the different controls” in a good readable font instead of cycling a messy bottom strip.
- **2026-09-21** — Sandbox combat text and green HUD text must use the same visual grammar as the rest of the game, not look like a separate debug overlay.

### Art, presentation and performance

- **2026-09-21** — Tables, weapons, drugs and hands need proper modelling rather than rough placeholders; “all the like drug... things... all the models look stupid”.
- **2026-09-21** — Bullets should not read as lasers: “the bullet like shoots like a laser” and “It's kind of dumb”.
- **2026-09-21** — Normal sandbox performance should remain smooth; the only reported hitch was “when I shoot it's just a slight bit laggy Not bad”.
- **2026-09-21** — This chunk adds no specific music, ambience or sound requirement.

## 2. DISLIKES / REJECTIONS

- **2026-09-19** — The live-management state felt unreliable: “stuff seems like kinda a mess”.
- **2026-09-19** — Rejected expensive five-minute AI supervision: “this is a huge waste of tokens”.
- **2026-09-19** — Rejected Orca as then configured: “used up all my usage and nothing has even been done”.
- **2026-09-20** — Rejected the project being fragmented across rogue tasks/copies: “consolidate demo fix the character creation all rouge tasks and agents”.
- **2026-09-20** — The current build failed as a playable whole: “the game does not work properly”.
- **2026-09-20** — Opening defects: “the vat at the startr still is not red”, the examiner blocked the workstation, and tank bodies were not current player models.
- **2026-09-21** — Menu polish was insufficient: “the UI on the uh menu needs work”.
- **2026-09-21** — A transient console window felt alarming: “Window system thirty-two CMD just opened for a second. Makes me think I have a virus”.
- **2026-09-21** — G/device UI was unusable: “the G menu not working at all” and the map was “completely broken”.
- **2026-09-21** — Rejected rough organ stand-ins: “Not really the real models”.
- **2026-09-21** — Rejected the debug-like control/HUD layout: “it looks cool. And doesn't just look really messy”.
- **2026-09-21** — Rejected the sandbox table: “I don't like the table model”.
- **2026-09-21** — Rejected weapon and substance props: “all the models look stupid and like... doesn't even like look good”.
- **2026-09-21** — Rejected the launcher’s appearance: “the model for like the grenade launcher is like also completely broken”.
- **2026-09-21** — Rejected the base body: “I'm also sick of this character model. It has like this broken, unworking topology.”
- **2026-09-21** — Wounds did not conform to the body: “not accurate to the topology in the game”.
- **2026-09-21** — Death response was weak: “they kinda just fall on the floor really quick” and “it's kinda underwhelming”.
- **2026-09-21** — Severing was visually poor: “you can blow like their arms off, but it's just super lame”.
- **2026-09-21** — Missing dynamics were unacceptable: “there's no ragdoll physics”.
- **2026-09-21** — Rejected endlessly recycling effects: “the uh particles kind of just constantly refresh”.

## 3. DECISIONS

- **2026-09-19** — Stop the active Orca workflow immediately: “can you just stop orca right now”.
- **2026-09-19** — Preferred replacement: one lead/integration agent plus up to three bounded PowerShell workers, separate worktrees, event-driven checks; Greg answered “can we do this”.
- **2026-09-19** — Merge useful project work into one authoritative build before account switching; usage pressure was explicit: “i am draining my mums usage on this acocunt”.
- **2026-09-20** — Parallel agents are acceptable when bounded: “just open 1 more claude agent” and have the agents continue the 30-minute gameplay.
- **2026-09-20** — The 30-minute gameplay document/ledger is the sequencing authority: “theres a 30 minutes of first gameplay doc we are following this”.
- **2026-09-20** — Opening composition decided: one anonymous doctor/handler, a current-body-derived customizable player in the vat, bloody fluid, visible mouth tube, lab view and post-intake breakout.
- **2026-09-20** — Menu hierarchy decided: DEMO first/largest, FULL GAME locked beneath it, PSYCHOFRENIA SANDBOX after it.
- **2026-09-21** — Manual playtest verdict: sandbox generally ran smoothly; gunfire caused only a small hitch.
- **2026-09-21** — Screenshots and narrated play are the preferred review method for visual failures.
- **2026-09-21** — The launcher’s behavior worked despite its visual defect: “The grenade launcher ac-actually works in like just blows the character's gore off.”
- **2026-09-21** — Body-system direction decided: one shared low-poly anatomical rig, simple accurate organs, destruction/severing, physical ragdolls and an optional exaggerated Postal-like blood layer.

## 4. STILL OPEN?

- **2026-09-19 — PARTLY: simplify orchestration and consolidate.** Request: “stick to the usual 1 build copy for faster rapid devolopment”. Evidence: `launch-latest` is an integrated playable branch/worktree and commit `0a4189de` established Play-Latest-from-source, but `git worktree list` currently reports **78** worktrees. The “one copy” cleanup was not completed.
- **2026-09-20 — PARTLY: exact front-door flow.** Request: “and not the starting splash screen”. Built: `game/country_town_menu.gd:262`, `:270`, `:282` has DEMO / locked FULL GAME / PSYCHOFRENIA SANDBOX in the requested order, and `:340-344` sends DEMO into the vat route. Not exact: `country_town_menu.gd:7`, `:135-218` still builds and plays a splash/logo backdrop. Later sessions changed the desired title/load-in framing, so the no-splash wording is not cleanly final.
- **2026-09-20 — PARTLY: vat/intake scene and real tank bodies.** Request: “red bloody vat water” plus “a tube in your mout thats visible”. Built: `vat_chamber.gd:575-663` has bloody growth fluid/red vat light; `vat_body_preview.gd:134-150` has the visible mouth tube; intake, current player preview and examiner station are wired. `model_skin.gd:27,98-113` puts the generated examiner skin on BaselineHuman. Remaining mismatch: `systems/lab_vat.gd:84-99` still makes other tank subjects from spheres/capsules, not current player rigs.
- **2026-09-21 — BUILT: held Black Mirror and satellite page.** Request: “still not like the phone in the hand thing”. Evidence: `systems/handheld_device.gd` owns the raised device/hand, MAP mode and live `LivingMap`; `bone_yard_hunt.gd:980-1018` wires the handheld and map into the Hunt. `handheld_device.gd:394-400` explicitly fixes the missing satellite source; map keys are forwarded at `bone_yard_hunt.gd:1620-1625`. Later captures/tests include `handheld_map.png`, `handheld_satellite_test.gd` and `map_surface_satellite_layer.png`.
- **2026-09-21 — PARTLY: one real anatomy presentation everywhere.** Request: “all the organs in the x-ray in the body should be like the real models”. Built seam: `baseline_human.gd:481-493` creates the shared organs; `gore_demo.gd:535-580` and `bone_yard_hunt.gd:1297-1324` both use BaselineHuman; `brain_index_hub.gd:91-96` uses the live BaselineHuman preview. Remaining: the organs are still authored procedural geometry rather than final high-fidelity anatomical models; later Greg sessions continued asking for Sniper-Elite-level anatomy.
- **2026-09-21 — BUILT: readable controls UI and removal of permanent strip.** Request: “when you press F1, it has like a customized UI”. Evidence: commit `ace67a92` added a single KEYS page; `79e681fa` fixed the F1 card and overflow; `6a144214` removed the facility’s standing controls strip. Current route uses one-time key hints (`vat_chamber.gd:2706`, `service_arcade.gd:676`).
- **2026-09-21 — PARTLY: hands, table, substances and weapon models.** Request: weapons “need to actually have like proper modeling”. Evidence: `gore_demo.gd:496-501` puts shared production `HeldGear` models on the rack, while later commits placed generated models for the sidearm/BREACH NINE/shiv. However, `held_gear.gd:421-460` still constructs the launcher procedurally, and the substance station/table remain system-built placeholders. No later human search result clearly closes the table/launcher-model complaint.
- **2026-09-21 — PARTLY: body topology, gore, pain and ragdolls.** Request: “there's no ragdoll physics”. Built: BaselineHuman now owns shared zones, bones, organs, wounds and severing; `systems/ragdoll_body.gd` turns those exact zones into a corpse rig; `gore_demo.gd:543-580` enables it in the Psychofrenia sandbox. Commits `6e785fcd`, `06efe20e` and `d6832196` added weighted/world-space ragdolls. Remaining: repo grep finds `"ragdoll": true` only in `gore_demo.gd`; the Hunt creates BaselineHuman without enabling that option, so route-wide parity is not proven.
- **2026-09-21 — BUILT in code, not re-benchmarked here: shooting hitch.** Complaint: “when I shoot it's just a slight bit laggy”. Evidence: later commit `ed1c5be3` prebuilds shared gore materials at load rather than mid-fight; `da4dae27` corrected the sandbox FPS readout. Later Greg sessions target/observe ~160 fps, but this reader did not run the game or profile the current build.
- **2026-09-21 — NOT FOUND as a distinct feature: “live-logs” anatomy overlay.** Request: “We should update it live-logs in the game”. The saved anatomy updates live through BaselineHuman/WorldHistory, but no production class or later Greg session clearly identifies a player-facing feature named live logs. This may have meant live anatomy state rather than a literal log overlay.

## 5. WORLD / LORE / NAMES

- **2026-09-20** — **doctor / handler**, deliberately “unkown”; one person in the opening, not two figures.
- **2026-09-20** — **DEMO**, **Full Game**, **Psychofrenia Sandbox** are the requested front-door labels/order. Greg also pronounced/spelled the sandbox as “psychophrenia” in voice; the current UI spelling is **PSYCHOFRENIA**.
- **2026-09-20** — The examiner wears a **government-style esoteric sigil outfit**; no faction name or sigil name is supplied in this chunk.
- **2026-09-20** — The opening space is a bloody growth **vat** looking into a 3D **laboratory**; nearby vats hold damaged, living or fetal-position subjects.
- **2026-09-21** — **Body menu / Index** is the cited canonical source for real organ presentation.
- **2026-09-21** — **G device / phone in the hand** is the handheld interface with the satellite map; this chunk does not use the later canonical name Black Mirror.
- **2026-09-21** — **Ashline cleaver** is the one named weapon model in the playtest criticism.
- **2026-09-19 to 2026-09-21** — No new places, factions, tunnel names, exit names or character personal names were coined in this chunk.

## 6. STYLE OF WORKING

- **2026-09-19** — Minimize token burn and stop unattended frequent reasoning loops: “i think you and all the other agents are using all your tokens inneficetly”.
- **2026-09-19** — Prefer a lean lead plus bounded workers over heavy Orca orchestration; stop workers promptly when asked.
- **2026-09-19** — Keep one authoritative integration/build and merge verified worker commits into it before presenting the game.
- **2026-09-20** — Agents should clean up duplicate plans, lanes and instructions: “clean everything up thats making it like that”. Preserve the checklist, proposals and worldbuilding in a simpler structure.
- **2026-09-20** — Do not let completed systems remain isolated as whole alternate game copies: “finished chunks of ther game unrerasonably being split off into its own entire game version”.
- **2026-09-20** — Work from the first-30-minutes document/ledger, broadly canonically, while allowing independent work where viable.
- **2026-09-21** — Keep one playable copy for rapid iteration: “1 build copy for faster rapid devolopment”.
- **2026-09-21** — Codex and Claude may work concurrently, but should not become two divergent projects waiting indefinitely for a merge.
- **2026-09-21** — Launch the actual game and let Greg narrate the playtest: “we can hop on voice and try it when you open the game”.
- **2026-09-21** — Use screenshots as concrete visual evidence; Greg deliberately supplied many wound, UI, hand, weapon and ragdoll examples.
- **2026-09-21** — Quality bar: shared production models, no rough debug UI, coherent style, real interaction, stable topology, accurate anatomy and satisfying physical response—not merely functioning buttons.

## 7. CONTRADICTIONS INSIDE THIS CHUNK

- **2026-09-19 to 2026-09-21 — One build vs many agents.** Greg demanded “one singulat project” and fewer agents, but also asked Codex/Claude to open multiple PowerShell agents/accounts. Best reconciliation: parallel bounded workers are allowed; divergent playable copies and persistent orchestration are not.
- **2026-09-21 — Performance.** He first said “Game isn't lagging. Wow”, then noticed “when I shoot it's just a slight bit laggy”. The later, more specific observation wins: normal play was smooth, firing had a hitch.
- **2026-09-21 — Launcher.** He called its model “completely broken”, then said the launcher “ac-actually works”. This is visual failure versus functional success, not a mechanics reversal.
- **2026-09-21 — Anatomy detail.** He asked for “real models” for all organs, then requested organ systems be “really simple” and low-poly. Best reconciliation: one simple, stable, shared rig whose shapes/proportions are anatomically accurate; fidelity need not mean high polygon count.
- **2026-09-21 — Gore tone.** He wanted Red-Dead-like accurate pain/ragdolls and also exaggerated Postal/Japanese-game blood spurts. Best reconciliation: physically credible bodies and reactions with a deliberately heightened blood-effects layer.
- **2026-09-20 to 2026-09-21 — Front-door wording.** “not the starting splash screen” coexists with a requested start menu and later menu/settings playtesting. It rejects an extra pre-menu splash, not the title/front-door menu itself.
