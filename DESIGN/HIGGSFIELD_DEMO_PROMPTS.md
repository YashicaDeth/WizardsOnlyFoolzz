# Higgsfield prompts: the rest of the 30-minute demo

25 September 2026. Greg: "create more prompts i can use on my higgsfield for
the rest of this 30 minute game demo: maps, gore, loading screen gfx, the
phone holding all apps, the internet personas, the pyramid, everything."
And: "use Higgsfield to enhance these, then TouchDesigner gfx to mask all AI
generative imaging to make it purely look like code and effects."

**How to run these**
- Paste the house style from `HIGGSFIELD_PROMPTS.md` in front of each one, or
  use the short version: *"PS2-era low-poly horror, crunchy 512px texels,
  dithering, Silent Hill fog, Cruelty Squad sick colour, dried blood #461009,
  arterial red #a8281a, copper #b0552a, bone #e6d4ac, acid green #b4da48,
  near-black #060b09, occult symbolism, no text, no watermark."*
- End flat art with **"centered, on pure black background, 2048x2048"**, not
  "transparent" (that gives a fake checkerboard).
- One image at a time. Tick the box when kept, and log it in
  `game/art/GENERATED.md`.
- Models: Nano Banana Pro for characters and plates, Soul Location for rooms
  and maps, Seedance for the video loops.

## The code-and-effects mask (every generated image goes through it)
- [ ] Nothing generated is shown raw. In the engine, each image is passed
      through a "code" shader: edge-traced line art, a dither or halftone
      grid, a scanline and RGB split, a feedback smear, and a slow data-mosh.
      It reads as a TouchDesigner patch, not a painting.
- [ ] (rec) Build it as a Godot shader (`generated_mask.gdshader`), so it
      ships in the game and runs live. TouchDesigner is Windows/Mac only and
      can't run in the cloud; if Greg wants, he renders loops in
      TouchDesigner on his PC and they're treated the same way.

## 0. Enhance the five we already have (image-to-image)
Upload the image, then:
- [ ] **Rune:** "sharpen the iron, deeper glowing cracks, thicker blood
      drips, on pure black background"
- [ ] **Metatron / Sri Yantra plates:** "crisper engraved lines, more
      verdigris, a faint red glow in the red element, on pure black
      background"
- [ ] **Skull and ribcage X-rays:** "higher detail bone, clearer bullet
      track and fragments, keep the black background, remove any text"

## 1. Loading screens (one per area, 16:9, 1920x1080)
- [ ] **L1 The vat:** "An anatomical X-ray body floating in a vat, wires in
      the skull, a tube in the mouth, framed by a ring of sigils, black
      background, old medical plate meets occult diagram"
- [ ] **L2 The Growing Floor:** "Rows of failed specimen vats seen from above
      like a circuit board, cables as traces, one vat glowing red, sacred
      geometry overlay"
- [ ] **L3 The Service Arcade:** "Abandoned underground arcade, dead cabinets
      in a row, one screen still lit with a hexagram, a guard's silhouette at
      a pressure gate"
- [ ] **L4 The Lower Works:** "Industrial pit with a fuse box sparking, a
      sentinel robot's red eye in the dark, a freight lift cage, fog"
- [ ] **L5 The old drains:** "Flooded brick drain gallery, a cistern, a thin
      pale stalker figure far off, reflections, green sick light"
- [ ] **L6 The dry falls:** "A dried waterfall of blood and gore down a rock
      gorge, smashed dead trees, a drain outfall above, dusk"
- [ ] **L7 The derby:** "Underground demolition derby pit, wrecked cars,
      floodlights, a crowd behind chain-link, blood on the sand"
- [ ] **L8 The Hunt:** "Ruined country town at 10 am, bone yard, a sparring
      post, streetlights, distant tall figure, overcast"
- [ ] **L9 The Support Unit:** "Cell block corridor, restraint beds,
      bingyanga faces at the cell windows, red alarm light"
- [ ] **L10 Sigil card set (make 6):** Seal of Baal, Tree of Life, Flower
      of Life, natal wheel, septagram, goetic circle. "engraved bone-white
      lines on black, one element in arterial red, 2048x2048"

## 2. Maps (the phone's MAP page and area maps)
- [ ] **M1 Satellite:** "Top-down satellite photo of a rural Australian-style
      country town and bushland, overcast, low-res, surveillance crop marks,
      9:16"
- [ ] **M2 Facility blueprint:** "Architectural blueprint of an underground
      lab complex: vat hall, arcade, lower works, drains, support unit, lift
      shafts; cyanotype lines on black, no text"
- [ ] **M3 Hand-drawn map:** "A torn, blood-stained hand-drawn map of the
      drains on yellowed paper, occult marks at exits, no text"
- [ ] **M4 Depth map:** "Heat-map / depth-scan of a lab room seen from the
      ceiling, false colour, camera cones drawn as triangles"
- [ ] **M5 The dry falls from above:** "Aerial view of a gorge with a dried
      red waterfall, destroyed trees, a track winding out, 16:9"

## 3. Gore (Sniper Elite X-ray and old-internet grime)
- [ ] **G1 Organ set:** heart, lungs, liver, kidneys, spine, brain, stomach.
      "X-ray kill-cam close-up of a human [organ], a bullet's path through it,
      shattered fragments, black background, 2048x2048"
- [ ] **G2 Blade wound set:** "X-ray of a blade entering between two ribs,
      cut tissue, black background"
- [ ] **G3 Blunt set:** "X-ray of a skull fracture from a blunt blow,
      radiating cracks, black background"
