# The checklist

The working document. The design has outrun the build, so this is how the build
catches up: **in segments, one at a time, slowly and surely.**

## The goal

Greg: *"until it's sharper and sharper so that you can play the game."* That is
the measure, and it is a better one than any feature count — every segment below
is judged on whether it moves the build toward something you can sit down and
play, not toward something that demos well.

So the list carries a second reading. **Critical path to a playable loop**, in
order, ignoring everything else:

| Order | Segment | Why it is on the path |
| --- | --- | --- |
| 1 | ~~**A7.1–A7.3**~~ `DONE` | Driving is the first thing the player does and it does not feel like driving. Everything in the derby is downstream of this. |
| 2 | ~~**A5.1–A5.3**~~ `DONE` | You cannot read your own state mid-heat. |
| 3 | ~~**C1.1–C1.2**~~ `DONE` | Six panels on six keys is the reason nothing connects. |
| 4 | ~~**B6.2–B6.3**~~ `DONE` | A fight that continues after a limb comes off is the combat identity. |
| 5 | ~~**F1.1–F1.2**~~ `DONE` | Witnesses are the cheapest step that makes the world remember. |
| 6 | ~~**D1.1–D2.2**~~ `DONE` | A character sheet, so a run is *yours*. |
| 7 | **G6.1–G6.3** | The opening carries the first ten minutes. |

Everything else is depth on top of that spine. When those seven are checked, the
game is playable end to end and the rest is making it good.

## How to drive this

**Say a segment id and I build that segment.** `B5.2`. `A7.1`. That is the whole
protocol. Nothing else needs to be typed.

- Say a bare item id (`B5`) and I take its next unchecked segment.
- Say `next` and I take the next unchecked segment in the section we are in.
- Say `B` and I work down that whole section in order, checking off as I go.

Segments are sized to be one sitting each: a thing that runs, is verified, gets
captured if it is visual, and is committed on its own. If a segment turns out to
be bigger than that when I open it, I split it and say so rather than sprawling.

`[x]` plus strikethrough is built and verified. `[~]` is partially there with
the rest named underneath. `[ ]` is not started. The strikethrough is visual
progress, not deletion: completed work remains readable and searchable.

**v2 convention:** when everything here is checked, the whole document gets
reworked from scratch against what the game actually is at that point, rather
than patched. This is v1.

Last rebuilt 2026-09-11.

---

## A — The visual pass

The systems outgrew the interface. Shortest distance between "tutorial project"
and "a game".

### A1 — Display typeface `BUILT`
- [x] ~~**A1.1** Stroke/stencil alphabet drawn in code, no font to licence~~
- [x] ~~**A1.2** Applied to headers and numerals across the index~~
- [x] ~~**A1.3** Derby HUD, map, kill cam and interstitial. Warning card keeps a real font for its body copy by design~~
- [x] ~~**A1.4** A second cut of the face — condensed, for tight columns~~
- [x] ~~**A1.5** Worn/smudged variant that degrades with the panel (pairs with I4)~~

### A2 — World Index UI `BUILT`
- [x] ~~**A2.1** Framed plate: notched corners, fixings, tape, dead pixels, scanlines~~
- [x] ~~**A2.2** Real dossier — stats, condition, installed hardware, memory~~
- [x] ~~**A2.3** The Tree axis, computed all along and never once shown~~
- [x] ~~**A2.4** KNOWN EDGES — the relation graph grudges propagate along~~
- [x] ~~**A2.5** Regrimed to Fallout/biopunk, cyan removed at the constant level~~
- [x] ~~**A2.6** Rail scrolls — more than ~12 subjects currently runs off the plate~~
- [x] ~~**A2.7** Search and filter, because the design says the index is incomplete *and* searchable~~
- [x] ~~**A2.8** Entries that are wrong on purpose, per §13~~

