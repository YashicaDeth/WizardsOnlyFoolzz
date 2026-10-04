# Build briefs: v0.1 "Escape"

The agent prompts for the eight jobs in `DESIGN/BUILD_PLAN.html`. One job, one
builder, one worktree. Each brief is complete: if you would have to guess a
design decision, it is listed under OPEN; stop and report instead of choosing.

## Read before any job

- `DESIGN/BUILD_PLAN.html` (scope of v0.1: what is in, what is switched off).
- `P:/GameDev/AgentHub/data/greg_direction_2026-10-04_controller_combat.md`
  and `P:/GameDev/AgentHub/data/greg_playtest_b_2026-10-04.md`: Greg's newest
  words. They win over every older document, including this one.
- Skills to load by name: `wof-lane-hygiene`, `wof-wire-before-polish`,
  `wof-verify-by-looking`, `running-headless-godot`, plus the ones named in
  your job.

## Rules for every job

1. **Wire before you build.** The repo has about 236 systems and many are
   finished but called by nothing. Before writing a new file, search for the
   one that already does it (`systems/`, scene scripts, `tests/`). Rebuilding
   an existing system is a failed job.
2. **Free parts from the internet first.** CC0 from Quaternius, Kenney, Poly
   Pizza, ambientCG, Poly Haven; free-for-games from Mixamo; CC-BY from
   Sketchfab or Freesound with credit. Every imported file is listed in
   `CREDITS.md` (source URL, author, licence). Never rip assets from
   commercial games. Generated art comes in only through
   `tools/import_generated_asset.py`.
3. **Pad first, keyboard equal.** Every action goes through real InputMap
   actions with joypad events (`systems/input_profile.gd`, Souls base layout:
   R1 light, R2 heavy, L1 block, L2 parry or aim, R2 fire with a gun). On-screen
   hints come from `systems/key_hints.gd` and follow the last device used.
4. **One game.** Work in your own worktree off `claude/launch-latest`; run
   `--headless --import` once before anything else. Merge happens through the
   hub gate. Commit small and often so a usage limit cannot lose work.
5. **Look at it.** A change that affects what the player sees is not done
   until you rendered it (capture harness under `game/tests/*_capture.tscn`, or
   one windowed run on the right monitor) and opened the PNG. Say which PNGs in
   the commit message.
6. **Performance.** 144 fps or better on Greg's RTX 2060 SUPER in every room
   you touch (`F10` counter or `game/tests/*perf*` / frame-budget tests).
7. **Report back** in three parts: what is done (with PNG paths and tests
   run), what you could not verify, and any pre-existing failures you met.

---

## Job 1: Mechanics lab

**GOAL.** Greg: *"a demo dev test area you can just walk around… here's how the
liquid physics, here's how the weather works, how the weather interacts with
the area, the rain, the storms, acid rain, how the destruction physics works
with weapons… then we apply that to the actual full game."* One small walkable
map inside the game where every world mechanic is shown working, using the
same code the real map uses.

**EXISTS** (use, do not rebuild): `systems/world_weather.gd`,
`systems/storm_weather.gd`, `systems/blood_pool.gd`, `systems/blood_flow.gd`,
`systems/ground_hole.gd`, `systems/breakable_prop.gd`, `systems/world_break.gd`,
`systems/breakable_door.gd`, `systems/vat_smash.gd`, `systems/ragdoll_body.gd`,
`systems/baseline_human.gd`, `systems/penetration.gd`, `systems/world_xray.gd`.
The combat sandbox `psy_lab.tscn` / `gore_demo.tscn` already has a weapon rack
and dummies; reuse its pieces rather than copying them.

**OWNS.** New: `game/lab/mechanics_lab.tscn`, `game/lab/mechanics_lab.gd`,
`game/lab/stations/*`, `P:/GameDev/Start-MechanicsLab.cmd`. Shared systems:
fix bugs you find, but do not change their public behaviour.

**BUILD.** A 40 x 40 m greybox yard with a covered half and an open half (so
weather can be compared under cover and in the open), lit so all five stations
read at once. A station is a plinth with a short label and one pad button:
1. *Liquid.* A glass tank of red fluid (shader surface with depth tint and
   wobble). Break the glass: GPU particles with collision pour out, a pooling
   decal spreads on the floor, splashes when walked through or shot.
