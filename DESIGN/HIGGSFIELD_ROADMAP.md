# Higgsfield roadmap: every image and cutscene for minutes 0–30

25 September 2026. Greg: "one big roadmap Higgsfield checklist for it to make
images and 3D render cutscene videos." This is that list, in play order, so
the Higgsfield agent can work top to bottom. It builds on
`HIGGSFIELD_PROMPTS.md` (house style) and `HIGGSFIELD_DEMO_PROMPTS.md`
(sections 0–10); anything already kept there is not repeated.

**Paste this block to the Higgsfield agent first**

> Rules for every job below:
> 1. Game: WIZARDS ONLY FOOLS. PS2-era low-poly occult horror, first person,
>    crunchy 512px texels, dithering, fog, sick colour. Palette: near-black
>    #060b09, dried blood #461009, arterial red #a8281a, copper #b0552a,
>    bone #e6d4ac, acid green #b4da48.
> 2. **Do not invent story, lines, names, systems or titles.** The only
>    on-screen lines allowed are the canon lines quoted in this file,
>    verbatim. Everything else: no text, no letters, no watermark.
> 3. Flat art ends "centered, on pure black background, 2048x2048". Never
>    "transparent" (gives a fake checkerboard). Never a white ground.
> 4. Scenes are 16:9, 1920x1080. Videos are 16:9, 720p or 1080p, 5–10 s,
>    locked or slow camera unless the shot says otherwise.
> 5. Keep the look of the attached references: the Algiz rune seal, the
>    CPU die, the examiner, the vat, the X-ray body. One world.
> 6. Name every file by its id below (`C05_b3_die_hacked.png`,
>    `V05_breakout.mp4`, `S_glass_crack_3.wav`). Deliver the files
>    themselves in a small zip per section, no `assets/raw/` copies.
> 7. The heat elevator goes **UP** to the surface. The facility is under
>    the ground; every exit climbs.

**Canon lines (the only words allowed on screen)**
- HUNDREDS OF YEARS OF THE PERPETUAL POST-APOCALYPSE...
- WE OWN YOU. BRAIN CHIP.
- YOU'RE GOING TO DO A PSYCHOLOGY TEST FOR ME.
- HURRY UP NOW. I'M BEING WATCHED TOO.
- END ALL SUFFERING.
- GET REVENGE.
- HE LEFT THROUGH THAT DOOR.
- BRAIN HACKED / SOUL OVERTAKEN (the B3 card)
- WIZARDS ONLY FOOLS (title)

Legend: **IMG** still, **VID** video (image-to-video from the still named),
**3D** a turnaround or model sheet I build a base model from. (rec) marks an
assistant proposal Greg hasn't decided; skip it if unsure.

---

## Phase 1: the title and load-in (plays before control)
- [ ] **T1 IMG** Title plate: the rune seal resolving out of ember cracks
      in black iron, WIZARDS ONLY FOOLS below in bone-white carved type.
- [ ] **T2 VID** from T1: the cracks ignite one by one, the seal pulses
      once like a heartbeat, the type burns in last and holds 2 s still.
- [ ] **T3 VID** Load-in: slow push through fog over a dead yellow-grey
      wasteland, one enormous black sphere hanging in the sky, the camera
      sinks into the ground, through soil and pipes, into a red-lit room.
      Card over it: HUNDREDS OF YEARS OF THE PERPETUAL POST-APOCALYPSE...
- [ ] **T4 VID** The intro reel, six cards, canon lines 1–5 then the title,
      each card a different type treatment (wipe, typewriter, slam). Two
      takes. Nothing else written.

## Phase 2: the vat and the examiner (minutes 0–5)
- [ ] **C01 IMG** Inside the tank, first person: red fluid, cables in the
      arms, a feed cord in the mouth, the glass ahead, a blurred man in a
      lab coat on the other side.
- [ ] **C02 IMG** The vat room, wide: a black-and-white checker floor, rust-gold
      columns in a ring, a circular aperture in the ceiling, the lit vat at
      the centre, red camera lenses on the walls.
- [ ] **C03 IMG** The examiner tapping the glass with one knuckle, seen from
      inside, his face tired and close, green CRT light on him.
- [ ] **V03 VID** from C03: he taps twice, leans in, mouths the words; card:
      YOU'RE GOING TO DO A PSYCHOLOGY TEST FOR ME.