### A3 — Rank pyramid `BUILT`
- [x] ~~**A3.1** Tiers from real command strength, not a template~~
- [x] ~~**A3.2** Buy-in, downline, OPPORTUNITY on an empty post~~
- [x] ~~**A3.3** Who is actually positioned to take a vacancy~~
- [x] ~~**A3.4** Spinning 3D head per occupied tier~~
- [x] ~~**A3.5** Click a tier member to jump to their file~~
- [x] ~~**A3.6** Push the MLM register harder — recruitment pitch copy, testimonials, a rank you can *buy*~~
- [x] ~~**A3.7** Show the edges between tiers: who recruited whom~~

### A4 — Wire page `BUILT`
- [x] ~~**A4.1** Accounts derived from real subjects, reach that is not combat skill~~
- [x] ~~**A4.2** Whether they will read you, and why — routes, leverage, being hated~~
- [x] ~~**A4.3** Your own exposure and the trace that comes back~~
- [x] ~~**A4.4** The feed, interleaving real world history with the hostile register~~
- [x] ~~**A4.5** Actually send a DM from the panel (the sim supports it; the UI does not)~~
- [x] ~~**A4.6** Expose / fabricate / trace / swarm as buttons with their costs shown~~
- [x] ~~**A4.7** Infinite scroll that actually farms you (I6)~~

### A5 — Derby HUD corners
- [x] ~~**A5.1** Hull integrity off the default font and onto the plate vocabulary~~
- [x] ~~**A5.2** Hunt signal — the one you singled out — rebuilt~~
- [x] ~~**A5.3** Damage bust and contact radar in the same language~~
- [x] ~~**A5.4** Grunge pass: the HUD is a cab instrument, so it is filthy~~
- [x] ~~**A5.5** Cut visible prose by ~60%, per the Tier 1b note~~

### A6 — Living Map as an object `BUILT`
- [x] ~~**A6.1** Salvaged bezel — pipes, rust plate, screws — around the chart~~
- [x] ~~**A6.2** Named discovered places with a description panel~~
- [x] ~~**A6.3** Location-based travel~~
- [x] ~~**A6.4** Cracked-screen occlusion over unsurveyed ground~~
- [x] ~~**A6.5** 2D-to-tilted-3D zoom~~

### A7 — Derby driving model `BUILT`
**This was the actual cause of "the derby map is broken".** The venue was
re-authored twice against the complaint and measured worse both times — the
clue that the arena was never the problem. Confirmed: the car is a car now.
- [x] ~~**A7.1** Per-wheel raycast suspension replacing the single-body servo~~
- [x] ~~**A7.2** Load transfer — weight moves under brake, throttle and steering~~
- [x] ~~**A7.3** Real contact patches and per-wheel grip~~
- [x] ~~**A7.4** Decide the upright angular lock: does a derby car roll?~~
- [x] ~~**A7.5** Retune the AI against the new model (it was tuned against the old one)~~
- [x] ~~**A7.6** Speed-linked camera shake and FOV~~

### A9 — The radio `BUILT`
Greg, 2026-09-11: an Oxenfree-style **tunable** radio in the Fallout register —
seamless, in-world, and the dial is a real instrument rather than a track
selector. Signals found on it start quests, which surface in the index.

This earns its place rather than being a music player, for two reasons already
in the design. Coverage is a **property of place** (`DESIGN/IN_GAME_INTERNET.md`
gates the Wire the same way), so a station you can only receive standing in one
valley is a location. And the Wire already needs a second transmission channel
for grudges and rumour that is slower and less reliable than the feed — a
half-tuned broadcast is exactly that.
- [x] ~~**A9.1** A tunable dial with real static between stations~~
- [x] ~~**A9.2** Bowls cut hard (the quarry rim), buildings scatter, and the dial names the obstruction~~
- [x] ~~**A9.3** Numbers stations and half-signals that resolve into a quest hook~~
- [x] ~~**A9.4** Hooks surface in the index rather than as a popup~~
- [x] ~~**A9.5** A real bus: the band narrows, the drive climbs, the room opens and the carrier rises~~
- [x] ~~**A9.6** The radio carries Wire news late and wrong, per the distortion rules~~