2. *Weather.* One button steps clear, rain, storm, acid rain. Wet surfaces
   darken and shine, puddles form in low spots, lightning flashes, cloth and
   foliage take wind. Acid rain visibly etches a metal prop over 30 s and hurts
   a dummy standing in the open but not one under cover.
3. *Destruction.* A wall, crates, glass panes, a pipe run and open ground.
   Every v0.1 weapon from job 3 breaks them in authored stages with debris;
   ground takes a hole sized by the round. Pre-fractured pieces made with
   Blender's Cell Fracture add-on are swapped in on the hit.
4. *Bodies.* A row of dummies for cuts, severing, ragdoll and the X-ray view.
5. *Vehicle pad.* An empty marked area for later driving work.
Free-walk with the normal player controller; Start button opens a station menu
that teleports you to each plinth.

**PROOF.** One PNG per station in its "after" state, plus one of the whole yard.
**TESTS.** New `tests/mechanics_lab_test.tscn`: every station loads and its
system answers one input. Existing weather, ground-hole, breakable and
vat-smash tests stay green.
**OPEN.** Which weather states the real map uses at launch. Whether acid rain
damages the player at full strength. Do not decide; build the dials.
**OUT.** Story, enemies that fight back, the derby itself.
**Skills.** `create-game-vfx`, `godot-shaders`, `godot-physics`.

---

## Job 2: Rigged bodies

**GOAL.** Fix what Greg saw: *"the body model in third person just has no head
and for some reason the shoulders are massive"*, *"arms looking weird"*, and
ragdolls whose limbs come apart. Every person becomes a proper rigged low-poly
humanoid, with our anatomy riding on its bones.

**EXISTS.** `systems/baseline_human.gd` (zones, organs, wounds, severing),
`systems/anatomy_component.gd`, `systems/ragdoll_body.gd`, `systems/model_skin.gd`
(skins over BaselineHuman zones), `systems/clothing_shell.gd`,
`systems/body_forms.gd`, `systems/world_xray.gd`. These are the contract: no
gore, X-ray or severing feature may be lost.

**OWNS.** New `systems/rigged_body.gd` (+ scene), the imported character and
animation files under `game/art/characters/`, `CREDITS.md`. In
`baseline_human.gd` and `ragdoll_body.gd`, only the code that attaches zones to
bones and builds ragdolls.

**BUILD.**
1. Import one CC0 rigged low-poly humanoid (Quaternius base characters, or a
   Mixamo-compatible low-poly body) and its animation set: idle, walk, run,
   crouch, jump, roll, hit reactions front/back/left/right, two deaths, plus
   the attack sets job 3 needs. Retarget to one skeleton.
2. Map every BaselineHuman zone (head, neck, torso, each arm segment, hands,
   each leg segment) to a bone with a `BoneAttachment3D`, so wounds, organs and
   X-ray layers follow the animated skeleton.
3. Severing: hide the cut limb's bones' mesh section (or swap a pre-cut stump
   mesh) and spawn the limb as its own physics body with the same zones.
4. Death ragdoll from `PhysicalBone3D` on the same skeleton with joint limits
   and damping that fold and sprawl believably, weighty not floaty. Compare
   Godot Physics and Jolt (built in since Godot 4.4) in the mechanics lab and
   write the result into your report before proposing a project-wide switch.
5. Apply the existing PS1-style material so it reads as the game.

