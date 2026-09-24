# The first 30 minutes, the demo and the start menus: the big checklist

24 September 2026. Greg: *"keep going 100x the size of checklist for the
first 30 mins and the demo and menus at the start and opening reanimating
the text and graphic of the actual game logo image with gfx stuff"*.

This checklist expands `DESIGN/GOAL_LOOP_2.md` down to single, shippable
lines. Section 0 of that file (destruction physics) is still the top
priority. This file is the long queue after it, in play order: from
launching the exe to arriving in the Hunt.

Marks used:
- `[x]` is built and merged, with its commit in `DESIGN/GOAL_LOOP_2.md` or
  git log.
- `(rec)` is an assistant proposal until Greg says yes.
- **ASK** is a question box for Greg, recommended option first.
- Every other line is Greg's direction, or follows from it directly.

A line is done when a player can do it in the real build, the world records
it, it's rendered and looked at, it has a test, and it's merged and built
(see "Done means" in `DESIGN/FIRST_30_REBUILD.md`).

## Paste this to start it

> /goal Work `DESIGN/GOAL_LOOP_2.md` section 0 (destruction physics) first,
> then `DESIGN/FIRST_30_MEGA.md` top-down, on your own, all night. Branch
> `claude/dust-to-bones-look`. Read `AGENTS.md`, `DESIGN.md` and the
> project skills first.
>
> Take lines in batches that share one system. For each batch:
> - build it so a player can do it in the real route
> - record it in WorldHistory
> - render it and look (motion gets a clip)
> - add one small test, with the core suite green
> - merge it
> - send me a Windows build named `WOF-<commit>`
>
> Tick each line with its commit. Ask me question boxes, recommended option
> first, at every ASK, and record my answers in `DESIGN.md` straight away.
> If an ASK blocks a line, build the recommended option behind the question
> and move on. Report what you verified and what you couldn't. Go.

---

## A. Launch and boot (seconds 0-10)

### A1. The exe and the first frame
- [ ] The exe icon is the WOF seal at every Windows size (16 to 256), not
      the Godot robot.
- [ ] The window title reads "Wizards Only Fools", with no "(DEBUG)".
- [ ] The first frame is black, never a grey Godot flash.
- [ ] (rec) Godot's boot splash is replaced by a black frame with the
      seal's ember, so the handoff into our splash is seamless.
- [ ] It launches borderless-fullscreen at the monitor's resolution by
      default, with windowed as a setting.
- [ ] If the GPU can't do Forward+, it falls back to Compatibility with a
      one-line notice, not a crash.
- [ ] A crash on boot writes `user://crash.log` with the commit.
- [ ] The build's commit shows in the corner of the title screen, small.
- [ ] Double-launching focuses the running game instead of opening a
      second window.
- [ ] (rec) Time from exe to first splash frame is under 2 s on a mid PC;
      measure it and write it down.

### A2. Publisher cards
- [x] CellOutz card and Allusions Too Grandeur card, blood-poured
      (`boot_splash.gd`).
- [ ] The Allusions Too Grandeur card uses the "TOO" corrected wordmark
      everywhere, including the site and the store.
- [ ] Each card has its own sound: a hum for the CellOutz static, and a
      drip for Grandeur.
- [ ] Cards skip on any key, click or pad button, and a skip is never
      swallowed by the next screen.
- [ ] Held skip (hold any key) skips everything straight to the menu after
      the first launch.
- [ ] (rec) The first launch plays everything; later launches play the
      short cut (seal only).
- [ ] The card timing is recorded in a test, so a slow card shows up as a
      failed number.
- **ASK:** "Keep both publisher cards every launch, or only the first?"

### A3. The logo, re-animated (Greg: "reanimating the text and graphic of the actual game logo")
- [x] The real `wof_stacked.png` is the title, not a redraw (`logo_fx.gdshader`).
- [x] **The seal assembles.** The Algiz seal's four arc segments slide in
      from off-centre, lock, and spark at each joint.
- [x] **Glitch in.** The wordmark arrives through RGB split and
      scan-slice tearing; the slices settle one by one.