- [ ] **G4 Decals (make 8):** "Blood splatter decal, top-down, dark dried
      edges, glossy fresh centre, on pure black background, 1024x1024".
      Variants: spray, pool, drag smear, handprint, drips, arterial arc,
      footprint trail, spatter on tile.
- [ ] **G5 Gibs sheet:** "A sprite sheet of low-poly gore chunks: bone
      shards, meat pieces, an eye, teeth, on black, 2048x2048"
- [ ] **G6 Vat subject:** "A pale failed vat-grown human curled on a wet
      floor, translucent skin, umbilical cables, censored, dim red light"
- [ ] **G7 Kill-cam video (Seedance, from G1):** "slow camera push as the
      bullet enters, bone fragments spray outward in slow motion"

## 4. The phone (the Black Mirror handheld)
- [ ] **P1 The phone itself:** "A scuffed, cracked old smartphone with a thick
      rubber case, rust and dried blood in the seams, poking from a jester
      costume pocket, 3/4 view, on pure black background"
- [ ] **P2 Hand holding it:** "First-person view of a grimy hand holding a
      cracked phone in the dark, screen glow on the fingers, 16:9"
- [ ] **P3 App icons (one sheet):** "A grid of 7 app icons for a horror phone:
      a dossier file (INDEX), a satellite dish (MAP), a spiderweb network
      (WIRE), a radio dial (RADIO), a backpack (CARRY), a ritual candle and
      eye (RITUAL), a tuning fork (FIELD). Pixel-art, 64px style, bone on
      black, one red accent each"
- [ ] **P4 Wallpaper:** "Phone lock-screen wallpaper: the Algiz rune in a
      broken circle, glitching, on black, 9:16"
- [ ] **P5 Screen cracks overlay:** "Cracked phone glass overlay, spiderweb
      cracks from one corner, on pure black background, 9:16"
- [ ] **P6 RADIO page:** "An old radio tuning band, glowing amber needle,
      numbers-station feel, 16:9"
- [ ] **P7 CARRY page:** "Items laid out on a lab tray, top-down: a
      restraint, a key card, a smock, a pistol, a fuse, black background"
- [ ] **P8 RITUAL page:** "Evidence board of an occult ritual: a chalk circle,
      candles, a polaroid, red string, top-down"
- [ ] **P9 Wizard eyes:** "The same street seen through 'wizard eyes': ghostly
      spirits glowing in green, everything else in dark negative"

## 5. The Wire: internet personas (one per person on the Wire)
Each persona gets an avatar and a website banner.
- [ ] **W1 Avatar style:** "A 64x64 pixel-art forum avatar of [who], early
      2000s internet, dithered, bone and red on black"
- [ ] **W2 Personas (Greg fills in who):** the examiner / doctor, Hollis,
      a splinter monk, a scrap trader, a conspiracy poster, a cult
      recruiter, a derby promoter, a bingyanga fan page. Same prompt as W1,
      swapping [who].
- [ ] **W3 Website banners:** "A 468x60 web banner from a 2003 conspiracy
      website, glitter GIF feel, occult eye, no readable text"
- [ ] **W4 Site backgrounds (make 4):** "Tiled early-web background texture:
      [starfield / blood marble / circuit / flesh], seamless, 256x256"
- [ ] **W5 Conspiracy board (canon):** "A wall covered in photos, maps and
      red string, a pyramid at the centre, dim flashlight, 16:9"

## 6. The pyramid (33 tiers, the Nemesis-style army screen)
- [ ] **Y1 The structure:** "A tall double pyramid of 33 stepped stone tiers
      meeting at a narrow waist, tiny human figures on every tier, most
      crowded in the middle, a glowing figure at each tip, black void, 16:9"
- [ ] **Y2 Top tip:** "An enthroned robed figure at the peak of a stepped
      pyramid, gold light, the Algiz rune behind, dark"
- [ ] **Y3 Bottom tip:** "A pit at the inverted base of a pyramid, a
      crowned scum-king on a heap of bones, red light"
- [ ] **Y4 Rank badges (make 33, or 1 sheet of 33):** "Sheet of 33 small
      rank sigils, from gold at the top through bone to rust at the bottom,
      on black"
- [ ] **Y5 Portrait cards:** "A Nemesis-style enemy portrait card: face in
      shadow, scars, a rank sigil, bone frame, on black"

## 7. The areas (concept plates to build from)
- [ ] **A1 The doctor's office:** "A cramped lab office, CRT monitors, a
      hologram projector on the desk, filing cabinets, a blood-stained lab
      coat on a hook, green light"
- [ ] **A2 Vehicle bay and hologram:** "An underground vehicle bay, a sedan
      under a tarp, a flickering blue hologram of a man in a lab coat"
- [ ] **A3 Hollis's post:** "A guard booth by a pressure gate, CCTV monitors,
      a coffee cup, a revolver on the desk"
- [ ] **A4 Heat elevator:** "Looking up a shaft from a rising industrial lift,
      heat shimmer, orange light above"
- [ ] **A5 Surfacing:** "A drain grate opening onto a sunny overgrown field,
      first light after darkness, 10 am"

## 8. Video loops (Seedance, for menus and loading)
- [ ] **V1** From L1: "slow push in, the body twitches, bubbles rise"
- [ ] **V2** From the rune: "the rune pulses like a heartbeat, embers drift"
- [ ] **V3** From Y1: "slow orbit around the pyramid, figures shift"
- [ ] **V4** From M1: "a scan line sweeps the satellite map, a red dot blinks"

## 9. Sound (Seed Audio)
- [ ] Muffled screaming through fluid; a gag forced in; glass cracking three
      times; a vat draining; a phone app click; a radio number station; a
      derby crowd roar; a drain drip echo.
