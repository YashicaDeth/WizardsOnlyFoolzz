# TouchDesigner → the game: the materia pipeline

For Greg. Your words, 5 Oct 23:10: *"making the drug pass VFX and game
mechanics, smoking physics, and then using TouchDesigner to make interesting
drug sequences."* The background is `DESIGN/FINAL_V.md` §16 and "Connecting
TouchDesigner and Blender".

**The short version.** TouchDesigner cannot run inside the shipped game. It is
where you **design** a look and **bake** the textures that look needs. The
game runs the look itself, every frame, in one shader
(`game/shaders/psychedelic.gdshader`) with 22 dials. While you work, TD can turn
those dials live over OSC and you see the game change.

```
 TouchDesigner (your lab, never ships)          The game (ships)
 ───────────────────────────────────            ─────────────────────────────
 sliders / LFOs / Audio Analysis CHOP ──OSC──►  psychedelic.gdshader dials (live, dev only)
 Ramp TOP  ─────── bake PNG ──────────────────► art/materia/lut_<palette>.png
 Noise TOP ─────── bake PNG ──────────────────► art/materia/flow.png
 any TOP chain ─── image sequence ─ pack ─────► art/materia/trip_flipbook.png + .json
```

---

## 1. Seeing it live (about five minutes)

1. Start the mechanics lab: `Start-MechanicsLab.ps1`.
2. Walk to station 7, **MATERIA** (or Start / Tab opens the station menu: pick MATERIA).
3. At the plinth, D-pad left/right (keyboard: the `heal` / `inspect` keys) to
   **TOUCHDESIGNER OSC LINK (DEV)**, then USE. The lab line reads
   `OSC LISTENING ON 9000`. USE again turns it off. It is **off by default**,
   and an exported build refuses to open the port at all.
4. In TouchDesigner, open the Textport (Alt+T), paste in
   `tools/touchdesigner/build_psy_dials.py` and press Enter. It builds
   `/project1/wizards_dials`: a Constant CHOP called `dials` with one channel
   per dial, wired to an OSC Out CHOP aimed at `127.0.0.1:9000`.
5. Drag a value. The game changes.

While the link is on, TD has the wheel: the substance curves stop writing the
dials, so nothing fights your sliders. Turning it off puts the screen back to
rest.

No TouchDesigner to hand? `python tools/psy_dials.py lut_strength=0.6
kaleidoscope_segments=6` sends the same messages from the command line, and
`python tools/psy_dials.py materia=deliriant` shows a class preset.

### The OSC addresses

One message per channel, one float. **The dial is the last part of the
address**, so `/psy/darkness`, `/darkness` and `/anything/darkness` all set
`darkness`. On the OSC Out CHOP use "one message per channel" (that is what
makes the channel name the address). Names the game does not know are
ignored, never a crash.