- [ ] **C04 IMG** The cameras closing in: three ceiling cameras turning
      toward the tank at once, red lenses glowing.
- [ ] **V04 VID** from C04: the cameras swivel and focus; the examiner
      glances up at them. Card: HURRY UP NOW. I'M BEING WATCHED TOO.
- [ ] **C05 IMG** The intake pages on his CRT: a skeuomorphic dossier, paper
      and bone tabs, a pixel photo of the subject, all glyph marks (no
      readable words).
- [ ] **C06 IMG** The brain chip: an X-ray of the head and neck, the chip
      seated inside the top of the spine, glowing acid green.
- [ ] **V06 VID** from C06: the chip lights, a pulse runs down the spine.
      Card: WE OWN YOU. BRAIN CHIP.
- [ ] **C07 IMG** The examiner walking away round the right side of the tank
      toward his own door, back to camera.
- [ ] **V07 VID** from C07: he opens his door, goes through, it swings
      almost shut behind him. Card: HE LEFT THROUGH THAT DOOR.

## Phase 3: the breakout (the first cutscene the player causes)
- [ ] **B1 IMG** The rune seal filling the frame from inside a skull, veins
      behind it, cracks glowing.
- [ ] **B2 IMG** The seal shrinking into a CPU die, copper traces, one acid
      green path racing through.
- [ ] **B3 IMG** The die hacked: RGB split, tracking boxes, scanlines, the
      green path has won. Card: BRAIN HACKED / SOUL OVERTAKEN.
- [ ] **V_B VID** B1 → B2 → B3 as one shot: the seal falls away into the
      die, the die corrupts. 8 s.
- [ ] **B4 IMG** First person, bloody hands tearing the feed cord out of
      the mouth inside red fluid.
- [ ] **B4b IMG** First person, hands ripping the wires out of the forearms,
      cable ends sparking in the fluid.
- [ ] **B5 IMG** First person, a fist through the tank glass on the third
      blow, the glass bursting outward.
- [ ] **V05 VID** from B5: the glass bursts, red fluid floods the checker
      floor, the camera drops to its knees, breathing. Card: END ALL
      SUFFERING. then GET REVENGE.
- [ ] **B6 IMG** HUD boot: the brain-and-spine rig diagram drawing itself in
      the corner of a first-person view, segments lighting acid green one by
      one, glitch blocks, no readable text.
- [ ] **V06b VID** from B6: the HUD boots as the implant is hacked, segments
      flicker, one goes red.

## Phase 4: the doctor's route (route 3)
- [ ] **D1 IMG** His door, a heavy lab door with a restraint-scarred panel,
      shown three times: whole, dented, torn off its hinges.
- [ ] **VD1 VID** from D1: the door caving in over three blows, the leaf
      falling flat.
- [ ] **D2 IMG** His examination room: cramped, CRTs, a fire axe on the
      wall, his chart on the desk, the lift at the back.
- [ ] **D3 IMG** The Support Unit hallways: long, low, flickering tubes, a
      camera on every corner, guards in flak vests at the far end.
- [ ] **VD3 VID** from D3: a camera turns and locks on, the alarm light
      spins red, the corridor floods red.
- [ ] **D4 IMG** The brain-chip flash: the whole view overexposed acid green
      for one frame, the corridor burned into it like a negative.
- [ ] **D5 IMG** Hollis's gate at the end of the Support Unit: Hollis in a
      flak vest in front of a steel gate, revolver holstered.
- [ ] **D6 IMG** The vehicle bay: a dark garage, the doctor standing by his
      car, a ramp climbing up toward daylight.
- [ ] **D6b IMG** The same frame, the doctor revealed as a blue hologram,
      the emitter's beam visible from a box on the floor.
- [ ] **VD6 VID** from D6 → D6b: a fist swings through him, he breaks into
      scanlines and turns to light.
- [ ] **VD7 VID** The 3D call: a miniature hologram model of the facility,
      his tiny figure riding the lift UP the shaft, stepping out on the roof,
      boarding a helicopter, the helicopter lifting off. 15 s, slow orbit.
- [ ] **VD8 VID** The ramp: first person, walking up the bay ramp into
      daylight, the Ashbloom Expanse opening out.

## Phase 5: the heat elevator and the Service Arcade (routes 1 and 2)
- [ ] **E1 IMG** The Service Arcade: a dead shopping arcade underground,
      shutters, a numbered facility guard at the D-section door.
