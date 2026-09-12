# The checklist

The working document. The design has outrun the build, so this is how the build
catches up: **in segments, one at a time, slowly and surely.**

## Versions — how a segment gets better after it is done

Greg, 2026-09-12: *"make it so you can click and change the a1 to a1v2 and its a
new set of things to reimprove upon the mechanics... up to v3 or v10 would be the
go with this work system just recycling and reupgrading code over and over"*.

**A tick is not a finish line, it is a version.** This project has already proved
that: the World Index was marked done three separate times before Hunt Grounds
actually opened the real one, and the combat has been "reworked" in four separate
sessions. Binary done/not-done was lying, and versions are the honest shape.

The convention:

- A segment carries a version: `v1` the first time it works, `v2` after a pass
  that materially improves it, and so on. **v10 is not a target.** Most segments
  will stop at v1 or v2 and that is correct; a high version means a mechanic
  earned repeated attention, not that somebody kept fiddling.
- **A version is never deleted.** Each pass records what it was and why it moved,
  so the history of a mechanic is readable from the segment itself.
- **A new version needs a reason stated in one line.** "Polish" is not a reason.
  "The screen the player actually opens was never the one we rebuilt" is.
- A segment can go up a version without being reopened. Going *down* is not a
  thing; if something breaks, that is a bug, not a version.
- Unbuilt segments have no version. They are not v0 — they are nothing yet.
- **Closing a version opens the next one.** When `vN` is ticked, `vN+1` is
  written before the session ends, with its reason. A mechanic is never finished,
  only current. This is the ratchet Greg asked for: *"when they do a1v2 then
  make a v3 until maybe 10 or 9"*.
- **v9 is the ceiling.** Not because a mechanic cannot improve past it, but
  because a system with no end condition is a treadmill. Anything still earning
  versions at v9 is the best thing in the game and should be left alone.
- **Each version is built on the one before it.** `vN+1` addresses what `vN`
  actually produced or exposed — never a fresh idea that could have been done at
  v1. Greg: *"it improves and can only get made off its own previous v2 versions
  getting better and better."* If a fault existed before `vN`, it belongs at the
  version that introduced it, not bolted onto the newest one. This is what stops
  the ladder becoming a wish list with numbers on it.
- The ratchet has one guard, and it is the whole reason it does not become
  noise: **a version that cannot state a real fault is not written.** If the
  next pass has nothing to fix, the segment stops there and that is a finished
  mechanic, which is allowed.

Written as `v3 —` immediately after the code, with the passes listed under it.

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

### A10 — The map is the world, seen from above
Greg, 2026-09-12: *"make the map an inbuilt satellite transferring from topview
somewhat 3d with showing the maps color and what it looks like, then make it
transferable into streetview and interwebbed into the phone black mirror tool"*.

A6 built a survey **chart** — drawn, stencilled, surveyed by walking. This is the
other thing a map can be: the actual region rendered from above, in its own
colours, so what you are looking at is the world rather than a diagram of it.
The two are not in competition. The chart marks stay; they sit on top of the
image instead of on top of nothing.

The technique already exists in this project — `xray_specimen.gd` renders a live
3D scene into a SubViewport for the loading screen. This is that, pointed down.

- [x] **A10.1** A camera in the player's own world, above the region, rendered into the map
- [x] **A10.2** Its real colours and materials — terrain, contamination pools, roads, building footprints
- [x] **A10.3** Tilts past a threshold as you zoom: top-down to oblique to street
- [x] **A10.4** Street view is the same camera at the bottom of its descent, arriving at 1.68m
- [x] **A10.5** Unwalked ground is grey and fogged, thinning at the edges of where you have been; walking brings the colour in
- [x] **A10.9** The reveal is a gradient — clearness is read from the whole 3x3 neighbourhood, eased so the last of it comes off last
- [x] **A10.6** The chart marks, districts, contacts and title block all still read over the image
- [ ] **A10.7** It lives in the handheld's MAP page, so it is the black mirror looking down
- [x] **A10.8** UPDATE_DISABLED while the map is shut; one frame per open frame otherwise

### A6 — Living Map as an object `BUILT`
- [x] ~~**A6.1** `v2` Salvaged bezel — pipes, rust plate, screws — around the chart~~
  - v1 — a hand-rolled Environment per scene
  - v2 — one WorldLook preset system every scene goes through
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

### A v2 — the second pass
A is sealed, which means the only way it improves now is a stated second pass.
Everything below is a real weakness in what v1 shipped, not polish.

- [ ] **A1.6** `v2` The stencil has no kerning pairs — every letter sits on the grid, so AV and TA gap
- [ ] **A2.9** `v2` One plate for every page; the dossier, the Wire and the pyramid should not be printed on the same substrate
- [ ] **A5.6** `v2` Grunge is seeded per screen and identical every session — it should remember the run it is in
- [ ] **A6.6** `v2` Dead pixels and scanlines are static; a failing panel flickers
- [ ] **A7.7** `v2` Retune the chassis against authored arena geometry once G3.1 lands
- [ ] **A9.7** `v2` Stations have a schedule — the dial is the same at 3am as at noon

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
- [x] ~~**B1.9v2** Organs are authored shapes that never deform — a compressed lung should read as compressed~~

### B2 — Limbs and cybernetics, one verb `BUILT`
- [x] ~~**B2.1** Flesh, bone, organs and hardware in one list, inspected identically~~
- [x] ~~**B2.2** **Implants become real parts with a real zone** — kills the keyword table that currently guesses where hardware sits~~
- [x] ~~**B2.3** Implant condition tracked, so "NO TELEMETRY" becomes a number~~
- [x] ~~**B2.4** Authored implant meshes per catalogue entry~~
- [x] ~~**B2.5** Wounds carry a zone at authoring time — kills the second keyword table~~
- [x] ~~**B2.6** Compare view: your part against theirs, which is the robbing decision~~
- [x] ~~**B2.7v2** Pain is a number with no behaviour of its own: it should change how a body stands before it changes what it can do~~

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
- [x] ~~**B4.10v2** Rot attracts something. Flies were shipped; nothing eats~~
- [x] ~~**B4.11v2** Blood pools persist across a scene change, or they are set dressing~~

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
- [x] ~~**B6.5** `v2` Reciprocity — the player is dismembered and keeps playing~~
  - v1 — losing a limb ends the fight
  - v2 — the fight continues in both directions, and the stump bleeds on everyone's clock
- [x] ~~**B6.6** Stump behaviour: bleed rate, one-armed movement and attacks~~
- [x] ~~**B6.7v2** A fracture is binary. A compound fracture is a different injury and should look it~~
- [x] ~~**B6.8v2** Internal bleeding is indistinguishable from external — the X-ray should be the only way to find it~~
- [~] **B6.9v3** The 33 vertebrae recur as a shared system: segmented trauma, X-ray diagnosis, posture and mobility consequences. Spine damage and X-ray count are built; broader ritual/cosmology recurrence remains open.

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

### C v2 — the second pass
- [ ] **C1.6** `v2` The device is raised at one angle in one hand, every time
- [ ] **C1.7** `v2` It can be dropped, and it can be taken off you
- [x] **C1.8** `v2` Wear accumulates in WorldHistory and only ever goes one way — a cracked screen does not heal
- [x] **C2.6** `v2` F1-F5 reach a page directly; cycling is how you learn the device, not how you use one you know
- [x] **C5.5** `v2` Cracks seeded from the device's own serial, at its real condition rather than a constant 0.85

### C v3 — the third pass
Opened because C1.8, C2.6 and C5.5 closed at v2. Each entry is a fault the v2
work created or exposed, not a wish.

- [ ] **C1.9** `v3` Wear is only visible on the screen you are reading; the device in your hand looks new from the outside
- [ ] **C2.7** `v3` Direct page access exists and nothing ever teaches it — a control nobody discovers is a control nobody has
- [ ] **C5.6** `v3` Cracks are per-device but still radiate from one authored origin; an impact should crack the glass where it landed

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

### D v2 — the second pass
- [ ] **D3.5** `v2` The handler says the same things in the same order every decanting
- [ ] **D4.6** `v2` Race is data the world reads, but the intake does not react to it out loud
- [ ] **D2.4** `v2` CLERICAL ERROR is never discoverable — finding out which part of your sheet is wrong should be possible and should cost something
- [ ] **D7.4** `v2` The mirror lies the same way every time; the lie should fit the body
- [ ] **D8.5** `v2` Declining a modifier is the harder difficulty and the game never acknowledges it

## E — The two ladders

Full design in `DESIGN/RITUAL_AND_KARMA.md`. All of it hangs off the
Ascent/Descent axis that already exists and is currently unused.

### E1 — Karma from real events
- [x] ~~**E1.1** The axis accumulates from recorded history~~
- [x] **E1.2** Factions price you by where you sit
- [x] **E1.3** Never a good/evil slider — read through the Tree view. Audited rather than built: `character_archive.gd`'s `_draw_tree_alignment()` (~line 514) draws `tree_alignment()` only as a marker position between ASCENT/LIMBO/DESCENT labels — no code path in the dossier prints the number itself

### E2 — The ritual app
- [x] ~~**E2.1** Seal-drawing vocabulary in the `celloutz_type` stroke register~~
      `goetic_seals.gd` stayed data-only by design — per the originality
      non-negotiable, the 72-name roster is free public-domain material but
      the historical sigils themselves are not, so this does not reproduce
      Mathers' seals. `seal_strokes(seed)` grows an original one instead: a
      containment ring, seeded spokes each ending in a hook or a loop, and
      chords between ring points the way a pentagram's own construction lines
      cross it — deterministic from one integer, same seed always the same
      mark. `draw_seal` places it; a seal for every Goetic number and every
      original id actually draws something. Verified by `tests/seal_draw_test.gd`
      (6 checks on the geometry itself) and a gallery capture at
      `game/captures/e2_1_seal_gallery.png`.
- [x] **E2.2** The 72 Goetic seals as data — `systems/goetic_seals.gd`'s `GOETIA` const, name/rank/number verified against a primary source rather than transcribed from memory (data only, per non-negotiable 1 — no drawing lives here)
- [x] **E2.3** Original seals for what this world grew on its own — `ORIGINAL`, six seals each tied to a real faction or `AscentEntities` entry already built (Choir of Marrow ×2, Soft Rot, CellOutz, and the two Ascent entities) rather than floating free of anything. Covered by `tests/goetic_seals_test.gd` (23 checks)
- [x] ~~**E2.4** Seals animate, corrupt and burn~~ Three more `celloutz_type.gd`
      draws sharing the same generated strokes: `draw_seal_forming` reveals
      them in construction order (ring, then each spoke, then its chords) for
      a rite being drawn rather than a bar filling; `draw_seal_corrupted`
      reuses `draw_worn`'s segment-and-gap damage on the seal's own strokes;
      `draw_seal_burning` consumes strokes from a seeded front angle outward,
      the strokes still catching drawn ember-bright before they are gone
      rather than merely dimmed. All three in the gallery capture above.
- [x] ~~**E1.3** Never a good/evil slider — read through the Tree view~~

- [x] ~~**E2.2** The 72 Goetic seals as data~~
- [ ] **E2.3** Original seals for what this world grew on its own
- [ ] **E2.4** Seals animate, corrupt and burn

### E3 — Camera rituals
- [x] **E3.1** Ritual definitions: what must be done, what must be photographed — `systems/ritual_app.gd`'s `RITUALS`: three rites (including Greg's own worked example, five gored heads), each keyed to a real seal from `goetic_seals.gd` and paying its reward through `boons.gd` — E2/E3/E4 as the one system `RITUAL_AND_KARMA.md` says they are, not three
- [x] **E3.2** Verify the photograph against real anatomy — reuses the exact `contents: [{severed, ruptured, dead}]` shape `wire_net.gd`'s `publish_photograph()` already verifies, rather than a second evidence system
- [x] **E3.3** Rituals are playable, never a confirm button — `attempt()` takes no path to a reward without a `photo` argument that actually satisfies the requirement. Covered by `tests/ritual_app_test.gd` (13 checks)

### E4 — Temporary boosts, real costs
- [x] **E4.1** Boosts are always temporary — `systems/boons.gd`: `grant()` refuses a zero-or-less duration outright, and `active_boons()` prunes anything past its own duration on every read, so there is no code path that grants a permanent effect
- [x] **E4.2** Paid in blood, organs, limbs or standing — reuses `AnatomyComponent.ORGANS`/`DEFAULT_ZONES` for real defaults rather than inventing numbers, writes into the same `anatomy_state` shape `snapshot()`/`restore()` already use, and refuses rather than driving a ledger below a safety floor
- [x] **E4.3** Escalating price on repeat — each further grant of the same `boon_id` costs `1.4^times_taken` more; retaking one refreshes rather than stacks it. Covered by `tests/boons_test.gd` (16 checks). E2/E6 (rituals/drugs) still need to actually call this — nothing here invents that content

### E5 — Ascent entities
- [x] **E5.1** Entities as subjects on the nemesis machinery, not a shop — `systems/ascent_entities.gd`: The Clear Frequency and The Still Ledger are real subjects under `wizardsonlyfoolz`, and `regard()` draws the same kind of conclusion `RivalRegistry.consider()` draws on the other axis (a pattern in the log, not a scripted appearance), reading recorded mercy instead of harm
- [x] **E5.2** Wash away sins for positive quests — `wash()` is refused until an entity has actually noticed you, then spends that notice on success (a fresh run of mercy earns it again, never bought twice with the same acts). The "quest" standing in for E2/E3/E6 content that does not exist yet is the same one already used elsewhere: a real recorded pattern. `sin_washed` added to `KARMA`/`event_karma()` in `world_history.gd`. Covered by `tests/ascent_entities_test.gd` (13 checks)
- [x] **E5.3** The long route: climbing lets the game continue — `route_endings.gd` (E7.2) is that hand-off, now built: reaching it is named `ascended_continue`, not a terminal state, and nothing in `RouteEndings` ends the game either way