| Address | Rest | Range | What it does |
| --- | --- | --- | --- |
| `/psy/lut_strength` | 0 | 0 to 1 | How much of the palette LUT replaces the picture's colour |
| `/psy/palette_cycle` | 0 | -0.5 to 0.5 | Palette cycling speed (LUT turns per second) |
| `/psy/kaleidoscope_segments` | 0 | 0, then 2 to 24 | Mirror wedges. Below 2 the fold is off |
| `/psy/kaleidoscope_spin` | 0 | -3.2 to 3.2 | Rotation of the fold, radians per second |
| `/psy/kaleidoscope_clear` | 0 | 0 to 1.5 | Radius of the middle left unfolded, so you can still see what you aim at |
| `/psy/mirror_fold` | 0 | 0 to 1 | Left-right mirror, softer than the kaleidoscope |
| `/psy/feedback_strength` | 0 | 0 to 1 | Trails: how much of the last frame shows through |
| `/psy/feedback_zoom` | 1 | 0.9 to 1.1 | Above 1 the trails stream outward (tunnel), below 1 inward |
| `/psy/feedback_spin` | 0 | -0.5 to 0.5 | Trails twist, radians per second |
| `/psy/chromatic_offset` | 0 | 0 to 0.05 | Red and blue pulled apart, as a fraction of the screen |
| `/psy/displacement_strength` | 0 | 0 to 0.3 | Warp: how far the flow texture pushes the picture |
| `/psy/displacement_scroll` | 0.3 | -2 to 2 | How fast the flow texture moves |
| `/psy/melt_strength` | 0 | 0 to 0.2 | Melt: columns of the picture slide down at their own rates |
| `/psy/pulse_strength` | 0 | 0 to 1 | How hard each beat breathes the frame in and lifts it |
| `/psy/beat_level` | 0 | 0 to 1 | The beat itself (from your Audio Analysis CHOP while the link is on) |
| `/psy/cut_intensity` | 0 | 0 to 1 | Hard cuts to a flat colour on the beat |
| `/psy/cut_rate` | 8 | 0.5 to 30 | Cuts per second |
| `/psy/cut_seed` | 0 | 0 to 64 | Which sequence of cut colours |
| `/psy/saturation_shift` | 0 | -1 to 1 | Colour drained (negative) or pushed (positive) |
| `/psy/darkness` | 0 | 0 to 1 | A vignette that eats inward and crushes what it leaves |
| `/psy/tunnel` | 0 | 0 to 1 | The frame shrinks to a window with nothing outside it |
| `/psy/edge_figures` | 0 | 0 to 1 | Standing figures at the edge of vision. Deliriant only |

Two extra messages for the materia station:

| Address | Arguments | Does |
| --- | --- | --- |
| `/materia/preset` | class (string), level (float, optional, default 1) | Shows a class at that point of its curve: `stimulant`, `cannabinoid`, `psychedelic`, `dissociative`, `deliriant`, `empathogen`, `depressant`, `opioid`, `new_world` |
| `/materia/lut` | file path (string) | Loads a LUT PNG from disk straight onto the screen, so you can try a bake before saving it into the game |

---

## 2. Each effect: the TD graph and the matching dial

Build the look in TD with the graph on the left. When it is right, read the
numbers off and they are the dial values on the right. Each graph starts from
a `Movie File In TOP` holding a screenshot of the game (any capture under
`P:/GameDev/Temp/drug70c/` will do), so you are designing over the real
picture.

Operator and parameter names below are from TouchDesigner's documentation and
were **not checked against an installed TD** (there is none on the build
machine). If one is spelled differently in your version, the dial on the right
is still the contract.

### Palette cycling: Lookup TOP
```
Movie File In TOP ─┬────────────────────────► Lookup TOP (input 1) ─► Cross TOP ◄─ (original)
                   │  Ramp TOP (256 x 1) ───► Lookup TOP (input 2)        │
                   │   └ Transform TOP (Translate X animated, Extend: Repeat)
                   └────────────────────────────────────────────────────┘
```
- Lookup TOP indexed by luminance = what the shader does (dark end of the
  ramp on the left). If your version only indexes by a channel, put a
  `Monochrome TOP` before input 1.
- Cross TOP's Cross value → `lut_strength`.
- The Transform TOP's Translate X speed (in ramp widths per second) →
  `palette_cycle`.
- The ramp itself is the palette: bake it (section 3).

### Kaleidoscope and mirror: Kaleidoscope TOP
```
Movie File In TOP ─► Kaleidoscope TOP ─► Null TOP
```
- Segments (number of mirror wedges) → `kaleidoscope_segments`.
- Rotate speed → `kaleidoscope_spin` (TD rotates in degrees: divide by 57.3).
- If your build has no Kaleidoscope TOP, use a GLSL TOP with the six lines
  from `psychedelic.gdshader` (search "Fold the frame"). The left-right mirror
  (`mirror_fold` = 1) is the left half of the picture beside a `Flip TOP`
  (Flip X) copy of it.
- The clear middle has no TD operator: in TD, a `Circle TOP` used as the
  mask on a `Matte TOP` between the folded and unfolded picture shows it. The
  circle's radius (as a fraction of half the screen height) → `kaleidoscope_clear`.

