# The interface, as its own art direction

Captured from Greg, 2026-09-11, across several bursts while looking at the
rebuilt World Index. This is the standard the whole UI layer is now held to.

## The thing he does not want

> *"instead of boxes and boxes of text having that ugly approach of that
> spaceship friendslop game — I hate that"*

Flat rectangles, uniform padding, a grid of labelled fields, the same panel
repeated with different words in it. It is what co-op survival UI looks like and
it is what this project's interfaces looked like before the display face landed.
The World Index rebuild moved off it; **nothing else has**.

Rule, stated plainly so it can be applied without re-asking: **no screen in this
game is a list of text in a box.** If a screen's information could be a
spreadsheet, it is not finished.

## The thing he does want

> *"matrix code game esq matrix code + blood guts gore xrays broken bones ect
> feces, edgy"*

**Code as a material.** Falling character rain is the surface everything else
sits on or is cut out of — but it is not decoration, it carries data. The
characters should be the game's own vocabulary: subject ids, event types, zone
names, sequence numbers. When something is wrong with a body the code over it
should degrade. This connects to the CRT/digital-decay line already in
`ART-DIRECTION.md` and gives it a form.

**Gore is interface, not just world.** X-ray plates, broken bones, viscera and
the rest are not confined to the kill cam — they are the register the panels
themselves are built in. The anatomy work is the most complete system in the
project and the least visible, so putting it *in the chrome* is the cheapest way
to make the game look like itself.

**Greg's own site.** `celloutz.xyz` "has that kinda style without the gore", and
his art folder is the intended texture source. Both are **blocked on Greg** —
see the open questions at the end of `CHECKLIST.md`. This is the single largest
available upgrade to the look and it cannot start without the files.

## Seamlessness is a hard requirement, not a polish pass

> *"everything seamless clickable customisable inspectable seamless organic user
> experience"*

Every hard cut in this game is a bug. The scene transitions were the first pass
(`systems/interstitial.gd`); the World Index page swap was the second. What is
left:

- Opening and closing a panel should not pop.
- Selecting a row should not redraw the page instantly.
- A part lifting out of a diagram must appear to *leave the diagram*, never open
  a modal — this is already the Tier 1c rule and it now applies everywhere.
- Entering and leaving the handheld, the map, the radial, the X-ray.

**Everything is clickable and inspectable.** Nothing on screen should be inert
text if the thing it names exists as an object. A wound, an organ, a
cybernetic, a person, a faction rank, a post, an account — all of them are
things you can point at and open.

## Psychonauts, early

> *"that early psyconauts influence in terms of seamless trippy intense"*

The transferable part is not the art style, it is that **the interface is part
of the world's psychology**. Menus warp, levels are minds, presentation shifts
with state. Applied here: the panel degrades as the *player* degrades. Blood
loss, pain, consciousness and Wire strain already exist as numbers in
`anatomy_component.gd` and are unused by any UI. They should drive it —
a bleeding player's index is harder to read, and that is diegetic rather than a
filter.

## "Using psychology tips" — the honest split

Greg asked for the UX to use attention psychology. That deserves a precise
answer, because this game already satirises exactly that.

- **The Wire is deliberately hostile.** `DESIGN/IN_GAME_INTERNET.md` already
  specifies a feed that is "designed to feel like being farmed": infinite
  scroll, engagement bait, variable reward, no useful sort order. That is
  *satire*, and it must actually work on the player for the joke to land.
- **The player's own tools are not.** The handheld, the index, the map and the
  body inspector serve the player: readable, honest, fast, no manufactured
  friction, no dark patterns.

Legibility, momentum, feedback and rhythm on one side; a farm on the other. The
contrast is the point, and the game should be confident enough to make the
difference obvious.

## The Wire is many websites, not one feed

> *"the internet should be a vibe coded crazy mess like neocities websites and
> esq crazy different worlds on the internet"*

This supersedes the single-feed presentation currently built. The Wire's feed
is one surface; **the web behind it is many, and each site is its own world.**

The register is hand-built personal web: tiled backgrounds, clashing palettes,
text that is centred for no reason, marquees, visitor counters that are
obviously lying, under-construction markers on sites abandoned four years ago,
guestbooks with one entry, webrings linking to six dead things and one live
horror, autoplaying audio that cannot be stopped. Nothing uses the same layout
twice, because nobody who made them agreed on anything.

Mechanically this matters more than it sounds: a site with its own layout is a
place, and `DESIGN/IN_GAME_INTERNET.md` already makes connectivity a property
of physical place. A site you can only reach from one terminal, that looks like
nothing else in the game, is a location.

Implementation note so this does not become unbounded: sites are **authored
layouts drawn in code**, from a small vocabulary of broken-web primitives
(tiled ground, marquee, counter, guestbook, webring, banner farm, popup),
combined per site with a seed. Not a browser engine, and no real HTML.

## What this changes on the checklist

- A6 (Living Map as an object) and A5 (derby HUD) inherit the no-boxes rule.
- C1 (device shell) must be seamless in and out, not a visibility toggle.
- A new **I** section covers the code-rain material, per-site web layouts, the
  state-driven panel degradation, and the celloutz.xyz integration.
