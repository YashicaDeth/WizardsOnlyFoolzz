# The ladder

**What this fixes:** how many rungs there are, what a rung means, how a seat
empties and refills, and what a person on it can do to you.

**Status:** structure, not build. Where this file and `pyramid_society.gd`
disagree, the code is the authority and this file is the bug. Everything marked
**PROPOSAL** is an assistant proposal that has not been answered by Greg.

**It replaces** the 33-tier spec recorded in `DESIGN.md` on 24 September 2026.
That spec was never built; the built model went to five bands with scarce
seats, which is the answer to "33 tiers is overwhelming".

---

## 1. What is actually built

`game/systems/pyramid_society.gd` (`PyramidSociety`) is a canonical,
presentation-independent model. It is tested by `pyramid_society_test` and
called by no scene. It stores, per subject:

- `social_power` — twelve dimensions, each 0-100. Never summed into one score.
- `alignment` — -1 to 1, the Descent/Ascent axis.
- `dossier` — references of six kinds: evidence, social posts, websites,
  locations, associates, notes.
- `nemesis_events` — an append-only history with sequence ids.
- `status`, `death`, `resurrection_receipt`.
- `graveyard` — the dead are archived, never deleted.

The twelve dimensions, in the order they are compared:

```text
class · influence · wealth · access · reputation · fear
respect · faction · combat · leverage · knowledge · relationships
```

### The five bands

| Band id | Label | Seats | Eligibility gates (`_eligible_band`) |
| --- | --- | ---: | --- |
| `singularity` | SINGULARITY | 1 | class ≥ 90, influence ≥ 75, access ≥ 70, leverage ≥ 65 |
| `privy` | PRIVY RING | 3 | class ≥ 70, influence ≥ 55, access ≥ 50 |
| `office` | OFFICE | 9 | influence ≥ 40, access ≥ 30, and faction ≥ 40 or wealth ≥ 55 |
| `network` | NETWORK | 27 | influence ≥ 18, or relationships ≥ 30, or reputation ≥ 35 |
| `outside` | OUTSIDE | ∞ | everyone else |

Forty seats, then the crowd. Placement is **lexicographic, not a hidden
scalar**: a person starts at the highest band they are eligible for and is moved
down one band at a time until a seat is free or they reach OUTSIDE, which is
uncapped (`pyramid_society.gd:121-126`). Within a band they sort on `class,
influence, access, leverage, relationships, faction, wealth, knowledge,
reputation, respect, fear, combat`, then on id so it is stable.

### The shape

`pyramid()` reports `geometry: "3x3_expanding_horseshoe"`. Each placement
carries a `position` dictionary holding `row`, `column`, `depth` and two
normalized coordinates, `horseshoe_x` / `horseshoe_y`, derived from
`alignment * PI * 0.82` (`pyramid_society.gd:405-410`; the test reads them as
`receiver.position.horseshoe_x`). Both poles curve back toward the apex:
alignment above +0.15 is `ABOVE`, below -0.15 is `BELOW`, in between is `HINGE`.
A renderer may draw this flat or use `depth` as a third axis.

### Death and return

`mark_dead()` sets status, writes the death, moves the subject to `graveyard`
and records `subject_died`. `resurrection_offer()` carries `costs` (world
resources only — `real_money`, `fiat`, `crypto` and `payment` are rejected in
code), `hook_ids` and a `story_gate`. `request_resurrection()` returns a request
for another system to fulfil; `complete_resurrection()` returns the subject to
`active` and records `subject_resurrected`. Nothing here charges anything.

---

## 2. Two readings, not two hierarchies

There are two different ladders in the code and they answer different questions.
Keeping them apart is the whole reason the board can stay flat and readable.

| Reading | Owner | Question | Values |
| --- | --- | --- | --- |
| **Standing** | `pyramid_society.gd` | How much pull does this person have? | 5 bands, 12 dimensions |
| **Kind** | `demon_hierarchy.gd` | What *is* this person in the cosmology? | LEADERSHIP · SIN · CAPTAIN · LESSER DEMON |

`DemonHierarchy` is explicitly a read-only classifier over subjects that already
exist — it authors no demons. A Horseman is the living holder of CellOutz's
`CROWN` rank; a Sin is a faction; a Captain commands one; a Lesser Demon is a
rival with no faction.

**Rule:** a person has one standing and, possibly, one kind. Standing is what
the board shows. Kind is what the cosmology shows. Neither is derived from the
other, and neither is a number the player is told.

**Known conflict to fix, not to paper over:** `ashline_wreckers` appears in
`CastNames.FACTIONS` as a road faction ("Ashline Wreckers") *and* in
`DemonHierarchy.SIN_FACTIONS` as the Wrath sin. One id, two meanings. Either the
road crew is renamed or the Sin absorbs it; that is Greg's call.

