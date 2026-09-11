# The cosmology — who is above, who is below, and what the player is

Captured from Greg, 2026-09-12, in one burst. Recorded whole rather than
half-built, because this is the frame the rest of the design has been missing:
the Tree axis, the two ladders, the route endings and the faction table have all
existed in code for sessions without anyone being able to say *who is at each
end*. Now they can.

---

## AS ABOVE, SO BELOW, finally populated

The central motif was already the spine of `world_history.gd` — every subject
sits somewhere on an Ascent/Limbo/Descent axis, and `FACTION_TREE_AXIS` gives
each faction a baseline pull. What was never decided is what the two ends
actually *are*. They are now:

| | **Below — CellOutz** | **Above — wizardsonlyfoolz** |
| --- | --- | --- |
| What it is | The demon faction. The underground. | The mage collective. Higher-frequency entities, gods, the angelic register. |
| Register | Corporate, extractive, bodily. A company that sells you your own organs back. | Occult, collective, frequency-and-signal. A guild that will not take you seriously. |
| Already in the game | The CellOutz brand is on every interface, every product notice and the storefront. | Unbuilt. |

This is the joke the project has been sitting on without realising: **CellOutz
has been the devil the whole time.** The HUD is a CellOutz product. The
liability notice on the warning card is CellOutz refusing responsibility. The
handheld is CellOutz hardware. The player has been carrying hell's branded
merchandise since the first scene, and it reads as ordinary because a company
is exactly what a modern hell would look like.

`wizardsonlyfoolz` was previously recorded only as a candidate working title
(open question 5). It is better used here — as the name of the ascending
collective — than as the title of the game. That question stays open, but this
is an argument for keeping *Allusions to Grandeur* on the cover.

## The player

**A CellOut wizard. Half demon, half angel.** Not a chosen one — a person with
a foot on each ladder, which is mechanically already true: `tree_alignment()`
returns a single number that can sit anywhere between the two ends, and the
player starts in Limbo at 0.0 by default.

This retroactively explains the opening. You are decanted out of a vat on the
Growing Floor with a debt that is "in the meat", because CellOutz grew you and
CellOutz owns the body. Being half of the other thing is what makes you able to
leave.

## What the player wants

**To fight God, and to get his attention.** Not nihilistically — the goal is to
force a hearing, so the earth can be fixed and the true evil got rid of. The
player is a Hunter, and what is being hunted is ultimately upward.

Two things follow that the design already half-supports:

- **E5 — Ascent entities** are not a shop. They are the lower ranks of the thing
  the player is trying to reach, and they run on the same nemesis machinery as
  any rival. Getting their attention is the mechanic.
- **E7 — route endings** are now legible. Signing yourself over to CellOutz is
  becoming what grew you. Climbing far enough is the route where the game keeps
  going, and it is the one that matches the stated goal.

The satire pillar survives this intact: the target is institutions and power —
a hell that is a corporation, a heaven that is a gatekeeping collective, and a
god who has to be *forced* to look. It aims at the structures, not at anyone's
faith.

## The Four Horsemen as rotating bosses

**Recurring bosses across the whole game, who take turns leading the CellOutz
faction.** This is the strongest structural idea in the drop, because it solves
a problem the Hunt System already has:

- `HUNT_SYSTEM.md` mechanism 2 is **promotion into real vacancies** (F3, still
  unbuilt). Killing a leader must leave a real hole filled by someone who
  already existed.
- Four named Horsemen are exactly that: a standing succession. Kill the one in
  charge and the next takes the post, which changes what the faction *does*
  rather than just changing a name — Famine running CellOutz is a different
  world from War running it.
- It gives the roguelike structure Greg asked for (open question 4) something to
  hang on: the Horseman in power is the run's character.

None of them should be a health bar in a room. They lead a faction that is
already simulated, so they should be met the way any ranked subject is met.

## What this unblocks

- **F3** gains its content: the CellOutz succession is the first real hierarchy.
- **E5** gains its entities: the wizardsonlyfoolz ranks.
- **E7** gains both endings in concrete terms.
- **E2**, blocked on Greg naming the order, is now answered — the order is
  `wizardsonlyfoolz`, and its seals are the ascending vocabulary. The bastardised
  Thelema question in `RITUAL_AND_KARMA.md` resolves the same way: the collective
  is the institution being satirised, and it is entirely this world's own.
- **`FACTION_TREE_AXIS`** needs both new factions added, with CellOutz well below
  the existing descending factions and wizardsonlyfoolz well above the Gate
  Lanterns — the existing five become the middle of the table rather than its
  extremes.

## Still open for Greg

1. The four Horsemen's names in this world — the traditional four, or Ashbloom
   equivalents?
2. Are the Gate Lanterns part of wizardsonlyfoolz, or a rival ascending faction?
3. Does the player's half-and-half nature have a *mechanical* expression beyond
   starting at 0.0 — can both ends be climbed at once, or does committing to one
   close the other?

## The hierarchy below — captured 2026-09-12

Greg: *"4 horsemen, 7 deadly sins, lesser demons roaming the world, using the
nemesis system, demon structure of the forts being created with the abstracted
internet world."*

Four tiers, and every one of them runs on machinery that already exists.

| Tier | Who | Runs on |
| --- | --- | --- |
| **Leadership** | The Four Horsemen, rotating | F3 promotion into real vacancies |
| **Princes** | The Seven Deadly Sins | `FACTION_TREE_AXIS` principles |
| **Captains** | Named rivals like Mara | The Hunt System as built |
| **Lesser demons** | Roaming, generated | F4.1 rivals born out of events |

**The Sins are already half in the code.** `FACTION_TREE_AXIS` gives four
descending factions a principle each — Ashline is Wrath, Black Mile is Greed,
Soft Rot is Gluttony, the Choir of Marrow is Envy. Those are not decoration any
more: each is the faction a Sin holds. **Pride, Lust and Sloth have no faction
yet**, which is the gap to fill rather than a system to invent.

### The forts are the internet, and that is the point

This is the part that matters most and Greg got it right without being told.
`DESIGN/FACTIONS.md` already replaced fortress capture with **signal
territory** — feeds, masts, presses, accounts — contested by out-publishing,
discrediting, hijacking, flooding or cutting. A demon hierarchy whose holdings
are *signal* is not a fort assault loop; it is the alternative this project
deliberately chose instead of one.

So: a Sin does not hold a keep. It holds a channel. Wrath owns the feeds that
make people angry; Greed owns the ones that sell; Sloth owns the dead forums
nobody has closed. Taking one off them is an argument, a hijack or a cut mast,
which is the play `FACTIONS.md` already specifies and which nobody else's game
does.

`HUNT_SYSTEM.md`'s boundary still stands and is easy to hold here: no named
hierarchy tiers lifted from anyone, no fort assault structure, no
follower/betrayal command layer. Tiers named after the Sins and holdings made of
signal are this world's own.

### Why this is strong rather than just big

The four tiers give the Hunt System something it has never had: **a reason for
promotion to matter**. Killing a lesser demon is noise. Killing a captain opens
a post. Killing a Sin changes what an entire faction *is about*, because the
principle is what the faction's axis and pricing already read from. And killing
a Horseman changes who runs CellOutz, which is the run.