### A8 — Seamless panel open/close
- [x] ~~**A8.1** Page-to-page transitions ease and wipe~~
- [x] ~~**A8.2** Opening and closing the index itself still pops~~
- [x] ~~**A8.3** Row selection redraws instantly instead of settling~~
- [x] ~~**A8.4** One shared transition helper so nothing new cuts by default~~

---

## B — Make the body the centrepiece

The most complete system in the project and, until this pass, the least visible.

### B0 — Spinning head icons `BUILT`
- [x] ~~**B0.1** Real head mesh and real skull mesh per subject~~
- [x] ~~**B0.2** X-ray state shows the actual anatomy, not a filter~~
- [x] ~~**B0.3** Tinted by Tree alignment, spin seeded per name~~
- [x] ~~**B0.4** Head damage shows on the icon — missing eye, broken jaw~~
- [x] ~~**B0.5** Icons on the FILE rail as well as the pyramid~~

### B1 — Clickable 3D organs `BUILT`
- [x] ~~**B1.1** Part viewer with real meshes from the rig's own tables~~
- [x] ~~**B1.2** Lift-out from the diagram with a thread back to it, never a modal~~
- [x] ~~**B1.3** Condition darkens the part itself, not just the caption~~
- [x] ~~**B1.4** Hover to preview, click to pin — currently click-only~~
- [x] ~~**B1.5** Authored organ silhouettes: lung lobes, liver wedge, gut coil, instead of spheres with attachments~~
- [x] ~~**B1.6** Wet pass — subsurface and slick specular, so organs read as meat rather than plastic~~
- [x] ~~**B1.7** Drag to rotate and scroll to zoom, instead of a fixed spin~~
- [x] ~~**B1.8** Damage on the mesh: a ruptured organ is torn, not only darker~~

### B2 — Limbs and cybernetics, one verb `BUILT`
- [x] ~~**B2.1** Flesh, bone, organs and hardware in one list, inspected identically~~
- [x] ~~**B2.2** **Implants become real parts with a real zone** — kills the keyword table that currently guesses where hardware sits~~
- [x] ~~**B2.3** Implant condition tracked, so "NO TELEMETRY" becomes a number~~
- [x] ~~**B2.4** Authored implant meshes per catalogue entry~~
- [x] ~~**B2.5** Wounds carry a zone at authoring time — kills the second keyword table~~
- [x] ~~**B2.6** Compare view: your part against theirs, which is the robbing decision~~

### B3 — The X-ray cursor `BUILT`
- [x] ~~**B3.1** Brass ring, real button, skull mark, key and click through one path~~
- [x] ~~**B3.2** Empty seats drawn, so it reads as the unfinished tool it is~~
- [x] ~~**B3.3** Works in the world, not only inside the index~~
- [x] ~~**B3.4** X-ray actually sees through world geometry and bodies at range~~
- [x] ~~**B3.5** Own the pointer — hide the OS cursor~~
- [x] ~~**B3.6** Hold to expand into the full radial (this is where B3 becomes C2)~~

### B4 — Chunk physics and layers `BUILT`
- [x] ~~**B4.1** Identified chunks: layer, zone, subject, organ, implant~~
- [x] ~~**B4.2** Depth from damage, damage type and how open the zone already was~~
- [x] ~~**B4.3** Bodies remember how far they have been opened~~
- [x] ~~**B4.4** Cap, recycle, `take()`, `from_subject()`~~
- [x] ~~**B4.5** **Layer exposure on the zone mesh itself** — skin, then fat, then muscle, then bone, visible on the body~~
- [x] ~~**B4.6** Chunks mark the ground where they land and where they roll~~
- [x] ~~**B4.7** Authored chunk meshes instead of primitives~~
- [x] ~~**B4.8** Per-layer impact sound — bone does not land like fat~~
- [x] ~~**B4.9** Rot over time: flies, discolouration, smell as a gameplay signal~~

### B5 — Rob cybernetics off a body `BUILT`
**Unblocked by B4** — `GoreChunks.take()` already returns the identified part.
- [x] ~~**B5.1** Interact with a downed or dead body to open the extraction view~~
- [x] ~~**B5.2** Extraction requires reaching the right layer — you have to dig~~
- [x] ~~**B5.3** The tool matters: bare hands, blade, or something surgical~~
- [x] ~~**B5.4** Extracted part enters CARRY with its condition and its lien~~
- [x] ~~**B5.5** Install a robbed part into yourself~~
- [x] ~~**B5.6** Someone notices — the Choir price it, the owner remembers~~