- [x] **Burn reveal.** The letters burn in from noise with a hot ember edge,
      not a fade.
- [x] **Rust breathing.** The letters' rust texture crawls slowly under a
      moving noise, as if wet.
- [x] **The drips run.** The six blood drips under ONLY FOOLS lengthen, bead
      and fall, then re-form.
- [x] **Spikes flare.** The thorn spikes glint in a sweep of light that
      crosses the mark every few seconds.
- [x] **CRT and VHS.** Scanlines, a rolling bar, and a chromatic fringe,
      held low enough that the name always reads.
- [x] **Heartbeat.** The whole mark pulses faintly with a heartbeat, and
      the pulse sets the glitch intensity.
- [x] **Sparks and embers.** Sparks at the lock; embers rise off the mark in the splash and on the title (`logo_embers.gd`). A few embers rise from the letters; sparks fly
      when the seal locks.
- [x] **Sound.** A burn riser, a metal clank as the seal locks, static on
      the tear, and a heartbeat thump (`logo_audio.gd`; the drip tick is
      generated but not yet cued).
- [x] The same animation plays on the title screen, behind the menu,
      calmer (`country_town_menu.gd`, the wet run down its drips).
- [ ] It can be skipped, and it's never longer than 6 s on first launch.
- [ ] A clip of it goes on wizardsonlyfoolz.net and the Instagram.
- [ ] (rec) A 9:16 version for Reels, and a 1:1 loop for the profile.
- **ASK after the first cut:** "More glitch, more gore, or calmer?"
- **ASK:** "Should the seal spin, or only assemble?"

## B. The title screen and menus

### B1. The title screen
- [x] Main menu with START GAME, Demo, Full Game (locked), Sandbox,
      Support, and settings (`country_town_menu.gd`).
- [x] The live logo animation (A3) sits above the menu.
- [ ] The background is a slow camera over the country town at dusk, with
      the Wire's paper collage bleeding at the edges.
- [ ] Menu items are set in the game's stencil face (`CellOutzType`), never
      Godot's fallback font.
- [ ] Hover makes an item glitch-shift, with a tick sound.
- [ ] Selecting an item makes the blood pour down it, then the screen goes.
- [ ] It works with keyboard, mouse and gamepad, and the focus is always
      visible.
- [ ] Idle for 60 s and the attract mode plays: gameplay footage in the
      body-cam frame.
- [ ] A version and build line sits in one corner, the Discord and site in
      another.
- [ ] Escape on the title screen asks "Leave?" and never just closes.
- [ ] (rec) The title music is an ambient pad with the vat's heartbeat
      under it.
- **ASK:** "Title music: your track, a generated one, or silence and room
  tone?"

### B2. DEMO // THE BEST HALF HOUR
- [x] The demo door exists.
- [ ] The demo's scope is exactly minutes 0-30, and it ends at the Hunt's
      first objective with an end card.
- [ ] The end card: "END OF THE DEMO", the time you took, the route you
      chose, what you killed and freed, a wishlist link, and the Discord.
- [ ] The demo's stats are recorded in WorldHistory and shown on the end
      card.
- [ ] After the end card: play again, a different route, or the menu.
- [ ] Demo saves are separate from full-game saves.
- [ ] Demo builds hide the full-game door or show it as locked, with "SOON".
- [ ] (rec) A demo feedback prompt at the end: one line and a 1-5 rating,
      saved locally and optionally mailed.
- [ ] The demo build is named `WOF-DEMO-<commit>`.
- **ASK:** "Where does the demo end: the first Hunt objective, the first
  kill up top, or the first minute on the surface?"

### B3. Full game and sandbox doors
- [ ] Full game shows "LOCKED // SOON" in the stencil face, with a glitch on
      hover.
- [ ] The Psychofrenia sandbox launches its own scene, and returns cleanly.
- [ ] The locked doors say what's coming, one line each.

### B4. Saves: Quantum Immortality
- [x] The branch panel: birth a world, choose a surviving world.
- [ ] Slots show the route, time played, day, and a thumbnail from the last
      body-cam frame.