### E6 — Drugs
- [x] **E6.1** Substances with real body cost through the anatomy component — `systems/substances.gd`: Marrow Dust, Choir Bloom and Static Hymn, each an Ashbloom-native thing (ground bone, a fungal graft, dead-mast feedback — non-negotiable 1, nothing renamed off a real drug), paying into the same `anatomy_state` ledger `boons.gd` already pays into
- [ ] **E6.2** Preparation and consumption minigames (UI; not attempted here)

### E8 — Sitting still
Greg, 2026-09-12: *"with the stamina and health a meditation or psychedelic drug
part should be apart of it"*. E6 built the substances — Marrow Dust, Choir Bloom,
Static Hymn, and the door to the entity layer. This is the other half of the same
idea: the thing you do when you have no drugs and no time, which is stop.

The pairing is the point. A substance is fast, costs the body, and can reach the
entity layer. Meditation is slow, costs only time, and reaches further inward
than outward — and doing it anywhere dangerous is the whole risk.

- [ ] **E8.1** Sit down and stop — a held state, not a button that grants a buff
- [ ] **E8.2** It restores stamina faster than standing, and pays down pain rather than health
- [ ] **E8.3** Interrupted is worse than never started — the world does not pause for it
- [ ] **E8.4** Where you sit matters: signal, territory and who is nearby all read
- [ ] **E8.5** Deep enough, it reaches the entity layer the way a door substance does — slower, cheaper, and it cannot be rushed
- [ ] **E8.6** It is the only route that costs the body nothing, which is why it is slow
- [x] **E6.3** The door to the entity layer — a "door" substance calls `AscentEntities.glimpse()`, a real recorded `entity_glimpsed` contact that costs nothing of the entity's attention and cannot be spent on `wash()` — distinct from `regard()`'s earned notice
- [x] **E6.4** Production and sale economy — `carry.gd`'s `take_substance()` carries one the same way a robbed part is carried (same wallet, `sale_value()` now prices `kind: "substance"`, same spoil clock). Covered by `tests/substances_test.gd` (16 checks)

### E7 — Route endings
- [~] **E7.1** Become a demon; the soul is signed over — `systems/route_endings.gd` detects and permanently records crossing the Descent threshold (`-0.85`, near CellOutz's own `-0.95`) from real accumulated karma. What's missing: any actual consequence of having signed away (locking further karma, a title card) — that needs either scene/UI work or an API request into `world_history.gd`'s `_accumulate_karma()`, which is Codex's file
- [~] **E7.2** Climb far enough and keep playing — same file, the Ascent threshold (`0.85`). "Keep playing" specifically is already true by default (nothing here ends the game either way); what's missing is anything that reads `route_ending_recorded` to make the moment felt
- [x] **E7.3** Both endings written into world history — `route_ending_reached` event plus a permanent `route_ending` field, written exactly once (re-checking returns the same answer without re-recording). Covered by `tests/route_endings_test.gd` (9 checks)

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
- [x] ~~**F3.1** A death opens a real post (the pyramid already shows this)~~
- [x] ~~**F3.2** The successor is someone who already existed~~
- [x] ~~**F3.3** Rank weighs influence and debt, not combat skill~~

### F4 — Rivals generated from real events
- [x] ~~**F4.1** Rivals born out of what happened, not authored~~
- [x] **F4.2** Tactic adaptation on LimboAI — a rival who lost an arm inside your reach now stands off at 7.5m
- [x] ~~**F4.3** The wound as the memory~~

### F5 — Player defeat routed to shackled
- [x] ~~**F5.1** Losing is not a reload~~
- [x] ~~**F5.2** Shackled, conscripted or stamped by whoever won~~
- [x] ~~**F5.3** Deliberate death: forfeit loot, re-decant out of the tar~~

### F6 — Mind-stamp and the asset list
- [x] ~~**F6.1** Non-consensual recruitment through the handheld~~
- [x] ~~**F6.2** Assets listed, taskable, remotely executable~~

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
- [x] ~~**G2.1** Stripped chassis with exposed mechanism~~ Procedural: an engine
      block, driveshaft ribs and a cut-away sill hang low and central on the
      chassis (`Silhouette.dress_vehicle`), so the silhouette bares mechanism
      instead of reading as a smooth shell. Verified: `game/captures/g2_derby_cars.png`
- [x] ~~**G2.2** Bone and sinew lashings~~ Bone struts run corner to corner
      across the hull with a darker sinew strap crossing each one. Same capture.
- [~] **G2.3** Fungal bloom in the wheel wells done and verified (same capture).
      Dried spatter is built but currently only applied to the player's own
      car — see the docstring on `Silhouette.dress_vehicle`:
      `tests/derby_balance_test.tscn` measured that adding the spatter patches
      to all twelve AI wreckers reproducibly zeroed every hunter-player impact
      for a full 30s heat, while the identical patches on the parked player
      car, and everything else in this kit on the wreckers, measured clean.
      No collision shape is involved anywhere in the kit, so this was
      reproduced and gated (`include_spatter` on `dress_vehicle`) rather than
      root-caused — worth another agent's time before extending it to wreckers.
- [ ] **G2.4** Re-export carrying the biopunk palette natively. Still needs
      Greg's hands: `regrime()` already remaps the toybox material names in
      `art/scrap_skiff.glb` onto the biopunk palette at load, and the kit
      above adds procedural detail on top, but the base mesh itself (bonnet,
      cabin, panels) is only reachable by re-exporting from
      `art/scrap_skiff_v1/scrap_skiff.blend`.

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

- [x] ~~**G0.1** Make a hunter's final approach a committed straight run rather
      than an orbit — the gap it is steering toward is never zero~~
- [x] ~~**G0.2** Re-check `IMPACT_SPEED` against the rebuilt chassis; 4.0 m/s of
      normal closing may simply be unreachable now~~
- [x] ~~**G0.3** Assert impacts fire, not just that hull drops, so this cannot
      regress silently again~~

### G3 — The derby arena
- [ ] **G3.1** Re-author the oval for a larger footprint — deliberately not
      attempted this pass. `ARENA_SCALE` is already recorded as a dead end at
      2.15 and 2.45 (wreckers drift outward and never engage), and the fix on
      record is real level-design work on the authored bowl, not a code
      change I can respond to based on a balance-test number. Doing it blind
      risks re-breaking the G0 fix that took real measurement to land. Needs
      either Greg's hands on the kit or an explicit go-ahead to reshape it
      procedurally (e.g. a stadium/oval footprint instead of a bigger circle,
      so opposite ends stay close enough to keep engaging).
- [ ] **G3.2** Retune the engagement cap against it together — blocked on G3.1
- [x] ~~**G3.3** Contamination colour through authored surfaces, not light~~
      tint. The eight floodlights alternated orange/green per light, which
      re-tinted whatever stood nearest them on top of whatever colour
      `regrime()`/`WorldLook.surface()` already gave the surface — two
      competing colour sources instead of one. Lights are now a single
      practical warm-white; the pit's colour now comes from the authored
      materials. Verified: `game/captures/g3_lights_neutral.png`, and
      `tests/derby_balance_test.tscn` still 0 failures (lighting only, no
      geometry or physics touched).

### G4 — Silhouettes
- [x] ~~**G4.1** Bevels and broken corners on generated geometry~~
- [x] ~~**G4.2** Greebles and attached junk~~
- [x] ~~**G4.3** Leaning and settling, so nothing is plumb~~

### G5 — Sound rework
- [x] **G5.1** `v2` Bus structure built, mixable, and everything actually routed through it
  - v1 — the four buses built and driven from the settings screen
  - v2 — everything actually routed through them; ensure() repairs a chain that bypasses the mixer
- [x] ~~**G5.2** Engine layered by load rather than one pitched sine~~ A third
      `engine_strain` layer joins the existing low/high pair, gated to only
      exist above 72% effort so redline reads as a distinct band arriving
      rather than a tone blending in continuously. Verified: `tests/audio_test.tscn` (G5.2 section)
- [x] ~~**G5.3** Impact layers by severity and material~~ A shared low-end
      `impact_body` layer stacks on top of the material voice once a hit
      passes 50% intensity, so severity is heard as added weight rather than
      the same one-shot played louder. Verified: `tests/audio_test.tscn` (G5.3 section)
- [x] **G5.4** `v2` Per-layer gore sound — bone cracks, organs burst, cybernetics fault (shares with B4.8)
  - v1 — six layer profiles, one shape with different numbers
  - v2 — a layer is an event: bone cracks, organs burst, cybernetics fault

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
- [x] **K1.2** CellOutz written through the existing branding as deliberate, not coincidence — both poles are now real registered `WorldHistory` subjects (`systems/cosmology_factions.gd`), not just table entries; CellOutz's doctrine and territory state the branding conceit directly ("the brand under every panel you have touched since the vat")
- [x] **K1.3** wizardsonlyfoolz given a presence — ranks, a Law, a Book, paid grades. Founder (Orrin Vail, "the First Frequency" — three official, mutually contradictory biographies published side by side on purpose), Law ("There is no static, only those who have not yet paid to stop hearing it."), and Book (*The Unbroken Transmission*, a pamphlet subscription revised whenever someone senior enough complains) drafted and approved by Greg 2026-09-12. Paid grades use the order's own signal vocabulary (Static → Carrier → Sideband → Harmonic → Clear, `wire_net.gd`'s `rank_label()`) on the exact same buy-in math every Sin already runs — display-only, not a second rank system. `wren_ashby`, paid into Static, gives the pyramid a real headcount. Covered in `tests/cosmology_factions_test.gd` (25 checks total)

### K2 — The Four Horsemen
Named by Greg 2026-09-12 — the traditional four, used directly. Built in
`systems/the_four_horsemen.gd`.
- [x] **K2.1** Four named subjects on the nemesis machinery, not health bars in rooms — War, Famine, Pestilence, Death, each a real `WorldHistory` person under CellOutz with their own grip on a real Sin (War/Ashline, Famine/Black Mile, Pestilence/Soft Rot, Death/Choir of Marrow) rather than a stat block
- [x] **K2.2** Rotating succession: killing the one in power promotes the next (pairs with F3) — deliberately *not* scripted (non-negotiable 2): each Horseman's `loyalty`/`wealth` are real fields, their Sin-grip gives real influence, and `WireNet.promote_successor()`'s existing generic scoring decides who actually takes CROWN. Verified: killing War hands the post to Death, from the numbers alone, not a hardcoded order. Found and fixed along the way: neither `WireNet.promote_successor()` clearing a fallen holder's own `faction_rank`, nor `demon_hierarchy.gd`'s `tier()`, accounted for a dead subject still reading "CROWN" on paper — `current_reign()` and `tier()` now both check status
- [x] **K2.3** Who holds the post changes what CellOutz does, not just the name — `current_doctrine()` reads whoever actually holds CROWN and returns *their* doctrine/threat variant of CellOutz's own "ownership, downward" line, not one static text
- [x] **K2.4** The Horseman in power is what makes a run different (answers the roguelike question) — answered by K2.2/K2.3 together: succession is emergent per run and it actually changes what CellOutz's own doctrine reads as, verified in the same test. Covered by `tests/the_four_horsemen_test.gd` (21 checks)