**PROOF.** PNGs: front, side, first-person arms, third-person over the
shoulder, a ragdoll at rest, a severed arm. Head present, shoulders normal.
**TESTS.** `ragdoll_body_test`, `gore_sandbox_hit_reaction_test`,
`baseline_human_test`, `body_cut_test` stay green (update with a stated reason
if a test asserted the old pieces). New `rigged_body_test`: every zone has a
bone; a death leaves all unsevered parts within joint reach.
**OPEN.** The final character art (Greg's own later). Whether the player
character uses the same base as enemies.
**OUT.** Faces and character-creation sliders (job 4 hooks those up).
**Skills.** `build-rigged-game-assets`, `godot-animation`, `godot-physics`,
`godot-3d-essentials`.

---

## Job 3: Moving and fighting

**GOAL.** The v0.1 weapons work on a pad and feel weighty. Greg replaced the
fire axe (*"200 years in the future, why would they just have an axe"*) and the
sword. v0.1 weapons are:
- a **heated / vibro cleaver**: an industrial meat-processing cleaver with a
  heating edge, light cyberpunk, still brutal;
- a **powered polearm / staff**: a guard's shock staff with reach;
- the **pistol** (MERCY NINE) with aim down the barrel.
Disciplines in v0.1: **Brawler** (cleaver, staff) and **Marksman** (pistol).

**EXISTS.** `systems/hunter_arsenal.gd` (weapon table, MERCY NINE, slots),
`systems/held_gear.gd` (hands and holding), `systems/sword_moveset.gd`,
`systems/souls_roll.gd`, `systems/souls_pad.gd`, `systems/knockback.gd`,
`systems/combat_stance.gd`, `systems/limb_momentum.gd` (the blow is performed),
`systems/penetration.gd`, ADS on the sight line (merged 4 Oct, see
`git log --grep "Aim down the barrel"`), `systems/lock_ring.gd`. The fire axe
lives in `systems/doctor_route.gd` and `support_unit.gd`: replace its uses with
the cleaver.

**OWNS.** Weapon entries and movesets in `hunter_arsenal.gd`,
`sword_moveset.gd` (generalise to a melee moveset), new weapon model files and
their `CREDITS.md` lines, the camera rig (add the Phantom Camera addon or use
the existing third-person camera), and the axe-to-cleaver swaps.

**BUILD.**
1. Movement on the Souls pad base: walk/run on stick tilt, sprint (L3 or hold
   Circle), crouch, jump, roll with i-frames and stamina cost. Accelerate and
   stop quickly with a landing dip (Greg: grounded, quick stops).
2. Melee: R1 light, R2 heavy (hold to charge), L1 block, L2 parry. Directional
   swings from stick or mouse direction. Hit windows, hitstop 60–90 ms on
   contact, camera kick, blood and spark from the existing FX, enemies stagger
   on heavy hits. Input buffer of about 150 ms so presses during an animation
   are not lost. The cleaver's heated edge glows brighter after hits and
   leaves a burn decal on wounds; the staff has reach and a charged shock
   that staggers. Numbers live in one table so they can be tuned.
3. Pistol: L2 aims down the barrel, R2 fires, L3 steps zoom; rounds are
   objects (`penetration.gd`); casings stay.
4. Lock-on (R3) that frames both fighters over the shoulder; target switch
   with the right stick.
5. Models: free CC0/CC-BY low-poly cleaver, staff and pistol, retextured to the
   house palette, with sight and muzzle markers for ADS.

**PROOF.** A short capture (or PNG sequence) of each weapon killing a dummy and
a fighting enemy in the mechanics lab, on the pad. PNGs of each weapon held in
first person.
**TESTS.** `combat_stance_test`, `souls_pad_test`, `souls_roll_test`,
`sandbox_duel_test`, ADS test from the 4 Oct merge stay green. New
`v01_weapons_test`: each weapon hits a dummy through real input actions.
**OPEN.** The weapons' names. Whether the cleaver's heat costs anything
(battery, overheat). The staff's exact moves beyond light, heavy, charged
shock. Build sensible defaults behind dials and list them in the report.
**OUT.** The other four disciplines, off-hand guns, grips, the weapon wheel.
**Skills.** `design-action-combat`, `maximizing-game-feel`, `godot-animation`,
`build-game-camera-controls`.

---

## Job 4: Waking in the vat

**GOAL.** Greg's opening, in order: *"the cutscene happens after you press
play… you slowly open your eyes, you're in a vat, it's in first person,
there's liquid all around you… actual liquid with physics… it's red, a bloody
vat"*. Then a short intake, the brain screen, the brain hack and the breakout.
No belt, no handless crawl: *"why am I holding this stupid piece of a belt? I
have no hands"*. Four minutes from load-in to standing.

**EXISTS.** `vat_chamber.tscn/.gd`, `systems/vat_intake.gd`,
`systems/vat_body_preview.gd`, `systems/torture_load_in.gd`,
`systems/doctor_examination.gd`, `systems/vat_smash.gd`,
`systems/room_lights.gd`, `systems/character_presets.gd`. Greg likes the intro
cutscene and the "get revenge" beat: do not change the cutscene.

**OWNS.** `vat_chamber.gd/.tscn`, `systems/vat_intake.gd`, the new brain-screen
scene, the liquid shader and spill effect (shared with job 1: import job 1's
liquid if it has landed).

**BUILD.**
1. Fix the intro cutscene playing too fast (find the time-scale or skip leak).
2. Wake: black, then eyes open slowly underwater in first person; red fluid
   with depth tint, wobble and bubbles; muffled sound and heartbeat; you can
   look down at your own rigged body (job 2) with the cords in it.
3. Intake on the pad: bumpers change tab, stick moves rows and values, Cross
   confirms, Circle goes back, Triangle rerolls; big targets; the quick-start
   preset is the default button. Rename by an on-screen pad keyboard. Every
   on-screen key hint follows the device. (Arcade-cabinet redesign is later.)
4. Brain screen after intake: pick Brawler and Marksman (the two v0.1
   disciplines), third person switches on.
5. Brain hack: the existing scream, screen break, memory flashes, 1.2 s of
   silence, BRAIN HACKED / SOUL OVERTAKEN.
6. Breakout with your hands: tear the cords out (pain, blood, scream each),
   hit the glass until it cracks and bursts (Cell Fracture pieces), the fluid
   floods the floor and you fall with it, crawl a few metres, pull up on the
   tank, stand.
7. Declutter and enlarge the experimentation room so the vat, the lab, the
   examiner's door and the exit read clearly.

**PROOF.** PNGs of each beat (underwater, intake on pad, brain screen, glass
cracking, the flood, standing). A timed run under 4 minutes.
**TESTS.** `opening_handoff_test`, `vat_smash_test`, `demo_launch_timing_test`,
intake tests stay green. New: the whole beat chain completes using only joypad
events.
**OPEN.** Exact line of the player's own thoughts at each beat (Greg writes
these). Whether mismatched discipline pairs matter in v0.1 (only two exist).
**OUT.** The other routes, the Support Unit, character art.
**Skills.** `create-game-vfx`, `godot-shaders`, `godot-ui-control`,
`maximizing-game-feel`.

