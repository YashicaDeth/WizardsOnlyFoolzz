# The checklist

Greg asked for a list he can drive by number, because the design has outrun the
build. **Say a number and I build that item.** Nothing here is lost — every line
traces to a capture in `ROADMAP.md` or `DESIGN/`.

Ordered so each item makes the next one look and feel better. `DONE` items stay
on the list so it reads as a record rather than a wish.

Last rebuilt 2026-09-11, including everything captured so far.

---

## A — The visual pass

The systems outgrew the interface. Shortest distance between "tutorial project"
and "a game".

| # | Item | What you get |
| --- | --- | --- |
| A1 | **Display typeface** `DONE` | A drawn stencil face instead of Godot's default. |
| A2 | **World Index UI** `DONE` | The worst offender rebuilt: framed plate, real dossier, the Tree axis and the relation graph, both computed all along and never shown. |
| A3 | **Rank pyramid** `DONE` | Faction hierarchy as a recruitment scheme, from real command strength, with real vacancies and who is positioned for them. |
| A4 | **Wire page** `DONE` | Reach, tier, whether they will read you and why, leverage held, your own exposure, and the feed. |
| A5 | **Derby HUD corners** | Hull integrity, hunt signal, damage bust, contact radar — the corners you hated, in the new language. Inherits the no-boxes rule (I0). |
| A6 | **Living Map as an object** | The map in a salvaged bezel with named travel points, not a chart on black. |
| A7 | **Derby driving model** | Per-wheel raycast suspension, load transfer, real contact patches, replacing the single-body arcade servo. **This is the actual cause of "the derby map is broken"** — the venue reads wrong because the car does not behave like a car in it. |
| A8 | **Seamless panel open/close** | Opening the index still pops. Nothing in this game should cut. |

## B — Make the body the centrepiece

The most complete system in the project and the least visible.

| # | Item | What you get |
| --- | --- | --- |
| B0 | **Spinning 3D head icons** `DONE` | Real head and real skull per subject, turning in place, X on for the X-ray. First working piece of Tier 1c. |
| B1 | **Clickable 3D organs** | Hover a zone, the organ lifts *out of* the diagram and spins with its real condition. Never a modal. |
| B2 | **Limbs and cybernetics inspect the same way** | One verb for the whole body. |
| B3 | **The X-ray cursor** | Circular cursor with an X-ray button on it — see through anything, any time, as a constant verb. |
| B4 | **Chunk physics and layers** | Skin, fat, muscle, blood, bone, organ, cybernetic as real pieces that know what they are. |
| B5 | **Rob cybernetics off a body** | Dig through the layers to take the part. Looting as a physical act, not a menu transfer. |
| B6 | **Dismemberment as a combat verb** | Take an arm mid-fight and the fight continues with them still in it. |

## C — The handheld, and killing the six-panel problem

Six fullscreen panels on six keys is the root cause of "nothing connects".

| # | Item | What you get |
| --- | --- | --- |
| C1 | **Device shell** | One junk handheld with modes, replacing Tab / M / T / J. Seamless in and out. Not a Pip-Boy. |
| C2 | **Radial selection** | Circular menu, custom cursor, for weapons, cybernetics, modes, seals. **Prototype / GTA-style seamless time dilation** while it is open, so selection never breaks out to a menu — and the slowdown must not soften the fight, because the difficulty target stays soulslike. |
| C3 | **Camera mode** | Photograph the world. Required by rituals; also just good. |
| C4 | **CARRY** | The inventory that already exists, finally on screen. |
| C5 | **Physical connectivity** | Masts, terminals, dead zones, cracked screen eating the interface. |

## D — Character creation in the vat

**Races are D4.** Full design in `DESIGN/CHARACTER_CREATION.md`. Also fixes the
under-directed opening.