- [ ] Overwriting a slot asks twice.
- [ ] A corrupt save shows "THIS WORLD DID NOT SURVIVE" and never crashes.
- [ ] Saves carry the commit they were made with, and an old save loads or
      explains why not.
- [ ] (rec) Autosave at every beat of the first 30.

### B5. Settings
- [x] Gore, censor, bloom, graphics preset, render scale, AA, vsync and
      colour grade.
- [ ] Every setting applies live, with a preview, and persists.
- [ ] Audio: master, music, effects, voice, and the examiner's voice volume.
- [ ] Controls: remap every key, with the key caps shown everywhere updated.
- [ ] Mouse sensitivity, invert Y, FOV (70-110), and head bob on or off.
- [ ] Subtitles on or off, and their size.
- [ ] Accessibility: reduce flashing (tames the glitch and datamosh),
      reduce camera shake, colourblind-safe telegraph colours.
- [ ] Language placeholder, English only for now.
- [ ] Reset to defaults, per tab.
- [ ] Settings are reachable from the pause menu, not only the title.
- **ASK:** "Is 'reduce flashing' on by default for the demo?"

### B6. Support, bugs and the site
- [x] Support / report a bug opens mail.
- [ ] (rec) Bug reports carry the commit, the scene and the last 50 ledger
      lines, pasted in.
- [ ] A link to wizardsonlyfoolz.net and the Discord (once it exists).
- [ ] Credits: Greg, the CC-BY models with their credit lines, and the
      tools.

### B7. The pause menu
- [ ] Resume, settings, the controls sheet, save and quit, quit to the
      title.
- [ ] Pausing freezes the world, but the body-cam REC keeps blinking.
- [ ] The pause menu has the same stencil and glitch style as the title.

## C. The intake (minutes 0-4)

### C1. Waking in the vat
- [x] You wake submerged, and the examiner enters by his door.
- [x] The examiner's desk is beside the tank, and the screen faces you.
- [ ] Bubbles rise past the camera, and your breath comes through the tube.
- [ ] The first sound is your own heartbeat, muffled by fluid.
- [ ] The vat glass has fingerprints and old scratches on the inside.
- [ ] The examiner looks at you before he looks at the screen.
- [ ] His footsteps are heard, then he's seen.
- [ ] (rec) A slow head-turn is allowed while submerged; you can't move.

### C2. The examiner
- [ ] A better 3D model, with an ordinary face and a bloodied coat.
      **ASK** with side-by-side renders.
- [x] His mouth moves with his voice (first pass).
- [ ] Blinks, and eye darts between the screen and you.
- [ ] His hands type on the keyboard while he talks.
- [ ] He reacts to a refusal: a pause, a note, a look.
- [ ] He reacts to a stare answer by leaning closer to the glass.
- [ ] His name stays withheld, and the header says so.
- [ ] His lines never repeat inside one intake.
- [ ] His voice is the generated pipeline, pitched to his model.

### C3. The intake pages
- [x] Receipt-printed tabs, blink icons, a transcript, and stat gauges.
- [x] The pages swing in on gears, ink bleeds, and blood runs from the
      clip.
- [ ] Every tab's content is readable at 1080p and at 720p.
- [ ] The blank space under short pages holds the subject photo, stamps
      and the procedure log. **ASK.**
- [ ] The RACE tab shows a small render of each race.
- [ ] The FACE tab's sliders each move one feature (a regression test
      exists).
- [ ] The BODY tab previews in the vat on the right, and turns with the
      mouse.
- [ ] The SCHEDULE tab shows what each schedule costs, in plain words.
- [ ] Filing plays the stamp sound, and the sheet flies up out of frame.
- [ ] Filing records the preset, and rebirth reuses it.
- [ ] (rec) Tab and Shift-Tab move between tabs, and Enter confirms.
- [ ] (rec) An idle nudge after 40 s: the examiner taps the glass.

