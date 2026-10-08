# Bugs: v0.1 route stability pass

Greg, 6 Oct: the build is "very very bugged out". This is the list from the
stability lanes (bughunt-79-a/b/c). One line per bug: **where**, what,
severity (blocker / major / minor), status. Fix blockers before majors, the
root cause and not the symptom. Next lane: read this first, fix what is still
open, then play the route again for new ones.

How it was found (bughunt-79-a, 2026-10-06): headless route suites with their
own APPDATA (first_thirty_route, facility_one_map_walk, first_run_walk,
intake_pad_walk, route_endings, demo_route, plus the v01_/examiner/arcade/
Lower Works/menu/pad/death suites), and windowed captures opened as PNGs:
menu_capture, new menu_chooser_capture, intake_pad_capture,
hands_on_breakout_capture, examiner_exit_capture, facility_one_map_capture
(staff door to surface gate, 13 shots), rebirth_capture, v01_ending_capture,
interstitial_capture.

No blocker was found: every route suite reaches the surface and the ending,
and START -> chooser -> vat now has its own test. Also green and looked at: arcade_execution_test, execution_beat_test (+capture), hunt_execution_test, aim_down_sights_test (+capture), black_mirror_lens_test, vat_rebirth_test, rebirth_every_killer_test, opening_death_test, death_save_screen_test, service_arcade_route_test, lower_works_route_test, lower_works_gantry_test, examiner_fight_test, examiner_feed_test, v01_guard_duel_test, v01_creature_duel_test, vat_pad_chain_test, pad_bridge_test, hunt_pad_layout_test, menu_transition_test, menu_silence_test.

bughunt-79-b (2026-10-06) re-ran the six route suites plus v01_ending, service_arcade_route, lower_works_route, examiner_fight, examiner_keycard, opening_death, death_save_screen, vat_rebirth, rebirth_every_killer, menu_input_chooser and menu_transition (all green; the only ERROR lines are quit-time leak reports), and opened hands_on_breakout_capture, intake_pad_capture, examiner_exit_capture, facility_one_map_capture (vat to daylight, 13 shots) and rebirth_capture.

bughunt-79-c (2026-10-06, after the v0.1 sound pass merged) re-ran the six route suites plus the gate (baseline_human, body_cut, opening_handoff), all green, then menu_*, support_mail, facility_guard_post, support_unit, service_arcade_route, vat_rebirth, audio, chunk, impact_feel; opened menu_capture (settings before/after), hands_on_breakout_capture, rebirth_capture (before/after) and facility_one_map_capture (13 shots, vat to daylight; fps_min 3 on the first frame, average 205).

## Fixed