---

## Job 5: The facility, one map

**GOAL.** Greg: *"one coherent map in one section that has all the
interconnection tunnels… not constant loading screens"*, *"take the elevator
down and then it's actually going down"*. v0.1 walks vat floor, examiner
office, service arcade and Lower Works, then rides the heat elevator up.

**EXISTS.** `DESIGN/FACILITY.md` (the map: levels, room origins, grid,
connections), `facility.tscn/.gd`, `facility_tunnel_network.tscn`,
`systems/facility_elevator.gd`, `systems/facility_tunnel_door.gd`,
`systems/breakable_door.gd`, `systems/facility_routes.gd`, the room scenes
(`vat_chamber`, `service_arcade`, `buried_city` for Lower Works). The tunnel
kit (Higgsfield, 4 Oct) is imported.

**OWNS.** `facility.gd/.tscn`, `facility_tunnel_network.tscn`, the elevator and
tunnel-door scripts, room-to-room corridor geometry. Room scripts: only their
exits and the removal of the items listed below.

**BUILD.**
1. Place the four v0.1 rooms at their `FACILITY.md` origins in one scene (or
   streamed cells with no visible load) joined by corridors on the 4 m grid.
2. Transit lift and heat elevator are real rides: doors close, the cab moves
   through a visible shaft with passing light strips, floor indicator and hum,
   doors open on the new level; you keep control and can look around.
3. Remove from v0.1 (switch off behind a flag, do not delete): the breach tool
   and pressure-gate scan puzzle, the vent, "creep past it", the lift-fuse
   hunt, the scavenger stashes, power-line cutting, the wound minigame,
   undressing the subject, text inspections, and the invisible demo barrier.
4. One objective line, never clipped at any resolution, always naming the next
   doable thing and matching the door in front of you.
5. Retexture greybox with ambientCG grime; Quaternius or Kenney CC0 modular
   sci-fi pieces where the tunnel kit has gaps; pools of light per the lighting
   decisions in `DESIGN.md` (28 September).

**PROOF.** A walk from the vat to the surface door with zero
`Interstitial.travel` calls (log it). PNGs of every corridor join and both lift
rides.
**TESTS.** `first_thirty_route_test` (update to the new route), facility and
elevator tests from 4 Oct stay green. New: walkable path vat to surface with
no scene change.
**OPEN.** Whether the switched-off routes come back as dead ends or sealed
doors in v0.1.
**OUT.** Drains, Support Unit, doctor chase, the derby.
**Skills.** `author-game-levels`, `godot-3d-essentials`, `performance-profiling`.

