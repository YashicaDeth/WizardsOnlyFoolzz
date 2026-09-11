# The checklist

Greg asked for a list he can prompt from, because the design has outrun the
build. **Say a number and I build that item.** Nothing here is lost — every
line traces back to a capture in `ROADMAP.md` or `DESIGN/`.

Ordered so each item makes the next one look and feel better. `DONE` items stay
on the list so it reads as a record rather than a wish.

---

## A — The visual pass (in flight now)

The game's systems have outgrown its interface. This is the shortest distance
between "tutorial project" and "a game", and it is what Greg reacted to.

| # | Item | What you get |
| --- | --- | --- |
| A1 | **Display typeface** — `DONE` | A drawn stencil face instead of Godot's default. |
| A2 | **World Index UI** — *in flight* | The worst offender in the game rebuilt: real dossier, framed plate, display face. |
| A3 | **Rank pyramid view** — *in flight* | Faction hierarchy as a recruitment pyramid, drawn from real subjects, with real vacancies. |
| A4 | **Wire feed page** — *in flight* | The surviving internet playable: accounts, reach, DMs that go unread, the underbelly. |
| A5 | **Derby HUD corners** | Hull integrity, hunt signal, damage bust and radar brought into the same language. |
| A6 | **Living Map as an object** | The map in a salvaged bezel instead of a chart on black, with named travel points. |

## B — Make the body the centrepiece

The gore and anatomy work is the most complete thing in the project and the
least visible. This makes it the thing people remember.

| # | Item | What you get |
| --- | --- | --- |
| B1 | **Clickable 3D organs** (Tier 1c) | Hover a zone, the organ lifts out of the diagram and spins in place with its real condition. |
| B2 | **Limbs and cybernetics inspect the same way** | One verb for the whole body, not organs only. |
| B3 | **The X-ray cursor** | A circular cursor with an X-ray button on it. See through anything, any time. |
| B4 | **Chunk physics and layers** | Skin, fat, muscle, blood, bone, organ, cybernetic — as real pieces with real identity. |
| B5 | **Rob cybernetics off a body** | Dig through the layers to take the part. Looting as a physical act. |
| B6 | **Dismemberment as a combat verb** | Take an arm mid-fight and the fight continues with them still in it. |

## C — The handheld, and killing the six-panel problem

Six fullscreen panels on six keys is the root cause of "nothing connects."

| # | Item | What you get |
| --- | --- | --- |
| C1 | **Device shell** | One junk handheld with modes, replacing Tab / M / T / J. Not a Pip-Boy. |
| C2 | **Radial selection** | Circular menu with a custom cursor for weapons, cybernetics, modes, seals. |
| C3 | **Camera mode** | Photograph the world. Required by rituals; also just good. |
| C4 | **CARRY** | The inventory that already exists, finally on screen. |
| C5 | **Physical connectivity** | Masts, terminals, dead zones, and a cracked screen that eats the interface. |

## D — Character creation in the vat

Full design in `DESIGN/CHARACTER_CREATION.md`. Also fixes the under-directed
opening.

| # | Item | What you get |
| --- | --- | --- |
| D1 | **The sheet** | A real player subject built from data instead of a hardcoded dict. |
| D2 | **Traits and point budget** | Project Zomboid intake checkboxes. Every one hooks a system that exists. |
| D3 | **The intake scene** | Handler, clipboard, tube in your mouth, blink to answer, he writes it down wrong. |
| D4 | **Races** | Six, all consequences of the Reset. Silhouette + metabolism + social price. |
| D5 | **The chart route** | Real birth chart to real stats. Skyrim standing stones, done properly. |
| D6 | **The instrument route** | Personality test that congratulates you on your dark triad scores. |
| D7 | **The mirror** | Sliders, under-skin editing, and a preview that lies because you are under goo. |
| D8 | **Opt-in modifiers** | Neural lace, mast tithe, full schedule. They work, and that is the problem. |

## E — The two ladders