- **Arcade -> both lifts -> surface gate**: the fight teacher's "RED GLINT // STEP OUT OR DODGE" (and any pickup or door line) was written into the vat subtitle and never cleared, so it rode the transit lift, the Lower Works and the heat elevator up to the surface gate. Major. FIXED bughunt-79-a: once on your feet a line clears 6 s after it last changed (`vat_chamber._expire_subtitle`, `route_subtitle_expiry_test`).
- **Ending card**: "PRESS TO RETURN TO THE TITLE" had no button in it. Major. FIXED bughunt-79-a: names CROSS or ENTER from InputProfile (`v01_ending_test` checks it).
- **Main menu, START input chooser**: see-through default panel over the menu column, controls hint ran off the plate, d-pad down from BACK walked onto the menu behind it, Circle / Escape did nothing. Major (every run starts here; every suite skipped it). FIXED bughunt-79-a: opaque copper plate, wrapped hint, focus kept inside, Circle closes (`menu_input_chooser_test`, START -> KEYBOARD -> arrives in the vat).
- **Examiner office / any fight that bleeds after a scene reload (death -> vat rebirth)**: `blood_pool.keep` cast a freed node out of its static cache: 1952 "Trying to cast a freed object" SCRIPT ERRORs in one examiner fight, 2909 in examiner_keycard_test (which then timed out). Major (error spam every frame of a fight). FIXED bughunt-79-a.
- **Vat glass / doctor's route**: `glass_tank` kept freed shards in a static typed list: 96 "assign previously freed" SCRIPT ERRORs in doctor_route_test. Minor. FIXED bughunt-79-a.
- **Every scene travel (loading plate)**: `anatomy_film.gdshader` passed the TEXTURE builtin into a function; the shader compiler ERRORed on each plate. Minor. FIXED bughunt-79-a (blur reads a `film` uniform; soft phase seen rendered).
- **Main menu settings**: GORE and CENSOR rows were the only left-aligned rows. Minor. FIXED bughunt-79-a (seen in menu_capture).
- **Tests reporting false pad failures**: souls_pad_test failed 7 ("R1/R2/L2 do nothing") because four tests still selected the old "sword" slot (now "cleaver") and waited on physics frames for triggers SoulsPad polls in `_process`; examiner_keycard_test failed on seeds that fight bare-handed (needs ~29 blows since Job 6). Not game bugs. FIXED bughunt-79-a in the tests; menu_capture hung on a removed Support row, now skips it.
- **Vat, GET REVENGE card**: the "E USE / OPEN / TEAR" hint box sat on the card's letters (standing up offers it the same frame the card plays), and the tank beat "TANK 0C-7 // CYCLE ABORTED // VOIDING" was repainted into the aisle subtitle under the card. Minor. FIXED bughunt-79-b: KeyHints waits out any playing MissionCard; `_update_beats` only runs submerged/voiding (`hint_waits_for_card_test`; hands_on_breakout_capture bo_5 before/after looked at).
- **Every mission card (GET REVENGE first)**: the 79-b fix hid the key hint for the whole card, so on standing up there was no E USE / LMB STRIKE prompt for the first seconds of control. Minor. FIXED fix-86: while a card plays the hint sits under the card's title (`MissionCard.title_rect`), then returns to its own spot; a card with no room under its title (BRAIN HACKED SOUL OVERTAKEN at 720p) still holds it. The hint's hold counts from when it first shows (`hint_waits_for_card_test`; seen in hands_on_breakout_capture `bo_6_revenge_hint.png`).
- **Intake (Neural Intake panel)**: race "FILED AS" label and note ran past the paper's right edge and onto the description line; body "FILED" note cut off; transcript cut at "EXAMINER TERMINAL CO"; subhead touching the tab row. Minor. FIXED bughunt-79-b: FILED text right-aligned and fitted, transcript wraps, subhead raised (intake_pad_capture race/body before/after; eight intake_* suites green).
- **Service Arcade (and every hall title)**: the billboard hall title rode up into the subtitle line as you walked under it ("SERVICE ARCADE" over the fight teacher's line, 03a). Minor. FIXED bughunt-79-b: room titles hidden inside 8 m, fading in to 11 m; still read from the entry (facility_one_map_capture 03a/05b looked at).
- **Service Arcade, Hollis warning shot**: his spoken line was a few pixels tall at firing distance. Minor. FIXED bughunt-79-b: fixed screen-size speech label (rebirth_warning_shot before/after: "Next one's in you." legible).
- **Mechanics lab, PRODSTAFF "the shock staggers the dummy"**: not a game bug. The light thrust staggers the dummy 1.2 m back (by design), leaving it past the charged thrust's 3.5 m reach, so the shock hit the floor. FIXED bughunt-79-b in the test (re-face before R2); v01_weapons_test 0 failures.
- **Examiner office door sign "doubled/ghosted"**: not a bug. examiner_exit_capture shoots during the departure, when the player is still in the tank and `tank_view` wobbles the screen through the fluid; one Label3D exists. Closed bughunt-79-b.
- **Vat aisle, "floating red disc" (facility_one_map_capture 01)**: live smash debris (flesh drops and glass shards) still flying in the first frames after the breakout; it moves between runs. Not a bug. Closed bughunt-79-b.

- **Exit-time "Lambda capture at index 0 was freed" (12 per baseline_human_test, any fight that ends in a free or reload)**: `GoreChunks.play_impact`'s delayed-layer lambda captured the struck body, which is often freed inside the few-ms delay. Minor. FIXED bughunt-79-c: captures the instance id (baseline_human_test now 0 lambda errors).
- **Main menu settings, Support / report-a-bug row**: dead since merge dcec1583. FIXED bughunt-79-c: one call in `_ready`; the address line stays in a real font (CellOutzType has no "@" and no wrapping, it read "WIZARDSONLYFOOLZTHEGAME GMAIL.COM" and the failure line ran past the panel). menu_capture now opens settings through `_open_settings()` (it had photographed the undressed panel). menu_01/02 looked at.
- **Service Arcade after rebirth, guard's spoken line**: depth-tested Label3D, so the growing tank cut "You again. They grew you back." off at "They grew you ba". Major (his line is the beat). FIXED bughunt-79-c: `no_depth_test` on his and the Support Unit's speech (rebirth_old_body before/after).
- **impact_feel_test "a sever rings longer"**: failed on the base commit under load; awaited ~50 ms headless frames measured the shot's 54 ms ring as ~0.15 s. Not a game bug. FIXED bughunt-79-c in the test (fixed 60 Hz steps).

- **Lower Works and both lift shafts near-black (map-84)**: the zone surface sets (DiamondPlate, MetalPlates, CorrugatedSteel) loaded their Metalness maps at full metal; with no sky or reflection probe underground, metal has no diffuse, so every lamp landed on black. Major. FIXED map-84: `FacilityZoneIdentity.METAL_SHARE` 0.3, plus six high-bay floods under the trusses and a flood over the heat elevator mouth. The vessels, crane, sentinel and floor read from the transit lift (facility_one_map_capture 05/05b/05c, P:/GameDev/Temp/map-84/).
- **Service Arcade one long empty box (map-84)**: stall counters, partitions, awnings and work lamps in front of the shutters, a cashier booth on the east wall and two waist-high barriers mid-hall; guards walk round them (`ARCADE_COVER`), and pistol guard 49 stands behind the barrier at (30.6, -43.4) instead of being a speck at the far end. Two wide floods under the last frames wash the far half up to the transit lift. Major. FIXED map-84 (02b/03/03a/03b).
- **Transit lift and heat elevator rides (map-84)**: the readout moved off the lintel (it rode into the HUD objective box) onto a small dark panel with a lit rim on the door jamb at eye height; the big curved readouts over the side slots are gone; the shaft strip is a short tube in a housing and the shaft wall takes light. Major. FIXED map-84 (04/07).
- **Surface gate a flat white square (map-84)**: open gate leaves, a lit yard, wall stubs and fence posts against a far daylight backdrop. Major. FIXED map-84 (08).
- **Staff-door start shot (map-84)**: the "floating red slabs" were opening debris mid-flight in the capture's first frames, not in play; the capture now waits 3 s. The Growing Floor checker tile has wall concrete multiplied over it as grime: still a checker, less clean. Minor. FIXED map-84 (01); whether the lab floor should stay a checker at all is an art call.

## Open

- **Rebirth, old body in the arcade**: glowing orange ghost body with red discs and a ring (REMASTER_LOG job7 "Still weak"; rebirth_old_body.png). Major (looks broken). PARTIAL fix-85: removed the floating "YOUR OLD BODY" billboard; the nearby `[E] TAKE YOUR GEAR BACK...` prompt remains. OPEN: the ghost-body look still needs a real corpse/bloodstain read and Greg's art direction.
- **Vat, cord beat**: the subtitle "The cord is still down your throat." (sentence case) and the thought "IT'S DOWN MY THROAT. PULL." show at once, two lines saying the same thing (bo_1_cord.png). Minor. OPEN: Greg's opening text; a question, not a lane fix.
- **Examiner fight, bare-handed**: with no axe and no restraint he takes ~29 blows (260 health, 9 per fist) for a ~1 min fight. Minor (balance). PARTIAL fix-102: fists 9 -> 15 behind the DAMAGE dial; Greg to confirm.
- **The Hunt, aiming down the sights**: sights are centred, the grip hands drop 0.035 m below them at full aim, and HRT/EEG/CAM fade to 25% so the top-right rig does not crowd the sight picture. Minor (after the route). FIXED fix-97/fix-100.
- **Exit-time noise**: the 12 lambda errors are fixed (above). Left: route runs end with RID/ObjectDB leak lines (11868 ObjectDB in demo_route), one Jolt "maximum number of jobs" warning seen by 79-b. Quit-time only. Minor. OPEN.
- **Legacy doctor chase**: doctor_chase_route_test failed 8 ("his door comes down (80 blows)" onward) at the base commit too: it drove the pre-hands-on breakout instead of the examiner's dropped-keycard path. Minor (stale test, not the route). FIXED fix-83: the suite now takes the dropped keycard and opens the staff door through the real interaction path, leaves the detailed card assertions to examiner_keycard_test, and retains the current Support Unit -> empty vehicle bay -> surface chase handoffs.
- **First-person sleeves "purple checker" (REMASTER_LOG imp-64 Still weak)**: it is the jester leather pattern on `held_gear` sleeves, not a missing texture. Art call, not a lane fix. OPEN (look).

- **Service Arcade, guard's "SEEN 100%" awareness tag**: BlockTracker's tag sits over his speech line at the old-body spot (rebirth_old_body). Minor. FIXED fix-94: awareness box stays, tag text yields for the guard's spoken line and returns when it ends (`P:/GameDev/Temp/rebirth_old_body.png`).
- **Main menu settings**: the support address line sits ~12 px left of the plate's row inset. Minor. FIXED fix-82: the real-font address now uses the compact plate's 14 px row inset (`P:/GameDev/Temp/menu_01_settings_support.png`).

## Not verified by bughunt-79-a

- A real controller in hand: pad paths were driven by synthetic events only.
- Frame rate on Greg's RTX 2060 SUPER: the windowed map capture's first frame was 3 fps (shader warm-up), the rest 98-361 fps on this machine.
- Audio.
- bughunt-79-b: still no real pad, GPU or audio check. The examiner door sign was not seen on foot (no capture stands there after the breakout).
- bughunt-79-c: no real pad, GPU or audio check either; the menu Support press was only seen in test mode (no mail client opened on purpose).