### B6 — Dismemberment as a combat verb
- [x] ~~**B6.1** Severing exists on the rig with thrown limbs, stumps and exposed bone, driven by the strike direction~~
- [x] ~~**B6.2** Sever from a directional blow crossing a limb threshold *mid-fight*~~
- [x] ~~**B6.3** The fight continues with them still in it, fighting worse~~
- [x] ~~**B6.4** The severed limb is a chunk: pick it up, carry it, sell it, hit someone with it~~
- [x] ~~**B6.5** Reciprocity — the player is dismembered and keeps playing~~
- [x] ~~**B6.6** Stump behaviour: bleed rate, one-armed movement and attacks~~

---

## C — The handheld, and killing the six-panel problem

Six fullscreen panels on six keys is the root cause of "nothing connects".

### C1 — Device shell `BUILT`
- [x] ~~**C1.1** One handheld object with modes, raised as a physical action~~
- [x] ~~**C1.2** INDEX / MAP / TREE / WIRE / CARRY folded into it~~
- [x] ~~**C1.3** The world keeps running while it is up — reading is a risk~~
- [x] ~~**C1.4** Seamless raise and lower, not a visibility toggle~~
- [x] ~~**C1.5** Hardware condition damages the interface itself~~

### C2 — Radial selection `BUILT`
- [x] ~~**C2.1** Expand B3's ring into a full radial~~
- [x] ~~**C2.2** Weapons, cybernetics, modes and seals on one input grammar~~
- [x] ~~**C2.3** **Seamless time dilation while open** — Prototype/GTA register~~
- [x] ~~**C2.4** The slowdown must not soften the fight; difficulty stays soulslike~~
- [x] ~~**C2.5** Custom cursor art~~

### C3 — Camera mode `BUILT`
- [x] ~~**C3.1** Raise a camera, frame the world, take a photograph~~
- [x] ~~**C3.2** Photographs are objects with contents that can be inspected~~
- [x] ~~**C3.3** Verify what is in frame against real anatomy state (required by E3)~~
- [x] ~~**C3.4** Photographs post to the Wire~~

### C4 — CARRY `BUILT`
- [x] ~~**C4.1** Surface the inventory subject that already exists~~
- [x] ~~**C4.2** Chunks, organs and hardware carried as identified objects~~
- [x] ~~**C4.3** Weight, spoilage and what a body will hold~~

### C5 — Physical connectivity `BUILT`
- [x] ~~**C5.1** Masts extend coverage; caves have none~~
- [x] ~~**C5.2** Terminals as fixed access points~~
- [x] ~~**C5.3** The underbelly needs a physical terminal, not a menu toggle~~
- [x] ~~**C5.4** Cracked screen eats regions of the interface~~

---

## D — Character creation in the vat

**Races are D4.** Full design in `DESIGN/CHARACTER_CREATION.md`. Also fixes the
under-directed opening.

### D1 — The sheet `BUILT`
- [x] ~~**D1.1** A real player subject built from data, not a hardcoded dict~~
- [x] ~~**D1.2** Everything below writes into it~~
- [x] ~~**D1.3** Save and load it~~

### D2 — Traits and point budget `BUILT`
- [x] ~~**D2.1** Point budget: positives cost, negatives refund~~
- [x] ~~**D2.2** The eight authored traits, each hooking a system that exists~~
- [x] ~~**D2.3** CLERICAL ERROR — part of your sheet is wrong and you are not told which~~

### D3 — The intake scene `BUILT`
- [x] ~~**D3.1** Handler, clipboard, tube in your mouth so you cannot speak~~
- [x] ~~**D3.2** Blink and twitch to answer~~
- [x] ~~**D3.3** He writes down what he thinks you said~~
- [x] ~~**D3.4** Pacing, camera and delivery (this is also G6)~~

