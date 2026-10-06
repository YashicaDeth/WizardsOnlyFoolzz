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
- **Intake (Neural Intake panel)**: race "FILED AS" label and note ran past the paper's right edge and onto the description line; body "FILED" note cut off; transcript cut at "EXAMINER TERMINAL CO"; subhead touching the tab row. Minor. FIXED bughunt-79-b: FILED text right-aligned and fitted, transcript wraps, subhead raised (intake_pad_capture race/body before/after; eight intake_* suites green).
- **Service Arcade (and every hall title)**: the billboard hall title rode up into the subtitle line as you walked under it ("SERVICE ARCADE" over the fight teacher's line, 03a). Minor. FIXED bughunt-79-b: room titles hidden inside 8 m, fading in to 11 m; still read from the entry (facility_one_map_capture 03a/05b looked at).
- **Service Arcade, Hollis warning shot**: his spoken line was a few pixels tall at firing distance. Minor. FIXED bughunt-79-b: fixed screen-size speech label (rebirth_warning_shot before/after: "Next one's in you." legible).
- **Mechanics lab, PRODSTAFF "the shock staggers the dummy"**: not a game bug. The light thrust staggers the dummy 1.2 m back (by design), leaving it past the charged thrust's 3.5 m reach, so the shock hit the floor. FIXED bughunt-79-b in the test (re-face before R2); v01_weapons_test 0 failures.
- **Examiner office door sign "doubled/ghosted"**: not a bug. examiner_exit_capture shoots during the departure, when the player is still in the tank and `tank_view` wobbles the screen through the fluid; one Label3D exists. Closed bughunt-79-b.
- **Vat aisle, "floating red disc" (facility_one_map_capture 01)**: live smash debris (flesh drops and glass shards) still flying in the first frames after the breakout; it moves between runs. Not a bug. Closed bughunt-79-b.

## Open

- **Transit lift and heat elevator rides**: the floor readout is a big curved "DOWN 0C SERVICE ARCADE" / "UP 0D LOWER WORKS" floating in the black, the lintel "DOWN" overlaps the HUD objective box, the shaft strip is one flat green bar (REMASTER_LOG job5 "Still weak"; facility_one_map_capture 04, 07). Major (looks broken). OPEN, owned by the pending `remaster-job5-p2` job (lift readout and HUD overlap); not duplicated here.
- **Rebirth, old body in the arcade**: glowing orange ghost body with red discs and a ring, plus a floating "YOUR OLD BODY" label like debug text (REMASTER_LOG job7 "Still weak"; rebirth_old_body.png). Major (looks broken). OPEN: needs a real corpse/bloodstain read; Greg's art direction.
- **Vat, cord beat**: the subtitle "The cord is still down your throat." (sentence case) and the thought "IT'S DOWN MY THROAT. PULL." show at once, two lines saying the same thing (bo_1_cord.png). Minor. OPEN: Greg's opening text; a question, not a lane fix.
- **Examiner fight, bare-handed**: with no axe and no restraint he takes ~29 blows (260 health, 9 per fist) for a ~1 min fight. Minor (balance). OPEN: Greg's dial (Job 6).
- **Main menu settings**: the Support / report-a-bug row Greg asked for (Y2, "email me in settings") has been dead code since the 16 Sep merge dcec1583 dropped its `_build_support_row()` call; the "settings > support" note it pointed at is gone too. Minor. OPEN: one call in `_ready` if the row is still wanted after the menu redesign.
- **The Hunt, aiming down the sights**: sights are now centred, but in first person the low-poly hands and knuckle spheres fill the lower third of the frame while aimed (aim_down_sights_capture stage2 / third_person_aimed). Minor (after the route). OPEN.
- **Exit-time noise**: baseline_human_test prints 12 "Lambda capture at index 0 was freed" at quit, and route runs end with RID/ObjectDB leak lines; one Jolt "job system exceeded the maximum number of jobs" warning in a route run. bughunt-79-b: the lambdas are not BaselineHuman's 90 s gore-expiry timers (binding those left the count at 12). Source still unknown; needs a `--verbose` run or a lambda-by-lambda bisect in GoreChunks/BaselineHuman. Minor.
- **Legacy doctor chase**: doctor_chase_route_test failed 8 ("his door comes down (80 blows)" onward) at the base commit too: it drove the pre-hands-on breakout instead of the examiner's dropped-keycard path. Minor (stale test, not the route). FIXED fix-83: the suite now takes the dropped keycard and opens the staff door through the real interaction path, leaves the detailed card assertions to examiner_keycard_test, and retains the current Support Unit -> empty vehicle bay -> surface chase handoffs.
- **First-person sleeves "purple checker" (REMASTER_LOG imp-64 Still weak)**: it is the jester leather pattern on `held_gear` sleeves, not a missing texture. Art call, not a lane fix. OPEN (look).

## Not verified by bughunt-79-a

- A real controller in hand: pad paths were driven by synthetic events only.
- Frame rate on Greg's RTX 2060 SUPER: the windowed map capture's first frame was 3 fps (shader warm-up), the rest 98-361 fps on this machine.
- Audio.
- bughunt-79-b: still no real pad, GPU or audio check. The examiner door sign was not seen on foot (no capture stands there after the breakout).
