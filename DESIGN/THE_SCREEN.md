# The screen

**What this fixes:** where the board physically is, what it shows, how it is
navigated, and what it may never show.

It answers the question left open in `THE_BOARD.md` ("is the Board diegetic — a
physical wall — or carried, on the black mirror?") and the checklist's L3.1 /
H10.6 ("is the Board a wall in a room, or on the Mirror?").

**Status:** a recommendation with its alternatives. The choice is Greg's; the
consequences of each are written out so the choice can be made once.

---

## 1. The recommendation

**The Board is a wall. The Mirror carries a photograph of it, one edit behind.**

- The wall is the board: corkboard, paper, string, in a room the player returns
  to. `pin_board.gd` already describes itself as "the storyline, as a wall".
- The Mirror page called BOARD shows the last photograph the player took of that
  wall — a real image, taken with `field_camera.gd`, stored by `photo_album.gd`.
  If the wall has changed since the photograph, the screen says so, because a
  copy that quietly updated would be a menu pretending to be a wall.
- This satisfies law 14 twice, and it gives the board a **price**: it can be
  lost, copied, or found by someone else. A board that lives in a menu can never
  be any of those things.

The alternative — the board only on the Mirror — is cheaper to build and obeys
law 14 once (the phone is an object) but makes the board private and weightless:
nothing can be taken from it. The alternative in the other direction — a wall
with no copy — forces the player to walk back to one room to remember anything,
which is a fetch quest.

## 2. What it shows

Seven rows, in the order a person looks:

```text
SINGULARITY   1 seat
PRIVY RING    3 seats
OFFICE        9 seats
NETWORK      27 seats
OUTSIDE      the crowd
YOU          your seat, wherever your standing puts it
FALLEN       the archive, capped, with a count
```

- **Seats are drawn as seats.** An empty one is visibly empty and says when it
  fills; `THE_LADDER.md` §5 decides whether that is dawn or a sponsor.
- **Cards**, not portraits: name, role, band word, side, three traits, one scar
  line, retinue count, aim. Section 7 of `THE_CAST.md` is the contract.
- **Strings between cards** are the player's claims, and a claim can be wrong
  (`THE_BOARD.md`). Nothing marks a false string false.
- **FALLEN** is one press away, always, and never hides the living.

## 3. How it is navigated

- **Typed, reversible navigation.** `rabbit_hole_navigator.gd` already exists for
  exactly this: the Pyramid, the Wire and physical tools share one navigation
  grammar so Back means the same thing everywhere.
- **Pad first.** Left stick pans, right stick zooms, trigger selects, Circle goes
  back one level, Options opens the card. Everything the mouse can do, the pad
  can do; the reverse is not required.
- **Two magnifications, not five.** Across the room the shape reads; at arm's
  length the cards read. Zooming past the card is a dossier, not a board.
- **One press to the physical thing.** From a card, the place that person was
  last seen is reachable, and the route is the same route the world uses.

## 4. Register

- House type for the board's titles and card headers (`celloutz_type.gd`): caps
  only, no arrows, no wrapping — so every string is fitted, not trusted to wrap.
- Paper, tape and stains come from `celloutz_grunge.gd`; the board should look
  made, not rendered.
- **Red is danger**, as everywhere else in this game. A person is not coloured
  red for being high on the board; a person is marked red when they are coming
  for you.
- Nothing glows for attention. The board is lit by the room it is in.

## 5. What it may never show

1. A total, a level, a rating or a percentage.
2. A quest, a checklist, an objective marker, a "!".
3. A hidden score leaking through sort order that the player cannot see the
   reason for. If the board orders people, the ordering has to be one of the
   twelve dimensions the card can name.
4. A false string marked as false.
5. Debug text, ids, or a schema version.
6. A person the player has never met, described as if they had.

## 6. Build slices

Each slice is playable on its own; none is a placeholder for the next.

1. **The wall, read-only.** Board in a room, populated from `WorldHistory`,
   seven rows, cards, pan and zoom.
2. **The photograph.** The Mirror's BOARD page holds the last photo of the wall,
   stamped with the hour it was taken.
3. **Pinning.** The player pins a card from the index, the camera or CARRY.
4. **Strings as claims.** Draw a connection; the world supports it or does not;
   leads open.
5. **Publishing.** A theory goes to the Wire through the actions that already
   exist (`expose` / `fabricate`).

## 7. Open, and only Greg can answer

1. **Where the wall is.** A den, a room in the facility, the back of the cab, or
   several (a board per place). Recommended: one wall you return to, plus the
   photograph.
2. **Can it be found or taken?** Recommended: yes, and the loss is recoverable
   only as the photograph.
3. **Does a wrong string ever get corrected**, or does the player live with a
   board that is partly nonsense? (Recommended: only by acting on it.)
