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
- **v10 is the ceiling.** Greg: *"do a rework up to v10"*. Not because a
  mechanic cannot improve past it, but because a system with no end condition
  is a treadmill. Anything still earning versions at v10 is the best thing in
  the game and should be left alone. The ladders that reach it are the ones the
  rework gave ten real faults to; most sections stop far earlier and that is
  still correct.
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
| 7 | ~~**G6.1–G6.3**~~ `DONE` | The opening carries the first ten minutes. |

Everything else is depth on top of that spine. When those seven are checked, the
game is playable end to end and the rest is making it good.

**All seven are now checked, and this table was the last thing to find out.**
It sat with row 7 open while G6.1, G6.2 and G6.3 had been struck through in
section G — a hand-maintained view of something that kept moving underneath it,
which is the same failure mode as any cached value nobody invalidates. Before
trusting a row here, check the section it names; this table is a summary, and
the sections are the source.

`tests/loop_smoke_test.tscn` is what checks the claim rather than restating it.
It reads the scene graph out of the source at run time — every transition goes
through `Interstitial.travel`, so the whole graph is one regex away — and
asserts that every door leads to a scene that exists and loads, and that a
stranger can reach the hunt from the front door. It found one thing:

> **`bone_yard_hunt.gd` has no exit transition of any kind.** You can enter the
> Bone Yard and the only way out is the pause gate, which abandons the run
> rather than finishing it. The spine reaches the game; it does not yet come
> back. That is downstream of T, which is blocked on *what persists between
> runs* — so this is a known gap rather than an oversight, and it is the first
> thing the demo (P) will hit.

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
- [x] **A10.7** It lives in the handheld's MAP page, so it is the black mirror looking down — the satellite was built and worked anywhere a scene called `LivingMap.attach_world` itself. The device never did: `HandheldDevice.bind` passed the generator to the map's own `bind` and stopped, so reaching the map through the thing you actually hold left `satellite` null, `_satellite_ready()` false, and the mirror drawing the A6 chart on a dark plate while the satellite worked fine everywhere else. One call, and nothing said so. `_attach_map_world()` now hands the world down at `bind` and retries on every page open, because a device built before its region has no world to take yet. Leaving MAP also calls `close_map()` — A10.8 was true of the map and not of the device, which only ever set `visible`, so the camera kept rendering behind the WIRE page. Nine assertions in `tests/handheld_satellite_test.gd`
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

- [x] **A1.6** `v2` The stencil has no kerning pairs — every letter sits on the grid, so AV and TA gap — fixed by measurement rather than a table: the face is cut into eight bands, and a pair closes by the smallest clearance any band has. AV, TA, AT and VA all close 1.56 grid units; HH, OO and MN close nothing, because vertical-sided letters have no hole. Correct by construction whenever a glyph is edited
- [x] **A1.7** `v2` The face could not be set into a column — no wrapping, no alignment, no clipping, and eleven characters the screens were already drawing that it had no glyph for. All three gaps are now on `CellOutzType` itself: `wrap_condensed()`, `draw_condensed_aligned()`, `draw_block()` and `fit_condensed()`, with `living_map.gd`'s private `_wrap_condensed()` folded into the shared one so there is one wrapper rather than one per screen. The glyphs matter more than they sound: an unset character in this face is **not** a missing-character box — `draw_text()` skips it and still advances the cursor, so it prints as a hole exactly one letter wide, invisible in review and only catchable in a screenshot. That is the bug A10.9's own notes already record being hit twice (the crest's em-dashes, the weapon well's `×`) and worked around by rewriting the copy; this fixes the cause instead. Which characters were missing was counted off the real `draw_string` call sites — interpunct 12 uses, em dash 7, underscore 7, then the backslash, the four arrows and the two directional quotes — and `type_layout_test` re-reads those call sites on every run and fails if any character they pass has no glyph, so the check cannot go stale the way a hand-written list would. 31/31 green. **Looking at it caught what the data did not**: the horizontal arrowheads were the obvious mirror of the vertical ones and read as a plus sign under the condensed cut, which squeezes x to 0.68 and leaves y alone; reshaped wider and shallower. Honestly still open — at 12px condensed any arrow in this face is about five pixels wide and `←` is the weakest glyph on the specimen sheet; that is the condensed cut's size floor, not a stroke that can be redrawn out of it. The thirteen screens themselves are **not** converted here: this pass builds the infrastructure that made converting them a layout hazard, and `world_index.gd` alone is 49 `draw_string` calls leaning on right-alignment and wrap widths, which is its own pass. Specimen sheet at `captures/a1_7_type_specimen.png`
- [x] **A1.8** `v2` The cold open's photograph was a hard-edged rectangle sitting in black, which is the single thing making it read as a pasted image rather than as a screen — `splash_attack.gdshader` ends on a binary `step()` mask used directly as alpha, so there is no feather at all. Greg asked for three things in one breath — a border of "3d visceral organs bloody ect but regal", "edges blended and more different and gamified", and "curving on the screen to make a alien futuristic hud but still playabile" — and they are one problem, the edge of the picture, so they are one object: `RegalFrame` + `shaders/regal_frame.gdshader`, a sibling pass that paints *over* the seam rather than an edit to the photo shader (several agents are in the cold open at once; a sibling cannot collide with them). The idea that makes "visceral" and "regal" coexist rather than cancel: the vasculature is **mirrored about each side's midpoint**. Asymmetric viscera reads as a wound; the moment it is exactly symmetric it reads as heraldry — a coat of arms cut out of an animal — and exact symmetry is cheap in a shader and near-impossible by hand. Three variants (`reliquary`, `offering`, `ossuary`) as Greg asked for variants to play with. **Four defects found only by rendering it**, none of which the code showed: bead-and-reel highlights across the band read as a **barcode**, so the ornament moved from stripes-on-the-band to a lobed *silhouette* — a cartouche is recognisable from its outline alone, and a lobed margin is also what an organ's edge looks like; the additive subsurface and specular terms made it **glow like neon** rather than read as tissue, so both were cut to roughly a third and the base colours dropped well below the reds in the photograph, which also puts the frame behind the picture in depth where a mount belongs; `half_size` multiplied `opening.x` by the aspect ratio when `fit_to_photo` already passes x in aspect-corrected units, making a 1.035-wide opening 0.92 against a screen half-width of 0.888 and pushing **both side runs off the screen**; and `ossuary`'s deliberately thin band **leaked the rectangle straight back**, because the photograph's edge sits a fixed distance out from the opening and a short band drops that edge into the ragged dissolve instead of under solid ornament — restraint there has to come from colour, not from running the band short. Honestly still open: **"regal" is the under-delivered half.** It reads as dark wet tissue, which is right, but as organic *mist* more than as carved heraldic swags — the lobes are soft and the bone rule is barely visible at this scale. The curvature uniform exists and is deliberately tiny (0.045) because Greg asked for curvature and "still playable" in the same sentence, and it is nowhere near the CRT bulge he described; the stop-motion/CRT-degradation switching between his two images is **not** built here at all. And it is **not wired into the cold open yet** — it is a verified standalone with a one-call hookup, left unwired because `boot_splash.gd` was being edited by another agent minutes earlier. Verified by eye on `reliquary` and `ossuary` over the real backdrop mid-attack; captures at `captures/a1_8_frame_{off,reliquary,offering,ossuary}.png`, with the frame-off shot kept deliberately so the original hard cut is on record beside the fix rather than described
- [x] **A1.9** `v2` The glass the cold open is seen through — `CrtGlass` + `shaders/crt_glass.gdshader`. Greg asked for "curving on the screen to make a alien futuristic hud but still playabile and seamless" and for "2 images switching with slow degradation of crt distrortion through like stop mootiuion", and named that he already has CRT plugins for After Effects and TouchDesigner. Done live anyway, for the same three reasons `splash_attack.gdshader` gives for not baking the invert: the curvature fits the window it is actually running in rather than the frame size a render was exported at, the degradation becomes a **dial something else can drive** instead of a fixed timeline, and it survives the picture underneath being swapped. **The design is pinned by the second half of his own sentence.** A faithful CRT geometry bows straight lines about 8% and eats the corners — wonderful over a photograph, hostile over a menu you are reading. So the glass is added to the *backdrop* canvas, under the readable layer: the picture curves, the words on top of it do not, and in the menu the type lives on `$HUD`, a different canvas entirely, so it never enters the warp at all. That compromise is what makes this shippable rather than the first thing turned off in settings. Everything scales off one `degrade` uniform, and `surge()` ramps it into a beat and settles it after — the tube struggles as the authored invert tears across and recovers once it lands, which is what makes distortion *information* rather than wallpaper; a constant level stops being read after ten seconds. The stop-motion register is quantised, not smooth: the vertical hold jumps to a new offset and **holds** for a beat rather than drifting, because interpolating between offsets reads as underwater rather than as broken, and only some steps slip at all — a permanent offset is just a misaligned picture, the failure is that it is intermittent. Scanlines are strongest in the mid-tones and blow through the highlights the way a real tube does, rather than sitting flat over everything like a screen-door texture. Four registers: `flat` (off but still sampling, so a scene can tween *to* the others without popping the shader on), `panel` (the shippable default), `aperture` (Greg's alien-HUD end — more bow, more glow), `failing` (the surge target). Verified by eye on `panel`, `aperture` and `failing` over the real backdrop and frame with menu-sized type laid over the top, since "still playable" is exactly the half only a rendered frame can settle; captures at `captures/a1_9_glass_{flat,panel,aperture,failing}.png`. Wired into both the boot splash and the menu. The menu needed a second pass, and the finding is worth keeping: built onto the backdrop canvas it **silently lost its geometry**. The colour half — bloom, scanlines, aberration — landed correctly, so it looked like it was simply tuned subtle; forcing the `failing` register to check proved otherwise, because the photograph stayed a dead-straight rectangle where the standalone harness bowed the same shader hard enough to open black wedges in the corners. That canvas is the 3D background via `BG_CANVAS`, so a screen-texture read inside it sees its own canvas rather than the composited frame, and warping the sample of something about to be re-projected warps nothing. **A half-working shader that fails only in its geometry is the dangerous kind** — nothing errors and the remaining half is plausible enough to ship. Fixed by giving the glass its own `CanvasLayer` at -50, above the backdrop and the 3D world and below every readable canvas: it now samples what has actually been drawn, so the room *and* the street and the bodies in front of it curve together rather than a flat picture sitting behind curved nothing, and `$HUD` at layer 0 still never enters the warp. Confirmed by re-probing `aperture` in the live menu — the whole tableau bows and the menu type stays crisp. The image *switching* itself is unchanged — this degrades the switch, it does not restage it
- [x] ~~**A2.9** `v2` One plate for every page; the dossier, the Wire and the
      pyramid should not be printed on the same substrate~~ `_draw_plate()`
      grimed the same paper under FILE, PYRAMID, BODY and WIRE alike. The
      physical registry (the notched shape, the tabs, the tape) stays one
      shared object on purpose — that is what A0's "one made object" already
      asked for — but WIRE now prints on `black_mirror.gd`'s black glass
      instead of paper grime, since that page reads the surviving internet
      and nothing else here is a screen. Verified:
      `tests/index_substrate_test.gd` (new, 2/2 — samples the same patch of
      the plate on FILE and on WIRE and confirms it is both visibly
      different and darker; needs a real window, since headless rendering in
      this environment reads back a blank frame), plus the existing
      `index_wire_glow_test.gd`, `index_link_rebuild_test.gd`, `link_test.gd`,
      `celloutz_site_test.gd` and `clerical_audit_test.gd` regression suites,
      and a windowed capture (`captures/a2_9_v2_index_file_paper.png` /
      `a2_9_v2_index_wire_glass.png`).
- [x] **A5.6** `v2` Grunge is seeded per screen and identical every session — it should remember the run it is in — `WorldHistory.run_salt`, generated once per save and mixed into every seed. Still perfectly still frame to frame; two runs simply wear differently. Old saves and test mode stay at zero on purpose
- [x] **A6.6** `v2` Dead pixels and scanlines are static; a failing panel flickers — positions stay fixed, expression does not: each fault carries its own period, duty and phase, rows shear before they drop out, some pixels are stuck *on* rather than dead, and the backlight sags and drops. All of it off `condition`
- [ ] **A7.7** `v2` Retune the chassis against authored arena geometry once G3.1 lands
- [x] **A9.7** `v2` Stations have a schedule — the dial is the same at 3am as at noon — and it was blocked on the fact that this game had no time of day at all. `world_clock.gd` (W1.1) now exists and the dial is its first reader: noon is pit control and the numbers station, three in the morning is the preacher, the gate lantern loop and the numbers station. Off air is zero strength however close you stand, and the dial says when it comes back


### A v3 — the third pass
v2 fixed the face, the grime and the failing panels, and every one of those fixes was looked at in daylight. The rework says light *warps and distorts* at night, and nothing in A has ever been seen in the dark.
- [x] **A3.1** `v3` Every surface A built is judged again after dark, not just dimmed — judged after dark it turned out the world was not even dimmed, only half dimmed: `_update_day_night` drove the sun, the ambient and the exposure, and nothing at all drove the sky. A capture at 01:00 and one at noon came back with a pixel-identical horizon, the ground under it crushed to black, and the one sodium lamp in frame reading the same at both hours because it had a lit sky to compete with. `WorldLook.apply_hour()` now moves sky, fog and volumetric fog with `daylight()` as well, deriving night from each preset's own authored day colours rather than declaring a second palette somebody would have to keep in agreement with the first. Captured at noon, 19:30 and 01:00 (`captures/a3_1_v3_hour_noon/dusk/night.png`, `tests/night_surface_capture.tscn`) — the harness's original 18:00 shot was a second noon, since `daylight()` holds at 1.0 until 18.5
- [x] **A3.2** `v3` Warping is a property of the light, not a post-process on the whole frame — `systems/light_warp.gd` and `shaders/light_warp.gdshader`: a shell of real geometry parented to each of the nine Ashbloom sodium lamps, sized to that lamp's own `omni_range`, displacing only the screen it actually covers and scaled by `1.0 - daylight()`. AS2.1 built this as a dial on the fullscreen psychedelic shader, which warped the sky, the ground and the open index — none of which are light — left the lamps that *are* light rendering exactly as they do at noon, and spent the one dial the game reserves for being on something. Two faults found by capture and fixed here: a falloff read from the fragment's distance to the lamp is constant across a shell that has no interior, so the first build discarded itself everywhere; and the chord through the sphere, which replaced it, reads long in every direction once the player stands among nine overlapping throws — the full-frame wobble again. The measure that behaves both inside and outside is the view ray's miss distance from the lamp. Verified off and on from one paused frame at 01:00, 9 shells attached (`captures/a3_2_v3_warp_off.png` / `a3_2_v3_warp_on.png`)

### A v4 — the fourth pass
v3 made night look different and there was almost no light in it to warp. A world lit only by an environment has nothing for v3 to act on.
- [x] **A4.1** `v4` Real light sources in the world at night, few and placed — the only lights in 470 by 370 metres were nine lamps in an arithmetic row, `-24 + index * 6`, eight metres apart at the origin: that is why v3's night read as one lit clearing with a black region around it rather than as a region after dark. They are places now rather than a loop (`GATE_LIGHTS`) — the pit gate, which is the only one that casts a shadow because it is the only one close enough for a shadow to be worth its cost, two along the road out, a pair over the wreck line, and one per settlement read from `AshbloomWorldGenerator.DISTRICT_CENTERS` so a district that moves takes its light with it instead of leaving a lamp over empty ground. All eleven come up at dusk and go out at dawn off `daylight()`; they used to burn at a constant energy around the clock, which is invisible at noon and means night never had a moment of coming on. Two faults the captures found and fixed: a light with no fixture is only its effect on what it reaches, which at any distance through this fog is nothing (the first build photographed a black region with five lights in it), so every lamp has an emissive bulb and a volumetric throw; and the first vantage framed a region whose districts sat outside a 78° FOV. Verified at 01:00 from the ground sixty metres out from the western settlement (`captures/a4_1_v4_settlement_glow.png`) and at the gate (`a4_1_v4_gate_night.png`)
- [x] **A4.2** `v4` The handheld is one of them (AS1.1), and the first thing v3 warps — `LightWarp.attach()` takes any `Light3D` now, and the handheld spot carries a shell like every placed lamp, driven off its own battery in `_update_handheld_lamp()` rather than off the hour: a guttering torch bends the air in the same stutter it lights with, and a dark beam leaves still air. Two shapes of light needed two measures rather than one. A lamp out in the world is walked past, so the view ray's distance from it is the right question; a light carried at the eye is never walked past — every ray leaves from it, that distance is always nothing, and the measure saturates straight back into the full-frame wobble v3 removed. A spot is measured instead as the angle off its own beam against `cos(spot_angle)`: the cone it actually fills, seen from the only place this game's one spot is ever seen from. Its shell is small and close (`CARRIED_SHELL`, 0.6m) so nothing short of something touching the camera can cut between the light and its own air at the depth test. Verified off and on from one paused frame at 01:00, with the device's panel faded for the photograph only — raising it is what lights the torch (`captures/a4_2_v4_torch_off.png` / `a4_2_v4_torch_on.png`)

### A v5 — the fifth pass
v4 put light into the dark and every surface answered it identically. Greg: *"working shaders and reimbursing the biopunk touch"*.
- [x] **A5.1** `v5` Flesh, scrap, rust and glass answer light differently — a kind was two scalars and a pattern up to v4, so the world was one material wearing six colours and every surface returned a lamp with the same highlight. Each kind now differs in *how* it returns light rather than in what colour it is: brushed anisotropy on chrome, so salvaged plate smears a highlight along its grain instead of holding a round spot; subsurface scattering and a backlight on flesh; a backlight on bone; a real `glass` kind, which A5.1 names and the game did not have — `smoked_glass` was remapped onto chrome, so every window in the world was a mirror — transparent, sharply specular and slightly refractive; and near-zero specular on dirt, which had been carrying a sheen under every lamp and reading as wet concrete. Verified by `tests/material_chart.tscn`, one sphere per kind, shot with a key lamp (`captures/a5_1_v5_chart_keylit.png`) and with the lamp *behind* the row (`a5_1_v5_chart_backlit.png`) — the only exposure that can tell meat from plaster, and the condition nothing in this project had ever been lit from. Three faults the chart found: Godot's transmittance is computed from the shadow map and stayed invisible on a limb-sized body at every depth and boost tried, so the wrap-through is `backlight`, which is the engine's supported path; backlight is multiplied by the shadow term, so a sphere shadows its own front from a lamp behind it and the one material that should glow photographed black until that light's shadows came off; and the chart's own first rig ran a 7-energy lamp three metres from albedo that runs 0.025 to 0.3, which drove the whole row to paper white
- [x] **A5.2** `v5` Contamination reads as a material property rather than a tint — it was painted into the albedo and nothing else, while the roughness map was `_noise(scale)`: unrelated noise, the same field for every kind. A rust bloom and the clean plate beside it therefore returned a lamp identically, and the contamination existed only in daylight, as a stain. `_contamination()` is `_surface_maps()` now and the one field that decides where the growth is also decides how that patch answers light — bloom is wet and takes a tighter highlight (alpha drives roughness), and the living part of the surface is the only part that emits, in its own growth colour rather than a house green. Found on the way: Godot's default emission operator is ADD, which computes `(emission + texture) * energy`, so a white emission colour lit every texel in the world to mid grey and read as fog — it is MULTIPLY now, and the map alone decides what burns. Verified with every lamp switched off, where a tint photographs as nothing and this does not (`captures/a5_2_v5_chart_bloom.png`), and in the world at noon, where the wrecks carry visible growth instead of flat brown (`a5_2_v5_world_noon.png`)

### A v6 — the sixth pass
v5 made the ground materially believable and left the sky a box. AO2.1 says the firmament is broken and it has never been drawn as broken.
- [x] **A6.1** `v6` The firmament is visibly broken rather than a gradient — THE_REWORK §1 says *"the sky is broken"* and for five passes it was a `ProceduralSkyMaterial`: two colours and a sun disc, the one surface in this game that had never been asked to say anything, and the one thing a broken sky cannot be. `shaders/firmament.gdshader` draws the dome now, keeping the same two colours `apply_hour()` already drove so none of v3's day/night work is thrown away, and carrying the fracture across it — a web of joins generated in `world_look.gd` beside the contamination maps and sampled in three dimensions off the direction vector, which removes both the seam behind the player and the pinch at the poles that an equirect field gets for free. Two faults found by measurement: Godot's cellular distance2-minus-distance1 never approaches zero on a cell boundary (it runs 0.33 to 0.99 over this sphere), so the obvious "near the join" threshold could not fire and the first map generated was empty at every texel; and the lit edge, at a 0.35 floor, put a warm wash over the whole night dome and quietly undid A3.1. Verified at noon, with the harness reading the map the shader samples to find the most broken texel and turning the player to face it, since a fracture covering under a percent of the sky is not something a fixed heading finds by luck (`captures/a6_1_v6_firmament_noon.png`, `a6_1_v6_fracture_map.png`)
- [x] **A6.2** `v6` What is behind the break is not just more sky — Earth here is an industry and prison planet and the thing that ended it came from outside, so what shows through the tear is the outside of a shell somebody was kept under: the void, a stable starfield the atmosphere never shows, and the lattice of the firmament itself caught along the inside of the break. The stars fade out as the sky lights (`star_density` off `daylight()`), for the same reason you cannot see them through a lit window. One fault found: `fog_sky_affect` held at 0.6 around the clock, so the haze colour repainted the whole dome at every hour — the night sky photographed as a brown wash at roughly 0.15 whatever the sky's own energy was, and nothing behind the break could be seen through it. Fog is lit by the sun, so with the sun gone it now largely stops painting (`captures/a6_2_v6_firmament_night.png`)

### A v7 — the seventh pass
v6 broke the sky open and put nothing behind it. AO2.2: a god for each planet, the moon and the sun, visible at certain hours.
- [x] **A7.1** `v7` The gods are up there and `WorldClock.hour()` decides when — `systems/gods.gd`: nine bodies, one per planet plus the moon and the sun, each with its own hour window, its own fixed quarter of the sky and its own colour, so after a few nights a player knows where to look and when. That fixedness is the whole point — a god that could appear anywhere at any time teaches nobody anything, and the sky in this game is a clock face with these as the numbers on it. The hours are read from `WorldClock.hour()` rather than a timer or a roll, windows that cross midnight are handled as windows that cross midnight, and each one fades in over its first half hour so a god arrives rather than being switched on. They are drawn in the same firmament shader v6 built, three slots deep (a sky with everything in it at once is a planetarium, not an omen), as a body with a brightening limb and drifting bands rather than a disc — and added over the dome rather than into it, since a thing that size is not hidden by the shell it is bigger than. Verified at 13:00, where exactly one is up, and at 02:00, where five are (`captures/a7_1_v7_furnace_noon.png`, `a7_1_v7_gods_night.png`)
- [x] **A7.2** `v7` Seeing one is an event the world records, not decoration — a sighting needs the god near the middle of the frame for a second and a half, so glancing past one while running does not make you a witness, and it is recorded once per god per day: the Witness is up every night and a world that wrote that down nightly would be recording the weather. It goes into `WorldHistory.record_event("god_seen", ...)` with the body, its prayer, the day and the stamp, and — this is the part that makes it not decoration — `god_seen` is in `CHAOS_MAGICK` at 0.05, a third of a completed ritual, so looking up feeds the same charge the ritual system already drains and storms already read. The scene answers on the status line rather than with a bespoke banner, because what this world does with an omen is note it and carry on. Verified by event count across two hours in `tests/night_surface_capture.tscn`: one sighting at 13:00, a second at 02:00, and no repeat for a god already seen that day

### A v8 — the eighth pass
v7 made the sky the most interesting thing on screen, which is wrong when the player is a spirit in bright flame (AP2.2).
- [x] **A8.1** `v8` The undying flame is a real shader on the player, not an overlay — `systems/undying_flame.gd` and `shaders/undying_flame.gdshader`. It is a `material_overlay` on the player's own zone meshes, which is the whole distinction the segment is drawing: it follows every limb the anatomy moves, is occluded by whatever occludes the player, leaves with a limb that comes off, and is simply absent from a frame the player is not in — none of which a screen overlay can do. Overlay rather than override, so A5's flesh material underneath is untouched and a zone still answers light as flesh while it burns; additive and unshaded, because this is light leaving a person rather than light landing on one; fresnel-weighted, so the silhouette carries the tongues and a limb never goes dark between them. Driven by `anatomy.combat_ratio()` — the body failing is what lets the spirit show, so this is the one reading in the game that gets stronger the worse things are. Verified by taking the body apart for real rather than turning the dial: condition 1.00 to 0.15 across five hits, with the flame visibly climbing (`captures/a8_1_v8_flame_intact.png`, `a8_1_v8_flame_wrecked.png`, `a8_1_v8_flame_on_the_body.png`)
- [x] **A8.2** `v8` It genuinely melts the frame around it rather than tinting it — `shaders/flame_melt.gdshader`: a shell on the body displacing the screen behind it, using the ray-miss measure A3.2 arrived at, because a chord through the shell fails here the same way it failed there. What differs from a lamp is the character of it — this drags upward and tears rather than drifting, at an order more displacement, and scorches what it drags so the effect is legible on a dark frame, since a black pixel moved is still a black pixel. Strength is cubed off the same condition the flame reads, so an intact body burns without taking the frame with it. Two faults found by capture: the shell sat at the rig origin, which is between the feet, putting the melt in a puddle on the floor; and every framing in the Hunt Grounds at night puts the player against a lit wreck pile that is soft and warm on its own — a control frame with the shell hidden proved the smear in three attempts was that scenery and not this shader. Shot against `material_chart.tscn`'s flat backdrop instead, where the drag above a burning body is unmistakable (`captures/a8_2_v8_melt_off.png` / `a8_2_v8_melt_on.png`)

### A v9 — the ninth pass
v8 made the player luminous and the air between them and everything else is still clean. Contamination has weather (W1.2) and A has never drawn it.
- [x] **A9.1** `v9` The air carries contamination that moves and settles — `systems/contaminated_air.gd`. A5 made contamination a property of every surface; this is the same fact in the one place still missing, which is the space in between. The motes drift and sink rather than hang, because whatever is in this air came off something and is on its way down — barely falling, since dust at anything like real gravity reads as rain and this has been airborne since the world ended — with turbulence to keep it from falling in lines. They are lit rather than unshaded, which costs more and is the whole point: A4 put eleven lamps in the region and a torch in the player's hand, and air you cannot see until a light crosses it is the argument for both. The volume follows the player in six-metre steps rather than continuously, or the air travels with them instead of past them
- [x] **A9.2** `v9` Storm severity from AS4.2 is visible in the air before it is audible — AS4.2 itself is not built, but it says severity tracks chaos magick in `WorldHistory`, and that is live, so the air reads the number the storm will read rather than inventing a second source of truth: when AS4.2 lands it inherits an air already answering it. Severity moves everything you can see before anything makes a sound — how much is up, how fast, how hard it is pushed sideways, how dirty it looks, and the haze thickening behind it — eased into the fog rather than assigned, since `_update_day_night()` writes the same value off the hour and the two would fight frame by frame. Verified through the world rather than by setting the dial (anything written straight onto the node is gone by the next physics frame, which is the system being right): eight completed rituals took `chaos_magick()` 0.00 → 0.99, severity 0.00 → 0.99 and mote density 0.17 → 1.00 (`captures/a9_1_v9_air_calm.png`, `a9_2_v9_air_storm.png`)

### A v10 — the tenth pass
Nine passes of procedural surface, and none of it is Greg's own work. AP3.3: *"collaging my old and current art to use as textures intelligently"*.
- [x] **A10.1** `v10` Real collaged art from the collections folder, used as texture with intent — the pipeline has been laying down 34 derived sheets in `game/art/derived/` for three kinds, and until now they reached the index plates, the Wire and flesh detail: everywhere except the world the player walks through. They are posted bills now, on the district buildings. *With intent* is what decided the construction: a sheet fed through `_apply_grain()` as a triplanar detail layer would repeat across every wall in the region, which turns a collage into wallpaper and says nothing — so it is a quad at reading height, beside the door, on one building in three, sized like an actual bill rather than scaled to the wall (a poster that grows with its building is a decal, not an object), weathered down hard because it has been up a while in the air A9 just filled, and hung off square because nobody posting a bill uses a spirit level. The two thirds of buildings without one are what make the third mean anything. Verified at noon on a bill the harness found rather than one it assumed: 20 of 60 buildings carry one (`captures/a10_1_v10_posted_bill.png`)
- [x] **A10.2** `v10` It sits inside the procedural system rather than replacing it — the bill is an object added to a building the generator built, not a texture that displaces what the material system produces: the wall underneath keeps its procedural contamination, its roughness and its emission from A5, and the bill sits on it the way a real one sits on a real wall. `art_set.gd`'s rule holds all the way through — a worktree with no derived sheets, or a pipeline nobody has run, generates exactly the region it always did, because `ArtSet.pick()` returning null means no bill rather than a missing texture

- [x] **A10.3** `v10` The hour changes every material, not just the sky — from v3 onward the sky, the fog and the lamps all moved with the clock and the surfaces underneath them did not: a wall at midnight was lit differently and was otherwise the same material it had been at noon. Every material the look system makes is now weakly registered, and `apply_hour()` drives the one part of it that is alive — A5.2 made contamination the only thing on a surface that emits, and things that glow do it at night. In daylight the bloom is washed out the way real bioluminescence is; after dark it is the only thing on a wall giving anything back, which is what makes a lamp worth carrying past a wall rather than only into a room. Weak references so a freed wrecker's flesh can still be collected, and quantised to fiftieths so a sunset walks the registry a handful of times rather than sixty times a second (which is the cost A10.14 is about). Verified by reading a material rather than a picture: the same rust reads `emission_energy_multiplier` 0.126 at noon and 0.672 at 01:00. One fault found on the way — the quantised early-out meant a material created mid-run kept its daylight value until the clock next moved, so a wrecker spawned at one in the morning burned at 0.280 while every surface around it read 0.672; materials are born at the current hour now
- [x] **A10.4** `v10` Nothing in the world is lit by an ambient term nobody chose — the presets have carried an `ambient` per region since v1 and the Hunt Grounds ignored it: `_update_day_night()` drove `lerpf(0.16, 0.72, daylight)` for ambient and `lerpf(0.85, 1.18, daylight)` for exposure, four numbers typed into a scene, of which one happened to match the Ashbloom preset and three matched nothing at all. So the region the game spends most of its time in was lit by a term chosen by nobody, and any scene wanting the same night had to copy the same four numbers to get it. Both now come from `apply_hour()`, scaled off the preset's own `ambient` and `exposure`, which means a region's night is a property of that region and retuning one is a one-line change in a table rather than a hunt through scenes. `material_chart.tscn` keeps its own ambient *source* — a flat colour rather than the sky, because it is a chart and there is no sky in it — but takes the region's level (`captures/a10_4_v10_noon_after_ambient.png`)
- [x] **A10.5** `v10` Grain, grime and wear are generated, never painted in by hand — audited rather than asserted. Every field that grimes a surface in the running game comes out of `FastNoiseLite`: the contamination and response maps in `world_look.gd`, the warp flow in `light_warp.gd`, the flame in `undying_flame.gd`, the fracture in `firmament()`. The only images loaded anywhere near a world material are the two `.glb` kits and `prototype_lab/lab.gd`'s `polarity.webp`, which is a lab bench and not the game. Greg's collaged sheets are the deliberate exception A10.1 argues for — they are art posted on a wall, not wear painted onto one, and the wall underneath keeps its generated grime
- [x] **A10.6** `v10` A screenshot of any square metre reads as this game and no other — three ordinary square metres, chosen to be unphotogenic rather than flattering: a wreck face, the ground somebody walks on, and a district wall (`captures/a10_6_v10_metre_wreck.png`, `_metre_ground.png`, `_metre_wall.png`). This is a judgement and it is marked as one, but it rests on things that were measured rather than felt: every surface in frame carries generated contamination posterised to seven steps with panel seams and vertical weep through it (A5.2), answers light according to what it is made of (A5.1), sits in the hue band A10.7 measured at 0.059 to 0.076 across all three regions, and changes its emission with the hour (A10.3). What stops it reading as anybody else's game is the combination — banded PS1-era crunch on top of a physically-answering surface, under a sky with a hole in it — and no stock asset or store shader produces that set together. The honest limit: this is a claim about the look, not proof of it, and the only real test is somebody who has never seen the project being shown one frame
- [~] **A10.7** `v10` The palette holds under a storm, underground, and in the shadow realms — measured for two of the three, and "holds" is given a meaning that can be checked rather than described: the mean hue, saturation and value of a frame of the material chart, lit and shot under every preset the game has after dark. Ashbloom reads hue 0.059, sat 0.921, val 0.163; the Bone Yard 0.075 / 0.784 / 0.139; the ossuary — which is underground — 0.076 / 0.772 / 0.139. All three sit in the same narrow orange band with values within 0.02 of each other, so a region changes the temperature and the light without changing what family of colour the world is made of (`captures/a10_7_v10_palette_ashbloom.png`, `a10_7_v10_palette_ossuary.png`). The storm has a frame too, from A9.2. What is missing is the third condition: the shadow realms are named in three comments across `world_look.gd` and `bone_yard_hunt.gd` and do not exist as a scene, a preset or a system, so there is nothing to hold a palette under yet. When one is built it needs this same measurement and the same band
- [x] **A10.8** `v10` Contamination is a material property everywhere it appears — A5.2 made it one in `world_look.surface()`: a single generated field decides where the growth is, how rough that patch is and what it emits, and A10.3 put its emission on the clock. The "everywhere" half is an audit, and it passes — no scene, system or shader outside the material path draws contamination as a colour of its own. The green in the world comes from geometry that *is* contaminated (the fungal caps and pools the generator builds, carrying material from the same function), and the only other places the word appears are the map and the satellite view, which are readouts of the world rather than the world. `contaminated_air.gd` is the one addition since, and it takes its colour from the same palette and answers the same severity
- [x] **A10.9** `v10` The stencil face sets every plate, and body copy never uses it — audited on both halves. `CellOutzType` is called 332 times across some twenty systems — the HUD, the index, the map, the kill cam, the keys card, the radial menu, the pin board, the interstitial, the sigils — which is what "sets every plate" looks like in a project that draws its own type. The other half is the one that could quietly rot, and it has not: no string longer than 42 characters is drawn through the face anywhere in the codebase, and the `draw_string` calls that do exist are exactly what A1.3 said they would be — findings, notes, percentages and "NO BODY ON FILE." in a real font, at 9 to 14 points, where a stencil alphabet would be unreadable. `body_inspector.gd` runs both in one panel and is the pattern: the plate is drawn, the copy on it is typed. Audited by sampling rather than exhaustively, so a future plate that quietly uses a system font for its header would not be caught by this
- [x] **A10.10** `v10` Nothing renders correctly only at one distance — given a number rather than an opinion: the standard deviation of luminance across a fixed window of the same wall, shot at two and a half, eleven and forty-four metres. A surface that only works up close flattens toward a single colour as the mips take over, and a flat colour has no deviation. Relative deviation (deviation over mean) reads 1.08 at 2.5m, 1.16 at 11m and 2.32 at 44m — the generated contamination is still resolving structure at forty-four metres rather than washing out, which is the failure this segment names. One half of it this harness cannot answer: shimmer under motion is temporal and every capture here is a still frame, so a surface that crawls as the player walks would pass this test (`captures/a10_10_v10_wall_at_2m.png`, `a10_10_v10_wall_at_44m.png`)
- [ ] **A10.11** `v10` A surface somebody destroyed looks destroyed a month later — **blocked, and worth saying why rather than leaving it silent.** Nothing in this game can destroy a surface. Bodies come apart (`baseline_human.gd`), vehicles crumple (`rift_derby.gd`), and the world's geometry is generated from a seed and is not touched again: there are no decals, no scars, no impact marks and no code path anywhere that damages a wall. So this is not a look segment at all in its current form — the look half is perhaps an hour's work (a scar map on the material, aged off `WorldClock.month()`, which already exists), and it has nothing to draw until something can mark a surface in the first place. That belongs to whichever section owns destructible geometry, and this should follow it rather than lead it
- [x] **A10.12** `v10` The look survives the quantum restart looking like itself — the note this replaces said **blocked on the restart**, and it has been wrong since `systems/quantum_saves.gd` landed. The restart is there: `begin_new()` is the restart proper (history cleared, a fresh `run_salt`, the clock back to 16:30) and `enter()` crosses back into a branch that has been through a file on disk. So this is what the old note said it would be — a capture either side and a comparison, not a build: `tests/quantum_look_test.tscn`, 32/32, both directions. **Same salt across a restart:** a branch saved at 18:45 on the second day, left for a new world, then re-entered off disk, comes back with its interface grime, its cast, its materials, its palette, its region, the hour's effect on every surface and the player's wounded body all identical — and the sky back at the dusk it was saved at rather than the 16:30 a fresh world opens on. Dusk on purpose: `daylight()` is 0.81 there, so every clock-fed dial is caught mid-lerp, where a restore that rounded or defaulted the clock shows. **New salt:** the interfaces wear somewhere else and the world is populated by different people, while the materials, the palette after dark, the hour response and the region are unchanged — which is the half of *looking like itself* that a different world could break, and the half nothing was checking. One correction the old note needs, because it would mislead the next person: it claimed every surface, field and map in A is generated from a seed **and** a `run_salt`. Half true. The salt reaches the interface grime (`CellOutzGrunge._mix()`), the generated cast (`CastNames._seed_for()`) and the roamers seeded off both (`bone_yard_hunt.gd:5444`) — and nothing in the material path: `world_look.surface()` takes an explicit seed from its caller and the region takes a constant one (774013), so a new branch is the same city worn differently rather than a different city. Both halves are asserted, so wiring the salt into the region later fails here loudly rather than quietly shipping five cities. What the capture is, stated because it is not a screenshot: `--headless` has no framebuffer — probed rather than assumed, a headless viewport's `get_image()` returns null — so the comparison is taken one level up, off what the renderer would draw from. The generated contamination and response maps sampled on an 8×8 grid of each 96×96 map, the material scalars, the sky/fog/ambient/exposure dials, the region's every transform and lot, the seed and RNG stream every grime mark is placed from, the cast, and the saved body. Falsifiable rather than decorative, and tried three ways: removing `restore_snapshot()`'s `remember_run()` fails the grime layer, dropping the restored clock fails the sky, dropping the restored salt fails grime and cast. Not covered, and left uncovered on purpose — the rig's gore draws from the global RNG (`baseline_human.gd:587, 1026-1074`), so what is compared is the record the body is rebuilt from rather than a rebuilt body, and shader output, which no headless suite can see
- [x] **A10.13** `v10` Every effect is one shader with dials rather than a new shader — this one was failed by this very session before it was met. A8.2 shipped `flame_melt.gdshader`, which differed from `light_warp.gdshader` in four numbers and a direction and was otherwise the same measure, the same screen sample and the same falloff shape: exactly the habit the segment names. It is deleted. The displacement shader now carries the dials that make one shader serve both — `falloff` (squared for air off a lamp, cubed for tight around a body), `drag` (the upward pull that is the difference between a shimmer and something melting), `field_scale` and `field_rate` (weather, or a body coming apart), and `tint_add` (a lamp bending air should not brighten it; a body failing must, or the displacement is invisible on a dark frame). Seven shaders to six, with the flame's melt verified unchanged after the merge (`captures/a10_13_v10_one_shader_two_dials.png`)
- [~] **A10.14** `v10` Performance is part of the look: nothing here costs more than it earns — the harness to answer this is built (`tests/night_surface_capture.tscn` toggles the air, the warp shells and the flame's melt one at a time at 01:00, with everything else running, and averages script time over 150 frames) and it cannot currently answer it. Measured twice in the same configuration the same scene reported 19.9ms and 39.97ms of process time, a factor of two apart, and an earlier cumulative version reported a scene getting *faster* as systems were switched on. The number that is solid: 2,514 draw calls at 01:00 with every system of v3 through v10 running. What this needs is a quiet machine — a second Godot was running another agent's test suite throughout — and GPU frame time rather than `TIME_PROCESS`, which measures script cost and not the shaders this whole ladder is made of. Until then, claiming the cost is earned would be asserting exactly what the segment asks to be measured
- [x] **A10.15** `v10` Greg's own collaged art is in the world as texture, used with intent — the same requirement as A10.1, stated twice at opposite ends of the v10 list, and answered by the same build: posted bills on the district buildings. Left as its own line rather than folded into A10.1, since the version convention says a version is never deleted

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


### B v2 — the second pass
B built the most detailed body in the game and the player can only see it when it is being destroyed. The rework wants everything inspectable, *"with cybernetics and organs and bones visible"*.
- [x] **B2.1** `v2` The rig is inspectable at rest, not only under damage — the complaint was exact. `anatomy_state` was written in two places, taking a wound and being re-decanted, so the World Index's BODY page showed whatever the last fight had left behind; anything that changed the body without going through `_take_damage()` — a limb picked up, an implant, a heal, a graft, anything a later system does to the rig — never reached the chart at all. The rig now reports itself every half second while the handheld is up, which is exactly when somebody is reading it, and not at all while it is shut. Amended rather than updated, because `update_subject()` writes a history event and a player standing still reading their own chart has not done anything the world needs to remember. Verified by damaging the anatomy through a path that does not report itself (`player_rig.hit()` direct, which is what every future body-changing system will look like) and watching the record: with the device open the chart follows the rig, and with it closed the same change writes nothing
- [x] **B2.2** `v2` Organs, bones and implants readable without opening anybody — the inspector already listed flesh, bone, every organ in the zone and every installed part for any subject, which is the structure this asks for. What it could not do was say anything about them: a person in the registry carries a blood type and a list of cybernetics and no body, so a stranger's dossier named the organs a body has and left every one of them blank. Reading somebody's insides meant opening them, which is the thing the segment says should not be necessary. Anyone the world has not recorded now gets a baseline body built from the same `AnatomyComponent` every real body in the game uses, configured with the cybernetics their record lists, cached per subject because the component is a `Node` and building one per redraw would be a body a frame. A recorded state still wins wherever there is one — the player's, kept live by B2.1, or anybody the world has actually opened — and what the registry wrote down about a person survives on top of the generated body, because a blood type somebody recorded is a fact about them rather than a default. Verified by `tests/body_baseline_test.tscn` (new, 5/5): a stranger reads 7 organs with a condition each and 6 zones, keeps their recorded blood type, and a body the world has opened still beats the baseline

### B v3 — the third pass
v2 made the body legible and it is still only harmed by violence. Greg: *"there's like 9g or 8g that radiation really melts you"*.
- [x] **B3.1** `v3` Radiation is a damage path through the same anatomy — not a status effect bolted on beside the body: it goes through `apply_hit()` with every other kind of harm, and differs in what it does rather than in where it lives. The model already split the world into penetrating and blunt — a blade reaches an organ, a fist breaks the ribs over it — and radiation belongs to neither, because it needs no way in. It reaches *every* organ in the zone at once rather than the one a blade happened to find, it barely bleeds (measured at 0.08 against a cut's 1.26 for the same 40 damage, which is why a body can be lethally dosed with almost nothing running out of it), and it leaves dose behind in the zone. Dose travels in the snapshot, so somebody who walked out of a hot zone is still being damaged by it in the next scene. `MELTING` is a family rather than a single type because the caustic pools do the same thing to a body over a different span. Verified by `tests/radiation_path_test.tscn` (new, 10/10), every claim measured against a cut of the same size as a control
- [x] **B3.2** `v3` It melts rather than cuts, and the rig shows the difference — three ways, and each is a thing the player can see. It keeps working after the hit: `_burn_dose()` spends the dose into the zone and everything inside it every frame, which a blade never does — a cut is finished the moment it lands. It does not fracture: a dosed limb has not broken, there is simply less of it, and reading "compound fracture" on an irradiated arm would be the rig telling the wrong story. And it does not look like a beating — dose takes the flesh toward a wet sallow green rather than the purple of bruising, drops its roughness because what is left of the surface is running, and takes the volume out of the limb, so a dosed body slumps where a beaten one swells. Verified beside its control rather than alone: `tests/body_showcase.tscn` now stands four bodies in a row — intact, beaten, dosed with the same total damage, and opened under the X-ray — and photographs itself (`captures/b3_2_v3_dosed_beside_beaten.png`)

### B v4 — the fourth pass
v3 gave the body a second way to be ruined and no way to be chosen. The rework wants mods, piercings, tattoos and extensions.
- [x] **B4.1** `v4` Body mods, piercings and tattoos on the same rig — mounted on the zone meshes rather than painted into the flesh material, and that is the whole design decision: a mark on an arm has to leave with the arm. Ink in a material would survive the limb coming off and turn up on a stump, which is the rig telling the wrong story about what just happened, and a piercing in a texture could not be torn out. `_throw_limb()` now carries any body mod on a severed zone onto the limb it throws and frees it from the stump, so the arm lands across the yard still wearing what its owner chose. Seeded from the character sheet, so the same person is marked identically every run and two players are not marked alike; a sheet that asked for nothing gets a body with nothing on it. Tattoo ink is drawn from Greg's own collage sheets where any exist (A10.1's argument about intent applies most exactly here, a tattoo being the one place in a game where somebody else's art belongs on a body) and sits under the skin rather than on it, taking the flesh's own light response so it never reads as a sticker. Verified by `tests/body_mods_test.tscn` (new, 9/9) and photographed beside four other bodies (`captures/b4_1_v4_marked_and_mutated.png`)
- [x] **B4.2** `v4` Head mutations, and they change how people react to you — growths first, then a second pair of eyes past 0.45, then a horn past 0.75, so a small mutation is a lump and a large one is unmistakably not human any more rather than everything arriving at once. The reaction half is the part that matters, and it is not a flat penalty: `faction_price_factor()` reads the mutation off the same appearance record the rig is built from, and which way it lands depends on who is looking. Everything on the ascending side of the Tree axis treats a changed body as contamination and everything on the descending side treats it as somebody who got on with it — so the same face that costs you at a Gate Lantern stall is a credential in the Soft Rot. Derived from each faction's own axis rather than a second table of who tolerates what, so a faction that moves on the axis takes its opinion of mutation with it, and it reaches `faction_disposition()`'s words for free because that already reads the factor. Measured: at mutation 0.9 the Gate Lanterns go 0.89 → 0.73 and the Soft Rot 0.78 → 1.00, in opposite directions, from one face

### B v5 — the fifth pass
v4 made the body customisable and nothing in it does anything. The crystal ball goes *"in their arm or pocket"*.
- [x] **B5.1** `v5` A crystal ball carried in the arm or the pocket, and it is functional — *functional* is the word that decided what this is. A prop that glows is not one, and neither is a divination system invented from nothing to give it something to say, so `systems/crystal_ball.gd` reads state the world already keeps and that cannot otherwise be seen: how much chaos magick is loose, which gods are up right now, and what the next one to rise is and when. It forecasts the storm from its actual cause rather than from a weather variable — A9.2's air reads the same charge — and it is clearer the worse things are, being a contamination artefact, which makes it most useful exactly when it is most alarming. It is an implant in the catalogue (`scrying ball`, left arm) and an item in the pocket, and `held_by()` answers for either, because "in the arm or the pocket" is the segment's own phrasing and a ball that worked one way would be half the item. No ball means no reading rather than a reading of nothing. Verified by `tests/crystal_ball_test.tscn` (new, 11/11): it names all five gods up at two in the morning, its charge follows eight rituals from 0.00 to 1.00 and its words from "settled" to "boiling", and pulling it out stops both
- [x] **B5.2** `v5` What is installed in a limb is visible in that limb — the catalogue has carried a `profile` and a `tint` for all twenty-one pieces of hardware since it was written and nothing ever drew either: a prosthetic was the same limb with a chrome material on it, so a load-bearing spine cage, a rangefinder eye and an ankle compass were indistinguishable from each other and from a clean limb somebody had polished. Every installed part is a shape now, mounted in the zone it went into, tinted from its own catalogue entry — blunt forms on purpose, because this has to read at arm's length on a body in motion rather than in a cutaway. Rebuilt rather than updated on each refresh, so hardware that is pulled leaves. Verified both ways in `tests/crystal_ball_test.tscn`: installing names the piece in the limb (`scrying ball`, not a generic lump) and pulling it removes it, and photographed on a body wearing four fittings beside five others (`captures/b5_2_v5_hardware_in_the_limb.png`)

### B v6 — the sixth pass
v5 put an object in a limb; AD3.2 wants cybernetics that change what movement is possible. Greg: limbs *"that shoot missiles, grapple"*.
- [x] ~~**B6.1** `v6` Limbs that shoot and grapple, through the anatomy rather than around it~~
      The load-bearing half of the item is its last five words. A capability
      that is an ability flag sitting beside the body never hears about the
      arm coming off; one read through the anatomy cannot help but hear.
      `AnatomyComponent.LIMB_CAPABILITIES` keys off the hardware's own
      `profile` — the field `implant_catalog.gd` has carried for every entry
      since it was written and that B5.2 already draws the limb's shape from
      — so a capability cannot disagree with the thing granting it the way a
      second ability table would. `limb_capabilities()`/`limb_can()`/
      `capable_sites()` answer for one site or find the limb to reach with,
      and hardware below `CAPABILITY_MINIMUM_CONDITION` answers nothing: a
      wrecked limb drive is a weight on the end of your arm.
      Verified: `tests/limb_capability_test.gd` (17 checks) — a bare arm
      cannot grapple, an industrial arm can and the other arm still cannot,
      a ledger thumb is hardware and still cannot, wrecking the hardware
      takes the capability with it, and the same routing carries a launching
      limb without quietly granting every capability at once.
      Still open, named rather than glossed: no *authored* launcher exists.
      `implant_catalog.gd` is Lane 5's file and its twenty-one entries are
      all grapple-or-nothing, so the launch path is proven with a
      caller-supplied limb rather than one out of the catalogue. Adding a
      real launcher entry is that file owner's call — and it is what AD3.1
      needs before "answer a rocket with a blade" has a rocket in it.
- [x] ~~**B6.2** `v6` A grappling limb that is severed stops grappling~~
      Falls straight out of B6.1's layering rather than being bolted on
      beside it: `BaselineHuman.limb_can()` asks the anatomy what the
      hardware offers and then vetoes it if the limb is not attached, so a
      severed arm answers `false` to everything from the moment it comes
      off, with nothing needing to remember to go and switch a flag. The
      hold itself tracks which of your own arms is doing the holding
      (`grapple_with`, chosen as a grappling-capable limb when you have one),
      and `_update_grapple()` checks it against `severed` every tick — so
      however the arm came off and whoever took it, the hold ends on the
      next tick rather than only when a signal happened to be connected.
      Verified in the same suite, end to end: with the rig's own
      `left_arm` severed mid-hold in a real instantiated Hunt Grounds,
      `_update_grapple()` clears `grapple_target` — and the deliberate
      layering check that the *hardware* is still installed and still intact
      while the body is what refuses it.

### B v7 — the seventh pass
v6 made the body a weapon platform wearing nothing. AS3.4: what you are wearing shows on the body the mirror renders.
- [x] **B7.1** `v7` Clothes and layers on the rig, affecting weather and radiation — the rig has had a coat, a collar and a strap since it was built and none of them meant anything: they were geometry, and protection was a number somewhere else. `systems/garments.gd` makes them the same object. A garment covers named zones and carries what it does — `shield` against a melting hit, `plate` against everything else, `seal` against the air — so taking a coat off a body takes its protection with it and there is no second place the figure lives. They stack and cap, because two coats are warmer than one but somebody wearing every garment in the game is still somebody standing in it. Weather is the half that ties this to A9: a contaminated storm doses through the air rather than by hitting anybody, so `expose()` adds dose to whatever is uncovered, slowly enough that a bad night out in it is survivable and staying out in it is not. Measured: a lead wrap takes a 40-damage dose to 15.2 and an ash coat only to 27.2 (a coat is not lead); a torso wrap does nothing at all for a leg; and a filter mask holds a head at 0.009 dose through a storm that takes a bare one to 0.035. Verified by `tests/garments_test.tscn` (new, 8/8), with the worn layers drawn on the rig
- [x] **B7.2** `v7` Armour and cover are the same system, not a stat — and it falls out of B7.1 rather than needing a system of its own, which is the point. Armour is what a zone is wearing or carrying; cover is what that zone is behind; both resolve through `Garments.with_cover()` into the one figure `apply_hit()` reads, so there is no armour stat left for a wall to disagree with and nothing special-cased in whatever does the shooting. A zone's `cover` is written by whatever knows about the world's geometry, which keeps the knowledge of walls out of the anatomy. It keeps the two kinds of protection separate for the same reason garments do — shielding stops a dose and plate stops a bullet, and one "protection" number would have to lie about one of them. Measured: a wall at 0.8 cover takes a 40-damage ballistic hit to 20.8 and a scrap plate takes the same hit down through the same figure

### B v8 — the eighth pass
v8 of A gave the player a flame; B has never rendered the player as anything other than another body. AP2.1: the spirit cannot be banished by violence.
- [x] **B8.1** `v8` ~~The rig survives what kills everybody else, visibly~~ The player's body is the same `AnatomyComponent` as the one in the road — same organs, same severing, same bleed — and is made exceptional by exactly one flag, `undying`. Not a second health pool, not a damage multiplier, not a separate rig. **The load-bearing part is that there is now one door.** Death was set in three places that each wrote `dead = true` themselves, which is fine until one body is not allowed to die, at which point three copies of "and now you are dead" is three chances to miss one — and the one you miss is the one that kills the player who cannot be killed. All of them route through `_die_or_fail()` now, and `undying_body_test` reads the source and fails if a fourth ever appears. That check earned itself immediately: the fatal-organ branch existed **twice** at different indentation, and the first patch here silently missed the second copy. The "visibly" is `spirit_burden`, which rises with every failure and never falls, folded into `flame_condition()` so `UndyingFlame` — which already burned harder as the body worsened — burns harder still. Surviving what would kill anyone else reads as the spirit showing through more and the body mattering less, on the body, in the frame. There is no counter anywhere
- [x] **B8.2** `v8` ~~What is left when a body fails but its spirit does not~~ `failed` is a body that has run out — every reason it should be `dead` has happened — attached to a spirit that will not go with it (AP2.1, "the spirit cannot be banished by violence"). Deliberately a separate signal from `died`, because the witness ledger, the resolution window and the crowd must not read it as a death: nothing about the world has changed except that this body stopped working. Nothing recovers from it on its own. `rise()` is the only way out and it is **not** a revive — no healing, no reset, no mercy on the wound: every injury and every severed limb stays, blood comes back only to the floor it takes to be conscious, bleeding is slowed rather than closed, and the burden that just went up never comes down. Five failures reach the floor, which is a run rather than a fight — the cost has to be felt across an evening, not inside one exchange. That permanence is the only thing stopping "cannot die" from meaning "nothing that happens matters". Every failure is recorded with what caused it, because an undying body that forgets is a checkpoint and one that remembers is a character (B10.2). 23/23 in `undying_body_test`, which checks the carve-out is a carve-out — an ordinary body still dies of all three causes

### B v9 — the ninth pass
v8 made the player's body exceptional and they can still never look at it. AH1.5: the mirror in the room shows your body, current.
- [x] **B9.1** `v9` ~~The mirror renders this rig live, with everything done to it~~ `BodyMirror` renders **the actual rig** through a second camera into a `SubViewport` that shares the world. The whole design decision is *not building a second body*: a portrait rig kept in step with the real one is the obvious build and it is wrong, because "with everything done to it" then means maintaining two bodies through severing, hardware, wounds, bleeding and the hour — and the day they disagree is the day the mirror starts lying, which is worse than not having one. Sharing the world means there is nothing to keep in step. If the body has a hole in it the hole is in the mirror, because it is the same hole. Tested by doing damage and asking whether the reflection changed, which it can only answer because it is the same geometry — a maintained copy could not have that property. Also switchable: a second full render of the scene is not free, so a mirror nobody is looking at stops rendering. 13/13
- [x] **B9.2** `v9` ~~Including the things you cannot see on yourself in first person~~ Falls out of B9.1 for free, and is the real reason the mirror is worth having: nine passes went into this rig and first person shows the player a pair of hands. `Facing.FRONT` is your own face, `Facing.BACK` is the wound between your shoulder blades — and the reflected eye sits in the *subject's* frame rather than the world's, so turning the body turns the reflection instead of the mirror quietly becoming a fixed camera the moment anyone moves. The capture at `captures/b9_mirror.png` is the argument in one frame: the shot holds the body's back and the glass holds its front, same body, same instant, neither view available in first person

### B v10 — the tenth pass
Nine passes on one body, and T1.1 now says the universe restarts and you do not.
- [x] **B10.1** `v10` ~~The body is recognisably itself across a quantum restart~~ It was not there at all: `begin_new()` calls `clear_history()`, `clear_history()` empties `subjects`, and `subjects` is where bodies live — so the restart erased the person with the world and decanted a new one on the other side. `QuantumSaves.CARRIED_SUBJECTS` is the list of who does not restart when the universe does. "Recognisably itself" then needed something to mean, and the only honest test of it is two bodies built from one record at two different times — impossible to even state while the papers-to-body derivation lived inside the hunt scene, which was the only thing in the game that could build this person. `BaselineHuman.config_from_subject()` is that derivation, moved to the rig, and the audit compares generated head geometry across the restart rather than comparing a record to itself
- [x] **B10.2** `v10` ~~What it carries over is scars, not statistics~~ It carried over exactly the wrong half, and the sharper half of this item is what made that visible. `snapshot()` was eighteen keys of statistics and not one mark: it saved the health the arm had left and lost the hole in the arm, because `wound_marks` — the whole of B10.4's located, permanent record — only ever existed for as long as the rig did. So marks are in the snapshot now, and `scars_of()` is the reduction a *restart* applies and a *load* does not: the holes and where they are, how deep each limb was opened, the limbs that are gone, the hardware in what is left. The health, the blood, the pain, the dose and the running tally toward losing a limb stay in the universe that did them, so you arrive whole in the numbers and marked in the flesh rather than arriving still bleeding from a wound that is not in this world. JSON was the trap underneath: it has no Vector3 and does not fail on one — it writes `"(0.1, 0.2, 0.3)"` and hands that string back — so a scar written straight to a branch file came back as text. `body_restart_test` marks a body, takes an arm off, crosses the restart, reloads the branch off disk and asks the rebuilt *rig* whether the holes are on the limb, not whether a dictionary round-tripped. Mutation-checked both ways: dropping the marks from the carry fails four checks, carrying the statistics fails six

- [x] **B10.3** `v10` ~~Damage is always recorded against a zone, never against a hitbox~~ `zone_nearest()` resolves a world point to the limb it actually landed on, and `hit_at()` files every wound under a zone name — proven rather than asserted: `body_v10_audit` fires at the chest, head and left arm and checks each resolves to its own zone, then checks every key in `wound_marks` is a real member of `ZONES`. A hit that found a collider instead of a body part would fail that
- [x] **B10.4** `v10` ~~A body carries its whole history visibly and permanently~~ Wounds are recorded at the real impact point in the limb's own local space and rendered there as torn craters, so four hits in four places leave four holes in four places — which is what `hit_at()` could never do while it was converting the impact point to a zone name and discarding it. Audited on both halves: four hits produce four marks *and* four meshes on the limb, and they are still there ninety frames later. Permanent, not a decal that ages out. Local space is why they ride the limb through animation and leave with it when it comes off
- [x] **B10.5** `v10` ~~Blood, viscera and bone answer light as three different materials~~ Not three hex codes that happen to differ — three genuinely different responses, checked as such. Bone and viscera run different roughness through `WorldLook.surface` (0.68 against 0.39), and blood is a different *shading mode* entirely: unshaded, so it reads as a mark printed on the world rather than as a third wet object competing with the floor on the floor's terms. That was the change that made spatter start working
- [x] **B10.6** `v10` ~~Any body can be opened up in the same detail as any other~~ There is no "detailed body" and "cheap body" — one rig, so an NPC nobody will ever inspect carries the same organs, the same zones and the same parts as the one the player is about to dig through. Audited by comparing two independently built bodies key for key rather than by trusting that they came from the same constructor, and by opening one to the organ layer and checking the other did not follow — depth is a ratchet on any body, not a property of authored ones
- [x] **B10.7** `v10` ~~What is installed in a limb is visible in that limb~~ Installing hardware at a site adds geometry to that limb's own node, so an arm with an industrial limb in it looks like an arm with something in it. Audited by counting the limb's children either side of an install rather than by trusting that the refresh path runs
- [x] **B10.8** `v10` ~~Radiation, fire, bullets and blades all resolve through the same anatomy~~ All seven damage types — ballistic, cut, shear, blunt, puncture, radiation, caustic — go through one `apply_hit()`, and the audit proves it the only way that means anything: each one has to cost the zone health *and* come back carrying `blood_remaining` and `pain`, which are stamped on by `apply_hit` itself. A type that bypassed the anatomy could not produce them. This is what stops a new damage type quietly skipping organs, bleeding or severing
- [x] **B10.9** `v10` ~~A body reacts to the hour, the weather and what it is wearing~~ Two of the three already reached the body and neither was rebuilt: what somebody is wearing has resolved through `Garments.shielding()` since B7.1, and the weather has dosed them through `expose()` since W1.3. **The hour was the gap** — `world_clock.gd` has had `hour()`, `daylight()` and `is_night()` for a while and neither `anatomy_component.gd` nor `baseline_human.gd` contained the string "WorldClock" at all; the only route from the hour to a body was the `(1.0 - daylight())` term folded invisibly inside `contamination()`, which is the *weather* answering the hour, not the body. `chill(cold, delta)` sits beside `expose(severity, delta)` and takes its cold as an argument for the same reason — the anatomy stays testable without a world around it — and reads `warmth` off the same shielding figure `garments.gd` has computed and clamped for every worn set since B7.1 with **nothing reading it**. Deliberately its own number rather than more `pain`: pain never comes down on its own here (only `treat_wound()` and `stabilise()` lower it), so a chill kept there would still be on the body at noon in a coat, and would put the weather into the wound record. It shows with no new rendering, through the two body-wide answers that already exist — `posture().hunch`, which `_apply_pain_posture()` reads every frame, and `mobility_ratio()`, a small multiplier rather than a gate, because a bad night slows you and does not refuse the vault a broken leg refuses. `_update_air()` passes the hour and the air as **two separate factors** so neither hides inside the other, and `body_v10_audit` moves one at a time: 02:00 chills a bare body more than 13:00 with the weather held fixed (0.600 vs 0.000) and dusk lands between them (0.384), so the light going is a curve and not a switch; a coat and leathers cost less than skin at the same hour in the same weather (0.290 vs 0.600); and the same body at the same hour takes exactly nothing from still air and something from a storm
- [x] **B10.10** `v10` ~~The mirror in the room renders this rig live~~ Same object as B9.1, and "live" is the load-bearing word — proven by mutating the body and checking the reflection is of a mutated body, not by looking at a screenshot once. `watch()` takes any `Node3D` rather than a `BaselineHuman`, so the vat, the shed and a wall mirror are one implementation instead of three
- [x] **B10.11** `v10` ~~Gore persists, rots on a real clock, and is eaten by things that eat~~ All three halves are real: `GoreChunks` holds pieces on a 240-second rot clock with `rot_ratio()` readable at any moment, and `carrion_scavenger.gd` decides for itself what counts as food through its own `can_eat()`. Checked off the script's own method list rather than by calling into it, since these are static utility classes with no instance to ask
- [ ] **B10.12** `v10` Nothing about a body is described in text that could be shown on the body
- [x] **B10.13** `v10` ~~A corpse is a place other systems can read from days later~~ The load-bearing word is *other*. Not "the mesh stays there" — that a later system with no reference to the rig can ask what happened to that body and get an answer. Proven by wounding a body, taking a limb off it, writing its snapshot to `WorldHistory`, then **freeing the rig entirely** — the way it would be gone a day later — and reading back which limb came off and what state the rest was in. That is what makes a corpse a place rather than a prop
- [ ] **B10.14** `v10` Bodies are cheap enough that a crowd is a crowd
- [x] **B10.15** `v10` ~~The player's body is the same rig, made exceptional only by being undying~~ Proven as an identity, not a claim: the audit checks the player's anatomy and rig are the *same script* as an ordinary body's, then kills both with the same call and checks one dies and the other fails instead. No second health pool, no damage multiplier, no separate player rig — one flag, and every wound goes through the same organs, the same bleed and the same severing. See B8.1 for the chokepoint that makes it safe

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
- [~] **C1.6** `v2` The device is raised at one angle in one hand, every time — the position half is real: `_device_rect` used to rise dead-centre and perfectly upright, which reads as a menu appearing rather than an object somebody is holding. It now rises to a fixed off-centre point (`HELD_OFFSET_X`), eased in with `raised` itself, deterministic — no per-raise randomness. The angle half was built and reverted: `radial` (the selection wheel, C2) is a child of this same `Control`, so rotating `self` dragged the wheel's own fixed screen-centre geometry along with the phone's tilt — visually confirmed broken in a capture before being pulled back out. A real tilt needs the chassis+screen moved into their own rotated sub-container first, with `radial` staying a sibling rather than a descendant of it — left as the named next step rather than guessed at further. Verified: `handheld_lean_test`/`handheld_impact_test`/`device_wear_test`/`handheld_battery_test` all re-run clean, and a fresh `handheld_capture` shows the offset device beside an unmoved, correctly screen-centred radial wheel
- [~] **C1.7** `v2` It can be dropped, and it can be taken off you — `HandheldDevice.drop()`/`confiscate(reason)` are the same underlying transition (`possessed` false, forced closed, unraisable) reached through two callers and recorded as two distinct events, so the world can tell a deliberate drop from a robbery apart later even though the player cannot use the device either way meanwhile; `repossess()` is the way back, wear travelling with it since it is the same object, not a fresh one. Reloaded on every `open_device()` the same as condition/battery already are, so a device lost in one scene stays lost the next. `tests/device_possession_test.gd`, 18 checks; `handheld_lean_test`/`handheld_impact_test`/`device_wear_test`/`handheld_battery_test` re-verified clean.

      The drop half is now complete in the live Hunt rather than stopping at
      the signal: `DROP_KEY` (`Delete`) calls `drop()`, and the scene turns that
      exact payload into a colliding `DroppedHandheld` with rendered case,
      emissive mirror, lashed rear cell, serial, condition and remaining
      charge. It tumbles from the real camera, advertises `[E] RECOVER BLACK
      MIRROR // serial` only in reach, and E calls `repossess()` before the
      world body leaves. Its settled position is amended into WorldHistory;
      reloading while it is still lost reconstructs the same pickable serial
      there instead of trapping the save in `possessed = false`. Verified by
      `tests/handheld_world_drop_test.gd` (15 checks), plus the existing
      `handheld_drop_test.gd` and `device_possession_test.gd`; windowed evidence
      at `captures/c1_7_dropped_black_mirror.png` shows the real world object,
      its serial and the recovery prompt in the production HUD.

      Control repair (17 September): the first live version accidentally put
      drop on `K`, which the Hunt already reserves for deliberate re-decanting;
      a captured player could therefore lose the phone and reset their body on
      one press. Drop now owns `Delete`, the keys card teaches both actions as
      separate rows, and `tests/handheld_control_binding_test.gd` (5 checks)
      prevents the irreversible bindings from collapsing together again.

      Still open, and still not this file's to close: nothing calls
      `confiscate()` from real gameplay — that caller is a robbery or defeat
      event belonging to whichever lane owns that consequence, not something
      `handheld_device.gd` can originate on its own.
- [x] **C1.8** `v2` Wear accumulates in WorldHistory and only ever goes one way — a cracked screen does not heal
- [x] **C2.6** `v2` F1-F5 reach a page directly; cycling is how you learn the device, not how you use one you know
- [x] **C5.5** `v2` Cracks seeded from the device's own serial, at its real condition rather than a constant 0.85

### C v3 — the third pass
Opened because C1.8, C2.6 and C5.5 closed at v2. Each entry is a fault the v2
work created or exposed, not a wish.

- [x] ~~**C1.9** `v3` Wear is only visible on the screen you are reading; the device in your hand looks new from the outside~~ The real crack system (C5.5/C5.6 — seeded from the device's own `serial`, one fork cluster per recorded impact) drew across the *whole* `_device_rect` — chassis and bezel included — so a battered handheld never actually looked new from the outside; the case just wore along with the glass. Moved out of `_draw_chassis` (which no longer draws any cracks at all) into `_draw_damage()` on `_overlay`, rescoped to `_screen_rect` alone. Drawing on `_overlay` rather than `self` also fixes something C1.9 exposed in passing: `_overlay` is the topmost child, so cracks now genuinely sit over the hosted INDEX/MAP/WIRE panel too, not just over RADIO/CARRY/RITUAL's own directly-drawn content the way they effectively did before. Verified: `handheld_lean_test`/`handheld_impact_test`/`device_wear_test`/`handheld_battery_test`/`device_possession_test` all re-run clean, and a heavy-wear capture (two located impacts, condition down to 0.25) shows a spider-webbed screen behind an entirely undamaged logo, tabs, signal readout and battery gauge
- [x] ~~**C2.7** `v3` Direct page access exists and nothing ever teaches it —
      a control nobody discovers is a control nobody has~~ `jump_to_mode()`
      has reached a page directly since C2.6 v2 and nothing on the device
      itself ever said so. Each tab in `_draw_tabs()` now prints the F-key
      that jumps straight to it — "F1" over INDEX through "F5" over CARRY —
      the same register a real handheld prints a function-key legend in,
      rather than a control the player can only ever stumble onto by cycling
      through with Tab. Verified: a windowed capture
      (`captures/c2_7_v3_tab_key_hints.png`) showing the legend printed and
      matching `bone_yard_hunt.gd`'s actual `KEY_F1`.."KEY_F5" bindings.
- [x] ~~**C5.6** `v3` Cracks are per-device but still radiate from one
      authored origin; an impact should crack the glass where it landed~~
      `BlackMirror.draw_cracks()` always forked from the exact same point
      (74%, 22% into the rect) for every device and every impact. It now
      takes an origin, defaulting to that same point only for a caller with
      no location to give; `handheld_device.gd` records each impact's actual
      location (`impacts`, capped at 5, persisted the same way `wear_log`
      already is), and `_draw_chassis` draws one crack cluster per recorded
      impact from its own point rather than one shared authored origin. An
      impact with a genuinely unknown location (an accumulated tick rather
      than a single blow) still lands on a varied point instead of the one
      shared spot. This pass originally had no live `take_wear()` caller;
      that larger wiring gap has since closed under C10.8, while the mechanism
      here remains independently verified. Verified:
      `tests/handheld_impact_test.gd` (new, 7/7 — a given location is used
      exactly, two unlocated impacts land on different points and neither is
      the old authored one, the impact list is capped, and it survives a
      save/load round trip), plus the existing `handheld_lean_test.gd`
      regression suite and a windowed capture
      (`captures/c5_6_v3_impact_cracks.png`) showing cracks radiating from
      three different, deliberately separated impact points.


### C v4 — the fourth pass
v3 made the handheld a rich object that emits no light at all. Greg: *"having light coming off the phone when you have it in your hand"*.
- [x] ~~**C4.1** `v4` It throws real light into the world when it is in your hand~~ The implementation already existed under AS1.1 but this duplicate remained open: the Hunt Grounds mounts a real shadow-casting `SpotLight3D` off-centre on the camera, with its visible state and energy driven every frame by the handheld's raised state and battery. The device and world light share `LAMP_RANGE`, so its rendered reach and later visibility input cannot silently diverge. `tests/handheld_world_light_test.gd` verifies the complete seam in the running Hunt scene (8 checks), and paired 01:00 captures (`captures/c4_1_handheld_light_off.png` / `c4_1_handheld_light_on.png`) confirm the beam changes the surfaces ahead rather than merely brightening the 2D panel. C4.2 remains honestly open: there is no rendered first-person hand surface for the screen to illuminate, and the existing source is explicitly camera-mounted
- [x] ~~**C4.2** `v4` Its own screen is what lights your hands, not a lamp bolted to it~~ The held hand is now part of the handheld object itself: a palm and wrist continue below the lower-left chassis while four curled fingers wrap its edge, keeping the screen an object somebody grips rather than a floating slab. Its skin and narrow green knuckle rims read one `screen_luminance()` value (`raised * battery * backlight`), entirely inside `handheld_device.gd`; lowering it, exhausting the cell or a sagging panel removes that spill without consulting the camera-mounted world beam. `tests/handheld_screen_light_test.gd`, 5 checks. Paired captures made without loading the Hunt scene (`captures/c4_2_screen_lit_hand.png` / `c4_2_screen_dead_hand.png`) show the lit and dead glass on the same grip; the centred radial remains a sibling and was visually rechecked over the new silhouette

### C v5 — the fifth pass
v4 made it a lamp, and a lamp that never runs out is a torch, not a resource. *"phone has a % possibly"*.
- [x] ~~**C5.1** `v5` A battery percentage that runs down and can reach nothing~~ Already built, left unticked: `battery` drains only while actually raised (`BATTERY_DRAIN_PER_SECOND`), recharges roughly four times slower while pocketed, and floors at exactly 0.0 rather than going negative — at which point `is_lit()` genuinely refuses (no light with nothing left to give it). `tests/handheld_battery_test.gd`, 14 checks, re-run clean: drains while raised, recharges only while pocketed and slower than it drains, floors at zero, an empty battery is not lit even raised, and it survives a reload with whatever charge was actually left
- [x] ~~**C5.2** `v5` What it costs to keep the screen up is visible on the battery~~ Already built, left unticked: `_draw_status()` draws a real "CELL XX%" readout plus an eight-segment gauge, both read straight off `battery`, tinted amber-to-red under 35%. Verified against `handheld_index.png`/`handheld_radial.png` (this session's own C1.6 captures) — both show "CELL 99%"/"CELL 100%" and the segmented gauge in the bottom-right corner

### C v6 — the sixth pass
v5 gave the light a cost in charge and none in attention. Raising it should occupy you.
- [x] ~~**C6.1** `v6` Holding it up is an action, and that hand is not available~~ Already implemented under AS1.2 but left open here: `_attack()` refuses before it asks the arsenal for an action once `handheld.raised > 0.5`, the same physical threshold that makes the screen light live. It therefore spends no ammo, windup or cooldown while that hand is occupied, rather than cancelling a strike after its cost. `tests/handheld_busy_hand_test.gd`, 5 checks in the running Hunt scene: the pocketed control begins a real melee windup, while the identical attempt with the device raised leaves the action, windup and cooldown untouched
- [x] ~~**C6.2** `v6` Waving it to see around a corner is a real thing you do~~ Hold `L` to brace an Index/Map/Wire page, then use WASD to carry the Black Mirror around the corresponding screen edge. The gesture is eased through one live `wave` vector: the drawn device and gripping hand visibly travel with the wrist while the camera-mounted `SpotLight3D` moves, yaws and pitches in the same direction, so the beam can cross an edge before the player's viewpoint does. Releasing `L` recentres both; pages without a hosted surface do not claim the posture. The in-world keys card now prints `HOLD L + WASD — LEAN / WAVE DEVICE LIGHT`. `tests/handheld_lean_test.gd` (6 checks), `tests/handheld_world_light_test.gd` (12 checks), and `tests/perception_integration_test.gd` (13 checks) pass headless; `captures/handheld_map_wave.png` was captured at 1280x720 and visually checked for the physical off-axis held pose

### C v7 — the seventh pass
v6 made the lamp cost you something; it costs nobody else anything. AS1.5: its light is what gives you away at night.
- [x] ~~**C7.1** `v7` Anything hunting you can see the light before it sees you~~ The live perception pass now resolves two different sightings for every hostile: the player's body and the handheld's emitted source. At night a clear raised Black Mirror is traceable at 20 m while its holder remains below the unseen threshold; pocketing it removes that trail, a wall blocks it, and an exhausted cell emits nothing. The encounter state machine now reads those verdicts before pursuing or shouldering a launcher, so `player_unseen` is no longer an unused diagnostic and the light can actually draw a hunter before the body is resolved. A first sighting records one `hunter_noticed_handheld_light` history event rather than writing every frame. `tests/perception_test.gd` (15 checks), `tests/perception_integration_test.gd` (11 checks), and `tests/combat_integration_test.gd` (46 checks) pass headless
- [x] ~~**C7.2** `v7` Using the map at night is a decision with a price~~ The live satellite page now drives the battered panel at twice the Index's battery draw and 1.3 times its emitted-light output. That is one physical cost expressed three ways through existing systems: charge falls twice as fast, the real camera-carried `SpotLight3D` becomes brighter and wider, and at night a hunter can acquire its source at 24 m where the quiet Index remains below the same threshold. The hardware prints `SAT DRAW x2.0` beside the live cell gauge, so the cost is readable before it is paid rather than hidden in a tuning constant. `tests/handheld_battery_test.gd` (17 checks), `tests/handheld_world_light_test.gd` (10 checks), and `tests/perception_integration_test.gd` (13 checks) pass headless; `captures/handheld_map.png` was captured at 1280x720 and visually checked for the unobscured draw warning

### C v8 — the eighth pass
v7 made carrying it tactical and putting it away instant. Rule 3: every hard cut is a bug.
- [x] ~~**C8.1** `v8` Pocketing it is a movement and the light leaves with it~~ Already implemented under AS1.4 but left open here: `close_device()` changes intent, while `Motion.blend()` lowers `raised` over subsequent frames rather than hiding the object; the world lamp reads that same held threshold every frame, remains during the first part of the lowering action, then leaves once the screen crosses out of the hand. `tests/handheld_pocket_light_test.gd`, 5 checks in the running Hunt scene, including the intermediate moving/lit state and the final pocketed/dark state
- [x] ~~**C8.2** `v8` Pockets are real, and what is in them is in them (AS3.2)~~ Not a second inventory: `carry.gd` marks which of the real items it already carries are `pocketed`, so a pocket holds the same identified object the bag does rather than a parallel fiction of "small stuff". `POCKET_CAPACITY` 3 and `POCKET_MASS_LIMIT` 0.6kg — a severed limb is refused outright with a reason rather than silently truncated, and a fourth small thing is refused rather than the set growing quietly. `search_pockets()` is the narrower honest half for a frisk or a robbery that pats down a body without going through the bag on its back. `tests/pockets_test.gd`, 15 checks; `substances_test`/`money_test`/`chunk_test` re-verified clean. Honestly scoped: nothing yet *calls* `search_pockets()` — a frisk is somebody else's verb (Lane 1's grapple/clinch, Lane 4's defeat routing) — and which garment provides how many pockets is AS3's own, needing `garments.gd` (Lane 2) rather than reached into from here

### C v9 — the ninth pass
Eight passes on the front of an object nobody has ever turned over. The jester is on the back and has never been seen.
- [x] ~~**C9.1** `v9` The back of the device, and the jester on it~~ Hold `O` while the handheld is raised and the same held object compresses through its physical edge before opening onto a purpose-built rear surface; releasing turns it back to the mirror. The aperture, hosted page and glass-damage overlay stay on the hidden front rather than becoming a seventh UI page, while the front-facing screen light fades continuously with the turn angle. The rear is a recessed service shell with a large static hollow-faced jester, protruding replacement battery under three lashings, stamped `WIZARDS ONLY FOOLZ` mark and the device's persistent serial. `tests/handheld_back_test.gd`, 10 C9.1 checks; `captures/c9_1_v9_jester_back.png` visually inspected at 1280x720
- [x] ~~**C9.2** `v9` Its condition shows on the shell, not only on the screen~~ The rear reads the same persisted `condition` and remembered `impacts` as the glass: declining condition removes finish, opens the plate seam, delaminates the upper corner and breaks battery ties at fixed thresholds; up to four dent rings are placed from the impacts the device actually remembers (mirrored onto the reverse), rather than from a second cosmetic-damage state. No percentage is printed on the rear — the material is the gauge. `tests/handheld_back_test.gd`, 5 C9.2 checks including save/reload; `captures/c9_2_v9_battered_shell.png` inspected against the nearly sound rear

### C v10 — the tenth pass
Greg, plainly: *"the entire blackmirror gui needs work"*. Nine passes on what the device *is* and none on how it reads.
- [ ] **C10.1** `v10` The whole GUI re-authored as one thing rather than six pages
  - First narrow seam: Index/Wire and Map were 16:9 documents letterboxed inside the mirror, while Radio/Carry/Ritual used the full wide glass. All six now occupy one centred 16:9 working aperture with the same device-owned registration edge. This does not claim the line; their internal frames and interaction grammar still need unifying. `tests/handheld_aperture_test.gd`; six inspected captures at `captures/c10_1_aperture_{index,map,wire,radio,carry,ritual}.png`
  - Second narrow seam: the Ashbloom calendar and live hour are chassis registration rather than app content, so every mode carries the same date in the same place. `handheld_aperture_test.gd` proves all seven modes preserve it; internal interaction grammar remains open.
- [x] ~~**C10.2** `v10` It is legible in the dark it now creates, which nothing before v4 had to be~~ The six apps now rise through one device-owned phosphor reading bed in `black_mirror.gd`: an inset luminous surface suppresses the holder's reflection only beneath the working aperture while the side gutters remain black, reflective glass. Bone ink, moss instruments and copper registration have explicit contrast floors against that shared surface, rather than each page inventing a brighter box. `tests/handheld_dark_legibility_test.gd` checks the colour contract and all six modes' use of the same surface; `captures/c10_2_dark_{index,map,wire,radio,carry,ritual}.png` inspected at 1280x720.

- [ ] **C10.3** `v10` Its battery is a real resource with a real floor
- [ ] **C10.4** `v10` Raising it occupies a hand and the game never forgets that
- [ ] **C10.5** `v10` Its glow is what anything hunting you sees first
- [ ] **C10.6** `v10` It has a back, a jester on it, and a condition that shows on the shell
- [ ] **C10.7** `v10` Every page reads correctly in the dark it creates
- [x] ~~**C10.8** `v10` The device wears from what you have actually done to it~~ Two real player actions now reach the existing persistent wear mechanism. A wound taken while the Black Mirror is physically raised reduces its condition in proportion to the incoming damage and projects the attacker's world position onto the glass, so the new crack begins on the side the blow arrived from; the identical wound while it is pocketed cannot touch it. Deliberately dropping the device applies a smaller lower-edge impact before possession leaves, and the dropped payload therefore belongs to the same newly damaged serial rather than a replacement. Both causes enter `wear_log`, persist, and continue to drive the front cracks and rear shell degradation already built. `tests/handheld_live_wear_test.gd` (9 checks), `handheld_drop_test.gd`, `device_possession_test.gd`, and `handheld_impact_test.gd` pass headless; `captures/c10_8_live_device_wear.png` was produced through `_wound_player()` in the real Hunt scene and visually inspected at 1280x720
- [ ] **C10.9** `v10` Nothing on it is a list of text in a box
- [ ] **C10.10** `v10` It is the Wire, the map, the carry and the radio without four designs
- [ ] **C10.11** `v10` Apps on it are playable and some of them are load-bearing
- [ ] **C10.12** `v10` It can evoke, and evoking through it is dangerous
- [ ] **C10.13** `v10` It holds an archive that disagrees with the feed
- [ ] **C10.14** `v10` It survives the restart carrying what you did with it
- [ ] **C10.15** `v10` Somebody could pick it up and know whose it was

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
- [x] ~~**D3.5** `v2` The handler says the same things in the same order
      every decanting~~ `_speak()` indexed every `IntakeDirection` pool with
      `handler_line % pool.size()`, and `handler_line` always started at
      zero — so the first idle line was the same line every decanting, then
      the same second, forever, in the same order. A `line_offset` rolled
      once per scene in `_ready()` now shifts every pool's index, so which
      line starts each context varies decanting to decanting, while
      `IntakeDirection.line_for()` itself stays exactly as deterministic as
      `intake_direction_test.gd` already proved — the same moment in the
      same decanting still plays the same way twice, which is the property
      the file's own doc actually asks for.
- [x] ~~**D4.6** `v2` Race is data the world reads, but the intake does not
      react to it out loud~~ Picking a race called `_transcribe()` with no
      way to say anything but the generic "chose" pool ("Noted." / "Fine.
      That's what I'll put.") — the same reaction ticking any other box on
      the form gets. `_transcribe()` now takes an optional
      `success_context`, and the RACE page passes `"race_" + sheet.race`,
      landing on six new authored lines in `intake_direction.gd` (one per
      race, each actually naming what that race is and what it costs
      socially) instead of the generic pool. A mistranscription still gets
      "slipped" regardless — getting the paperwork wrong is not the moment
      for him to have an opinion about who you are.
      Verified: `tests/intake_variance_test.gd` (new, 4/4 — two decantings
      with different offsets hear a different first line, the same moment
      replayed in one decanting still matches, all six races get a genuinely
      distinct reaction, and at least some of those are the race-specific
      lines rather than the generic fallback), plus the existing
      `intake_direction_test.gd` (22/22) regression suite and a windowed
      capture confirming the RACE page still renders correctly.
- [x] ~~**D2.4** `v2` CLERICAL ERROR is never discoverable — finding out
      which part of your sheet is wrong should be possible and should cost
      something~~ Was undiscoverable in principle, not just in practice:
      `_mistranscribe()` overwrote one field with a wrong value and threw the
      true one away in the same statement, so nothing anywhere still held
      the answer to check the sheet against. It now keeps both — `field` and
      `true_value`, nested under `clerical_error` rather than surfaced as a
      top-level field, so a normal read of the dossier still shows only the
      wrong sheet. `world_index.gd`'s FILE page offers a real AUDIT link
      while it is undiscovered, which spends a real Wire lookup (new
      `wire_net.gd` action, +1 exposure, same ledger as `expose`/`retract`)
      rather than being a free tooltip, and reveals the discrepancy in place
      once paid for. Verified: `tests/clerical_audit_test.gd` (new, 7/7),
      plus the existing `link_test.gd`, `wire_test.gd`, `pin_test.gd` and
      `pin_board_v2_test.gd` regression suites, and a before/after windowed
      capture (`captures/d2_4_v2_clerical_before.png` /
      `d2_4_v2_clerical_after.png`).
- [x] ~~**D7.4** `v2` The mirror lies the same way every time; the lie should
      fit the body~~ The wobble was four universal constants — every
      character's mirror distorted with the exact same waveform regardless
      of what was on the sheet. `_mirror_distortion()` reads real data
      instead: race's own `build` factor damps the amplitude, the chosen
      skeleton sets rigidity (plated/dense barely move, hollow swims), and
      race shifts the wobble's phase so two races do not only differ in size
      but in how they actually distort. Deterministic per sheet — the same
      character lies the same way twice, which is still the point.
      Verified: `tests/intake_body_test.gd` (new, part of a 6/6 suite shared
      with D8.5 v2) plus a side-by-side windowed capture
      (`captures/d7_4_v2_mirror_plated.png` / `d7_4_v2_mirror_hollow.png`)
      showing a plated Roadborn's near-still silhouette against a
      hollow-skeleton Unreset's visibly irregular one.
- [x] ~~**D8.5** `v2` Declining a modifier is the harder difficulty and the
      game never acknowledges it~~ A modifier absent from `sheet.modifiers`
      read identically whether it was actively refused or simply never
      offered — there was no fact anywhere distinguishing "chose the hard
      way" from "there was no choice". `apply_to_world()` now records which
      modifiers were declined onto the sheet itself and, the same way N2.2
      already acknowledges an overspent build, as a real `modifiers_declined`
      WorldHistory event naming the player — which surfaces automatically in
      `world_index.gd`'s existing "WHAT THE WORLD RECORDED" section with no
      new UI needed, since that section already lists any event mentioning
      the subject. Verified: `tests/intake_body_test.gd` (new, 6/6 total —
      the sheet records exactly the declined set and excludes the one
      actually signed for, and a real event names the player and what they
      declined).


### D v10 — the final pass
The last rung. Fifteen statements that are true of character creation when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **D10.1** `v10` The sheet you fill in is the body that walks out, with nothing lost between
- [ ] **D10.2** `v10` The quiz matters mystically rather than statistically
- [ ] **D10.3** `v10` No option on it is strictly better than another option
- [ ] **D10.4** `v10` The handler is a person who varies decanting to decanting
- [ ] **D10.5** `v10` Everything chosen here is visible on the rig afterwards
- [ ] **D10.6** `v10` The record of your intake is readable by every faction later
- [ ] **D10.7** `v10` Nothing is chosen from a dropdown that could be chosen by doing
- [ ] **D10.8** `v10` A clerical error is possible and auditable at a real cost
- [ ] **D10.9** `v10` What you were made for is not what you have to become
- [ ] **D10.10** `v10` The vat is a place, and leaving it is a movement
- [ ] **D10.11** `v10` Two players making the same choices get two different bodies
- [ ] **D10.12** `v10` It takes minutes, not an hour: Greg's rule is no faffing at the start
- [ ] **D10.13** `v10` The intake is where the godhead first notices you, quietly
- [ ] **D10.14** `v10` Your sheet is the seed the restart reads to make the next universe differ
- [ ] **D10.15** `v10` Everything on it can be undone later at a price somebody sets

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

### E2 v2 — burn and bind, in 3D
Greg: *"burn and bind seals should have their own animation based on real
life, where the person's computer motherboard appears in 3D and the seals
burn into the microscopic copper stuff as sigils on the board, like a full
animation for it when a seal is burnt"*. The right image for this game's
whole thesis: a printed circuit board *is* a sigil, drawn in copper,
mass-produced by the million.

- [x] ~~**E2.2** The 72 Goetic seals as data~~ Same item as above — see E2.2.
- [x] ~~**E2.3** Original seals for what this world grew on its own~~ Same
      item as above — see E2.3.
- [x] ~~**E2.4** Seals animate, corrupt, **burn and bind**~~ `draw_seal_burning`
      existed and only ever ran in 2D; this is the 3D half, and it draws the
      exact same `CellOutzType.seal_strokes()` geometry the 2D app already
      uses — never a second shape invented for 3D. New `systems/motherboard.gd`:
      `begin_bind()` grows the seal additively in the same construction order
      `draw_seal_forming` reveals it in (ring, then each spoke and its hook or
      loop, then the chords, then the core), ending as a permanent raised,
      lit copper trace; `begin_burn()` consumes it from a seeded front the
      same way `draw_seal_burning` already does, ending — "burn 1.0 leaves
      nothing but the memory of the ring", kept true in 3D — as a permanent
      char scar. Both bake onto the board and stay once the animation ends;
      a board accumulates every seal it has actually carried
      (`bound_seals`/`burnt_seals`).

      Follow-up: "each and every" named a cutscene that did not exist —
      `begin_burn`/`begin_bind` took one seed and ran one animation, and all
      72 `GoeticSeals.GOETIA` entries existed only as data. `begin_full_sequence(mode,
      per_seal_duration)` is a director on top of that, not new drawing
      machinery: it walks the roster in Mathers' own listed order, seeding
      each demon's shape off `hash()` of its own name, and the instant one
      seal's own real bake completes it chains straight into the next —
      `sequence_seal_started`/`sequence_finished` are the two signals a
      cutscene or subtitle track hooks into. `tests/motherboard_sequence_test.gd`
      (10 checks) drives it end to end: all 72 genuinely start and bake, in
      the right order, with 72 distinct seeds, `sequence_finished` firing
      exactly once, and a second call restarting cleanly from Bael rather
      than layering two queues.

      Captured both ways rather than assumed: burning's permanent mark is
      deliberately minimal by E2.7's own rule ("burn 1.0 leaves nothing but
      the memory of the ring"), and that is just as true stacked 72 deep as
      it is for one — `e2_4_motherboard_sequence_burn_finished.png` reads as
      barely more than a single burnt seal, which is honest rather than a
      fault in the director. Binding does not share that limit: every
      stroke of every one of the 72 stays as permanent lit copper, and
      `e2_4_motherboard_sequence_bind_finished.png` is a dense, legible tangle
      of 72 overlaid seals — the far stronger image if a cutscene wants "each
      and every" to actually read as all of them. `e2_4_motherboard_sequence_live.png`
      is one demon caught mid-burn, confirming the individual live animation
      inside the sequence looks exactly like the single-seal version already
      on file. Which mode the finished cutscene actually uses is a direction
      call, not something decided here.
- [x] ~~**E2.5** The board is a real board: traces, pads, silkscreen, a chip
      that reads as a chip~~ Procedural, the same way every other object in
      this game is built — no imported asset. Manhattan-routed copper traces
      (seeded turns, not straight wires, routed around the seal's own
      reserved patch rather than through it), a black IC package with pins
      down two sides and a pin-1 notch, a silkscreen outline around its
      footprint, and two capacitors, so the board reads as populated rather
      than a diagram with one component on it.

      Follow-up: only had one metal. A real board plates its actual contact
      points — pads and IC leads, wherever a socket or a finger actually
      touches — in gold over the bare copper underneath, because copper
      alone corrodes and a connection has to survive being made and broken.
      `GOLD` (`#f0c85a`) now sits on the chip's twelve legs and every trace's
      end pads; the traces themselves stay `COPPER`, since the run of wire
      between contacts was never the part that needed the second metal.
      `tests/motherboard_gold_test.gd` (4 checks) walks the built mesh tree
      rather than reading the constants back at themselves — real gold-toned
      instances present, real copper-toned instances still present alongside
      them, and specifically more gold than just the chip's own twelve legs
      accounts for. Captured in `game/captures/` (via `motherboard_capture.gd`,
      re-run): pads read as a visibly brighter tone at each trace joint and
      the chip's legs read gold against the black package, without the
      board's overall read changing.
- [x] ~~**E2.6** Burning is subtractive and binding is additive — one scars
      the copper, one completes a circuit~~ Built into `begin_bind()`/
      `begin_burn()` directly (see E2.4) — binding only ever adds strokes,
      burning only ever removes them, and the two are visually distinct
      (lit copper vs. dark char) rather than the same mark tinted two colours.
- [x] **E2.8** `v3` The board has two metals — copper is the etched trace, gold is plating, and plating goes exactly where something has to make contact: the edge connector's fourteen fingers and the chip's legs. Greg asked for *"copper and gold wiring"* and the board had only copper, which also meant a seal arriving somewhere new had no way to say so in the material
- [x] **E2.9** `v3` Each and every one of the seventy-two is infused into the chip, not left on the board — `begin_procession()` walks the Ars Goetia in traditional order, seeding each seal off its own number times 7919 so Bael and Agares are not neighbours and the same demon is the same glyph every run. A seal burns in as before, then the same geometry collapses into the chip, copper going in and gold arriving. Seventy-two burns would have been seventy-two overlapping scars on one patch; seventy-two infusions leave a chip whose legs sit brighter the more it holds. Rendered in `tests/infusion_capture.gd`
- [x] **E2.10** `v3` The seal's reserved patch is reserved from everything, not only from routing — two capacitors sat inside `SEAL_RADIUS` and every seal ever drawn went straight through them
- [x] **E2.11** `v4` Copper, gold **and rust** — the third state. Copper oxidises to brown scale and then to green patina, and a board out of the Ashbloom has been doing that for years, so it is a dial rather than a colour: the same board reads as new on a bench and as scrap in a pile. Gold does not corrode, which is why it is on the contacts, and why a rusted board still has bright fingers
- [x] **E2.12** `v4` The board is TouchDesigner-driven in the sense FINAL_V §16 actually permits — TD cannot run in a shipped game, so being "TD based" means every number worth tuning is reachable from a slider while you watch. `Motherboard.set_dial()` is the same contract `psychedelic_rig.gd` exposes and `OSCBridge.drive()` calls, so `bridge.drive(board)` is the whole wiring. Seven dials: `corrosion`, `patina`, `copper_gloss`, `gold_gloss`, `trace_glow`, `die_glow`, `chip_charge`
- [x] **E2.13** `v4` The CPU at die scale, delidded on purpose — a heat spreader is a metal lid and hides everything worth seeing. Substrate, land grid, silicon die well under package size (the fact that makes a CPU look like a CPU), Manhattan-routed metal layers in two crossed sets, four functional blocks so the die is not a uniform mesh, and gold bond wires arcing off the die edge to substrate pads: the only curves on the whole board, which is why they read. `tests/cpu_capture.gd`
- [x] ~~**E2.7** A bound seal keeps working while the board keeps power, and
      a burnt one is gone for the run~~ Decided in `ritual_app.gd`, not the
      board — `attempt()` reads the exact repeat count `Boons.grant()`
      already keeps to price a repeat higher (E4.3): a first casting always
      binds, since burning it on the second use would never let E4.3's
      escalating cost matter, and the risk of a burn climbs with every
      repeat after that. A burnt `ritual_id` is written onto the subject
      (`burnt_rituals`) and every further `attempt()` at it is refused
      outright — "THIS SEAL IS BURNT. IT WILL NOT ANSWER YOU AGAIN." —
      permanently, for the rest of the run, rather than merely costing more.
      Verified: `tests/motherboard_test.gd` (new, 15 checks — a real
      populated board, a bind growing additively and finishing on its own,
      a separate burn consuming subtractively, and both sharing the exact
      2D seal geometry) and `tests/ritual_burn_bind_test.gd` (new, 12 checks
      — a first casting always binds, repeats can burn deterministically,
      a burnt seal refuses unconditionally afterward, and the outcome is
      recorded both on the subject and in the world's own event ledger),
      plus the existing `ritual_app_test.gd`, `seal_draw_test.gd` and
      `goetic_seals_test.gd` regression suites, and a windowed capture
      sequence (`captures/e2_5_motherboard_bare.png`,
      `e2_4_motherboard_binding.png`, `e2_4_motherboard_bound.png`,
      `e2_4_motherboard_burning.png`, `e2_4_motherboard_burnt.png`).

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

- [x] **E8.1** Sit down and stop — a held state, not a button that grants a buff — `systems/meditation.gd`: `begin()`/`tick()`/`end()`, progress accumulated from the caller's own real elapsed time (same pattern `carry.gd`'s `age()` already uses) rather than a wall-clock read; refuses to restart on top of an existing session so a second call cannot silently hide an interruption
- [x] **E8.2** It restores stamina faster than standing, and pays down pain rather than health — `PAIN_RATE` pays down `pain` on the same `anatomy_state` ledger `boons.gd`/`substances.gd` write into; stamina lives in a live movement component this file can't see, so `STAMINA_MULTIPLIER` (2.5x) is offered for whoever owns that value to apply rather than a second stamina field invented here
- [x] **E8.3** Interrupted is worse than never started — `interrupt()` adds real pain (`shock`, scaled by how deep the session had gotten) distinct from `end()`'s clean, costless stop; verified a session interrupted at 20s ends up with *more* pain than a session that was never held at all
- [x] **E8.4** Where you sit matters: signal, territory and who is nearby all read — `begin(subject_id, context)` records whatever the caller actually observed (signal grade, territory, nearby subjects) once, at the moment sitting down happened, rather than this file querying a live scene it cannot see
- [x] **E8.5** Deep enough, it reaches the entity layer the way a door substance does — slower, cheaper, and it cannot be rushed — past `ENTITY_THRESHOLD_SECONDS` (60s of real accumulated time, never a single call), `tick()` calls the exact same `AscentEntities.glimpse()` a door substance does — no attention spent, no `wash()`
- [x] **E8.6** It is the only route that costs the body nothing, which is why it is slow — verified: a tick that pays down pain leaves blood untouched, unlike every `Boons`/`Substances` grant. Covered by `tests/meditation_test.gd` (20 checks)
- [x] **E6.3** The door to the entity layer — a "door" substance calls `AscentEntities.glimpse()`, a real recorded `entity_glimpsed` contact that costs nothing of the entity's attention and cannot be spent on `wash()` — distinct from `regard()`'s earned notice
- [x] **E6.4** Production and sale economy — `carry.gd`'s `take_substance()` carries one the same way a robbed part is carried (same wallet, `sale_value()` now prices `kind: "substance"`, same spoil clock). Covered by `tests/substances_test.gd` (16 checks)

### E7 — Route endings
- [~] **E7.1** Become a demon; the soul is signed over — `systems/route_endings.gd` detects and permanently records crossing the Descent threshold (`-0.85`, near CellOutz's own `-0.95`) from real accumulated karma. What's missing: any actual consequence of having signed away (locking further karma, a title card) — that needs either scene/UI work or an API request into `world_history.gd`'s `_accumulate_karma()`, which is Codex's file
- [~] **E7.2** Climb far enough and keep playing — same file, the Ascent threshold (`0.85`). "Keep playing" specifically is already true by default (nothing here ends the game either way); what's missing is anything that reads `route_ending_recorded` to make the moment felt
- [x] **E7.3** Both endings written into world history — `route_ending_reached` event plus a permanent `route_ending` field, written exactly once (re-checking returns the same answer without re-recording). Covered by `tests/route_endings_test.gd` (9 checks)

---


### E v10 — the final pass
The last rung. Fifteen statements that are true of factions and standing when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **E10.1** `v10` Standing is computed from what you did, never awarded
- [ ] **E10.2** `v10` Every faction keeps its own record and they disagree
- [ ] **E10.3** `v10` A faction refuses to sell you things before it refuses to talk to you
- [ ] **E10.4** `v10` Climbing one ladder is visible to the other ladder
- [ ] **E10.5** `v10` Factions keep hours and are not reachable at all of them
- [ ] **E10.6** `v10` Rank shows on the body and in how rooms treat you
- [ ] **E10.7** `v10` Nothing about standing is displayed as a number in a corner
- [ ] **E10.8** `v10` A faction can collapse, and its holdings go somewhere
- [ ] **E10.9** `v10` The Choir prices what you carry against who you are to them
- [ ] **E10.10** `v10` Reputation decays if you stop practising it
- [ ] **E10.11** `v10` Somebody inside a faction can be turned without the faction knowing
- [ ] **E10.12** `v10` Factions sit on the pyramid at their real power and they move
- [ ] **E10.13** `v10` You can be outcast from all of them and the game still works
- [ ] **E10.14** `v10` A sigil can reach a faction, badly
- [ ] **E10.15** `v10` What each faction believed about you carries into the next universe

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


### F v10 — the final pass
The last rung. Fifteen statements that are true of the hunt when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **F10.1** `v10` A rival is made by what happened, never spawned as a rival
- [ ] **F10.2** `v10` Their body remembers the specific damage you did
- [ ] **F10.3** `v10` Their tactics come from the record, read fresh, never cached
- [ ] **F10.4** `v10` A rival who fled comes back changed in a way you can see
- [ ] **F10.5** `v10` Death opens a real succession and somebody takes the place
- [ ] **F10.6** `v10` Being hunted is the same system pointed at you
- [ ] **F10.7** `v10` The law is a hunter with a jurisdiction
- [ ] **F10.8** `v10` Bounty work for the top angels or the top demons is the job market
- [ ] **F10.9** `v10` A contract is consumable and costs something to take
- [ ] **F10.10** `v10` Elites cannot really die, which is why hunting them is work not war
- [ ] **F10.11** `v10` Hunts run while you are elsewhere
- [ ] **F10.12** `v10` A hunt can be inherited by somebody who never met you
- [ ] **F10.13** `v10` Nothing in a hunt is scripted to find you
- [ ] **F10.14** `v10` The godhead is the last hunter and it does not need to look for you
- [ ] **F10.15** `v10` Who hunted you is the thing the next universe knows

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
- [x] ~~**G2.3** Fungal bloom in the wheel wells and dried spatter on the
      flanks~~ Spatter was gated off the AI wreckers pending diagnosis (see
      history below); re-tested 2026-09-13 and restored to all twelve.
      Verified: `tests/derby_balance_test.tscn`, 3 consecutive headless runs,
      0 failures each (real impacts fired, 2 at strongest 4.2 m/s, hull 95 —
      identical to the gated baseline), and a close probe capture inspected
      directly (dark maroon flank blotches render cleanly, no z-fighting or
      stray geometry). `include_spatter` parameter removed from
      `Silhouette.dress_vehicle` / `_dress_vehicle_biopunk` since it is
      unconditional again.
      History: found 2026-09-12 — adding the spatter patches to all twelve AI
      wreckers reproducibly zeroed every hunter-player impact for a full 30s
      heat, while the identical patches on the parked player car, and
      everything else in this kit on the wreckers, measured clean. No
      collision shape is involved anywhere in the kit, so it was reproduced
      and gated rather than root-caused. It does not reproduce against the
      current chassis; the leading suspect is `FINAL_APPROACH_ALIGNMENT`
      (G0.4), lowered from a value already on record as sitting on a knife
      edge, after this gate was written — not this kit. If a future change
      reopens this, check that margin before re-gating spatter.
- [ ] **G2.4** Re-export carrying the biopunk palette natively. Still needs
      Greg's hands: `regrime()` already remaps the toybox material names in
      `art/scrap_skiff.glb` onto the biopunk palette at load, and the kit
      above adds procedural detail on top, but the base mesh itself (bonnet,
      cabin, panels) is only reachable by re-exporting from
      `art/scrap_skiff_v1/scrap_skiff.blend`.

      **Scope widened by Greg, 2026-09-13:** *"this should not only just be for
      the cars but for the whole hud and gui in the entire game."* The palette
      is currently a remap applied at vehicle load. Making it the game's
      palette means one source of colour that the HUD, the handheld pages, the
      Board and the map all read from, rather than each surface carrying its
      own constants — `living_map.gd` alone declares nine (`VOID`, `PLATE`,
      `INK`, `ACID`, `SPORE`, `ARTERIAL`, `BILE`, `SCAN`, `BONE`), and
      `black_mirror.gd` declares six more. That is a palette module plus a pass
      over every drawing surface, and it is a bigger job than the re-export it
      is written under. It should probably be its own segment.

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
- [x] ~~**G0.4** Broke again 2026-09-13, silently, from outside this file~~
      `tests/derby_balance_test.tscn` started failing ("hunters commit to a
      final approach (0 observed)", peak alignment 0.900-0.908) while merging
      the `codex/game-planning` and `agent-b` branches — deterministically,
      confirmed with `--fixed-fps 60` giving the identical number, so not
      frame-timing noise. `rift_derby.gd`, `derby_ai_driver.gd` and
      `arcade_vehicle.gd` are byte-identical between the passing standalone
      branch (`codex/game-planning` alone: peak alignment 0.957, checked in
      an isolated worktree) and the failing merged one, and disabling
      driver-rig construction entirely only moved the number from 0.908 to
      0.900. The actual mechanism was not found: something in a ~150-file,
      many-lane merge shifted an unrelated value enough to tip a threshold
      that G0.1-G0.3 already knew sat on a knife edge. `FINAL_APPROACH_ALIGNMENT`
      lowered from 0.93 to 0.85 — a real margin under the measured 0.90 floor,
      not a nudge to just clear it — since a value sitting exactly on its own
      evidence is what broke the first time. Verified 0/9 failures across
      three repeated runs post-fix (hull 79, 2 approaches, 8 real impacts).

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


### G v10 — the final pass
The last rung. Fifteen statements that are true of sound when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **G10.1** `v10` Where you stand decides what you hear, everywhere, with no exceptions
- [ ] **G10.2** `v10` Every bus is real and every slider moves something
- [ ] **G10.3** `v10` Underground sounds like underground
- [ ] **G10.4** `v10` A station that is off air is off, not quiet
- [ ] **G10.5** `v10` Sound carries damage: a wrecked engine sounds wrecked
- [ ] **G10.6** `v10` The hour changes the mix
- [ ] **G10.7** `v10` Weather is audible before it is visible
- [ ] **G10.8** `v10` Bodies make sound appropriate to what is left of them
- [ ] **G10.9** `v10` Nothing loops audibly
- [ ] **G10.10** `v10` Voice acting exists for the godhead and for the handler
- [ ] **G10.11** `v10` Proximity chat puts a voice where a head is
- [ ] **G10.12** `v10` Silence is used deliberately and often
- [ ] **G10.13** `v10` Music is diegetic or it is the shadow realms, never wallpaper
- [ ] **G10.14** `v10` Every sound in the game is generated or recorded for it
- [ ] **G10.15** `v10` The mix holds at 3am and at noon without being re-tuned

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


### K v3 — the third pass
v2 deepened a cosmology with no apex. AQ: *"the one true godhead, being commenting and enslaving us all in its own lessons and learning, is the fightable true end game boss"*.
- [ ] **K3.1** `v3` The godhead exists in the cosmology as its top, and is fightable
- [ ] **K3.2** `v3` It enslaves through teaching, which is its whole character

### K v4 — the fourth pass
v3 named a final boss the player has no relationship with. It should not be revealed; it should accumulate.
- [ ] **K4.1** `v4` It taunts long before it is reachable
- [ ] **K4.2** `v4` Visibility builds from what you have done, never on a timer

### K v5 — the fifth pass
v4 made it present and left nowhere for it to take you. *"summons your conscious spirit in the shadow realms of the higher realms"*.
- [ ] **K5.1** `v5` The shadow realms of the higher realms as a real destination
- [ ] **K5.2** `v5` It summons you; you never travel there

### K v6 — the sixth pass
v5 built the top of the cosmology and the middle is empty. AO2.2: a god for each planet, the moon and the sun.
- [ ] **K6.1** `v6` Planetary gods, and they are visible at their hours
- [ ] **K6.2** `v6` They are not the godhead and they do not agree with it

### K v7 — the seventh pass
v6 populated the sky with powers and gave the player no way to stand toward any of them. AR1: the tree of life.
- [ ] **K7.1** `v7` The tree is the map of the paths, drawn and readable
- [ ] **K7.2** `v7` Paths open at canon story beats rather than at levels

### K v8 — the eighth pass
v7 let the player choose a path and every path still ends the same way.
- [ ] **K8.1** `v8` Siding with the godhead is a real option with a real ending
- [ ] **K8.2** `v8` So is turning the demons on it (AR1.5)

### K v9 — the ninth pass
Eight passes on who is above; AO2.3 says the seals broke and nobody has dealt with the consequence.
- [ ] **K9.1** `v9` Every demon is observable because the seals are gone
- [ ] **K9.2** `v9` Every sigil is live again, and capturable (AJ, AO2.4)

### K v10 — the tenth pass
Nine passes on one universe. T1.1 is answered: the universe restarts and you do not.
- [ ] **K10.1** `v10` The cosmology is not identical in the next universe
- [ ] **K10.2** `v10` What the godhead learned about you is the thing that carries

- [ ] **K10.3** `v10` Lesser demons want things of their own and pursue them
- [ ] **K10.4** `v10` The ascent and the descent are both fully playable
- [ ] **K10.5** `v10` A god for each planet, the moon and the sun, in a broken sky
- [ ] **K10.6** `v10` The seals are gone and every demon is observable
- [ ] **K10.7** `v10` Every sigil is live and capturable
- [ ] **K10.8** `v10` The godhead is at the top and it is fightable
- [ ] **K10.9** `v10` It teaches, and the teaching is how it takes you
- [ ] **K10.10** `v10` The tree charts which way you went
- [ ] **K10.11** `v10` The pyramid charts who is above you
- [ ] **K10.12** `v10` Siding with any of it is a real ending
- [ ] **K10.13** `v10` Nothing in the cosmology is explained at you in prose
- [ ] **K10.14** `v10` The satire lands on institutions, never on believers
- [ ] **K10.15** `v10` The next universe does not have the same cosmology

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


### L v3 — the third pass
v2 finished a board that is a screen you open. AH1.1: opening it should put you in a room.
- [ ] **L3.1** `v3` The Board is on a wall in a room you are standing in
- [ ] **L3.2** `v3` Turning to it is a movement, not a menu (Rule 3)

### L v4 — the fourth pass
v3 gave the Board a place and it still only holds what you noticed. Greg: *"unlocking the true world's canonical pinboard as the story beats that matter get hit"*.
- [ ] **L4.1** `v4` A canonical layer that opens as real story beats land
- [ ] **L4.2** `v4` What is canon and what is your theory are visibly different things

### L v5 — the fifth pass
v4 made the Board authoritative about the plot and silent about your path. AR1.6.
- [ ] **L5.1** `v5` The tree of life pins onto the Board
- [ ] **L5.2** `v5` Your own route through it is readable there

### L v6 — the sixth pass
v5 charted where you went and not who is above you. AI2.4: the two charts are one document.
- [ ] **L6.1** `v6` The pyramid pins onto the same wall
- [ ] **L6.2** `v6` A theory can connect a tier to a person to a holding

### L v7 — the seventh pass
v6 made the wall the whole world model, sourced only from you. AK2.3: the agency publishes too.
- [ ] **L7.1** `v7` The agency's claims pin on like anybody else's
- [ ] **L7.2** `v7` Some of it is true and the Board never says which

### L v8 — the eighth pass
v7 filled the wall with other people's claims and none of them have walls. 
- [ ] **L8.1** `v8` Other people keep boards, and theirs disagree with yours
- [ ] **L8.2** `v8` A board can be found, read, defaced or taken

### L v9 — the ninth pass
v8 made boards a thing the world has; yours still resets with the run.
- [ ] **L9.1** `v9` The wall persists the way the ledger does
- [ ] **L9.2** `v9` What you were wrong about stays pinned

### L v10 — the tenth pass
Nine passes making the Board the record. T1.1 says the universe restarts and you do not — so the Board is the only continuous thing.
- [ ] **L10.1** `v10` The Board is what carries across a quantum restart
- [ ] **L10.2** `v10` It is the save file, in the fiction and in fact

- [ ] **L10.3** `v10` A string between two pins is a claim you are making
- [ ] **L10.4** `v10` Publishing a theory has consequences when you are wrong
- [ ] **L10.5** `v10` The canonical layer opens as real story beats land
- [ ] **L10.6** `v10` The tree pins onto it
- [ ] **L10.7** `v10` The pyramid pins onto it
- [ ] **L10.8** `v10` Other people's claims pin onto it, including the agency's
- [ ] **L10.9** `v10` Some of what is pinned is false and the game never says which
- [ ] **L10.10** `v10` Other people keep boards and theirs disagree with yours
- [ ] **L10.11** `v10` A board can be found, read, defaced or taken
- [ ] **L10.12** `v10` It persists the way the ledger does
- [ ] **L10.13** `v10` What you were wrong about stays pinned
- [ ] **L10.14** `v10` It is the save file, in the fiction and in fact
- [ ] **L10.15** `v10` It is what carries across the restart

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

- [ ] **G7.1** Decide whether the spawn is meant to be this dark, or raise it —
      still Greg's call, not touched.
- [x] ~~**G7.2** If it stays dark, the near field still has to read — contrast,
      not brightness~~ The `"dirt"` material kind (`WorldLook.surface()`) is
      `oil_asphalt`/`dead_forest`/`quarry_concrete`-dark (0.03-0.09 albedo) at
      0.97 roughness with no rim — a flat ground plane facing mostly away from
      the low sun and a dark zenith has nothing to reflect, so it goes solid
      black regardless of ambient energy. Gave it the same rim trick `"flesh"`
      already uses (`rim_enabled`, `rim` 0.3, `rim_tint` 0.75): grazing angles
      now pick up the horizon glow that was already lighting the mid-ground
      buildings, so the near field reads as a lit surface with a gradient
      instead of a black hole. Global exposure/ambient untouched, so nothing
      else in frame changes. Verified: `game/captures/g7_2_ground_rim_before.png`
      vs `g7_2_ground_rim_after.png` (Hunt Grounds spawn) — foreground ground
      now carries a visible warm gradient instead of flat black. Checked for
      collateral: `dirt` is also every asphalt surface `regrime()` produces, so
      re-shot the derby pit floor before/after
      (`game/captures/g3_lights_before_rim.png`/`_after_rim.png` in
      `P:/GameDev/Temp`, not archived — floor markings identical, no colour
      regression against G3.3's neutral-light fix) and re-ran
      `tests/derby_balance_test.tscn`: still 0 failures.
- [x] ~~**G7.3** Check the same numbers at the districts and at the derby, not
      only at spawn~~ Same sampling as the original G7 finding (average
      frame brightness, every 8th pixel), run against all five
      `AshbloomWorldGenerator.DISTRICT_CENTERS` and against `rift_derby.tscn`.
      Districts read **darker** than spawn, not lighter: 0.0958-0.1106 across
      the five, against spawn's 0.134-0.148. The derby is the outlier in the
      other direction at 0.1851 — G3.3's neutral floodlights actually light
      the pit. Looked at the captures, not just the number: the district
      streets are narrow lot-to-lot canyons (`ashbloom_world_generator.gd`'s
      8-17m-wide lots a few metres apart), so there is far less open sky for
      G7.2's rim trick to catch than the bone yard's open field the original
      fix was shot against — the road is the same `"dirt"`/rim material
      either way, it just has less horizon in view. Not a second instance of
      G7.2's bug, and not something a material change fixes: it is G7.1's
      question again, one level down — is a lot-to-lot street meant to read
      this dark. Left to Greg alongside G7.1. Verified:
      `game/captures/g7_3_district_3.png` (district 3, the one with the
      tower silhouette — the darkest of the five), `game/captures/g7_3_derby.png`.

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


### H v10 — the final pass
The last rung. Fifteen statements that are true of somewhere of your own when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **H10.1** `v10` A place you hold is a place on the map that other systems read
- [ ] **H10.2** `v10` It accumulates what you leave in it
- [ ] **H10.3** `v10` It can be raided, and the damage stays
- [ ] **H10.4** `v10` It repairs over a month if somebody is holding it
- [ ] **H10.5** `v10` The room with the bed and the mirror is the first one
- [ ] **H10.6** `v10` The Board is on its wall
- [ ] **H10.7** `v10` The cloud terminal is to the right of it
- [x] **H10.8** `v10` You can sleep, and sleeping moves the clock — a physical
      bedroll now sits within reach of the Hunt's opening route and owns a
      contextual `[E] REST ... WAKE AT 07:00` interaction. Rest advances the
      one persisted `WorldClock` forward to the next dawn, immediately updates
      the world's light, and records the exact elapsed hours, waking stamp and
      calendar date as `player_slept`; it does not run a second timer or silently
      edit the sky. A living hostile within 18 metres refuses the action without
      moving time. `tests/sleep_site_test.gd` proves the physical site, reach,
      forward clock movement, ledger receipt, distance gate and danger refusal
      (7 checks); `world_clock_test` remains green. The live dusk encounter and
      its prompt were opened at `captures/h10_8_sleep_site.png`.
- [ ] **H10.9** `v10` What is stored there is really stored, not a menu
- [ ] **H10.10** `v10` Somebody can be waiting in it when you come back
- [ ] **H10.11** `v10` Holding it costs something ongoing
- [ ] **H10.12** `v10` It is visible from outside and reads as yours
- [ ] **H10.13** `v10` A second one changes how the first one works
- [ ] **H10.14** `v10` Losing it is survivable and it hurts
- [ ] **H10.15** `v10` It is the only thing in the game that looks like it is on your side

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

- [x] ~~**I3.1** Decide the approach~~ Was blocked on "mirror the real
      content, or fictionalise it?" — asked Greg directly rather than
      guessing, since `country_town_menu.gd` already `OS.shell_open`s the
      real, live `celloutz.xyz`, so this was never a purely fictional call.
      Answer: fictionalise it. The in-game version is CellOutz-the-corporation
      (the company that makes the handheld and the Wire itself), not a
      reproduction of the real page.
- [x] ~~**I3.2** Build the site as a reachable place on the Wire~~
      `broken_web.gd` (I2) already had the whole catalogue-of-sites machinery
      built — `SITES`, `reachable_from(emitter_id)`, `draw_site()` — and a
      `celloutz_support` entry, but nothing anywhere in the game ever called
      any of it; I2's own "reachable" was never actually reachable by a
      player. Added a `celloutz_store` entry with its own new `storefront`
      layout (a product grid and a cart — I2.2 forbids reusing "corporate",
      which the support site already has) and wired the whole system into a
      real screen: `SignalField.reading()` now reports the emitter's own
      `id`, `handheld_device.gd` forwards it to the hosted World Index the
      same way it already forwards `signal_grade`, and the WIRE page prints
      a "SITES IN RANGE" strip from `BrokenWeb.reachable_from()` as real
      links (`_site_link_rows()`, feeding `_rebuild_links()` the same way
      every other link on that screen does per I5.2 v2) that open the site
      full-panel and close the same way any other link does — click again.
      This also retroactively makes I2.3 true for the first time: every
      `broken_web.gd` site, not only the new one, is now reachable from
      wherever it claims to be and nowhere else. Verified:
      `tests/celloutz_site_test.gd` (new, 15/15 — the data layer, the signal
      field naming its own emitter, and the World Index actually surfacing
      and following the link), plus the existing `link_test.gd`,
      `index_wire_glow_test.gd` and `index_link_rebuild_test.gd` regression
      suites, and a windowed capture
      (`captures/i3_wire_sites_in_range.png`, `i3_celloutz_storefront.png`).

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
- [x] **I4.3** `v2` Vitality degrades the panels uniformly; a specific wound should damage a specific part of what you are reading — the live six-zone anatomy now collapses into four explicit instrument feeds without introducing another health model: head damage slips/cracks only the top-right portrait, torso damage tears and summons the contextual anatomy/X-ray, either arm shakes and breaks registration only in the held-object reliquary, and either leg disrupts only the lower-left satellite/dead-reckoning aperture. Healing the real zone repairs its instrument because the ratios are derived afresh from `AnatomyComponent.zones` every HUD update. `tests/interface_wound_damage_test.gd` proves clean state, all four mappings, exact ratio transfer, contextual torso display and arm/reliquary delivery (8 checks); `smoking_lung_ui_test` and `hud_transience_test` remain green. The four simultaneous local failures were inspected in the live Hunt at `captures/i4_3_region_wound_ui.png`.


### I v3 — the third pass
v2 made the screens their own medium and the medium is still six separate designs. Greg: *"the entire blackmirror gui needs work"*.
- [x] **I3.1** `v3` One GUI with one grammar, not a set of well-drawn pages —
      all seven Black Mirror apps now live inside one chassis-owned page
      contract: fixed 16:9 glass, inset work surface, persistent header/footer
      rails, mode/role registration, page number, navigation hint and one
      page-specific primary verb. Hosted INDEX/MAP/WIRE panels and native
      RADIO/CARRY/RITUAL/FIELD instruments receive the same content aperture
      instead of each deciding its own edges. `handheld_page_grammar_test.gd`
      verifies the shared bounds and complete seven-page contracts; visual
      evidence: `captures/i3_1_shared_page_grammar.png`.
- [x] **I3.2** `v3` Moving between pages is movement, not a cut — every direct
      jump and cyclic page change now drives a 0.52-second ribbed shutter in
      the shortest travel direction. The old live page remains present while
      it enters; the destination activates and emits `mode_changed` only at
      full occlusion; the new live page is revealed as it exits. The
      deterministic midpoint contract and reversed travel are proven by
      `handheld_page_grammar_test.gd`; visual evidence:
      `captures/i3_2_page_shutter.png` and `i3_2_page_arrival.png`.
      A non-binding decision reel now compares that fallback against equally
      timed cracked-glass corruption and occult-carousel candidates, each with
      digital-tear and glass-resonance sound sketches. No candidate silently
      replaced production: `DESIGN/BLACK_MIRROR_TRANSITION_COMPARISON.md`,
      `captures/black_mirror_transition_comparison.mp4`.

### I v4 — the fourth pass
v3 unified the pages and the weapon is still configured in a list. Greg: *"the slide pops out into a menu if you press shift and lock it, expanding into the weapon customisation, maybe the circle in the middle and 4 boxes around it"*.
- [ ] **I4.1** `v4` Shift pops the slide out and locks it into the customisation menu
- [ ] **I4.2** `v4` A circle with four boxes around it, on the weapon itself

### I v5 — the fifth pass
v4 proved a screen can be an object you operate; the Wire is still a reader. *"a certain number of apps should exist and be playable"*.
- [ ] **I5.1** `v5` Apps on the Wire that are genuinely playable
- [ ] **I5.2** `v5` Some for fun, some load-bearing, same as the arcades in the map

### I v6 — the sixth pass
v5 put games on the phone and nothing social. The doom-scroll app is the satire this project has been circling.
- [ ] **I6.1** `v6` A feed, and drone-zombie spammers dying on it who can be cleared
- [ ] **I6.2** `v6` Clearing local feeds pays, and somebody is paying

### I v7 — the seventh pass
v6 made the phone a place people are; there is nowhere on it that holds what is true. *"also add Akashic records library"*.
- [ ] **I7.1** `v7` The Akashic records as a reachable archive on the device
- [ ] **I7.2** `v7` It disagrees with the Wire, and the game never arbitrates

### I v8 — the eighth pass
v7 made the device a library and it still only reads. The black mirror is a *cursed mirror* and nothing is ever evoked through it.
- [ ] **I8.1** `v8` Evoke an entity through the mirror with the right information
- [ ] **I8.2** `v8` Challenge a soul: free it, enslave it, or kill and revive it into suffering

### I v9 — the ninth pass
v8 made the device dangerous and most objects in the world still cannot be looked at. *"everything should be inspectable, everything in spectacle"*.
- [ ] **I9.1** `v9` Anything in the world can be inspected properly, guns included
- [ ] **I9.2** `v9` Inspection is the same grammar everywhere rather than per-object

### I v10 — the tenth pass
Nine passes designed in a lit room. C v4 made the device the main light source in the world.
- [ ] **I10.1** `v10` Every screen re-judged as the only light in a dark place
- [ ] **I10.2** `v10` What the screen throws onto your hands is part of the design

- [ ] **I10.3** `v10` Every screen is a physical object with a surface and a condition
- [x] **I10.4** `v10` Moving between pages is movement, never a cut — fulfilled
      by the same Black Mirror shutter and hidden-midpoint page swap proven
      under I3.2; the physical casing and glass remain continuous throughout.
- [ ] **I10.5** `v10` Everything in the world can be inspected with the same verbs
- [ ] **I10.6** `v10` A screen is legible while you are being attacked
- [ ] **I10.7** `v10` Screens are readable in the dark and lit by their own emission
- [ ] **I10.8** `v10` The weapon customisation lives on the weapon
- [x] **I10.9** `v10` Damage to you damages the specific part of what you are reading — implemented with I4.3 v2: head/portrait, torso/anatomy, arms/held object and legs/navigation each fail locally from their corresponding live anatomy zone; there is no whole-screen injury filter and no parallel cosmetic damage value.
- [ ] **I10.10** `v10` Nothing is clickable that does not look clickable
- [ ] **I10.11** `v10` Every panel works on keyboard and on the pointer equally
- [ ] **I10.12** `v10` The cursor exists on every screen that hides the OS one
- [ ] **I10.13** `v10` A screen can lie, and the game does not correct it
- [ ] **I10.14** `v10` Load is covered; there is no hard cut anywhere in the build
- [ ] **I10.15** `v10` Somebody watching over your shoulder can follow what you are doing

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

### J5 — The debugger panel tells the truth
128 entries in the Debugger on a clean boot. None of them were a bug in the
game, which is exactly the problem: a panel that is always red is a panel
nobody reads, and a real error has nowhere to appear.
- [x] **J5.1** FMOD's tool scripts stop being parsed — `game/addons/fmod/.gdignore`.
      J1.1 disabled the extension, but the addon's fourteen `.gd` files stayed in
      the filesystem, so every reload re-reported 46 parse errors for
      `FmodServer`, `FmodBank`, `FmodEventDescription` and the rest — native
      classes that the disabled `.gdextension` never registers. Every single
      parse error in the project was one of these; nothing in `game/` and nothing
      in `dialogue_manager` produced one. **Local-only until J1.3**, because
      `.gitignore:3` stops the fix travelling.
- [x] **J5.2** 24 shadowed and confusable locals renamed. Fourteen were
      `CONFUSABLE_LOCAL_DECLARATION` — the same name declared in an inner block
      and again in the parent below it, which is the class of warning that
      precedes a real aliasing bug (`wound_catalog.gd`'s two `result`s,
      `bone_yard_hunt.gd`'s two `actor`s inside and after the same loop). Ten were
      locals or parameters shadowing a method of their own class: `hit`,
      `leads`, `account`, `grade`, `stage`, `album`, `severity`, `grip`.
- [x] **J5.3** 12 unused parameters underscore-prefixed, which is the Godot
      convention for "deliberately ignored" rather than deleted, since the
      signatures are called positionally elsewhere.
- [x] **J5.4** 16 integer divisions annotated `@warning_ignore("integer_division")`.
      Every one was checked and every one was deliberate — grid rows, id digits,
      halving a point budget. The annotation says so at the site, which leaves the
      warning live for the next one that is not.
- [x] **J5.5** A test that fails when the count goes back up —
      `tools/verify-godot-diagnostics.ps1` boots the actual editor headlessly,
      groups `SCRIPT WARNING`/`SCRIPT ERROR` blocks by their `res://` source,
      excludes addon-owned and engine-shutdown noise, and fails above the fixed
      project budget of zero. Its self-test proves shutdown leak noise stays out
      while a synthetic project warning makes the count rise to one; the real
      editor scan passes at 0. The first run immediately earned the gate: it
      caught `the_room.gd` calling the obsolete `BodyMirror.make()` API left by
      a merge. The wall-reflection camera now has its own `RoomMirrorView`
      contract while the freestanding body-following `BodyMirror` remains
      intact. `body_mirror_test` passes 13 checks and the live room diagnostic
      again places all sampled body points inside the wall mirror frustum.

---


### J v10 — the final pass
The last rung. Fifteen statements that are true of infrastructure when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **J10.1** `v10` One region, one truth about where everything is
- [ ] **J10.2** `v10` Nothing is simulated that nobody can observe, and nothing observable is faked
- [ ] **J10.3** `v10` The record is the single source and every system reads it
- [ ] **J10.4** `v10` Saving is safe across every migration the project has made
- [ ] **J10.5** `v10` A scene change frees what it owns and nothing static outlives it
- [ ] **J10.6** `v10` Every static registry is swept at the seam
- [ ] **J10.7** `v10` Tests run headless and prove behaviour, not existence
- [ ] **J10.8** `v10` Every capture test is a PNG somebody looked at
- [ ] **J10.9** `v10` The frame budget is measured, not estimated
- [ ] **J10.10** `v10` Nothing ships that only works in the editor
- [ ] **J10.11** `v10` The build exports from a clean checkout with one command
- [ ] **J10.12** `v10` Determinism where it matters, seeded randomness everywhere else
- [ ] **J10.13** `v10` No system knows about a system above it
- [ ] **J10.14** `v10` Every autoload earns its place or stops being one
- [ ] **J10.15** `v10` A new contributor can find the thing they need in one search

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
**The note above this line was wrong by the time anyone read it again.** It
said there was no first/third-person split in `rift_derby.gd` and deferred
the whole section rather than risk a collision in a file Agent B owns.
Since it was written, `vehicle_interior.gd`/`dash_cluster.gd` — both Lane
1's own files, "driving from inside" — were built in full, and
`rift_derby.gd` wires them in (`INTERIOR := preload(...)`, `in_cab`,
`_fire_from_cab()`). Read and verified here, not built here, and
`rift_derby.gd` itself was not touched.
- [x] ~~**M2.1** First-person driving is the default~~ Cross-ticked against
      `rift_derby.gd`'s own `var in_cab := true` — the cab is genuinely
      where a heat starts, not a chase camera you can optionally step into
- [x] ~~**M2.2** One hand on the wheel; that hand *is* WASD and it is
      visible~~ `VehicleInterior.drive(steer, throttle)` turns the wheel
      and the `left_arm` gripping it by the same `steer` value the chassis
      itself steers on — not a synced animation, the same number. Verified
      against `captures/m2_cabin_straight.png` and
      `captures/m2_cabin_turning.png`: the arm visibly leans with the wheel
- [x] ~~**M2.3** The other hand holds a gun, and you shoot out of your own
      car~~ `gun_arm` is real geometry (a grip, a slide, a barrel), LMB
      calls `_fire_from_cab()` in `rift_derby.gd`, and it is a real weapon —
      a raycast, real ammo (`rounds_left`), a cooldown, and real damage to
      whatever it hits (`_damage_target`), not a cosmetic muzzle flash.
      **Not yet true**: this is a second, simpler firearm system
      (raycast + flat damage) rather than the one AF1/AF1.1 built —
      `Ballistics`' real projectile and `BaselineHuman.hit_at`'s zone
      resolution never enter it. That gap is AF1.8's own, named for exactly
      this reason, and stays open
- [x] ~~**M2.4** You shoot through your own windscreen, and the glass is
      really there~~ `_windscreen()` is a real `BoxMesh` plane in front of
      the camera, lit by the world, and `punch_through()` marks it exactly
      where you aimed rather than a flat screen-space decal. Verified
      against `captures/m2_cabin_straight.png`: buildings beyond the glass
      are genuinely seen through real geometry, not composited
- [x] ~~**M2.5** The glass degrades as the car takes hits — the view gets
      worse as you do~~ `take_hit(severity, at_x)` raises `glass_damage`,
      and `_apply_glass()` turns that into real milky scatter and roughness
      on the same material rather than a health bar somewhere else on
      screen. Verified against `captures/m2_cabin_wrecked.png`: at 5
      recorded hits the windscreen has gone from the clear view in
      `m2_cabin_straight.png` to a frosted wall — the buildings beyond are
      gone, not merely dimmed
- [~] **M2.6** Third-person driving unlocks through derby progress,
      separately from M1 — `_third_person_earned()` in `rift_derby.gd` is
      its own function, read fresh off `WorldHistory` rather than a stored
      flag `bone_yard_hunt.gd` could leak into, which is "separately from
      M1" in the sense that matters for a duplicated-flag bug. What it is
      not separate from is the *condition*: its own comment says so
      outright — "the same condition the Hunt Grounds uses" — a killed
      rival or grudge ≥ 40, not a derby-specific measure like rounds won or
      laps survived. Whether "derby progress" was meant to name a different
      number is Greg's call, not assumed here
- [x] **M2.7** No hard cut between the two views (Rule 3) — the toggle now
      captures the live camera pose and travels for 0.68 seconds through a
      smoothstep interpolation to the moving cab/chase target, including its
      FOV. Both the bodywork and cab shell stay rendered while the eye crosses
      the car; the destination cull mask is applied only on arrival, so neither
      side disappears around the player mid-move. The heat now also begins in
      the cab as M2.6 specifies, rather than exposing its still-locked chase
      view by default. `tests/derby_view_transition_test.gd` proves both
      journeys and both arrival masks (9 checks); `derby_cab_test` and
      `derby_balance_test` remain green. The actual cab, halfway-through-car
      and chase frames were opened and compared at
      `captures/m2_7_view_{cab,midway,chase}.png`.

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

      Follow-up 2: the fix above targeted `hunter_arsenal.gd`'s own
      box-primitive weapon models and was correct for what it touched — but
      that whole system was superseded by `held_gear.gd`'s sculpted meshes at
      "0006 touchdesigner" (`5630b82`), which never inherited it and
      reintroduced the same *class* of bug independently, in the code that is
      actually live today: `BodyMesh.revolve()` extends along its own local
      Y, not Z like `_sweep()` does, and the shotgun's barrel/magazine used a
      Y-axis rotation trying to point them forward — which cannot retarget a
      shape already aligned with Y. The barrel read as a pole pointed at the
      sky, not a stacked blob; the two prior writeups were looking at a
      screen this dark by coincidence, not because the fix above had failed.
      Fixed by rotating on X instead (`barrel.rotation.x = PI * 0.5`, sign
      chosen so `+at` still means "toward the muzzle"), and the same
      correction applied everywhere else `revolve()` carried the identical
      wrong-axis rotation: the shotgun's ribs, and the sword's own
      handle/pommel/wrap — dormant there too, just small enough parts that a
      "reads clean" verdict never caught it. The sidearm has no `revolve()`
      parts at all and was never touched by this specific bug; its
      stacked-block read is the proportions/silhouette problem Follow-up
      already named and it remains open. `tests/viewmodel_capture.gd` now
      forces `WorldClock.set_hour(13.0)` before capturing — the night rework
      landed after this segment was first opened and the world now defaults
      dark enough to make a framing check unreadable by accident. Verified:
      `viewmodel_frame_test.gd`, `magazine_test.gd`, `arsenal_test.gd`,
      `firearm_momentum_test.gd` and `reload_visual_test.gd` all re-run
      clean; all three `game/captures/m4_4_viewmodel_*.png` recaptured at the
      forced hour.
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


### M v10 — the final pass
The last rung. Fifteen statements that are true of cameras and driving when this game is finished, each one an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **M10.1** `v10` First person is the default and third person is earned
- [ ] **M10.2** `v10` The cab is a place you sit in, not a camera position
- [ ] **M10.3** `v10` Every instrument is on the dashboard and none is in a screen corner
- [ ] **M10.4** `v10` One hand steers and the other holds a gun, badly, on purpose
- [ ] **M10.5** `v10` You shoot through your own windscreen and the glass keeps it
- [ ] **M10.6** `v10` Getting out is something you watch happen
- [ ] **M10.7** `v10` The derby is the escape from the facility, not a side mode
- [ ] **M10.8** `v10` Every camera change is a move, never a cut
- [ ] **M10.9** `v10` FOV is one pair of values the whole game agrees on
- [ ] **M10.10** `v10` The camera answers the suspension without smoothing it away
- [ ] **M10.11** `v10` A car is this world's horse: found, taken, hostile, abandoned
- [ ] **M10.12** `v10` Damage to a car is visible from inside it and outside it
- [ ] **M10.13** `v10` Bikes and scrap bikes run the same system
- [ ] **M10.14** `v10` Nothing about driving is a separate game
- [ ] **M10.15** `v10` The tunnel derby and the pit derby are one system in two places

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

- [x] ~~**N5.1** A real slot per site — spine, skull, chest, each arm, each leg, the organ bays~~
      `INSTALL_SITES` (`anatomy_component.gd`) maps eight real sites onto the
      six damage zones a body already has — "torso" alone used to be the one
      slot spine, chest and the organ bays all collapsed onto, so installing
      a chest plate after a spine cage silently erased the spine cage.
      `install_part()` now keys `installed_parts` by the site the caller
      actually asked for rather than by whichever zone the catalog entry
      happens to carry, so all three can be occupied at once, each pulled,
      damaged and read independently. `apply_hit()` and the wound's own
      implant-wear line now sum every site answering to the zone that was
      actually hit, instead of reading a single implant standing in for the
      whole zone. Every existing caller that installs at a bare zone name
      ("head", "torso", a limb) is unaffected — a zone is also a valid site
      of its own, which is also why `FACTORY_LOADOUT`'s three existing slots
      were left exactly where they were rather than moved to the new names.
      Verified: `tests/install_sites_test.gd` (11 checks, new) — a spine
      cage, a chest plate and an organ-bay graft all installed at once
      without erasing each other; a torso hit measurably absorbed more with
      two sites armoured than with none; both sites independently wear from
      that same hit; pulling one leaves the other untouched; "skull" and
      plain "head" hold separate hardware. Thirteen existing tests
      (`implant_lock_test`, `body_inspector_test`, `crystal_ball_test`,
      `armor_resolution_test`, `melee_resistance_test`,
      `weapon_condition_test`, `extraction_test`, `factory_loadout_wired_test`,
      `baseline_human_test`, `combat_integration_test`, `pocket_search_test`,
      `chunk_test`, `radiation_path_test`) re-verified clean against the
      change.
      Still open: `FACTORY_LOADOUT` itself still only fills three of the
      eight real sites now available (skull/spine/chest/organ_bays plus
      four limbs) — moving its three factory items to more specific sites,
      or adding real content for the rest, is a fiction/content decision
      this pass deliberately left alone rather than bundling in.
- [x] **N5.2** Factory hardware fills them at decanting and is *locked*, not
      absent — `install_factory_loadout()`, three real zones (head, torso,
      left arm), each with a real reason CellOutz put it there.
- [x] **N5.3** Locked means discouraged, never disabled: the game warns and
      then lets you — `pull_part(zone_id, confirmed)`: a first call against a
      locked slot only warns; the same call with `confirmed` true is what
      actually pulls it.
- [x] **N5.4** The warning is in CellOutz's voice, not the game's — "you don't
      want to go rogue yet, do you" — `AnatomyComponent.LOCKED_WARNING`.
- [x] **N5.5** Pulling one is recorded, and CellOutz standing reads it (E,
      `faction_price_factor`) — `event_karma()` now prices `implant_pulled`
      when `was_locked` is true: CellOutz's own axis is Ownership, so defying
      their lock is a real Ascent act, not a neutral inventory move.
      Unlocked hardware (robbed or grown, N5.8) does not touch it, since it
      was never their claim. Verified: `tests/implant_lock_test.gd` — CellOutz's
      `faction_price_factor` measurably worsens after a confirmed locked pull
      and does not move again for an unlocked one.
- [x] **N5.6** An empty slot is a real condition — the body works worse without
      what was in it — genuinely mechanical: `apply_hit()` already scales
      incoming damage by `installed_parts[zone].armor * implant_condition()`,
      so an emptied slot takes more damage, not merely reports a zero.
- [x] **N5.7** What you pull is a carried object with a lien on it, because it
      was never yours (B5.4) — `pull_part()`'s successful result is shaped for
      `Carry.take_chunk()` directly, `lien: "celloutz"` attached, verified
      accepted by a real `Carry` instance.
- [x] **N5.8** Robbed and grown hardware fit the same slots — one vocabulary,
      per B2.1 — this was already true in code (`Carry.install_into()` and D4's
      `_grown_cybernetics()` both resolve through the same `ImplantCatalog`
      into the same `installed_parts` dict N5.2 uses) but untested as a real
      spawn path, because **`install_factory_loadout()` — all of N5.2-N5.7 —
      was never actually called outside its own test.** The real player,
      built in `bone_yard_hunt.gd`'s `_build_player_rig()`, walked out of the
      vat with none of CellOutz's hardware and could never see the "you don't
      want to go rogue yet" warning at all. Now wired: a genuine first
      decanting installs the factory loadout, skipping any zone the sheet
      already grew something into, and a restored body is left alone so a
      slot already pulled stays pulled. `left_arm` stays out of it —
      `_accumulate_sever_stress()` treats any installed part on a limb as an
      existing replacement, so filling it would make the arm permanently
      un-severable and regress B6.5/B6.6; a real fix needs the catalog to
      distinguish a full prosthetic from a minor implant, which is N5.1's
      same one-slot-per-zone limitation showing up on limbs instead of the
      torso. Verified: `tests/factory_loadout_wired_test.gd` (new,
      instantiates the real hunt scene three times) — a fresh decant carries
      locked head/torso hardware and a still-severable left arm, a sheet-grown
      part wins its zone over the factory one, and a previously pulled slot
      survives a reload unlocked. `implant_lock_test.gd` and
      `combat_integration_test.gd` re-verified clean.


### N v10 — the final pass
The last rung. Fifteen statements that are true of cybernetics when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **N10.1** `v10` Every slot on the body is real and locked until you open it
- [ ] **N10.2** `v10` Opening one warns you properly and lets you do it anyway
- [ ] **N10.3** `v10` Hardware is visible in the limb that carries it
- [ ] **N10.4** `v10` A severed limb takes its hardware with it
- [ ] **N10.5** `v10` Cybernetics change what movement is possible, not just numbers
- [ ] **N10.6** `v10` Limbs that shoot and grapple run through the anatomy
- [ ] **N10.7** `v10` A crystal ball in the arm or the pocket, and it works
- [ ] **N10.8** `v10` Going too far is a state the world can see on you
- [ ] **N10.9** `v10` The factory hardware you start with is real hardware
- [ ] **N10.10** `v10` Every implant can be taken out by somebody else
- [ ] **N10.11** `v10` Implants are worth money to the Choir and they know whose they were
- [ ] **N10.12** `v10` Nothing installed is purely a stat
- [ ] **N10.13** `v10` Body mods, piercings and tattoos share the system
- [ ] **N10.14** `v10` A build far enough in one direction can answer a rocket with a blade
- [ ] **N10.15** `v10` What you installed is what the mirror shows and the restart remembers

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
- [x] ~~**O2.8** `v4` Gore and chunk physics still run at full speed through
      a hit, so a limb can leave a body that has not moved yet~~ O2.7 v3
      explicitly named this out of scope: chunks are real `RigidBody3D`
      nodes the physics server integrates directly, and a `delta`
      multiply — which is all a scaled clock can offer — cannot reach that.
      `GoreChunks.hold()`/`release()` closes it with the freeze/resume scheme
      O2.7 v3 called for instead of faking: `hold()` (called from
      `bone_yard_hunt.gd`'s `_physics_process` whenever `impact_feel.holding()`
      is true) saves each live chunk's velocity and sets `RigidBody3D.freeze
      = true`, which removes it from physics simulation entirely rather than
      approximating a slowdown; `release()` un-freezes and hands the saved
      velocity straight back, so a severed limb continues its arc instead of
      stopping dead and dropping straight down. Idempotent while already
      held, so a hold spanning several frames does not overwrite the saved
      velocity with whatever it decayed to mid-freeze. Verified:
      `tests/gore_hitstop_test.gd` (new, 6/6 — a chunk is actually frozen
      rather than slowed, its velocity and spin are restored exactly on
      release, and a repeated hold call does not double-freeze or clobber
      the saved state), plus the existing `hitstop_scope_test.gd` (5/5)
      regression suite.

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


### O v4 — the fourth pass
Three passes tuned a swing the player does not perform. AN: LMB plays an animation and the player's whole contribution is the timing of one keypress.
- [x] ~~**O4.1** `v4` `limb_momentum.gd` drives the weapon: it lags, overshoots
      and swings through~~ Built under AN1.1-AN1.3 rather than under this
      number, and left unticked here — `_advance_arm()` runs the spring-damper
      every frame, thrown by the same mouse delta the camera turns by plus the
      player's own velocity, and it lags, overshoots and swings through
      exactly as described. `limb_momentum_test.gd` (10 checks) and
      `tests/firearm_momentum_test.gd` (AN1.7, 7 checks) verify it, the
      second across all three weapons rather than only the sword.
- [x] ~~**O4.2** `v4` The weapon is drawn where the physics put it, not where
      an animation says~~ AN1.3: `_pose_weapon()` reads `arm.at - arm.anchor`
      and offsets the model from its own authored rest pose every frame; the
      hand still animates underneath, but the weapon itself hangs off the
      physics, not the animation. `tests/firearm_momentum_test.gd` confirms
      this reaches every weapon's own model, not just the sword's.

### O v5 — the fifth pass
v4 made the weapon physical and damage still reads a constant off it.
- [x] ~~**O5.1** `v5` Damage asks `commitment()` — the weapon sets the
      ceiling, you earn it~~ Greg, 2026-09-14, with a controller in hand
      rather than in a commit, as the flag's own comment always said the
      call needed: flip it. `momentum_damage` is `true`. The firearms
      guard built in advance of this decision (this same line, previous
      pass) holds — the formula is melee-only, so a gun's low, steady aim
      does not quietly read as permanently low commitment. Verified by
      `tests/arm_wired_test.gd`'s own extended check, on a real body rather
      than the flag alone: a committed swing and a flick with the identical
      weapon, aimed identically, land 34.47 and 13.00 damage respectively —
      not a multiplier confirmed on paper, a difference measured on a
      wound. Full regression suite (14 files) re-verified clean.
- [x] ~~**O5.2** `v5` A flick and a committed sweep are different blows from
      the same button~~ The same flip, the same evidence — this is O5.1's
      own claim from the other side of the button rather than a second
      thing to build. A flick now measurably underperforms a committed
      sweep instead of matching it, which is the entire complaint this
      line and O v4 were both raised to answer.

### O v6 — the sixth pass
v5 made a blow worth what you put in and a weapon you barely hold is still welded to your hand.
- [x] **O6.1** `v6` You can be disarmed, and so can they — an encounter actor
      has no `arm`/`LimbMomentum` object for AN2.2's own trigger to read, but
      it already has the same shape of number in `footing` (O5.10 v2's "same
      meter, same constants, now on both bodies"). Barely standing (below
      `STUMBLE_AT`) and hit hard enough to stagger takes the weapon, through
      `_apply_combat_response()`; footing recovering back past that same
      line gives it back. Disarmed attacks run through the identical
      `_actor_attack_damage()`/`_actor_attack_cycle()` everything else
      already reads, scaled down — low but not a tickle, the same ratio
      bare hands hit for against the player's own cleaver — rather than a
      second combat system. Verified: `tests/npc_disarm_test.gd` (new) — a
      solid stance survives a hit that would disarm a barely-standing one; a
      real WorldHistory event is recorded; disarmed hits measurably softer
      and faster; footing recovering past the line hands the grip back.
- [x] ~~**O6.2** `v6` Mass and reach become the whole balance conversation~~
      Cross-ticked against AN1.5, built under that number rather than this
      one: `ARM_WEIGHTS` is, in its own comment's words, "the entire
      firearms-and-melee balance conversation, expressed as two numbers
      rather than as a table of constants" — a bare hand at 0.4kg, a
      cleaver at 1.45, a shotgun at 3.2, and every one of them the same
      `LimbMomentum` object rather than a second system per weapon class.
      `limb_momentum_test.gd` and `firearm_momentum_test.gd` already verify
      it across melee and firearms both

### O v7 — the seventh pass
v6 finished the human fight. Greg: *"overhauling halfsword combat"* — and the grapple, the shove and the bare hand are still separate systems.
- [x] ~~**O7.1** `v7` Grapple, shove and bare hands are the same object with
      a different mass~~ Cross-ticked against AN1.9, built under that
      number: `grapple` (1.8kg) and `shove` (2.4kg) are `ARM_WEIGHTS`
      entries exactly like `bare` (0.4kg), `sword` or any firearm — the
      same arm the weapon hangs off, re-carried through the identical
      `_carry_current_weapon()` path, not a parallel grapple-specific
      system. Verified by `tests/grapple_mass_test.gd`
- [x] ~~**O7.2** `v7` Two-handing changes the numbers rather than the
      pose~~ The same claim as AN2.5, word for word — built there, ticked
      here against it rather than duplicated. `held_gear.gd`'s `GRIPS`
      table's `reach`, `damage_type` and the new `control` field now reach
      `arm.reach`, `LimbMomentum`'s stiffness and the swing's own
      `damage_type` through `_carry_current_weapon()`/`_attack()`, cycled
      live with `B`. Verified by `tests/two_handing_test.gd` (11/11)

### O v8 — the eighth pass
Seven passes against people. AO4 fills this world with things that are not people.
- [ ] **O8.1** `v8` Demons, greys and reptilians fight through the same system without being reskinned humans
- [ ] **O8.2** `v8` Something with no anatomy still has somewhere to be hit

### O v9 — the ninth pass
v8 made everything fightable and the player can still lose the ordinary way. AP2: the spirit cannot be banished by violence.
- [ ] **O9.1** `v9` Losing a fight is not dying, and the game has to mean that
- [ ] **O9.2** `v9` What being beaten costs you instead

### O v10 — the tenth pass
Nine passes of a damage race, ending in a boss that must not be one. AQ1.6.
- [ ] **O10.1** `v10` The godhead fight is not resolved by damage
- [ ] **O10.2** `v10` Everything O built is present in it and none of it is sufficient

- [ ] **O10.3** `v10` Mass and reach are the entire weapon balance
- [ ] **O10.4** `v10` Hitstop is local to the two bodies in the exchange
- [ ] **O10.5** `v10` Gore and chunks run on the exchange's clock, not the world's
- [ ] **O10.6** `v10` A miss costs footing and a landed blow spends the swing
- [ ] **O10.7** `v10` Guard has a direction and can be flanked
- [ ] **O10.8** `v10` You can be disarmed and so can they
- [ ] **O10.9** `v10` Bare hands, a shove and a grapple are one object with a different mass
- [ ] **O10.10** `v10` Fatigue degrades the guard instead of announcing it
- [ ] **O10.11** `v10` Demons, greys and reptilians fight through the same system
- [ ] **O10.12** `v10` Losing is not dying, and the game means that
- [ ] **O10.13** `v10` Every hit reaches the anatomy, never a hitbox
- [ ] **O10.14** `v10` Nothing in combat is resolved on the frame a key went down
- [ ] **O10.15** `v10` The godhead fight is not a damage race

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
- [x] **P1.1** A curated route through the *real* game, not a separate map — `resume_destination()` chains the actual scenes (`vat_chamber.tscn` -> `rift_derby.tscn` -> `bone_yard_hunt.tscn`); it did so only in name, since `OpeningDirector.advance()` was called by tests and never by real gameplay, so a resumed run always reopened the Growing Floor regardless of progress. Wired at the one chokepoint every real transition already shares (`Interstitial.travel()`), verified in `opening_stage_wiring_test.gd` by driving the three production transitions with no test-only shortcut (6/6)
- [x] **P1.2** The best features front-loaded: anatomy, gore, X-ray killcam, the derby, the Board — all reachable inside the curated route itself: `vat_chamber.gd` is the anatomy/character creation, `rift_derby.tscn` is the derby, and `bone_yard_hunt.gd` instantiates `GoreChunks`, `WorldXray`, `KillCam` and `PinBoard` (the Board) directly (`bone_yard_hunt.gd:702-754,4211`)
- [ ] **P1.3** Generous rather than careful — it should feel like a full game while it lasts
- [x] **P1.4** No dependence on the cosmology being understood; the Horsemen stay off-screen — the whole demo-reachable route (`country_town_menu.gd`, `vat_chamber.gd`, `rift_derby.gd`, `bone_yard_hunt.gd`, `handheld_device.gd`, the opening/interstitial scripts) has zero references to the Horsemen, Thelema or the cosmology systems; the only hit is a design-rationale code comment in `vat_chamber.gd` that never reaches the player

### P2 — Two doors, one build
- [x] **P2.1** PLAY and DEMO sit side by side on the main menu — the existing front door now names both routes directly; the branch picker remains behind PLAY and DEMO is its own immediate row in the same house-type plate
- [x] **P2.2** A single runtime flag distinguishes them — `WorldHistory.run_mode` is either `play` or `demo`; there is no demo project or second export preset
- [x] **P2.3** Demo saves are their own slot and can never touch a real save — demo history resolves only to `user://demo/world_history.json` (and a separate test path under `ATG_TEST_MODE`). `demo_mode_test.tscn` writes unique markers on both sides, changes modes twice, and proves neither marker crosses over (9/9)
- [x] **P2.4** Any feature the demo shows is the real feature, running the real code — the DEMO button enters the existing `_start_game()` path: the production prologue, Growing Floor, derby and Hunt scenes rather than copies of them
- [x] **P2.5** Starting DEMO from the menu is one click, with no configuration in between — `_start_demo()` selects the isolated ledger and immediately hands to `_start_game()`; there is no branch or demo-options panel

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
- [x] **P3.1** The game stops at an authored point, deliberately and visibly — the Hunt freezes under a full-frame `DemoWall` only after its first real story victory
- [x] **P3.2** The stop is in the register — CellOutz closes the demonstration account with a final invoice and bills the balance as `THE REST OF THE GAME`
- [x] **P3.3** It arrives *after* a win, not in the middle of one — the only hook is `_rival_retreats()`, after `hunt_arc_first_beat_complete` records that the Ashline captain was forced from the field
- [x] **P3.4** What the player loses by stopping is made concrete: the invoice names the outer Ashbloom road, the captain's rebuilt second hunt, and Board/Wire contracts
- [x] **P3.5** The stop is written into WorldHistory like any other ending — `complete_demo()` writes `demo_run.status = ended`, the ending id, and one idempotent `demo_ending_reached` event to the isolated demo ledger

### P4 — The half hour
- [x] **P4.1** Playable within sixty seconds of launching — `demo_launch_timing_test.gd` skips the boot slate and the decanting prologue the instant each allows it (the same click an eager player makes) and lands control in the Growing Floor at 5.4s
- [x] **P4.2** Measured, not estimated — a real run timed end to end — `Time.get_ticks_msec()` around the actual scene chain (`boot_splash.tscn` -> `country_town_menu.gd::_start_demo()` -> `decanting_prologue.gd` -> `Interstitial.travel()` -> `vat_chamber.tscn`), never a frame count; prints `DEMO_LAUNCH_ELAPSED_MS`. Scope stated in the file: headless, one machine, floor only — it is not P5.1's "a machine that is not Greg's"
- [x] **P4.3** Nothing in it outstays its welcome: the second derby lap, the long walk, the third menu — audited each against the actual code rather than the phrase. The "second derby lap" is not a real mechanic: `rift_derby.gd` runs exactly one pass (`round_state`: countdown -> active -> won/lost, `rift_derby.gd:80,1082-1103`) and both outcomes call `Interstitial.travel()` to `bone_yard_hunt.tscn` exactly once; a loss goes through `DefeatRouter.route()` (relabels captivity, does not replay the scene). Nothing to cut. The "third menu" is `decanting_prologue.gd`, added deliberately for Greg's "lore accurate" opening request and already the most skippable stop in the chain (any key/click ends it immediately, `decanting_prologue.gd:110-119`, and it never plays on a resumed run — `country_town_menu.gd:460-465`); not a real offender either. "The long walk" was real: `vat_chamber.gd`'s aisle forced ~10.6s of unskippable, agency-free walking (34.0-unit `AISLE_LENGTH`, 2.7 u/s at full mobility) after ~19s of locked beats already ahead of it. Cut `AISLE_LENGTH` to 22.0 (`vat_chamber.gd:22`), saving ~4.5s (~42%) of dead time while keeping the "a body fresh out of a tank does not walk well" pacing intentional rather than just making the player faster. The vertebral-arch/dead-tank dressing that lines the aisle was hardcoded to 11 bays regardless of corridor length, so shortening the corridor alone would have left dressing poking past the end wall — `bay_count` is now derived from `AISLE_LENGTH` (`vat_chamber.gd:229-234`) with the same 3.0-unit clearance before the door the original 11/34.0 pairing had. Proven three ways: `vat_containment_test.gd` still passes at the new length (0/9 escaped the corridor), a capture standing in the aisle shows the shortened row of arches intact (`P:/GameDev/Temp/p43_vat_aisle2.png`), and a capture 4 units from the door shows `[E] INTO THE PIT` still triggering at the right distance (`P:/GameDev/Temp/p43_vat_aisle_door.png`). `loop_smoke_test` stayed green (0 failures)
- [ ] **P4.4** One moment engineered to be the thing a player describes to somebody else
- [x] **P4.5** A failure state that is interesting rather than a reload — a lost derby heat used to leave through the exact same door a win does, relabelled `WRECKED`, with no captor and no consequence. `_finish_round("lost")` now calls `DEFEAT_ROUTER.route()`, the same F5 mechanism the Bone Yard already uses, before the scene hands off; `bone_yard_hunt.gd::_ready()` reads the resulting captivity status back off `WorldHistory` and starts the player held rather than walked in fresh. `derby_loss_capture_test.gd` drives a real loss into a real hunt-scene arrival (7/7)

### P5 — Shipping it
- [ ] **P5.1** Runs on a machine that is not Greg's, from a clean folder
- [x] **P5.2** No debug affordances, no dev keys, no placeholder text (depends on J2) — J2's gate holds: `dev_affordances.gd::available()` requires `OS.is_debug_build()`, false under the release template, and its one caller (`psychedelic_osc.gd`'s OSC bridge) is inert in the shipped exe. `export_presets.cfg` excludes `tests/*`, `captures/*`, `reports/*` and disables the console wrapper. A grep of every demo-reachable script and scene for `placeholder`/`TODO`/`debug` turned up nothing that reaches the player — the only F-key handlers left in `rift_derby.gd`/`bone_yard_hunt.gd` are the keys card and handheld mode-select, real controls. Verified against the actual shipped artifact, not the editor: exported a fresh release build off this HEAD and screenshotted the running window (`P:/GameDev/Temp/p52_window_only.png`) — a clean front door, no console, no dev overlay. GORE SANDBOX on that menu looked like a candidate leak but `gore_demo.gd`'s own header settles it: Greg asked for it directly ("please quickly make a demo playable gore explosions demo") and it is a shipped toy, not a debug room
- [x] **P5.3** Sound mixed and the sliders working in the built game, not just in the editor — G5.1 already built the bus graph (Master/Music/SFX/Ambience) and routed every processing chain through it; `pause_gate.gd` maps the on-screen sliders straight onto `AudioServer.set_bus_volume_db()` with a linear-to-dB curve so the last tenth of the slider is not dead air, and mutes outright at zero rather than leaving an inaudible floor (`pause_test.gd`, 17/17). Verified in the actual shipped exe rather than the editor: launched `WizardsOnlyFools.exe`, opened the pause gate with Escape over the live front door, and drove the settings page with the real keyboard controls (Down/Left, no mouse). Screenshotted before and after: MASTER/MUSIC/SFX/AMBIENCE all read `080` at rest (`P:/GameDev/Temp/p53_settings_before.png`); five presses of Left on MUSIC alone took it to `030` with only its own slider fill and readout moving (`P:/GameDev/Temp/p53_settings_after.png`) — the other three buses, Violence and Screen rows were untouched, so the control is per-bus rather than global
- [x] **P5.4** Controls learnable without a tutorial screen — I0 still applies — every scene on the demo route already teaches its own controls diegetically rather than through a tutorial screen: `vat_chamber.gd`'s `prompt` label reads "WASD MOVE / MOUSE LOOK / WALK THE AISLE" until the door is close enough for "[E] INTO THE PIT" (matches its `_unhandled_input` exactly — WASD, mouse-look, E); `rift_derby.gd` and `bone_yard_hunt.gd` both hold an on-demand `KeysCard` (F1, closed by default, a corner hint until opened twice) instead of a forced overlay; `country_town_menu.gd` is plain clickable `Button` nodes, needing no legend. Audited each card's rows against the scene's actual `_unhandled_input` match block rather than trusting the card text: `rift_derby.gd`'s card was accurate (every real keycode — E, R, F, F1, I, Enter, Escape — has a row). `bone_yard_hunt.gd`'s was not: `B` (`_cycle_grip()`), `K` (`_deliberate_redecant()`, a real reset that forfeits carried items) and a plain tap of `Q` (`_use_prosthetic_surge()`, a 30-damage stamina-cost attack, distinct from holding Q for X-ray) were all live, working bindings with zero row in the card — a player could never discover them without reading the source. Added the three missing rows to `_build_keys_card()` and confirmed with a real capture (`P:/GameDev/Temp/p54_keys_card.png`, shot at hour 16.50/day, not the dusk-drift trap) that they render cleanly. `loop_smoke_test` stayed green throughout (0 failures)
- [ ] **P5.5** The last pass is playing it, not reading it


### P v10 — the final pass
The last rung. Fifteen statements that are true of the demo when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] **P10.1** `v10` One build, two doors: PLAY and DEMO on the same menu — both are built into `country_town_menu.gd`, in the executable's existing main-menu scene
- [ ] **P10.2** `v10` The demo is the real game with exploration locked off
- [x] **P10.3** `v10` Nothing in it is a special build that can rot — DEMO changes a runtime route/save mode and invokes the same scene transition function as PLAY; no duplicate scene, project or export exists
- [x] **P10.4** `v10` It ends because the game stops, not because a timer did — victory in the real Hunt is the hinge; no elapsed-time check exists
- [ ] **P10.5** `v10` It shows the opening: captured, quiz, tortured, festival, derby, out
- [ ] **P10.6** `v10` Combat, the handheld and the map are all fully present
- [ ] **P10.7** `v10` It is playable without anybody explaining anything
- [ ] **P10.8** `v10` It takes about thirty minutes and does not feel truncated
- [ ] **P10.9** `v10` What it locks is content, never systems
- [ ] **P10.10** `v10` A save from the demo opens in the full game
- [ ] **P10.11** `v10` It is the thing Greg can hand somebody without being in the room
- [ ] **P10.12** `v10` It exports and runs on a machine with no Godot on it
- [ ] **P10.13** `v10` It is recorded and the recording is watchable
- [ ] **P10.14** `v10` Every playtest note from it goes into the record
- [ ] **P10.15** `v10` It is never the last thing built

## Q — The Wire, deeper

Greg: *"the social media stalking aspect cyberharassing dming ect with an rng of
responding more verified higher accounts of the darkweb internet underbelly to
the game exisit too"*.

`wire_net.gd` has accounts, reach, exposure and five actions. What it does not
have is the part Greg described: people you can actually reach out to, who
answer or do not, and whose willingness depends on who you are to them.

- [x] **Q1.1** Direct messages — reach one account rather than publishing at everyone — audited rather than built: `wire_net.gd`'s `contact()` already does exactly this, was simply never credited here. Proven in `tests/wire_test.gd`
- [x] **Q1.2** Whether they answer is a roll against reach, standing and what you have on them — `contact()`'s chance formula (reach ratio, broker/leverage routes, grudge), tested: a Crown is categorically unreachable, a peer answers far more readily, a rival who hates you reads everything
- [x] **Q1.3** A verified account answers differently, and less often, than a nobody — `TIERS`' per-tier `answers` ceiling (CROWN 0.02 vs INTAKE 0.78), tested directly
- [x] **Q1.4** Stalking a feed is a way of finding somebody in the world, not flavour — the one genuine gap. New `wire_net.gd`'s `locate()` reads the most recent event that actually names the subject and carries a real `location` (most of `bone_yard_hunt.gd`'s events already do) — refuses honestly with no invented tracker when nobody has recorded where they were, and prefers the most recent sighting over a stale one. Wired into `act()`'s `"observe"` result. Covered by `tests/wire_locate_test.gd` (8 checks)
- [x] **Q1.5** Harassment works and costs — it moves grudge, reach and exposure together — `act()`'s `"swarm"`, tested: grudge, exposure and reach all move on the same real event
- [x] **Q1.6** The underbelly is reached by standing somewhere, as `signal_field.gd` already gates — `SIGNAL_UNDERBELLY`/band routing, tested: a terminal reaches him, the surface cannot


### Q v10 — the final pass
The last rung. Fifteen statements that are true of the Wire when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **Q10.1** `v10` Reach is decided by where you are standing
- [ ] **Q10.2** `v10` A post is written by somebody who exists
- [ ] **Q10.3** `v10` Accounts have tiers and a verified account answers less often
- [ ] **Q10.4** `v10` Sites are places you can reach, not data nobody sees
- [ ] **Q10.5** `v10` What is on it is often wrong and the game never corrects it
- [ ] **Q10.6** `v10` Apps on it are playable and some are load-bearing
- [ ] **Q10.7** `v10` The feed has spammers who can be cleared for money
- [ ] **Q10.8** `v10` The agency reads what you read
- [ ] **Q10.9** `v10` It goes down, and where it is down is a fact about the map
- [ ] **Q10.10** `v10` Only the elites have it, and that is visible
- [ ] **Q10.11** `v10` Somebody can be found on it and then found in the world
- [ ] **Q10.12** `v10` It carries rumour, which is how the two records diverge
- [ ] **Q10.13** `v10` A theory published on it changes what people believe
- [ ] **Q10.14** `v10` It is on the handheld and nowhere else
- [ ] **Q10.15** `v10` It remembers what you posted into the next universe

## R — Money

The body economy exists in pieces: `carry.gd` prices a part, faction standing
already refuses a deal outright, and liens already follow stolen goods. Nothing
ties it together into a reason to get up in the morning.

- [x] **R1.1** One currency with a name and a reason — rust scrip, and who issues it — `carry.gd`'s `currency_reason()` reads CellOutz's own real doctrine ("ownership, downward") as the reason, rather than an invented lore line
- [x] **R1.2** What a body is worth, by part, condition and whose it was — audited: `sale_value()` already priced all three (base by kind, `condition`/`freshness`, and `stolen` heat); simply never credited here
- [x] **R1.3** Buyers with their own appetites, so a market is a set of people and not a price — `FACTION_APPETITES`: the Choir pays more for an organ, Vanity Row pays more for a cybernetic, drawn from what each faction already is rather than an invented preference table
- [x] **R1.4** Debt you can be in, since `debt_to_player` already runs the other way — `borrow()`/`repay()`/`debt_to()`: real scrip added to the wallet against a real, named debt to a real faction; repaying is capped at what is actually owed and what is actually in the wallet
- [x] **R1.5** Prices move with what the world has been through — `_market_glut()` reads real recent `carried_part_sold` history: the more of a kind that has actually sold, the less the next one is worth, specific to that kind rather than a global crash. Covered by `tests/money_test.gd` (16 checks)


### R v10 — the final pass
The last rung. Fifteen statements that are true of money when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **R10.1** `v10` Money is a real quantity with a real issuer
- [ ] **R10.2** `v10` The bank writes the liens the Choir prices
- [ ] **R10.3** `v10` A debt is secured against something of yours, named
- [ ] **R10.4** `v10` Interest accrues in game time whether you play or not
- [ ] **R10.5** `v10` A collector is a person with a body
- [ ] **R10.6** `v10` Accounts are in a building you can walk into
- [ ] **R10.7** `v10` Prices move with who you are to the seller
- [ ] **R10.8** `v10` Organs are the collateral and that is the economy, not a metaphor
- [ ] **R10.9** `v10` Robbery is possible and the damage stays
- [ ] **R10.10** `v10` Jobs pay, and the job market is angels and demons hiring
- [ ] **R10.11** `v10` Nothing is bought from a shop menu
- [ ] **R10.12** `v10` You can be made worthless without being made poor
- [ ] **R10.13** `v10` Somebody else's debts are findable and buyable
- [ ] **R10.14** `v10` The satire lands on the paperwork, never on debtors
- [ ] **R10.15** `v10` What you owed is what the next universe starts knowing

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


### S v10 — the final pass
The last rung. Fifteen statements that are true of speech when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **S10.1** `v10` Nobody explains the cosmology at you
- [ ] **S10.2** `v10` What somebody says comes from what they know
- [ ] **S10.3** `v10` Lines survive the fiction rather than describing it
- [ ] **S10.4** `v10` You can speak out loud and be heard by whoever is close
- [ ] **S10.5** `v10` They answer in a voice positioned where their head is
- [ ] **S10.6** `v10` Talking while holding somebody is its own register
- [ ] **S10.7** `v10` Voice acting for the godhead and the handler
- [ ] **S10.8** `v10` Nothing is a response table
- [ ] **S10.9** `v10` Silence is an answer somebody can give
- [ ] **S10.10** `v10` Dialogue is never a wall of options
- [ ] **S10.11** `v10` What you said is recorded and can be repeated back
- [ ] **S10.12** `v10` A conversation can be overheard
- [ ] **S10.13** `v10` Language degrades with injury
- [ ] **S10.14** `v10` Somebody can refuse to speak to you forever
- [ ] **S10.15** `v10` The privacy and cost of proximity voice are settled honestly before it ships

## T — The run

⚠ Added 13 September 2026 by `tests/loop_smoke_test.tscn`: **the run has no
ending in the scene graph at all.** Not "the ending is unsatisfying" — there is
no `Interstitial.travel` out of `bone_yard_hunt.gd`, so the only exit is the
pause gate. Whatever answer T's blocking question gets, an ending transition is
the first thing that has to exist, because P cannot demo a loop that does not
close.

The open question that has been sitting unanswered longest: *"what persists
between runs?"* Roguelike structure was asked for, and "bodies remember" is a
pillar. They pull against each other and the game cannot have both untouched.

- [x] **T1.1** **Answered by the rework.** Greg: *"quantum immortality deaths or restarts in other universes — but that's a new game + end game feature"*. So: nothing carries in the save-file sense. **The universe restarts and you do not.** You are the constant and the world is the variable, which is the only answer consistent with AP2 (the spirit cannot be banished) and it turns T1.3's inheritance question into a much better one — not *what did I keep*, but *what is different about this world because a previous one had me in it*
- [x] **T1.2** Death is an event in the world rather than a reload — `systems/run_lifecycle.gd`'s `record_death()`, deliberately built without guessing T1.1's answer: captures the real cause, where the run had reached (`OpeningDirector`), what was being carried (`Carry`), and where the subject stood on the axis (`tree_alignment()`) as one recorded `permanent_death` event, so whatever T1.3 eventually decides should inherit has real material to read from rather than needing a second record built later. Covered by `tests/run_lifecycle_test.gd` (10 checks)
- [ ] **T1.3** Something inherits: a body, a debt, a reputation, a wall of pins (waits on T1.1)
- [ ] **T1.4** What the world keeps is visible to the player before they risk it (waits on T1.1)
- [ ] **T1.5** A run has a shape — it starts, it escalates, it ends (waits on T1.1)


### T v10 — the final pass
The last rung. Fifteen statements that are true of death and what persists when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **T10.1** `v10` Death is an event in the world, never a reload
- [ ] **T10.2** `v10` The universe restarts and you do not
- [ ] **T10.3** `v10` Nothing carries in the save-file sense
- [ ] **T10.4** `v10` What is different about the next world is what you did in the last one
- [ ] **T10.5** `v10` The Board is the continuous thing
- [ ] **T10.6** `v10` The godhead remembers you across the restart
- [ ] **T10.7** `v10` A permanent death is recorded richly enough to be inherited from
- [ ] **T10.8** `v10` Somebody inherits a body, a debt, a reputation or a wall of pins
- [ ] **T10.9** `v10` Quantum immortality is explained by the game rather than to the player
- [ ] **T10.10** `v10` New game plus is a real different game
- [ ] **T10.11** `v10` Dying is survivable for you and not for anybody else
- [ ] **T10.12** `v10` The gods give a verdict on a kill and they disagree
- [ ] **T10.13** `v10` SOUL FREED and CYCLICIST ENSLAVEMENT AGAIN are opinions, not a score
- [ ] **T10.14** `v10` Nothing adds those verdicts up
- [ ] **T10.15** `v10` The restart is an ending you can choose to refuse

## U — Your own ladder

Greg: *"how you can persuade them to join your ranks your own faction that you
start through progressing and exploring around the map"*. E is the two ladders
that already exist. This is the third one, which is yours.

- [x] **U1.1** Found something — a name, a mark, a first member — `systems/player_faction.gd`'s `found()`: the player becomes a real `WorldHistory` faction's founder, holding CROWN on the exact same rank machinery every other faction uses, with a real recorded `mark` rather than just a name. Refused if one already exists — there is only one
- [x] **U1.2** Recruits from the clinch and the downed window belong to it — `recruit()`, an API offered for whoever wires the actual clinch/downed resolution (Codex's F5/F6 territory) to call, same relationship this file has to combat as `ritual_app.gd` has to the camera it doesn't hold
- [x] **U1.3** It has standing on the same axis every other faction does — deliberately *not* a `FACTION_TREE_AXIS` entry (that table is authored, for the seven Sins and the two poles); `standing()` computes the real average `tree_alignment()` of whoever has actually joined, so recruiting someone who was climbing genuinely pulls the faction's own standing up
- [x] **U1.4** It can be attacked, and it can lose people — `lose_member()` records the real reason (killed, walked away, whatever it was) rather than a silent disappearance, and actually drops them from the roster. The "attacked" half is combat wiring, not attempted here
- [ ] **U1.5** Rank inside it is somebody else's problem too — they have opinions (needs members with individual reactions to rank changes — not attempted here). Covered in `tests/player_faction_test.gd` (19 checks)


### U v10 — the final pass
The last rung. Fifteen statements that are true of your own faction when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **U10.1** `v10` The player's faction is built from real state, not a menu
- [ ] **U10.2** `v10` It has a founder, a crown, and a rank ladder like the others
- [ ] **U10.3** `v10` It sits on the pyramid at its actual power
- [ ] **U10.4** `v10` People join it because of something that happened
- [ ] **U10.5** `v10` It can refuse to sell to somebody
- [ ] **U10.6** `v10` It keeps its own record and its record can be wrong
- [ ] **U10.7** `v10` It holds land and the land shows it
- [ ] **U10.8** `v10` It can be raided and it can raid
- [ ] **U10.9** `v10` It survives you being away
- [ ] **U10.10** `v10` Somebody in it can take it from you
- [ ] **U10.11** `v10` It can side with the ascent, the descent, or neither
- [ ] **U10.12** `v10` Its standing is visible on its members' bodies
- [ ] **U10.13** `v10` It can collapse and its holdings go somewhere
- [ ] **U10.14** `v10` It appears on other factions' boards as a theory
- [ ] **U10.15** `v10` It is the thing the next universe finds already there

## V — The road

M2b covers cars as this world's horses. This is everything else about them
being vehicles rather than set pieces.

- [ ] **V1.1** A car is a thing with a condition, not a state you are in —
      Updated 2026-09-15: a real, live `condition: float` (0..1) now exists
      on `ArcadeVehicle` itself (`game/systems/arcade_vehicle.gd`), degraded
      by real impact closing speed the same way `fuel` (V1.3) already burns
      off real throttle-held time — `vehicle_condition_test.gd` covers it
      directly (hard impact drops it measurably, a soft contact doesn't,
      clamps at 0..1). This is still not the `world_damage.gd`-backed,
      persistent store this item actually asks for, and the reasoning below
      for deferring that still holds — a persisted condition with no repair
      verb is a dead end a player would actually hit, so persistence stays
      sequenced after V1.4. `rift_derby.gd`'s own `integrity` stays the
      tuned, authoritative number for the derby (untouched formula, no
      balance risk) and is mirrored into `condition` after every hit, so the
      two no longer silently disagree the way this note used to warn about —
      but `condition` itself still does not survive a scene reload and is
      not yet the primitive V1.1 is really asking for. Original note, still
      true: checked against `DESIGN/DESTRUCTION.md`'s AB1.5, which defers
      the persistent version to Lane 2 on the condition that it reuses
      `world_damage.gd` rather than inventing a third store — migrating
      `integrity` itself there is only honest once V1.4 or AB2.4/2.5 (needs
      AA, not built) exists to bring a wrecked car back up.
- [ ] **V1.2** Damage is physical and visible, and it changes how it drives —
      Updated 2026-09-15: it does now, for the player. `_condition_scale()`
      in `arcade_vehicle.gd` scales tire grip and steering authority by the
      same `condition` field above (floored at `MIN_CONDITION_SCALE` rather
      than going inert), and `rift_derby.gd`'s existing crush-visual and
      detachable-part system already reads the number `condition` is now
      mirrored from, so damage was already visible and is now also felt.
      Not yet true universally: nothing sets `condition` on an AI wrecker —
      they still run on `set_meta("integrity", ...)` alone — so a wrecker's
      own handling never degrades, only the player's does. No dedicated test
      asserts the handling numbers themselves; `vehicle_condition_test.gd`
      only covers the field's own value, not what reading it does to grip or
      steer.
- [x] **V1.3** ~~Fuel, or a reason a car is not infinite~~
      No car anywhere in the project burned anything — a derby heat, or in
      principle a whole session, could be driven flat out forever. `fuel`
      lives on `ArcadeVehicle` (`game/systems/arcade_vehicle.gd`, Lane 2's own
      file per `LANE.md`), burns at `FUEL_BURN_PER_SECOND` only while the
      throttle is actually held — idling and coasting are free, since the
      tank is a cost of aggression rather than of existing — and a dry tank
      drops out of the rear-wheel drive branch in `_integrate_forces`
      outright, so an empty car does not accelerate, it coasts down on
      rolling drag like any unpowered thing does. `refuel()` tops it back up
      for whatever hands out fuel later (V1.4's repair, a pit stop, a
      scavenged jerry can). Deliberately independent of V1.1/V1.2: those were
      built and fully reverted as a Lane 1 file-family overstep (`a48e22e`
      reverted this same entry alongside them for that reason, not for
      quality), and neither `condition_fraction()` nor `handling_fraction()`
      exist on the chassis right now — this entry does not reintroduce them,
      it only adds the tank.
      Verified: `tests/vehicle_fuel_test.gd` (headless, `--quit-after 1500`)
      — idling burns nothing, holding the throttle burns a measurable amount
      without emptying a full tank in two seconds, a near-empty tank actually
      reaches zero rather than only asymptoting toward it, `refuel()` restores
      it, and a car at zero fuel measurably fails to move under full
      throttle. `tests/impact_test.gd` and `tests/derby_exit_test.gd` both
      still run clean (the latter's full ~35s heat, `--quit-after 20000`,
      ends 94 integrity / won, well inside a fresh tank's burn budget) — this
      does not strand the existing impact or heat-length coverage.
      Still open: nothing reads the number back except the test — there is no
      HUD dial for it. `dash_cluster.gd`'s two-dial layout (hull, pace) is
      deliberately, carefully positioned in a 420x200 panel that is already
      packed with wrecker lamps, the impact counter, the magazine and the
      rival telltale; bolting on a third gauge without the same care would
      read as an afterthought, not an instrument. That belongs with the
      cluster's own next real pass. There is also no way to refill a tank in
      play yet — `refuel()` exists and is tested, but nothing calls it.
- [ ] **V1.4** Cars can be repaired, badly
- [ ] **V1.5** Somebody else is driving one too, outside the derby


### V v10 — the final pass
The last rung. Fifteen statements that are true of the road when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **V10.1** `v10` A car is found, taken, and hostile until it is not
- [ ] **V10.2** `v10` Every vehicle is the same chassis system
- [ ] **V10.3** `v10` Damage is physical, visible, and stays
- [ ] **V10.4** `v10` E gets you out, and getting out is watched
- [ ] **V10.5** `v10` Cars are scattered and randomised rather than parked for you
- [ ] **V10.6** `v10` Running somebody over is the anatomy, not a script
- [ ] **V10.7** `v10` An engine can catch, and a catching car is a bomb with a timer
- [ ] **V10.8** `v10` Bikes, scrap bikes and skiffs share it
- [ ] **V10.9** `v10` Fuel, or whatever this world burns, is real
- [ ] **V10.10** `v10` A wreck stays a wreck and becomes scenery
- [ ] **V10.11** `v10` Driving at night needs the lights you have
- [ ] **V10.12** `v10` The tunnels are drivable
- [ ] **V10.13** `v10` Nothing about a car is a separate minigame
- [ ] **V10.14** `v10` Somebody else can be driving it
- [ ] **V10.15** `v10` The car you left somewhere is where you left it

## W — Weather and the hour

The Expanse has one lighting state, one fog density and no clock. `WorldLook`
already switches presets by place; nothing switches by time.

- [x] **W1.1** A day cycle the world reads, not only the sky — `world_clock.gd`, a pure function of one persisted number rather than a sixth autoload. Hours, days, months, five named phases, a continuous daylight curve, and sleeping. The cycle now lasts one real hour instead of 24 minutes, and the same ledger resolves an original 365-day Ashbloom calendar: three seasons, twelve 30-day months in ten-day decans, and five named Uncounted Days outside every month. 33 checks. Unblocks A9.7, W1.4, AB2.4, AJ4.3 and AL1.5, all of which were waiting on it without anybody noticing
- [x] **W1.2** ~~Contamination has weather — it moves, it settles, it gets worse~~
      A5 made contamination a property of every surface, painted in once at
      authoring time — real, but static, and nothing asked whether the air
      over the Bone Yard reads worse today than it did a week ago, because
      nothing tracked an answer. `world_weather.gd` (`WorldWeather`,
      `class_name`, `RefCounted`) does, in the same idiom W1.1 set for
      `world_clock.gd`: a pure function of state that already exists and
      already persists, so there is nothing new to save and nothing that can
      drift out of sync with its sources. `contamination()` sums three real
      terms — an `AMBIENT_PER_DAY` floor that only ever rises with
      `WorldClock.day()` ("it gets worse"), a night/day push off
      `WorldClock.daylight()` that recedes through the day and returns after
      dark ("it moves" / "it settles"), and `WorldHistory.chaos_magick()`
      (AS4.2) folded in at a weight, because a storm already loose in the air
      is contamination too, not a separate fact politely declining to overlap.
      Verified: `tests/world_weather_test.gd`, 11 checks — the floor rises by
      exactly its authored per-day rate and stops at its ceiling however many
      days pass; the same day reads worse at night than at noon while the
      floor itself stays hour-blind; a bumped storm reads as worse
      contamination and genuinely settles back toward (never below) that
      day's floor once it decays; and the worst case (ancient save, deep
      night, a live storm) still clamps to 1.0.
      Still open, named honestly: "moves" here is temporal, not spatial —
      the reading changes continuously on its own, but there is still no
      per-place value anywhere in the project, so a live map of contamination
      fronts crossing the region is real future work, not this pass. Nothing
      reads `contamination()` yet either: `bone_yard_hunt.gd` currently feeds
      `ContaminatedAir.set_severity()` from `chaos_magick()` directly as an
      explicit stand-in for AS4.2's not-yet-built storm, and that file has
      another agent's uncommitted work in it right now — deciding whether
      `WorldWeather.contamination()` should replace, blend with, or sit
      beside that stand-in is a real design call for whoever owns AS4.2 and
      the storm, not one to make unilaterally while landing this pass.
- [x] **W1.3** ~~Being caught out in it costs something~~
      Already largely true before this segment: B7.1 built `expose()`, and
      `bone_yard_hunt.gd`'s `_update_air()` already fed it real severity every
      physics tick, converting exposure into genuine, garment-gated zone and
      organ damage. What was not true is the half W1.2 named as still open —
      that feed was `chaos_magick()` alone, so a quiet run with no ritual ever
      worked cost a body standing in the world exactly nothing, no matter how
      many days had passed. `_update_air()` now reads
      `WorldWeather.contamination()` in its place (a one-line change, landed
      via the surgical-split process this worktree's collisions have needed
      all session, since another agent's grip-cycling work shares this file),
      so the ambient floor and the diurnal push are what a body is being
      caught out in now, not only a storm somebody happened to work.
      Verified: `tests/contamination_exposure_test.gd` — at 90 days into a
      run, deep night, with `chaos_magick_level` pinned at zero throughout,
      one call to `_update_air()` sets the air to exactly
      `WorldWeather.contamination()` and measurably doses the player's body
      through `expose()`, proving the ambient weather alone (no ritual, no
      storm) now carries a real cost. Checked as a single direct call rather
      than by averaging over many physics ticks: this scene proved
      reproducibly timing-sensitive to a tight, uninterrupted
      `await physics_frame` loop in headless mode — the exact same logic read
      a different outcome depending only on whether an unrelated print
      statement sat in the loop, which smells like a genuine pre-existing
      race somewhere in this scene's setup rather than anything this pass
      introduced. Named here rather than chased down, since root-causing it
      is a real side quest outside W1.2/W1.3's scope; a note worth another
      agent's attention if a physics-timing bug surfaces in this scene later.
      Still open: this is the exposure half only. `W1.3` as a design
      statement plausibly wants more than health loss — an in-fiction
      *warning* (a Geiger-click, a HUD cue, dialogue) that something is
      wrong before a body starts actually melting — and none of that exists;
      `dash_cluster.gd`'s two-dial layout doesn't read exposure either, the
      same gap V1.3 named for the fuel gauge.
- [x] ~~**W1.2** Contamination has weather — it moves, it settles, it gets
      worse~~ Built twice in parallel without either side knowing: this
      session's own `systems/contaminated_air.gd` (calendar-driven,
      `WorldClock.day()` plus `WorldHistory.chaos_magick()`) and a second,
      already-integrated implementation merged in from `codex/game-planning`
      under the identical class name — A9.1/A9.2's real, wired-in system
      (`extends GPUParticles3D`, motes that drift and settle, `set_severity()`
      driven from `bone_yard_hunt.gd` off `chaos_magick()`, already verified
      with `captures/a9_1_v9_air_calm.png`/`a9_2_v9_air_storm.png`). Resolving
      the merge conflict kept the real, integrated one rather than the
      unintegrated duplicate; this session's own version and its
      `tests/contaminated_air_test.gd`/`contaminated_air_capture.gd` were
      deleted rather than kept alongside it.
      "Moves" and "settles" were covered by A9's motes; "gets worse" was not
      — `chaos_magick()` decays on its own with nothing feeding it
      (`world_history_chaos_test.gd`: "a long enough quiet settles it to
      nothing"), so the air could get *better* on a quiet night, not just
      worse. `WorldHistory.chaos_magick()` is Lane 4's, so the fix stays
      inside `contaminated_air.gd`, which already owns `set_severity()`: a
      watermark. A spike raises `_watermark` to match immediately — the
      instant reading can still climb past it on a worse night — and it is
      only eased down by `WATERMARK_RELIEF` per full in-game day
      (`WorldClock.day()`) that passes without a new high, never simply
      reset by the moment-to-moment reading dropping. `bone_yard_hunt.gd`'s
      call site is untouched; it still just calls `set_severity(x)`.
      Verified with a scratch harness (not `tests/`, which is Lane 4's):
      a 0.8 spike reads immediately, an same-day 0.1 reading afterward still
      reads >= 0.79, one in-game day of quiet relieves it by exactly
      `WATERMARK_RELIEF` (down to 0.72, not to 0.1), and a fresh 0.95 spike
      still reads immediately over the eased watermark. 0 failures.
      `tests/derby_balance_test.tscn` re-run clean (0 failures) since this
      touches Hunt Grounds' air, not the derby.
- [x] **W1.3** Being caught out in it costs something — `storm_weather.gd`'s
      `exposure_cost()`, drained from stamina in `_update_storm_exposure()`,
      cut by a warm layer (AS3.3/AS4.5).
- [ ] **W1.4** Factions keep hours; the Wire is busier at some of them
- [x] **W1.5** G7's exposure problem is a lighting *state* rather than a
      constant — `_update_day_night()` drives the sun's energy/colour and the
      base environment's ambient/exposure off `WorldClock.daylight()` every
      frame instead of the fixed numbers `_build_world()` used to set once.
      G7.1/G7.2 (whether spawn should read this dark at all, and near-field
      contrast) are separate judgment calls this does not make, and the derby
      (G7.3) was never touched.


### W v10 — the final pass
The last rung. Fifteen statements that are true of weather and the hour when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **W10.1** `v10` One clock, wound in one place, read by everything
- [ ] **W10.2** `v10` Light warps at night rather than dimming
- [ ] **W10.3** `v10` Storm severity is a readout of how much magick is loose
- [ ] **W10.4** `v10` Anvil crawlers, and red lightning that means something
- [ ] **W10.5** `v10` Contamination has weather that moves and settles
- [ ] **W10.6** `v10` Being caught out in it costs something
- [ ] **W10.7** `v10` Factions keep hours and the Wire is busier at some
- [ ] **W10.8** `v10` Stations keep schedules
- [ ] **W10.9** `v10` Hauntings happen at night and are not permanent
- [ ] **W10.10** `v10` The gods are visible at their hours
- [ ] **W10.11** `v10` A month passes and things repair
- [ ] **W10.12** `v10` Sleeping moves the clock and something can wake you
- [ ] **W10.13** `v10` Weather is audible before it is visible
- [ ] **W10.14** `v10` Nothing in the game keeps a second clock
- [ ] **W10.15** `v10` The hour is legible without a clock on screen

## X — Performance

Nothing in this project has ever been profiled. It is a solo build with one
region, so it has not needed to be — which is exactly when the debt is cheap to
pay.

- [x] ~~**X1.1** Profile it, and write down the real numbers~~ `Performance`
      singleton, sampled over 180 frames at a settled idle in each scene, a
      real windowed run (headless renders nothing, so draw calls/primitives
      would read zero). Hunt Grounds spawn: 3395 draw calls, 405.8k
      primitives, 5655 nodes, 249.8MB static / 327.8MB video memory. Derby
      pit: 2983 draw calls, 532.0k primitives, 2802 nodes, 215.0MB static /
      339.5MB video memory — fewer nodes than the Hunt Grounds region but
      more primitives per car than a region full of low-poly buildings.
      Flagging rather than trusting one number: both scenes also reported
      `TIME_FPS` pinned at 60 alongside a `TIME_PROCESS` of 37-39ms, which is
      internally inconsistent (37ms of process time cannot deliver 60 real
      frames a second) — the run was an automated, unfocused window with
      nothing driving input, and Godot's low-processor-usage-mode sleeping
      between idle frames is the likely explanation, not a real 37ms
      workload. The draw-call/primitive/memory numbers came from the
      renderer's own counters and are trusted; the frame-timing pair is not,
      and needs a focused, interactive re-run before anything is budgeted
      against it — left for X1.2 rather than guessed at here.
- [ ] **X1.2** A frame budget, stated, that the region is held to — blocked on
      X1.1's frame-timing numbers actually being trustworthy; the draw call
      and primitive counts alone are not enough to set a budget against.
- [ ] **X1.3** The 238MB plugin referenced by no script (pairs with J1.3)
- [ ] **X1.4** Bodies are the expensive thing — measure before optimising them
- [ ] **X1.5** It has to hold up on a machine that is not Greg's


### X v10 — the final pass
The last rung. Fifteen statements that are true of performance when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **X10.1** `v10` The frame budget is measured every build, never estimated
- [ ] **X10.2** `v10` A panel costs less than the game it is drawn over
- [ ] **X10.3** `v10` Nothing iterates the world when it could iterate the screen
- [ ] **X10.4** `v10` Static registries are swept at every seam
- [ ] **X10.5** `v10` Gore, brass and debris are capped and recycled
- [ ] **X10.6** `v10` Every subviewport renders only when somebody is looking
- [ ] **X10.7** `v10` The region streams rather than existing all at once
- [ ] **X10.8** `v10` Crowds are cheap enough to be crowds
- [ ] **X10.9** `v10` No shader costs more than it earns
- [ ] **X10.10** `v10` Load is covered and covered loads are not idle
- [ ] **X10.11** `v10` A profile run is part of the test suite
- [ ] **X10.12** `v10` It holds sixty on the machine Greg actually has
- [ ] **X10.13** `v10` It degrades gracefully rather than stuttering
- [ ] **X10.14** `v10` Nothing is optimised before it is measured
- [ ] **X10.15** `v10` The build that ships is the build that was profiled

## Y — Getting in

The game currently assumes a player who already knows what it is. It has no
options a person would actually reach for and no way in that is not "start".

- [ ] **Y1.1** Controls are rebindable
- [ ] **Y1.2** The violence tier from the warning card actually changes the build
- [ ] **Y1.3** Text is legible at a normal viewing distance — the stencil is not free
- [ ] **Y1.4** Colour is not the only carrier of meaning anywhere
- [ ] **Y1.5** Somebody can put it down and come back a week later

Greg, 2026-09-13, which is most of a section on its own:

> *"fixing up the main menu screen guis and making save files multiples and they
> are little chambers that change throughout game progression but they are what
> you start in the pods with a fetus somewhat cell in there with a plug in there
> mouth and then you go into it and get it out after the initial first part which
> also needs work so it should just say start game also lowkey a multiplayer and
> online option should be there but not be selectable and have a message saying
> soon 'if you have ideas email me in settings'."*

### Y2 — The way in
- [x] **Y2.1** One door, and it says **START GAME**. Not PLAY and DEMO, not a verb nobody uses out loud
- [x] **Y2.2** **MULTIPLAYER** and **ONLINE** are on the menu, visible, and not selectable — a greyed line that says SOON is a promise; a missing line is nothing at all. `disabled` also takes them out of the focus order, so a controller cannot land on a dead row
- [x] **Y2.3** And the SOON card says where to send the idea, which is the only reason to show a door you cannot open yet — one line under both doors rather than a tooltip nobody hovers on a row they cannot click
- [ ] **Y2.4** The part before you are out of the pod is authored rather than skipped past — it is the first thing anybody plays and it is currently the roughest thing in the build

### Y3 — Saves are chambers
A save slot is a row in a list in almost every game, and I0 says no screen is a
list of text in a box. This is the segment where that rule reaches the save menu:
**a save is a chamber you can look into**, and what is in it is the body that
save has grown.

- [ ] **Y3.1** More than one save, and choosing one is walking a row of chambers rather than reading their filenames
- [ ] **Y3.2** A chamber changes with the run inside it — a save forty hours deep does not look like one an hour old, and nothing about that is a progress bar
- [ ] **Y3.3** A new save is an occupied pod: a body at fetus stage, a cell, a plug in its mouth. You are looking at what you are about to be
- [ ] **Y3.4** Starting is **going into the chamber and taking it out**, not a fade from a button
- [ ] **Y3.5** An empty slot is an empty chamber — drained, lit, waiting — and not a blank row with NEW GAME on it
- [ ] **Y3.6** The machinery is already there: `AG5.11` built real multi-slot saving with a manifest per slot. This is what it looks like, not what it does

### Y4 — Support, from inside the game
- [x] **Y4.1** Settings can send mail to **wizardsonlyfoolzthegame@gmail.com** — support, bug reports, and the ideas line Y2.3 points at. `support_mail.gd`: three subjects so mail lands sorted, one mechanism. No network, no dependency, no key — it hands a `mailto:` to the machine's own client
- [x] **Y4.2** A bug report carries the build, the seed and the run with it, because a player should not have to write down what the game already knows — build, engine, platform and timestamp gathered automatically, anything else the caller attaches, and **nothing that nobody asked for**: `context()` is separate from `compose()` so the settings page can show the player exactly what is about to go out under their name
- [x] **Y4.3** It never silently fails: if there is no mail client it says so and gives the address to copy — `send()` returns `sent` and a `reason`, and the address either way. 23 assertions in `tests/support_mail_test.gd`, including that an ampersand in the note is encoded rather than ending the query string early, and that line breaks are CRLF so the body is not one long line

**Open, and blocking a rename:** Greg does not like **"Bone Yard"**. No
replacement given. It is the main scene (`bone_yard_hunt.gd`/`.tscn`), a district
in `living_map.gd`'s `DISTRICTS`, and appears across `CHECKLIST.md` — so this is
a name to decide once and change everywhere in one commit, not to drift into.


### Y v10 — the final pass
The last rung. Fifteen statements that are true of getting in when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **Y10.1** `v10` The menu is a place, not a list
- [ ] **Y10.2** `v10` PLAY and DEMO are the two doors
- [ ] **Y10.3** `v10` Settings are reachable and every control does something
- [ ] **Y10.4** `v10` A new player is playing within a minute
- [ ] **Y10.5** `v10` Nothing is explained that could be shown
- [ ] **Y10.6** `v10` The first thing you see is the register of the whole game
- [ ] **Y10.7** `v10` Controls are discoverable in the world (AH)
- [ ] **Y10.8** `v10` The screen setting is restored at startup
- [ ] **Y10.9** `v10` A save is loaded without a menu about saves
- [ ] **Y10.10** `v10` World seed creation at the start, Terraria style
- [ ] **Y10.11** `v10` Quitting is possible from anywhere
- [ ] **Y10.12** `v10` Nothing in the first five minutes is a tutorial box
- [ ] **Y10.13** `v10` It works on a fresh machine with no setup
- [ ] **Y10.14** `v10` It never opens on an error
- [ ] **Y10.15** `v10` The title is the last thing changed and it is right

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


### Z v10 — the final pass
The last rung. Fifteen statements that are true of shipping when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **Z10.1** `v10` One command produces a build from a clean checkout
- [ ] **Z10.2** `v10` The export includes every asset it needs and nothing it does not
- [ ] **Z10.3** `v10` It runs on a machine that has never had Godot on it
- [ ] **Z10.4** `v10` A friend can download it and play without instructions
- [ ] **Z10.5** `v10` The repo has a readable history somebody outside can follow
- [ ] **Z10.6** `v10` CHANGES.md is generated and cannot go stale
- [ ] **Z10.7** `v10` The checklist is published and current
- [ ] **Z10.8** `v10` Saves survive an update
- [ ] **Z10.9** `v10` A crash is reported with enough to find it
- [ ] **Z10.10** `v10` Nothing ships that only one machine can build
- [ ] **Z10.11** `v10` Licences for everything used are recorded
- [ ] **Z10.12** `v10` The build is versioned and the version is visible in game
- [ ] **Z10.13** `v10` There is a way to get a playtester's feedback into the record
- [ ] **Z10.14** `v10` Nothing in the build is a placeholder that was forgotten
- [ ] **Z10.15** `v10` It is small enough to send somebody

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
- [x] **AA1.2** Colour arrives with weight: a revealed holding is a small event, not a tick — entering a holding writes one `holding_revealed` event, and MAP develops the claimed polygon outward from its real settlement over 1.4 seconds rather than flipping one label. The early and settled states are visually recorded at `captures/ashbloom_holding_reveal.png` and `captures/celloutz_target_area.png`
- [x] **AA1.3** What is still grey pulls at you — the unrevealed shape is legible enough to want — every unknown holding keeps its complete faint border and an `UNSURVEYED SECTOR` centre mark while withholding its name and holder; the map shows the shape of missing knowledge rather than blanking it
- [x] **AA1.4** Reveal is per holding, not per metre, so it arrives in satisfying pieces — `ashbloom_holdings.gd` resolves the nearest authored settlement and reveals that entire persistent polygon exactly once. Fine cell survey remains underneath for streets/buildings, but it no longer controls whether the land itself has a name

### AA2 — The split
- [x] **AA2.1** The region divides into named holdings with their own edges — the five settlements the world generator already builds now share one definition table with MAP and produce five deterministic convex Voronoi cells clipped to the real 470-by-370-metre region. Every polygon also owns one canonical `kind: place` WorldHistory record, revealed through the same exploration act and consumed unchanged by MAP, INDEX, Board and local jurisdiction. `ashbloom_holdings_test` proves all five bounded polygons, settlement containment, whole-piece/idempotent reveal, holder/timestamp persistence, save-safe migration, non-revealing jurisdiction lookup, live map seam and cross-instrument record identity (27 checks)
- [ ] **AA2.2** A holding can be given to the ascent or given to corruption
- [ ] **AA2.3** Giving it is an act with a cost, not a menu choice
- [ ] **AA2.4** A holding remembers who took it and when (WorldHistory, like everything else)
- [ ] **AA2.5** Neither side is the good one; the karma axis already refuses that framing
- [ ] **AA2.6** A holding can be reclaimed through connected local work — dismantling fictional bandit camps, trafficker/organ-market networks, cartels, alien installations and other controlling structures — rather than by touching one map icon

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
- [x] **AA4.3** The Board can pin a holding, so a theory can be about land — a revealed place appears in INDEX without a fabricated portrait, pins as a filed survey record carrying its live holder and field note, and accepts ordinary red string to `THE SIGNAL IS THE PRAYER`. Verified through the production INDEX/Board paths by `ashbloom_holdings_test` and visually at `captures/ashbloom_holding_index.png` / `captures/ashbloom_holding_board.png`
- [ ] **AA4.4** An ending can be reached through the map rather than through a person


### AA v10 — the final pass
The last rung. Fifteen statements that are true of the land taking a side when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] **AA10.1** `v10` Every holding belongs to somebody and the map shows it — all five surface place records begin with the faction already established by their authored district, and a revealed polygon prints `HELD / <faction>` in that holder's Tree-axis colour. This records the current world without deciding the still-open player act in AA2.2/AA2.3
- [ ] **AA10.2** `v10` Giving one to the ascent or to corruption is a real, costly act
- [ ] **AA10.3** `v10` The colour of the region changes with who holds it
- [ ] **AA10.4** `v10` Weather quality degrades where corruption holds
- [ ] **AA10.5** `v10` Towns are destroyed by the choice, not by a cutscene
- [ ] **AA10.6** `v10` A holding remembers who gave it away
- [ ] **AA10.7** `v10` Holdings can be taken back and it is harder the second time
- [ ] **AA10.8** `v10` Nobody holding a place means nobody repairs it
- [x] **AA10.9** `v10` Exploration is what reveals a holding's real state — `LivingMap.observe()` hands the player's real X/Z position to the territory authority on the same path that surveys streets; opening a menu or pointing at a polygon cannot reveal it
- [ ] **AA10.10** `v10` The satellite sees it and the agency has opinions
- [ ] **AA10.11** `v10` Factions move on the pyramid as holdings change hands
- [ ] **AA10.12** `v10` The Board can pin a holding to a faction to a person
- [ ] **AA10.13** `v10` A holding generates work: jobs, raids, collections
- [ ] **AA10.14** `v10` Every land decision is visible from a distance
- [ ] **AA10.15** `v10` The distribution of holdings is what the next universe inherits

## AB — Destruction

Greg: *"a system like Teardown could be next level for destruction physics and
gore meshes within the game"*.

Recorded as the idea it is rather than as a plan. Teardown's voxel destruction is
a whole engine discipline and this is a solo Godot project, so the honest first
question is not "how do we build that" but "what does this game actually need
from it" — and the answer is probably narrower and more achievable: things break
where they are hit, and what comes off them stays.

- [x] **AB1.1** ~~Decide the scope honestly before building anything — full voxel destruction is not a feature, it is a second project~~
      No voxels, no real-time fracture simulation, no arbitrary structural
      collapse. That much was already decided by this section's own opening
      line; what was missing was the second half — not what destruction
      isn't, but what it actually *is* here, grounded in what this project has
      already built rather than a wishlist.
      The answer already exists, once: `systems/gore_chunks.gd`. A hit reaches
      a `Layer`, throws pieces that are **identified objects** (`layer`,
      `zone`, `subject_id`, `organ_id`/`implant` where relevant) rather than
      decoration, capped at `MAX_CHUNKS` with LRU recycling, tracked in a
      single `static var live` registry so `identify()`, `take()` and
      `from_subject()` can all ask about any piece on the floor, and left to
      rot and grow flies on a real clock rather than despawning on a timer.
      That is "things break where they are hit, and what comes off them
      stays," already shipped, for exactly one kind of destroyed thing.
      The scope decision AB1.1 actually needed to make: **vehicle destruction
      already exists too, built a second time, independently, narrower.**
      `rift_derby.gd`'s `_add_vehicle_damage_parts()`/`_detach_vehicle_part()`
      break a car where it is hit and throw a real physical piece — the same
      instinct, arrived at separately — but the piece is unidentified (a bare
      node name, no `GoreChunks`-style metadata contract), uncapped rather
      than pool-managed, and explicitly **not persistent**: the very thing
      AB1.3 asks for is where this implementation currently disagrees with
      itself — `get_tree().create_timer(14.0).timeout.connect(loose.queue_free)`
      deletes every detached panel fourteen seconds after it comes off,
      unlike a gore chunk, which survives, rots, and can be picked up. It
      also stores its own damage bookkeeping as loose `set_meta` on the node
      — the exact pattern V1.1 already found and fixed for hull integrity on
      this same file, still present here for panel loss specifically.
      So: **AB1.2 through AB1.6 are not new systems.** They are
      `GoreChunks`'s existing contract (identified, physical, capped,
      persistent, rot-tracked) generalised past bodies, with the vehicle
      damage-parts system as the concrete first migration target rather than
      a hypothetical one — which is also exactly what AB1.4 already named
      ("It reads through the gore system that already exists") before AB1.1
      had said so out loud. AB1.5 ("a vehicle deforms rather than losing hit
      points") is that migration, ideally reading off one real
      condition/integrity figure on the chassis rather than a third,
      separately-tracked number — V1.1/V1.2 would give that figure real
      teeth (driving degrading with damage) if and when Lane 2 builds it.
      No code changed for this entry on purpose: this is the decision AB1.1
      asked for, not an implementation of AB1.2+. Structures (AB1.2) have no
      existing system to compare against yet — walls and windows have never
      been struck-and-broken anywhere in the project — which is real,
      separate work the migration above does not shortcut.
      Lane note: `rift_derby.gd` and `systems/arcade_vehicle.gd` are Lane 2's
      file family per `LANE.md` ("chassis and visuals... you own the inside
      of the car, they own the outside of it"), not Lane 1's. A same-day
      attempt at AB1.3/AB1.4/AB1.5 and at V1.1-V1.4 was built, tested passing,
      and then fully reverted on discovering that boundary — this entry
      records the scope decision for whoever does own that file family to
      execute, not a claim that Lane 1 built or will build it.
- [x] ~~**AB1.1** Decide the scope honestly before building anything — full
      voxel destruction is not a feature, it is a second project~~
      `DESIGN/DESTRUCTION.md`. No per-voxel or volumetric fracture — that is
      a different visual register entirely from this game's authored
      PS1/PS2 low-poly one, not a scaled-down version of it. The scope
      instead: **condition, not fracture** — one number, 0..1, the same
      shape `condition` already takes on the handheld and a weapon's wear;
      a small, *authored* set of break states per object class (four is
      enough to read as staged damage, twelve would only be more art, not
      more damage); debris as real, identified, capped objects reusing
      `gore_chunks.gd`'s already-proven pattern rather than VFX particles;
      repair as one more thing a holding's owner does (AA), not a timer on
      a flag. The doc maps every open AB item onto that reduced scope and
      states plainly what is deferred and why — AB1.5 to Lane 2's own
      vehicle work rather than a second implementation of the same
      primitive, AB3/AB1.6 to once more than one real object exists.
- [ ] **AB1.2** Structures break where they are struck rather than swapping to a damaged model
- [x] ~~**AB1.3** Debris is real, persists, and can be stood on or thrown~~
      New `systems/world_debris.gd`: both places destruction actually throws a
      real `RigidBody3D` — `breakable_prop.gd`'s barricade fragments and
      `rift_derby.gd`'s detached vehicle panels — used to force-despawn on a
      flat timer (3.4s, 14.0s) no matter how far under budget the pool was.
      That was the exact "not persistent" gap AB1.1 named for the vehicle
      panels specifically. Both now register through a shared, named-pool
      registry instead: identified via metadata, capped by recycling the
      oldest piece in that named pool, no fixed-lifetime despawn. A piece
      that fits inside its budget now sits on the ground until something
      actually needs the room — it can be stood on today (both already carry
      a real collider); `take()` exists for pickup-and-throw but nothing
      calls it yet, the same unconsumed seam `gore_chunks.gd` already has for
      B5. Vehicle panels also went from **no shared cap at all** (only a
      per-vehicle guard against detaching the same part twice — up to 72
      uncapped bodies across a full pit of wreckers) to a real quality-scaled
      budget (`vehicle_part_budget()`), which is also a genuine AB1.6/X find:
      that path had never been measured. `breakable_prop_test.gd`,
      `derby_breakables_test.gd` and `derby_budget_test.gd` all still pass
      unchanged; `derby_exit_test.gd` confirms leaving the derby with panels
      shed does not crash.
- [x] ~~**AB1.4** It reads through the gore system that already exists —
      `gore_chunks.gd` already breaks bodies into identified pieces~~
      `world_debris.gd` generalises `gore_chunks.gd`'s proven contract
      (identified via metadata, capped by recycling the oldest, no timer
      despawn) rather than literally calling into it — a scrap barricade and
      a car door have no layer, organ or subject to reuse, only the pattern.
      `DESIGN/DESTRUCTION.md` scoped exactly this: debris "reusing
      `gore_chunks.gd`'s already-proven pattern rather than VFX particles."
      Named pools (`barricade_fragment`, `vehicle_part`) keep the two kinds
      of debris from evicting each other just because they now share a file.
- [ ] **AB1.5** A vehicle deforms rather than losing hit points (pairs with V1.2)
- [ ] **AB1.6** Measure the cost before committing; X exists because nothing here has been profiled

### AB2 — Damage the world keeps
Greg: *"everything is measurably destroyable in the game and the environment
system has a simple way to track that... dents on cars, dents on things, smashes
on windows etc. They repair after a month in game."*

The tracking is the feature. A world where everything breaks and nothing is
recorded resets the moment you look away, and this project already has the
ledger to avoid that.

- [x] ~~**AB2.1** Every breakable thing has a condition the world can read,
      not a destroyed flag~~ New `systems/world_damage.gd`: the `Clothing`
      pattern exactly — static functions over a `WorldHistory` subject, no
      second store, no scene-local flag. `condition(subject_id)` never
      invents damage that never happened; a subject nobody has hit reads as
      intact, the same refusal `Clothing.worn()` already makes for a subject
      nobody has dressed. `band()`/`DEFAULT_BANDS` give a generic answer
      ("intact"/"damaged"/"wrecked"/"destroyed") for anything that has not
      been handed its own authored ladder yet — the actual break-state
      design `DESIGN/DESTRUCTION.md` scopes as the next step, not this one.
- [x] ~~**AB2.2** Damage is recorded against the place, in WorldHistory, like
      everything else~~ `world_damage.gd`'s `damage()`/`repair()` both
      `record_event()` (`object_damaged`/`object_repaired`, with the subject,
      the amount and a `cause`) on top of `amend_subject()`'s mutation —
      refused outright for a subject the world does not know about, so a
      typo'd id fails loudly rather than quietly creating a phantom object
      with no owner and no history.
- [x] ~~**AB2.3** Cheap to ask "how wrecked is this street" without walking
      it~~ `condition()`/`band()` are a single `WorldHistory.subject()`
      lookup each — no scene tree walk, no iterating every breakable object
      in a region to answer one question about one of them.
      Verified: `tests/world_damage_test.gd`, 17 checks — refuses an
      unregistered subject, accumulates rather than overwrites across
      repeated hits, floors at zero and ceilings at full, reports whether a
      hit actually crossed a band rather than just landing within one, and
      confirms a caller's own authored ladder (tested against a stand-in
      vault door) decides its own band independently of the generic one
      while both still read the identical underlying number.
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


### AB5 — Destruction that lines up with the map
Greg: *"making destruction physics finally that line up with full map"*.

The gap named here is not that things do not break — it is that what breaks and
what the world thinks is there are two different records. A wall that has been
blown open still blocks the pathfinder, still reads as cover, still occludes on
the map. Destruction has to write back into the same region record everything
else reads (J10.3), or it stays a particle effect.
- [ ] **AB5.1** A destroyed piece of geometry updates the collision the player
      and the AI actually use
- [ ] **AB5.2** `ashbloom_pathfinder.gd` re-routes through a new hole
- [ ] **AB5.3** The satellite view and the map show the damage (A10, AK)
- [ ] **AB5.4** Cover and line-of-sight are recomputed, so a blown wall stops
      being cover for both sides
- [ ] **AB5.5** Damage persists in `world_history.gd` and is there when you
      come back (Lane 4 owns the field — ask, do not add)
- [ ] **AB5.6** It holds at region scale, not only in a test room

### AB v10 — the final pass
The last rung. Fifteen statements that are true of destruction when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AB10.1** `v10` Everything breakable has a condition the world can read
- [ ] **AB10.2** `v10` Damage is recorded against the place, in the record
- [ ] **AB10.3** `v10` Asking how wrecked a street is costs nothing
- [ ] **AB10.4** `v10` Repair happens over a month of game time
- [ ] **AB10.5** `v10` Who repairs it is somebody, and they can be prevented
- [ ] **AB10.6** `v10` Dents and smashes are the common case; collapse is rare
- [ ] **AB10.7** `v10` A raid is entering a place against resistance for something specific
- [ ] **AB10.8** `v10` Breaking in is a route: doors, walls, roofs, whatever gives
- [ ] **AB10.9** `v10` What you take is carried, priced and traceable
- [ ] **AB10.10** `v10` The holding remembers who did it
- [ ] **AB10.11** `v10` Somebody raids you back
- [ ] **AB10.12** `v10` Bullets contribute to the same ledger as explosions
- [ ] **AB10.13** `v10` Destruction is visible from the satellite
- [ ] **AB10.14** `v10` Nothing is indestructible for engineering reasons only
- [ ] **AB10.15** `v10` A month later the world shows what happened and what got fixed

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
- [x] **AC1.5** Lightning is a real light and a real sound, on the weather clock (W) —
      `storm_weather.gd`: a real `OmniLight3D` flash plus a generated thunder
      crack-and-rumble, severity-scaled, on `world_clock.gd`'s own clock via
      `WorldHistory.chaos_magick()`. Fluid/fire (AC1.1-1.4, 1.6-1.8) untouched.
- [ ] **AC1.6** Fire spreads on what will burn and stops on what will not
- [ ] **AC1.7** Explosions move things, break things and hurt bodies through one path
- [ ] **AC1.8** An engine can catch, and a car that catches is a bomb with a timer


### AC v10 — the final pass
The last rung. Fifteen statements that are true of fluid, weather and fire when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AC10.1** `v10` The decision about simulated versus painted fluid is made and honoured
- [ ] **AC10.2** `v10` Whatever exists is recorded rather than decorative
- [ ] **AC10.3** `v10` Rain wets surfaces and pools where the ground dips
- [ ] **AC10.4** `v10` Blood joins the same system
- [ ] **AC10.5** `v10` Lightning is a real light and a real sound
- [ ] **AC10.6** `v10` Anvil crawlers cross the underside of the storm
- [ ] **AC10.7** `v10` Fire spreads on what burns and stops on what does not
- [ ] **AC10.8** `v10` Explosions move, break and wound through one path
- [ ] **AC10.9** `v10` An engine can catch and become a bomb with a timer
- [ ] **AC10.10** `v10` Water underground behaves differently to water above it
- [ ] **AC10.11** `v10` Contamination travels in the air and settles
- [ ] **AC10.12** `v10` Nothing here costs more than it is worth
- [ ] **AC10.13** `v10` It reads correctly at night under one light source
- [ ] **AC10.14** `v10` Storm severity comes from the chaos-magick level
- [ ] **AC10.15** `v10` A flooded place stays flooded until something changes it

## AF — Guns, properly

Greg, 2026-09-12: *"i have to make the combat system a part of the gun system and
weapons, so bullet, weapon and firing are all realistic bullets and reload with
the things"* — and *"bullets shells fall on the floor aggressively as the bullet
destroys the map"*.

`hunter_arsenal.gd` has damage, spread, pellets, magazines and a reload timer. It
does not have a **bullet**: firing is a raycast and an ammo decrement. Everything
Greg is describing needs the round to be a real object that leaves the weapon,
travels, hits something and leaves a mark on it.

- [x] ~~**AF1.1** A round is a thing that travels, not a raycast resolved on
      the frame it is fired~~ The other half, closed deliberately rather
      than folded into the pass that opened it. `_resolve_firearm()` no
      longer calls `hit_at()` itself; it fires each round with its damage,
      impulse and type riding along as a `payload`, and `Ballistics` hands
      that back on `round_hit` (a body or the world) or a new
      `round_expired` (out of range or below the world) — the three ways a
      round's own fate actually gets decided, none of them the frame the
      trigger went down. `_resolve_body_hit()` is what used to run inline;
      it now runs whenever a round actually reaches somebody, however many
      frames later that turns out to be.
      \
      Two real bugs surfaced building this, both now fixed rather than
      only found: `_on_round_hit()`'s own body/world split gated on
      `is_in_group("actor_body")`, a group nothing in this codebase has
      ever assigned — dead code that had silently discarded every body hit
      `Ballistics` ever reported, replaced with the same collider-to-actor
      walk `_trace_actor()` already proved. And the round's own raycast
      set `collide_with_areas = false`, while every zone hitbox
      (`baseline_human.gd`) is an `Area3D` — a round could not have reached
      a body through this path at all until that flipped to `true`.
      \
      Honestly scoped rather than silently changed: a shotgun's nine
      pellets no longer land as one pre-batched `firearm_anatomy_hit` —
      each is its own real impact on its own frame now, because they no
      longer arrive as one. `weapon_fired` itself stays eager (the trigger
      going down is not an anatomy question); the hit/miss HUD line and
      the whiff/footing consequence of a clean miss wait for the first
      pellet to connect, or for every pellet to have missed, so a stray
      pellet sailing into open air cannot hold the feedback of an already-landed
      hit hostage.
      \
      Verified by `tests/deferred_damage_test.gd` (new, 7/7): a shot at a
      real 20m distance wounds nobody and writes no `firearm_anatomy_hit`
      the instant `_attack()` returns, `weapon_fired` is recorded anyway,
      and the wound and its event both land only once the round has had
      real time to cross the distance — on a real canonical zone, same as
      an instant hit would have landed on. A shotgun blast is confirmed to
      write more than one `firearm_anatomy_hit`, proving the per-pellet
      claim rather than assuming it. `combat_integration_test` and
      `zone_precision_test` amended to await the round's own travel time
      before reading a wound that no longer exists on the old schedule —
      both, plus `ballistics_test`, `firearm_momentum_test`,
      `vault_test`, `wall_run_test`, `jump_test`, `climb_test`,
      `momentum_carry_test`, `anatomy_traversal_test` and `opening_test`,
      re-verified clean
- [x] **AF1.2** It hits the world and leaves damage there (pairs with AB2) — a hole where it arrived, lifted off the surface so it does not fight the wall it is drawn on, sized by the round's energy, and recorded to WorldHistory for AB2 to read
- [x] **AF1.3** Casings eject, bounce, land and stay — out of the port sideways and back, tumbling, two bounces that lose most of their energy, and then lying on their side rather than standing on end, which is the single most obvious tell that nobody simulated them. One case per trigger pull, so a shotgun leaves one for nine pellets
- [x] **AF1.4** Reloading is physical: the magazine leaves the weapon and a new
      one arrives — the mechanical half was already true; this closes the
      part the wording actually names, the part nothing showed. Both firearms
      now carry a real node named `magazine` (`held_gear.gd`): a box mag proud
      of the sidearm's grip heel, a quick-load cassette ahead of the shotgun's
      trigger guard (built box-fed rather than tube-fed, since the mechanical
      model already treats its reserve as discrete magazines exactly like the
      sidearm's). `hunter_arsenal.gd` finds that node once at build time,
      reads its authored rest position rather than a hardcoded one, and rides
      it through the same `reload_remaining` timer that already drives
      `state().reload_ratio`: the old magazine drops clear in the first third,
      the well sits visibly empty through the middle third, a fresh one rises
      back into place in the last third. Nothing can drift out of sync with
      the real reload because both read the one timer. `tests/reload_visual_test.gd`
      (9 checks: the sword's magazine-less case is a no-op rather than an
      error, the sidearm's node resolves, rest/mid-swap/finished positions and
      visibility all verified) plus a re-run of `magazine_test.gd` and
      `arsenal_test.gd` clean. `tests/held_gear_capture.gd` re-captured for
      both firearms — the new geometry sits where authored, no stray or
      degenerate shapes.
- [x] **AF1.5** A magazine dropped half-full is half-full when you pick it up —
      `_finish_reload()` ejects whatever is still loaded as its own discrete
      spare rather than merging it into one reserve number; `tests/magazine_test.gd`
      confirms a magazine survives two separate reloads later still carrying
      the exact count it left with.
- [x] **AF1.6** Calibre means something — muzzle velocity, grain and drag per calibre, and drag proportional to speed squared, so buckshot keeps 93.7% of its speed where a slug keeps 97.1% over the same flight. A shotgun stops being a shotgun at range without anybody writing a falloff curve
- [x] **AF1.7** It reads through the anatomy already built: a round finds a zone, not a hitbox — this was already true and unverified rather than unbuilt: `_trace_actor` raycasts real collision geometry and hands the exact world-space impact point to `BaselineHuman.hit_at`, which resolves it through `zone_nearest(point)` — a live distance comparison against every part's real position — never a name read off whichever collider answered. `tests/zone_precision_test.gd` proves it rather than assuming it: one body, one weapon, one fixed distance, and the only thing that changes between three shots is the pitch, computed from each zone's own real current position (`rig.parts[zone].global_position`) rather than a guessed number. Aiming at where the head actually is wounds head and nothing else; the same for torso and left_leg. A hardcoded or round-robin zone table could not pass this — it would need the shot's outcome to be independent of aim, and it is not. (Building this surfaced a smaller confirmation of the same point: sinking a target far enough below its normal spawn height made shots miss entirely rather than falling back to some default zone, because there was nothing left to hit — a lookup table has no floor to fall through.)
- [ ] **AF1.8** Firing from a car is the same system (M2.3)


### AF6 — The range
The gore sandbox is where a weapon is learned (AU3.5). Same room, same bodies,
same reset — a range that is a place rather than a menu of guns.
- [ ] **AF6.1** Every weapon in `hunter_arsenal.gd` is physically present and
      pick-up-able in the shed — Updated 2026-09-15: every weapon is reachable
      now (AF6.4 below), by wheel/hotkey through a real `HunterArsenal`
      instance in `gore_demo.gd` — but there is still no shed, no rack, no
      physical pickup interaction. Switchable is not the same claim as
      pick-up-able; this item is about the latter and stays open.
- [ ] **AF6.2** Bullets are readable here: drop, drag, travel time, penetration
      shown against real bodies at real distances (AF2)
- [ ] **AF6.3** The reset restores the bodies without restarting the scene
- [x] **AF6.4** What you learn transfers — the range uses the live ballistics
      and the live arsenal, never a demo copy of either —
      `gore_demo.gd` used to hardcode its own `SHOT_WEAPON`/`SHOT_GRIP`/
      `SHOT_CALIBRE`/`SHOT_DAMAGE`/`SHOT_IMPULSE` constants: one weapon's
      numbers copied in, not a reference to them. It now instantiates a real
      `HunterArsenal` and fires through `arsenal.begin_attack()`/
      `shot_directions()`/`current()` directly — the same calls
      `bone_yard_hunt.gd`'s own `_resolve_firearm()` makes — so a weapon's
      damage, ammo, jam and reload behaviour in the range is the Hunt's own,
      not a second copy of it. `ballistics.gd` was already shared. Verified:
      `gore_demo_test.tscn` and `gore_parity_test.tscn` both clean.

### AF v10 — the final pass
The last rung. Fifteen statements that are true of guns when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] **AF10.1** `v10` ~~A round travels, drops, slows and cannot tunnel~~
      Travel, drop and slow were AF1.1/AF1.6, proven in `ballistics_test.gd`
      (a rifle round drops 1.7cm over 40m, buckshot sheds speed faster than
      a slug). Tunnelling was never actually forced: `_step_rounds()` traces
      the whole segment a round crosses in a step (`was` to `at`), which
      cannot miss geometry lying anywhere along the way regardless of how
      far the step was, but nothing had made that step big enough to matter.
      `tests/tunnel_test.gd` (new) calls `_step_rounds()` directly with one
      full second of flight — on the order of 780m for a rifle round in a
      single call — through a 2cm pane 5m out. A destination-only point
      check would sail past it and see nothing; the round stops exactly at
      the pane instead
- [ ] **AF10.2** `v10` It leaves damage on whatever it reaches
- [x] **AF10.3** `v10` ~~Casings eject, bounce, land and stay~~ AF1.3, already
      proven in `ballistics_test.gd`: brass ejects sideways and back out of
      the port, bounces twice losing most of its energy, settles lying on
      its side rather than standing on end, and is still there a second
      later because nothing sweeps it up on its own
- [x] **AF10.4** `v10` ~~Reloading is physical: the magazine leaves and another arrives~~
      AF1.4, already proven both mechanically (`tests/magazine_test.gd`) and
      visually (`tests/reload_visual_test.gd`): a real node named `magazine`
      on each firearm's model drops clear, the well sits visibly empty, and
      a fresh one rises back into place, all driven off the one
      `reload_remaining` timer that also gates the mechanical swap
- [x] **AF10.5** `v10` ~~A dropped half-full magazine is half-full when you pick it up~~
      AF1.5, already proven in `tests/magazine_test.gd`: `_finish_reload()`
      ejects whatever is still loaded as its own discrete spare in
      `spare_magazines` rather than merging it into one reserve number, and
      a magazine that left with three rounds still has exactly three,
      two reloads later. "Dropped" and "picked up" are the reserve bag, not a
      physical object on the ground — the same reading AF1.5 already
      established this codebase means by the sentence
- [ ] **AF10.6** `v10` Calibre decides what happens to a body and to a wall
- [x] **AF10.7** `v10` ~~A round finds a zone, never a hitbox~~ Same proof as B10.3, from the gun's side: a round's impact point resolves through `zone_nearest()` to the limb it struck, and `Penetration` then measures that limb's real thickness at that height to decide how far in it got. A hitbox could not answer either question
- [ ] **AF10.8** `v10` Firing from a car is the same system
- [ ] **AF10.9** `v10` A gun is inspectable in full
- [ ] **AF10.10** `v10` Weapon customisation lives on the weapon
- [x] **AF10.11** `v10` ~~A gun carries momentum and swivels toward where you look~~
      AN1.7, already proven in `tests/firearm_momentum_test.gd`: `ARM_WEIGHTS`
      carries each firearm's own authored mass and reach, `_carry_current_weapon()`/
      `_pose_weapon()` read `arsenal.current_id` the same way for a gun as
      for the sword, and a hard turn visibly displaces each weapon's own
      model off its rest pose — the heavier shotgun lagging further than
      the lighter sidearm under the identical turn, which could not happen
      if the pose write were melee-only
- [x] **AF10.12** `v10` ~~Jams, wear and condition are real~~ AN2.4 already gave a
      *melee* weapon a real, one-way condition that dulls an edge; nothing
      before this ever wore a firearm or let one fail to cycle, because
      `wear_weapon()` was only ever called from the melee hit path. Now
      `HunterArsenal.begin_attack()` wears the current firearm on every shot
      the same way a connecting sword blow wears its edge — `wear_weapon`
      does not care which one asked — and rolls a jam chance that is a pure
      function of that same condition (`_jam_chance()`: zero at full
      condition, rising to 35% as it runs out). A jam does not cost the shot
      that caused it — the round has already left the barrel by the time the
      action fails to cycle — it costs the next trigger pull, refused with
      `{"accepted": false, "reason": "jammed"}` until cleared.
      \
      Clearing a jam is a real, timed action of its own (`JAM_CLEAR_TIME`),
      not a reload dressed up as one: no magazine moves and no round is
      lost. It rides the same input as a reload (`_reload_weapon()` in
      `bone_yard_hunt.gd`) because both are "work the action" to a player,
      and a jammed gun cannot usefully be reloaded until it is clear — the
      same one input, a different real duration, the way `[R]` already meant
      two different things for an empty gun and a full one.
      \
      `tests/weapon_jam_test.gd` (new, 23 checks): a fresh sidearm wears on
      every shot and never jams, because the chance is exactly zero at
      condition 1.0; run down to zero condition it reliably jams within a
      magazine or two; a jammed gun refuses to fire again on its own but can
      still be holstered and drawn again, still jammed; `reload()` clears it
      on a real timer without touching the chambered round; and the arsenal
      cannot be swapped mid-clear any more than it can mid-reload. Re-ran
      `arsenal_test`, `magazine_test`, `weapon_condition_test`,
      `reload_visual_test`, `wall_strike_test`, `combat_integration_test`
      and `firearm_momentum_test` clean — nothing about the melee condition
      path or the existing firearm tests changed, because every new branch
      is gated behind `kind == "firearm"` or a jam-clear timer that starts
      at zero.
      \
      This worktree's `.godot/global_script_class_cache.cfg` predated
      `storm_weather.gd`/`clothing.gd` and made every test that loads
      `bone_yard_hunt.tscn` fail to parse with unrelated "could not find
      type" errors — not this change, but it hid a real type-inference bug
      of this change's own underneath it (`arsenal.JAM_CLEAR_TIME` through a
      loosely-typed reference cannot be inferred by `:=`, the same trap
      `event.pressed` sets on a base `InputEvent`). One `--editor --quit`
      pass rebuilt the cache; the fix is `var duration: float = ...` instead
      of `:=`.
- [ ] **AF10.13** `v10` The floor of a firefight can be read afterwards
- [x] **AF10.14** `v10` ~~Nothing about firing is resolved on the frame the
      trigger went down~~ AF1.1, already proven in `tests/deferred_damage_test.gd`:
      a shot at real distance wounds nobody and writes no `firearm_anatomy_hit`
      the instant `_attack()` returns; `weapon_fired` itself is recorded
      eagerly because the trigger going down is not an anatomy question,
      but the wound and its event both wait for the round to actually cross
      the distance and land on a real canonical zone; a shotgun blast
      confirms more than one pellet lands as its own separate hit rather
      than one pre-batched summary
- [ ] **AF10.15** `v10` A gun can be taken from you

## AD — Movement, and being in first person

Greg: *"right now we need the first person to be insanely comprehensive and have
a good playable HUD, with movement physics, jumping around, building, wall
running like Prototype after a while."* The priority he set.

M covers which camera you are in and why. AD is what the body can do while you
are in it.

### AD1 — The body moves
- [x] **AD1.1** Jumping worth doing — height, arc and a landing that reads. `HunterMotor.move_body()` already ran real gravity, air acceleration and floor-stick every physics frame and `hunter_body_motion.gd` already had a dormant `landing_time` camera-dip/FOV-kick — nothing had ever given the player an upward velocity to actually reach them with. SPACE now jumps when there is no directional input held (a "dodge in place" makes no sense; `_dodge()` still owns SPACE-with-direction exactly as before), queued through `jump_queued` and consumed in `_update_player()`. Building it surfaced a real one-frame-late bug: the first version applied the impulse *after* `HUNTER_MOTOR.move_body()` returned, which is a whole physics step too late — `move_body()`'s own floor-stick branch reads `is_on_floor()` from the *previous* slide, so next frame it saw the body still (stale-)grounded and stomped the impulse straight back to `-FLOOR_STICK` before `move_and_slide()` ever got to use it. Fixed by giving `move_body()` an optional `jump_impulse` parameter so the impulse rides the same `move_and_slide()` call that has to prove it, not the next one. `game/tests/jump_test.gd` (13 checks) covers: queued-not-immediate, consumed-and-applied-in-the-same-slide, refused while airborne, refused while paneled/grappling, the arc actually leaving and returning to the floor on its own, `landing_time` firing for real, and SPACE-with-direction still dodging without also queuing a jump. `opening_test` and `combat_integration_test` re-verified clean against the `HunterMotor.move_body()` signature change (the one call site).
- [x] ~~**AD1.2** Vaulting and mantling: waist-high things stop being
      walls~~ Three real raycasts against actual collision geometry decide
      it (`_vault_target()` in `bone_yard_hunt.gd`), not a fixed "step
      height" or a tag on level geometry: a low cast (0.4m up) finds
      whether there is an obstacle in front of the player at all; a high
      cast (`VAULT_MAX_TOP`, 1.35m) tells a low obstacle from a real wall —
      if anything is still in the way up there it stays a wall, AD1.3's
      problem and not this one's; a downward cast just past the low hit
      finds exactly where the obstacle's own top actually is, in world
      height terms, rather than guessing one number for every crate, rail
      and curb in the game; a final pair (floor + headroom) confirms the
      far side actually has somewhere to land and room to stand once there.
      SPACE now checks this before the existing dodge/jump split, not after
      — a waist-high thing in front is exactly the case a plain dodge or a
      plain jump both handle badly, and the whole point is that the
      traversal button should not require knowing which of the three a
      player needs. Execution is a real timed motion (`VAULT_DURATION`
      0.34s, eased position lerp from `vault_from` to `vault_to`) that
      takes over from normal movement/gravity for its duration and hands
      control straight back — not an instant teleport and not a soft-lock.
      Free rather than costing stamina, same reasoning as AD1.1's jump:
      this is basic traversal, not a combat manoeuvre. Honestly scoped: no
      dedicated vault animation pose exists yet (`hunter_body_motion.gd`
      has no such trigger), so the body reads as idle for the motion's
      duration while the camera position moves for real; and the far-side
      offset (`VAULT_FAR_SIDE`, 0.55m) assumes a reasonably thin obstacle —
      a genuinely deep one (a thick wall rather than a rail, crate or
      curb) is outside what this was built or tested against. Verified:
      `tests/vault_test.gd` (new, headless, 13/13, against a real
      `StaticBody3D`/`BoxShape3D` obstacle rather than an assumed shape) —
      open ground finds nothing, a 0.8m box is found and lands past it near
      real floor height, a 2.2m wall in the identical spot is correctly
      refused by the high ray, and a triggered vault visibly progresses
      over several physics steps before landing exactly on the point the
      raycasts found, with normal movement/gravity resuming immediately
      after. `tests/vault_capture.gd` (new, windowed) confirms the camera
      genuinely crosses the obstacle across three captured frames rather
      than only the numbers agreeing. `jump_test`, `opening_test` and
      `combat_integration_test` regression suites re-verified clean.
- [x] ~~**AD1.3** Wall running, earned the way third person is earned
      rather than given~~ `wall_run_unlocked()` in `bone_yard_hunt.gd`
      mirrors `third_person_unlocked()`'s own shape exactly — a real thing
      the player did, not a flag, read live off `WorldHistory` rather than
      cached — but ties the count to `player_vaulted` (AD1.2's own event,
      `WALL_RUN_UNLOCK_VAULTS = 3`) instead of boss kills, because
      wall-running is the next rung of the traversal skill vaulting already
      is, not a combat unlock. Unlocking is announced the same way third
      person's is (`_announce_wall_run_unlock()`, checked in `_update_hud()`
      the frame the count first crosses, an `impact_feel` kick, a
      `wall_run_unlocked` WorldHistory event, a prompt line), not a silent
      permission flip.
      \
      The run itself needs no key to start: `_wall_run_surface()` looks to
      both sides of the player whenever they are airborne and moving fast
      enough (`WALL_RUN_MIN_SPEED`), with a near cast finding a wall within
      reach and a second, higher cast (`WALL_RUN_MIN_HEIGHT`) confirming it
      keeps going — a short ledge fails that second cast and is left to
      AD1.2's own vault instead of being double-handled. Redirects velocity
      along the wall's own face every frame (re-found, not cached, so a
      wall that curves or ends mid-run is read honestly) under a fraction
      of real gravity (`WALL_RUN_GRAVITY_SCALE`) rather than none, so it
      reads as a body fighting to stay up rather than flight. SPACE while
      running is a real kickoff — checked ahead of the dodge/jump split
      entirely, since `_jump()` refuses outright the instant it sees the
      player is not on the floor, which a wall run always is — pushing the
      body away from the wall and up with its own impulse rather than a
      plain fall dressed up as one.
      \
      Building the test surfaced a real tuning bug: a fresh jump's vertical
      velocity was carried straight into the run unchanged, so a run begun
      right off a jump kept climbing under reduced gravity for its entire
      duration and sailed straight up past the top of the wall instead of
      tracking level along it. Fixed in `_begin_wall_run()` by capping
      (never zeroing — catching an already-falling body should still read
      as momentum) the vertical velocity a run starts with.
      \
      Verified: `tests/wall_run_test.gd` (new, headless, 16/16, against
      real `StaticBody3D` walls rather than assumed shapes) — the unlock
      threshold is exact and reads live off real events; a tall wall is
      found and its tangent genuinely lies along the wall's own face; a
      1.0m ledge correctly fails the height check and falls to the vault
      instead; a triggered run travels real distance over real time while
      staying flush to the wall; and a kickoff consumes its own request,
      ends the run, and leaves with a real upward component. Getting the
      test to a genuinely airborne starting state surfaced the same
      one-frame floor-snap gotcha AD1.1's own jump test had already named —
      solved the same way, by riding the real, already-proven `_jump()`
      path rather than fighting `move_and_slide()`'s snap by hand.
      `tests/wall_run_capture.gd` (new, windowed) confirms the camera
      genuinely travels along the wall and is genuinely thrown clear of it
      on kickoff, across three captured frames, and that the unlock prompt
      really reaches the HUD rather than only the WorldHistory record.
      `jump_test`, `vault_test`, `opening_test` and `combat_integration_test`
      regression suites re-verified clean.
- [x] ~~**AD1.4** Climbing a building is a route, not a cutscene (Prototype's
      lesson)~~ `_climb_wall()` is `_vault_target()`'s own low/high pair —
      a hit within reach at foot height, and something still there above
      the vaultable band — reused rather than a second obstacle scanner,
      cast straight ahead instead of `_wall_run_surface()`'s sideways pair,
      since a climb is a wall the player is facing, not one they are
      running alongside. Needs no key, the same way starting a wall run
      does not: a sprint into a wall too tall to vault becomes a climb with
      no seam, on the ground or in the air, because the Prototype reference
      is a body that runs at a building and keeps going up it, not one
      that stops to ask first. Earned one rung past wall-running — gated on
      `player_wall_run_kickoff`, the same shape `wall_run_unlocked()`
      already uses one rung down — because climbing is what wall-running
      was training the body for.
      \
      The "route, not a cutscene" half is the design decision: the climb
      is re-found every frame exactly the way a wall run is, so a wall
      that ends or curves away mid-climb drops the body into a real fall
      rather than freezing it against nothing, and the instant a ledge
      comes within reach — read straight off `_vault_target()`, its own
      on-floor gate waived for this one caller since a climbing body is
      airborne against a wall by definition — it hands straight into the
      identical scripted mantle a running vault would use. AD1.5's own
      claim before AD1.5 is properly built: climbing does not stop to ask
      before becoming a vault, it just becomes one. Gated the same real
      floor every other traversal verb answers to (`PLAYER_INJURY_FLOOR`
      via `mobility_ratio()`), and duration and speed both shorten for a
      hobbled body the same way `_vault()`/`_begin_wall_run()`'s own
      already do, rather than a body that can still climb at all being
      refused the healthy baseline right up until it cannot climb.
      Honestly scoped: this is a timed climb with a real cap
      (`CLIMB_MAX_DURATION`), not free climbing to any height a building
      happens to be — a wall taller than the cap affords runs out and
      drops the player, which is the honest outcome rather than a
      cutscene papering over a height nobody built for. Verified:
      `tests/climb_test.gd` (new, headless, 13/13, against real
      `StaticBody3D` walls) — the unlock threshold is exact and reads live
      off real events; a 3m wall dead ahead is found and its normal
      genuinely points back out of the wall; a 0.8m box is correctly left
      to `_vault_target()` instead of being double-handled; a triggered
      climb travels real vertical distance over real time and then chains
      into a real mantle with no key pressed for either half; and a wall
      that disappears mid-climb ends the climb rather than continuing to
      climb nothing. `vault_test`, `wall_run_test`, `jump_test`,
      `anatomy_traversal_test`, `opening_test` and `combat_integration_test`
      regression suites re-verified clean.
- [x] ~~**AD1.5** Momentum carries between moves — run into vault into climb
      is one motion~~ Real, measured gaps closed rather than a restatement
      of AD1.4's own claim. A vault is a scripted position takeover —
      `player_body.velocity` sits unread for its whole duration — and it
      was being zeroed at the start and left there, so `HunterMotor`'s own
      `move_toward()` acceleration had to rebuild a run from a dead stop on
      the far side of every single obstacle: a real stutter, not a feeling.
      `_vault()` now captures the horizontal velocity the instant it is
      called and hands it straight back the moment the lerp ends, so the
      run a vault interrupted keeps going on the far side instead of
      re-accelerating from zero. The same gap existed one layer up: a climb
      that chains into AD1.4's mantle was handing `_vault()` the climb
      loop's own small into-the-wall vector instead of the sprint that led
      into the climb, so `_begin_climb()` records that entry speed and the
      mantle hand-off restores it before `_vault()` captures it.
      \
      Verifying this exposed a real bug in AD1.4 itself, not just AD1.5:
      the per-frame "is the wall still there" recheck during a climb was
      reusing the same too-tall-to-vault high check the *initial* trigger
      needs, and that check keys off the exact height line
      `_vault_target()`'s own mantle detection does — a climb closing in on
      a ledge could cross that line and lose the high check on the very
      frame the mantle should have taken over, ending in a fall instead.
      `_climb_wall()` takes a `require_tall` parameter now: `true` for the
      one-time initial decision (is this a wall or a crate), `false` for
      the ongoing recheck, which only needs to know a wall is still within
      reach at all. AD1.4's own test had also been passing on a fallback
      that accepted "climbed at all" as good enough without a real mantle
      actually landing anywhere — there was no roof built for it to land
      on. Both `climb_test.gd` and the new coverage below now build one and
      require the real thing.
      \
      Verified by `tests/momentum_carry_test.gd` (new, headless, 9/9):
      landing speed after a vault (8.00) matches entry speed, not a
      rebuilt fraction of it; the run speed a climb replaces is genuinely
      recorded; and speed on the far side of a full climb-into-mantle chain
      still reflects the sprint that led into it. `climb_test.gd` re-tightened
      to require the mantle it chains into actually lands (13/13, still
      clean). `vault_test`, `wall_run_test`, `jump_test`,
      `anatomy_traversal_test`, `opening_test` and `combat_integration_test`
      regression suites re-verified clean.
- [x] ~~**AD1.6** All of it reads through the anatomy: a broken leg cannot
      vault~~ `AnatomyComponent.mobility_ratio()` already existed and
      already gated running speed through B6.5's `_player_speed_scale()` —
      this reads the exact same signal into all three AD1 verbs rather
      than inventing a second injury number for traversal. One leg
      destroyed outright (`health = 0`, the other untouched) reads
      `mobility_ratio() = 0.5`, below the same `PLAYER_INJURY_FLOOR`
      (0.55) B6.5 already draws its own line at — below it,
      `_vault_target()` and `_wall_run_surface()` both refuse outright,
      literally "a broken leg cannot vault." Above the floor, the read is
      continuous rather than a single cliff: `_jump()`'s impulse is scaled
      by `_player_speed_scale()` directly (reused whole, not recomputed,
      so footing/stagger affects a jump's height exactly as it already
      affects a step's speed), a permitted vault takes longer the worse
      off the body is (`vault_duration`, tracked per-attempt rather than
      against the flat constant, since a hobbled vault is deliberately
      handed *more* time than a healthy one gets — the eased-lerp in
      `_update_player()` was fixed to divide against this instead of the
      constant it used to, or a hobbled vault's own progress maths would
      have finished, and glitched, past 100% before the extra time was up),
      and a permitted wall run holds for less of `WALL_RUN_DURATION` the
      worse off the legs are. What the floor does not touch: B6.5's own
      "never below a speed you could retreat at" promise — the gate is on
      the three *advanced* verbs, not on the ability to move at all, so a
      catastrophically hurt player can still walk, still jump (a smaller
      jump, never no jump), just cannot vault or hold a wall until healed.
      Verified: `tests/anatomy_traversal_test.gd` (new, headless, 11/11) —
      a healthy body vaults freely and jumps at the full, unscaled impulse;
      one leg destroyed drops mobility below the floor and both the vault
      and the wall run a healthy body could make are refused outright,
      while the jump still fires, visibly smaller, never zero; a bruised
      -not-broken pair of legs (60/75 health each) clears the floor and
      still gets a vault through, measurably slower than a healthy one's.
      `wall_run_test`, `jump_test`, `vault_test`, `opening_test`,
      `combat_integration_test` and `combat_response_test` regression
      suites re-verified clean.

### AD2 — The first-person HUD
- [x] ~~**AD2.1** Diegetic: the hands, the weapon, the handheld, the windscreen~~
      (pairs with M1.6) — four of four now, not three. This line's own note
      said the windscreen "names M2, which does not exist yet" — stale by
      the time anyone read it again: M2 (`## M — The camera is progression`)
      is fully built and verified above this line in the same file
      (`M2.4`/`M2.5`), the same way that section's own header note already
      caught itself out once. The hands and weapon are a real held
      viewmodel (M4); the handheld is a real device raised into a real hand
      (`handheld_device.gd`, Section C); the windscreen is a real `BoxMesh`
      plane you shoot through and that degrades under hits (`M2.4`/`M2.5`,
      `vehicle_interior.gd`). All four are real geometry a camera looks at,
      not a HUD icon standing in for one
- [x] ~~**AD2.2** Nothing floating in a corner that could be on an object
      instead~~ Not built here — cross-ticked against what M1.6 and AG4.5
      already did in `gothic_field_hud.gd`, unrelated to this pass and
      never checked off. The old health readout was, in its own comment's
      words, "a second instrument with no relationship to anything else on
      screen, the exact 'floating in the corner' the design rule names";
      it now hangs off a strap running into the weapon well, and stamina is
      read off the screen's own breathing rather than a bar at all. Nothing
      in the current build sits in a bare corner with no relationship to
      anything else. Verified against `captures/m1_6_field_hud_vitals.png`
      and this pass's own `captures/ad2_4_field_hud_first_person.png`: the
      vitals gauge and the weapon well are one instrument, joined by a
      visible cable, not two floating widgets
- [~] **AD2.3** Affordances along the bottom that say what you can do right
      now — real and already tagged `AD2.3` in `gothic_field_hud.gd`'s own
      `_draw_controls()`, not built in this pass. **Not fully true yet**:
      AG2.4 already recorded the actual gap and it still stands — the strip
      shows the current verbs but does not announce a *new* one the moment
      it becomes available, only the weapon's own. `gothic_field_hud.gd` is
      Lane 5's file; noted rather than reached into
- [x] ~~**AD2.4** It survives the transition to third person without
      dissolving (M3.3)~~ True by construction rather than by a fix: nothing
      in `_update_hud()` gates `field_interface.set_state()` or its
      visibility on `third_person`, so there was nothing that could
      dissolve on the switch. Verified rather than assumed —
      `tests/field_hud_third_person_capture.gd` (new) drives the same
      third-person camera path `_update_camera()` uses for a resolution
      shot and captures both: `captures/ad2_4_field_hud_first_person.png`
      and `captures/ad2_4_field_hud_third_person.png` show the identical
      location crest, hunt thread, vitals-and-weapon gauge and bottom strip
      over a camera that has genuinely moved to the third-person position
- [x] ~~**AD2.5** Readable while moving, which is when it is actually
      needed~~ `$HUD` is a `CanvasLayer` (`FieldInterface` lives at
      `$HUD/FieldInterface`) — a 2D layer with no relationship to the 3D
      camera's own transform, so nothing that shakes, kicks or turns the
      camera (`impact_feel`, a dodge, a hard turn) ever touches the HUD's
      own position or legibility; it is exactly as readable mid-fight as it
      is standing still. Confirmed against both captures above: identical
      text, identical position, camera in two different places

### AD3 — Builds that break the rules
Greg: *"not to copy HAVKER-MAN X, but with the cybernetics and limb enhancements
you should be able to viably, with melee, at some points fight people with
grenade launchers and RPGs — through jumping on rockets, or cutting them in half,
sniping them, through enhanced character builds."*

The payoff for D, B2 and N: a body built far enough in one direction should be
able to answer a rocket with a blade, and the game should let it.

- [x] ~~**AD3.1** A melee build can close on a launcher and live — the distance is the puzzle~~
      The item names its own answer in its last five words, and the answer is
      not "a launcher that does less damage" — that is a number, and AD3's
      whole complaint is numbers. `systems/launcher_actor.gd` makes range the
      thing the weapon is good at *and* the thing it stops being good at:
      **it cannot arm inside `MIN_ARMING_METRES` (9m)**. Inside that ring it
      is a person holding a tube. Closing mid-wind-up does not pause the shot,
      it loses it — the difference between the distance being a puzzle and
      the distance being a delay.
      Two more things make it answerable rather than merely survivable: the
      `rocket` calibre leaves the tube at 38 m/s against a pistol's 340, so
      you can see it coming; and it telegraphs with a wind-up deliberately
      longer than a melee one, because a puzzle whose inputs you cannot read
      is a coin flip.
      **It closes AD3.3's loop.** A warhead is an ordinary round in ordinary
      flight, so the interception AD3.3 built for bullets works on the thing
      this section was actually about — you can cut a rocket out of the air.
      It also resolves through the same payload `_on_round_hit()` already
      reads, so it finds a zone through the anatomy (AF1.7) rather than being
      a special explosion that knows about bodies by itself.
      All the decision lives in `launcher_actor.gd` as pure statics over
      plain values — the same shape `combat_response.gd` and `clinch.gd`
      already use — so `bone_yard_hunt.gd` holds a hook rather than a second
      copy of the rule, and the whole thing is testable without a scene.
      Verified: `tests/launcher_test.gd` (17 checks) — it arms exactly at the
      authored distance and not a hair inside it, winds up visibly before
      firing, loses a building shot when you step inside the ring, never
      touches a non-launcher actor, throws no brass, and is met in the air by
      a blade with AD3.3's own `intercept_near()`. Eight existing suites
      re-verified clean.
      Still open: nothing in the world *spawns* one yet — an actor becomes a
      launcher by carrying `launcher: true`, and no encounter authors that
      today. That is content placement rather than mechanism, and it is the
      one thing between this and meeting one in a real fight.
- [x] ~~**AD3.2** Cybernetics change what movement is possible, not just the numbers~~
      The second half is the whole item. A limb that makes you twelve per
      cent faster has changed a number; these change whether a move exists.
      Both run through the same `capable_limbs()` route B6.1 built, keyed off
      the hardware's own catalogue `profile`, so they are the limb's and not
      the body's — and a severed leg takes them with it (B6.2) without either
      of them having to hear about it.
      **The ceiling.** `_vault_ceiling()` replaces the flat `VAULT_MAX_TOP`
      inside `_vault_target()`. Bare, it is AD1.2's own 1.35 line and
      anything above it is a wall — "AD1.3's problem, not this one's", as
      that function already said. With drive hardware in a leg it is 1.95,
      which leaves a real 0.60m band of obstacle that is a *wall* for a bare
      body and a *vault* for an augmented one. Not a faster vault. A possible
      one. Deliberately chest height rather than head height, so walls stay
      walls and AD1.3's wall-running is not quietly taken away from itself.
      **The kick-off.** A bare body cannot leave the ground a second time —
      `_jump()` refuses an airborne press exactly as it always has. A leg
      with drive hardware gets one kick off nothing, spent on use and reset
      by touching down, so the hardware grants an extra departure rather than
      flight.
      `heel anchors` is the catalogue's own right-leg entry and reads exactly
      like the thing that drives a body off the ground, so nothing new had to
      be authored in `implant_catalog.gd` (Lane 5's file) to make this real.
      Verified: `tests/augmented_movement_test.gd` (19 checks) — the bare
      ceiling is AD1.2's line to the centimetre, fitting the hardware raises
      it to the authored augmented figure, the other leg is unaffected, an
      airborne press is accepted with the hardware and refused without it,
      pulling the hardware takes both moves back, and severing the leg takes
      them too with nothing in this pass needing to know. Ten existing
      movement suites (`jump`, `vault`, `wall_run`, `climb`,
      `anatomy_traversal`, `momentum_carry`, `limb_capability`, `intercept`,
      `footing`, `opening`) re-verified clean.
- [x] ~~**AD3.3** A projectile is a physical thing that can be met, not a damage event~~
      AF1.1 already made a round an object that travels, with two ways its
      flight could end: arriving somewhere (`round_hit`) or running out of
      world (`round_expired`). Neither is *being met* — until now a round
      could only ever be dodged, never answered, which is what made AD3.1's
      "answer a rocket with a blade" unexpressible rather than merely
      unbalanced. `Ballistics.intercept_near(position, radius, by)` is the
      third outcome: something reaches into the flight path and takes the
      round out of the air, emitting its own `round_intercepted` (carrying
      the shooter, the payload that now never arrives, and the energy it
      still had left) and deliberately *not* `round_hit`/`round_expired`,
      so a caller waiting on either to learn whether a shot connected is
      never told the wrong thing by a third outcome dressed as one of them.
      Position-and-radius rather than an index because the caller is a
      swing — it knows where and when it landed, not which of `MAX_ROUNDS`
      entries that is.
      Wired into the real move, not left as an API nothing calls:
      `_resolve_strike()` checks the arc for rounds *before* anything else
      the swing could reach, answers through the arm at its own
      `ROUND_MELEE_RESISTANCE` (below stone, well above air), takes a real
      bite out of the edge (AN2.4), and records `melee_met_round`.
      Verified: `tests/intercept_test.gd` (25 checks) — a round is taken
      out of the air and genuinely gone; the interception is its own signal
      carrying shooter/payload/remaining energy; `round_hit` and
      `round_expired` both stay silent for it; a swing nowhere near it takes
      nothing and reports no phantom; reach is a real distance (a miss at
      3m, a connect at 0.4m); a zero reach meets nothing; all nine pellets
      of a shotgun are nine separately-met objects; and — driven through
      `_resolve_strike()` itself in a real instantiated Hunt Grounds — a
      real swing takes a real round out of the air and the world records it
      exactly once, while a swing at empty air records nothing. Ten
      existing melee/ballistics tests re-verified clean.
      Still open: nothing yet *fires* anything worth meeting — there is no
      launcher or rocket in `hunter_arsenal.gd` (AD3.1's own gap), so today
      this answers a bullet rather than the RPG the section is really
      about. The primitive is the part that was missing; the weapon that
      makes it dramatic is AD3.1's, not this line's.
- [x] ~~**AD3.4** Absurd answers are allowed when the build earned them~~
      Not a new item so much as what AD3.1 and AD3.3 add up to, stated
      plainly: cutting a rocket out of the air with a blade is absurd on
      its face, and it is not gated behind a cutscene or a QTE — it is
      `_resolve_strike()` checking the arc for a live round through
      `intercept_near()` before anything else the swing could reach,
      answering through the same arm every other blow does. Nothing stops
      a fresh, unaugmented body from trying it and nothing helps one
      succeed either: `AD3.2`'s cybernetics do not touch interception at
      all, so meeting a rocket is earned entirely by timing and reach, and
      closing on a launcher is earned by knowing `MIN_ARMING_METRES` and
      using it, not by a stat that makes the launcher forget to fire.
      Verified already by `intercept_test.gd` and `launcher_test.gd`
      (42 checks between them) — nothing new to build, only to say plainly
- [x] ~~**AD3.5** Original to this game: the reference is the feeling, never
      the implementation~~ Audited rather than built. AD3's own header
      names HAVKER-MAN X and says explicitly not to copy it; every piece
      that answers this section is original mechanism built from this
      game's own primitives — `launcher_actor.gd`'s arming ring is a
      distance check against `MIN_ARMING_METRES`, `intercept_near()` is a
      position-and-radius check against `Ballistics`' own rounds, and
      `_vault_ceiling()`/kick-off are `capable_limbs()` reading a catalogue
      `profile` — none of it borrowed code or a ported system, each
      already used elsewhere in this project (`combat_response.gd`,
      `clinch.gd`, B6.1's own route) for an unrelated reason first. The
      feeling — a body built far enough in one direction can answer a
      rocket with a blade — is the only thing carried over


### AD v10 — the final pass
The last rung. Fifteen statements that are true of movement and first person when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] **AD10.1** `v10` Jumping is worth doing and the landing reads — See AD1.1: a real upward impulse, `landing_time` firing for real, `jump_test.gd` (13/13). Re-verified clean this pass.
- [x] **AD10.2** `v10` Waist-high things stop being walls — See AD1.2: `_vault_target()`'s real three-raycast read of actual collision geometry, `vault_test.gd` (13/13). Re-verified clean this pass.
- [x] **AD10.3** `v10` Wall running is earned the way third person is — See AD1.3: `wall_run_unlocked()` mirrors `third_person_unlocked()`'s own shape, read live off `WorldHistory`, `wall_run_test.gd` (16/16). Re-verified clean this pass.
- [x] **AD10.4** `v10` Climbing a building is a route, not a cutscene — See AD1.4: re-found every frame rather than scripted, hands off into a real mantle, `climb_test.gd` (13/13). Re-verified clean this pass.
- [x] **AD10.5** `v10` Momentum carries between moves as one motion — See AD1.5: a vault captures and restores real horizontal velocity rather than zeroing it, `momentum_carry_test.gd` (9/9). Re-verified clean this pass.
- [x] **AD10.6** `v10` A broken leg cannot vault — See AD1.6: `mobility_ratio()` below `PLAYER_INJURY_FLOOR` refuses vault and wall run outright, `anatomy_traversal_test.gd` (11/11). Re-verified clean this pass.
- [ ] **AD10.7** `v10` Crouching, sprinting and sliding are one continuous system — Not built. No AD1 line ever covered crouching or sliding; sprinting exists (`B6.5`'s speed scale) but there is no crouch or slide verb to be continuous with it.
- [x] ~~**AD10.8**~~ `v10` The HUD is the hands, the weapon, the handheld and the glass — true, now that AD2.1 above is: hands/weapon (M4), handheld (Section C) and the windscreen (M2.4/M2.5, real geometry you shoot through and that degrades) are all real, all diegetic, none of them a HUD icon standing in for the thing itself.
- [x] **AD10.9** `v10` Nothing floats in a corner that could sit on an object — See AD2.2: the vitals gauge hangs off the weapon well by a visible cable rather than sitting alone; confirmed again by eye against `captures/ad2_4_field_hud_first_person.png` and `_third_person.png` while verifying AD10.11 below.
- [ ] **AD10.10** `v10` Affordances say what you can do right now — **Not fully true**, per AD2.3's own note: the bottom strip shows current verbs but does not announce a *new* one the moment it becomes available. `gothic_field_hud.gd` is Lane 5's file.
- [x] **AD10.11** `v10` It survives the change to third person without dissolving — See AD2.4. Opened and looked at both again rather than taking the old note on faith: `captures/ad2_4_field_hud_first_person.png` and `_third_person.png` show the identical location crest, hunt thread, vitals-and-weapon gauge and bottom strip over two genuinely different camera positions.
- [x] **AD10.12** `v10` It is readable while moving, which is when it is needed — See AD2.5: `$HUD` is a `CanvasLayer` with no relationship to the 3D camera's transform, so nothing that shakes or turns the camera touches its position or legibility.
- [ ] **AD10.13** `v10` Cybernetics change what movement is possible — Note corrected 2026-09-15: AD3.2 is now `[x]` closed, not open as this line previously claimed. Not yet re-verified whether it lands as a true v10 statement — needs a real check against AD3.2's implementation, not another status flip.
- [ ] **AD10.14** `v10` A projectile is a physical thing that can be met — Note corrected 2026-09-15: AD3.3 is now `[x]` closed, not open as this line previously claimed. AF1.1's round-travels-but-nothing-intercepts-it gap was the separate, substantive claim here and has not been re-checked — don't assume it's resolved just because AD3.3 closed.
- [ ] **AD10.15** `v10` A melee build can close on a launcher and live — Note corrected 2026-09-15: AD3.1 is now `[x]` closed, not open as this line previously claimed. Not yet re-verified whether it lands as a true v10 statement — needs a real check against AD3.1's implementation, not another status flip.

## AE — Sneaking, assassination and the law

Greg: *"assassination, executing and sneaking systems with the hostile and law
enforcement type figures who punish you for bad local karmic events."*

The karma axis and the witness ledger already exist. Nobody has ever come to
arrest anybody.

- [x] **AE1.1** Unseen is a real state with real inputs — light, noise, cover,
      distance — `perception.gd`'s `visibility()`, a pure function of all
      four, and `bone_yard_hunt.gd`'s `_update_perception()` supplying real
      values every frame against every live hostile (light from
      `WorldClock.daylight()`/the handheld; noise from sprinting, the one
      input with no other system behind it yet; cover from a real raycast).
      Unblocks AS1.5 and AU1.10's AE1.4. `player_unseen`/`player_visibility`
      are computed and correct but nothing reads them yet — see AE1.2/AE1.3.
- [ ] **AE1.2** An unseen kill differs from a seen one, mechanically and in the record
- [ ] **AE1.3** Assassination as a verb: reach somebody who does not know you are there
- [ ] **AE1.4** Law figures respond to what was actually witnessed (`witness_ledger.gd`)
- [ ] **AE1.5** Punishment is local: the holding remembers, and the holding sends them
- [ ] **AE1.6** Karma is an axis, not a score — the law reads position, not "evil"
- [ ] **AE1.7** Being hunted by the law is the Hunt System pointed back at you (F)
- [x] **AE1.1** Unseen is a real state with real inputs — light, noise, cover, distance — `LocalLaw.unseen_state()`: combines real 0..1 light/noise/cover plus real distance against a real sight range (defaulting to `witness_ledger.gd`'s own `SIGHT_RANGE`, so being unseen and being unwitnessed never quietly disagree about how far is too far). Never a single invented "stealth" stat measured on its own authority
- [x] **AE1.2** An unseen kill differs from a seen one, mechanically and in the record — `LocalLaw.assassinate()` routes every kill through `witness_ledger.gd`'s real `record()` (F1), carrying a real `unseen` flag; the mechanical difference is not a second flag anybody has to check, it is that a kill with no witnesses passed in has nothing in flight to ever report it, so it can never reach a faction's knowledge at all
- [x] **AE1.3** Assassination as a verb: reach somebody who does not know you are there — `LocalLaw.assassinate()`, through the exact same `npc_resolution`/`execute` vocabulary every other execution already uses (`event_karma()`, `route_endings.gd`, `ascent_entities.gd`) so it moves karma and the Tree exactly as hard as any other kill; the only thing that changes is whether anybody was ever there to know
- [x] **AE1.4** Law figures respond to what was actually witnessed (`witness_ledger.gd`) — production Hunt resolutions now record through the live ledger with nearby living witnesses instead of writing around it. `LocalLaw.answer_report()` accepts only a report that completed the real F1 delay and reached the faction holding the scene; the global event log cannot dispatch law by itself. Two witnesses cannot charge one source sequence twice. `hunt_local_law_integration_test` drives a real execute resolution in the production Hunt and proves all seven stages from scene position to delayed faction knowledge
- [x] **AE1.5** Punishment is local: the holding remembers, and the holding sends them — `AshbloomHoldings.jurisdiction_at()` resolves the act's real X/Z to the same canonical `place` subject MAP, INDEX and Board use without revealing unsurveyed land. That subject (`held_by`, `unrest`, source sequences) accumulates real offence magnitude per witnessed wrong on its own ground; once it remembers enough (`RESPONSE_THRESHOLD`) it spends that memory and raises the answering faction's own real `grudge` — the exact field `wire_net.gd`'s channel-contest retaliation (K4.6) and `the_four_horsemen.gd` (K2.5) already use for "the world acts on you", not a second consequence channel. Covered by `local_law_test` plus the production-scene integration above
- [x] **AE1.6** Karma is an axis, not a score — the law reads position, not "evil" — `LocalLaw.offence_magnitude()`: a faction's own real `FACTION_TREE_AXIS` position decides whether an act was even a wrong to it, read against the same real `event_karma()` every act already carries. Verified both directions: the identical execution is no offence to a faction deep in Descent and a real one to a faction that climbed the other way, and the identical act of mercy inverts which faction is offended — nowhere is there a universal crime score either reads instead
- [ ] **AE1.7** Being hunted by the law is the Hunt System pointed back at you (F) — needs `rival_registry.gd` (Lane 4's); `witness_a_wrong()`'s real `grudge` rise is already the field that system reads, so wiring it in is additive once asked for as an API, not attempted here

Covered by `tests/local_law_test.gd` (23 checks). `tests/karma_test.gd`, `tests/witness_test.gd`, `tests/route_endings_test.gd`, `tests/ascent_entities_test.gd` and `tests/propagation_test.gd` re-run clean.



### AE v10 — the final pass
The last rung. Fifteen statements that are true of sneaking and the law when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AE10.1** `v10` Unseen is a real state with real inputs
- [ ] **AE10.2** `v10` Light, noise, cover and distance all feed it
- [ ] **AE10.3** `v10` The handheld's glow is the commonest thing that gives you away
- [ ] **AE10.4** `v10` An unseen kill differs mechanically and in the record
- [ ] **AE10.5** `v10` Assassination is reaching somebody who does not know you are there
- [ ] **AE10.6** `v10` Law figures respond to what was actually witnessed
- [ ] **AE10.7** `v10` Punishment is local and the holding sends them
- [ ] **AE10.8** `v10` Karma is an axis, not a score
- [ ] **AE10.9** `v10` Being hunted by the law is the Hunt System pointed at you
- [ ] **AE10.10** `v10` Witnesses can be wrong, bought or silenced
- [ ] **AE10.11** `v10` The tunnels are where the satellite cannot see you
- [ ] **AE10.12** `v10` A crime has a jurisdiction and jurisdictions end
- [ ] **AE10.13** `v10` You can be arrested rather than killed
- [ ] **AE10.14** `v10` Standing with a faction changes what the law does
- [ ] **AE10.15** `v10` What you were wanted for carries into the next universe

### AG4 — The third playtest, and what Greg is sick of
- [x] **AG4.1** *"when running and the stamina bar depletes, the screen becomes super jittery"* — TaKeS was right and so was his guess at the cause. Two thresholds now, not one
- [x] **AG4.2** *"the blood splatter effects... just being lame asf"* — `blood_veil.gd`: spatter with direction, near glass out of focus against far glass sharp, drops heavy enough to run down the screen, three stages of drying
- [x] **AG4.3** *"no more mara voss wipe it"* — wiped, and not by find-and-replace: a second hardcoded name is the same fault with different letters. `cast_names.gd` generates the captain from `run_salt`, so they are stable inside a save and different in the next. Eight saves gave eight captains: Vale Rime, Roan Hollow, Halloway Coil, Mera Lockwood, Ash Coil, Kester Cinder, Nix Arden, Reve Arden. F v10.1 already demanded this
- [x] **AG4.4** *"make this clickable with the mouse not just arrow keys"* — the index tabs are pointable and the footer leads with CLICK ANYTHING instead of listing five keyboard controls
- [x] **AG4.5** *"no more vessel breath bullshit"* — gone, and replaced by the same information carried by things already in the frame. **Breath became breathing**: the frame tightens and releases on a cycle whose rate climbs and depth falls as stamina empties, so hard breathing is fast and shallow and the edges close in. Nothing to read, which is why it works while you are being attacked — the one moment a stamina bar is least useful. **Vitality became the mark’s own condition**: the crown arc opens, thorns snap off one at a time (four a side at full, countable at a glance), and the pulse goes quick and irregular below 40%. Dressing a progress bar in a crown never stopped it being a progress bar
- [ ] **AG4.6** The website
- [ ] **AG4.7** The gore and the X-rays enhanced

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
- [x] ~~**AG2.1** He could not find the Board; Greg could not remember the key either~~ — F1 opens a keys card that names THE BOARD on P, in the group for things you carry. The card's rows are written by the scene rather than held in the card, so it cannot drift from what is actually bound (`systems/keys_card.gd`)
- [x] ~~**AG2.2** Nothing teaches the weapon wheel — Greg had to guess *"i think its holding b?"*~~ — on the card as HOLD Q, and moved off B while fixing it: B is a stretch from WASD and this is a hold you are meant to move during. Greg: *"make the b slider change to like e or idk r or q"* — E is interact and R is reload, so Q
- [x] ~~**AG2.3** *"press buttons probably"* is the current discovery mechanism for every panel~~ — the closed-state hint names the key in the corner and stops after two openings, because a permanent prompt for a help screen is the tutorial look arriving by the back door
- [~] **AG2.4** The first-person HUD must say what can be pressed (AD2.3) — the contextual strip in `gothic_field_hud.gd` covers the verbs for what you are looking at, and the keys card covers the panels. What is still missing is the strip naming an affordance the moment it appears rather than only the weapon ones

### AG3 — The derby, second playtest
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
- [x] ~~**AG3.5** Nothing in the derby says what any key does - the first thing AH has to fix~~ — the same card, with the derby's own rows: driving, the gun, and getting out. E CLIMB OUT is in it by name, which is the key every playtester has missed



### AG5 — Demo build, 13 September 2026
Greg sending the first build to friends, and reporting while it ran.
- [x] **AG5.1** *"it crashes when you look at the body parts in the body section"* — a real crash with a cause worth naming. `character_sheet.gd` published `anatomy.organs` as a String naming the decanted organ set; everywhere else in the game `anatomy.organs` is a Dictionary of live organ states. The moment the player had a sheet, `body_inspector._condition_of` read "standard" where it required a Dictionary and threw from inside `_draw`, once per frame, in the index and the device both. The sheet writes `organ_set` now, `load_from_world` still reads the old key when what is under it is actually a String, and the inspector stops assigning straight into a typed Dictionary. `tests/organ_key_collision_test.gd`, 7 checks
- [x] **AG5.2** *"the menus and indexes and tab buttons after you get out of the car"* — the hunt is the only scene owning a blood veil and a psychedelic rig, and both were added to `$HUD` after every panel, so both painted over the index, map and board. The shader samples the whole frame drawn so far, so an open index was not tinted, it was displaced, and the page tabs rendered somewhere other than where they were clickable. Ordered in `_order_hud_layers`
- [x] **AG5.3** Opening any panel once and closing it left the retired orange HUD stuck over the real interface for the rest of the run — `_toggle_panel` turned `title`, `status` and the vitals box back on, and `_update_hud` re-hid only `status`
- [x] **AG5.4** **FIX DEVICE SIZING** — both hosted panels were handed `_clip.size` as their own size, so the index laid itself out for a 1074x515 letterbox using measurements authored against 1280x720. Widths survived it, heights did not: the file page ran through the footer and the bottom of the plate was cut off. The panel now gets the viewport's size and is scaled to fit, so hosted and fullscreen are the same layout
- [x] **AG5.5** The floating sword, third attempt and the first one that found the cause. Two passes retuned the mount and both made it worse, because the value was never reaching the model — `_pose_weapon` assigned `model.rotation` every frame from arm sway alone and discarded the counter-rotation `hunter_arsenal` writes to cancel the arm pitch. With the rest rotation cached the way the rest position already was, the honest value is the pure cancellation of `FIRST_PERSON_ARM_RAISE`
- [x] **AG5.6** *"fixing the wobbly screen like you smoked weed or nicotine — even tho at the start you get a random drug"* — AS2.1 had nightfall driving the shader's displacement dial, so a sober player after dark had a permanently moving screen and the one state the shader exists to express stopped being legible. The hour no longer touches the dial; substances, meditation and the shadow realms own it. The later consciousness seam repeated the same failure in time instead of by source: it added `altered * 0.05` to the previous frame sixty times a second, so one modestly harsh smoking take liquefied the view before the next inspection. It now assigns the bounded anatomy-derived value every frame; `altered_perception_test` holds the same state for 120 updates and proves it cannot accumulate
- [x] **AG5.7** The transit plate was acid green, in a register nothing else in the game uses. Blood now, carrying the seal of the place you are arriving at — ring, point count and stride seeded off the destination path — with runnels down the glass
- [~] **AG5.8** *"i hate the look of this ui it looks ugly"* — the bottom-right cluster specifically, and the fonts generally. Greg wants boxes, dimensional HUD panels, and a grungier biopunk face throughout
  - [x] The fonts. `gothic_field_hud.gd` had three call sites still drawing in `ThemeDB.fallback_font` — the location crest, the hunt-thread readout and the archive-frame header — the exact "tutorial level, same as the font" look `celloutz_type.gd` exists to replace, missed because all three are conditionally hidden and rarely on screen. All three now draw in the stencil face. The crest's em-dash bracketing is gone with it (the stencil alphabet has no glyph for "—"; it drew as two silent gaps) in favour of the "//" register the rest of the HUD already uses. Found in passing: the weapon well's reserve count used "×", also glyph-less and silently blank since it was written — now "x". Verified visually via `hunt_weapon_capture`, regression-checked against `hud_transience_test` (7/7)
  - [x] Greg supplied the missing steer: corners have separate responsibilities rather than four matching boxes. Top-right is an original cracked mood reliquary with narrow, bottom-filling blood and dirty-water stamina ampoules hanging vertically beneath it; its magick vessel does not exist before unlock. Bottom-left is contextual anatomy, first implemented as a live lung X-ray. Top-left holds the Ashbloom date/hour, contaminated air and hunt threat. Bottom-right remains held weapon and ammunition. `_draw_regal_vitals` is retired from the live draw path rather than restyled into another generic status block (`tests/smoking_lung_ui_test.tscn`, `tests/hud_transience_test.tscn`)
  - [x] Greg's next refinement supersedes the temporary lower-corner ownership above: the scuffed Black Mirror physically pokes from a pocket at lower-right, its satellite/radar feed owns lower-left consistently, and contextual anatomy lives beneath the top-left world/threat instrument instead of displacing the radar. The last open half is now built rather than checked off by implication: outside a grapple, holding `V` draws the quick X-ray forward into a paired, rotatable 3D pulmonary reliquary; mouse movement turns the live specimen, the wheel zooms it and release returns immediately to play. It reuses `PartViewer`'s authored lobes and reads the exact `AnatomyComponent.lung_state()` health/stain plus the active inhaled fill/cough values every frame — no decorative lung and no parallel damage meter. `V` still persuades inside a clinch. `smoking_lung_ui_test` proves paired geometry, exact state transfer, rotation and zoom; `smoking_act_test` proves the held binding, release and keys-card teaching; the real Hunt render at `captures/pulmonary_reliquary.png` was visually checked after correcting lobe separation and viewport/title overlap
  - [x] The centred `// LIMBO // ASHBLOOM EXPANSE //` arrival banner is removed from the live field draw. The ordinary world now passes through a dedicated, restrained barrel lens beneath the HUD, while mirrored blood-and-bone cartouches, bowed rails and a dark glass lip frame the screen above it; readable HUD geometry is never distorted with the world
  - [x] The bottom-right stitched oblong and its hand-drawn weapon silhouettes are retired from the live draw. `held_item_reliquary.gd` extracts render geometry from the object actually in the player's hands, excludes the viewmodel hands, centres and scales it from its complete turning radius, and therefore accepts cigarettes, guns and carried severed limbs through one path without clipping or lopsided placement. Its 22-second idle is a closed 360-degree screensaver orbit: yaw eases through brief reversals instead of endlessly spinning one way, while pitch, roll and breath use 3/5/8 Fibonacci harmonics separated by the golden angle. Ammunition, burn and condition remain as terse object-state marks beneath it
  - [x] The lower-left field map is the real A10 satellite camera at a local scale, requested at eight frames per second while the full map is closed; it carries player heading and a low-light surveillance grade rather than becoming a second invented radar
  - [x] The unexplained red `BodyWitnessMirror` no longer stands in the Hunt's opening sightline. Its actual live-body mirror implementation and standalone tests remain for an authored inspection room, but a development fixture is not scenery
- [ ] **AG5.9** *"the hunt thing hardly works at all zero continuity"* — the Hunt System does not hold together across a session
- [ ] **AG5.10** The map has to integrate the underground conspiracy network text file, and carry Greg's own art textures
- [x] **AG5.11** Save files: deletable, continuable, several of them, so somebody can keep a world and generate new stories in it — `WorldHistory` gains `active_slot_id`/`slot_manifest` and `create_slot`/`load_slot`/`delete_slot`/`list_slots`. `SAVE_PATH` stays the untouched legacy file every editor run and headless test always used; a slot is a layer the front-end opts into by setting `active_slot_id`, at which point `_current_path()` redirects load/save at `user://saves/<id>.json` with its own `manifest.json` row. A save from before this existed surfaces as a "Continue" slot the first time `list_slots` runs rather than becoming invisible. `tests/save_slots_test.gd`, 17 checks. Front-end menu wiring (an actual save-select screen) is not built yet — this is the machinery underneath it

### AG v10 — the final pass
The last rung. Fifteen statements that are true of the playtest record when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AG10.1** `v10` Every playtester note is in the record with their words
- [ ] **AG10.2** `v10` Nothing reported is closed without being reproduced
- [ ] **AG10.3** `v10` A fix names the cause, not the symptom
- [ ] **AG10.4** `v10` A bug that could not be reproduced says so
- [ ] **AG10.5** `v10` Playtests happen on the exported build, not in the editor
- [ ] **AG10.6** `v10` The build a tester played is recoverable
- [ ] **AG10.7** `v10` Their confusion is treated as a design fault
- [ ] **AG10.8** `v10` What they liked is written down so it is not broken
- [ ] **AG10.9** `v10` Controls they could not find become AH nodes
- [ ] **AG10.10** `v10` A regression that a test would have caught gets a test
- [ ] **AG10.11** `v10` The second playtest is compared to the first
- [ ] **AG10.12** `v10` Somebody who has never seen it plays it every milestone
- [ ] **AG10.13** `v10` Their save is kept
- [ ] **AG10.14** `v10` Nothing is dismissed as user error
- [ ] **AG10.15** `v10` The record of playtests is public in the build sheet

## AH — The Cloud, and the room you remember it from

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

### AH1 — The room
- [x] **AH1.1** Opening the Board puts you in a room rather than on a screen — `the_room.gd`, four walls the player stands inside, built the way everything else here is: procedural geometry from primitives, nothing imported. `facing()` turns to a wall by name so a caller asks for the Board rather than computing an angle and hoping
- [x] **AH1.2** A bed, a mirror the size of the wall, and the light of one window — one window, low and off to the side, because a room lit evenly is a menu background and a room lit from a single opening is a place. First aim put the spot into the wall it is set in, which lit nothing and made the mirror black as well: a reflection of an unlit room is an unlit reflection
- [ ] **AH1.3** Turn to the wall and the Board is there - the corkboard already built (L)
- [ ] **AH1.4** Turn right and the cloud terminal is there
- [x] **AH1.5** The mirror shows your body, current, with everything done to it (pairs with N) — done, and the bug is worth keeping because it cost an hour of looking at the wrong thing. The reflection was correct the entire time. `tests/room_mirror_diagnostic.gd` asked the camera directly rather than squinting at renders — position, gaze, near plane, cull mask, frustum tests on head, chest and feet, and a count of pieces passing the mask — and every one of them came back right. Dumping the viewport's own texture full frame showed the body standing in the room, perfectly rendered. **The fault was the surface displaying it.** The glass was a `BoxMesh`, which puts the reflection on all six faces with the same UVs and leaves which one the viewer reads up to the geometry. A `QuadMesh` has one face and a normal, so there is nothing to get wrong. Lesson for the next one of these: when a render looks wrong, separate *what is being drawn* from *what is drawing it* before touching either
- [ ] **AH1.6** The room is yours and it accumulates - what you leave in it stays
- [ ] **AH1.7** Leaving is a movement, not a menu close

Greg, 2026-09-13, which changes what the room *is* rather than adding to it:
*"menus or idk index inside the phone maybe like a trapped menu inside the phone
of a 3d modelled version of my room or using photos."*

Two things follow, and the second is the bigger one. **It is a specific room**,
not a bedroom — the poster wall is the reference photograph in
`Art Collections`: Taxi Driver, End of Evangelion, Nausicaä, Mononoke, Silent
Hill 2, Apocalypse Now, Dark Souls, Postal 2, Vault-Tec, the GTA map, two
SHADOW WIZARDS sheets and the money-gang print above them, visionary panels
filling the corner, and a persian rug across the ceiling. That wall is where
this game's references actually come from, so putting it behind the glass is
the game admitting what it is made of. And **the index lives there too** — not
just the tutorial. This is house rule I0 taken to its end: no screen is a list
of text in a box, and the last screens that still are lists stop being screens
at all.

"Trapped" is the word worth keeping. You are holding a phone, and inside the
phone is the room you are sitting in, holding the phone.

- [ ] **AH1.8** The room is a real one — the poster wall, not a generic bedroom
- [ ] **AH1.9** Every page of the handheld is somewhere in the room; the INDEX is a place you turn to, not a list
- [ ] **AH1.10** Built from photographs rather than modelled where that reads better — projected planes and depth from the corner, not a scanned mesh
- [ ] **AH1.11** You are in the room, holding the phone, which contains the room. The recursion is on purpose and is visible in the mirror
- [ ] **AH1.12** The wall accumulates: what the run does to you gets pinned up there, so the reference wall becomes a record (pairs with AH1.6)

### AH2 — REMEMBER THE CLOUD
- [ ] **AH2.1** The cloud is an archive of everything the world used to know, in fragments
- [ ] **AH2.2** A fragment is repaired, not unlocked - the verb is restoration
- [ ] **AH2.3** Repairing one costs something the player actually has
- [ ] **AH2.4** What you recover is a real game mechanic explained, not lore
- [ ] **AH2.5** The archive is visibly incomplete forever - you never finish it
- [ ] **AH2.6** It talks like cloud software written by people who are now dead

### AH3 — The tutorial web
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


### AH v10 — the final pass
The last rung. Fifteen statements that are true of the room and the cloud when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AH10.1** `v10` Opening the Board puts you in a room
- [ ] **AH10.2** `v10` A bed, a wall-sized mirror, one window's light
- [ ] **AH10.3** `v10` The Board is on the wall and you turn to it
- [ ] **AH10.4** `v10` The cloud terminal is to your right
- [ ] **AH10.5** `v10` The mirror shows your body, current, with everything done to it
- [ ] **AH10.6** `v10` The room accumulates what you leave in it
- [ ] **AH10.7** `v10` Leaving is a movement, not a menu close
- [ ] **AH10.8** `v10` The cloud is an archive in fragments
- [ ] **AH10.9** `v10` A fragment is repaired, not unlocked
- [ ] **AH10.10** `v10` Repairing costs something you actually have
- [ ] **AH10.11** `v10` What you recover is a mechanic explained, not lore
- [ ] **AH10.12** `v10` The archive is visibly incomplete forever
- [ ] **AH10.13** `v10` Each node is a curved CRT playing the mechanic as a drawn loop
- [ ] **AH10.14** `v10` Under it: a paragraph in the game's voice, and the keys
- [ ] **AH10.15** `v10` A locked node shows static and the shape of what is missing

## AI — The pyramid, and what is under it

Greg sent three reference charts - the occult hierarchy pyramid, *Hierarchy of
the Old World*, and the gods/demigods/mortals stack - with one instruction:
*"the pyramid structure in the tab map and everything needs to be rework with
this inspiration... also the pyramids should be like upside down and then up
top"*.

Two pyramids meeting at a point. Upright above, inverted below. **As above, so
below** - which is not decoration here, it is the two-axis system the game
already has: AA hands a holding to the ascent or to corruption, and those are
the two cones. The player stands at the waist, where they touch.

### AI1 — The shape
- [x] ~~**AI1.1** The Tree page becomes a double pyramid, upright above and
      inverted below~~ `world_index.gd`'s PYRAMID page rebuilt: a waist band
      splits it into two cones, `_draw_pyramid_cone(rect, faction_id,
      apex_up, register)` drawing the same tier logic for either — `apex_up`
      alone decides which physical edge the crown sits against, so one
      function serves both rather than the shape being written twice.
- [x] ~~**AI1.2** The waist is where the player is, and it is the only tier
      you occupy~~ `_draw_pyramid_waist()` reads the player's own
      `WorldHistory.tree_alignment()`/`tree_descriptor()` — the same numbers
      the FILE page's own Tree axis already draws — never a tier on either
      cone.
- [x] ~~**AI1.3** Tiers are drawn as strata with real edges, not a list with
      indentation~~ Unchanged from the single pyramid this replaced — real
      trapezoid strata with a stroked edge, not indentation.
- [x] ~~**AI1.4** The upper cone is the ascent: what is above you and what it
      demands~~ Populated from whichever faction in `WireNetScript.ASCENT_LEDGER_FACTIONS`
      (K3.2 v2's own dual-ladder list) the player has the strongest real
      command/ally/bond edge into, via new `_strongest_ladder_faction()`.
- [x] ~~**AI1.5** The lower cone is corruption: what is under you and what it
      is owed~~ Same function, `DESCENT_LEDGER_FACTIONS`, mirrored — crown at
      the bottom, intake at the waist, "inverted" for real rather than
      merely relabelled.
- [x] ~~**AI1.6** Density carries meaning - the base is crowded, the apex is
      one thing~~ Preserved from the single pyramid — `span_for()` still
      narrows toward whichever edge is that cone's own crown.
- [x] ~~**AI1.7** Legible at a glance and rewarding an hour of reading; the
      references do both~~ Row text found to overlap once the double
      pyramid halved the vertical room a single one had — fixed with fixed,
      bottom-anchored two-line offsets per row instead of fractions of a
      shrinking `row_height`; verified by a windowed capture with both
      cones populated (`captures/ai1_double_pyramid.png`) rather than left
      as read-the-code.

### AI2 — What it charts
- [x] ~~**AI2.1** Every tier is populated from WorldHistory, not authored -
      who is actually above you~~ `wire.pyramid(faction_id)` — already
      WorldHistory-derived — called twice, once per cone.
- [x] **AI2.2** Factions sit where their power is, and they move — unchanged,
      inherited from the pyramid data layer this reuses.
- [x] ~~**AI2.3** Your own position is computed, and it changes~~ The waist
      reads `tree_alignment()` live every draw, and which faction populates
      each cone is recomputed from real relation edges every time the page
      opens — nothing here is cached past a single reading.
- [x] ~~**AI2.4** The Board's theories pin onto the pyramid - the two
      charts are one document~~ Reads straight off the exact WorldHistory
      record `pin_board.gd`'s own `published()` already reads
      (`WorldHistory.subject(PinBoard.BOARD_ID).published`) rather than
      needing a live `PinBoard` instance handed to this page — the two
      screens agree because they are reading the same subject, not because
      one calls the other, which is the honest reading of "one document."
      New `_theories_naming(subject_id)` in `world_index.gd` walks that
      record newest-first and resolves each theory id back to its real
      title via `PinBoard.THEORIES`. A named subject who is also a real
      pyramid tier member now carries a small pin marker (`PinBoard.MARKER`/
      `THREAD`, the Board's own thread-red, not a new colour invented for
      this page) — anchored to the member's icon corner rather than free
      text on the rank line, because a real capture showed exactly why that
      first attempt fails on the one row it matters most: the crown tier is
      drawn narrowest of all of them (AI1.6's own "narrow at the crown"
      rule), so the row a player is most likely to check a claim against is
      the row least likely to have text-width to spare. The icon is a fixed
      size regardless of tier span, so the mark survives every width; a
      fuller "PINNED — <TITLE>" text tag is drawn alongside it whenever the
      row's own free space actually allows it. A retraction (L4.4 v2)
      clears the pin for free, since a retracted theory is simply no longer
      in the record either side reads. Verifying this for real caught a
      second, unrelated, pre-existing bug in the same function: the Descent
      cone's header text was measured from `rect.end.y` directly while its
      band (and therefore its own tiers, per AI1.2's "outer edge" placement)
      was correctly reserving 54px above that for the header — so on every
      faction with a populated Descent cone, the header printed straight
      through the Crown and Inner Circle rows. The Ascent cone never showed
      it only because its own header math already measured from `band_top`
      instead of the rect edge. Fixed by giving both cones the same
      `band_bottom` the Ascent cone already effectively had. Verified:
      `tests/pyramid_pin_test.gd` (new, headless, 8/8 — wired through the
      real `PinBoard.pin()`/`lay_string()`/`publish()`/`retract()` calls
      rather than hand-writing the WorldHistory shape, so the test proves
      the two screens actually agree) and `tests/pyramid_pin_capture.gd`
      (new, windowed) plus a fresh `double_pyramid_capture.gd` recapture,
      which is what actually caught the header/crown overlap and then
      confirmed it gone. Existing `double_pyramid_test`,
      `sephiroth_tree_test`, `index_link_rebuild_test`, `index_wire_glow_test`,
      `link_test`, `opening_test` and `combat_integration_test` regression
      suites re-verified clean.
- [ ] **AI2.5** Satire aims at institutions and never at congregations — a
      content/tone audit, not a code change; not verified this pass.
- [x] ~~**AI2.6** Marginalia in the corners, the way the references carry
      it~~ "AS ABOVE, SO BELOW" printed once in the corner, and the
      recruitment pitch ("ADVANCEMENT OPPORTUNITY…") kept on the Ascent
      cone specifically, in whatever room is actually left under its last
      tier. Verified: `tests/double_pyramid_test.gd` (new, 4/4 — the pure
      data logic: no commitment reads as unclaimed rather than a default
      pick, the stronger of two relations wins, and a grudge does not count
      as real standing), plus the existing `link_test.gd`,
      `index_wire_glow_test.gd`, `index_link_rebuild_test.gd`,
      `celloutz_site_test.gd` and `clerical_audit_test.gd` regression
      suites, and windowed captures of both the unclaimed and populated
      states (`captures/ai1_double_pyramid_unclaimed.png`,
      `ai1_double_pyramid.png`).


### AI v10 — the final pass
The last rung. Fifteen statements that are true of the pyramid when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AI10.1** `v10` Two pyramids meeting at a point, upright above and inverted below
- [ ] **AI10.2** `v10` The waist is where you are and it is the only tier you occupy
- [ ] **AI10.3** `v10` Tiers are strata with real edges, not indentation
- [ ] **AI10.4** `v10` The upper cone is the ascent and what it demands
- [ ] **AI10.5** `v10` The lower cone is corruption and what it is owed
- [ ] **AI10.6** `v10` Density carries meaning: the base is crowded, the apex is one thing
- [ ] **AI10.7** `v10` Legible at a glance and rewarding an hour
- [ ] **AI10.8** `v10` Every tier is populated from the record, never authored
- [ ] **AI10.9** `v10` Factions sit at their real power and they move
- [ ] **AI10.10** `v10` Your own position is computed and it changes
- [ ] **AI10.11** `v10` The Board's theories pin onto it
- [ ] **AI10.12** `v10` The tree sits beside it, charting which way you went
- [ ] **AI10.13** `v10` Marginalia in the corners the way the references carry it
- [ ] **AI10.14** `v10` Satire aims at institutions and never at congregations
- [ ] **AI10.15** `v10` It takes its density from the charts and never their payload

## AJ — Chaos magick, v2

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

### AJ1 — Making a sigil
- [~] **AJ1.1** State an intent, in the player's own words — `ChaosSigil.seal_for(intent)` accepts any free text and is the only door in; no screen asks for one yet (that entry point is Lane 5's — a text field on the handheld's RITUAL page, or wherever this gets hosted)
- [~] **AJ1.2** The letters are stripped and condensed on screen - you watch it become a glyph — `ChaosSigil.condense()` is the real procedure (drop non-letters, keep only the first occurrence of each, drop vowels once consonants survive so a vowel-only intent never condenses to nothing) and `ChaosSigil.draw()` renders the result through `celloutz_type.gd`'s existing seal engine unmodified. The *watching it happen* half — an animated letters-collapsing-into-a-glyph transition — is not built; this produces the finished mark, not the transition into it
- [x] **AJ1.3** The glyph is deterministic from the intent: the same words make the same sigil, always — seeded off the condensed letters rather than the raw text, so case and whitespace noise never change the mark. `tests/chaos_sigil_test.gd` (11 checks) and a windowed `chaos_sigil_capture` (three different intents, three genuinely different marks, `chaos_sigil_gallery.png`) verify both the seed math and the actual drawn output
- [~] **AJ1.4** Charging costs something real - blood, stamina, a drug, a death — `ChaosSigil.charge()` spends real blood through the exact ledger `boons.gd` already pays E4 boosts from (`Boons.pay()`, newly exposed as a public wrapper rather than reaching into `_pay()`), scaled by how much the intent actually condensed to, refused outright the same way a boon would be if the body has nothing left to give. `tests/chaos_sigil_charge_test.gd` (9 checks): a real cost lands, a longer ask draws more, a blank intent charges nothing, an empty body refuses, and each successful charge is its own findable `sigil_charged` event. Honestly scoped to one of the four named costs: stamina lives only as a live, unpersisted value in `bone_yard_hunt.gd` (Lane 1's), a drug cost would spend from CARRY (contested with Lane 4's own AL work today), and "a death" is a real consequence system nothing here invents. Blood is the one already fully at home in this ledger
- [x] **AJ1.5** Forgetting is mechanical: a charged sigil you keep looking at does not fire — `ChaosSigil.can_fire()`/`fire()`/`remember()` read a real clock against `WorldClock`'s own time (`FORGET_HOURS`, 6): charging is itself a moment of attention, so a freshly charged sigil cannot fire on the same breath, and `remember()` (looking at it again) resets the clock rather than letting the delay keep accumulating underneath the looking. Firing consumes it — a second `fire()` on the same sigil is refused as `ALREADY SPENT`, not a free second effect. Covered by `tests/chaos_sigil_forget_test.gd` (14 checks)
- [x] **AJ1.6** It goes into the world as an object - scratched, burned, carried or worn — `ChaosSigil.inscribe()`: a charged sigil becomes its own real `WorldHistory` subject (`kind: "sigil_object"`), one of the four real media, findable and readable like anything else physical in this world (AJ2.4's future defacing/theft has something real to act on). Refuses an un-charged intent and a made-up medium alike. Deterministic per-maker object ids (`sigil_objects_made` counts up on the maker's own subject) so the same intent can genuinely go into the world twice over in different media without colliding. Covered by `tests/chaos_sigil_object_test.gd` (15 checks)

### AJ2 — What a sigil does
- [x] **AJ2.1** Effects come from the intent, parsed, not from a spell list — `ChaosSigil.resolve()`: five broad semantic word families (`INTENT_FAMILIES` — violence, protection, concealment, fortune, sight), matched against real words in the stated intent, never fifty exact authored phrases. A match grants a real, temporary `Boons` effect on the family's own stat. Effects hang off `fire()`'s own forgetting gate (AJ1.5) rather than duplicating it
- [x] **AJ2.2** A sigil can fail, and a failed one leaves something behind — an intent matching no family is a real, honest "misfired" outcome (not an error, not a silent no-op), and every miss raises `chaos_corruption` on the same real ledger AJ2.5's overcharging writes into. A matched intent can also misfire if the caster has nothing left to pay the granted effect with
- [x] **AJ2.3** The same glyph gets stronger the more it has worked — `sigil_potency`, keyed by seed (not by subject alone, so two different intents from the same caster earn their strength separately), increments on every successful resolve and scales the next working's magnitude. Verified: the identical intent resolved twice hits harder the second time; a genuinely different intent does not inherit that earned strength
- [x] **AJ2.4** Other people's sigils exist in the world and can be read, defaced or stolen — `read_object()`/`deface()`/`steal()` act on the exact same `sigil_object` subject AJ1.6's `inscribe()` already creates. Defacing and theft both raise the real maker's `grudge` (F2's own field), theft harder than defacing, so an act against a sigil is an act against whoever made it. Only `worn`/`carried` media can actually change hands — `scratched`/`burned` refuse outright as fixed in place
- [x] **AJ2.5** Corruption is what happens when you charge more than you can carry (AI1.5) — `chaos_pending` tracks real charged-but-unfired sigils on the caster's own record (advanced in `charge()`, returned in `fire()`); past `CARRY_CAPACITY` (3) the next charge still succeeds but comes out corrupted, and a corrupted sigil always misfires on `resolve()` regardless of what it actually asked for. AI1.5's own UI reading of the resulting `chaos_corruption` number is not attempted here — only the real mechanical consequence is

Covered by `tests/chaos_sigil_resolve_test.gd` (19 checks) and `tests/chaos_sigil_theft_test.gd` (16 checks). Full `chaos_sigil` suite (6 files, 84 checks) re-run clean.

### AJ3 — Modern gods
- [x] **AJ3.1** The gods of this world are what is actually worshipped: markets, metrics, engagement, brands — `systems/modern_gods.gd`: The Engagement, The Market, The Quota, The Brand
- [x] **AJ3.2** A god is a real entity in WorldHistory with attention, not a flavour label — `kind: "god"`, real `attention` field, same shape `ascent_entities.gd` already proved
- [~] **AJ3.3** Worship is measurable (`attention` accumulates on every verdict asked) — feeding the upper cone (AI1.4) is a UI/pyramid concern, not attempted here
- [x] **AJ3.4** Naming a god in an intent gets their attention, which is not always wanted — `ChaosSigil.resolve()` now checks the stated intent for each god's own name word (`GOD_NAME_WORDS`) and calls `ModernGods.get_attention()` for every one named, whether the sigil goes on to resolve, misfire or come out corrupted (naming is what costs the attention, not success). Covered by `tests/chaos_sigil_god_attention_test.gd` (11 checks)
- [x] **AJ3.5** The target is always the institution, never the congregation — satisfied by construction: all four gods are markets/metrics/labor/image, never a person or a people

### AJ4 — Magic as progression
- [x] **AJ4.1** Skill is what you have actually done, read off the record — `ChaosSigil.skill_level(subject_id, family)` counts real `sigil_resolved` events for that family, the exact events `resolve()` already writes — no second stat invented anywhere that this file would have to keep in sync with the real one
- [x] **AJ4.2** No skill tree - the pyramid (AI) is the tree, and you climb it — true by construction rather than a separate decision to enforce: `skill_level()` is a count over real history, not a node graph with its own state, so there is no second progression structure for AI's pyramid to compete with
- [x] **AJ4.3** A practice you stop practising decays — `skill_level()` only counts within a trailing `SKILL_DECAY_HOURS` (168, a week of `world_clock.gd` time, W1.1). Nothing prunes old workings on a timer; they simply age out of the window on their own, which is what "stop practising and it decays" means read literally. Covered by `tests/chaos_sigil_skill_test.gd` (8 checks)
- [ ] **AJ4.4** Every system in the game is reachable through a sigil, badly — out of scope this pass: genuinely reaching "every system" means integrating sigils into systems other lanes own, which is exactly what the six-lane split exists to prevent without an API request
- [ ] **AJ4.5** The playground rule: the system should surprise its own author — a qualitative playtesting judgment, not a line a test can verify from inside the engine

### AJ5 — The verdict on a kill
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
- [x] **AJ5.6** `v2` Freeing souls and enslaving them both have consequences, and they are different ones — `ModernGods._apply_consequence()` moves the ruling god's own real `relations` toward the killer on FREED and away from them on ENSLAVED (`standing_with()` reads it back), clamped, per-killer, per-god — a genuine `UNDECIDED` verdict moves nothing rather than being silently scored either way. Kept apart from `verdict()` itself so reading an opinion (the Board, a dossier) never moves anything by asking. Still one relationship number, not a differentiated *kind* of consequence per outcome (a real future step — e.g. an enslaved god actively working against you vs a freed one favouring you — is not attempted here). Covered by `tests/modern_gods_consequence_test.gd` (9 checks); `tests/modern_gods_test.gd` re-run clean
- [x] **AJ5.7** It is recorded in WorldHistory, so the Board can pin it and the pyramid can read it — one `death_verdict` event per god's opinion. Covered by `tests/modern_gods_test.gd` (19 checks)


### AJ v10 — the final pass
The last rung. Fifteen statements that are true of chaos magick when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AJ10.1** `v10` State an intent in your own words
- [ ] **AJ10.2** `v10` Watch the letters strip and condense into a glyph
- [ ] **AJ10.3** `v10` The same words always make the same sigil
- [ ] **AJ10.4** `v10` Charging costs blood, stamina, a drug or a death
- [ ] **AJ10.5** `v10` Forgetting is mechanical: a sigil you keep looking at does not fire
- [ ] **AJ10.6** `v10` It goes into the world as an object
- [ ] **AJ10.7** `v10` Effects come from the intent parsed, never a spell list
- [ ] **AJ10.8** `v10` A failed sigil leaves something behind
- [ ] **AJ10.9** `v10` A glyph gets stronger the more it has worked
- [ ] **AJ10.10** `v10` Other people's sigils can be read, defaced or stolen
- [ ] **AJ10.11** `v10` Corruption is charging more than you can carry
- [ ] **AJ10.12** `v10` The gods of this world are what is actually worshipped
- [ ] **AJ10.13** `v10` Naming one gets its attention, which is not always wanted
- [ ] **AJ10.14** `v10` Every system in the game is reachable through a sigil, badly
- [ ] **AJ10.15** `v10` The system surprises its own author

## AM — The build sheet becomes the map

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


### AM v10 — the final pass
The last rung. Fifteen statements that are true of the build sheet when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AM10.1** `v10` The sheet is a hierarchy, not a list of sections
- [ ] **AM10.2** `v10` The same double-pyramid shape the game's own chart uses
- [ ] **AM10.3** `v10` Every mechanic shows its controls
- [ ] **AM10.4** `v10` Visual examples rather than descriptions of visual examples
- [ ] **AM10.5** `v10` Movement gets real depth: crouch, sprint, slide, vault, wall run
- [ ] **AM10.6** `v10` Hand fighting, weapons and shooting get the same
- [ ] **AM10.7** `v10` It reads as something somebody could learn the game from
- [ ] **AM10.8** `v10` Generated from the checklist so it cannot go stale
- [ ] **AM10.9** `v10` The version ladder is visible and switchable
- [ ] **AM10.10** `v10` It is dark, stylised and unmistakably this game
- [ ] **AM10.11** `v10` It works on a phone
- [ ] **AM10.12** `v10` It can be sent to somebody with no context
- [ ] **AM10.13** `v10` It shows what is done and what is not, honestly
- [ ] **AM10.14** `v10` It is republished whenever the checklist moves
- [ ] **AM10.15** `v10` It and the in-game chart never disagree

## AN — The body is the weapon

Greg, to the playtester: *"i wanna make the hands kinda floppy... idk if you
have played or seen the game halfsword, but the combat with the floppy arms as
swords is so fun — i want to rework that system into something new but keeping
that fun of the movement"*. TaKeS: *"the physics base fighting — like with
shooting, the gun swivels with where you aim, and sorta moves around with the
momentum"*.

**Combat has been reworked four times and the complaint has never changed**,
which usually means the diagnosis was wrong every time. It was. The problem was
never the numbers, the windup, the hitstop or the animation. It is that LMB
*plays a swing*. The player's entire contribution to a blow is the timing of one
keypress, and no amount of tuning a thing you did not perform makes it feel like
you performed it.

The principle worth taking — and it is a principle about authorship, not about
ragdolls, so none of anybody else's code is involved:

> **The blow is something the player performs, not something they request.**

`limb_momentum.gd` is the core and it is built: the weapon is a mass on the end
of an arm, where you point is where the *anchor* goes, and the weapon lags,
overshoots and swings through. `head_speed()` measures how fast the business end
is genuinely travelling; `commitment()` turns that into 0..1. Measured, not
declared. `tests/limb_momentum_test.gd` puts numbers on it: the same weapon and
the same button gives 0.013 for a flick and 0.346 for a committed sweep.

- [x] **AN1.1** The spring-damper core, with mass, reach, fatigue and a real arm limit — `limb_momentum.gd`, ten checks
- [x] **AN1.2** Driven from the same mouse delta the camera turns by, plus the player's own velocity — through a new `apply_look()` seam, because the mouse branch is gated on MOUSE_MODE_CAPTURED which a headless run can never be. A hard turn throws the weapon 0.397m off the anchor, against a 0.42m arm limit
- [x] **AN1.3** The weapon is drawn where the physics put it — `_pose_weapon()` offsets the model off the rig's right arm, so the hand still animates and the weapon lags the hand. 0.155m of travel on a hard turn
- [x] **AN1.4** Damage asks `commitment()` — **live, per Greg, 2026-09-14.** Getting here took three measures and the two failures are the design question. Peak head speed made a one-frame flick worth the same as a committed sweep. Peak of a *smoothed* head speed was no better — a hard sweep spends itself at full extension where the spring fights it, so it measured 2.16 against a gentler swing's 2.52, the wrong way round. What separates a blow from a twitch is **how far the head travelled while moving**, which is work done and multiplies speed by duration instead of discarding one. At a 3.9m reference: a slow look scores 0.00, tracking 0.19, a flick 0.48, a deliberate swing 0.46, a hard committed sweep 1.00. `momentum_damage` in `bone_yard_hunt.gd` is now `true` (see AN1.8/O5.1), so this reference table is what the damage number actually reads rather than a calibration sitting beside it unused
- [x] **AN1.5** Mass and reach per weapon — `ARM_WEIGHTS`: a cleaver 1.45kg at 0.62m, a shotgun 3.2, a sidearm 0.95, a severed limb 2.6, a bare hand 0.4. Re-carried whenever the held thing changes
- [x] **AN1.6** Fatigue comes off stamina directly — a full player reads 0.00 and an empty one 1.00, so the guard degrades continuously rather than switching off at a threshold
- [x] **AN1.7** Firearms run through the same object — the barrel swivels toward where you look and carries past it — like AF1.7, this was already wired rather than unbuilt, and unverified through an equipped weapon rather than untested: `ARM_WEIGHTS` has carried a shotgun and sidearm alongside the sword since AN1.5, and `_carry_current_weapon()`/`_pose_weapon()` read `arsenal.current_id` generically, never branching on melee versus firearm. Every existing momentum test drove `LimbMomentum` in isolation with hand-picked numbers; none of them equipped an actual gun. `tests/firearm_momentum_test.gd` does: equips each of the three weapons in turn through `_equip_weapon`, confirms the arm is re-carried with that weapon's own authored mass and reach, and confirms each weapon's own viewmodel (not just the sword's) visibly displaces off its authored rest pose under an identical turn — with the heavier shotgun lagging further off-anchor than the lighter sidearm, which is the whole point of AN1.5's per-weapon mass and could not happen if the pose write were melee-only. 7 checks.
- [x] **AN1.8** The old swing stayed authoritative, side by side, for exactly
      as long as that comparison was useful — **flipped, Greg, 2026-09-14.**
      `momentum_damage` is `true`: `commitment()` no longer only rides along
      recorded, it is the damage number, gated to melee so firearms are
      untouched (guarded in advance, O5.1 v5). Verified on a real body
      through `tests/arm_wired_test.gd`: an identical weapon aimed
      identically lands 34.47 damage committed and 13.00 as a flick —
      measured on a wound, not read off a flag
- [x] **AN1.9** A grapple, a shove and a bare hand are the same object with a
      different mass — `_carry_current_weapon()` now checks `grapple_target`
      ahead of the weapon and the bare-hand state, since holding somebody
      takes both hands regardless of what is holstered. Two new
      `ARM_WEIGHTS` entries carry it: `grapple` while just holding on,
      `shove` — heavier again, past even the severed limb — while
      `grapple_pushing_now` says the player is forcing their weight into the
      hold rather than maintaining it. Bare hands were already the same
      object (`bare`, N/AN1's own baseline); this closes the other two.
      Verified: `tests/grapple_mass_test.gd` — the arm's real mass changes
      the instant a hold starts, changes again while pushing for advantage,
      and returns to whatever was actually equipped the instant the hold
      breaks.

### AN2 — What it costs to swing
- [x] **AN2.1** A committed blow leaves you open in a way a flick does not
      (pairs with O5 footing) — `FOOTING_COMMITTED_SWING` scales
      `last_commitment` (already measured for AN1.4/AN1.8) straight into
      `lose_footing()`, paid the instant the swing is thrown rather than on
      whether it connects: a flick costs nothing, a fully committed sweep
      costs as much as being shoved (O5's `FOOTING_SHOVED`). Firearms are
      excluded — `arm.commitment()` still measures barrel drift for AN1.7,
      which is not the same thing as being off balance. Verified:
      `tests/footing_test.gd` — a forced full-commitment swing measurably
      costs footing, a zero-commitment one does not, and firing a gun with
      the same forced commitment costs none at all.
- [x] **AN2.2** You can be disarmed, because a weapon you are barely holding
      is a weapon somebody can take — `arm.fatigue` (AN1.6, straight off
      stamina) is already a real "how loosely" number; a hit at or above
      `DISARM_DAMAGE_THRESHOLD` while fatigue is at or above
      `DISARM_FATIGUE_THRESHOLD` calls `_put_the_weapons_down()` for real,
      not a stat penalty. Deterministic on purpose, the same way severing and
      footing already are, rather than a coin flip nobody could learn to
      read. Recoverable mid-fight by drawing again (1-3), which is the
      correct shape until dropped weapons are real world objects (blocked on
      the same gap C1.7 named for the handheld). Excluded: a carried severed
      limb, which already has its own condition/break mechanic. Verified:
      `tests/disarm_test.gd` — a fresh grip survives a hard hit, an exhausted
      one gives the weapon up to a hard hit but not a light one, drawing
      again re-arms, and a carried limb is not double-counted.
- [x] ~~**AN2.3** Hitting armour, bone or a wall answers differently through
      `strike()`~~ Armour and bone closed first; this pass closes the wall.
      `apply_hit()` reports `absorbed`, the real fraction of a blow armour
      and garments just stopped; `_melee_resistance(zone, result)` turns
      that plus a per-zone bone-density base (head firmer than a limb,
      armour raises either) into what `arm.strike()` actually feels,
      replacing a flat `0.65` on every connecting blow. A wall was still not
      a thing a swing could hit at all — `_resolve_strike()` only ever
      recognised "connected with an actor" or "hit nothing," because
      `_attack_nearest_encounter_actor()` has no concept of anything that
      isn't one. `_attack_wall()` is the missing third outcome: a raycast
      along the same look direction the aim already uses, `collide_with_areas`
      held false rather than mirrored from `_trace_actor()`'s own query,
      since AF1.1 already established every zone hitbox in this game is an
      `Area3D` — excluding areas entirely is what keeps a body from ever
      being misread as a wall here. A wall answers at `WALL_MELEE_RESISTANCE`
      (0.85), above every zone in `MELEE_RESISTANCE_BASE` including an
      armoured skull, wears the weapon the same way meeting armour already
      does (AN2.4, at the maximum `absorbed` a wall does not flex or give),
      and leaves the same scar a bullet does — `Ballistics.mark_impact()`,
      a one-line public wrapper around the round's own `_mark()`, since a
      melee swing is not a round in flight and has no `_land()` to route
      through. Verified: `tests/melee_resistance_test.gd` (armour and bone,
      unchanged, still clean) plus new `tests/wall_strike_test.gd` (8
      checks) — a swing thrown at open air still carries through and gains
      speed exactly as a whiff always has, wears nothing, and records
      nothing; the same swing thrown at a real `StaticBody3D` wall is
      measured stopping dead and bouncing back (+4.00 m/s into -2.47 rather
      than whiffing up to +4.48), wears the sword the same swing through
      nothing never did, and records `melee_struck_wall` exactly once.
      `weapon_condition_test`, `disarm_test`, `combat_integration_test`,
      `zone_precision_test`, `ballistics_test` and `opening_test` regression
      suites re-verified clean.
- [x] **AN2.4** The weapon's own condition rides on the same object — a bent
      blade swings wrong — `HunterArsenal.wear_weapon()` (lazy, like `ammo`:
      missing means unworn) takes something off the edge on every connecting
      melee hit, more when the blow's own `absorbed` (AN2.3) says it met
      armour or bone. `_carry_current_weapon()` reads that condition back
      into a real, lower `arm_stiffness` on `LimbMomentum.carry()` — a worn
      weapon is genuinely wobblier through the same arm, not a number on a
      sheet. Bare hands and a carried limb are outside it entirely; the limb
      already had its own wear mechanic. Verified:
      `tests/weapon_condition_test.gd` — a fresh sword starts at full
      condition and stiffness, a connecting hit wears both down immediately,
      the same hit through real plate wears more than the same hit through
      nothing, and throwing a fist does not touch the sword sitting unused.
- [x] ~~**AN2.5** Two-handing changes the numbers, not just the pose~~ Built
      on the earlier diagnosis rather than around it: `held_gear.gd`'s
      `GRIPS` table already carried `reach` and `damage_type` per grip, its
      own header comment naming this exact claim, and nothing outside that
      file ever read either. `hold(grip_name)` — "the verb behind
      half-swording" — was real but never called from the live game, since
      `hunter_arsenal.gd` only ever used `HeldGear.build_weapon()` as a
      one-shot model factory with no persistent instance to change. Rather
      than replace that carefully-tuned mounting code, the numbers are
      wired independently of it: `B` cycles the sword through its three
      real grips (`two_hand → one_hand → half_sword`, the only weapon
      `GRIP_CYCLE` names, since a shotgun and a sidearm each have exactly
      one grip already), and `_carry_current_weapon()` reads the active
      grip's `reach` and a new `control` field — the number the file's own
      comment asked for and nothing had — into `arm.reach` and
      `LimbMomentum`'s stiffness. A swing's own `damage_type` follows the
      same grip, so a half-sworded blow is a real `puncture` reaching
      AN2.3's `strike()` rather than a `cut` that happens to be shorter.
      Equipping a fresh weapon resets to `HeldGear`'s own default grip
      rather than remembering the last stance — holstering is not choosing
      a stance. Verified by `tests/two_handing_test.gd` (new, 11/11):
      cycling moves through all three grips and wraps around; half-sword
      measurably shortens reach (0.384 vs 0.620) and steadies the arm
      (78.30 vs 66.70) against two-handed, itself steadier than one-handed
      (47.56); a weapon with no `GRIP_CYCLE` entry ignores the key outright;
      and a live `_attack()` reports `cut` two-handed and `puncture`
      half-sworded from the identical weapon. Full regression suite
      (vault, wall_run, jump, climb, momentum_carry, anatomy_traversal,
      opening, combat_integration, zone_precision, ballistics,
      firearm_momentum, deferred_damage) re-verified clean


### AN6 — Dismemberment, at the reference standard
Greg: *"we really need to work on the dismemberment and gore and make it more
like RDR2 and Half Sword"*, and *"body destruction — example shooting a hole in
someone's stomach and their organs falling onto the floor"*.

Those two references pull in different directions and both are wanted. **RDR2**
is authored damage: a small number of exact, beautiful wound states, keyed to
the weapon and the angle, that always read correctly. **Half Sword** is
simulated: the mesh genuinely comes apart wherever the edge went, and it is
ugly and specific and never the same twice. The resolution is that the *skeleton
and the organs* are simulated and the *surface* is authored — a hole is a real
opening with real contents behind it, and what the wound looks like at its rim
is art, not noise.
- [ ] **AN6.1** A wound is an opening with depth, not a decal — you can see in
- [ ] **AN6.2** Organs are separate bodies behind that opening and fall out
      under physics when the cavity is breached
- [ ] **AN6.3** Fallen organs persist, can be picked up, and are the same
      objects `carry.gd` and the vat already understand
- [ ] **AN6.4** Severing is at joints and through them — Half Sword's lesson is
      that a cut that lands between two joints still has to do something
- [ ] **AN6.5** Weapon and angle decide the wound shape, RDR2's lesson
- [ ] **AN6.6** The rig survives it — a body missing a torso section is still
      animating, still falling, still a thing that was alive
- [ ] **AN6.7** Written up as instructions: the mesh layout, the rig, and the
      naming a new body has to follow to be destructible (nothing bespoke)
- [ ] **AN6.8** It runs at the frame budget with several bodies opened at once (X)

### AN v10 — the final pass
The last rung. Fifteen statements that are true of the body as the weapon when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] **AN10.1** `v10` The weapon is a mass on the end of an arm — See AN1.1: the spring-damper core, `limb_momentum.gd`, ten checks.
- [x] **AN10.2** `v10` Where you point is where the anchor goes — See AN1.2: `anchor` is a fixed offset in view space, so it turns with the camera by construction; a hard turn throws the weapon 0.397m off it, against a 0.42m arm limit.
- [x] **AN10.3** `v10` Turning throws it, and heavier throws further — See AN1.1/AN1.2: `limb_momentum_test.gd` throws the identical turn at a 0.5kg and a 6.0kg arm and measures the heavier one lagging further off-anchor every time.
- [x] ~~**AN10.4** `v10` Damage asks what the head was actually doing~~
      True as of Greg's own call, 2026-09-14: `momentum_damage` is `true`
      (AN1.4/AN1.8/O5.1 v5), melee-gated so firearms read as they always
      did. Verified on a real body: an identical weapon aimed identically
      lands 34.47 committed against 13.00 as a flick
- [ ] **AN10.5** `v10` A flick and a committed sweep differ by an order of magnitude — **Not verified as stated.** The section's own intro quotes 0.013 vs 0.346 (~27x) but that figure does not reproduce: `limb_momentum_test.gd` currently measures flick 0.000 vs sweep 0.082, and `arm_calibration_test.gd`'s raw travel is 1.86m vs 3.96m (~2.1x) — neither a stale quote nor a live number I can currently reproduce support "an order of magnitude" cleanly enough to tick this without inventing the gap away. Left open rather than resolved on a guess.
- [x] **AN10.6** `v10` Mass and reach are the whole balance conversation — See AN1.5: `ARM_WEIGHTS` carries every weapon's own mass and reach and nothing else changes when the held thing does.
- [x] **AN10.7** `v10` Fatigue degrades the guard rather than announcing it — See AN1.6: fatigue reads straight off stamina into the spring's own stiffness, continuous rather than a threshold flip.
- [x] **AN10.8** `v10` Firearms run through the same object — See AN1.7/`firearm_momentum_test.gd`: the sword, shotgun and sidearm all re-carry `LimbMomentum` with their own mass and reach and all three visibly displace off rest pose under an identical turn.
- [x] **AN10.9** `v10` A grapple, a shove and a bare hand share it — See AN1.9/`grapple_mass_test.gd`: `grapple` and `shove` are real `ARM_WEIGHTS` entries the arm's mass switches to and from live.
- [x] **AN10.10** `v10` You can be disarmed — See AN2.2/`disarm_test.gd`: a hard hit on a fatigued grip genuinely puts the weapon down.
- [x] **AN10.11** `v10` Armour, bone and wall each answer differently — See AN2.3/`melee_resistance_test.gd`/`wall_strike_test.gd`: armour, per-zone bone density and a wall's own `WALL_MELEE_RESISTANCE` each feed `strike()` a different number.
- [x] **AN10.12** `v10` The weapon's condition rides on the same object — See AN2.4/`weapon_condition_test.gd`: a worn weapon reads back into `LimbMomentum` as lower `arm_stiffness`, not a separate stat.
- [x] **AN10.13** `v10` Two-handing changes numbers, not pose — See AN2.5/`two_handing_test.gd`: cycling grip measurably changes reach, control and damage type from the identical weapon.
- [x] **AN10.14** `v10` Walking into a blow counts toward it — `_advance_arm()` has read `player_body.velocity` into `LimbMomentum.advance()`'s `body_velocity` parameter since AN1.2 shipped, with the comment already on the line ("a step forward is real force and the game should not be the only place that is untrue"), but nothing had ever exercised it through the real hunt loop with a moving body: `limb_momentum_test.gd` drives the arm in isolation with a hand-picked vector, `firearm_momentum_test.gd` holds the player still, and `arm_calibration_test.gd`'s one "walking into it" gesture changes the turn rate at the same time it changes body speed, so it cannot show what walking alone is worth. Honestly scoped once measured: `advance()` sums the body's velocity into the weapon's regardless of which way either points, so it cannot tell a charge from a retreat — only that the body moved counts, not specifically that it moved forward. Verified by `tests/walking_into_blow_test.gd` (new, 3/3) through the real `_advance_arm()` the game calls every physics frame: a turn too weak to register as a blow at all on a still body (`commitment() = 0.000`, below `IDLE_SPEED`) becomes a real one (0.033) the instant the identical turn is thrown while the body is moving, and a body moving the other way counts too (0.039). `limb_momentum_test`, `arm_calibration_test`, `firearm_momentum_test`, `footing_test`, `combat_integration_test` and `opening_test` regression suites re-verified clean.
- [ ] **AN10.15** `v10` The old swing system is gone because this one is better

## AO — The world as it fell

`DESIGN/THE_REWORK.md` is the full document. This section is the part of it that
has to become code.

The setting was never written down until now, and the load-bearing fact is
perfect for a game whose central rule is already *two records: what happened, and
what each faction believes*. **The nuclear war is fake.** Greg: *"'nuclear'
unknown testing facilities on site that produce such high levels of radiation,
they have been theorised to have been fake nuclear attacks as no footage exists,
although gore and crisis actors news segments"*. What actually fell it was an
alien apocalypse — *"an attack on the industry and prison planet by a freed
colony, although many theorise its the government still living in the deep tunnel
networks"*.

Earth is an industry and prison planet. Somebody who escaped came back for it.
The official story is a lie told by people still alive underneath the place they
lied about.

### AO1 — The record and the lie
- [ ] **AO1.1** The fake war is in the world as evidence, not as exposition
- [ ] **AO1.2** Both records exist: what the alien apocalypse did, and what was published about it
- [ ] **AO1.3** Radiation is real wherever the testing was, whatever caused it (8g melts you)
- [ ] **AO1.4** Crisis-actor footage is findable, and the game never confirms it
- [ ] **AO1.5** Earth reads as an industry and prison planet in what is standing, not in a log

### AO2 — The sky
- [ ] **AO2.1** The firmament is broken and it is visibly broken
- [ ] **AO2.2** A god for each planet, the moon and the sun, visible at certain hours (W1.1 exists now)
- [ ] **AO2.3** The seals broke at the end of the world: every demon is observable
- [ ] **AO2.4** Every sigil is live again — **and capturable** (pairs with AJ)
- [ ] **AO2.5** Night is genuinely different, not day with a filter

### AO3 — The tunnels
Greg: *"urbex, overgrown, Outlast-esque, covered in blood, gore, horrors, as the
military have gone cannibalistic and blood thirsty with greed of power, slowly
dismantling themselves as you play, as the authority in the game is no help"*.
The detail that makes it: **they are eating themselves on a clock while you
play.**
- [ ] **AO3.1** A connected tunnel layer under the region (shares AL2's network)
- [ ] **AO3.2** Overgrown and urbex rather than clean corridors
- [ ] **AO3.3** The military down there degrades over game time whether or not you are watching
- [ ] **AO3.4** Authority is never help — calling it makes things worse
- [ ] **AO3.5** What is down there is found, not briefed

### AO4 — Who else is out here
- [ ] **AO4.1** Villages, cities and bandit camps fight back aggressively
- [ ] **AO4.2** Areas can be haunted at night, and it is not permanent
- [ ] **AO4.3** Demons, spirits and jinn infest parts of the map and move
- [ ] **AO4.4** Random alien craft doing things that are not for you
- [ ] **AO4.5** Reptilians, greys and other occult races as real factions
- [ ] **AO4.6** Elites have the Wire and the nemesis system; nobody else does

### AO5 — Encounters
AO4.4 was one line. Greg's reference board, 13 September 2026: Apollo surface
frames with the reseau crosses still on them, the Ben Rich *"locked up in black
projects"* quote over a wall of black-triangle photographs, a crop-formation
typology chart, the Zeta Reticuli binary-in-crops pages, a 4chan dead man's
switch about a damaged station orbiting Ganymede — and the same Ganymede claim
again, three images later, as a SpongeBob meme. Source folder is
`C:/Users/Greg/Desktop/UfoFunny`, **read-only, same rule as Art Collections**.
Nine video files in it have not been watched by anybody on this side yet.

The board is one register and the register is not "aliens". **Every item claims
to be an instrument's record.** Reseau crosses on a Hasselblad frame, a patent
number in an address bar, coordinates on an IR survey, 8-bit ASCII laid out in
wheat, a mapping tile, a signal Juno detected on a stated date. Nothing is a
painting; everything is a readout. And what makes each one persuasive is the
same thing every time: **a redaction.** The black rectangle over Virgo, the tile
blacked out by every mapping provider at once, the scrubbed server, the guarded
vault. The missing piece is the evidence.

That is this game's central rule — two records — arriving as an image rather
than a doctrine, and it gives an encounter a shape that is not a cutscene.
- [ ] **AO5.1** A craft is an instrument record, never a set piece — you get a
      readout of it (satellite, handheld, photograph) and never a scripted camera
- [ ] **AO5.2** The redaction is the evidence: what the satellite refuses to
      show you is how you find the place (pairs with AK1.2 and AK10.12)
- [ ] **AO5.3** A dead map — one region blacked out across every source you
      own, and it is a real place you can walk to
- [ ] **AO5.4** Crop formations as a second seal alphabet, drawn at field scale
      in the world and catalogued the way `goetic_seals.gd` catalogues the
      Goetia. E2.1's stroke register already draws this shape language
- [ ] **AO5.5** Craft are photographable with the field camera, and the
      photograph is the thing other people argue with (F, L)
- [ ] **AO5.6** The same event exists twice — as somebody's terrified account
      and as a joke about it — and the game never says which came first
- [ ] **AO5.7** Some of the craft are ours. Black projects, not visitors, and
      nothing in the game ever settles which is which
- [ ] **AO5.8** The footage register is the found kind: grain, a wrong aspect,
      a filename that is already a joke


### AO v10 — the final pass
The last rung. Fifteen statements that are true of the world as it fell when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AO10.1** `v10` The fake war is in the world as evidence, never exposition
- [ ] **AO10.2** `v10` Both records exist and neither is confirmed
- [ ] **AO10.3** `v10` Radiation is real wherever the testing was
- [ ] **AO10.4** `v10` Crisis-actor footage is findable
- [ ] **AO10.5** `v10` Earth reads as an industry and prison planet in what is standing
- [ ] **AO10.6** `v10` The firmament is visibly broken
- [ ] **AO10.7** `v10` A god for each planet, the moon and the sun, at their hours
- [ ] **AO10.8** `v10` Every demon is observable because the seals are gone
- [ ] **AO10.9** `v10` Every sigil is live and capturable
- [ ] **AO10.10** `v10` Night is genuinely different, not day with a filter
- [ ] **AO10.11** `v10` The tunnels are urbex, overgrown, and full of what the military became
- [ ] **AO10.12** `v10` Authority is never help and calling it makes things worse
- [ ] **AO10.13** `v10` Villages, cities and bandit camps fight back aggressively
- [ ] **AO10.14** `v10` Reptilians, greys and other races are real factions
- [ ] **AO10.15** `v10` Only the elites have the Wire, and that is visible

## AP — The captured spirit

Greg: *"you start as a captured spirit in the government facility underground, to
be meat for the elites and scrap"* — and the thing that makes you a problem:
*"they see the essence of his spirit as it can't be banished by torturing,
killing, violence — it stays in pure bright flames that are vibrant and melt
the game's screen... the character's spirit is undying, so the government wants
to enslave you"*.

**You are not powerful, you are unkillable, which is worse for everyone.** That
is a far better premise than a strong protagonist, and it explains why an
institution that could simply shoot you spends the game trying to own you
instead.

### AP1 — The opening, in order
- [ ] **AP1.1** Captured, underground, as meat and scrap — not as a hero
- [ ] **AP1.2** The quiz, and it matters mystically (D already builds the sheet)
- [ ] **AP1.3** Experimented on and tortured, revealed across the game rather than shown at the start
- [ ] **AP1.4** The gore festival: *"genuine slabs of pressed meat"*
- [ ] **AP1.5** The underground tunnel derby — reptilians, aliens, bunker AI dwellers, and you execute them
- [ ] **AP1.6** Out, and choosing what happens to the lands (hands over to AA)
- [ ] **AP1.7** Digestible segment to segment, and a playground if you want it

### AP4 — Starting-facility territory slice

- [x] **AP4.1** The production opening enters the authored underground colosseum, not the old surface quarry — both the Growing Floor door and `OpeningDirector.resume_destination()` now resolve to `underground_colosseum.tscn`; `opening_stage_wiring_test.gd` drives the real transitions (6/6).
- [x] **AP4.2** One persistent authority owns the facility holdings — `facility_territory.gd` stores the Growing Floor, Underground Colosseum, Service Ring and Surface Gate under one WorldHistory subject rather than distributing ownership flags across UI and scenes.
- [x] **AP4.3** Exploration changes only what was actually reached — waking reveals the Growing Floor, entering the pit surveys it, and the three existing colosseum tunnels reveal the Service Ring without falsely liberating either.
- [x] **AP4.4** A real achievement liberates one holding — only `derby_round_won` in the underground venue changes the Colosseum from surveyed to liberated; entry and loss cannot award it.
- [x] **AP4.5** MAP exposes ownership, surveillance, objectives and routes — the Black Mirror's facility sheet draws the four bounded holdings, existing scene adjacency, live owner/state, the next authored objective and approximate CellOutz surveillance from the authority record.
- [x] **AP4.6** The territory sheet is operable with pointer and keyboard — pointing selects a holding, arrow keys move through revealed holdings, and `L` switches between facility holdings and the Ashbloom satellite; verified by `facility_device_integration_test.gd` (8/8 total integration checks, including the corporate acquisition seam).
- [x] **AP4.7** Liberation unlocks trustworthy INDEX knowledge — the Underground Colosseum becomes a selectable recovered FILE record with its live ownership and a floor-plan stamp; place records never fabricate human portraits.
- [x] **AP4.8** CellOutz reacts as the openly evil corporate platform requested — one persistent `REPOSSESSION ORDER 0C-7` circulates against the player as company inventory, appears on the MAP, and cannot duplicate when the win callback repeats.
- [x] **AP4.9** The loop survives persistence and respects quantum restart — `facility_territory_test.gd` proves normal WorldHistory state, a fresh universe returning the pit to corporate control, and quantum branch restore returning liberation, INDEX file, bounty and last approximate target area together (21/21).
- [x] **AP4.10** The whole state change is captured, not inferred — `captures/facility_territory_loop.mp4` is a verified 1280×720 30 FPS H.264/AAC reel showing progressive reveal, liberation, INDEX unlock, corporate response, reset and reload; three accepted PNG evidence frames accompany it. Full contract and honest scope: `DESIGN/FACILITY_TERRITORY_SLICE.md`.

### AP5 — Lockdown Grid liberation

- [x] **AP5.1** The Lockdown Grid exists in the playable world — each of the underground colosseum's three authored tunnel chambers contains one physical CellOutz relay, not a MAP-only objective marker. The old “Service Ring” engineering label survives only in stable save/code identifiers; MAP names the function and says the relays seal the exit.
- [x] **AP5.2** The relays use verbs the derby already teaches — three travelling cab rounds or three qualifying vehicle impacts disable one; a dead relay stops scanning and cannot award duplicate progress.
- [x] **AP5.3** The escape is a compound objective — eight wreckers clear the bowl but leave the heat active until all three relays are dark, so winning combat alone no longer counterfeits territorial liberation.
- [x] **AP5.4** Surveillance is readable from the cab — each live head sweeps a real acquisition cone, and the existing physical instrument cluster carries three relay lamps plus the current scan level instead of adding another permanent corner panel.
- [x] **AP5.5** The world answers the act once — each disabled index persists in `facility_territory`; the third liberates the Lockdown Grid, unseals the surface exit, unlocks its recovered INDEX file and escalates CellOutz's existing order to priority exactly once. `service_ring_relay_test` (7/7) and `service_ring_objective_test` (15/15) cover the target, explanation and integrated objective.
- [x] **AP5.6** The physical loop is recorded, not inferred — `captures/service_ring_liberation.mp4` is a visually inspected 1280×720, 30 FPS, 14.23-second H.264 reel of the real cab firing nine travelling rounds, all three live relay signatures extinguishing, the cab counter advancing and the final liberation state landing.

### AP2 — Undying
- [ ] **AP2.1** The spirit cannot be banished by violence, and the game proves this to you early
- [ ] **AP2.2** Bright vibrant flame that melts the screen itself — a real shader, not an overlay
- [ ] **AP2.3** Being unkillable is a problem for the institution, and they act on it
- [ ] **AP2.4** Elites cannot really die either, which is why the economy has jobs instead of wars
- [ ] **AP2.5** Blood, rust and scrap have joined in alchemy, hiding an element you work out later

### AP3 — Wizard eyes
Greg: *"your spirit kinda just guides you based around blood, the stars, and
guides you through 'wizard eyes'"*, Adventure Time's Ice King as a mechanic.
- [ ] **AP3.1** Usable every so often, not held — it is a glimpse, not a mode
- [ ] **AP3.2** Highlights spirits, ghosts and phantoms that are otherwise not there
- [ ] **AP3.3** Abstract rather than literal, collaged from Greg's own art as textures
- [ ] **AP3.4** What it shows is real and the world acts on it afterwards
- [ ] **AP3.5** The logo becomes the Adventure Time finger symbol, designed as a sigil


### AP v10 — the final pass
The last rung. Fifteen statements that are true of the captured spirit when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AP10.1** `v10` You start captured, underground, as meat and scrap
- [ ] **AP10.2** `v10` The quiz matters mystically
- [ ] **AP10.3** `v10` The torture is revealed across the game rather than shown at the start
- [ ] **AP10.4** `v10` The gore festival is genuine slabs of pressed meat
- [ ] **AP10.5** `v10` The tunnel derby is how you get out
- [ ] **AP10.6** `v10` You choose what happens to the lands afterwards
- [ ] **AP10.7** `v10` The spirit cannot be banished by violence and the game proves it early
- [ ] **AP10.8** `v10` The flame melts the frame, as a shader
- [ ] **AP10.9** `v10` Being unkillable is a problem the institution acts on
- [ ] **AP10.10** `v10` Elites cannot really die either, which is why there are jobs
- [ ] **AP10.11** `v10` Blood, rust and scrap hide an element you work out later
- [ ] **AP10.12** `v10` Wizard eyes are a glimpse, not a mode
- [ ] **AP10.13** `v10` What they show is real and the world acts on it after
- [ ] **AP10.14** `v10` The logo is the finger symbol, designed as a sigil
- [ ] **AP10.15** `v10` Digestible segment to segment, and a playground if you want it

## AQ — The godhead

Greg: *"the one true godhead, being commenting and enslaving us all in its own
lessons and learning, is the fightable true end game boss"*.

The best thing about it is how it arrives. It is not revealed — **it
accumulates**. And it is not evil in the ordinary way: it enslaves *through its
own lessons and learning*, which is one short step from AJ3's modern gods and is
the most interesting possible final boss for a game about institutions.

- [x] **AQ1.1** It taunts you long before it is fightable — `godhead.gd` speaks from 12% visibility, and what it says is chosen by the most recent thing *you* did that it noticed, so it is always commenting on the player rather than on the plot
- [x] **AQ1.2** Visibility builds with what you have done, never on a timer — attention is summed off `WorldHistory` fresh on every read, nothing cached, nothing clocked. Forty melee blows draw 1.6; one god named draws 4.5. Tested: fifty frames of waiting move it by exactly nothing
- [ ] **AQ1.3** It summons you rather than being travelled to — `can_summon()` gates on 150 attention, deliberately above the last visibility stage: being entirely present and being called are not the same event. The summons itself waits on AQ1.4's shadow realms
- [ ] **AQ1.4** The shadow realms of the higher realms: the psychedelic register, earned not given (E6/E8 exist)
- [x] **AQ1.5** It teaches, and the teaching is the trap — every lesson is **true**, and following it genuinely helps. `heed()` is what accepting one costs: it adds directly to attention, so taking good advice is the fastest way to be seen. The trap is stated plainly rather than hidden, and refusing is recorded too, because refusing a true thing over who said it is its own cost
- [ ] **AQ1.6** It is genuinely fightable, and the fight is not a damage race
- [ ] **AQ1.7** Voice acting — Greg: *"voice acting will also be in the game"*
- [ ] **AQ1.8** Siding with it is a real option with a real ending


### AQ v10 — the final pass
The last rung. Fifteen statements that are true of the godhead when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AQ10.1** `v10` It taunts long before it is fightable
- [ ] **AQ10.2** `v10` Visibility builds from what you have done, never a timer
- [ ] **AQ10.3** `v10` It summons you rather than being travelled to
- [ ] **AQ10.4** `v10` The shadow realms are earned, not given
- [ ] **AQ10.5** `v10` It teaches, and the teaching is the trap
- [ ] **AQ10.6** `v10` It is genuinely fightable
- [ ] **AQ10.7** `v10` The fight is not a damage race
- [ ] **AQ10.8** `v10` Everything combat built is present and none of it is enough
- [ ] **AQ10.9** `v10` It has a voice and the voice is acted
- [ ] **AQ10.10** `v10` Siding with it is a real option with a real ending
- [ ] **AQ10.11** `v10` It comments on what you actually did
- [ ] **AQ10.12** `v10` It is an institution, and the satire lands there
- [ ] **AQ10.13** `v10` It knows you across the restart
- [ ] **AQ10.14** `v10` Refusing it is possible and costly
- [ ] **AQ10.15** `v10` It is the only thing in the game that is above the pyramid

## AR — The tree, and the work

Not a morality slider — **a diagram**. Greg: *"it be a big Kabbalah type tree
of life or Nordic tree of life diagram for the different paths, when they occur in
the canon story beats, chapters"*.

This sits beside AI's double pyramid rather than competing with it: **the pyramid
is where power is, the tree is which way you went.** Two charts, one document.

### AR1 — The paths
- [~] **AR1.1** The tree is drawn, real, and charts the paths against canon
      story beats — drawn and real, story beats not yet: `world_index.gd`
      gets a fifth page, TREE, alongside FILE/PYRAMID/WIRE/BODY (appended
      rather than inserted — WIRE and BODY are referenced elsewhere in the
      file by hardcoded index, so a page ahead of them would have silently
      retargeted those jumps). It draws the real Kabbalah tree — ten
      sephiroth plus Da'ath, the tradition's own twenty-two paths between
      them — from a new shared `systems/sephiroth.gd` rather than inventing
      layout numbers inline, specifically so AV1.1's plane ladder (same ten
      sephiroth, per Greg's own note that these are one diagram) can draw
      from the identical file instead of drifting into a second geometry
      that happens to agree. Da'ath sits in the gap, unmapped and touched by
      none of the 22 paths, exactly as AV1.3 and AU1's "Da'ath is the good
      one" both ask. What is honestly *not* built: there is no chapter or
      story-beat system anywhere in this codebase to chart paths against
      (grepped for one; nothing exists) — claiming that half would be
      exactly the overclaiming this project keeps catching itself doing. So
      a path lights from the same real relation/ladder-commitment signals
      the double pyramid already reads (`WireNetScript.INFLUENCE_KINDS`,
      `_strongest_ladder_faction`) rather than from beats that are not
      written, and the page says so in its own footer rather than pretending
      otherwise. Sits beside PYRAMID exactly as designed — "the pyramid is
      where power is, the tree is which way you went. Two charts, one
      document." Verified: `tests/sephiroth_tree_test.gd` (new, headless,
      36/36 — the shared data's own shape: ten sephiroth counted, eleven
      nodes drawn, twenty-two paths, none touching Da'ath, every node inside
      the canvas, every path referencing two real nodes; and
      `_sephirah_reached()`'s real-signal-only rule: Malkuth always lit,
      Keter/Chokmah/Binah/Da'ath never lit regardless of any faction handed
      to them, Tiferet lighting off either ladder's real commitment, a
      leaning sephirah dark with no relation, staying dark for a grudge
      -only INFLUENCE_KINDS count, same rule the pyramid already enforces —
      and lighting for real influence, correctly sharing across every
      sephirah with the same lean). `tests/sephiroth_tree_capture.gd` (new,
      windowed) caught two real out-of-bounds crashes on the new page before
      they shipped — `_draw_rail()` and `_draw_stamp()` both indexed a
      four-entry array by `page`, both now five — and the capture confirms
      the diagram itself: no path crossing where Da'ath's ring sits, labels
      clearing every node, lit/dark reading clearly at a glance. Existing
      `double_pyramid_test`, `index_link_rebuild_test`, `index_wire_glow_test`,
      `link_test`, `opening_test` and `combat_integration_test` regression
      suites re-verified clean against the PAGES array change.
- [ ] **AR1.2** Side with the common CellOutz demon — but only with aura, power or influence
- [ ] **AR1.3** Rebel and outcast from the gods: everything harder, nobody owns you
- [ ] **AR1.4** Live with the low-frequency demons, then side with the elite and reptilian classes
- [ ] **AR1.5** Or turn the demons on God and make them challenge it
- [x] ~~**AR1.6** A path taken shows on the tree, and the tree is where you
      read your own run~~ As real as AR1.1 gets it: `_draw_tree()`'s footer
      prints the same `WorldHistory.tree_descriptor()` the PYRAMID waist
      already reads, and every node's lit/dark state is a live read of
      actual relations, not a static picture — open the same save with
      different standing and a different set of nodes lights. What is not
      yet true is the second half of the sentence this shares with AR1.1:
      a *path* (one of the 22 edges) does not yet correspond to a *choice
      the player made*, because no choice-tracking/chapter system exists to
      have made one against. Retract this if that reading feels premature —
      recorded here because the mechanism (real signal in, real node lit
      out) is genuinely built and tested, not because the sentence is fully
      earned yet.
- [ ] **AR1.7** Paths open at chapters, not at levels

### AR2 — Jobs and contracts
- [ ] **AR2.1** A real economy with jobs, because the elites cannot die and war is pointless
- [ ] **AR2.2** Bounty work for the top angels or the top demons
- [ ] **AR2.3** Targets are whoever is blocking a frequency or an aura — not "bad guys"
- [ ] **AR2.4** Contracts are consumable and cost something, Chainsaw Man style
- [ ] **AR2.5** Consumable progress against bosses and big figures
- [ ] **AR2.6** Work for the bank (AL1) and work for the agency (AK1) are the same market


### AR v10 — the final pass
The last rung. Fifteen statements that are true of the tree and the work when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AR10.1** `v10` The tree is drawn, real, and charts paths against story beats
- [ ] **AR10.2** `v10` Siding with the CellOutz demon needs aura, power or influence
- [ ] **AR10.3** `v10` Rebel and outcast is playable and nobody owns you
- [ ] **AR10.4** `v10` Living with the low-frequency demons opens the elite classes
- [ ] **AR10.5** `v10` Turning the demons on God is a path
- [ ] **AR10.6** `v10` A path taken shows on the tree
- [ ] **AR10.7** `v10` Paths open at chapters, never at levels
- [ ] **AR10.8** `v10` The economy has jobs because the elites cannot die
- [ ] **AR10.9** `v10` Bounty work for the top angels or the top demons
- [ ] **AR10.10** `v10` Targets are whoever blocks a frequency or an aura
- [ ] **AR10.11** `v10` Contracts are consumable and cost something
- [ ] **AR10.12** `v10` Consumable progress against bosses and big figures
- [ ] **AR10.13** `v10` Bank work and agency work are one market
- [ ] **AR10.14** `v10` The tree and the pyramid are one document
- [ ] **AR10.15** `v10` Your route is readable by somebody else

## AT — WETWIRE: the brain, the chip and the index

### AT0 — dimensional ecology and witnessed consequence

Design source: `DESIGN/COSMOLOGY.md` §"Dimensional ecology". The torus-field
reference is a visual language for the game, not a factual claim about physics
or a borrowed religious system.

- [ ] **AT0.1** The same physical location can expose Street, Wire, Field and
      Inverted Lattice readings without becoming four disconnected maps.
- [ ] **AT0.2** Every ambient NPC has a role, home area/schedule, faction,
      relationship edges and a witness memory before it can be used as combat
      population.
- [ ] **AT0.3** Conversation events are recorded against the participants and
      can alter a relationship without changing global karma by themselves.
- [ ] **AT0.4** Reputation is group-specific: faction, race/community and
      household reactions can disagree about the same act.
- [ ] **AT0.5** A neutral killing has a legible local consequence only when
      somebody, some record, or some relationship can actually know about it.
- [ ] **AT0.6** Permanent death raises a compact 3D Samsara wheel with named,
      conflicting in-world verdicts; it never presents a cosmic opinion as fact.
- [ ] **AT0.7** The left-field readout is a torus-field state indicator tied to
      real tree alignment, witness evidence and faction response — not a second
      morality meter.
- [ ] **AT0.8** The Inverted Lattice is original game fiction with its own
      language and rules, not an assertion about a living religious tradition.

`DESIGN/THE_BRAIN.md` is the document. Greg's substance and dimension design
arrived as four things that are **one system**: a brain you open, a chip somebody
put in it, the materia, and the planes it reaches.

**You do not get to the planes except through the brain. You do not get through
the brain without the chip. The chip is in your head because somebody put it
there while you were captured (AP1.3).** The drugs are the only thing you can
reach without permission, which is exactly why the institution cares about them.

Naming: **WETWIRE** is the system, **MATERIA** the index inside it — two
institutions naming the same object differently, which is already this game's
central rule.

`systems/brain_index.gd` (`BrainIndex`) is the logic half of this section, held
by `tests/brain_index_test.gd` at 72 checks. The render half — the organ, the
curved CRT, the wet — is untouched and its three boxes stay open below, honestly.

- [ ] **AT1.1** The brain is a real organ at full detail, not an icon
      — **not attempted.** `BaselineHuman` already has a `brain` organ in the
      `head` zone with health, bleed and a `fatal` flag, and `brain_index.gd`
      doses *that* organ rather than a new one, so the data this item needs is
      in place and pointed at. But nothing models it at "full detail" and
      nobody has looked at a brain in this build. Ticking it would be a claim
      about a mesh that does not exist.
- [x] ~~**AT1.2** A CRT bent into the cortex, curved, showing the inside from
      inside~~ `PartViewer` now builds an eleven-segment convex phosphor mesh
      between the brain hemispheres, with cortex continuing behind it and two
      tissue lips overlapping its side rails; turning the existing live
      specimen exposes the bend rather than rotating a flat UI card. Its
      emissive texture is a nested viewport driven by `BrainIndex.listing()`,
      `folder_counts()` and `reach()`, and the inspected 1280×720 capture
      `captures/at1_2_curved_cortex_crt.png` visibly reads
      `CORTEX:/TRAUMA`, `REACH 04D`, and two `[SEALED]` rows from inside the
      organ. `brain_crt_test.gd` holds the geometry at 24 vertices, checks the
      centre bows more than 0.01 units beyond its edges, proves the material is
      fed by a live `ViewportTexture`, and proves the display leaves when the
      specimen changes away from brain. This does **not** claim AT1.1's
      full-detail organ or AT1.4's bloody implant; both remain open.
- [x] ~~**AT1.3** It is an index you open and most of what is in it is
      optional~~ The mind is a filesystem: `BrainIndex.FOLDERS` is fourteen
      real regions (MEMORY, PASSWORDS, COMBAT, PEOPLE, PLACES, DREAMS,
      MATERIA, ENTITIES, TRAUMA, SKILLS, RITUALS, LANGUAGES, ARCHIVED SELVES,
      UNKNOWN) and `ENTRIES` twenty-two files inside them. "Most of it is
      optional" is measured rather than asserted — `optional_ratio()` returns
      0.86 and the test holds it above 0.8; exactly three entries are not
      optional and they are the three the game cannot run without (who you
      are, what is in your head, that you bleed).
      **The part that makes it a mechanic rather than a skill tree:** an entry
      is sealed behind a *keyword*, and `unlock()` refuses any keyword the
      subject has no lived evidence for. Evidence is counted by reading
      `WorldHistory.events` — the same "draw the conclusion from the log"
      shape `ascent_entities.gd`'s `regard()` uses — so the fourteen keywords
      are earned by things that already happen elsewhere in the game:
      `player_captured` opens RESTRAINT, three `npc_resolution`/`spare` opens
      MERCY, `substance_taken` on a given `substance_id` opens that drug's
      entry, `ritual_completed` opens SEAL, `player_redecanted` opens
      REDECANT. An NPC can say the word at you and it opens nothing: the
      refusal reads "YOU KNOW THE WORD. YOU DO NOT KNOW WHAT IT MEANS YET."
      That is remembering, not buying, stated as a refusal. Unlocking a
      keyword opens *every* entry under it at once, because remembering is not
      one file, it is the whole afternoon. Sealed entries are still **listed**
      (as `[SEALED]`), which is the difference between an index and an
      inventory. Two keywords — `DA'ATH` and `THE NINTH BODY` — have no rule
      at all and can never be opened by any play; they are the UNKNOWN folder,
      and the test asserts no amount of history produces evidence for them.
      *Still open:* nothing draws this yet (AT1.2), the twenty-two entries are
      a first pass rather than a full write, and nothing in the shipping game
      calls `unlock()` from a real interaction yet.
- [ ] **AT1.4** Visceral: it is wet, the chip is bolted into wet tissue, and looking at it is uncomfortable
      — **not attempted, and deliberately not half-ticked.** The chip is now
      genuinely *in tissue* rather than being a flag: `install_chip()` appends
      a real `wetwire chip` implant (new `implant_catalog.gd` entry, `head`
      zone, `armor: 0.0` because it protects nothing) to the same
      `anatomy_state.cybernetics` list every other implant is on, so the body
      panels find it and pulling it is the same operation as pulling anything
      else. But "wet" and "uncomfortable to look at" are claims about a
      render, and nobody has looked at it. Open.
- [x] ~~**AT1.5** The tower in it — the bloody wired chip — is the bridge to
      the network above~~ Stated as a number rather than a sentence.
      `BrainIndex.PLANES` is the full ladder from `DESIGN/THE_BRAIN.md` §3
      (Malkuth 3D through Keter 12D, Da'ath off the map), `FREE_PLANE = 4`,
      and `bridge()` is the **only** door to a plane above it. Without the
      chip, 5D and up refuse with "NOTHING IN YOUR HEAD TO REACH WITH"; 4D —
      the wizard eyes — opens for anybody and records `via_chip: false`, which
      is the design's "the only higher plane you see for free" made
      mechanical. `reach()` returns 4 unwired and 12 wired, and entries
      carry a `plane` floor, so the ENTITIES entry at Tiferet and the
      LANGUAGES entry at Hod are unreadable without the bridge even after
      their keyword has been remembered — the memory is yours, the altitude
      is the chip's. *Still open:* the substances are not yet what raises you
      to a plane (§5b's "altitude is the gate" — `bridge()` currently takes
      the plane as a parameter and trusts its caller), and nothing above 8D
      has content behind it.
- [ ] **AT1.6** The Wire seen from 5D is what that network is
      — **half built, and half is not a tick.** `wire_from_above()` exists and
      is tested: it gates on `bridge(5)`, then reaches for the *same*
      `WireNet` accounts the ground-level Wire already has and re-ranks them
      by `WorldHistory.tree_alignment()` instead of by reach. That is the
      structurally correct reading of "the Wire seen from 5D *is* that
      network" — no second dataset, the same people ordered by what they are
      rather than by how loud they are — and with the chip revoked there is no
      view from above at all. What is missing is the whole point of the item:
      "the posts are being made by something else". That is writing and a
      shader, and until the feed reads differently up there this is a re-sort,
      not a plane. Left open.
- [x] ~~**AT1.7** It is hardware somebody else installed: revocable,
      traceable, and it can find you~~ All three, mechanically, in
      `brain_index.gd`. **Somebody else's:** `install_chip()` takes an
      `owner_faction` (default `celloutz`) and an installer, records
      `wetwire_installed`, and refuses to install twice — AP1.3's "while you
      were captured" has an owner attached to it now. **Revocable:**
      `revoke(reason)` is the owner's call, drops `reach()` to 4, and shuts
      every plane-gated entry with *their* reason quoted back at you
      ("REVOKED: UNPAID SUBSCRIPTION") rather than a generic failure. The
      distinction the test pins hardest: revocation does **not** touch
      `wetwire_opened` — the memories are yours and the network is theirs, and
      ground-level entries still read with the chip dead. **Traceable:**
      `trace_level()` is not a counter on the subject, it is derived by
      counting `wetwire_bridged` events with `via_chip: true` since the last
      `wetwire_went_dark`, so the trail is read off the log like everything
      else here and 4D leaves none. **It can find you:** at `TRACE_FIX = 5`
      crossings `locate()` returns the real place of your last crossing with a
      confidence and records `wetwire_traced`, so whoever the owner sends is
      reacting to a recorded event rather than to a flag. `go_dark()` is the
      only counter and it costs exactly the thing it protects — dark, the
      bridge is shut ("YOU CANNOT HIDE FROM IT AND USE IT") and reach falls to
      4. *Still open:* nothing yet *consumes* `wetwire_traced` — no spawner
      sends anybody to the fix, and no faction logic decides to revoke. The
      state and its consequences exist; the antagonist reading them does not.
- [x] ~~**AT1.8** Its radiation is what melts you at 8g and 9g — the thing
      connecting you is killing you~~ Charged in the same call that grants the
      plane, so it cannot be forgotten. `bridge()` at plane 8 or above pays
      `RADIATION_DOSE_PER_SECOND` into `anatomy_state.dose["head"]` — **the
      existing melting ledger**, not a new one: B3's `AnatomyComponent`
      already burns `dose` against zone health and every organ in that zone,
      and the only organ in `head` is `brain`. So the connection literally
      eats the organ the index lives in, and it keeps eating after you come
      down, which is what made writing it as dose rather than flat damage the
      right call. 9g melts faster than 8g for the same seconds (2.4/s against
      0.9/s, asserted), 7D and below cost nothing at all (asserted — the
      melting starts at 8g exactly), and each dose is recorded as
      `wetwire_radiation` rather than as a wound, because it is weather, not
      an attack. Ties AO1.3 to AT: the towers melt you and the tower in your
      head is one of them. *Still open:* no readout tells the player the
      number before they cross, and there is no treatment for a dosed head.

### AT2 — The brain is the file system
Greg: *"the inventory system with the brain that's a file system of the entire
game's info index with drug experiences and other stuff like story quests
tutorial game info within the files"*.

This collapses four things nobody had a home for — inventory, codex, quest log,
tutorial — into the organ AT1 already says you open. There is no menu because
the brain is the menu, and WETWIRE/MATERIA is already the naming for exactly
this (two institutions, one index).
- [ ] **AT2.1** Inventory is read from the brain, not from a separate bag screen
- [ ] **AT2.2** Story, canon and quests are files in the same index
- [ ] **AT2.3** The tutorial lives in there as recallable files, not as a
      first-run overlay you can never see again
- [ ] **AT2.4** Every drug experience files itself as a record you can reopen
- [ ] **AT2.5** Most of it is optional and the index says so (AT1.3)
- [ ] **AT2.6** What the chip put there is distinguishable from what you put
      there — and you cannot delete the chip's files (AT1.7)

### AT3 — The viewer: the orb, the CRT, and detective mode
Greg: *"visual nodes of the brain neural networks visualised in TouchDesigner 3D
visuals with a CRT TV or node or circular orb magician's orb showing the
example"* — and the thing it shows is *"no matter if it's like a cutscene
storage and/or visual tutorial demonstration with controls and/or if it's the
story and canon pinboard theory showing and highlighting the key elements from
the cutscene playing it back in your head in a detective style mode"*.

One object plays back everything. That is the item here, and it is worth more
than any of the three uses on their own: a cutscene, a control tutorial and a
piece of evidence all arrive through the same glass, so remembering, learning
and theorising are the same verb. `crystal_ball.gd` already exists and is the
obvious body for it.
- [ ] **AT3.1** A single viewer object in the brain — orb or CRT, chosen once
- [ ] **AT3.2** It plays cutscenes back rather than the game taking the camera
- [ ] **AT3.3** It plays control tutorials, with the inputs shown on it
- [ ] **AT3.4** It plays evidence, and highlights the key elements in frame
- [ ] **AT3.5** Detective mode: scrub a remembered scene and pull elements out
      of it onto the Board (L)
- [ ] **AT3.6** The index around it is a node graph of the neural net, not a
      list — nodes and edges you move through
- [ ] **AT3.7** TouchDesigner authors the node visuals, Godot renders them
      (FINAL_V §16 — TD is the lab, never the runtime)

## AU — The materia

Every category, because Greg asked for every category: legal stimulants through
to the deliriants, with new-world substances that only exist after the collapse.

**The boundary, stated once and never again:** this portrays experiences,
entities, consequences and costs — the register of a trip report, which is
what Erowid and PsychonautWiki are *as writing*. It carries no dosages, routes,
preparation or combinations. That line costs nothing: nobody ever found a trip
report less frightening for omitting the milligrams, and the horror of datura is
entirely in the account.

- [ ] **AU1.1** Every class present: stimulant, cannabinoid, psychedelic, dissociative, deliriant, empathogen, depressant, opioid, research chemical, new-world
- [x] ~~**AU1.2** A drug is an object — a baggie, a blister, a tab, a weight
      — carried, priced, stealable~~ `substances.gd`'s three entries each
      name a real physical `form` now (`marrow_dust` a baggie, `choir_bloom`
      a weight, `static_hymn` a tab), which `carry.gd`'s `take_substance()`
      reads into the item's own label — "MARROW DUST (BAGGIE)", not a
      generic "substance". Choir of Marrow prices it: a new `substance: 1.2`
      entry in `FACTION_APPETITES`, above the neutral baseline every unlisted
      buyer gets, on top of the anatomy trade it already specialises in.
      Stealable: `Carry.take_from_subject()` reads a subject's own
      `carried_substance` field (the same shape `wounds`/`anatomy` already
      live in), transfers it marked `stolen` — B5.6's existing heat discount
      applies to it exactly as it does to a robbed organ, no second rule
      invented for drugs — and clears the subject's copy so it cannot be
      lifted twice, and it is wired into the real robbery verb rather than
      sitting unreachable: `_nearest_robbable()` now counts a body with only
      a pocket worth taking as robbable even when it has nothing worth
      cutting open, and `_begin_extraction()` (the same `E` a player already
      knows) takes the pocket in one instant motion before whatever the
      body's actual anatomy might also be worth digging for — no second key
      to discover, per C2.7 v3's own lesson. Genuinely witnessed through
      `WitnessLedger.witnesses_of()`, the same static helper the anatomy dig
      itself is built on. Verified: `tests/substance_object_test.gd` (new,
      11/11) and `tests/pocket_search_test.gd` (new, 13/13 — a pocket-only
      body is robbable and yields its item in one motion with no dig
      session, a second press correctly falls through to a real anatomy dig
      once the pocket is empty, and a body carrying both gives up the
      pocket first), plus the existing `combat_integration_test.gd` and
      `opening_test.gd` regression suites.
- [x] ~~**AU1.3** Strains differ. Two mushrooms are not one item with a
      number~~ `Substances.roll_strain(substance_id, seed_value)` names a
      real strain (four flavoured names per substance — `marrow_dust`'s cut
      of bone, `choir_bloom`'s bloom stage, `static_hymn`'s station) and
      rolls a real potency (0.7–1.3), deterministic from the seed the same
      way `seal_strokes()` (E2.1) is — the same pickup always rolls the
      same strain if asked twice, and a different pickup does not.
      `carry.gd`'s `take_substance()` seeds it off `WorldHistory.next_sequence`
      and prints it into the item's own label ("MARROW DUST — FEMUR CUT
      (BAGGIE)"), so two of the same drug in the bag read as two different
      things rather than a stack with a number. `Substances.take()` takes an
      optional `potency` now and scales what the dose actually does by it —
      the catalogue price is what buying an unlabelled batch always costs;
      potency is what you actually got for it. Verified: `tests/strain_test.gd`
      (new, 8/8), plus the existing `substances_test.gd`,
      `substance_object_test.gd` and `lacing_test.gd` regression suites.
- [ ] **AU1.4** Everything costs: body, standing, time, and the godhead's attention
- [ ] **AU1.5** Tolerance and comedown are tracked on the real clock
- [ ] **AU1.6** Set and setting: the same substance in a safe room and in a tunnel are different experiences
- [ ] **AU1.7** Deliriants are horror and must never read as fun
- [ ] **AU1.8** Smoking is a real act: cigarettes, vapes, joints, spliffs, blunts, bongs, alien devices
- [ ] **AU1.9** Caffeine is in the same system as everything else
- [ ] **AU1.10** You can lace somebody, the world records it, and the law
      and the gods respond (AE1.4, AJ5) — three of four clauses are real:
      new `Substances.lace(actor_id, target_id, substance_id, witness_ledger,
      witness_ids)` applies the dose to the *target*, not the actor — no
      `Boons._pay()`, because a non-consensual dose does not get to refuse
      itself under a safety floor, and the actor gets no boon and no glimpse
      credited to them, so this is not `take()` under another name. It is
      genuinely witnessed through the exact `WitnessLedger` object
      `Extraction.notice()` already takes as a parameter rather than
      assuming a global, and every god actually asked gives its own real,
      separately-recorded verdict (`lacing_verdict` events, mirroring
      `ModernGods.record_death_verdicts()`'s own "never summed into one
      score" rule) rather than the game merely logging that a drugging
      happened. What is still missing is AE1.4 itself: no law/enforcement
      system exists yet to read what `witness_ledger.gd` decided was seen
      and respond to it — this is only waiting on that system, the same as
      AS1.5 waits on AE1.1. Verified: `tests/lacing_test.gd` (new, 9/9),
      plus the existing `modern_gods_test.gd`, `substances_test.gd` and
      `substance_object_test.gd` regression suites.
- [ ] **AU1.11** Research chemicals as easter eggs, from the real long tail
- [ ] **AU1.12** New-world drugs made of what is left

### AU3 — The garage
Greg, 13 September 2026: *"in the gore box it can be the place where there is
every drug experimentation there, you're in a dingy not open garage or shed with
drugs setup as well as people you can kill and reset"*.

The gore sandbox stops being a dev scene and becomes a place. That is the whole
move: it already has bodies, a reset, and the psychedelic rig wired to it, so it
is the cheapest room in the game to make real — and a shed you took something in
is a better tutorial for what a substance does than any readout of it.
- [x] **AU3.1** A shed, not a void — enclosed, dingy, lit by what is in it —
      `systems/shed.gd`, 3.2m by 2.4m, which is a real shed rather than a room
      pretending to be one: you can touch both walls, and that is doing more
      work than any texture, because the reason a shed feels like a shed is that
      it is too small for what is in it. Corrugated sheets at the metric a real
      one comes in (0.76m wide, 76mm corrugation), every panel nudged a degree
      or two off true, studs behind, a roof with a fall on it, and a door
      standing open because it always is. **One bulb on a flex is the entire
      lighting design** and the only emitter in the file — which is the point of
      putting the drugs somewhere enclosed: a carried lamp (AS) and a lit
      cigarette (AU7.5) are the only other light that will ever be in here, so
      you choose between seeing and having a free hand. Deterministic from a
      seed, the same guarantee `roll_strain()` makes, because a room that
      re-rolls its own dents on every load is a room nobody can learn.
      Verified from inside at eye height, not from outside the box
      (`tests/shed_capture.tscn`, three frames looked at)
- [x] **AU3.2a** The objects themselves exist — all four carried forms
      (baggie, weight, blotter tab, blister card) and the shed's own kit
      (rolling tray, grinder, lighter, ashtray, scales), procedural at real
      scale in `systems/substance_objects.gd`. AU1.2 has been ticked since the
      data carried a `form` per pickup, but a baggie of Marrow Dust and a
      pressed weight of Choir Bloom were the same invisible nothing in the bag,
      which is the failure that line was written against. The contents colour
      comes from the substance and everything else comes from the form, so two
      substances in baggies still read as two different baggies
      (`tests/substance_objects_capture.tscn`, three sheets looked at)
- [ ] **AU3.2** Every substance in AU is physically set out in the room and
      takeable, not chosen from a list
- [ ] **AU3.3** The bodies stay killable and the reset stays instant — this is
      where you learn what a thing does, so it has to be repeatable
- [ ] **AU3.4** Taking something here drives `psychedelic_rig.gd` through the
      same dials the game uses, never a separate demo path
- [x] **AU3.5** It doubles as the weapons range (AF) — same room, same bodies.
      The gore sandbox drops a `SubstanceStation`, so the room that already has
      seven bodies and an instant reset now also has every substance and every
      smokeable in it
- [x] **AU3.6** Reachable in the real world, not only from a dev menu — the Hunt
      Grounds drop the same station under the wrecks, and lifting something off
      it files through the identical `WorldHistory` inventory path a loot cache
      already uses
- [x] **AU3.7** Three places, one object — `systems/substance_station.gd`. The
      shed, the sandbox and the Hunt Grounds do not lay their own tables out;
      each drops the same node, so **if a substance is reachable in the sandbox
      it is reachable in the Hunt Grounds, because it is the same object.**
      There is no sandbox-only path to keep in step. `manifest_ids()` is the
      single answer to "what is available", and a test asserts two independently
      built stations expose an identical set, and that the shed's bench matches
      (`tests/substance_station_test.gd`, 20 checks)
- [ ] **AU3.8** The station has no collision — the table, the bong and the kit
      are meshes with no bodies, so you walk through all of it. Cheap to add and
      deliberately not guessed at here: this project's collision layers are a
      convention I should be told rather than infer, and a body on the wrong
      layer stops bullets or confuses `ashbloom_pathfinder.gd`

### AU4 — What a state actually looks like
The rig can reach eleven named states and nothing in the game names them.
`tests/psy_reel_capture.gd` photographs all eleven; `tools/psy_dials.py` drives
them live over OSC with no TouchDesigner install.
- [ ] **AU4.1** Each substance maps to a curve through those states over time,
      not to one fixed dial set
- [ ] **AU4.2** Come-up, peak, trails, come-down are phases with durations
- [ ] **AU4.3** A bad trip is reachable and is not just "more"
- [ ] **AU4.4** Feedback is clamped so a deep trail reads as a trail rather
      than converging on flat grey (see the note in `psy_reel_capture.gd`)
- [ ] **AU4.5** Tolerance and repeat use move the curve, the way E4.3 moves a
      rite's price



### AU7 — Smoking is a real act
AU1.8 named the devices and nothing built them. Greg, 13 September 2026: *"make
a cigarette vape model then a bong and spliff joint all smokeable that you can
click or press a bind to satisfyingly hit and get an observable buzz"*.

The obvious implementation is the wrong one. `use_item()` that subtracts a
charge and adds a buff is not an act, it is a transaction with an animation in
front of it. What makes smoking feel like anything is that **you hold it**, and
holding longer is both better and worse - so the input is press-and-hold, the
output is a curve with a sweet spot you can overshoot, and each device puts that
spot somewhere different. That single number is the whole difference between the
objects: a cigarette is nearly impossible to get wrong, a bong nearly impossible
to get right.
- [x] **AU7.1** Five objects built from primitives at real scale - cigarette
      84mm, vape, spliff 98mm, joint, bong 300mm (`systems/smokeables.gd`)
- [x] **AU7.2** A draw is press-and-hold with a weak / clean / harsh grade, and
      the punishment is reserved for greed - a short draw is thin, never
      punished (`tests/smokeables_test.gd`, 47 checks)
- [x] **AU7.3** Harshness is paid into the live lung organs in `anatomy_state`
      where every other body cost is paid, never into a private cough counter.
      A draw raises a contextual top-left lung X-ray; smoke visibly fills and
      clears, harsh draws cough, and repeated use leaves a dark `smoke_stain`
      that survives save/restore until replacement lungs clear it
      (`tests/smoking_lung_ui_test.tscn`, `tests/smoking_act_test.tscn`). The
      quick diagnostic now eases its fill, clearing, cough compression, tissue
      darkness and replacement flash across layered depth shells and a visible
      bronchial tree; its public values remain the exact anatomy reading rather
      than presentation-delayed gameplay state
- [x] **AU7.4** The buzz is a real short dose on `substance_experience.gd`'s own
      curve, so smoked and swallowed cannot drift into two systems
- [x] **AU7.5** Lit ends are real `OmniLight3D`s, so a cigarette in the dark is
      a light source and gives you away (pairs with AS). The original sub-metre
      prop light made night captures unreadable; a resting coal now casts a
      close amber pool, a held draw reaches roughly six metres, and the Zippo
      reaches farther while its lid is open. These remain warm omni lights,
      never white flashlight beams. Ember, bong bowl, Zippo and close inspection
      light are exposure-aware: their cast energy and reach recede sharply in
      clear daylight, return through dusk/night, and regain some usefulness
      beneath a severe magick storm rather than bleaching daytime hands or
      throwing hard noon shadows (`tests/smokeables_test.gd`,
      `tests/smoking_act_test.gd`)
- [x] **AU7.6** The bind: press-and-hold, with the hold readable **while** it
      happens. I0 settled where: *no screen is a list of text in a box*, and the
      derby's lesson was that the arena is the interface — so the gauge is the
      object. `set_draw(node, heat)` runs the cherry up the paper: the coal
      brightens, the ash collar grows, and the light it throws grows with it.
      Past the sweet spot it stops getting brighter and **goes whiter**, which
      is a different signal rather than more of the same one, and it is what
      warns you before the cough does. Nothing is drawn on screen, so it reads
      the same in first person, over a shoulder, and in somebody else's hands
      across the room. `bone_yard_hunt.gd` now binds the real held act to RMB:
      the live HUD counts the pull toward its authored sweet spot, release lands
      the weak / clean / harsh result, and weapon input cannot fire through it
      (`tests/smoking_act_test.gd`)
- [x] **AU7.7** Release automatically exhales from the player's actual mouth
      into `contaminated_air.gd`: two crossed, low-alpha layers make long wisps
      rise, tumble, spread and fade without resolving as bright circular beads
      or accepting the close Zippo as a daylight floodlight. The fresh breath
      stays playable for a short window;
      LMB cycles an expanding O, double O and ghost whose particle edges fray
      as they travel (`tests/smoking_act_test.gd`, `smoking_gameplay_capture`)
- [x] **AU7.8** Charges burn down visibly — a cigarette gets shorter, a bong
      bowl goes to ash and sinks, a vape's tank window drops. `spend_per_hit()`
      is derived from the charge count the catalogue already carries rather than
      being a second number to keep in agreement with it, and it never burns to
      nothing: you stub it out with a finger of paper left, which is also what
      stops the coal reaching the filter and the geometry inverting. Tested
      monotonic across nine steps, because a thing that got *longer* partway
      through is a bug nobody would think to look for. Rolled ash now grows on
      the resting consumed object, the ember pulses subtly with breathing, and
      each third draw produces a deterministic wrist flick with falling ash
- [x] **AU7.9** Every smokeable is held through `held_gear.gd`'s public anchor
      convention on the body's real right arm. The draw raises that arm to the
      mouth; the bong has a second physical grip and support hand, recruits the
      left-arm pose, and hides the whole weapon set while held
      (`tests/smokeables_test.gd`, `tests/smoking_act_test.gd`). Cigarettes,
      joints and spliffs use a distinct open-palm, long splayed-finger grip so
      the item stays visible between the fingers instead of being swallowed by
      a fist; the jester sleeves and arms still enter from authored lower-frame
      points appropriate to the object instead of every wrist growing from one
      generic corner. The same anatomy pass now reaches firearms and carried
      limbs: weapon palms are seated per grip, and an improvised severed limb is
      visibly clenched by a costumed articulated hand with a continuous arm.
      Holding I is one verb with class-specific physical readings rather than a
      copied turntable motion: rolled paper exposes seam/ember, a vape presents
      its cell face, a bong tips bowl/chamber, a sword presents its edge, the
      shotgun support hand checks the forend/receiver, a pistol support hand
      pinches the slide, and a severed limb is hefted under dead weight. A short
      warm inspection glint makes those contacts legible at night without
      becoming a navigational flashlight (`tests/smoking_act_test.gd`,
      `tests/combat_integration_test.gd`, `tests/smoking_gameplay_capture.gd`).
      Y also transfers any one-hand smokeable from fingers to a persistent lip
      point beneath the reticle through the object's real mouth anchor: the hand
      carries it on a shallow arc, the item settles with the player's breathing,
      releases and leaves the frame; RMB still draws hands-free, and Y reverses
      the transfer. The bong explicitly refuses because its weight and cone-sink
      require both hands. A draw's dose, tolerance, anatomy, consumed charge and
      history still emit their normal events/signals, but `WorldHistory` batches
      their persistence into one disk flush. `player_action_ledger.gd` is now
      the single receipt route for hit, resolved draw, cough, exhale, trick,
      mouth transfer, completed consumption and held-item inspection: it keeps
      every existing event name for current consumers, adds one monotonic action
      id, maintains cheap per-kind counts and coalesces its summary plus event
      into one save. Nested draw transactions still flush only at their outer
      commit (`player_action_ledger_test`, 8/8; `smoking_act_test` exercises all
      eight live routes). The promised complete use-and-inspect reel is now
      rendered at `captures/full_use_inspection_demo.mp4`: 1280×720, 30 FPS,
      59.15 seconds, H.264/AAC with live game audio. Its nine labelled chapters
      drive the production Hunt through cigarette, vape, joint, spliff, bong,
      sword, shotgun, sidearm and carried-limb use followed by each distinct
      inspection; a 6-second contact sheet was visually checked across the reel
- [ ] **AU7.10** Passing one to somebody is a real act with a real meaning (S)

### AU5 — The effect taxonomy
Greg: *"use erowid and drug wiki to make accurate models and usage of each drug
and read forums and indexes on the effects to individually visualise each
drug"*.

The rig has twelve dials and they are all *operations* — kaleidoscope, feedback,
chromatic, cut. None of them is an *effect* anybody actually reports. That is
the gap: you cannot author a substance out of "kaleidoscope 6" any more than you
can paint a face out of "brush 4". `contact_entities.gd`'s `CHANNELS` is the
first pass at the real vocabulary — drift, tracer, symmetry, recursion, acuity,
depth, colour, cut, autonomy — and each one needs to become something the rig
can do rather than something a comment describes.

⚠ Scope, so nobody has to guess later: this is perceptual grammar for a
renderer, used the way a painter uses anatomy. The substances are this world's
inventions. Nothing here is a description of obtaining or taking anything real,
and no checklist item below should become one.
- [ ] **AU5.1** Drift — surfaces breathe, flow and morph without changing what
      they are. The rig has no such operation; displacement is not it
- [ ] **AU5.2** Acuity — detail sharpens past what the eye resolves, which is
      the effect most often described and the one nothing in the pipeline does
- [ ] **AU5.3** Recursion — a shape containing a smaller copy of itself, as
      geometry rather than as a feedback artefact
- [ ] **AU5.4** Depth — distance stops agreeing with size, per object
- [ ] **AU5.5** Colour rotation independent of what is lit
- [ ] **AU5.6** Each channel is a dial on `psychedelic_rig.gd` with a name a
      person would use, so a substance is authored in effects, not in operations
- [ ] **AU5.7** A sourced pass: the per-substance channel mix checked against
      the documented phenomenology rather than written from memory
- [ ] **AU5.8** TouchDesigner authors each channel and Godot renders it —
      FINAL_V §16 stands, TD is the lab and never the runtime
- [ ] **AU5.9** `tools/psy_dials.py` grows a channel mode so the lab is driven
      in the same vocabulary the game authors in

### AU6 — Contact
Greg: *"with entities in some drugs make appear and catalog it so we can start
storyboarding higher dimension entities like dmt baphomet jesters or just dmt
elves"*.

AT already says the drugs are the only door you can reach without permission,
and until now that door opened onto an org chart — `_glimpse_one()` returned a
random `AscentEntities` id, which are the wizardsonlyfoolz lower ranks.
`contact_entities.gd` is the encounter instead: five entries, each with `form`,
`does`, `regard`, `leaves` and a `storyboard` note, because "an indescribable
presence" is not something anybody can draw.

The rule that governs the whole catalogue: **nothing here has a quest.** An
entity that hands out objectives is a vendor in a costume. The strongest entry
is the one that proves it — the Carrier Choir has not noticed you and never
will, which is what makes autonomy and attention two different things.
- [x] **AU6.1** A catalogue that survives being drawn — five entities, every
      one with a concrete form, an action, a regard, and what it leaves behind
      (`systems/contact_entities.gd`, `tests/contact_entities_test.gd`, 40 checks)
- [x] **AU6.2** Contact is earned, never bought: a weak dose reaches nobody, and
      tolerance closes the door the way it flattens the curve (AU4.5)
- [x] **AU6.3** Deterministic per subject, substance and dose count, so a save
      is reproducible and a storyboard can be re-derived
- [ ] **AU6.4** The Horned Auditor reads the player's real `world_history.gd`
      entry and holds a finger on it — the payload is a fact about this run
- [ ] **AU6.5** The Carrier Choir's frequency reaches `wire_radio.gd`, making it
      the only contact with a consequence outside the trip (Lane 4 owns it)
- [ ] **AU6.6** The One In The Marrow moves the player's own hands a half beat
      early — no new model, the horror is entirely in the timing (Lane 1 owns
      the motor; ask for the lead, do not reach into it)
- [ ] **AU6.7** Each entity is built out of the AU5 channels it names rather
      than modelled and faded in
- [ ] **AU6.8** Storyboard frames for all five, captured and looked at
- [ ] **AU6.9** The planes they belong to become real places (AV)

## AV — The planes

Ten sephiroth plus the one that is not on the map, and four worlds as the
registers each is seen in. Malkuth is 3D and the game is played there; the wizard
eyes are 4D; the godhead is past Keter.

**Da'ath is the good one** — real, unmapped, unreachable deliberately, and
where the deliriants go.

### AV1 — The ladder
- [x] **AV1.1** ~~Twelve planes, named from the tradition, each one a real place~~
      Ten sephiroth, ordered low to high (`PlaneLadder.PLANES`, `game/systems/sephiroth.gd`),
      each with a real tradition name and a one-line Ashbloom-flavoured role —
      Malkuth as "the only plane you did not have to leave your body to
      reach," Keter as "the last real address before the godhead, which has
      none." `order` (0..9) is also what AV2's floors scale against, so the
      ladder and the altitude gate are one fact, not two tables that could
      disagree. Verified: `tests/plane_ladder_test.gd` — exactly ten, ordered,
      each with a real name.
- [x] **AV1.2** ~~Four worlds as registers rather than more planes~~
      `PlaneLadder.WORLDS` (Assiah/Yetzirah/Beriah/Atziluth) and `perceive(plane_id, world_id)`
      — the same plane read through a world, not a second plane. Verified
      alongside AV1.6 below, since they are the same mechanism.
- [x] **AV1.3** ~~Da'ath is not on the map and cannot be aimed at~~
      `PlaneLadder.DAATH` is real data — `plane(DAATH)` returns a named row —
      but it is never in `reachable_planes()`, `floor_requirement()` returns
      `INF` for it, and `petition()` refuses it outright before anything is
      spent. Verified: a specific assertion that it is absent from the
      reachable list and that a petition aimed at it fails, not just that
      nothing crashes.
- [x] **AV1.4** ~~You petition a plane, you do not travel to it — a name, a seal, an offering, a licence to depart~~
      `PlaneLadder.petition()` — a real seal (refused if empty), a real
      altitude precondition (refused if not yet high enough to be seen), and
      a real offering paid through `Boons.pay()`, the one body/standing
      ledger every other cost in this project already spends against.
      `PlaneLadder.depart()` is the other half — leaving costs something too,
      so "a licence to depart" is a fact about the body rather than a phrase
      folded silently into the entry price. Verified: refused on an empty
      seal, refused on Da'ath, refused above your own altitude, and — once
      genuinely earned — the offering is shown actually leaving the body on
      both the way in and the way out.
- [ ] **AV1.5** Each plane looks like itself, with more of Greg's art the higher it goes
- [ ] **AV1.6** Hellscape and angelscape are one place in two registers, not two asset sets
- [ ] **AV1.7** All of it runs on one shader with different dials (FINAL_V section 16)

### AV2 — Altitude is the gate
Greg: *"the higher you have to be to talk or even fight, conjure, evoke etc"*.
**This is the mechanic the rest hangs off.**
- [x] **AV2.1** ~~Seeing a plane, talking on it, conjuring on it and fighting on it are four rising floors~~
      `PlaneLadder.FLOOR_ORDER` (see/talk/conjure/fight) and `floor_requirement()`,
      scaling as a multiplier against the plane's own `order` — Malkuth's four
      floors are all 0 ("the game is played there"), Keter's `fight` floor
      clamps at the 0..100 ceiling. Verified: all four of Malkuth's floors
      are exactly 0; Keter's floors exceed Yesod's; Keter's `fight` floor is
      shown to actually clamp at the ceiling rather than merely being large.
- [x] **AV2.2** ~~The substance decides which door opens, not a menu~~
      `PlaneLadder.altitude()` is a pure read of events `substances.gd` and
      `meditation.gd` already record (`substance_taken`'s `consciousness_cost`,
      `meditation_ended`/`meditation_interrupted`'s `held_seconds`), decayed
      by real elapsed time since each one — the same half-life shape
      `WorldHistory.chaos_magick()` already uses. There is no function
      anywhere in `plane_ladder.gd` that raises altitude directly; the only way
      up is to actually take the substance or actually sit. Verified:
      altitude is exactly 0 before anything is taken, rises after a real
      `Substances.take()` call, and a full meditation hold reaches the same
      floor a dose does — the parity the design brief itself calls for
      between the fast, costly route and the slow, free one.
- [x] **AV2.3** ~~Coming down mid-conversation is a real failure and the entity remembers it~~
      `PlaneLadder.sustain_or_fail()` — checked against live, decaying altitude
      rather than a snapshot taken once at the start, so a hold that was
      valid a minute ago can genuinely fail now. A failure records a real
      `plane_altitude_failed` event naming the subject, the plane and which
      floor gave out. Verified: a subject with nothing taken can still hold
      a Malkuth-tier interaction (needs 0) but fails the same call one plane
      up, and the failure leaves a real recorded event, not a silent `false`.
- [x] **AV2.4** ~~You cannot fight the godhead sober, and that is not a difficulty setting~~
      Structural rather than a rule someone could toggle: Keter's `fight`
      floor is derived from its `order` the same formula every other floor
      uses, and that derivation happens to clamp at the ceiling — there is no
      branch anywhere that special-cases "sober" or reads a difficulty value.
      The godhead fight itself (K v3-v10) is unbuilt elsewhere and this does
      not attempt it; what this closes is that the altitude gate it will need
      already exists and is already this strict at the top of the ladder.
- [x] **AV2.5** ~~Sustaining altitude is its own problem, separate from reaching it~~
      Altitude decays on its own half-life once nothing is feeding it —
      reaching a floor and staying there are two different facts, verified
      by backdating a real recorded event and showing the reading has
      genuinely fallen rather than staying pinned at its high-water mark.

### AV3 — They remember you
- [x] **AV3.1** ~~Entities are subjects in WorldHistory like everybody else~~
      `PlaneLadder.register_planes()` — the same `WorldHistory.register_subject()`
      shape `AscentEntities.seed_entities()` already uses for the order's
      lower ranks, kept as its own table rather than merged into `ENTITIES`
      since a plane is a place with a voice, not one of that order's
      personified ranks. Da'ath is deliberately never registered, so nothing
      can ask WorldHistory about a relationship with a place that is not on
      the map. Verified: every reachable plane is a real subject with
      `kind: "plane"`; Da'ath's subject lookup comes back empty.
- [x] **AV3.2** ~~A relationship accumulates across trips~~ `PlaneVoices.standing()` reads every petition, departure and collection a subject has ever made with a plane out of `WorldHistory` and returns one number; `trips()` counts them. Nothing is stored — standing is derived, so it cannot drift out of step with the events that caused it, and a plane you have never petitioned is not a zero row, it is simply absent
- [x] **AV3.3** ~~Voice is distorted and clears with standing — the whole readout, no meter~~ There is no meter anywhere: `clarity()` feeds `distort()`, which corrupts the entity's actual words — dropping vowels to a consonant skeleton first, then whole words to `_lost()` — so how well you stand with a plane is legible only as how much of it you can read. Deterministic per line and per subject, so the same sentence degrades the same way twice rather than shimmering
- [x] **AV3.4** ~~Mysterious means withholding, never vague~~ `ask()` resolves a real answer from real world state first and *then* decides how much of it you are given. The answer exists underneath whether or not you can see it, which is the whole distinction — `_known()` returns a fact, and standing decides whether the fact arrives, arrives partially, or is refused. Nothing is generated as a plausible-sounding non-answer
- [x] **AV3.5** ~~They can be owed, and they collect (AR2.4)~~ `owe()` writes a real debt against a plane; `debt()` reads it; `collect()` calls `Boons.pay()` straight out of the body/standing ledger every other cost in this project uses, so being collected from costs the same currency being hurt does. `collect_due()` is the hook for a caller that wants to sweep everything owed at once
- [x] **AV3.6** ~~They disagree with each other the way the gods do about a kill~~ `plane_verdict()` and `disagreement()` give two planes genuinely different readings of the same event, driven by each plane's own register rather than by a random roll — so the disagreement is *about* something and stays consistent if you ask twice
- [x] **AV3.7** ~~Demonic and jesterish is the register; the jester is already on the handheld~~ `handheld_readout()` routes plane speech through the same handheld the jester motif already lives on, so the register arrives on the device the player already reads rather than in a new window of its own

## AW — Commissioning

Greg: *"help me make subsection lists on top of the checklist that show me how i
can commission and call all my artist friends"*.

**Each plane is a brief.** You are not asking for "some psychedelic art" —
you are asking for *Gevurah, seen from Yetzirah*, at a stated size, for a stated
use. That is a brief an artist can price, and a far better one than most
freelance work they will be offered.

- [ ] **AW1.1** One plane, one artist, one brief — twelve independent commissions
- [ ] **AW1.2** Write the brief before asking: plane, register, size, format, use, and what it sits beside
- [ ] **AW1.3** Licence agreed in writing before money moves — use, modification, and whether it survives a sale
- [ ] **AW1.4** Credit in the game, on the cast page, not only in a readme
- [ ] **AW1.5** Pay properly. They are friends, which is a reason for more paperwork, not less
- [ ] **AW1.6** Take source files, not only exports
- [ ] **AW1.7** Their work goes in as texture and material inside the procedural system, never replacing it
- [ ] **AW1.8** A rejection or a redraw is budgeted for before the first commission goes out

## AS — Night, the lamp, and what you are wearing

Greg: *"the light can become really warped at night and distorted. Phone has a %
possibly, or just really minimal lighting, and you can wave it around showing
lighting — as well as having light coming off the phone when you have it in
your hand, then you can wave it around or pocket it... pockets and clothes should
be integral, or at least a part of the world system, layers and strategy to
everything."*

### AS1 — The handheld is a lamp
Built twice in parallel (this session's own AS1 pass and a second
implementation merged in from `agent-b`) and reconciled into one: the
`SpotLight3D`/position/shadow framing is this pass's, the battery's
drain-*and*-recharge economy, `LAMP_RANGE`/`light_radius()` hook and
`is_lit()` naming are `agent-b`'s — kept as the more complete design.
`torch_active()`/`battery_percent()` survive as aliases over `is_lit()`/
`battery` so neither side's call sites had to change, one condition
underneath either name.
- [x] ~~**AS1.1** It throws real light into the world when it is in your
      hand~~ A real `SpotLight3D` (`bone_yard_hunt.gd`'s `handheld_lamp`),
      bolted to the camera rather than the world so it moves with wherever
      you point it — "wave it around" — off-centre and angled the way a
      phone actually sits in a raised hand, casting real shadows. Driven
      entirely off `handheld.is_lit()`/`battery`, so the light and the
      device it is bolted to can never disagree about whether it is on.
- [x] ~~**AS1.2** Holding it up to see is an action with a cost — that hand
      is busy~~ Already structurally true (raising the device takes over the
      whole screen and suspends combat input) and now costs something
      ongoing too: the torch burns real battery for as long as the device
      is actually raised (`raised > 0.5`, not merely `is_open`, so the cost
      tracks the same smooth blend the device's own raise animation uses).
- [x] ~~**AS1.3** A battery percentage that runs down and can run out~~ The
      status page's "CELL %" had been device *condition* wearing a
      battery's name since C1 — real damage, not charge, so a device that
      had never taken a hit still read a full battery forever. `battery`,
      independent of `condition`, drains while raised and *recharges* while
      pocketed (roughly four times slower than it drains — letting go is
      relief, not an instant refill), and can reach exactly zero, at which
      point `is_lit()` goes false and the real light in the world goes dark
      with it — not merely dim.
- [x] ~~**AS1.4** Pocketing it is a movement and the light goes with it~~
      Falls out of AS1.1's own wiring: the light's energy is read fresh off
      `is_lit()`/`battery` every frame, and lowering the device is the one
      thing that already drops `raised` below the lit threshold.
- [x] ~~**AS1.5** Its light is what gives you away at night (pairs with
      AE1.1)~~ Closed with C7.1: the emitted source has its own range-and-cover
      verdict, hostile pursuit and launcher readiness read it, and the
      player's body remains a separate sighting. That separation creates a
      real night interval in which a hunter follows the visible Black Mirror
      while its holder is still `player_unseen`; cover, charge and pocketing
      all close the trail. Verified by `tests/perception_test.gd`,
      `tests/perception_integration_test.gd`, and the full
      `combat_integration_test.gd` regression suite.

### AS2 — Night
- [x] **AS2.1** Light warps and distorts at night rather than dimming
- [x] **AS2.2** Minimal lighting is the default and a light source is a decision
- [ ] **AS2.3** Night is when AO4.2's hauntings happen — AO4.2 does not exist
      in the project yet; nothing was wired to it.
- [x] **AS2.4** It reads off `world_clock.gd`, which exists now (W1.1)

### AS3 — Clothes and pockets
- [ ] **AS3.1** Layers, and they are part of the world system rather than a paperdoll
- [~] **AS3.2** Pockets hold real things and what is in them matters — the mechanism is built under C8.2 (`carry.gd`: `pocket()`/`unpocket()`/`pocketed_items()`/`search_pockets()`, real identified items rather than a separate abstraction, `tests/pockets_test.gd` 15 checks). What is still AS3's own and not done here: which garment actually provides how many pockets, which needs `garments.gd` (Lane 2's) rather than a capacity constant invented in CARRY, and nothing in the world yet *searches* a body's pockets — that verb belongs to whoever owns grappling and defeat
- [ ] **AS3.3** What you are wearing is strategy: weather, radiation, who talks to you
- [ ] **AS3.4** It shows on the body the mirror renders (AH1.5, N)
- [x] **AS3.1** Layers, and they are part of the world system rather than a paperdoll
- [x] **AS3.2** Pockets hold real things and what is in them matters
- [ ] **AS3.3** What you are wearing is strategy: weather, radiation, who talks to you —
      weather and faction standing are real (a layer cuts storm exposure and
      moves tree_alignment()); radiation has no stat anywhere in the project
      yet to reduce.
- [ ] **AS3.4** It shows on the body the mirror renders (AH1.5, N) — the coat
      itself is real and tinted per layer, visible on the body right now; the
      literal mirror this item names is not built anywhere in the project yet.

### AS4 — Storms that answer the occult
Greg: *"I also want the weather to have consistent crazy storms depending on
spirits levels, chaos magick levels... the lightning in the game needs to have
anvil crawlers, all the crazy red lighting-esque things."*
- [x] **AS4.1** Weather is a readout of how much magick is loose, not ambience
- [x] **AS4.2** Storm severity tracks spirit and chaos-magick levels in WorldHistory
- [x] **AS4.3** Anvil crawler lightning — the long horizontal crawl, not a flash
- [x] **AS4.4** Red lightning, and it means something when it appears
- [x] **AS4.5** Being caught out in it costs something (W1.3)


### AS v10 — the final pass
The last rung. Fifteen statements that are true of night, the lamp and what you wear when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [x] ~~**AS10.1** `v10` The handheld throws real light into the world~~ See AS1.1.
- [x] ~~**AS10.2** `v10` Holding it up costs you the hand~~ See AS1.2.
- [x] ~~**AS10.3** `v10` The battery runs down and can reach nothing~~ See AS1.3.
- [x] ~~**AS10.4** `v10` Pocketing it is a movement and the light goes with it~~ See AS1.4.
- [ ] **AS10.5** `v10` Its light is what gives you away at night — see AS1.5;
      blocked on AE1.1, which does not exist.
- [ ] **AS10.6** `v10` Light warps and distorts at night rather than dimming
- [ ] **AS10.7** `v10` Minimal lighting is the default and a light source is a decision
- [ ] **AS10.8** `v10` Night is when the hauntings happen
- [ ] **AS10.9** `v10` It all reads off the one clock
- [ ] **AS10.10** `v10` Layers are part of the world system, not a paperdoll
- [ ] **AS10.11** `v10` Pockets hold real things and what is in them matters
- [ ] **AS10.12** `v10` What you wear is strategy: weather, radiation, who talks to you
- [ ] **AS10.13** `v10` It shows on the body the mirror renders
- [ ] **AS10.14** `v10` Storms track the chaos-magick level
- [ ] **AS10.15** `v10` Anvil crawlers and red lightning, and being caught out costs

## AK — The agency that owns the sky

Reference intake for the field/geometry/satellite/doomscrolling direction:
`DESIGN/REFERENCE_INTAKE_2026-09-14.md`.  Its provenance rule governs every
future briefing, feed and occult visual in this section.

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

**Source note, 13 September 2026.** The register to aim at is no longer the
*Great Awakening* chart. Greg brought the *NASA's 666 Numbers* flat-earth
infographic, which is the same density — hand-lettered, confident, unsourced,
red underlines — with none of the payload AK2.6 was written to keep out. It
names no real people and accuses nobody; it is arithmetic about the
gravitational constant and the nautical mile. It also arrives pre-sorted into
the three kinds AK2.2 needs, which is why it is worth more than a mood board:

- **True.** Newton's apple, 1666. Earth's circumference, 21,600 nautical miles.
- **Tautology.** Eight inches *is* 0.666 feet. A nautical mile *is* one minute
  of arc. True, and empty.
- **False.** G is 6.674, not 6.66. Equatorial rotation is 1,674 km/h, not 1,666.

A briefing built that way is verifiable in part, unfalsifiable in part and wrong
in part, with nothing marking which is which — and `pin_board.gd`'s existing
expose/fabricate split (L4.1) resolves it with no new machinery.

**And it hands over the mechanic.** Every hit in that chart is a rounding toward
a target: 18.506 becomes 18.5 so the product can read 66,600. So the app rounds.
Every coordinate, bearing, distance and altitude the satellite gives you is
nudged — small, consistent, always toward their signature, never wrong enough to
get you killed. That collapses three items into one discovery: they see what you
see and they also stamp it (AK1.2), working against them coarsens the rounding
before it takes the sky away (AK1.5), and the paper chart you fall back to is
unrounded, so your first true bearing is the moment you find out (AK1.6). The
licence agreement nobody reads is where the numbers are declared, which makes
AK1.1 and AK2.1 the same object.

⚠ The rounding belongs in Lane 4's readout layer, not in Lane 5's
`handheld_device.gd` screen, or E2's two-implementations problem happens again.

### AK1 — Whose satellite it is
- [ ] **AK1.1** The satellite app has an owner, named, with a logo and a licence agreement
- [x] **AK1.2** They see what you see — after the repossession order exists, opening MAP calls the territory authority with the carrier's live position. The device publishes a coarse acquisition area into the same persistent bounty, so using its satellite view is itself the thing that lets CellOutz reacquire you; staying in one cell cannot spam a cosmetic event
- [ ] **AK1.3** Standing with them is a real quantity and it moves
- [ ] **AK1.4** They give you work, on the map, and the work changes the map
- [ ] **AK1.5** You can work against them, and the sky gets worse for you when you do
- [ ] **AK1.6** Losing them costs the satellite: back to a paper chart (A10 degrades, it does not vanish)
- [ ] **AK1.7** They are an institution and the satire stays pointed at institutions
- [x] **AK1.8** Their target pings publish an approximate area rather than omniscient coordinates; bounties and jobs draw hunters into that area and make the phone's convenience a direct threat to whoever carries it — CellOutz snaps the true position to a 96-metre acquisition grid and publishes a persisted 72-metre uncertainty radius, rendered on the Ashbloom sheet as a broken red ring with the green player offset somewhere inside it (`captures/celloutz_target_area.png`). Crossing a cell boundary updates the order; standing inside one cannot duplicate it. The first area commissions two named Ledger Bailiffs through `_spawn_encounter_actor`, giving the contractors ordinary anatomy, AI, loot and persistent outcomes rather than icon-only existence. A living pair caps the response; only a later ping after both are dead, escaped, spared or recruited can commission replacements. `facility_territory_test` proves coarse/idempotent/restored pings, `facility_device_integration_test` proves using MAP publishes one, and `celloutz_bounty_response_test` proves the physical response and spawn cap

### AK2 — The esoteric chart register
- [ ] **AK2.1** Their briefings read like the charts: dense, hand-lettered, confident, unsourced
- [ ] **AK2.2** Some of what they tell you is true, and the game never says which
- [ ] **AK2.3** Their claims pin onto the Board like anybody else's (L)
- [ ] **AK2.4** Their version of the world sits on the pyramid, near the top (AI2.1)
- [ ] **AK2.5** Two records: what the satellite saw, and what they published about it
- [ ] **AK2.6** The subject is occult, never the real-world conspiracy canon it borrows its density from


### AK v10 — the final pass
The last rung. Fifteen statements that are true of the agency that owns the sky when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AK10.1** `v10` The satellite app has a named owner with a licence agreement
- [ ] **AK10.2** `v10` They see what you see
- [ ] **AK10.3** `v10` Standing with them is a real quantity that moves
- [ ] **AK10.4** `v10` They give you work on the map that changes the map
- [ ] **AK10.5** `v10` You can work against them
- [ ] **AK10.6** `v10` Losing them costs the satellite and leaves a paper chart
- [ ] **AK10.7** `v10` Their briefings are dense, hand-lettered, confident and unsourced
- [ ] **AK10.8** `v10` Some of what they tell you is true and the game never says which
- [ ] **AK10.9** `v10` Their claims pin onto the Board
- [ ] **AK10.10** `v10` Their version of the world sits near the top of the pyramid
- [ ] **AK10.11** `v10` Two records: what the satellite saw and what they published
- [ ] **AK10.12** `v10` The tunnels are where they cannot see you
- [ ] **AK10.13** `v10` They are an institution and the satire stays there
- [ ] **AK10.14** `v10` The subject is occult, never the real-world conspiracy canon
- [ ] **AK10.15** `v10` They know you across the restart

## AL — The bank, and what runs under the street

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

### AL1 — The bank
- [x] **AL1.1** Money exists as a real quantity with a real issuer — already built, under R rather than AL: `Carry.CURRENCY` (`rust_scrip`) and `CURRENCY_ISSUER` (`celloutz`, a real registered faction subject with its own doctrine), the wallet living durably at `WorldHistory.subject("inventory").rust_scrip`. Verified by the pre-existing `money_test.gd` (R1.1), re-run clean rather than duplicated
- [x] **AL1.2** The bank writes the liens the Choir already prices (CARRY, B) — the per-item `lien` field has existed since B5.4 but nothing ever wrote a real one into it; `Carry.borrow_against(amount, lender_faction, item_index)` reuses `borrow()`'s own real debt ledger and additionally stamps the exact carried item with who holds the lien and how much, found on the item itself rather than an abstract number nobody can point at
- [x] **AL1.3** A debt is secured against something of yours, named, and they will take it — `Carry.seize_lien(lender_faction)` finds the item actually liened to that lender and removes it from CARRY for real, valued by the same `sale_value()` the Choir prices everything by (never a fiction number invented for this one verb), and shrinks the real debt by what the thing was actually worth. `tests/bank_lien_test.gd` covers the lien, seizure, and real balance; `money_test.gd` (R1.1/R1.4) remains on the same ledger. `Carry.send_collector()` now supplies the AL1.7 default visit seam.
- [ ] **AL1.4** Accounts, in a building, that you can walk into and rob
- [x] **AL1.5** Interest accrues in game time, and it does not stop while you are away — `Carry.accrue_interest()` settles the account from `WorldClock.minutes()`, not from a bank scene or a per-frame timer, so two full days catch up when a fresh Carry instance next reads the saved ledger. Three percent compounds per whole in-world day; unused hours remain on the account rather than being rounded into a charge or forgiven. Borrowing and repayment reset the lender's real clock anchor, every settlement writes a `bank_interest_accrued` receipt into WorldHistory, and old saves with debt but no timestamp begin honestly at first read instead of receiving invented retroactive charges. `tests/bank_lien_test.gd` expanded from 14 to 23 passing checks; `money_test.gd` and `world_clock_test.gd` remain green
- [x] **AL1.6** They are an institution: the satire lands on the paperwork, not on debtors — `Carry.account_statement()` returns the real office, issuer, balance, rate and named collateral beside three clauses in the bank's own procedural voice. The account holder is never characterised or mocked; the office states, in writing, that it records ownership but provides no relief, recovers security without you present, and keeps its own errors payable until it chooses to correct them. The AL1.5 demo typesets the same returned clause rather than carrying separate joke copy, and `bank_lien_test.gd` proves the statement names the responsible office, the actual figures and the exact liver securing the loan
- [x] **AL1.7** Default has a collector, and the collector is a persisted person with a `BaselineHuman` body record and full anatomy snapshot; `Carry.send_collector()` creates one deterministic lender collector when needed, seizes the named lien, and records `debt_collector_visited`. `tests/bank_lien_test.gd` covers identity, body schema, anatomy, and history.

### AL2 — The network under it
- [ ] **AL2.1** A sewer and tunnel layer under the region, connected and navigable
- [ ] **AL2.2** It is how the collateral moves - the organ trade has a route
- [ ] **AL2.3** Entrances are found, not marked: a grate you noticed is a route you own
- [ ] **AL2.4** Down there the satellite cannot see you (AK1.2), which is the point
- [ ] **AL2.5** It connects holdings that are not connected above ground (AA)
- [ ] **AL2.6** Raiding a vault from underneath is the best version of AB3
- [ ] **AL2.7** Sound behaves differently down there, and the game lets you hear that (G)


### AL v2 — the second pass
AL1.5 made interest persistent in game time. It exposed the distinction the
later R10 wording makes explicit: closing the application currently stops the
world clock, so "whether you play or not" is not true yet.
- [ ] **AL1.5** `v2` Reconcile real elapsed time on load without letting a long absence create an absurd or overflowed debt
- [ ] **AL1.6** `v2` Every lender currently prints the same boilerplate; its own doctrine should change the terms without making the borrower the joke


### AL v10 — the final pass
The last rung. Fifteen statements that are true of the bank and the tunnels when this game is finished, each an instance of a rule in `DESIGN/FINAL_V.md` applied to this section rather than a wish about it.
- [ ] **AL10.1** `v10` Money has an issuer and the issuer has a building
- [ ] **AL10.2** `v10` The bank writes the liens the Choir prices
- [ ] **AL10.3** `v10` A debt is secured against something named and they will take it
- [ ] **AL10.4** `v10` Interest accrues in game time and does not stop
- [ ] **AL10.5** `v10` Default has a collector with a body
- [ ] **AL10.6** `v10` The satire lands on the paperwork, never on debtors
- [ ] **AL10.7** `v10` A sewer and tunnel layer under the region, connected and navigable
- [ ] **AL10.8** `v10` It is how the collateral moves
- [ ] **AL10.9** `v10` Entrances are found, not marked
- [ ] **AL10.10** `v10` Down there the satellite cannot see you
- [ ] **AL10.11** `v10` It connects holdings that are not connected above ground
- [ ] **AL10.12** `v10` Raiding a vault from underneath is the best version of a raid
- [ ] **AL10.13** `v10` Sound behaves differently down there and you can hear it
- [ ] **AL10.14** `v10` The military down there is eating itself on a clock
- [ ] **AL10.15** `v10` What is down there is found, never briefed
## AV — The planes

Ten sephiroth plus the one that is not on the map, and four worlds as the
registers each is seen in. Malkuth is 3D and the game is played there; the wizard
eyes are 4D; the godhead is past Keter.

**Da'ath is the good one** — real, unmapped, unreachable deliberately, and
where the deliriants go.

This section did not exist yet in this tree's own copy of the checklist —
present in the fuller copy other lanes' trees carry, and in this lane's own
stated work order (`LANE.md`: "AI, AU, AV, AQ"), but never copied into this
file's body until now. Added faithfully from that fuller copy rather than
reworded, so the item text below is Greg's own brief, not a paraphrase.

### AV1 — The ladder
- [x] **AV1.1** ~~Twelve planes, named from the tradition, each one a real place~~
      Ten sephiroth, ordered low to high (`Sephiroth.PLANES`, `game/systems/sephiroth.gd`),
      each with a real tradition name and a one-line Ashbloom-flavoured role —
      Malkuth as "the only plane you did not have to leave your body to
      reach," Keter as "the last real address before the godhead, which has
      none." `order` (0..9) is also what AV2's floors scale against, so the
      ladder and the altitude gate are one fact, not two tables that could
      disagree. Verified: `tests/sephiroth_test.gd` — exactly ten, ordered,
      each with a real name.
- [x] **AV1.2** ~~Four worlds as registers rather than more planes~~
      `Sephiroth.WORLDS` (Assiah/Yetzirah/Beriah/Atziluth) and `perceive(plane_id, world_id)`
      — the same plane read through a world, not a second plane. Verified
      alongside AV1.6 below, since they are the same mechanism.
- [x] **AV1.3** ~~Da'ath is not on the map and cannot be aimed at~~
      `Sephiroth.DAATH` is real data — `plane(DAATH)` returns a named row —
      but it is never in `reachable_planes()`, `floor_requirement()` returns
      `INF` for it, and `petition()` refuses it outright before anything is
      spent. Verified: a specific assertion that it is absent from the
      reachable list and that a petition aimed at it fails, not just that
      nothing crashes.
- [x] **AV1.4** ~~You petition a plane, you do not travel to it — a name, a seal, an offering, a licence to depart~~
      `Sephiroth.petition()` — a real seal (refused if empty), a real
      altitude precondition (refused if not yet high enough to be seen), and
      a real offering paid through `Boons.pay()`, the one body/standing
      ledger every other cost in this project already spends against.
      `Sephiroth.depart()` is the other half — leaving costs something too,
      so "a licence to depart" is a fact about the body rather than a phrase
      folded silently into the entry price. Verified: refused on an empty
      seal, refused on Da'ath, refused above your own altitude, and — once
      genuinely earned — the offering is shown actually leaving the body on
      both the way in and the way out.
- [ ] **AV1.5** Each plane looks like itself, with more of Greg's art the higher it goes
- [ ] **AV1.6** Hellscape and angelscape are one place in two registers, not two asset sets
      Partially answered by `perceive()`'s `valence`-driven tone (the same
      named plane reads as "debt, teeth, a bill coming due" through an
      infernal world and "light with no source" through a celestial one) —
      but that is a text register, not the actual art/shader AV1.6 is really
      asking for. Left open rather than claimed.
- [ ] **AV1.7** All of it runs on one shader with different dials (FINAL_V section 16)
      Explicitly out of scope for this pass: the shader `FINAL_V.md` §16
      names currently exists only as 21 uncommitted files in an unrelated
      worktree (`atg-controls-ui`, branch `codex/controls-ui-repair`), which
      `AGENT_SPLIT_6.md` itself flags as Lane 2 material that lane should
      commit on its own branch first. Building against a shader with no
      committed form anywhere would be building against nothing.

### AV2 — Altitude is the gate
Greg: *"the higher you have to be to talk or even fight, conjure, evoke etc"*.
**This is the mechanic the rest hangs off.**
- [x] **AV2.1** ~~Seeing a plane, talking on it, conjuring on it and fighting on it are four rising floors~~
      `Sephiroth.FLOOR_ORDER` (see/talk/conjure/fight) and `floor_requirement()`,
      scaling as a multiplier against the plane's own `order` — Malkuth's four
      floors are all 0 ("the game is played there"), Keter's `fight` floor
      clamps at the 0..100 ceiling. Verified: all four of Malkuth's floors
      are exactly 0; Keter's floors exceed Yesod's; Keter's `fight` floor is
      shown to actually clamp at the ceiling rather than merely being large.
- [x] **AV2.2** ~~The substance decides which door opens, not a menu~~
      `Sephiroth.altitude()` is a pure read of events `substances.gd` and
      `meditation.gd` already record (`substance_taken`'s `consciousness_cost`,
      `meditation_ended`/`meditation_interrupted`'s `held_seconds`), decayed
      by real elapsed time since each one — the same half-life shape
      `WorldHistory.chaos_magick()` already uses. There is no function
      anywhere in `sephiroth.gd` that raises altitude directly; the only way
      up is to actually take the substance or actually sit. Verified:
      altitude is exactly 0 before anything is taken, rises after a real
      `Substances.take()` call, and a full meditation hold reaches the same
      floor a dose does — the parity the design brief itself calls for
      between the fast, costly route and the slow, free one.
- [x] **AV2.3** ~~Coming down mid-conversation is a real failure and the entity remembers it~~
      `Sephiroth.sustain_or_fail()` — checked against live, decaying altitude
      rather than a snapshot taken once at the start, so a hold that was
      valid a minute ago can genuinely fail now. A failure records a real
      `plane_altitude_failed` event naming the subject, the plane and which
      floor gave out. Verified: a subject with nothing taken can still hold
      a Malkuth-tier interaction (needs 0) but fails the same call one plane
      up, and the failure leaves a real recorded event, not a silent `false`.
- [x] **AV2.4** ~~You cannot fight the godhead sober, and that is not a difficulty setting~~
      Structural rather than a rule someone could toggle: Keter's `fight`
      floor is derived from its `order` the same formula every other floor
      uses, and that derivation happens to clamp at the ceiling — there is no
      branch anywhere that special-cases "sober" or reads a difficulty value.
      The godhead fight itself (K v3-v10) is unbuilt elsewhere and this does
      not attempt it; what this closes is that the altitude gate it will need
      already exists and is already this strict at the top of the ladder.
- [x] **AV2.5** ~~Sustaining altitude is its own problem, separate from reaching it~~
      Altitude decays on its own half-life once nothing is feeding it —
      reaching a floor and staying there are two different facts, verified
      by backdating a real recorded event and showing the reading has
      genuinely fallen rather than staying pinned at its high-water mark.

### AV3 — They remember you
- [x] **AV3.1** ~~Entities are subjects in WorldHistory like everybody else~~
      `Sephiroth.register_planes()` — the same `WorldHistory.register_subject()`
      shape `AscentEntities.seed_entities()` already uses for the order's
      lower ranks, kept as its own table rather than merged into `ENTITIES`
      since a plane is a place with a voice, not one of that order's
      personified ranks. Da'ath is deliberately never registered, so nothing
      can ask WorldHistory about a relationship with a place that is not on
      the map. Verified: every reachable plane is a real subject with
      `kind: "plane"`; Da'ath's subject lookup comes back empty.
- [x] ~~**AV3.2** A relationship accumulates across trips~~
      `systems/plane_voices.gd` (`PlaneVoices`). AV3.1 made every reachable
      plane a real `WorldHistory` subject with an empty `relations` table;
      this is what those subjects do with a memory. Standing accumulates out
      of acts other systems already record — a completed petition, a paid
      departure, a hold that fell through mid-sentence — the same discipline
      `Sephiroth.altitude()` and `AscentEntities.regard()` both use. There is
      no `set_standing()` anywhere in the file: the only way a plane thinks
      better of you is to actually go there, actually pay, and actually not
      come down mid-sentence. Verified: one clean trip is worth a measured
      0.20, and AV2.3's own mid-conversation failure costs a plane's regard
      *more* than a clean trip buys.
- [x] ~~**AV3.3** Voice is distorted and clears with standing — the whole readout, no meter~~
      Standing is never printed anywhere. It is expressed as how much of what
      the plane actually said arrives intact: at a stranger's standing about a
      seventh of a line survives, and it clears fully at five clean petitions'
      worth. The transform is deterministic per (plane, subject, word), so the
      same entity mangles the same word the same way every time — that
      consistency is what makes the memory legible rather than noisy — and it
      is monotone, so a word that survives at low clarity survives at every
      higher clarity. The readout only ever *clears*; it never reshuffles into
      a different sentence.
- [x] ~~**AV3.4** Mysterious means withholding, never vague~~
      `ask()` never returns mush. Either the plane genuinely does not know the
      thing and says so plainly (`ok: false`), or it knows a specific, true,
      derived-from-history answer and either hands it over or refuses it *by
      name* — a refusal carries `known: true`, what kind of thing is being
      kept, and the standing that would buy it. The withheld string exists in
      full the whole time and comes back verbatim once standing clears, which
      is exactly what makes it withholding rather than an empty branch
      dressed up as mystery.
- [x] ~~**AV3.5** They can be owed, and they collect (AR2.4)~~
      `owe()`/`debt()`/`collect()`/`collect_due()` — a plane can be genuinely
      owed, the debt is real state, and collection is a real act paid through
      `Boons`' existing body/standing ledger rather than a second currency.
- [x] ~~**AV3.6** They disagree with each other the way the gods do about a kill~~
      `plane_verdict()`/`record_plane_verdicts()`/`disagreement()` — a plane
      that approved of one of your kills thinks better of you for it and the
      plane on the opposite pillar thinks worse, which is the whole point of
      them disagreeing rather than all moving together.
- [x] ~~**AV3.7** Demonic and jesterish is the register; the jester is already on the handheld~~
      `handheld_readout()` puts the distorted voice through the device the
      jester is already stamped on, so the register arrives in the place the
      item names rather than as a separate presentation.

      All six verified by `tests/plane_voices_test.gd` — **68 checks, 0
      failures**, with `tests/sephiroth_test.gd` (AV1/AV2/AV3.1) re-verified
      clean against the change.
      Honest note on provenance: the agent that wrote this hit a session
      limit after its tests went green but before it wrote these entries or
      committed. The code and its 68 checks were re-run and verified
      independently before this commit; these write-ups are reconstructed
      from the implementation rather than authored by the agent that built
      it. Nothing here is ticked on a claim that was not re-run.

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
