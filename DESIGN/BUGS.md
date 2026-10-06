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
and START -> chooser -> vat now has its own test.

## Fixed

- **Arcade -> both lifts -> surface gate**: the fight teacher's "RED GLINT // STEP OUT OR DODGE" (and any pickup or door line) was written into the vat subtitle and never cleared, so it rode the transit lift, the Lower Works and the heat elevator up to the surface gate. Major. FIXED bughunt-79-a: once on your feet a line clears 6 s after it last changed (`vat_chamber._expire_subtitle`, `route_subtitle_expiry_test`).
- **Ending card**: "PRESS TO RETURN TO THE TITLE" had no button in it. Major. FIXED bughunt-79-a: names CROSS or ENTER from InputProfile (`v01_ending_test` checks it).
- **Main menu, START input chooser**: see-through default panel over the menu column, controls hint ran off the plate, d-pad down from BACK walked onto the menu behind it, Circle / Escape did nothing. Major (every run starts here; every suite skipped it). FIXED bughunt-79-a: opaque copper plate, wrapped hint, focus kept inside, Circle closes (`menu_input_chooser_test`, START -> KEYBOARD -> arrives in the vat).
- **Examiner office / any fight that bleeds after a scene reload (death -> vat rebirth)**: `blood_pool.keep` cast a freed node out of its static cache: 1952 "Trying to cast a freed object" SCRIPT ERRORs in one examiner fight, 2909 in examiner_keycard_test (which then timed out). Major (error spam every frame of a fight). FIXED bughunt-79-a.
- **Vat glass / doctor's route**: `glass_tank` kept freed shards in a static typed list: 96 "assign previously freed" SCRIPT ERRORs in doctor_route_test. Minor. FIXED bughunt-79-a.
- **Every scene travel (loading plate)**: `anatomy_film.gdshader` passed the TEXTURE builtin into a function; the shader compiler ERRORed on each plate. Minor. FIXED bughunt-79-a (blur reads a `film` uniform; soft phase seen rendered).
- **Main menu settings**: GORE and CENSOR rows were the only left-aligned rows. Minor. FIXED bughunt-79-a (seen in menu_capture).
- **Tests reporting false pad failures**: souls_pad_test failed 7 ("R1/R2/L2 do nothing") because four tests still selected the old "sword" slot (now "cleaver") and waited on physics frames for triggers SoulsPad polls in `_process`; examiner_keycard_test failed on seeds that fight bare-handed (needs ~29 blows since Job 6). Not game bugs. FIXED bughunt-79-a in the tests; menu_capture hung on a removed Support row, now skips it.

## Open

- **Transit lift and heat elevator rides**: the floor readout is a big curved "DOWN 0C SERVICE ARCADE" / "UP 0D LOWER WORKS" floating in the black, the lintel "DOWN" overlaps the HUD objective box, the shaft strip is one flat green bar (REMASTER_LOG job5 "Still weak"; facility_one_map_capture 04, 07). Major (looks broken). OPEN: needs the readout as a flat panel on the car wall, below the HUD's objective band.
- **Service Arcade**: the "SERVICE ARCADE" sign label sits on top of the subtitle line (03a). Minor. OPEN: lower the sign or the subtitle band.
- **Rebirth, old body in the arcade**: glowing orange ghost body with red discs and a ring, plus a floating "YOUR OLD BODY" label like debug text (REMASTER_LOG job7 "Still weak"; rebirth_old_body.png). Major (looks broken). OPEN: needs a real corpse/bloodstain read; Greg's art direction.
- **Service Arcade, Hollis warning shot**: his spoken line is a Label3D too small to read at play distance (rebirth_warning_shot.png). Minor. OPEN.
- **Vat, cord beat**: the subtitle "The cord is still down your throat." (sentence case) and the thought "IT'S DOWN MY THROAT. PULL." show at once, two lines saying the same thing (bo_1_cord.png). Minor. OPEN: Greg's opening text; a question, not a lane fix.
- **Vat, GET REVENGE card**: "HE WENT THROUGH THAT DOOR." and the "E USE / OPEN / TEAR" prompt sit on top of the GET REVENGE title (bo_5_get_revenge.png). Minor. OPEN: hold the prompt until the card clears.
- **Intake (Neural Intake panel)**: the tab rows overlap the "CELLOUTZ GROWING FLOOR // DESCENT INTAKE" subhead; RACE descriptions and the BODY "FILED UNSPECIFIED / GROWN" note run past the right edge; the left "NEURALACE ENGAGED // EXAMINER TERMINAL CO" line is cut off (intake_pad_*.png). Minor. OPEN.
- **Examiner office door**: the "EXAMINATION 0C // OBSERVATION" sign renders doubled/ghosted (examiner_exit_*.png). Minor. OPEN.
- **Examiner fight, bare-handed**: with no axe and no restraint he takes ~29 blows (260 health, 9 per fist) for a ~1 min fight. Minor (balance). OPEN: Greg's dial (Job 6).
- **Main menu settings**: the Support / report-a-bug row Greg asked for (Y2, "email me in settings") has been dead code since the 16 Sep merge dcec1583 dropped its `_build_support_row()` call; the "settings > support" note it pointed at is gone too. Minor. OPEN: one call in `_ready` if the row is still wanted after the menu redesign.
- **Mechanics lab, PRODSTAFF**: v01_weapons_test "and the shock staggers the dummy" fails: the charged shock lands (packet has shock) but no shock stagger is reported. Minor (lab, not route). OPEN.
- **Exit-time noise**: baseline_human_test prints 12 "Lambda capture at index 0 was freed" at quit; one Jolt "job system exceeded the maximum number of jobs" warning in a route run. Minor. OPEN.

## Not verified by bughunt-79-a

- A real controller in hand: pad paths were driven by synthetic events only.
- Frame rate on Greg's RTX 2060 SUPER: the windowed map capture's first frame was 3 fps (shader warm-up), the rest 98-361 fps on this machine.
- Audio.