### D4 — Races `BUILT`
- [x] ~~**D4.1** Six races as data: Decanted, Soft Rot, Marrow-Cut, Roadborn, Unreset, Lantern-Born~~
- [x] ~~**D4.2** Build factor is on the sheet, and the rig reads it~~
- [x] ~~**D4.3** Metabolism — what heals you, what poisons you~~
- [x] ~~**D4.4** Social price: how each faction reads you~~
- [x] ~~**D4.5** Baseline Tree pull per race~~

### D5 — The chart route `BUILT`
- [x] ~~**D5.1** Elements to attributes, modality to a commitment axis~~
- [x] ~~**D5.2** Ascendant sets starting Wire reach~~
- [x] ~~**D5.3** Ruling House as the Skyrim-standing-stone blessing~~
- [~] **D5.4** Derived wheel shipped and honest about it. Ephemeris still the open call

### D6 — The instrument route `BUILT`
- [x] ~~**D6.1** Original items on real axes — five-factor plus dark triad~~
- [x] ~~**D6.2** Scoring that congratulates you on the wrong things~~
- [x] ~~**D6.3** Output drives real stats, so honesty has consequences~~

### D7 — The mirror `BUILT`
- [x] ~~**D7.1** Sliders on a swing-arm mirror over the tank~~
- [x] ~~**D7.2** The preview lies, because you are under goo~~
- [x] ~~**D7.3** Under-skin editing: skeleton, organ set, blood type, grown-in hardware~~

### D8 — Opt-in modifiers `BUILT`
- [x] ~~**D8.1** Neural lace, mast tithe, full schedule as intake checkboxes~~
- [x] ~~**D8.2** Each one actually works — and each one is also a handle on you~~
- [x] ~~**D8.3** Short authored cutscene per choice~~
- [x] ~~**D8.4** Declining them is the harder difficulty~~

---

## E — The two ladders

Full design in `DESIGN/RITUAL_AND_KARMA.md`. All of it hangs off the
Ascent/Descent axis that already exists and is currently unused.

### E1 — Karma from real events
- [x] ~~**E1.1** The axis accumulates from recorded history~~
- [x] **E1.2** Factions price you by where you sit
- [ ] **E1.3** Never a good/evil slider — read through the Tree view

### E2 — The ritual app
- [ ] **E2.1** Seal-drawing vocabulary in the `celloutz_type` stroke register
- [ ] **E2.2** The 72 Goetic seals as data
- [ ] **E2.3** Original seals for what this world grew on its own
- [ ] **E2.4** Seals animate, corrupt and burn

### E3 — Camera rituals
- [ ] **E3.1** Ritual definitions: what must be done, what must be photographed
- [ ] **E3.2** Verify the photograph against real anatomy (needs C3.3)
- [ ] **E3.3** Rituals are playable, never a confirm button

### E4 — Temporary boosts, real costs
- [ ] **E4.1** Boosts are always temporary
- [ ] **E4.2** Paid in blood, organs, limbs or standing
- [ ] **E4.3** Escalating price on repeat

### E5 — Ascent entities
- [ ] **E5.1** Entities as subjects on the nemesis machinery, not a shop
- [ ] **E5.2** Wash away sins for positive quests
- [ ] **E5.3** The long route: climbing lets the game continue

### E6 — Drugs
- [ ] **E6.1** Substances with real body cost through the anatomy component
- [ ] **E6.2** Preparation and consumption minigames
- [ ] **E6.3** The door to the entity layer
- [ ] **E6.4** Production and sale economy

### E7 — Route endings
- [ ] **E7.1** Become a demon; the soul is signed over
- [ ] **E7.2** Climb far enough and keep playing
- [ ] **E7.3** Both endings written into world history

---

## F — The Hunt System becoming a system

Today Mara is one hardcoded character. `DESIGN/HUNT_SYSTEM.md` has six
mechanisms and almost none are built.

### F1 — Witness records `BUILT`
- [x] ~~**F1.1** Events record witnesses~~
- [x] ~~**F1.2** An unwitnessed act never enters faction knowledge~~
- [x] ~~**F1.3** Kill the witness before they report~~

