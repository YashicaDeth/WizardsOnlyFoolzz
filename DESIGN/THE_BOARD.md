# The Board — the storyline as a conspiracy pin board

Captured from Greg, 2026-09-12: *"the main game storyline career option thing is
a conspiracy theory pin board of all the ideas etc, in the Charlie Always Sunny
style conspiracy board"* — *"and that links everything in."*

Recorded whole before any of it is built, because the second half is the part
that matters and it is easy to lose.

---

## What it replaces

A quest log is a list of text in a box. It is the single worst offender against
I0 that this project has not yet built, and the surest way to make a
living-world sandbox feel like a to-do app. Every other screen has been dragged
out of that shape — the index, the map, the handheld, the dossier — and the
storyline was going to walk straight back into it.

The Board is the alternative: **the player's own theory of the world, pinned up
and strung together.** Cuttings, photographs, index cards, a receipt, a page
torn from a Compendium entry, all connected with red string and annotated in
marker by someone who is increasingly sure they are onto something.

## Why it is right for this game specifically

It is not a skin. Four things the project already has make it the correct
shape rather than a decorative one:

- **The register is already there.** `DESIGN/IN_GAME_INTERNET.md` sets the Wire
  in the David Dees paranoid-collage register — *"arrows and exclamation marks
  annotating things that are and are not connected"*. The Board is that, made by
  the player instead of read by them.
- **The two-records rule.** `world_history.gd` holds what happened; each faction
  holds what it *believes*. The Board is a third record: **what the player
  thinks**, which is allowed to be wrong. That is a pillar (§13, information is
  partial, late, manipulated or false) finally given a player-facing surface.
- **The evidence already exists as objects.** `field_camera.gd` (C3) takes
  photographs with verifiable contents. `carry.gd` holds identified parts.
  `witness_ledger.gd` records who saw what. Those are pinnable things, not
  quest flags.
- **Career progression is a shape, not a ladder.** "Career option thing" wants
  branching, and a board branches natively. A string from a body to a faction to
  a Horseman *is* a route, and the player drawing it is them choosing it.

## What goes on it

| Pinned | Comes from | Already built |
| --- | --- | --- |
| Photographs | `field_camera.gd` | yes |
| People | `WorldHistory` subjects | yes |
| Factions and ranks | `FACTION_TREE_AXIS`, rank pyramid | yes |
| Wire posts and accounts | `wire_net.gd`, `broken_web.gd` | yes |
| Carried parts, with their liens | `carry.gd` | yes |
| Wounds and implants | `anatomy_component.gd` | yes |
| The Sins, the Horsemen, the two poles | `DESIGN/COSMOLOGY.md` | designed |

## The one mechanic that makes it a game rather than a screen

**Drawing a string is a claim, and claims can be wrong.**

- A string the world supports becomes a **lead** — it opens work, names a place,
  or makes someone reachable.
- A string the world does not support stays on the board looking exactly as
  convincing as a true one. Nothing marks it false. The player finds out by
  acting on it.
- Publishing a theory to the Wire is the existing `expose` / `fabricate` action
  (I6, built): a true string published is **discrediting a faction**, and a
  false one published is **fabrication**, which already costs reach and
  exposure.

That last line is the "links everything in": the Board is where the Hunt System,
the Wire, the karma axis and the evidence tools meet, and it is the first screen
where being wrong has a price.

## Register

Charlie's board is the reference for *feel*, not for layout — corkboard,
overlapping paper, red string, block capitals, too many connections. The
project's own vocabulary supplies the rest: `celloutz_type` for the marker hand,
`celloutz_grunge` for the tape and the stains, the derived art sheets for the
paper. It should look made rather than rendered, and it should be legible the
way a wall is legible: from across the room you read the shape, up close you
read the cards.

## Sequencing

The Board is expensive and it should not be built as one drop.

1. **The surface.** Corkboard, pinned cards, string between them, pan and zoom.
   Read-only, populated from `WorldHistory`. This is the screen.
2. **Pinning.** The player pins what they choose, from the index, the camera and
   CARRY. Nothing is pinned automatically except the first card.
3. **Strings as claims.** Draw a connection; the world either supports it or
   does not. Leads open.
4. **Publishing.** A theory goes to the Wire through the actions that exist.
5. **Career.** Routes across the board are the progression, replacing any notion
   of a quest list entirely.

Step 1 is worth building on its own and proves the rest.

## Open for Greg

1. Is the Board diegetic — a physical wall in a place the player returns to —
   or is it carried, on the black mirror?
2. Can other people see it? A raided camp with the player's board on the wall is
   a very strong consequence, and it makes the board a thing that can be *lost*.
3. Does a wrong string ever get corrected, or does the player simply live with a
   board that is partly nonsense?