Full design in `DESIGN/RITUAL_AND_KARMA.md`. All of this hangs off the
Ascent/Descent axis that already exists and is currently unused.

| # | Item | What you get |
| --- | --- | --- |
| E1 | **Karma from real events** | The axis accumulating from recorded history, with factions pricing you by it. |
| E2 | **The ritual app** | 72 Goetic seals plus original ones, drawn in code, on the handheld. |
| E3 | **Camera rituals** | Kill five, photograph the heads. The ritual checks the real anatomy in frame. |
| E4 | **Temporary boosts with real costs** | Paid in blood, organs, limbs or standing. Never permanent, never free. |
| E5 | **Ascent entities** | Angels and higher-frequency gods who wash away sins for positive quests. |
| E6 | **Drugs** | Preparation and consumption minigames, an economy, and the door to the entity layer. |
| E7 | **Route endings** | Become a demon and sign the soul over, or climb far enough to keep playing. |

## F — The Hunt System becoming a system

Today Mara is one hardcoded character. `DESIGN/HUNT_SYSTEM.md` has six
mechanisms and almost none are built.

| # | Item | What you get |
| --- | --- | --- |
| F1 | **Witness records on events** | Cheap, and everything downstream needs it. An unwitnessed act never spreads. |
| F2 | **Grudges travel along relation edges** | Knowledge propagates, decays and distorts. You can cut the transmission. |
| F3 | **Promotion into real vacancies** | Kill a captain, someone who already existed takes the post. |
| F4 | **Rivals generated from real events** | Not one authored character. This is what LimboAI is installed for. |
| F5 | **Player defeat routed to shackled** | Losing is not a reload. Tar re-decanting as the deliberate alternative. |
| F6 | **Mind-stamp and the asset list** | Non-consensual recruitment, and the people you own listed on the handheld. |

## G — The look

None of this is code. It is the difference between "reads as programmer art"
and "reads as a game."

| # | Item | What you get |
| --- | --- | --- |
| G1 | **Greg's own art as texture source** | Cut up the art folder and the celloutz.xyz gallery — glitched, coded, shaded — as body textures, map plates and Wire collage. Outstanding: **the folder path is still needed.** |
| G2 | **The cars** | Blender pass. Stripped chassis, exposed mechanism, bone and sinew lashings, bloom in the wheel wells. |
| G3 | **The derby arena** | Re-author the oval larger and retune the engagement cap against it. A constant will not do it. |
| G4 | **Silhouettes** | Bevels, greebles, leaning, broken corners — so outlines stop reading as primitives. |
| G5 | **Sound rework** | Positional audio, layered engine by load, impact layers by material. |
| G6 | **The opening, directed** | Pacing, camera, sound, the handler's delivery. Pairs with D3. |

## H — Base building, reduced

Greg's own call, recorded in `ROADMAP.md`: Valheim's building is a pillar built
by five people over years, and a shallow version is worse than none.

| # | Item | What you get |
| --- | --- | --- |
| H1 | **Claim a camp** | Take a place and it is yours. Recruits live there. Investment changes what it produces. |
| H2 | **It can be raided off you** | Valheim's attachment and Rust's stakes, out of systems that already exist. |

---

## Open decisions only Greg can make

These are blocking nothing, but they change what gets built.

1. **Ephemeris or derived wheel?** "Most accurate" birth charts mean real
   planetary longitudes from a table. The sigil currently derives a wheel from
   sun sign and birth time. The first is a real chunk of work.
2. **Guns: common or scarce?** Changes encounter design either way. Currently
   built but undecided.
3. **How is the dark web gated?** Coverage is a property of place, so the
   natural answer is a physical terminal rather than a menu toggle — currently
   implemented that way, and reversible.
4. **What persists between runs?** Roguelike structure was asked for, but
   "bodies remember" is a pillar. These pull against each other.
5. **Does the chassis roll?** The upright angular lock stops cars rolling.
   Good arcade feel, possibly wrong for a demolition derby.
6. **Where is the art folder?** Needed for G1.