### F2 — Grudges travel real edges
- [x] ~~**F2.1** Propagation along the relation graph the index already draws~~
- [x] ~~**F2.2** Decay with distance~~
- [x] ~~**F2.3** Distortion on each retelling~~
- [x] ~~**F2.4** The Wire as a second, faster, less reliable carrier~~

### F3 — Promotion into real vacancies
- [ ] **F3.1** A death opens a real post (the pyramid already shows this)
- [ ] **F3.2** The successor is someone who already existed
- [ ] **F3.3** Rank weighs influence and debt, not combat skill

### F4 — Rivals generated from real events
- [ ] **F4.1** Rivals born out of what happened, not authored
- [ ] **F4.2** Tactic adaptation — adopt LimboAI, currently unused
- [ ] **F4.3** The wound as the memory

### F5 — Player defeat routed to shackled
- [ ] **F5.1** Losing is not a reload
- [ ] **F5.2** Shackled, conscripted or stamped by whoever won
- [ ] **F5.3** Deliberate death: forfeit loot, re-decant out of the tar

### F6 — Mind-stamp and the asset list
- [ ] **F6.1** Non-consensual recruitment through the handheld
- [ ] **F6.2** Assets listed, taskable, remotely executable

### F7 — The clinch as a social verb
**Highest value per line of code in the whole list** — four systems that already
exist start talking to each other.
- [x] ~~**F7.1** Hold-and-negotiate state out of the existing clinch~~
- [x] ~~**F7.2** Rob, abuse or persuade from inside the hold~~
- [x] ~~**F7.3** Feeds the downed-window resolution and recruitment~~

---

## G — The look

Not code. The difference between "programmer art" and "a game".

### G1 — Greg's art as texture source
**Unblocked 2026-09-12.** Source: `Desktop/Art Collections`, 43 artworks.
Read-only; everything derived lands in `game/art/derived/` via `tools/art_pipeline.py`.
- [x] ~~**G1.1** Locate and catalogue the source art~~
- [x] ~~**G1.2** Cut, glitch and shade into a texture set~~
- [x] **G1.3** Body textures — on flesh materials as a detail layer over the contamination
- [x] **G1.4** Map plates and interface surfaces — under the World Index plate
- [x] **G1.5** Wire collage — printed under the Wire feed

### G2 — The cars
- [ ] **G2.1** Stripped chassis with exposed mechanism
- [ ] **G2.2** Bone and sinew lashings
- [ ] **G2.3** Fungal bloom in the wheel wells, dried spatter
- [ ] **G2.4** Re-export carrying the biopunk palette natively

### G0 — The wreckers cannot land a hit `OPEN BUG`
Found 2026-09-12 by measurement, not yet fixed. A parked player finishes a
thirty-second heat on **full hull** across seven consecutive runs. What the
probe actually says, so the next attempt does not start from scratch:

- Cars in the open reach **12-14 m/s**, so this is not a speed or throttle
  problem. Throttle on the car nearest the player sits at 0.72, which is
  `closing * aggression` committing, not a floor.
- The nearest wrecker never closes below **4.0-4.6 m** and mostly orbits at
  5-6 m. Contact needs roughly 4.0 m centre to centre, so they are barely
  touching, and `IMPACT_SPEED` is 4.0 m/s of *normal* closing — a car sliding
  past tangentially at 6 m/s contributes almost none of it.
- Two hypotheses were tried and measured wrong. Widening `GRIND_RANGE` to 5.4
  made it worse (they peel off at 4.6-6.6 m, before ever touching). Reducing the
  steering gain from 2.2 to 1.15 was a real fix for permanent cornering and is
  kept, but did not by itself produce impacts.

- [ ] **G0.1** Make a hunter's final approach a committed straight run rather
      than an orbit — the gap it is steering toward is never zero
- [ ] **G0.2** Re-check `IMPACT_SPEED` against the rebuilt chassis; 4.0 m/s of
      normal closing may simply be unreachable now
