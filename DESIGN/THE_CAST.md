# The cast

**What this fixes:** who is on the board, what a name sounds like, what a title
means, how much a person is allowed to be described, and which people are
authored rather than generated.

**Status:** structure. Names and titles are **not invented here** — the grammar
below is the one already in the code, written down so that art and writing can
work from it.

---

## 1. The naming rule, as built

`cast_names.gd` generates names per save from `WorldHistory.run_salt`. The same
slot — `"derby_captain"` — always resolves to the same person inside one save and
to a different person in the next. Nothing is random at the point of call.

| Register | Rule | Examples in the code |
| --- | --- | --- |
| Forename | short, blunt, one or two syllables | Cass · Juno · Wren · Nix · Rook · Iris · Gray · Vale · Bex · Tallis · Orla · Pike · Sloane · Reve · Mera · Corin · Ash · Lior · Sable · Quill · Enna · Torr · Kester · Brann · Dove · Halloway · Ives · Nell · Roan · Sparrow · Verity · Whit |
| Surname | a material, a weather, an instrument, a part of a building — something you could be hit with | Lumen · Veil · Hollis · Ashby · Arden · Sable · Coil · Marrow · Gantry · Culvert · Lathe · Brine · Winch · Cinder · Rime · Lockwood · Tarn · Grieve · Mallory · Stanchion · Gale · Quarry · Fen · Hollow · Kiln · Lintel · Murrain · Pallor · Rafter · Sallow · Trestle · Vellum · Wick · Yarrow · Corbel · Drift |

**Never:** fantasy constructions, apostrophes, titles in the name, a hardcoded
name in the source. The wipe of "Mara Voss" was the correction; a second
hardcoded name would be the same bug with different letters.

**Slot naming** is stable and mixed (`_seed_for`), so `derby_captain` and
`derby_captain_2` are not siblings by accident.

## 2. Titles

A title is a role string, not a rank word. Roles live in `cast_names.gd` as
prose — `Bone Yard Captain`, `Pit Marshal`, `Scrap Surgeon`, `Line Foreman`,
`Ration Clerk`, `Signal Keeper`, `Wreck Boss`, `Grave Contractor`, `Tithe
Collector`, `Spare Parts Broker`, `Yard Warden`, `Rig Mechanic` — and `facility_
characters.gd` matches them by whole word, because a "Yard salvage hand" must not
be read as facility staff.

**Rule:** a title is read, never parsed. `implant_catalog.gd` sets the same rule
for hardware names: names are identifiers for humans, not keys. Anything that
needs to branch on a person branches on `faction_id`, `faction_rank` (`CROWN` is
the only rank string the code reads) or `kind`.

## 3. Three traits, one wound

A card carries at most:

1. **three traits** — each a sentence the person would say, drawn from the
   record: `grudge` for what they have against you, `status` for what has
   happened to them, `is_rival` for whether the world has noticed them;
2. **one wound story** — the scar line, read from the wound that made it (zone,
   cause, round count), never authored prose about a wound that did not happen;
3. **one aim** — `NONE`, `SEE YOU DEAD`, or whatever the standing supports. The
   aim is read from what they have done to you and what you did to them. It is
   never assigned to raise the stakes.

More than three traits is a dossier, and a dossier is a different screen.

## 4. Silhouette, by band

Art direction, not code. The rule that makes a rank readable across a room:

- **One silhouette change per band, and only one.** SINGULARITY reads by
  bearing and by what is carried for them; PRIVY RING by a fitted outer layer;
  OFFICE by a garment that constrains movement; NETWORK by issued kit; OUTSIDE by
  what they happened to be wearing.
- **Band is also a colour note**, never a colour fill. The palette is near-black,
  dried blood, arterial red, copper, bone and a sickly green at most; rank is a
  trim, a strap, a badge, not a team colour.
- **Readable in the dark**, because most rooms are dark. `silhouette_rim.gd`
  keeps a faint edge on bodies in unlit rooms; anything that must survive a
  blackout has to survive as a shape.
- **No rank without a body.** A card is a person, not a portrait frame.

`silhouette.gd` exists because a textured world still reads as boxes if every
silhouette is the same box; this section is that lesson applied to people.

## 5. Authored and generated

| Kind | Who | Where |
| --- | --- | --- |
| Authored | The Examiner — **deliberately unnamed**; if asked, he says what he does, never who he is | `facility_characters.gd` |
| Authored | Hollis, the numbered guard | `facility_guard_post.gd`, `facility_guard_loadout.gd` |
| Authored | The freed vat subject, the Lower Works sentinel | `support_guard.gd`, sentinel scene |
| Generated | Everyone else, from a slot, per save | `cast_names.gd` |
| Classified | Horsemen, Sins, Captains, Lesser Demons | `demon_hierarchy.gd` (read-only) |

The distinction matters: an authored person is one the story needs to be
specific, and a model improvising them would be improvising the institution. A
generated person is a life the simulation produced. Do not promote a generated
person to authored without a reason the story can name.

## 6. How many

The board is forty seats per faction, and that is a **faction**, not a cast. The
facility slice needs a board the player can read, which means:

- every seated person on the facility board has a name, a role, a band and a
  face that can be generated from the shared rig;
- the crowd (OUTSIDE) is allowed to be faces the player will not meet twice;
- **no new named person enters the slice unless they take a seat, hold a door,
  or can be met twice.**

### The v0.1 number

The slice reads one faction's board — celloutz — so the cast is the ladder's
seats plus the people the story has to be specific about:

| Who | Count | Where it comes from |
| --- | ---: | --- |
| Seated people | 40 | 1 + 3 + 9 + 27 (`THE_LADDER.md` §1); OUTSIDE is uncapped and not counted |
| Authored people | 4 | The Examiner, Hollis, the numbered guard, the Lower Works sentinel (§5) |
| **Named people in the slice** | **44** | the ceiling when every seat is filled; a fresh save seats fewer |

Of those 44, the drawing and casting work is split by band, not by taste:

| Work | Count | Why |
| --- | ---: | --- |
| Hand-authored face and body | 4 | The four the story has to be specific about (§5) |
| Rig-generated face, band pass (dress, silhouette, one distinguishing mark) | 13 | SINGULARITY + PRIVY + OFFICE: the bands with authority over the facility, so they must read across a room (§4) |
| Rig-generated face, standard | 27 | NETWORK: met on the facility floor |
| Crowd | uncapped | OUTSIDE; never met twice, never needs a name on screen |

Retinue (`THE_LADDER.md` §5, **PROPOSAL**) would add one to three bodyguards to
each PRIVY and OFFICE seat — up to 36 more named people — and is excluded from
these numbers until Greg answers it. Per-faction ring names do not change any
count; they change the words on the card.

## 7. What a card is allowed to say

The card is the unit of legibility, shared by the board, the dossier and the
X-ray read:

```text
NAME · ROLE                      BAND WORD · SIDE
three traits                      one scar line
aim: SEE YOU DEAD / NONE          retinue: 2
```

Nothing on the card is a number the world does not already hold. No level, no
rating, no percentage — the twelve dimensions stay behind it.

## 8. Open, and only Greg can answer

1. Which of the named facility people get a face Greg draws, and which are
   generated from the shared rig.
2. Whether the examiner is ever named (current rule: never).
3. The Instagram handle for crediting Greg's art in the gallery and on cards.