### K4 — The hierarchy below
Four tiers, all on existing machinery. See `DESIGN/COSMOLOGY.md`.
- [x] **K4.1** The Seven Deadly Sins as princes over the factions that embody them — CellOutz now holds a `command` relation over all seven Sin-factions (the four original plus the three below), so the Horsemen/Sins/Captains tiering is a real relation graph, not prose
- [x] **K4.2** Pride, Lust and Sloth need factions — four Sins already have one. Built: **Vanity Row** (Pride, augment vanity cult), **The Honeyvein** (Lust, intimacy/obligation brokers), **The Long Static** (Sloth, apathy cult holding dead signal), each with a doctrine, territory, a signal `channel`, one named captain, and a `FACTION_TREE_AXIS` entry. Covered by `tests/cosmology_factions_test.gd` (22 checks)
- [x] **K4.3** Lesser demons roaming, generated by F4.1 rather than authored — `systems/demon_hierarchy.gd`'s `is_lesser_demon()`/`lesser_demons()` classify RivalRegistry's existing rivals (any `is_rival` subject with no faction) rather than spawning anything new; also gives K2.2/K4.1 a real read (`tier()` reads whoever actually holds CellOutz's CROWN rank as Leadership and a Sin's own command-edge as its Captain, no name required, so K2 stays unblocked mechanically while the Horsemen's names stay blocked on Greg). Covered by `tests/demon_hierarchy_test.gd` (11 checks)
- [x] **K4.4** A Sin holds *signal*, not a keep — channels taken by argument, hijack or cut. `wire_net.gd`'s `contest_channel()` builds all five `DESIGN/FACTIONS.md` routes against real state: out-publish requires actually out-reaching the channel's own roster (`_channel_reach()`), discredit requires a real trace/expose already on record against one of its people (reuses `act()`'s own evidence, invents no second system), hijack/cut require physical access (`at_terminal`, for whoever wires the world to pass once a player stands at a mast), flood is always available but only ever dents control. Every success writes `signal_control` on the faction and a `channel_contested` event. Covered by `tests/channel_contest_test.gd` (14 checks)
- [x] **K4.5** Killing a Sin changes what its faction is about, because the principle drives its axis and pricing — already true for the original four by construction, and now verified true for the three new ones too (`faction_price_factor` reads any `FACTION_TREE_AXIS` entry generically)

### K3 — The player as half of each
- [~] **K3.1** Decide whether both ladders can be climbed at once or committing closes one — answered by default rather than invented fresh: `route_endings.gd`'s own comment argues both stay climbable right up until one is actually finished, and finishing one then locks (verified: a subject who signs away and later drifts all the way back up on paper still reads as the demon ending). A default worth Greg confirming or overriding, not a closed question
- [x] **K3.2** The opening reframed: CellOutz grew you, which is why the debt is in the meat — one line added to `vat_chamber.gd`'s `BEATS` (a pure clock-driven subtitle list, decoupled from the phase/movement logic it lives beside), landing as the very next beat after "Debt's in the meat, friend": *"CellOutz grew you. CellOutz owns what it grew. Read your own contract sometime."* Verified visually, not assumed: `tests/opening_capture.gd` now also captures this beat (`game/captures/opening_celloutz_reframe.png`, actually opened and read). `tests/opening_direction_test.gd` extended (3 checks) to assert the line exists, names CellOutz, and lands immediately after the debt line rather than buried elsewhere
- [x] **K3.3** Getting God's attention as the actual win condition, written into world history — `RouteEndings.forced_gods_attention()` reads the Ascent ending already built (E7.2) as that moment, per `DESIGN/COSMOLOGY.md`'s own framing, rather than inventing a distinct God entity. Covered by `tests/route_endings_test.gd` (14 checks total)

### K v2 — the second pass
- [x] **K2.5** `v2` The Horsemen exist as subjects with no behaviour of their own — `wire_net.gd`'s `_retaliate()` now also raises whoever actually reigns' own `grudge` (half what the Sin's own captain feels — once removed, still real) whenever any Sin CellOutz commands is contested, reusing `TheFourHorsemen.current_reign()`. The same grudge field the Hunt System already reads, so a Horseman who has accumulated enough of it is exactly as meetable as any other rival. Covered in `tests/the_four_horsemen_test.gd` (2 new checks, 23 total)
- [x] **K4.6** `v2` The Sins are named and placed but do not act on the world — `wire_net.gd`'s `contest_channel()` now retaliates: a successful contest raises the faction's own captain's real `grudge` toward whoever did it, scaled by how much it cost them (flood 4, out-publish 6, discredit 10, hijack 15, cut 20 — a mast cut is remembered harder than an afternoon of flooding). That grudge is not decorative — it is the exact field `RivalRegistry`/F2 propagation already reads, so a Sin acting on the world means a real future rival, not a scripted counter-raid. Only a contest that actually lands retaliates; a refusal does nothing. Covered in `tests/channel_contest_test.gd` (4 new checks, 19 total)
- [ ] **K1.4** `v2` Both poles are real in the ledger and barely felt in the world — a player should know which one they are standing in
- [x] **K3.2** `v2` Nothing yet stops a player climbing both ladders at once — real friction added, distinct from K3.1's answer: the Tree *axis* stays freely reversible until an ending locks it (deliberate), but `wire_net.gd`'s `_build_account()` now halves `reach` once a subject holds genuine command-relation weight (≥20 strength) in a Descent faction **and** in wizardsonlyfoolz *at the same time* — a small toe in the other ladder is not enough to trigger it, only real simultaneous standing on both. Covered in `tests/dual_ladder_test.gd` (3 checks, isolating the penalty by holding total influence constant and only varying the split)
- [x] **K5.1** `v2` Lesser demons are rivals reread; they should eventually want something of their own — `systems/demon_ambition.gd`: a first version, derived from real state rather than an authored personality. A demon with a real, strong grudge (≥15) wants to settle it (a recorded escalation each time it's pursued); otherwise it wants patronage from whichever Sin's `signal_control` is currently *weakest* — tying K5.1 into K4.4/K4.6 as one story (weakening a Sin's channel makes it a target for opportunists, not just a number dropping). Succeeding at patronage actually grants the faction affiliation and graduates them out of `DemonHierarchy.is_lesser_demon()` for good — a demon reread upward by its own pursuit, on the same F3/promote_successor track a captain or even a Horseman already runs on. Covered in `tests/demon_ambition_test.gd` (14 checks)

## L — The Board
The storyline and career as a conspiracy pin board rather than a quest list.
Captured 2026-09-12, see `DESIGN/THE_BOARD.md`. It is the third record: the
world holds what happened, each faction holds what it believes, and the Board
holds what the *player* thinks — which is allowed to be wrong.

### L1 — The surface
- [x] **L1.1** `v2` Corkboard, pinned cards, string, pan and zoom
  - v1 — the wall read out of WorldHistory, populated automatically
  - v2 — the player pins it themselves; only the theories and one card are pre-placed
- [x] **L1.2** Populated from WorldHistory — people, factions and events; posts and parts pending L2
- [x] **L1.3** Made rather than rendered: tape, stains, marker, torn edges, pin holes
- [x] **L1.4** Legible from across the room as a shape, up close as cards

### L2 — Pinning
- [x] **L2.1** The player pins what they choose, from the index, the camera and CARRY
- [x] **L2.2** Photographs from `field_camera.gd` pin with their verifiable contents
- [x] **L2.3** Nothing auto-pins except the first card

### L3 — Strings are claims
- [x] **L3.1** Draw a connection between two pinned things
- [x] **L3.2** A string the world supports becomes a lead and opens work
- [x] **L3.3** A false string looks exactly as convincing as a true one
- [x] **L3.4** The board never marks it — what a lead *leads to* lands with L5

### L4 — Publishing a theory
- [x] **L4.1** A theory goes to the Wire through `expose` / `fabricate`
- [x] **L4.2** True published = discrediting; false published = fabrication, and it costs
- [x] **L4.3** Being wrong has a price — the first screen where it does

### L6 — Theories, mainlines and endings
- [x] **L6.1** The board ships with authored theories already pinned, contradictory and unmarked
- [x] **L6.2** A mainline theory followed far enough is an ending; E7's two routes are the first two
- [x] ~~**L6.3** Sidelines are their own clusters, not smaller mainlines —
      some connect to two~~ `leads()` (L3.2) has recorded every supported
      string since the first pass, but nothing ever read them as anything —
      each lead was its own isolated pair with no way to tell "a sideline in
      its own right" from "a weak attempt at a mainline". `sideline_clusters()`
      groups the lead graph by simple union-find: a cluster is whichever
      theory ids one of its own nodes happens to be strung to, so a cluster
      touching none is a pure side story, one is a lead feeding a single
      mainline, and — the case named directly — a cluster genuinely strung
      into two different mainlines reads as connecting to both rather than
      being forced into one. No new content invented; this reads the graph
      that stringing already built.
- [x] **L6.4** Pre-placed theories read differently based on what the player actually did
- [x] ~~**L6.5** Different people, places and factions per route — no
      converging on one dungeon~~ Audited rather than reworked, because the
      five mainlines already held this: `THEORIES`' `supported_by`
      vocabularies never share a token (so no single piece of evidence
      satisfies two mainlines at once), no two of `ROUTES`' final stages
      close on the same event type (so no one act ends two routes together),
      and `LIVING_MAP.DISTRICTS` names five distinct places for the
      `map_travel`-gated stages to happen in rather than one. Verified by a
      real test rather than left as read-the-code: `tests/sideline_cluster_test.gd`.
- [x] **L6.6** No quest state anywhere: what you are "on" is read out of WorldHistory

### L5 — Career
- [x] **L5.1** Routes across the board are the progression
- [x] **L5.2** No quest list exists anywhere in the game

### L v2 — the second pass
- [x] ~~**L1.5** `v2` Strings pass straight through cards rather than round
      them, so a crowded wall reads as scribble~~ `_thread_detour()` checks
      the straight line against every pinned card (theories excluded — they
      are large, central and every route already runs a string into one on
      purpose) and bows the thread away from whichever one it would have cut
      through worst. Geometric only, never consults `supports()`, so L3.3
      still holds: a wrong connection detours around the same furniture a
      right one does.
- [x] ~~**L2.6** `v2` Nothing limits pinning, so the wall can never fill up —
      and a wall that cannot fill up has no cost to using~~ `MAX_PINNED` (40,
      on top of the five theories) is a real cap now; `pin()` refuses past it
      and sets `last_refusal` to a real line for whatever UI shows it.
- [x] ~~**L3.5** `v2` A string you drew and later disproved stays exactly as
      convincing; there is no way to look back and see which claims were
      wrong~~ Narrower than L3.3, which stays intact: a string is only ever
      marked once the theory it holds up was actually *published* and came
      back a fabrication — a recorded outcome the player has legitimately
      learned in play, not the board volunteering the truth early. Drawn
      chalked-grey with a strike mark rather than removed, because the wall
      does not erase your own bad calls.
- [x] ~~**L4.4** `v2` A published theory cannot be amended or withdrawn, which
      makes publishing a one-way door rather than a position~~ `retract()`
      pulls a theory back off the record at a real cost (2 exposure, 6
      grudge on whoever it named, through the same Wire object `publish()`
      already uses) so it can be re-published later — walking back a public
      claim now costs something instead of being structurally impossible.
- [x] ~~**L1.6** `v2` The board never ages. Paper yellows, pins rust, and a
      wall you have not touched in a week should say so~~ `neglect` reads the
      gap in `WorldHistory.events.size()` since the last time the board was
      opened (via `amend_subject`, deliberately not `update_subject` —
      visiting your own wall is not news the world recorded, and logging it
      as an event would inflate the count the next visit measures against)
      and drives a yellowing wash across the whole wall plus a pin tint that
      shifts toward rust. Verified: `tests/pin_board_v2_test.gd` (15 checks
      across all five), plus `pin_test.gd` and `board_capture.gd` unaffected.

## G7 — Exposure at the spawn

Measured 2026-09-12 while chasing two near-black captures of Hunt Grounds.
Camera, lights and environment all check out — the active camera is the player's,
ten lights are present, the sun is at 1.4 and ambient at 0.72 — and the screen
shader is not to blame either: average frame brightness is 0.134 with
`HUD/ScreenTreatment` on and 0.148 with it off, a 9% difference. The Expanse is
simply that dark from where the player spawns.

That is a look decision rather than a bug, which is why it is filed here instead
of under M, but 0.13 average is dark enough that structures a few metres away
read as black shapes rather than as buildings.

- [ ] **G7.1** Decide whether the spawn is meant to be this dark, or raise it
- [ ] **G7.2** If it stays dark, the near field still has to read — contrast, not brightness
- [ ] **G7.3** Check the same numbers at the districts and at the derby, not only at spawn

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
- [x] ~~**I0.1** `v3` Applied to the World Index~~
  - v1 — built as one of six separate panels
  - v2 — dragged out of the box: stencil type, code-rain substrate, pointable links
  - v3 — Hunt Grounds finally opens the real one; the Label it had been opening is deleted
- [x] **I0.2** Applied to the derby HUD — the rejected overlay is gone; the arena is the interface
- [x] **I0.5** The handheld becomes a black cracked mirror you look *into*, jester on the back
- [x] **I0.6** Kill the HUNT SIGNAL corner plate — a rival arrives when they change, not permanently
- [x] **I0.7** Hull read off the car, not off a number in a corner
- [x] **I0.8** The weapon well is a torn recess of gun, chambers and loose rounds — not a label/count row
- [ ] **I0.9** Cast display names reworked — ids stay, names change (blocked on Greg's list)
- [x] **I0.3** `v2` Applied to the map — the key is deleted, marks read by shape, metadata is a title block
  - v1 — a chart with a legend and a header strip, in the system font
  - v2 — the key deleted, marks told apart by shape, metadata moved into a title block
- [x] **I0.4** `v2` Applied to the handheld — CARRY draws what you took as objects in a bag, not rows
  - v1 — name / condition / weight in aligned columns
  - v2 — objects in a bag, sized by mass and tagged with whose they were

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

### I v2 — the second pass
- [x] ~~**I1.4** `v2` The stencil is now used for body copy it was never
      drawn for — long paragraphs in a display face are hard to read and the
      warning card already knew that~~ The pin board's theory cards were the
      clear offender: each theory's claim — two or three full sentences, the
      one piece of text on the whole board a player actually has to read and
      reason about to play L5/L6 at all — was set in `CellOutzType` at 8.5px
      condensed, the same face as the card's own title. Split the same way
      `warning_card.gd` and `world_index.gd`'s dossier memory already do: the
      title (a handful of words, a header) stays in the stencil via
      `CellOutzType.draw_condensed`; the claim now wraps and draws through
      `draw_string` on a real font (`_wrap_font()`, new, the same word-wrap
      as `_wrap()` measured against `ThemeDB.fallback_font` instead of the
      display face). Every other short label on a card — captions, route
      marginalia, a cutting's texture-not-words scrawl — is untouched; none
      of those are a paragraph. Verified: the existing `pin_test.gd`,
      `pin_board_v2_test.gd` and `sideline_cluster_test.gd` regression suites
      still pass, plus a windowed capture
      (`captures/i1_4_v2_theory_claims_real_font.png`) showing every claim
      legible in a real font against the titles still in stencil.
- [x] **I5.3** `v2` The rail is pointable — click a row to select it, hover to see where a click would land
- [x] ~~**I5.2** `v2` Links are collected during `_draw` and exist nowhere
      else, so nothing but the paint loop can ask what is on screen~~
      `_link_rects` was rebuilt as a side effect of `_draw_file`/`_draw_post`
      every paint and thrown away — a click arriving before the first frame
      had drawn read an empty list, and nothing but the renderer could ever
      ask what was pointable. `_rebuild_links()` now runs from `_process()`
      instead, reading the same layout through two new pure functions
      (`_file_link_rows`, `_wire_link_rows`) that compute rects with no
      draw_* calls attached, and `_panel_rect()` so the FILE/WIRE panel
      bounds are derived once instead of copied between `_draw()` and the
      new pass. `_draw()` now reads `_link_rects` instead of building it.
      Verified: `tests/index_link_rebuild_test.gd` (new, 5/5 — proves
      `_process()` alone populates real wound/implant links with no `_draw()`
      call in between, and that switching to a link-less page clears rather
      than leaves stale entries), plus the existing `tests/link_test.gd`
      (10/10) and a windowed capture confirming FILE and WIRE render
      identically to before.
- [x] ~~**I0.10** `v2` Panels are hosted at one fixed size inside the
      handheld; a map you cannot lean into is a picture of a map~~
      `device_size` was one clamp with nothing that ever moved it — the
      World Index and the Living Map, however much detail either had to
      show, always rendered into the same aperture. Holding `L` while a
      hosted panel is open (`INDEX`/`MAP`/`WIRE` — `RADIO`/`CARRY` have no
      hosted panel to gain anything from it) now eases the device up to
      1.32x its resting size, clamped to the viewport; letting go eases it
      back down. The hosted panel's own `.size` is already read off the
      aperture every frame, so it renders into the larger space with no
      separate change — the same Living Map, more of it, rather than a
      zoomed screenshot of it. Verified: `tests/handheld_lean_test.gd` (new,
      3/3 — holding grows it, releasing returns to rest, and a mode with
      nothing to lean into does not grow at all) and a windowed capture
      (`captures/i0_10_v2_handheld_map_resting.png` /
      `i0_10_v2_handheld_map_leaned.png`) showing the same map at both sizes.
- [x] ~~**I1.5** `v2` Code rain runs on screens that have not earned it — it
      is the substrate for the Wire, not decoration for every page~~ The
      World Index ran it full time behind FILE, PYRAMID and BODY as well as
      WIRE — a dossier, a career chart and an anatomy are not a network, and
      the rain used to fall behind all three regardless. `_wire_glow` eases
      toward 1 only while `PAGES[page] == "WIRE"` and back to 0 on every
      other page, folded into the rain's own tint alpha so it fades as one
      continuous material rather than switching on and off. `interstitial.gd`
      keeps its rain deliberately — that screen's own premise is a
      transmission ("CELLOUTZ TRANSIT", the body "in motion"), so the rain
      there is the Wire's vocabulary being earned on purpose, not decoration.
      Verified: `tests/index_wire_glow_test.gd` (3/3) plus
      `captures/i1_5_v2_index_file_no_rain.png` /
      `i1_5_v2_index_wire_has_rain.png`.
- [ ] **I4.3** `v2` Vitality degrades the panels uniformly; a specific wound should damage a specific part of what you are reading

## J — Infrastructure

Unglamorous, and each one is currently costing real time.

### J1 — Drop FMOD properly
- [x] ~~**J1.1** Extension disabled locally; headless tests run again~~
- [x] ~~**J1.2** Written up in `ROADMAP.md`, since `.gitignore` stops the fix travelling~~
- [ ] **J1.3** Remove the plugin outright — 238MB referenced by no script

### J2 — Debug affordances out of the shipping build
- [x] ~~**J2.1** Reset keys off the shipping input map~~
- [x] ~~**J2.2** Dev-only gate for the rest~~

### J3 — Adopt the installed plugins
- [x] **J3.1** LimboAI adopted narrowly — for the layer that did not exist, not as a rewrite of AI that works
- [ ] **J3.2** Terrain3D + Proton Scatter for the Ashbloom exterior
- [ ] **J3.3** Dialogue Manager when NPCs first speak

### J4 — Real loading behind the interstitial
- [x] ~~**J4.1** Stream behind the plate instead of a fixed 1.45s hold~~
- [x] ~~**J4.2** Progress bar that is telling the truth~~

---

## M — The camera is progression

Greg, 2026-09-12: *"the game should start probably in first person with the
insane fov style cruelty squad"* / *"you unlock third person once you get melee
weapons and bossfights through the nemesis system"* / *"in the car a driving the
wheel with one hand which is wasd and then making it you hold a gun through
shattered glass shooting out in first person driving then you can also switch
third person driving as you progress in the derby"*.

One rule in two places: first person is the default, third person is **earned**,
because third person is the abstract view — the one where you stop being a body
and start being an object — and leaving your body should cost something.

### M1 — On foot
- [x] **M1.1** Start locked in first person at FOV 106
- [x] **M1.2** Third person unlocks on a landed melee blow plus a dangerous rival put down
- [x] **M1.3** Both conditions read out of WorldHistory, neither stored
- [x] **M1.4** Pressing the key early answers in the game's voice, never silently
- [x] ~~**M1.5** The unlock itself is an event the player feels, not a quiet permission change~~ (found while building this: the unlock counter read a `"subject"` key no `npc_resolution` event has ever written — every writer uses `"subject_id"` — so M1.2's boss condition could never actually count a kill. Fixed alongside the felt event, since a stop+kick+line landing on a check that could never pass would have been silent forever.)
- [x] ~~**M1.6** A first-person HUD that is diegetic — nothing floating in the
      corner~~ The vessel/breath vitals were their own plate in the top-left
      corner — styled well, but structurally a second app widget with no
      relationship to anything else in view. Moved to hang off the weapon
      well instead, with a sagging strap running from the vitals crown into
      the torn mouth, so it reads as a gauge built into the gear in your hand
      rather than a corner readout.

      The location crest and hunt thread were the other two floating
      fixtures — permanent regardless of whether there was anything current
      to say, which I0.6 had already named and fixed on the derby's own
      version of the hunt readout ("a rival arrives when they change, not
      permanently") without the on-foot HUD ever getting the same treatment.
      The hunt thread now draws nothing while the status is dormant, same
      rule, same file finally. The location crest now announces an arrival
      and clears itself over a few seconds rather than sitting there for the
      rest of the session — honestly scoped: nothing currently feeds it a
      real mid-session location change, so today this is a one-time arrival
      card rather than a live travel readout, and building the latter is its
      own future segment once something tracks which named place the player
      is actually standing in. Verified: `tests/hud_transience_test.gd` (7
      checks — starts with nothing to announce, a first location announces
      and clears itself on its own, repeating the same location does not
      re-trigger it, a genuinely new one does, and rival status reads and
      normalises correctly), captured in `game/captures/m1_6_field_hud_vitals.png`.

### M2 — In the car
**Deferred this session.** There is currently no first/third-person split in
`rift_derby.gd` at all — one fixed chase camera — so this is a feature build
(seated view, a visible WASD hand, a held gun, a real glass object that cracks)
rather than a tune, in a file Agent B owns for visuals and is actively
changing. Starting it without coordinating risked either a merge collision or
landing something half-verified. Flagging it here rather than doing it
silently, per this session's brief.
- [ ] **M2.1** First-person driving is the default
- [ ] **M2.2** One hand on the wheel; that hand *is* WASD and it is visible
- [ ] **M2.3** The other hand holds a gun, and you shoot out of your own car
- [ ] **M2.4** You shoot through your own windscreen, and the glass is really there
- [ ] **M2.5** The glass degrades as the car takes hits — the view gets worse as you do
- [ ] **M2.6** Third-person driving unlocks through derby progress, separately from M1
- [ ] **M2.7** No hard cut between the two views (Rule 3)

### M2b — Cars are the horses of this world
Greg: *"in the car we need to be able to fully exit it like e exit the door type
of thing because in this world cars will be around like red dead horses but the
cars will be randomised fucked up and usually want to try and kill you because
the game is like carmageddon esc"*.
- [ ] **M2b.1** E opens the door and you get out — a real exit, not a mode switch
- [ ] **M2b.2** Cars are scattered through the world and can be taken, like a horse
- [ ] **M2b.3** Every car is randomised and wrong in its own way
- [ ] **M2b.4** Most of them want to kill you; driving one is not safe either
- [ ] **M2b.5** The derby is one place this happens, not the only place

### M4 — Perspective that holds up
Greg: *"perspective needs to be worked on and making accurate perspective enough
for the game to function in its own universe in its own right"*.
The FOV 106 default makes this urgent rather than cosmetic: at that width,
distortion, scale and horizon errors that were invisible at 72 become the whole
image.
- [x] ~~**M4.1** Scale is consistent — a door, a car and a person agree about how big a person is~~ Doorways have a lintel at 2.15 m and walls are banded per storey, so the world states human scale in its geometry; separately, Mara's rebuilt wrecker prop in `bone_yard_hunt.gd` was scaled 0.78 against the same `scrap_skiff.glb` at 1.05-1.176 in `rift_derby.gd` — a third smaller for no reason other than which file spawned it — and is now matched to 1.15. Player and NPC rigs already share one capsule height, verified side by side in a third-person capture.
- [x] **M4.2** Eye at 1.68 m off a 1.8 m body, dropping exactly as far as a crouch shortens it
- [x] **M4.3** `v2` FOV stated as the vertical angle Godot actually uses — ~110° across, not 134°
  - v1 — FOV raised to 106 for the Cruelty Squad register
  - v2 — 106 was the vertical angle, so it meant 134 across. 78 is the ~110 actually wanted
- [~] **M4.4** Weapon and hand framing hold up at the wide FOV without looking bolted on.
      Measured, not guessed: `hunter_arsenal.gd`'s weapon models were positioned
      before M4.1-M4.3 corrected the FOV and eye height, and sat entirely
      outside the frustum at the corrected numbers — verifiably invisible, not
      merely unconvincing. Re-solved against `right_arm`'s actual raised
      first-person pose and given a faint self-lit edge so it reads against the
      Expanse's own near-black ground level. Two agents hit this the same
      session from different angles — a shallower `arm_raise` on the arm
      itself, and a counter-rotated weapon model on top of it — and the merge
      landed both; the second pass caught that the counter-rotation had been
      copied against the *old* `arm_raise` value and would have silently thrown
      the weapon back out of frame, so it now reads `HUNTER_BODY_MOTION.FIRST_PERSON_ARM_RAISE`
      instead of a second hand-copied number. The cleaver reads clean — guard,
      grip and blade distinct, angled like a held blade, captured in
      `game/captures/`. The shotgun and sidearm are in frame and lit but their
      sub-pieces still read as stacked blocks rather than a gun silhouette from
      this angle — their own local `turn` values were never re-tuned against
      the same pose and are next. Guarded by `tests/viewmodel_frame_test.gd`
      so the frustum regression cannot happen silently again.

      Follow-up: the shotgun and sidearm pieces carried a shared -0.72 rad
      tilt authored for the old, unrotated hand — on top of `root`'s own
      counter-rotation it compounded into boxes pointing three different
      directions, reading as one stacked blob. Rechained straight down the
      same -Y axis the cleaver's own blade uses, with no rotation of their
      own; both now read as one coherent two-part held shape (a lighter
      barrel/slide over a darker stock/grip) rather than an ambiguous block —
      real progress, though neither is unmistakably gun-shaped at a glance
      the way the cleaver reads as a blade. Getting the rest of the way there
      is proportions and silhouette work (a longer, thinner barrel; a stock
      angled off the receiver) rather than another transform bug, so it is
      left here rather than force-finished. Recaptured in `game/captures/`.
- [x] ~~**M4.5** The rules are the game's own and applied everywhere, not photographic realism~~ (the resolution/interrogation camera had its own bare `72.0` FOV with no relationship to the 78/63 pair M4.3 established; it now takes `THIRD_PERSON_FOV` since it is already the "look at the body from outside" register)

### M3 — The seam
**Deferred this session**, for the same reason as M2: M3.1 and M3.2 both name
transitions (into driving, out of the derby) that do not exist as a mechanism
yet — the roadmap's own Tier 2 ("win the derby → exit the car → walk out of
the facility → Ashbloom") is not built. M3.3's diegetic HUD is a real,
smaller-scoped ask on its own; not attempted this session because the on-foot
half (`gothic_field_hud.gd`) and the derby half (`cab_screens.gd` /
`celloutz_hud.gd`) are two separate Control trees in two separate scenes today,
and "survives every transition" cannot be answered honestly without M3.1/M3.2
existing to transition through.
- [ ] **M3.1** The opening cutscene transitions into first-person driving without a cut
- [ ] **M3.2** The derby hands off to on-foot without a loading seam the player reads as one
- [ ] **M3.3** The HUD survives every transition; a diegetic HUD cannot simply fade to a third-person one

## N — The vat, extended

Greg, 2026-09-12: *"i love the current system of starting character creation
traits ect, but there should be a limited like well balanced starting trait
system still, obviously with more broken runs but then those are known they are a
bit more broken and like achievement runs"* — and *"needing a bigger thing on the
right showing the character 3d model changing parts face limbs full
customisation"*.

D is complete and stays complete. This is the layer on top of it.

### N1 — A budget worth spending
- [x] **N1.1** A limited, balanced starting trait budget — you cannot take everything — already built (D2, `BASE_POINTS := 6`); audited rather than rebuilt
- [ ] **N1.2** Costs tuned so the honest builds are genuinely competitive (a balance/playtesting question, not one this session can answer from the numbers alone)
- [x] **N1.3** Overspending is possible and the game lets you do it — `character_sheet.gd`'s `toggle_trait()` no longer hard-blocks on cost (that gate is what made overspending impossible); `can_take()` now only checks the trait exists and isn't already taken, and the old budget check survives as `is_affordable()` for whoever wants to warn rather than block. `vat_intake.gd`'s existing HOT colour on `points_left() <= 0` already reacts to this without any UI change

### N2 — Broken runs, honestly labelled
- [x] **N2.1** A run the game knows is broken is *marked* as broken, at creation — `apply_to_world()` writes `broken_run`/`overspent_by` onto the filed subject
- [x] **N2.2** Broken runs read as achievement runs rather than as mistakes — filing one records `achievement_run_started` (not an error/warning event) with the real deficit
- [ ] **N2.3** The world reacts to a broken build — being obviously wrong is visible to others (the flag is real and readable by anything — Wire, dossier, pricing — but nothing yet actually reads it; a reaction system is more than a single-sitting increment)
- [x] **N2.4** What counts as broken is derived from the build, not an authored list — `overspent_by()`/`is_broken_build()` read the same budget math every honest build already respects, threshold `BROKEN_OVERSPEND_THRESHOLD := 1` (today's trait roster can reach at most 1 point of overspend — set to match reality rather than an aspirational number nothing can trigger). Covered in `tests/sheet_test.gd` (13 new checks; existing D1/D2/D4/D5/D6/D8 checks — including the two that used to assert overspending was impossible — re-verified/updated with no other regressions, one confirmed via a real broken lottery roll at seed 215)

### N3 — The body on the right
- [ ] **N3.1** A large live 3D model beside the sheet, not a portrait
- [ ] **N3.2** It changes as you change: parts, face, limbs, build, wear
- [ ] **N3.3** Full customisation reaches the same rig the world spawns (BaselineHuman)
- [ ] **N3.4** Grown cybernetics and missing limbs show on it before you ever play
- [ ] **N3.5** It is lit and framed as a specimen, in the vat's own language

### N4 — The equipment screen
Greg, 2026-09-12: *"i want a hyperdetailed ui showing the player model equiping
weapons and its like fallout with a image or model on the right in 3d but all
things have models and little descriptions — right now you dont have to go that
far with descriptions"*.

The same live rig N3 puts beside the character sheet, put beside the inventory
instead: what you are carrying, what is in your hands, and a body that changes
when you change it. The technology is already built — `xray_specimen.gd` renders
a live `BaselineHuman` into a SubViewport, and `hunter_arsenal.gd` already builds
a model for every weapon.

- [ ] **N4.1** A live 3D body on the right, not an icon
- [ ] **N4.2** Equipping a weapon puts it in that body's hand, visibly
- [ ] **N4.3** Every item has a model rather than a name in a row (I0 applies)
- [ ] **N4.4** A short description per item — one line, in the game's voice, not a stat block
- [ ] **N4.5** Wounds, prosthetics and grown cybernetics show on the body here too
- [ ] **N4.6** It is the same rig the world spawns, so what you see is what walks out

### N5 — The slots, and what you are not supposed to touch
Greg, 2026-09-12: *"in the UI of the inventory and character, having slots for
all the spine and the body cybernetic organs being a thing that are locked at the
start until you change them — unless you want to take it out, but it warns you
saying 'you don't want to go rogue yet do you'."*

This is the best expression of the game's own premise that has come up. The
hardware in you is **not yours**. It was installed at intake, it is on CellOutz's
inventory, and the sheet you filled in D8 already calls each opt-in modifier "a
handle on you". Pulling one is the first genuinely disloyal act available to a
player, and it should be possible from hour one and quietly discouraged.

- [ ] **N5.1** A real slot per site — spine, skull, chest, each arm, each leg, the organ bays
- [ ] **N5.2** Factory hardware fills them at decanting and is *locked*, not absent
- [ ] **N5.3** Locked means discouraged, never disabled: the game warns and then lets you
- [ ] **N5.4** The warning is in CellOutz's voice, not the game's — "you don't want to go rogue yet, do you"
- [ ] **N5.5** Pulling one is recorded, and CellOutz standing reads it (E, `faction_price_factor`)
- [ ] **N5.6** An empty slot is a real condition — the body works worse without what was in it
- [ ] **N5.7** What you pull is a carried object with a lien on it, because it was never yours (B5.4)
- [ ] **N5.8** Robbed and grown hardware fit the same slots — one vocabulary, per B2.1

## O — Combat, reworked

Greg has now said this in four separate sessions, which makes it the most
repeated unresolved complaint in the project: *"the combat needs reworking"*.
Previous passes fixed aim resolution, lock-on and gore, and none of them
addressed whatever he is actually feeling. This section starts by finding out
what that is rather than fixing another symptom.

### O1 — Find the real fault first
- [x] **O1.1** Measured rather than played: timings, damage-per-zone and feedback path read off the code
- [x] **O1.2** Measured — 3 cleaver hits to a torso, 0.58s cooldown, 0.16s windup, **zero frames of contact feedback**
- [x] **O1.3** Named: there was no hitstop anywhere in normal combat

### O2 — Weight
- [x] **O2.1** Cleaver windup 0.16s → 0.28s; a heavy blade is readable before it lands
- [x] **O2.2** `v2` Hitstop, camera kick and shake on contact, scaled by the zone's own health
  - v1 — aim resolution, lock-on and gore fixed across three sessions
  - v2 — measurement found the real fault: no hitstop existed anywhere in the game
- [x] **O2.3** A miss carries the weapon through and moves the camera; it never stops time
- [x] **O2.4** Hold X to guard; the first 0.18s is a parry. Three answers now, not one

### O3 — The body is the health bar
- [x] ~~**O3.1** Damage lands on the limb you actually hit and stays there~~
      True for generic hostiles all along (`anatomy.dead`/`downed` already
      derive from real zone/blood state). The canonical Mara fight did not:
      melee correctly wounded her rig, but the retreat/defeat threshold ran
      off a separate flat `enemy_health` counter that only ever subtracted a
      fixed number, and the prosthetic surge subtracted 30 from it without
      touching her rig at all — the one attack in the fight that wounded
      nothing you could see. `enemy_health` is now derived from
      `_rig_health_ratio()`, a real average across all six zones, every time
      a hit lands; the surge now wounds her the same way melee does. Verified:
      a zone already at 0 pays out nothing further on a second hit, while
      spreading damage to a fresh zone still costs her — `tests/rival_body_health_test.gd`
      (8 checks). Found and fixed a second, unrelated bug on the way: her
      `wounds` array had gone `TypedArray[Dictionary]` from another subject's
      schema, so `.duplicate()` carried the stricter type over and
      `wounds.has()`/`.append()` on a plain string were throwing silently in
      the console rather than failing loud enough to notice without a test.
- [x] **O3.2** A damaged limb changes what that person can do, and now shows it — arms hang, legs trail, the body leans off the bad side
- [x] ~~**O3.3** Grappling connects to it — hold, force, rob, recruit~~ Rob and
      recruit already did (F7.2 lets you rob somebody you are holding; F7's
      persuade/threaten already read pain and fading consciousness). Hold and
      force did not: the clinch's tug-of-war already softened resistance for
      arm damage in general (`combat_ratio()`), but had no idea *which* limb
      it actually had — grabbing an untouched arm and one already broken was
      identical. `_start_grapple` now grabs whichever limb is worst off
      (`grapple_zone`), that specific limb's own condition weakens their
      resistance on top of the general figure, and pressing the hold (LMB)
      now actually damages the limb being leveraged rather than only the
      clinch's own private number. The prompt names the limb once it is
      hurt enough to matter. Verified: `tests/grapple_zone_test.gd` (4
      checks — the hold picks the worst limb, leverage through a broken one
      measurably outpaces a whole one, and pressing it costs real zone
      health), plus the existing grapple/clinch suite and opening/combat
      integration tests all still pass.
- [ ] **O3.4** Half Sword's lesson without Half Sword's code: the body is the weapon system

### O5 — The brawl

Greg has raised this more than any other combat idea: *"if the combat has
grappling too like halfsword you can hold them and say things force them to take
your abuse and thats how you can rob or aggress some npcs and also how you can
persuade them to join your ranks"*.

It has only ever been one line on this list, which is why it keeps coming back.
The register is Half Sword's — unglamorous, physical, off-balance — and the
implementation is emphatically **not** Half Sword's: no reading their code, no
reproducing their control scheme. What is being taken is the *lesson*, which is
that a fight between two bodies is about weight and leverage rather than about
hitpoints. `clinch_test.gd` and F7 already exist; this is the rest of it.

- [x] **O5.1** Stepping into a blow lends it your mass; retreating takes it out. The arc alternates sides on its own
- [x] **O5.2** Melee resolves against BaselineHuman zones by geometry — it was already true, now verified
- [x] **O5.3** A held clinch with advantage, stamina drain, and a real cost for losing it
- [x] **O5.4** Robbed, spoken to, leaned on, walked where you want them, and held in the line of fire
- [x] **O5.5** Already true via F7 — pain and fading consciousness feed the hold, the hold feeds consent, consent is what recruitment reads. Verified end to end rather than assumed
- [x] **O5.6** Their force opposes yours, scaled by their own pain and arms
- [x] **O5.7** The player has footing now, not just the enemies — whiffing, blocking and being shoved all cost it
- [x] **O5.8** Press 5 to put the weapons down — 42 dps against a cleaver's 76, at 1.55m of reach
- [x] **O5.9** Proven on the guard first: two broken arms block badly, no arms cannot block at all

### O4 — Enemies that fight back
- [x] ~~**O4.1** They read your commitment and punish it~~ A hostile already in
      melee range presses its own attack clock at 2.2x while the player is
      mid-windup (`strike_windup >= 0.0`) — a commitment you cannot cancel or
      guard against invites being punished for it, rather than the enemy
      ticking down on a clock indifferent to what you just did.
- [x] ~~**O4.2** They retreat, circle and group rather than walking at you~~
      Was a straight line to the same 3 m ring for every hostile at once,
      which reads as a queue. Whoever does not already hold the melee opening
      now orbits the player at a stand-off distance instead of stacking into
      it, so a second and third attacker read as surrounding you rather than
      waiting their turn. Retreat (fleeing on critical injury) already
      existed; this was the missing half.
- [x] ~~**O4.3** A wounded enemy fights differently from a fresh one~~ Already
      true by construction — `_actor_attack_cycle`/`_actor_attack_damage` read
      `anatomy.combat_ratio()`, so a maimed hostile already swings slower and
      softer (`combat_integration_test.gd`: "the one-armed fighter attacks
      more slowly" / "hits less hard") — just never checked off. Guarded by
      the new `tests/enemy_ai_test.gd` (5 checks) for O4.1/O4.2.

### O v3 — the third pass
Opened because O2.5 closed at v2. A fault the v2 work itself created.

- [x] **O2.7** `v3` The player's windup, cooldowns, arsenal and rig animation all tick on their own scaled clock — both bodies in contact feel the freeze
- [ ] **O2.8** `v4` Gore and chunk physics still run at full speed through a hit, so a limb can leave a body that has not moved yet
      own cooldowns, the rig animations and the gore still run at full speed
      during a hit they are part of. Cooldowns and rig animation are fixed:
      `attack_cooldown`, `dodge_cooldown`, `arsenal.tick()` and `strike_windup`
      now tick against `delta * impact_feel.scale_for("player")`, and
      `body_motion.update()` gets the same scaled delta for its own animation
      clock — movement itself deliberately stays on the real clock, since
      hitstop is not meant to take your feet out from under you, only the
      weapon and the cooldowns behind it. Gore is not: chunks are real
      `RigidBody3D` nodes integrated by the physics server directly, and
      slowing a specific body's physics selectively needs either a custom
      integrator or a freeze/resume scheme, not a delta multiply — genuinely
      bigger scope than the other two, so named rather than faked with
      something that would look worse than doing nothing. Verified:
      `tests/hitstop_scope_test.gd` (5 checks — cooldowns and the rig's own
      animation clock both tick at the real rate with no hit active, and
      both slow to `STOP_SCALE` during the player's own hitstop), plus the
      full combat/grapple regression suite still passes.

### O v2 — the second pass
- [x] **O2.5** `v2` Hitstop is local — the two bodies in the exchange slow, the region does not. The global clock is never touched
- [x] ~~**O2.6** `v2` The guard has no direction — it holds equally against
      something behind you~~ `guard_absorb()` never took an attacker position
      at all, so raising the guard toward whatever you were looking at
      somehow also covered your back — there was no such thing as flanking
      the player. It now takes the attacker's position and checks it against
      a real frontal arc (100° either side of where you are actually facing);
      outside that arc the blow goes through whole, as if the guard was
      never there for it, because it wasn't. The one existing call site
      already had the attacker's node in scope. Verified:
      `tests/guard_direction_test.gd` (4 checks — front still blocks, directly
      behind goes through untouched, and a call with no attacker position at
      all keeps the old always-blocks behaviour for backward compatibility),
      plus the full combat/grapple/clinch suite still passes.
- [x] ~~**O5.10** `v2` Footing is the player's alone; enemies use the older
      `staggered` state, so the two bodies in a brawl run on different
      systems~~ Enemies now carry the same `footing` meter, recovered every
      tick the same way. Every landed hit chips it on `response.severity`'s
      own scale rather than only doing something once the old hard-stagger
      threshold was crossed; a stumbling enemy cannot wind up a fresh attack
      (the same "the guard will not hold" rule the player's own footing
      already enforced, now on the other side); attack cycle and damage both
      soften further while off balance, on top of what `combat_ratio()`
      already costs them. Found the actual reason a parry "eating their own
      commitment" never did anything: it wrote to `actor["stagger"]` and
      `actor["cooldown"]`, and nothing anywhere ever read either field — a
      parry cost the enemy nothing beyond the damage it already blocked. It
      now costs real footing instead. The old binary `staggered` lock stays
      for genuinely heavy hits; footing is the meter underneath it that used
      to not exist. Verified: `tests/enemy_footing_test.gd` (8 checks), plus
      the full grapple/clinch suite, `enemy_ai_test`, `combat_integration_test`
      and `opening_test` all still pass.
- [x] ~~**O5.11** `v2` Swing momentum reads the body's velocity and ignores
      where the weapon was actually pointed~~ `swing_side` alternated every
      swing and was already returned in `swing_momentum()`'s own dictionary,
      but nothing anywhere compared it against how the player actually
      moved — the bonus only ever asked whether you stepped toward where you
      were looking. It now also reads the lateral component of your movement
      against the arc's own direction: moving with the swing lends a further
      `ARC_STEP_BONUS` (0.25, deliberately smaller than the 0.55 step-in
      bonus — the forward read stays dominant), moving against it costs the
      same back. A pure straight-in step with no lateral component is
      unaffected either way, so this is additive rather than a retune of
      what already worked. Verified: `tests/swing_arc_test.gd` (5 checks —
      the same lateral step reads oppositely depending on which way the arc
      is swinging, moving with it measurably outscores moving against it,
      flipping the arc flips the sign, and a straight-in step is untouched),
      plus the full combat suite still passes.
- [x] ~~**O3.5** `v2` Nothing a body wears or has grown changes what a blow does
      to it — armour and plating are not in the resolution at all~~ Audited
      rather than built: `anatomy_component.gd`'s `apply_hit()` already reads
      `installed.armor` scaled by the implant's own condition and reduces the
      applied damage by it, on every rig — this was written this session
      (B2.2/B2.3) and the claim simply predates it. This project's plating is
      surgical rather than worn, which fits the register — a "ceramic
      sternum" or a "load-bearing spine cage" out of `implant_catalog.gd` is
      the armour, not a jacket. Verified rather than assumed:
      `tests/armor_resolution_test.gd` (5 checks — a plated zone takes
      measurably less damage, the reduction matches the plate's own rating
      exactly, a battered plate protects less than a fresh one of the same
      rating, and the player's own opening-hand torque arm is not exempt from
      any of it).

## P — The demo

Greg, 2026-09-12, twice, and the second time corrected the first:

> *"the next big section needing to be added will be making the game a 30 minute
> demo seperate to the orignal version"*
>
> *"i want the demo to be a massive playable game like havker man x but edging
> the best and funnest features then in the demo we can make a bit where the
> game stops and its seperate to the press play in the main menu but same game
> just a demo version would be more helpful"*

**One build. Two doors.** The main menu offers PLAY and DEMO, and they run the
same game out of the same executable. That is the whole architecture, and it is
better than a separate export for the reason Greg gave: one thing to maintain,
one thing to test, nothing to drift.

And the demo is **not a cut-down game**. It is the game with its best hour
pushed to the front — generous, loud, showing off — that then **stops on
purpose**. A demo that feels thin is a demo that cut things. This one is
supposed to feel like too much, and then end.

### P1 — What the demo route is
- [ ] **P1.1** A curated route through the *real* game, not a separate map
- [ ] **P1.2** The best features front-loaded: anatomy, gore, X-ray killcam, the derby, the Board
- [ ] **P1.3** Generous rather than careful — it should feel like a full game while it lasts
- [ ] **P1.4** No dependence on the cosmology being understood; the Horsemen stay off-screen

### P2 — Two doors, one build
- [ ] **P2.1** PLAY and DEMO sit side by side on the main menu
- [ ] **P2.2** A single runtime flag distinguishes them — no second export preset
- [ ] **P2.3** Demo saves are their own slot and can never touch a real save
- [ ] **P2.4** Any feature the demo shows is the real feature, running the real code
- [ ] **P2.5** Starting DEMO from the menu is one click, with no configuration in between

### P2b — The edges of the demo

Greg: *"more exploration would be locked off and features in the demo but then
in the mainline its playable"*.

So the demo **is** gated — but the gate has to be the world refusing you rather
than the build missing content. That distinction is everything: a greyed-out
button says the game is unfinished, while a road nobody will let you down says
the game is bigger than you. This project is unusually well set up for the
second one, because the systems that gate things already exist and are already
diegetic.

- [ ] **P2b.1** Locked regions are refused by the world, never by a disabled control
- [ ] **P2b.2** Refusals reuse systems that already exist — signal grade, faction standing, a road nobody will open
- [ ] **P2b.3** A refusal names what is on the other side, so the player knows what they are missing
- [ ] **P2b.4** Locked features are absent, not visibly disabled — no ghost buttons
- [ ] **P2b.5** Everything locked in the demo is genuinely playable in the mainline; nothing is locked because it is unbuilt
- [ ] **P2b.6** The same code path serves both — the mainline does not get a second implementation

### P3 — The wall
The part that makes it a demo rather than a trial. It is a designed moment, in
the game's own voice, not a fade to a store page.
- [ ] **P3.1** The game stops at an authored point, deliberately and visibly
- [ ] **P3.2** The stop is in the register — CellOutz would bill you for it
- [ ] **P3.3** It arrives *after* a win, not in the middle of one
- [ ] **P3.4** What the player loses by stopping is made concrete: the wall names what was next
- [ ] **P3.5** The stop is written into WorldHistory like any other ending

### P4 — The half hour
- [ ] **P4.1** Playable within sixty seconds of launching
- [ ] **P4.2** Measured, not estimated — a real run timed end to end
- [ ] **P4.3** Nothing in it outstays its welcome: the second derby lap, the long walk, the third menu
- [ ] **P4.4** One moment engineered to be the thing a player describes to somebody else
- [ ] **P4.5** A failure state that is interesting rather than a reload

### P5 — Shipping it
- [ ] **P5.1** Runs on a machine that is not Greg's, from a clean folder
- [ ] **P5.2** No debug affordances, no dev keys, no placeholder text (depends on J2)
- [ ] **P5.3** Sound mixed and the sliders working in the built game, not just in the editor
- [ ] **P5.4** Controls learnable without a tutorial screen — I0 still applies
- [ ] **P5.5** The last pass is playing it, not reading it

## Q — The Wire, deeper

Greg: *"the social media stalking aspect cyberharassing dming ect with an rng of
responding more verified higher accounts of the darkweb internet underbelly to
the game exisit too"*.

`wire_net.gd` has accounts, reach, exposure and five actions. What it does not
have is the part Greg described: people you can actually reach out to, who
answer or do not, and whose willingness depends on who you are to them.

- [ ] **Q1.1** Direct messages — reach one account rather than publishing at everyone
- [ ] **Q1.2** Whether they answer is a roll against reach, standing and what you have on them
- [ ] **Q1.3** A verified account answers differently, and less often, than a nobody
- [ ] **Q1.4** Stalking a feed is a way of finding somebody in the world, not flavour
- [ ] **Q1.5** Harassment works and costs — it moves grudge, reach and exposure together
- [ ] **Q1.6** The underbelly is reached by standing somewhere, as `signal_field.gd` already gates

## R — Money

The body economy exists in pieces: `carry.gd` prices a part, faction standing
already refuses a deal outright, and liens already follow stolen goods. Nothing
ties it together into a reason to get up in the morning.

- [ ] **R1.1** One currency with a name and a reason — rust scrip, and who issues it
- [ ] **R1.2** What a body is worth, by part, condition and whose it was
- [ ] **R1.3** Buyers with their own appetites, so a market is a set of people and not a price
- [ ] **R1.4** Debt you can be in, since `debt_to_player` already runs the other way
- [ ] **R1.5** Prices move with what the world has been through

## S — Speech

`dialogue_manager` is installed and barely used, and Greg has twice asked for
talking to be a real verb — *"you can also speak to them via voicechat"*, and
the clinch already has TALK in it.

- [ ] **S1.1** Conversation is a state you are in with a body, not a menu over the world
- [ ] **S1.2** What they will say reads from what they know, not from a tree
- [ ] **S1.3** Proximity voice already exists — make it carry something
- [ ] **S1.4** Talking while holding somebody is different from talking to somebody free
- [ ] **S1.5** Lines survive the fiction: nobody explains the cosmology at you

### S2 — Talking to them out loud
Greg, twice: *"the proximity chat AI voices and being able to speak to AI in
game"*. `proximity_voice.gd` exists and already has a capture bus. Nothing has
ever been said into it.
- [ ] **S2.1** Speak, and be heard by whoever is close enough to hear it
- [ ] **S2.2** They answer in a voice, positioned where their head is
- [ ] **S2.3** What they say comes from what they know, not a response table
- [ ] **S2.4** Talking while holding somebody is its own register (feeds O5.4 and F7)
- [ ] **S2.5** Decide the cost and the privacy of this honestly before it ships

## T — The run

The open question that has been sitting unanswered longest: *"what persists
between runs?"* Roguelike structure was asked for, and "bodies remember" is a
pillar. They pull against each other and the game cannot have both untouched.

- [ ] **T1.1** Decide it — blocked on Greg
- [ ] **T1.2** Death is an event in the world rather than a reload
- [ ] **T1.3** Something inherits: a body, a debt, a reputation, a wall of pins
- [ ] **T1.4** What the world keeps is visible to the player before they risk it
- [ ] **T1.5** A run has a shape — it starts, it escalates, it ends

## U — Your own ladder

Greg: *"how you can persuade them to join your ranks your own faction that you
start through progressing and exploring around the map"*. E is the two ladders
that already exist. This is the third one, which is yours.

- [ ] **U1.1** Found something — a name, a mark, a first member
- [ ] **U1.2** Recruits from the clinch and the downed window belong to it
- [ ] **U1.3** It has standing on the same axis every other faction does
- [ ] **U1.4** It can be attacked, and it can lose people
- [ ] **U1.5** Rank inside it is somebody else's problem too — they have opinions

## V — The road

M2b covers cars as this world's horses. This is everything else about them
being vehicles rather than set pieces.

- [ ] **V1.1** A car is a thing with a condition, not a state you are in
- [ ] **V1.2** Damage is physical and visible, and it changes how it drives
- [ ] **V1.3** Fuel, or a reason a car is not infinite
- [ ] **V1.4** Cars can be repaired, badly
- [ ] **V1.5** Somebody else is driving one too, outside the derby

## W — Weather and the hour

The Expanse has one lighting state, one fog density and no clock. `WorldLook`
already switches presets by place; nothing switches by time.

- [ ] **W1.1** A day cycle the world reads, not only the sky
- [ ] **W1.2** Contamination has weather — it moves, it settles, it gets worse
- [ ] **W1.3** Being caught out in it costs something
- [ ] **W1.4** Factions keep hours; the Wire is busier at some of them
- [ ] **W1.5** G7's exposure problem is a lighting *state* rather than a constant

## X — Performance

Nothing in this project has ever been profiled. It is a solo build with one
region, so it has not needed to be — which is exactly when the debt is cheap to
pay.

- [ ] **X1.1** Profile it, and write down the real numbers
- [ ] **X1.2** A frame budget, stated, that the region is held to
- [ ] **X1.3** The 238MB plugin referenced by no script (pairs with J1.3)
- [ ] **X1.4** Bodies are the expensive thing — measure before optimising them
- [ ] **X1.5** It has to hold up on a machine that is not Greg's

## Y — Getting in

The game currently assumes a player who already knows what it is. It has no
options a person would actually reach for and no way in that is not "start".

- [ ] **Y1.1** Controls are rebindable
- [ ] **Y1.2** The violence tier from the warning card actually changes the build
- [ ] **Y1.3** Text is legible at a normal viewing distance — the stencil is not free
- [ ] **Y1.4** Colour is not the only carrier of meaning anywhere
- [ ] **Y1.5** Somebody can put it down and come back a week later

## Z — Shipping

- [x] **Z1.1** Windows export preset builds `WizardsOnlyFools.exe` (109MB + 16.5MB pck) and it launches — verified by running it, not by reading the log
- [ ] **Z1.2** Saves that survive the next version (`WorldHistory` migration already exists)
- [ ] **Z1.3** A crash is a released crash — the last pass is playing it
- [ ] **Z1.4** It has a name, a page and a way for one stranger to get it
- [ ] **Z1.5** Greg decides what the first public thing actually is

---

# The remaster — after Z

Greg, 2026-09-12: *"get the checklist to letter z in ideas then make it complete
then remaster it in a new way where we combine all the ideas together like all
the 5.0-5.9 etc but then all those link into this new checklist of the game
mechanic being a true thing we can combine"*.

**This list is organised by the order the work happened in, and that is the
wrong shape for a finished game.** A-Z are development buckets: "the visual
pass", "the handheld", "combat, reworked". They were the right way to build,
because each one could be closed. They are not how the game actually works.

The remaster re-cuts every closed segment by **mechanic**, so the numbered
groups stop being jobs done in a row and start being the systems the player
meets. What today is spread across five sections — O5.9 the arm that cannot
hold a guard, B4 the anatomy that scores it, F7 the clinch that reads pain,
E the standing that prices the deal, L the wall that pins the result — is one
mechanic, and after the remaster it reads as one.

Three rules for when it happens:

1. **Nothing is rewritten.** A remastered entry points at the segments that
   already built it. If a mechanic has no segments under it, it is not built,
   and saying so is the point.
2. **A mechanic earns a number only if it touches at least two sections.**
   Anything that lives entirely inside one section was never cross-cutting and
   stays where it is.
3. **It happens after Z is closed, not before.** Re-cutting a list while items
   are still being added produces a third list rather than a better one.

The candidate mechanics, from what is already built:

- **The body** — one rig, read by combat, the clinch, the guard, the vat, the
  loading screen and the Board.
- **The two records** — what happened, against what each faction believes.
- **Standing** — one axis pricing deals, refusals, recruitment and endings.
- **The hold** — the clinch as the seam between fighting, robbing, talking and
  recruiting.
- **The wall** — evidence, claims, leads, publication and the endings.
- **The camera** — progression expressed as what you are allowed to see.
- **Signal** — where you are standing deciding what you can reach.

## AA — The land takes a side

Greg, 2026-09-12: *"walking around it is like cleaning a massive window,
satisfying, like Elden Ring's map exploration pushing you to explore and cast
light or darkness upon areas like in Shadow of Mordor too — but you get to
choose, in the states or splits of the map, to give the lands to the ascended
wizard religious chaos magicians, or choose to send the lands to corruption,
destroying the map and the towns and decreasing weather quality, natural things
etc."*

This is the largest idea in the project and it connects almost everything
already built. A10 makes the map the world seen from above. **AA makes it
something you change.** The region splits into holdings; each one can be given
upward to wizardsonlyfoolz or downward to CellOutz corruption; and the choice is
visible from the air, permanently, in the colour of the ground.

It is worth being explicit about why this fits rather than being a bolt-on:
`FACTION_TREE_AXIS` already runs from CellOutz at -0.95 to wizardsonlyfoolz at
+0.92, `signal_field.gd` already divides the world into places with their own
reach, and the survey already tracks what the player has walked. The pieces are
in; nothing has ever asked the player to *use* them on a map.

### AA1 — Cleaning the window
- [ ] **AA1.1** Revealing ground is the satisfying part, not the admin — it should feel like wiping glass
- [ ] **AA1.2** Colour arrives with weight: a revealed holding is a small event, not a tick
- [ ] **AA1.3** What is still grey pulls at you — the unrevealed shape is legible enough to want
- [ ] **AA1.4** Reveal is per holding, not per metre, so it arrives in satisfying pieces

### AA2 — The split
- [ ] **AA2.1** The region divides into named holdings with their own edges
- [ ] **AA2.2** A holding can be given to the ascent or given to corruption
- [ ] **AA2.3** Giving it is an act with a cost, not a menu choice
- [ ] **AA2.4** A holding remembers who took it and when (WorldHistory, like everything else)
- [ ] **AA2.5** Neither side is the good one; the karma axis already refuses that framing

### AA3 — What the land becomes
- [ ] **AA3.1** Ascended ground: colour, light, weather clearing, things growing back
- [ ] **AA3.2** Corrupted ground: the towns go, the weather worsens, the natural things fail
- [ ] **AA3.3** The change is visible from the satellite view at a glance
- [ ] **AA3.4** It is visible on foot too — the same ground, walked
- [ ] **AA3.5** Corruption spreads on its own if nothing holds it
- [ ] **AA3.6** Ties to W: weather quality is a per-holding number, not a global one

### AA4 — Consequence
- [ ] **AA4.1** Who lives there reacts — a corrupted holding loses its people
- [ ] **AA4.2** Factions care: taking ground moves standing on both ladders
- [ ] **AA4.3** The Board can pin a holding, so a theory can be about land
- [ ] **AA4.4** An ending can be reached through the map rather than through a person

## AB — Destruction

Greg: *"a system like Teardown could be next level for destruction physics and
gore meshes within the game"*.

Recorded as the idea it is rather than as a plan. Teardown's voxel destruction is
a whole engine discipline and this is a solo Godot project, so the honest first
question is not "how do we build that" but "what does this game actually need
from it" — and the answer is probably narrower and more achievable: things break
where they are hit, and what comes off them stays.

- [ ] **AB1.1** Decide the scope honestly before building anything — full voxel destruction is not a feature, it is a second project
- [ ] **AB1.2** Structures break where they are struck rather than swapping to a damaged model
- [ ] **AB1.3** Debris is real, persists, and can be stood on or thrown
- [ ] **AB1.4** It reads through the gore system that already exists — `gore_chunks.gd` already breaks bodies into identified pieces
- [ ] **AB1.5** A vehicle deforms rather than losing hit points (pairs with V1.2)
- [ ] **AB1.6** Measure the cost before committing; X exists because nothing here has been profiled

### AB2 — Damage the world keeps
Greg: *"everything is measurably destroyable in the game and the environment
system has a simple way to track that... dents on cars, dents on things, smashes
on windows etc. They repair after a month in game."*

The tracking is the feature. A world where everything breaks and nothing is
recorded resets the moment you look away, and this project already has the
ledger to avoid that.

- [ ] **AB2.1** Every breakable thing has a condition the world can read, not a destroyed flag
- [ ] **AB2.2** Damage is recorded against the place, in WorldHistory, like everything else
- [ ] **AB2.3** Cheap to ask "how wrecked is this street" without walking it
- [ ] **AB2.4** Repair happens over game time — a month, not a respawn
- [ ] **AB2.5** Who repairs it is somebody: a holding nobody holds does not get fixed (pairs with AA)
- [ ] **AB2.6** Dents, smashes and scoring are the common case; collapse is the rare one

### AB3 — Raiding
Greg: *"the raiding physics and world in that way with the destruction physics
would be so integral it would be awesome."*

Destruction with nothing to destroy for is a toy. Raiding is the verb that makes
AB and AA the same system: you break a holding to take it.

- [ ] **AB3.1** A place can be raided — entered against resistance, for something specific
- [ ] **AB3.2** Breaking in is a real route: doors, walls, roofs, whatever gives first
- [ ] **AB3.3** What you take is carried, priced and traceable (CARRY, liens, the Choir)
- [ ] **AB3.4** The damage stays and the holding remembers who did it (AB2, AA2.4)
- [ ] **AB3.5** Somebody raids you back — H1 gives the player a place to lose

## AC — Fluid, weather and fire

Greg: *"if water, rain, weather, lightning etc environments wherever possibly
made to be built, the fluid physics would have to act similarly to the breaking
of buildings... if there is fluid or that type of thing in the game then it needs
to be very high in priority"* — and *"car engines and explosion physics being a
part of the game, especially if some weapons got insanely enhanced."*

The honest note first: **fluid simulation is the most expensive thing on this
list.** Greg is right that it must be high priority *if it exists at all*,
because half-done fluid reads worse than none — and that cuts both ways. AC1.1 is
a real decision, not a formality.

- [ ] **AC1.1** Decide whether this game has simulated fluid, or painted fluid done well
- [ ] **AC1.2** If it exists it obeys the destruction rule: recorded, not decorative
- [ ] **AC1.3** Rain wets surfaces and pools where the ground actually dips
- [ ] **AC1.4** Blood joins the same system — B4 already tracks where it lands
- [ ] **AC1.5** Lightning is a real light and a real sound, on the weather clock (W)
- [ ] **AC1.6** Fire spreads on what will burn and stops on what will not
- [ ] **AC1.7** Explosions move things, break things and hurt bodies through one path
- [ ] **AC1.8** An engine can catch, and a car that catches is a bomb with a timer

## AF — Guns, properly

Greg, 2026-09-12: *"i have to make the combat system a part of the gun system and
weapons, so bullet, weapon and firing are all realistic bullets and reload with
the things"* — and *"bullets shells fall on the floor aggressively as the bullet
destroys the map"*.

`hunter_arsenal.gd` has damage, spread, pellets, magazines and a reload timer. It
does not have a **bullet**: firing is a raycast and an ammo decrement. Everything
Greg is describing needs the round to be a real object that leaves the weapon,
travels, hits something and leaves a mark on it.

- [ ] **AF1.1** A round is a thing that travels, not a raycast resolved on the frame it is fired
- [ ] **AF1.2** It hits the world and leaves damage there (pairs with AB2)
- [ ] **AF1.3** Casings eject, bounce, land and stay — the floor of a firefight reads as one
- [ ] **AF1.4** Reloading is physical: the magazine leaves the weapon and a new one arrives
- [ ] **AF1.5** A magazine dropped half-full is half-full when you pick it up
- [ ] **AF1.6** Calibre means something — what a round does to a body and to a wall differ
- [ ] **AF1.7** It reads through the anatomy already built: a round finds a zone, not a hitbox
- [ ] **AF1.8** Firing from a car is the same system (M2.3)

## AD — Movement, and being in first person

Greg: *"right now we need the first person to be insanely comprehensive and have
a good playable HUD, with movement physics, jumping around, building, wall
running like Prototype after a while."* The priority he set.

M covers which camera you are in and why. AD is what the body can do while you
are in it.

### AD1 — The body moves
- [ ] **AD1.1** Jumping worth doing — height, arc and a landing that reads
- [ ] **AD1.2** Vaulting and mantling: waist-high things stop being walls
- [ ] **AD1.3** Wall running, earned the way third person is earned rather than given
- [ ] **AD1.4** Climbing a building is a route, not a cutscene (Prototype's lesson)
- [ ] **AD1.5** Momentum carries between moves — run into vault into climb is one motion
- [ ] **AD1.6** All of it reads through the anatomy: a broken leg cannot vault

### AD2 — The first-person HUD
- [ ] **AD2.1** Diegetic: the hands, the weapon, the handheld, the windscreen (pairs with M1.6)
- [ ] **AD2.2** Nothing floating in a corner that could be on an object instead
- [ ] **AD2.3** Affordances along the bottom that say what you can do right now
- [ ] **AD2.4** It survives the transition to third person without dissolving (M3.3)
- [ ] **AD2.5** Readable while moving, which is when it is actually needed

### AD3 — Builds that break the rules
Greg: *"not to copy HAVKER-MAN X, but with the cybernetics and limb enhancements
you should be able to viably, with melee, at some points fight people with
grenade launchers and RPGs — through jumping on rockets, or cutting them in half,
sniping them, through enhanced character builds."*

The payoff for D, B2 and N: a body built far enough in one direction should be
able to answer a rocket with a blade, and the game should let it.

- [ ] **AD3.1** A melee build can close on a launcher and live — the distance is the puzzle
- [ ] **AD3.2** Cybernetics change what movement is possible, not just the numbers
- [ ] **AD3.3** A projectile is a physical thing that can be met, not a damage event
- [ ] **AD3.4** Absurd answers are allowed when the build earned them
- [ ] **AD3.5** Original to this game: the reference is the feeling, never the implementation

## AE — Sneaking, assassination and the law

Greg: *"assassination, executing and sneaking systems with the hostile and law
enforcement type figures who punish you for bad local karmic events."*

The karma axis and the witness ledger already exist. Nobody has ever come to
arrest anybody.

- [ ] **AE1.1** Unseen is a real state with real inputs — light, noise, cover, distance
- [ ] **AE1.2** An unseen kill differs from a seen one, mechanically and in the record
- [ ] **AE1.3** Assassination as a verb: reach somebody who does not know you are there
- [ ] **AE1.4** Law figures respond to what was actually witnessed (`witness_ledger.gd`)
- [ ] **AE1.5** Punishment is local: the holding remembers, and the holding sends them
- [ ] **AE1.6** Karma is an axis, not a score — the law reads position, not "evil"
- [ ] **AE1.7** Being hunted by the law is the Hunt System pointed back at you (F)


## AG — Playtest, 12 September 2026

The first person who was not Greg played the build. Everything below is either a
bug he hit or something he said, quoted, because a playtester's own words are
more useful than a summary of them.

What worked, and is worth not breaking: the Living Map — *"oh shit, it shows
where I've been"* and *"and fog of war"*; the downed-resolution window — *"ok
they just fell down, and I could choose, omg"*; combat and gore; the handheld on
G — *"is that the pip boy thing you talked about, I see index map radio and
carry"*. His overall verdict was *"it's already so in-depth, I actually love
this"*.

### AG1 — Bugs he found
- [x] **AG1.1** The weapon wheel dilated time and drew nothing — the radial is a child of the handheld, and the handheld hides itself when lowered
- [x] **AG1.2** Holding B looped: the wheel spent its own budget, committed whatever the pointer was over (*"it will play the shooting thing"*), then reopened because the key was still down
- [x] **AG1.3** A full bag was a wall of overlapping labels — identical parts now group with a count
- [x] **AG1.4** SCREEN in settings, F11 anywhere, and it is restored at startup
- [x] **AG1.5** It does — `register_subject` is save-safe, WorldHistory persists to disk, and `apply_gore_setting()` runs at startup in both the hunt and the derby
- [x] **AG1.6** It does not. `tests/derby_exit_test.gd` drives a heat, sheds panels, wrecks all eight, leaves on both endings with a fully built arena, and lands in Ashbloom clean — every previous derby test had set `leaving = true` to stop the swap freeing the harness, so this path had never once been run
- [x] **AG1.7** *"when I'm looking through the Tree section I can't see my mouse cursor"* — the OS pointer is hidden for every panel and only the index drew a replacement

### AG2 — What he could not find
The theme of the whole session, and it is a design fault rather than his.
- [ ] **AG2.1** He could not find the Board; Greg could not remember the key either
- [ ] **AG2.2** Nothing teaches the weapon wheel — Greg had to guess *"i think its holding b?"*
- [ ] **AG2.3** *"press buttons probably"* is the current discovery mechanism for every panel
- [ ] **AG2.4** The first-person HUD must say what can be pressed (AD2.3)

### AG3 - The derby, second playtest
Greg, in the seat: *"the derby thing is so whack rn no hud or hull not
progressing out of the car animation no shooting through first person no
direction of controls"*. All four are real and all four are the same mistake.

`rift_derby.gd:_ready` contains, in order, `status.visible = false`,
`score_label.visible = false` and `rival_label.visible = false`, with a comment
saying the hull is read off the car instead. I0 said *no screen is a list of
text in a box*; it got applied as *no information*, which is not the same
sentence. And `vehicle_interior.gd` - the cab, the wheel, the gun hand, the
windscreen, the whole of M2 - is instantiated by **nothing but its own capture
test**. It was ticked on the strength of a screenshot and never wired to the
game.

- [x] **AG3.1** The readouts come back, as instruments in the binnacle rather than corner plates - `dash_cluster.gd`
- [ ] **AG3.2** The camera goes in the cab. M2 was built and never wired to anything
- [ ] **AG3.3** Getting out of the car is something you watch happen, not a scene swap on E
- [ ] **AG3.4** You can shoot through your own windscreen, and the glass keeps the holes
- [ ] **AG3.5** Nothing in the derby says what any key does - the first thing AH has to fix

## AH - The Cloud, and the room you remember it from

Greg: *"the black mirror is crazy... i want you to make it a room on the phone
somewhat, when you check the pinboard then you can be in a room with a massive
mirror on the wall and a bed, and then you can turn to the conspiracy quest
board, and then to your right you can look into like a neuralink or some cloud
connect thing and see the tutorial like a cloud software and its like 'remember
the cloud' and you repair the fragments of the cloud of archival information
which is the tutorial software parts"*.

This is the answer to all of AG2 and it is a far better answer than a tooltip.
**The tutorial is a place, and getting it is a mechanic.** You do not read help;
you recover it, fragment by fragment, out of a thing that used to know
everything and has been decaying since before you arrived.

### AH1 - The room
- [ ] **AH1.1** Opening the Board puts you in a room rather than on a screen
- [ ] **AH1.2** A bed, a mirror the size of the wall, and the light of one window
- [ ] **AH1.3** Turn to the wall and the Board is there - the corkboard already built (L)
- [ ] **AH1.4** Turn right and the cloud terminal is there
- [ ] **AH1.5** The mirror shows your body, current, with everything done to it (pairs with N)
- [ ] **AH1.6** The room is yours and it accumulates - what you leave in it stays
- [ ] **AH1.7** Leaving is a movement, not a menu close

### AH2 - REMEMBER THE CLOUD
- [ ] **AH2.1** The cloud is an archive of everything the world used to know, in fragments
- [ ] **AH2.2** A fragment is repaired, not unlocked - the verb is restoration
- [ ] **AH2.3** Repairing one costs something the player actually has
- [ ] **AH2.4** What you recover is a real game mechanic explained, not lore
- [ ] **AH2.5** The archive is visibly incomplete forever - you never finish it
- [ ] **AH2.6** It talks like cloud software written by people who are now dead

### AH3 - The tutorial web
Greg: *"a big node web tutorial that slowly gets unlocked alongside the board...
a little CRT TV animation and its curved on the TV of the game mechanic as a
little video with a description + it shows the controls"*.
- [ ] **AH3.1** A node web, not a list - the connections mean something
- [ ] **AH3.2** Each node is a CRT set, curved, with scanlines and a real tube falloff
- [ ] **AH3.3** The screen plays the mechanic as a short loop, drawn rather than recorded
- [ ] **AH3.4** Under it: what it is, in one paragraph, in the game's voice
- [ ] **AH3.5** And the keys, which is the part AG2 was actually asking for
- [ ] **AH3.6** Nodes unlock alongside the Board, from what you have actually done
- [ ] **AH3.7** A locked node shows static and the shape of what is missing
- [ ] **AH3.8** Every mechanic in the game has a node, including ones you have not met

## AI - The pyramid, and what is under it

Greg sent three reference charts - the occult hierarchy pyramid, *Hierarchy of
the Old World*, and the gods/demigods/mortals stack - with one instruction:
*"the pyramid structure in the tab map and everything needs to be rework with
this inspiration... also the pyramids should be like upside down and then up
top"*.

Two pyramids meeting at a point. Upright above, inverted below. **As above, so
below** - which is not decoration here, it is the two-axis system the game
already has: AA hands a holding to the ascent or to corruption, and those are
the two cones. The player stands at the waist, where they touch.

### AI1 - The shape
- [ ] **AI1.1** The Tree page becomes a double pyramid, upright above and inverted below
- [ ] **AI1.2** The waist is where the player is, and it is the only tier you occupy
- [ ] **AI1.3** Tiers are drawn as strata with real edges, not a list with indentation
- [ ] **AI1.4** The upper cone is the ascent: what is above you and what it demands
- [ ] **AI1.5** The lower cone is corruption: what is under you and what it is owed
- [ ] **AI1.6** Density carries meaning - the base is crowded, the apex is one thing
- [ ] **AI1.7** Legible at a glance and rewarding an hour of reading; the references do both

### AI2 - What it charts
- [ ] **AI2.1** Every tier is populated from WorldHistory, not authored - who is actually above you
- [ ] **AI2.2** Factions sit where their power is, and they move
- [ ] **AI2.3** Your own position is computed, and it changes
- [ ] **AI2.4** The Board's theories pin onto the pyramid - the two charts are one document
- [ ] **AI2.5** Satire aims at institutions and never at congregations
- [ ] **AI2.6** Marginalia in the corners, the way the references carry it

## AJ - Chaos magick, v2

Greg: *"the magic system using sigils and the new and improved chaos magick v2,
name work in progress, but a sigil and magic system app or whatever
intertwined... a magic system through the game or inbuilt progress of skills
that within the magic its kind of a playground for ideas, and if we built a
perfect magic system it would be insanely cool, and the occult influence being
based off real world everything would be sick, especially with getting modern
gods that are worshipped"*.

`celloutz_type.gd` already carries `seal_strokes`, `draw_seal`,
`draw_seal_forming`, `draw_seal_corrupted` and `draw_seal_burning` - a complete
procedural sigil engine that has only ever drawn decoration. This section points
it at a mechanic.

Why chaos magick is the right tradition to build on rather than an invented one:
**sigilisation is already a procedure.** State the intent, strip the repeating
letters, condense what is left into a glyph, charge it, forget it. Five real
steps, which are five real game verbs, and not one of them had to be made up.

### AJ1 - Making a sigil
- [ ] **AJ1.1** State an intent, in the player's own words
- [ ] **AJ1.2** The letters are stripped and condensed on screen - you watch it become a glyph
- [ ] **AJ1.3** The glyph is deterministic from the intent: the same words make the same sigil, always
- [ ] **AJ1.4** Charging costs something real - blood, stamina, a drug, a death
- [ ] **AJ1.5** Forgetting is mechanical: a charged sigil you keep looking at does not fire
- [ ] **AJ1.6** It goes into the world as an object - scratched, burned, carried or worn

### AJ2 - What a sigil does
- [ ] **AJ2.1** Effects come from the intent, parsed, not from a spell list
- [ ] **AJ2.2** A sigil can fail, and a failed one leaves something behind
- [ ] **AJ2.3** The same glyph gets stronger the more it has worked
- [ ] **AJ2.4** Other people's sigils exist in the world and can be read, defaced or stolen
- [ ] **AJ2.5** Corruption is what happens when you charge more than you can carry (AI1.5)

### AJ3 - Modern gods
- [x] **AJ3.1** The gods of this world are what is actually worshipped: markets, metrics, engagement, brands — `systems/modern_gods.gd`: The Engagement, The Market, The Quota, The Brand
- [x] **AJ3.2** A god is a real entity in WorldHistory with attention, not a flavour label — `kind: "god"`, real `attention` field, same shape `ascent_entities.gd` already proved
- [~] **AJ3.3** Worship is measurable (`attention` accumulates on every verdict asked) — feeding the upper cone (AI1.4) is a UI/pyramid concern, not attempted here
- [~] **AJ3.4** Naming a god in an intent gets their attention, which is not always wanted — `get_attention()` exists and accumulates, but AJ1 (intents/sigils) doesn't exist yet to call it; same relationship `ritual_app.gd` has to seals it doesn't draw
- [x] **AJ3.5** The target is always the institution, never the congregation — satisfied by construction: all four gods are markets/metrics/labor/image, never a person or a people

### AJ4 - Magic as progression
- [ ] **AJ4.1** Skill is what you have actually done, read off the record
- [ ] **AJ4.2** No skill tree - the pyramid (AI) is the tree, and you climb it
- [ ] **AJ4.3** A practice you stop practising decays
- [ ] **AJ4.4** Every system in the game is reachable through a sigil, badly
- [ ] **AJ4.5** The playground rule: the system should surprise its own author

### AJ5 - The verdict on a kill
Greg: *"the killing and fighting the npc system should be made so that if you
kill some people permanently you get told by the gods if killing them was a good
thing or if you forced them back into samsara, like 'soul freed' or 'cyclicist
enslavement again...' - so its like freeing them of the shackles of the 3d
world"*.

This is the missing half of the resolution window - the one thing in the whole
build the playtester reacted to hardest (*"ok they just fell down, and I could
choose, omg"*). You already decide what happens to a body. Nothing ever tells
you what it meant, and a game with an explicit cosmology owes the player that.

The rule that keeps it from being a morality score: **the gods disagree with
each other, and they are not reliable.** A verdict is one god's opinion, marked
as such, and a different god will read the same kill the other way.

- [x] **AJ5.1** A permanent death gets a verdict, delivered by a named god (AJ3) — `verdict()`/`record_death_verdicts()`; wiring the actual call into wherever a kill is finalized (Codex's defeat/resolution territory) is not done here
- [x] **AJ5.2** SOUL FREED and CYCLICIST ENSLAVEMENT AGAIN are the two poles, with room between — reuses `tree_alignment()` directly: dying deep in Descent reads as freed, dying mid-Ascent reads as enslaved again, and the raw continuous `lean` is returned alongside the label rather than only a binary text
- [x] **AJ5.3** The verdict is computed from the kill: how, where, by whose hand, and what they were carrying — `details` (`witnessed`, `harvested`, `contracted`, `public`), each god reading a different one of them
- [x] **AJ5.4** Gods disagree. Two verdicts on one death is a normal outcome — verified: the exact same death, asked of two gods, produces opposite labels
- [x] **AJ5.5** It is an opinion, not a score - nothing in the game adds them up — each god's verdict is returned and recorded separately; nothing sums them
- [ ] **AJ5.6** Freeing souls and enslaving them both have consequences, and they are different ones — not built: a verdict is currently read-only, with no differentiated mechanical effect on the world yet
- [x] **AJ5.7** It is recorded in WorldHistory, so the Board can pin it and the pyramid can read it — one `death_verdict` event per god's opinion. Covered by `tests/modern_gods_test.gd` (19 checks)

## AM - The build sheet becomes the map

Greg: *"this all links back to updating checklist ui and making a massive
worldmap tree hierarchy of the game mechanics so its super vibe coded and in
depth, highlighting visual examples of all the best mechanics, image examples
and controls, and making it heavy on the tutorial - seamless understanding of
the game's movement, crouching, sprinting, all the sliding movement aspects, the
hand fighting, the weapons, shooting"*.

The published sheet is a list of sections with tick boxes. It should be the same
double-pyramid the game's own Tree page is becoming (AI), with every mechanic
sitting where it belongs in the hierarchy, showing what it does and which key
does it. One document, two renderings: this one for Greg and whoever he sends it
to, the in-game one for the player.

- [ ] **AM1.1** The sheet is a hierarchy, not a list of sections
- [ ] **AM1.2** Same double-pyramid shape as AI, so the two never drift apart
- [ ] **AM1.3** Every mechanic shows its controls
- [ ] **AM1.4** Visual examples, not descriptions of visual examples
- [ ] **AM1.5** Movement gets the depth Greg keeps asking for: crouch, sprint, slide, vault, wall run
- [ ] **AM1.6** Hand fighting, weapons and shooting get the same
- [ ] **AM1.7** It reads as a tutorial somebody could learn the game from
- [ ] **AM1.8** Generated from CHECKLIST.md, so it cannot go stale

## AK - The agency that owns the sky

Greg: *"maps like this and insane esoteric knowledge would be really cool, again
linking back to the satellite and map part, but i wanted to add a satanic or
evil version of NASA that owns your phone's satellite app and you have to do
things on the map too for them or against them to change the map"*, with the
*Great Awakening* chart attached as the register to aim at - and then,
immediately after: *"not as much qanon shit but just black magick ect and chaos
magick"*. That second message is the one that governs. What is worth taking
from those charts is the **density**: hand-lettered, unsourced, confident,
thousands of connections drawn by somebody who was certain. What is not worth
taking is the payload - the named-people accusations and the trafficking
material, which is somebody's real-world harm rather than a game's texture. So
the chart look stays and the subject becomes the occult: black magick, chaos
magick, and an agency that treats both as procurement.

This is the missing owner of A10. The satellite view works and belongs to
nobody, which makes it a feature rather than a relationship. Give it a landlord
and every map interaction becomes a transaction with something that is watching
you back.

### AK1 - Whose satellite it is
- [ ] **AK1.1** The satellite app has an owner, named, with a logo and a licence agreement
- [ ] **AK1.2** They see what you see - using the map is being seen using the map
- [ ] **AK1.3** Standing with them is a real quantity and it moves
- [ ] **AK1.4** They give you work, on the map, and the work changes the map
- [ ] **AK1.5** You can work against them, and the sky gets worse for you when you do
- [ ] **AK1.6** Losing them costs the satellite: back to a paper chart (A10 degrades, it does not vanish)
- [ ] **AK1.7** They are an institution and the satire stays pointed at institutions

### AK2 - The esoteric chart register
- [ ] **AK2.1** Their briefings read like the charts: dense, hand-lettered, confident, unsourced
- [ ] **AK2.2** Some of what they tell you is true, and the game never says which
- [ ] **AK2.3** Their claims pin onto the Board like anybody else's (L)
- [ ] **AK2.4** Their version of the world sits on the pyramid, near the top (AI2.1)
- [ ] **AK2.5** Two records: what the satellite saw, and what they published about it
- [ ] **AK2.6** The subject is occult, never the real-world conspiracy canon it borrows its density from

## AL - The bank, and what runs under the street

Greg: *"same with the ingame bank system and having underground sewer and tunnel
networks alluding to trafficking and global conspiracys are really cool"* -
read alongside his correction one message later, *"not as much qanon shit but
just black magick ect and chaos magick"*.

Taken together the brief is clear, and the game already has the honest version
of it. **This world's contraband is bodies, and that is not an allegation, it is
the economy the game has been running since B.** CARRY holds organs. The Choir
prices them. Liens are debts secured against parts of people. A bank in this
world is not a metaphor for anything - it is the institution that writes those
liens, and the tunnels are how the collateral moves.

So: no real-world trafficking allegory. The tunnels serve the organ trade the
game already simulates, the bank is the institution that made that trade
legitimate, and the conspiracy is the ordinary one - an institution doing
paperwork over things that used to be people.

### AL1 - The bank
- [ ] **AL1.1** Money exists as a real quantity with a real issuer
- [ ] **AL1.2** The bank writes the liens the Choir already prices (CARRY, B)
- [ ] **AL1.3** A debt is secured against something of yours, named, and they will take it
- [ ] **AL1.4** Accounts, in a building, that you can walk into and rob
- [ ] **AL1.5** Interest accrues in game time, and it does not stop while you are away
- [ ] **AL1.6** They are an institution: the satire lands on the paperwork, not on debtors
- [ ] **AL1.7** Default has a collector, and the collector is a person with a body (F)

### AL2 - The network under it
- [ ] **AL2.1** A sewer and tunnel layer under the region, connected and navigable
- [ ] **AL2.2** It is how the collateral moves - the organ trade has a route
- [ ] **AL2.3** Entrances are found, not marked: a grate you noticed is a route you own
- [ ] **AL2.4** Down there the satellite cannot see you (AK1.2), which is the point
- [ ] **AL2.5** It connects holdings that are not connected above ground (AA)
- [ ] **AL2.6** Raiding a vault from underneath is the best version of AB3
- [ ] **AL2.7** Sound behaves differently down there, and the game lets you hear that (G)

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
8. ~~**Working title:** keep *Allusions to Grandeur*, or move toward Greg's new
   candidate **wizardsonlyfoolz**?~~ **Answered 2026-09-12: Greg calls it
   *Wizards Only Fools***. `config/name` and every in-game title card
   (opening, derby HUD, showcase, trailer) now read it. The repo path, folder
   names and save-data identifiers keep *AllusionsTooGrandeur* — no reason to
   break the working tree or the other agent's worktree over a display name.
   `wizardsonlyfoolz` stays in-fiction as the ascending mage collective
   (`DESIGN/COSMOLOGY.md`); the overlap with the cover title is intentional.