- [ ] **G0.3** Assert impacts fire, not just that hull drops, so this cannot
      regress silently again

### G3 — The derby arena
- [ ] **G3.1** Re-author the oval for a larger footprint
- [ ] **G3.2** Retune the engagement cap against it together
- [ ] **G3.3** Contamination colour through authored surfaces, not light

### G4 — Silhouettes
- [x] ~~**G4.1** Bevels and broken corners on generated geometry~~
- [x] ~~**G4.2** Greebles and attached junk~~
- [x] ~~**G4.3** Leaning and settling, so nothing is plumb~~

### G5 — Sound rework
- [~] **G5.1** Bus structure built and mixable (Master/Music/SFX/Ambience); routing still to do
- [ ] **G5.2** Engine layered by load rather than one pitched sine
- [ ] **G5.3** Impact layers by severity and material
- [ ] **G5.4** Per-layer gore sound (shares with B4.8)

### G6 — The opening, directed
- [x] ~~**G6.1** Pacing and camera~~
- [x] ~~**G6.2** Sound design~~
- [x] ~~**G6.3** The handler's delivery (pairs with D3)~~

---

## K — The cosmology
Captured 2026-09-12, see `DESIGN/COSMOLOGY.md`. CellOutz is the demon faction
below, wizardsonlyfoolz the mage collective above, the player a CellOut wizard
half of each, hunting upward to force a hearing. The Four Horsemen rotate as
CellOutz leadership. Both poles are already in `FACTION_TREE_AXIS`.

### K1 — The two poles
- [x] **K1.1** CellOutz and wizardsonlyfoolz on the Tree axis as the real ends
- [ ] **K1.2** CellOutz written through the existing branding as deliberate, not coincidence
- [ ] **K1.3** wizardsonlyfoolz given a presence — ranks, a Law, a Book, paid grades

### K2 — The Four Horsemen
- [ ] **K2.1** Four named subjects on the nemesis machinery, not health bars in rooms
- [ ] **K2.2** Rotating succession: killing the one in power promotes the next (pairs with F3)
- [ ] **K2.3** Who holds the post changes what CellOutz does, not just the name
- [ ] **K2.4** The Horseman in power is what makes a run different (answers the roguelike question)

### K4 — The hierarchy below
Four tiers, all on existing machinery. See `DESIGN/COSMOLOGY.md`.
- [ ] **K4.1** The Seven Deadly Sins as princes over the factions that embody them
- [ ] **K4.2** Pride, Lust and Sloth need factions — four Sins already have one
- [ ] **K4.3** Lesser demons roaming, generated by F4.1 rather than authored
- [ ] **K4.4** A Sin holds *signal*, not a keep — channels taken by argument, hijack or cut
- [ ] **K4.5** Killing a Sin changes what its faction is about, because the principle drives its axis and pricing

### K3 — The player as half of each
- [ ] **K3.1** Decide whether both ladders can be climbed at once or committing closes one
- [ ] **K3.2** The opening reframed: CellOutz grew you, which is why the debt is in the meat
- [ ] **K3.3** Getting God's attention as the actual win condition, written into world history

## H — Base building, reduced

Your own call: Valheim's building is a pillar built by five people over years,
and a shallow version is worse than none.

### H1 — Claim a camp
- [ ] **H1.1** Take a place and it is yours
- [ ] **H1.2** Recruits from the downed window live there
- [ ] **H1.3** Investment changes what it produces and who it attracts

### H2 — It can be taken off you
- [ ] **H2.1** Raids against a claimed place
- [ ] **H2.2** Losing it is written into world history

---

## I — The interface as its own medium

From `DESIGN/INTERFACE_DIRECTION.md`.