---

## Job 6: The examiner

**GOAL.** Greg: *"it's a boss fight. I hit him once, hit him twice, his head's
all broken… he's dead"*, and *"I literally killed him, where is his key"*. A
real, fair boss; his keycard always drops and always opens the staff door.

**EXISTS.** `systems/examiner_fight.gd`, `systems/doctor_examination.gd`,
`systems/doctor_route.gd`, `addons/limboai` (behaviour trees), the staff-door
and cupboard code in `vat_chamber.gd`, `systems/field_inventory.gd` (the
STAFF KEYCARD item already appears there; the door checks a different thing).

**OWNS.** `examiner_fight.gd`, a LimboAI tree for him, the keycard drop and the
staff-door check.

**BUILD.**
1. On the rigged body (job 2): about 30 seconds of fight. Telegraphed scalpel
   slashes, a syringe lunge that slows you for 6 s, a stagger window after a
   parried slash, two phases (he gets desperate under half health). Readable
   wind-ups, fair damage, the arena lit so you can read him.
2. Fix the head breaking apart after two hits: dismemberment is deliberate and
   earned, not a mesh glitch.
3. On death his keycard drops as a visible pickup; the staff door reads the
   same inventory item; its prompt names what it needs and where it is.
4. The cupboard behind it gives loot that matters for v0.1 (ammunition, a
   heal, the staff weapon if job 3 places it there).

**PROOF.** PNGs of his telegraphs, the keycard on the floor, the door opening.
**TESTS.** Examiner and doctor tests stay green. New: kill him, card in
inventory, door opens, every time (run it ten times with random seeds).
**OPEN.** His lines (Greg writes them). His final model (stand-in until Greg
says).
**OUT.** The hologram, the vehicle bay, the chase route.
**Skills.** `tune-enemy-ai`, `design-action-combat`,
`adversarially-validating-game-repairs`.

---

## Job 7: Death, saves and the screen

**GOAL.** You can die, come back, carry on and always know where to go, on a
pad, without clutter. Greg: *"there's no inventory… there's not even a menu
showing my items"*, *"there's like a trillion different UI things"*.

**EXISTS.** `systems/vat_rebirth.gd`, `systems/rebirth_site.gd`,
`systems/quantum_saves.gd`, `systems/character_presets.gd`,
`systems/field_inventory.gd`, `systems/key_hints.gd`,
`systems/gothic_field_hud.gd`, `systems/input_profile.gd`.

**OWNS.** The v0.1 HUD layout, the death and bloodstain flow, checkpoint
triggers, the pause/settings and inventory entry points.

**BUILD.**
1. Death: regrow in the vat; your carried items stay at your corpse; your
   blood fragments drop as a pulsing organ-sigil you hear before you see
   (heartbeat rising, red-copper glow); walk into it to recover; die again
   first and it is gone.
2. Checkpoints at the vat, the examiner office door and each lift.
3. Inventory on one button (Touchpad / Tab), pad-navigable, showing what you
   carry; the first time an item matters, one hint shows the button.
4. HUD for v0.1: health and stamina, one objective line, one context prompt.
   Everything else off. One-time button hints, big, bottom centre, device
   aware.
5. Pause and settings on Options / Esc, pad-navigable: volume, sensitivity,
   invert, FOV, subtitles, gore and censor, graphics preset.

**PROOF.** PNGs of the HUD in each room, the bloodstain, the inventory on pad,
the pause menu.
**TESTS.** Rebirth, saves, presets and key-hint tests stay green. New: die,
recover the stain, quit, load the checkpoint.
**OPEN.** What the blood fragments buy in v0.1 (nothing until the brain board
exists, unless Greg says otherwise).
**OUT.** The Black Mirror, the brain board, the Wire.
**Skills.** `godot-ui-control`, `build-game-inventory`, `audit-ai-design-slop`.

---

## Job 8: Play it, fix it

**GOAL.** Greg plays v0.1 from START to the surface on the pad and the five
worst problems get fixed, then again.

**BUILD.** Merge jobs 1–7. Build the tag `v0.1-escape`. Hand Greg
`P:/GameDev/PLAY.cmd`. Record his notes verbatim into the direction file.
Fix the five worst, one builder each, then repeat.

**PROOF.** The tag, a full-run capture, and Greg saying it feels right.