| # | Item | What you get |
| --- | --- | --- |
| D1 | **The sheet** | A real player subject built from data instead of a hardcoded dict. Everything below writes into it. |
| D2 | **Traits and point budget** | Project Zomboid intake checkboxes. Every one hooks a system that already exists. |
| D3 | **The intake scene** | Handler, clipboard, tube in your mouth so you cannot speak, blink to answer — and he writes down the wrong thing. |
| D4 | **Races** | Six, all consequences of the Reset: Decanted, Soft Rot, Marrow-Cut, Roadborn, Unreset, Lantern-Born. Silhouette + metabolism + social price + Tree pull. |
| D5 | **The chart route** | Real birth chart to real stats. Skyrim standing stones, done properly. |
| D6 | **The instrument route** | Personality test that congratulates you on your dark triad scores and files the result. |
| D7 | **The mirror** | Sliders, under-skin editing of the skeleton and organ set, and a preview that lies because you are under goo. |
| D8 | **Opt-in modifiers** | Neural lace, mast tithe, full schedule. They work, and *that* is the problem. |

## E — The two ladders

Full design in `DESIGN/RITUAL_AND_KARMA.md`. All of it hangs off the
Ascent/Descent axis that already exists and is currently unused.

| # | Item | What you get |
| --- | --- | --- |
| E1 | **Karma from real events** | The axis accumulating from recorded history, with factions pricing you by it. Not a morality slider. |
| E2 | **The ritual app** | 72 Goetic seals plus original ones, drawn in code so they can animate, corrupt and burn. |
| E3 | **Camera rituals** | Kill five, photograph the heads. The ritual checks the real anatomy of a real body in frame. |
| E4 | **Temporary boosts, real costs** | Paid in blood, organs, limbs or standing. Never permanent, never free. |
| E5 | **Ascent entities** | Angels and higher-frequency gods who wash away sins for positive quests. The nemesis code paths serve both ladders. |
| E6 | **Drugs** | Preparation and consumption minigames, an economy, and the door to the entity layer. |
| E7 | **Route endings** | Become a demon and sign the soul over, or climb far enough that the game continues. |

## F — The Hunt System becoming a system

Today Mara is one hardcoded character. `DESIGN/HUNT_SYSTEM.md` has six
mechanisms and almost none are built.

| # | Item | What you get |
| --- | --- | --- |
| F1 | **Witness records on events** | Cheap, and everything downstream needs it. An unwitnessed act never enters faction knowledge. |
| F2 | **Grudges travel real edges** | Knowledge propagates, decays, distorts. You can cut the transmission. |
| F3 | **Promotion into real vacancies** | Kill a captain and someone who already existed takes the post — possibly a worse fighter with better connections, which is worse news. |
| F4 | **Rivals generated from real events** | Not one authored character. This is what LimboAI is installed for and never used. |
| F5 | **Player defeat routed to shackled** | Losing is not a reload. Tar re-decanting as the deliberate alternative. |
| F6 | **Mind-stamp and the asset list** | Non-consensual recruitment, and the people you own listed on the handheld. |
| F7 | **The clinch as a social verb** | Hold someone and talk: rob, abuse, or persuade. Four systems that already exist start talking to each other — highest value per line of code in the whole list. |

## G — The look

Not code. The difference between "programmer art" and "a game".

| # | Item | What you get |
| --- | --- | --- |
| G1 | **Greg's art as texture source** | The art folder and the celloutz.xyz gallery, cut up, glitched, shaded — body textures, map plates, Wire collage. **Blocked: needs the folder path.** |
| G2 | **The cars** | Blender pass. Stripped chassis, exposed mechanism, bone and sinew lashings, bloom in the wheel wells. |
| G3 | **The derby arena** | Re-author the oval larger and retune engagement against it. A constant multiplier does not do it — measured and reverted twice. |
| G4 | **Silhouettes** | Bevels, greebles, leaning, broken corners, so outlines stop reading as primitives. |
| G5 | **Sound rework** | Positional audio, engine layered by load, impact layers by material. Not blocked on FMOD — see J1. |
| G6 | **The opening, directed** | Pacing, camera, sound, the handler's delivery. Pairs with D3. |