### Trails and infinite zoom: Feedback TOP
```
Movie File In TOP ─► Composite TOP (Operation: Maximum) ─► Null TOP ─┐
                          ▲                                           │
     Level TOP (Opacity) ◄─ Transform TOP (Scale, Rotate) ◄─ Feedback TOP (Target TOP = the Null)
```
- Use **Maximum**, not Over or Add. The shader uses `max`: a trail is an
  afterimage that shows where the new frame is darker, and never ratchets to
  white or washes to grey.
- Level TOP Opacity → `feedback_strength`.
- Transform Scale (uniform) → `feedback_zoom` (1.02 = 2% outward per frame).
- Transform Rotate per second, in radians → `feedback_spin`.
- In the game this is a real feedback loop: a SubViewport that samples its own
  previous frame (`systems/psychedelic_rig.gd`).

### Chromatic separation: Displace TOP, or three Transforms
```
Movie File In TOP ─┬─ Transform TOP (Scale 1+k) ─► Reorder TOP: R from here ─┐
                   ├─────────────────────────────► Reorder TOP: G from here ─┼─► Reorder TOP ─► Null
                   └─ Transform TOP (Scale 1-k) ─► Reorder TOP: B from here ─┘
```
- The shader pulls red and blue apart in opposite directions along the line
  from the centre of the screen. `k` above, as a fraction of the screen, →
  `chromatic_offset`.
- A `Displace TOP` fed a radial `Ramp TOP` does the same in one node if you
  prefer; its Displace Weight is `chromatic_offset`.

### Warp and melt: Noise TOP into Displace TOP
```
Noise TOP (animated: Translate Z or T) ─► Displace TOP (input 2)
Movie File In TOP ─────────────────────► Displace TOP (input 1) ─► Null
```
- Displace Weight → `displacement_strength`.
- Noise TOP Translate speed → `displacement_scroll`.
- The Noise TOP is the flow texture: bake it (section 3) and the game uses
  your exact noise.
- Melt: a Noise TOP stretched tall (Period Y huge) gives vertical bands; used
  only in Y on the Displace TOP it is `melt_strength`.

### The beat: Audio Analysis CHOP
```
Audio Device In CHOP (or Audio File In) ─► Audio Analysis CHOP ─► Select CHOP (kick / low)
   ─► Lag CHOP (attack 0, release 0.15) ─► Rename CHOP (to beat_level) ─► Merge into the OSC Out CHOP
```
- The channel named `beat_level` drives the pulse live. Set `pulse_strength`
  to how hard each beat hits.
- In play the game makes its own beat from its own sound
  (`systems/audio_reactive.gd` on the Master bus), with a heartbeat when the
  room is silent, so a preset never needs TD to pulse.

### Cuts, darkness, tunnel, figures
These are the game's own and have no single TD operator. Drive them from
sliders: `cut_intensity`, `cut_rate`, `darkness`, `tunnel`, `edge_figures`.
They are what the dissociative, deliriant and opioid presets mostly use.

---

## 3. Baking into the game

Everything goes in **`game/art/materia/`**. Every file is optional: with none
present the game uses what it makes itself. The game loads them through
`systems/materia_bakes.gd`.

| File | Make it with | Replaces |
| --- | --- | --- |
| `lut_<palette>.png` | Ramp TOP, 256 x 1, dark on the left | that palette's generated gradient |
| `flow.png` | Noise TOP, 512 x 512, seamless | the warp/melt noise |
| `trip_flipbook.png` + `.json` | any TOP chain, as an image sequence, then packed | Greg's plate under the trip |

To write a file from TD: put a `Movie File Out TOP` after the TOP, Type:
**Image**, File Type: **PNG**, file name as below, then press **Add Frame**
once.

### LUTs
- Palette names (in `systems/materia.gd`, `PALETTES`): `prism` (the bright one;
  psychedelic and the trip), `warm` (empathogen), `ash` (deliriant), `cold`
  (dissociative), `sodium` (stimulant), `smoke` (cannabinoid), `lead`
  (depressant), `honey` (opioid), `wire` (new-world).
