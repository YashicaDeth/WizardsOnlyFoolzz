# The look, taken from the Higgsfield concepts

26 September 2026. Greg: *"you can respond using all of these images as
reconceptualising the current look of the game without making things feel
really AI gen"*, and *"pick the distinct and similar enough ... with a grain
of salt, there's a lot I don't like, but a lot I do like"*.

**The rule this pass kept:** no generated image is drawn in the world. The
concepts were measured, and what the good ones agree on became a limitation
of the game's own screen and a few authored colour choices. The geometry,
textures, lights and people are still the game's own. That is the difference
between looking like the concepts and looking AI-made.

## Which concepts set the look

**Kept, because they agree with each other and with the game** (low-poly
renders, visible texels, a dither screen, black floors, colour held in the
light and the haze):

| Concept | What it set |
|---|---|
| The doctor walking out past the tank (checker floor, rust columns, red haze, open door) | The Growing Floor: dark, red-brown air, colour in the vat glow |
| The red vat renders | The Growing Floor's black point and red balance |
| The concrete hall with two guards | The Support Unit: red-brown concrete, bone highlights |
| The brick drain with scratched glyphs | The old drains: brown brick, khaki-green air, low saturation |
| The bingyanger in the drain water | The drains' haze colour |
| The driver's view down the sodium tunnel | The derby tunnels grade |
| The floodlit derby pit | The derby grade |
| The blood from the outfall pipe | The dry falls grade |
| The ruined town under the black sphere, and the bingyanga on the flats | The surface grade: pale khaki, only 11-12% near black |
| The doctor's green office, the lift shaft looking up | Not wired yet: they agree with the set, and are the next two areas to tune |

**Set aside for the world look** (kept as reference for other jobs, or not at all):

- The photographic grassland: a real photo, not the game.
- The painterly and sculpted renders (the realistic vat subject, the wired
  hands, the kidney MRI, the rune-in-skull, the die on a board): a different
  medium from the in-world renders, and the ones most likely to read as AI.
- The hooded monk with the green spirit: good, but illustration, not an
  in-world render. It is the monk's model reference, not a grade.
- The flat UI pieces (sigils, plates, X-ray diagrams, the dossier, the phone):
  these belong to the interface, which keeps its own crisp print look
  (ART-DIRECTION.md, "UI language").

## What is in the engine now

- **`HouseLook` (autoload) + `shaders/dust_to_bones_look.gdshader`.** A full
  screen pass on a CanvasLayer at -50, below every HUD, so the world is
  graded and text is not. It gives the world:
  - a 2x coarse framebuffer (about 640x360 at 720p);
  - 26 steps per channel with a 4x4 Bayer dither, the dither screen in every
    kept render;
  - a black point, a gamma and exposure, saturation;
  - shadow, mid and highlight colour balance;
  - stepped 12 fps grain and a vignette.
- **Per-area grades** in `house_look.gd`, each noting the concept it was tuned
  against and what that concept measured.
- **`growing_floor` and `old_drains` environment presets** (WorldLook): the vat
  room had been running `ossuary`, a mauve preset at 0.02 fog that measured a
  pastel median of 90/255.
- **Visible texels on the facility's surfaces** (LabSurface: nearest filtering
  with mipmaps), and the walls warmed from green-grey to red-brown concrete.
- **The drain lamps** moved off saturated orange toward sodium-khaki.
- **The security cameras' idle cone** dimmed. It was 0.13 alpha; now it rises
  from 0.07 to 0.23 as a camera locks on, so a camera watching you is still
  loud.

Measured on the game's own captures before and after (median luminance,
fraction of the frame near black, saturation):

| Area | Before | After | Concept |
|---|---|---|---|
| Growing Floor | 79-90 / 0.05 / 0.27 | 18-22 / 0.46-0.56 / 0.46-0.49 | 4-34 / 0.44-0.77 / 0.6 |
| Support Unit | 37 / 0.35 / 0.50 | 13 / 0.61 / 0.53 | 15 / 0.55 / 0.45 |
| Old drains | 19 / 0.51 / 0.97 | 24 / 0.46 / 0.50 | 26 / 0.39 / 0.46 |

`WOF_LOOK=clean` turns the pass off for a session (before/after captures).
`house_look_test` checks it is on, below the HUD, and picks each area's grade.

## Open (Greg)

- How chunky: the pixel size (2 now), and whether the dither should show more
  or less.
- Whether it is a setting the player can turn off.
- The doctor's office and the lift shaft grades, and the surface once played.