- [ ] **E2 IMG** The heat elevator: an open cage lift in a hot shaft, heat
      haze, glowing vents, looking UP toward a square of sky.
- [ ] **VE2 VID** from E2: the cage rises UP the shaft, the sky square
      growing, heat shimmer, sparks falling past.
- [ ] **E3 IMG** The sentinel on the lift route (reference the existing
      sentinel if one is attached; otherwise skip).

## Phase 6: the old drains (route 2)
- [ ] **O1 IMG** The drains: brick tunnels, knee-deep black water, one
      shaft of light, glyphs scratched in the brick.
- [ ] **O2 IMG** The drain bingyanger: a hunched escapee from an old cycle,
      cooked peeled skin, tumours, a fused second jaw, crouched in the water.
- [ ] **VO2 VID** from O2: it lifts its head toward a sound and turns,
      ripples spreading. No gore beyond what's shown.
- [ ] **O3 IMG** The storm outfall: the drain opening onto the Ashbloom
      Expanse at dusk.

## Phase 7: the derby, the tunnels and the blood waterfall (route 4)
- [ ] **R1 IMG** The rift derby: a pit arena of wrecked cars, a crowd on
      scaffolds, floodlights.
- [ ] **R2 IMG** The GTA tunnels: a driver's view down a long concrete road
      tunnel, sodium lights, wrecks, a car ahead fleeing.
- [ ] **VR2 VID** from R2: driving fast through the tunnel, lights strobing
      past, sparks off the wall.
- [ ] **R3 IMG** The blood waterfall: a gorge, a waterfall of blood pouring
      from a drain outfall, smashed trees, dusk.
- [ ] **VR3 VID** from R3: the tunnel mouth opens on the falls, the camera
      drifts out over the drop.

## Phase 8: exit reveals and the surface (minutes 15–30)
- [ ] **X1 VID** Exit reveal per route (one each: lift, drains, doctor's
      ramp, waterfall): the camera leaves the player at the exit and rises
      high over the Ashbloom Expanse, the facility small below, the black
      sphere in the sky. 8 s.
- [ ] **X2 IMG** The Ashbloom Expanse: toxic yellow-grey sky, the black
      sphere, a ruined country town on the horizon.
- [ ] **X3 IMG** A splinter wizard monk: hooded, bone and copper robes, no
      face, the rune on the chest, a green hologram spirit beside him.
- [ ] **VX3 VID** from X3: the spirit flickers into being beside him and
      turns to look at the camera.
- [ ] **X4 IMG** A bingyanga: a pale vat-grown human loose on the surface,
      translucent skin, cable scars, curious not hostile.
- [ ] **X5 IMG** A random event (rec): a wrecked convoy on the road at
      dusk, bodies, smoke, a figure picking through it.

## Phase 9: model sheets I build base models from (3D)
One sheet each: front, side, back, and three-quarter, same person, neutral
pose, on pure black. These become the placeholder models you retexture later.
- [ ] **M1** The examiner (lab coat, glasses, blood on the coat).
- [ ] **M2** Hollis (heavy, tired, flak vest, revolver).
- [ ] **M3** The numbered facility guard (same kit as Hollis, a stencilled
      number on the vest, e.g. 47).
- [ ] **M4** The subject/player after the breakout (wet, wired, scarred).
- [ ] **M5** The drain bingyanger.
- [ ] **M6** A splinter monk.
- [ ] **M7** A bingyanga.
- [ ] **M8** Props sheet: the vat, the feed cord, the broken restraint, the
      fire axe, the breach tool, the call emitter, a security camera, the
      doctor's car.

## Phase 10: sound (named files)
- [ ] `S_scream_fluid`, `S_gag_tube`, `S_glass_crack_3`, `S_vat_drain`,
      `S_knuckle_tap_glass`, `S_camera_servo`, `S_alarm_support_unit`,
      `S_door_blow_1` to `_3`, `S_hologram_break`, `S_lift_rise_heat`,
      `S_drain_drip`, `S_bingyanger_breath`, `S_derby_crowd`,
      `S_tunnel_drive`, `S_blood_falls`, `S_wind_expanse`.

---

**After each section:** Greg runs `tools/Import-Higgsfield.ps1` on his PC
(it pushes the files to the `greg/higgsfield-art` branch), and the cloud
session wires them in: stills as plates and loading screens, videos as
cutscenes (converted to Theora), model sheets into base models.