- Save as `game/art/materia/lut_ash.png` and so on. The game reads the middle
  row, left = darkest picture, right = brightest.
- **The deliriant's palette must stay dark.** `materia_test` reads a baked
  `lut_ash.png` too and fails if any of it is brighter than about a third.
  Deliriants are horror, never fun (THE_BRAIN §4).
- Try one first without saving it into the game: send
  `/materia/lut P:/path/to/test.png` while the link is on.

### Flow / noise
- Noise TOP, 512 x 512, Monochrome **off**, so R and G differ (they are the
  two directions of the push). Mid-grey (0.5) is still.
- It has to tile. Check with a `Tile TOP` at 2 x 2. If you see seams, make
  it a 2 x 2 of itself flipped (original, Flip X, Flip Y, both), scaled back
  to 512: mirrored noise always tiles.
- Save as `game/art/materia/flow.png`.

### A flipbook (frames for the trip)
1. Build the sequence in TD. Movie File Out TOP, Type: **Image Sequence**,
   PNG, into a folder under `P:/GameDev/Temp/`, and record.
2. Pack it:
   `python tools/touchdesigner/pack_flipbook.py P:/GameDev/Temp/<folder> --fps 12`
   (`--cell 640x360` sets the frame size in the atlas, `--once` holds the last
   frame instead of looping). It writes `trip_flipbook.png` and
   `trip_flipbook.json` into `game/art/materia/`.
3. Open the Godot editor once so it imports the PNG, and in the Import dock set
   Compress → Mode to **VRAM Compressed**. A 64-frame 640 x 360 atlas is about
   60 MB uncompressed in video memory and about 15 MB compressed.
4. Keep loops short: 2 to 6 seconds at 12 fps is the budget. Long passages are
   better made from several short loops with the live dials changing over
   them than from one long bake.

---

## 4. A baked sequence as a trip

The example trip is at the materia station (TRIP SEQUENCE, 40 s, USE skips at
any moment). It is `game/lab/stations/materia_trip.gd`:

- **The ground layer** is your plate `art/derived/plate/covermeinmoss.png`, or
  the flipbook if `trip_flipbook.png` exists. It plays at its own fps under
  the shader.
- **The live layer** is the same shader with a dial track keyed by time
  (`KEYS` in that file): calm, then colour, then the fold, then trails and
  warp over the ground, then the melt, then a short turn into the dark
  register, then rest. The world keeps running under it, so turning your head
  mid-fold is part of it.
- How much of the ground shows at each key is the `plate` value (0 to 1) in
  `KEYS`. For a sequence that is all bake, set it to 1 throughout.

To make a new one: design the look live (section 1), write the dial values
you settled on down at each moment, and those become a new `KEYS` list. An
agent can turn a list of "at 12 s: these dials" into the file in minutes.

---

## 5. What does not ship

- The OSC link: development only. The station's dial is off by default, and
  `systems/osc_bridge.gd` refuses to open a port in an exported build.
- Spout (sharing a live GPU texture from TD) is not built. It needs a
  GDExtension and would only ever be a preview.
- TouchDesigner itself: nothing from a `.toe` file runs in the game. Only the
  PNGs you bake do.

## 6. Where things are

| What | File |
| --- | --- |
| The shader (22 dials) | `game/shaders/psychedelic.gdshader` |
| The feedback rig, dial list | `game/systems/psychedelic_rig.gd` |
| Classes: presets, curves, tolerance, costs | `game/systems/materia.gd` |
| Baked file loading | `game/systems/materia_bakes.gd` |
| The OSC receiver | `game/systems/osc_bridge.gd` |
| The station and the trip | `game/lab/stations/materia_station.gd`, `materia_trip.gd` |
| TD bench builder | `tools/touchdesigner/build_psy_dials.py` |
| Flipbook packer | `tools/touchdesigner/pack_flipbook.py` |
| Command-line dials | `tools/psy_dials.py` |