## H — Base building, reduced

Greg's own call: Valheim's building is a pillar built by five people over years,
and a shallow version is worse than none.

| # | Item | What you get |
| --- | --- | --- |
| H1 | **Claim a camp** | Take a place and it is yours. Recruits live there. Investment changes what it produces and who it attracts. |
| H2 | **It can be raided off you** | Valheim's attachment and Rust's stakes, out of systems that already exist. |

## I — The interface as its own medium

New section, from `DESIGN/INTERFACE_DIRECTION.md`. This is the art direction for
the UI layer specifically.

| # | Item | What you get |
| --- | --- | --- |
| I0 | **No screen is a list of text in a box** | The standing rule. If a screen's information could be a spreadsheet, it is not finished. Applies to A5, A6, C1 and everything after. |
| I1 | **Code as a material** | Character rain carrying the game's own vocabulary — subject ids, event types, zone names — degrading where the body does. Not decoration. |
| I2 | **The web is many worlds** | Neocities register: every site its own layout, tiled grounds, marquees, lying visitor counters, guestbooks with one entry, webrings into dead things. Authored in code from broken-web primitives, not a browser. |
| I3 | **celloutz.xyz in-game** | Greg's own site as a reachable place on the Wire. **Blocked: needs a decision — mirror the real content, or a fictionalised in-world version?** |
| I4 | **Panels degrade with the player** | Blood loss, pain, consciousness and Wire strain already exist as numbers and drive no UI. A bleeding player's index is harder to read. The Psychonauts lesson: the interface is part of the world's psychology. |
| I5 | **Everything clickable and inspectable** | A wound, an organ, a cybernetic, a person, a rank, a post, an account — if it exists as an object, you can point at it and open it. |
| I6 | **The honest split on dark patterns** | The Wire is *deliberately* hostile — infinite scroll, bait, variable reward — because that is the satire and it must work to land. The player's own tools are the opposite: readable, fast, no manufactured friction. The contrast is the point. |

## J — Infrastructure

Unglamorous, and each one is currently costing real time.

| # | Item | What you get |
| --- | --- | --- |
| J1 | **Drop FMOD properly** | 238MB, referenced by no script, and its GDExtension fights any open editor for a port and floods stderr until headless tests starve. Disabled locally, but `.gitignore` covers `game/addons/fmod/` so the fix cannot travel — every checkout hits it again. |
| J2 | **Debug keys out of the shipping input map** | Reset keys and dev affordances still ship. |
| J3 | **Adopt the installed plugins** | LimboAI for F4, Terrain3D + Proton Scatter for the Ashbloom exterior, Dialogue Manager when NPCs first speak. 415MB currently doing nothing. |
| J4 | **Real loading behind the interstitial** | The plate covers a fixed 1.45s hold rather than actual load progress. Covered, not seamless. |

---

## Open questions — only Greg can answer these

Blocking nothing, but they change what gets built.

1. **Where is the art folder?** Blocks G1, the single largest available upgrade
   to the look.
2. **celloutz.xyz — mirror or fictionalise?** Blocks I3.
3. **Ephemeris or derived wheel?** "Most accurate" birth charts need real
   planetary longitudes from a table. The sigil currently derives a wheel from
   sun sign and birth time. Affects D5.
4. **Guns: common, or scarce and improvised?** Changes encounter design either
   way. Built but undecided.
5. **What persists between runs?** Roguelike structure was asked for, but
   "bodies remember" is a pillar. These pull against each other.
6. **Does the chassis roll?** The upright angular lock stops cars rolling. Good
   arcade feel, possibly wrong for a demolition derby. Affects A7.
7. **How is the dark web gated?** Currently a physical terminal, since coverage
   is already a property of place. Reversible.