### I0 — No screen is a list of text in a box
The standing rule. If a screen's information could be a spreadsheet, it is not
finished. Applies to everything below and to A5, A6, C1.
- [x] ~~**I0.1** Applied to the World Index~~
- [ ] **I0.2** Applied to the derby HUD — rejected 2026-09-12, see below
- [x] **I0.5** The handheld becomes a black cracked mirror you look *into*, jester on the back
- [ ] **I0.6** Kill the HUNT SIGNAL corner plate — a rival arrives when they change, not permanently
- [ ] **I0.7** Hull read off the car, not off a number in a corner
- [ ] **I0.8** The weapon well reworked
- [ ] **I0.9** Cast display names reworked — ids stay, names change (blocked on Greg's list)
- [ ] **I0.3** Applied to the map
- [ ] **I0.4** Applied to the handheld

### I1 — Code as a material
- [x] **I1.1** Character rain carrying the game's own vocabulary
- [x] **I1.2** Degrades where the body degrades
- [x] **I1.3** Used as a surface things are cut out of, not a backdrop

### I2 — The web is many worlds
- [x] **I2.1** Broken-web primitives: tiled ground, marquee, counter, guestbook, webring, banner farm, popup
- [x] **I2.2** Per-site authored layouts, no two alike
- [x] **I2.3** Sites as locations — reachable from one terminal, and nowhere else
- [x] **I2.4** Dead sites: last post four years old, moderator deceased

### I3 — celloutz.xyz in-game
**Blocked: mirror the real content, or fictionalise it?**
- [ ] **I3.1** Decide the approach
- [ ] **I3.2** Build the site as a reachable place on the Wire

### I4 — Panels degrade with the player
- [x] **I4.1** Blood loss, pain, consciousness and Wire strain drive the UI
- [x] **I4.2** A bleeding player's index is harder to read
- [x] **I4.3** Diegetic, never a post-process filter

### I5 — Everything clickable and inspectable
- [x] ~~**I5.1** Body parts~~
- [x] **I5.2** Wounds and implants from the dossier
- [x] **I5.3** People, factions and ranks
- [x] **I5.4** Posts and accounts

### I6 — The honest split on dark patterns
- [x] **I6.1** The Wire is deliberately hostile — infinite scroll, bait, variable reward
- [x] **I6.2** The player's own tools are the opposite
- [x] **I6.3** Make the contrast obvious enough to read as a joke

---

## J — Infrastructure

Unglamorous, and each one is currently costing real time.

### J1 — Drop FMOD properly
- [x] ~~**J1.1** Extension disabled locally; headless tests run again~~
- [x] ~~**J1.2** Written up in `ROADMAP.md`, since `.gitignore` stops the fix travelling~~
- [ ] **J1.3** Remove the plugin outright — 238MB referenced by no script

### J2 — Debug affordances out of the shipping build
- [ ] **J2.1** Reset keys off the shipping input map
- [ ] **J2.2** Dev-only gate for the rest

### J3 — Adopt the installed plugins
- [ ] **J3.1** LimboAI for F4.2
- [ ] **J3.2** Terrain3D + Proton Scatter for the Ashbloom exterior
- [ ] **J3.3** Dialogue Manager when NPCs first speak

### J4 — Real loading behind the interstitial
- [ ] **J4.1** Stream behind the plate instead of a fixed 1.45s hold
- [ ] **J4.2** Progress bar that is telling the truth

---

## Open questions — only you can answer these

They block nothing else, but they change what gets built.

1. **Where is the art folder?** Blocks G1 entirely — the largest available
   upgrade to the look.
2. **celloutz.xyz — mirror or fictionalise?** Blocks I3.
3. **Ephemeris or derived wheel?** "Most accurate" charts need real planetary
   longitudes from a table. Affects D5.4.
4. **Guns: common, or scarce and improvised?** Changes encounter design either
   way. Built but undecided.
5. **What persists between runs?** Roguelike structure was asked for, but
   "bodies remember" is a pillar. These pull against each other.
6. **Does the chassis roll?** Affects A7.4.
7. ~~**How is the dark web gated?**~~ **Answered and built** — `signal_field.gd`
   gates it on physically standing at a terminal. Reversible by changing one
   table; the two terminals are in the Ossuary Works and the Communion.
8. **Working title:** keep *Allusions to Grandeur*, or move toward Greg's new
   candidate **wizardsonlyfoolz**? Recorded as a candidate only; no project,
   executable or save-data identifiers change until Greg makes the call.