---

## 3. Seven rows on screen

The board is read, not studied. Seven rows:

1. **SINGULARITY** — one seat.
2. **PRIVY RING** — three.
3. **OFFICE** — nine.
4. **NETWORK** — twenty-seven.
5. **OUTSIDE** — the crowd, uncapped.
6. **YOU** — the waist, wherever your own standing puts you.
7. **FALLEN** — the graveyard, capped to what fits, the rest behind a count.

Seven reads at a glance. Thirty-three never will.

---

## 4. One ladder per faction

`pyramid(faction_id)` already filters by `faction_id`, so a table per faction is
free. The texture comes from **eleven tables with five rungs each**, not one
ladder with forty rungs — one table for each id listed below.

Faction ids that exist today:

```text
celloutz
ashline_wreckers · black_mile · soft_rot · choir_of_marrow
vanity_row · honeyvein · long_static
mercy_county_haul · the_slag_line · bonewright_union
```

**Ring names are Greg's.** The code's five labels (SINGULARITY, PRIVY RING,
OFFICE, NETWORK, OUTSIDE) are the defaults until a faction supplies its own five
words. The mechanism to add later is a five-entry `ring_labels` array on the
faction record; nothing else changes. No names are invented here.

---

## 5. Seats: empty, filled, sponsored

**Built:** a seat is a capacity. If a band is full, the next person falls a band.
Nothing currently refills a dead person's seat, and nothing records who vouched
for whom.

**PROPOSAL — every seat has a sponsor.** The person who vouched them up. It makes
CellOutz literally the pyramid scheme it is a parody of, and it gives the board
its one interesting verb:

- A promotion needs a sponsor: the person directly above, or a peer who is
  already seated.
- A sponsor's death leaves their downline exposed: the seat is contested by
  everyone they sponsored, and the winner inherits the grudge.
- **The main way a seat changes hands is your own downline taking it** — which
  means the board fills itself with people who have a reason to hate you, and
  the player can read the reason on the card.

If Greg says no, the fallback is seniority: the longest-serving person in the
band below takes the seat at dawn. Nothing else in this document depends on the
choice, but note that no tenureship field exists yet — `RankYears` belongs to
enRAGE, not to this codebase — so seniority needs a first-seen hour recorded on
the subject before it can be used.

**PROPOSAL — retinue.** Every PRIVY and OFFICE seat carries one to three named
bodyguards, themselves OUTSIDE. That is where "more players" comes from without
more rungs, and it is what makes an OFFICE seat feel different to walk into: he
is never alone, and the bodyguards are the ones who catch you.

**Promotion timing.** At the world clock's dawn, not at the moment of death. The
player should be able to see a seat empty and know it will be filled, and be able
to act in between.

---

## 6. What a band may do to you

**PROPOSAL**, derived from behaviour that already exists in the build. Each rung
should be felt as a different kind of threat, not a bigger number.

| Band | What they can do | Grounded in |
| --- | --- | --- |
| SINGULARITY | Sign a repossession order in your name; put the sky on you | AK1.2 repossession order, bailiffs |
| PRIVY RING | Dispatch the hunt; move ground; post a bounty | AK1.8, `hunt_contracts` |
| OFFICE | Hold a door, post a guard, call it in, withhold a keycard | guard procedure, `facility_guard_post` |
| NETWORK | Work a shift, be coerced, carry a keycard, remember your face | `witness_ledger`, guard dialogue |
| OUTSIDE | Be used, be in the way, be a witness | crowd, `roster` |

The rule that makes this legible: **the threat is the verb, not the stat.** A
SINGULARITY you never meet ruins you by post; an OUTSIDE you meet ruins you by
being there when it happens.

---

## 7. Open, and only Greg can answer

1. **Ring names** per faction (five words each), or keep the neutral five.
2. **Sponsor tree**: yes or no (section 5). Recommended: yes.
3. **Retinue**: one to three bodyguards on PRIVY and OFFICE. Recommended: yes.
4. **`ashline_wreckers`**: road crew or Wrath, not both.
5. **Does alignment split the board above/below the waist** (the horseshoe), or
   is `ABOVE`/`BELOW` only a card property? The geometry supports either.

---

## 8. What the screen does with it

`THE_SCREEN.md` decides where this is read. The contract this file owes it:

- seven rows, seats drawn as seats (empty ones visible);
- a card per person: name, role, band word, alignment side, three traits, one
  scar line, retinue count, and the aim word if they have one;
- no total score anywhere, ever;
- the fallen reachable in one press;
- a seat that is empty says when it fills.

## 9. Test surface

`pyramid_society_test` already exercises registration, band capacities, the
graveyard, resurrection and snapshot/restore. Any change to this document's
numbers is a change to that suite first.
