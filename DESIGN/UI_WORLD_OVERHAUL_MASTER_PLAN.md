# UI and world-system overhaul master plan

Status: active implementation plan, captured 2026-09-13 from Greg's annotated
screenshots and master directive. This document records requirements and the
delivery sequence; it does not claim that unfinished systems are complete.

## Product decision

The interface has two roots:

- **Pyramid:** people, power, violence, relationships, dossiers and death.
- **Wire:** information, online identity, communication, sites and signals.

Everything else is reached by following an object. A person leads to their body,
dossier, relationships and online identity. A post leads to an account, site,
place or person. An item leads to its owner, provenance, body slot or memory.
Persistent tab bars, left-side subject lists, modal detail boxes and decorative
centre cursors are transitional prototype UI and should disappear as equivalent
object-led navigation lands.

The visual target is a fictional digital civilisation, not one universal skin:
regal black-mirror hardware, friendly and strange console-era identity software,
authored personal-web sites, institutional surveillance, medical anatomy and
occult aerospace must be recognisably related without sharing one layout.

## Shared contracts first

1. `WorldHistory` remains canonical for physical subjects and events.
2. Online identities, dossiers, power facets, anatomy and inventory reference a
   subject id. They do not copy the subject into a second database.
3. Cross-system navigation uses typed routes and a reversible trail. A route
   carries its origin so transitions can visually explain where the player went.
4. New persistent fields are optional and receive defaults. Existing `elo` is
   accepted as legacy input but is not presented as the social hierarchy.
5. Wire markets use fictional in-game ownership and provenance only. No real
   currency, wallet, blockchain, cash-out or chance-purchase architecture.
6. Player-facing settings must bind to a real behaviour before they are shown.

## Delivery waves and ownership

The session supports four simultaneous workers, so the eight conceptual lanes
run in waves. Shared files are integrated only by the lead after lane tests pass.

### Wave 1 — foundations and first playable slice

| Lane | Owned implementation | Exit evidence |
| --- | --- | --- |
| Lead | route/trail contract, this dependency map, title audit, integration | route round-trip test; clean project parse |
| HUD/night | compact corner HUD and Black Mirror low-light sensor state | state/fade tests and a 1280x720 capture |
| Wire | search index, authored site descriptors, links, history and dark-route gates | search/cross-link/gating tests |
| Pyramid | social-power facets, hierarchy placement, nemesis ledger, dossier and Graveyard state | migration/placement/death/resurrection-hook tests |

### Wave 2 — make both roots playable

- Recompose `world_index.gd` around Pyramid and Wire canvases; remove the fixed
  left rail and top page tabs when equivalent object links exist.
- Pyramid uses portrait impostors at distance and a limited 3D head pool near
  focus. Clicking focus expands one character without a modal.
- Wire opens on search/discovery, not a feed. Sites use a small authored
  primitive vocabulary but keep distinct palettes, layouts, voices and routes.
- FILE becomes the identity landing object reached from a person/account, with
  expressive status phrases and a non-dropdown character carousel.
- Bind route origins to directional zoom, peel and reflection transitions.

### Wave 3 — character rabbit holes

- Online bodies: aliases, avatars, accounts, posts, stories, reels, sites,
  contacts and status, all keyed to physical subjects.
- Dossier evidence can reference posts, media, places, conversations, injuries,
  rumours and possessions without embedding duplicate data.
- Replace Kinship Web with a relationship portfolio sourced from real events.
- Dead subjects remain inspectable in the Graveyard. Resurrection is a costly
  story hook with explicit eligibility and consequences, not a generic button.

### Wave 4 — physical rabbit holes

- Replace CARRY with an `I`-key spatial inventory overlay that leaves the world
  visible and expands items in place.
- Body inspection becomes layered, rotatable and spatially synchronized:
  body → system → organ/bone → meaningful sub-part.
- Character, equipment, cybernetics and injuries share the same body anchors.
- The brain implant opens an explorable memory filesystem. Keywords link outward
  to people, sites, places, quests and the map.

### Wave 5 — world tools

- Living Map: discovery-first colour, fog of war, customizable player marker,
  useful zoom levels and gated travel.
- Satellite/cosmos: local map → planet → orbit → planetary/cosmic views, gated
  by story knowledge, ritual, altered states or equipment.
- Radio: eliminate persistent nuisance audio; make signals reactive audiovisual
  objects that can link to frequencies, people, quests and locations.

### Wave 6 — device, settings and polish

- Rebuild the device as curved ceremonial black-mirror hardware whose content
  exists in reflective glass. Power state belongs to the object, not a stock bar.
- Pause and settings inherit the world language while remaining direct.
- Wire strain, wounds and device damage influence presentation with accessible
  reductions for motion, flash, glitch, CRT distortion, text and contrast.
- Profile and optimise: pooled portraits, lazy site/body loading, cached models,
  event-driven refresh and LOD.

## Explicit screen decisions from the review

- Gameplay: world/map context top-left; character portrait top-right; health,
  magic and stamina integrated beneath/around it; weapon display subdued and
  contextual; full meters fade.
- Darkness: night remains threatening but navigable. The raised Black Mirror
  camera supplies sensor gain, exposure adaptation, autofocus, noise and bloom;
  a flat green overlay is not acceptable.
- Remove `DON'T LOSE THIS ONE` and equivalent placeholder scolding.
- Preserve and expand the idea of `WHAT THE WORLD RECORDED` as event history.
- Remove the Tree axis as a primary page. Cosmology is knowledge-gated rather
  than exposed as an unexplained diagram.
- Car condition should be read from the vehicle and damage feedback, not a large
  permanent HULL spreadsheet cell. Hunt status appears on change, not forever.
- Inventory replaces the empty CARRIED page. Radio and ritual remain reachable
  through objects/signals rather than permanent device tabs.
- Canonical live title spelling is `allusionstoograndeur`.

## Required end-to-end journeys

1. Pyramid → person → dossier → post → account → site → search result → person → Pyramid.
2. Inventory → character → brain → memory folder → keyword → memory → location → map.
3. Wire → hidden site → transmission → radio frequency → signal → quest → location.
4. Relationship → person → online identity → site → contact → conversation → dossier.

Each journey must preserve a visible/reversible trail and must not feel like a
stack of unrelated full-screen scene changes.

## Validation gate for every wave

- Run focused `ATG_TEST_MODE=1` headless tests with isolated temporary storage.
- Run project import/parse after new `class_name` scripts land.
- Exercise existing opening, combat, Wire, map, body and save tests affected by
  the change. No parser or null-reference cascades are acceptable.
- Capture changed interfaces at 1280x720 and at least one wider resolution; look
  at the images rather than approving layout from code.
- Confirm save defaults against an older fixture before adding persistent fields.
- Record real limitations. A prototype data surface is not a production 3D UI.

## Current safety boundary

At plan creation the worktree already contained unrelated modifications and new
files, including `broken_web.gd`, `vat_intake.gd` and `warning_card.gd`. Those are
preserved and are not treated as overhaul work unless deliberately reconciled.