### C4. Procedures and refusals
- [ ] Each procedure shows its cost before you blink yes.
- [ ] Refusals are counted, and they change the breakthrough later.
- [ ] A refused procedure gets his line and a stamp: REFUSED.
- [ ] (rec) A "torture cycle" beat on refusal that you can see on the
      mirror feed.

## D. The departure and the drain (minutes 4-6)
- [x] He files you, leaves by his door behind the vat, and it shuts.
- [ ] His walk is animated with real steps, not a slide.
- [ ] The staff door stays sealed, and says why if you touch it later.
- [ ] The tank alarm lights up amber and then red as the drain starts.
- [ ] The fluid level drops visibly, and bubbles speed up.
- [ ] Your body sinks onto the wires as the fluid goes.
- [ ] The drain sound: a gurgle, and a pump fighting air.

## E. The wires and the breakthrough (minutes 6-8)
- [x] END ALL SUFFERING, and three tugs per wire.
- [x] GET REVENGE, then the glass goes.
- [ ] Each tug has its own pain flash and a heartbeat spike.
- [ ] Pulling the mouth tube is a separate, last pull. **ASK:** the beat.
- [ ] The breakthrough reads as your soul seizing the implant: wetwire
      feedback, sigils flickering over the HUD as it boots. **ASK.**
- [ ] The HUD boots as the implant is hacked: REC, time, the location
      stamp, one piece at a time.
- [ ] Third person unlocks here or later. **ASK** (Greg's call).
- [ ] The glass break is a physics shatter, with shards that stay (links
      to destruction 0.3).
- [ ] You fall onto your knees in the puddle, and get up by pressing a key.

## F. The Growing Floor (minutes 8-12)

### F1. The room
- [x] Lain / Evangelion cables everywhere, 336 of them, and none at head
      height.
- [x] The station is beside the tank.
- [x] The other tanks can be smashed: the glass, the fluid and the subject
      out.
- [ ] The freed subjects turn up again in the drains and the Lower Works.
- [ ] (rec) Each freed subject has a name tag you can read (Greg writes
      names).
- [ ] More cameras on the walls; they turn to follow you.
- [ ] A camera that sees you breaking tanks raises the alarm level.
- [ ] Every door answers when used.
- [ ] The staff door is sealed, with a keypad that says "STAFF ACCESS".
- [ ] The pit door is readable and lit.
- [ ] The observation window at the back shows the examination room.
- [ ] (rec) Wet footprints follow you from the puddle.

### F2. The first objects
- [x] Pry the jammed tank with the restraint, and take the dead subject's
      smock.
- [ ] Hold I to inspect the restraint; it shows its wear.
- [ ] The smock has a name stitched in it.
- [ ] (rec) A clipboard on the station you can read: your own intake sheet,
      stamped.

### F3. The examiner's desk
- [ ] The screen shows your filed sheet, and can be read up close.
- [ ] The keyboard can be smashed, and the screen shot out (destruction
      0.1).
- [ ] (rec) A drawer with one item: a key card? **ASK** what's in it.

### F4. His door (the doctor's route)
- [x] It breaks with the restraint, the axe or your shoulder.
- [x] The fire axe on the wall.
- [ ] The door's break stages read clearly: dents, a cracked panel, a
      hinge gone, down.
- [ ] The lift ride down has sound, and a flickering light.

## G. The Service Arcade (minutes 12-17)
- [x] The ram, the card, Hollis coerced or put down, his hand on the reader,
      his gun in Carry, and the pressure gate.
- [ ] Hollis's real model. **ASK** (Greg picks, CC-BY credited).
- [ ] Hollis's warning shot, wound and kill read in play; he says "You
      again" after a death.
- [ ] The arcade machines can be smashed (destruction 0.2).
- [ ] The vending machine gives something when hit hard enough.
- [ ] Cameras in the arcade feed a monitor at Hollis's post.
- [ ] Hollis reacts to the alarm level set in the Growing Floor.
- [ ] Taking only his hand needs a blade the facility hasn't given you yet.
      Greg decides.
- [ ] (rec) A second way past Hollis: the vents, for a small body.

## H. The Lower Works (minutes 17-22)
- [x] Lit enough to read, the sentinel, the fuse, and the lift.
- [ ] The sentinel's patrol is readable from its lights.
- [ ] The fuse box sparks, and the lift wakes with a sound.
- [ ] Barricades you can break or climb (destruction 0.2 and 0.4).
- [ ] The breach tool swings as a weapon with the tier rules.
- [ ] (rec) A bingyanga ward glimpse through glass on the way.

## I. The Support Unit (the doctor's route)
- [x] Cells, restraints, bingyangas and guards, an alarm director.
- [ ] Every cell can be opened, and every freed one rolls friendly or
      hostile.
- [ ] Guards react to screams and cameras.
- [ ] The first blood-tree lesson happens here, in the first real fight.
- [ ] The doctor's bay, the hologram, the call, and the ramp up.
- [ ] The doctor's name, history and vehicle. **ASK** (Greg decides).

## J. The heat elevator (route 1)
- [x] Up to the overworld, surfacing at the sallyport point.
- [ ] The ride has heat shimmer, a rising sound and a view up the shaft.
- [ ] (rec) A last-second threat on the lift: something grabs the cage.

## K. The old drains (route 2)
- [x] The gallery, the cistern, the outfall, and the drain stalker.
- [ ] A second threat, or a chase. **ASK.**
- [ ] Water that ripples around your legs, and sound that echoes.
- [ ] Freed Growing Floor subjects appear here.
- [ ] The dry falls: blood waterfall, smashed trees, the gorge track.

## L. The derby (route 3, capture)
- [x] Wreck = captured, crushed = dead; the tunnels out to the dry falls.
- [ ] A slow-motion kill cam on the real body. **ASK** how slow, how long,
      how often.
- [ ] The crowd reacts to big wrecks.
- [ ] A derby win pays out in scrip.

## M. Arrival in the Hunt (minutes 28-30)
- [x] All four routes land at their own spot.
- [ ] You surface at 10:00, not in agony.
- [ ] The first thing you meet up top. **ASK** what it is.
- [ ] A reason to go somewhere: the stamped objective and a map mark.
- [ ] A readable first fight (a scavenger), with the sparring post nearby.
- [x] The breakable yard by the sparring post.
- [ ] The demo end card triggers at the demo's end point (B2).

## N. Death and rebirth in the first 30
- [x] Every killer in the first 30 sends you to the rebirth vat.
- [ ] Rebirth plays a short, skippable regrowth.
- [ ] Your old body lies where you fell, and E recovers what it held.
- [ ] Rooms for the rival's and the cult's vats. **ASK** who they are.
- [ ] (rec) A death counter on the demo end card.

## O. Combat in the first 30
- [x] Tiers, telegraphs, block and parry, readout, sparring, and the five
      blood-tree moves.
- [ ] Hit feel for each move (hitstop, camera, sound).
- [ ] Unarmed combat reads well enough to fight a bingyanger.
- [ ] Guns are rare before the surface; each round counts.
- [ ] Enemies call out to each other.

## P. Destruction (see GOAL_LOOP_2 section 0; mirrored here in play order)
- [x] 0.1 Bullets and blades break things, and the Hunt yard.
- [ ] Growing Floor: tank glass as physics shards, monitors, the keyboard,
      jars.
- [ ] Service Arcade: machines, the vending machine, glass, Hollis's
      window.
- [ ] Lower Works: barricades, crates, pipes that burst steam.
- [ ] Drains: rotten boards, grates.
- [ ] Support Unit: cell glass, restraint beds, monitors.
- [ ] Hunt: fences, cars, lights, crates, shacks with panels.
- [ ] Explosions: gas canisters in the Lower Works.
- [ ] Everything broken stays broken across loads.

## Q. The HUD and the body-cam
- [ ] The REC stamp, time and location, the same in every scene.
- [ ] Key caps pinned next to things, from one controls sheet.
- [ ] The objective card style is the same everywhere.
- [ ] The Nerve Rig spine shows health and stamina in the first 30 too.
- [ ] The censor glitch works in every scene.
- [ ] Subtitles for every spoken line.

## R. Sound
- [ ] A sound for every beat: the vat drain, the wires, the glass, Hollis's
      shot, the gate, the lift, a case opening, gold dropping.
- [ ] A material sound for each breakable: glass, metal, wood, flesh.
- [ ] Room tone per area.
- [ ] Footsteps per surface (grating, tile, water, dirt).
- [ ] Music: the title, the facility (low), and the Hunt. **ASK.**

## S. Performance
- [ ] A frame-time budget per scene, measured in Forward+ and written down.
- [ ] The Growing Floor at 60 fps on a mid PC, with cables and tanks.
- [ ] A debris cap per scene.
- [ ] Load times between scenes are under 3 s.

## T. Builds, QA and the site
- [ ] A `wof-build` skill: one command to export, name, zip, split and
      write notes.
- [ ] A demo build and a full build from the same commit.
- [ ] Every build becomes a GitHub Release, and the site's button finds it.
- [ ] A route replay test times each route.
- [ ] A smoke test that boots, gets through the splash, reaches the menu,
      starts the demo and reaches the vat.
- [ ] wizardsonlyfoolz.net goes live (the Pages and DNS steps are Greg's).
- [ ] The trailer and the logo animation go on the site.

## U. Waiting on Greg
- Hollis's model, and the examiner model.
- The doctor's name, history and vehicle.
- Names for freed subjects.
- The first thing up top.
- The title music.
- Where the demo ends.
- The anatomy downloads.
- The blade for Hollis's hand.
- When third person unlocks, and the breakthrough beat.
- Where the Board lives, and the sky agency.

---

# Part II: room by room, beat by beat

Each room gets the same six questions:
- **See:** what reads on screen.
- **Hear:** its sound.
- **Touch:** what E, click and HOLD I do.
- **Break:** what gives under a blow or a round.
- **Record:** what WorldHistory remembers.
- **Test:** how it's proven.

Every line below is **(rec)** unless it cites Greg.

## II.1 The boot splash, frame by frame
- [ ] See: the CellOutz card's static resolves into its letters, never a
      plain fade.
- [ ] See: the Grandeur card's drip pour matches the logo's drip colour
      exactly.
- [ ] See: the seal's burn starts at its centre rune and spreads out to the
      arcs.
- [ ] See: the four arcs lock in order (top, right, bottom, left), each
      with its own spark burst.
- [ ] See: the wordmark's spikes glint once each as the sheen passes.
- [x] See: embers rise off the wordmark for its whole hold.
- [ ] See: the collage backdrop dims while the mark burns, then comes back.
- [ ] Hear: a riser under the seal's burn, and a metal clank on each arc
      lock.
- [ ] Hear: a vinyl-crackle bed that ducks when the wordmark lands.
- [x] Hear: one low heartbeat thump per shader beat.
- [ ] Touch: any key skips to the next card, and holding skips all.
- [ ] Record: launches counted in the settings subject.
- [ ] Test: `logo_fx_test` and `boot_splash_timing_test` stay green.
- [ ] Test: a movie-writer clip of the splash is regenerated per release.

## II.2 The content warning
- [ ] See: WARNING in the stencil face, with the CellOutz liability notice.
- [ ] See: CLINICAL, FIELD CONDITIONS and UNRESTRICTED as a focused list.
- [ ] See: the choice previews what it hides (a blurred sample).
- [ ] Hear: a relay click per option and a stamp on confirm.
- [ ] Touch: 1-3, up and down, Enter, the mouse and a pad all work.
- [ ] Record: the choice and the time it was made.
- [ ] Test: it shows once, then only from settings.
- **ASK:** "Is the default choice UNRESTRICTED, FIELD, or none selected?"

## II.3 The title screen, piece by piece
- [x] The live logo: burn in, wet run, heartbeat, a tear every 5.5 s.
- [ ] See: the Algiz label pulses in time with the logo's beat, not on its
      own sine.
- [ ] See: the menu items type on, one at a time, after the logo lands.
- [ ] See: the hovered item is underlined in blood, with the others
      dimmed.
- [ ] See: ENTER CELLOUTZ.NET opens the site, with a confirm.
- [ ] See: the hexagram panel on the right shows the selected item's
      preview (demo footage, the locked full game, the sandbox).
- [ ] See: the footer line scrolls: WORLD BUILD // EVERY ACTION LEAVES A
      WITNESS.
- [ ] Hear: a hover tick, a select thud, a back click.
- [ ] Hear: title music ducks under the logo's tear bursts.
- [ ] Touch: the arrow keys wrap around, and Esc backs out of any panel.
- [ ] Touch: the mouse wheel scrolls the menu on small windows.
- [ ] Record: which door was chosen, and how long it took.
- [ ] Test: a title capture at 720p, 1080p and 1440p, with nothing cut
      off.
- [ ] Test: a gamepad-only walk from the title into the vat.

## II.4 Settings, line by line
- [ ] Graphics: preset, render scale, AA, vsync, bloom, colour grade,
      shadows, max FPS.
- [ ] Display: fullscreen, borderless, windowed, and monitor choice.
- [ ] Gore: OFF, REDUCED, FULL; censor on or off.
- [ ] Audio: master, music, effects, voices, UI, and mono audio.
- [ ] Controls: every action rebindable, conflicts warned, reset per
      action.
- [ ] Camera: FOV, sensitivity, invert, head bob, shake, and third-person
      distance.
- [ ] HUD: scale, opacity, and the body-cam overlay strength.
- [ ] Accessibility: reduce flashing, subtitles, subtitle background, and
      hold versus toggle for block, crouch and sprint.
- [ ] Every row has a one-line description under it.
- [ ] Changes are saved on leave, with no Apply button needed.
- [ ] Test: each setting persists across a restart.

## II.5 The Growing Floor, object by object
- [ ] Your tank: See the cracks from your wire tugs appear before the glass
      goes.
- [ ] Your tank: Hear the glass groan with each tug.
- [x] Your tank: the glass goes on GET REVENGE.
- [x] The other tanks: smash, drain and free the subject.
- [ ] The other tanks: See a subject press its hands to the glass when you
      come near.
- [ ] The other tanks: Hear muffled knocking from the ones still full.
- [ ] The other tanks: Record which ones you left full; the world
      remembers who you didn't free.
- [ ] The jammed tank: See its pry marks after you open it.
- [ ] The dead subject: See the smock gone from the body once you take it.
- [ ] The station: Touch reading the screen shows your filed sheet.
- [ ] The station: Break the monitor with a round or a blow; it sparks and
      goes dark.
- [ ] The station: Break the keyboard; keys scatter.
- [ ] The cables: Touch pulling one down, with sparks.
- [ ] The cables: Break a lit line by shooting it; it flickers out.
- [ ] Cameras: See each one turn to follow you, with a red lens.
- [ ] Cameras: Break one to cut what the alarm sees.
- [ ] Cameras: Record what they saw you do.
- [ ] The staff door: Touch the keypad: STAFF ACCESS REQUIRED.
- [ ] His door: See its damage states; Hear each blow.
- [ ] The observation window: See the examination room through it.
- [ ] The observation window: Break the glass (destruction 0.3).
- [ ] The pit door: See it lit, readable, with a heat haze.
- [ ] The floor: See wet footprints; the puddle ripples when stepped in.
- [ ] Test: every tank can be broken; every door answers; no prop blocks
      the aisle.

## II.6 The Service Arcade, object by object
- [ ] The ram and the card: See them lit where they lie.
- [ ] Hollis: See the real model, credited. **ASK.**
- [ ] Hollis: Hear his warning, then his escalation lines.
- [ ] Hollis: Touch coerce, threaten, fight, or sneak past.
- [ ] Hollis: Record how he was dealt with, and his memory of you.
- [ ] The reader: See his hand on it, and the door unlock.
- [ ] Machines: Break the arcade cabinets; screens shatter, sparks.
- [ ] Machines: Touch playing one, a short joke screen.
- [ ] Vending: Break or pay; it drops something.
- [ ] The pressure gate: See the pressure gauge move as it opens.
- [ ] Test: each way past Hollis reaches the gate.

## II.7 The Lower Works, object by object
- [ ] The sentinel: See its patrol light sweep; Hear its servo whine.
- [ ] The sentinel: Break its lamp to blind it for a few seconds.
- [ ] The fuse: See the arc when it's seated.
- [ ] The lift: See the heat shimmer rise; Hear the chain.
- [ ] Barricades: Break them into fragments (0.2); Touch climb over.
- [ ] Pipes: Break a pipe; it vents steam that hides you.
- [ ] Gas canisters: Break one and it explodes (0.5).
- [ ] The drain hatch: See it rusted; Touch prying it open.
- [ ] Test: the sentinel can kill you, and you wake in the vat.

## II.8 The old drains and the dry falls
- [ ] The water: See ripples; Hear splashes per step.
- [ ] The stalker: See it only by its shape in the dark; Hear it by sound.
- [ ] Freed subjects: See them here if you freed any.
- [ ] Freed subjects: Hear their lines echo.
- [ ] Grates: Break them to take a shortcut.
- [ ] The dry falls: See blood run down the rock; Touch sliding down the
      track.
- [ ] The gorge trees: Break the snapped trunks further.
- [ ] Test: the drains route and the falls route both land at their
      point.

## II.9 The Support Unit and the doctor's bay
- [ ] Cells: See each bingyanga; Hear each plead.
- [ ] Cells: Touch opening; Break the glass.
- [ ] Guards: See them respond to screams; Hear radio chatter.
- [ ] The doctor's bay: See the hologram doctor; Hear the call.
- [ ] The ramp: Touch walking up it; Record the route.
- [ ] Test: every cell opens, and every freed one rolls a mood.

## II.10 The derby
- [ ] The arena: See the crowd; Hear the announcer.
- [ ] Cars: Break panels, doors and hoods (built); a slow-motion kill cam
      on the real body. **ASK.**
- [ ] The tunnels: See GTA-style tunnels to the falls.
- [ ] Test: wreck equals capture, crush equals death, and both are
      recorded.

## II.11 Arrival in the Hunt
- [ ] See: the arrival card with the route's name.
- [ ] See: the first person, poster or threat within 60 s. **ASK.**
- [x] The breakable yard by the sparring post.
- [ ] Touch: the sparring post, the Wire exchange (U), the Brain Index
      (Tab), and the blood tree (7).
- [ ] Record: the arrival route, the time, and the first act up top.
- [ ] Test: a route replay reaches the Hunt and logs its time.

---

# Part III: the test matrix for the demo

| Check | How | Pass |
|---|---|---|
| Boots to the title | Launch the exe on Windows | Under 10 s, no errors |
| Title logo animates | Movie-writer clip | Burn, run, beat and tear all visible |
| Content warning once | Two launches | Shown on the first only |
| Every route reaches the Hunt | `first_thirty_route_test` | 4 of 4 |
| Every killer rebirths | `rebirth_every_killer_test` | All killers |
| Tanks break | `vat_smash_test` | Glass, fluid and subject |
| World breaks | `world_break_test` | Lights and barricades |
| Combat moves | `blood_moves_test` | 5 of 5 |
| Settings persist | A restart test | Every row |
| 60 fps | Frame-cost probe per scene | Under 16.6 ms on the reference PC |
| No softlocks | A route replay on each route | No stuck state |
| Demo end card | Reach the end point | Shows the stats and links |

# Part IV: the demo release
- [ ] A demo build with the demo flag, and the full-game door locked.
- [ ] Store capsules (460x215, 600x900, 231x87) from the lockup.
- [ ] A trailer cut from movie-writer clips: splash, vat, wires, smash,
      Hollis, derby, Hunt.
- [ ] The site's download button points at the demo release.
- [ ] Release notes written for players, not developers.
- [ ] A feedback form linked from the end card and the site.
- [ ] Discord invite once it exists.
- **ASK:** "itch.io first, Steam next fest, or both?"
