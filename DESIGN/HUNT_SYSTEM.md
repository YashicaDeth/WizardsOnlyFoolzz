# The Hunt System

Persistent rivalry architecture. This is the system Greg refers to as "the
nemesis system," and it is the one place in the project where the difference
between *copying an implementation* and *delivering an experience* has real
consequences.

## Why this is not a Shadow of Mordor clone

Two reasons, and the second matters more than the first.

**It is patented.** Warner Bros holds US Patent 10,926,179 ("Nemesis
characters, nemesis forts, social vendettas and followers in computer games"),
granted 2021 and in force into the mid-2030s. That patent is the reason no
other studio has shipped a Nemesis-style system in over a decade of obvious
player demand. A deliberate 1:1 reproduction of the claimed architecture is the
single most legally exposed thing this project could build, and it would sit
inside a game that also carries Greg's real name and art.

**The Master Codex already ruled on it.** §6: *"Create an original persistent
rivalry architecture inspired only by the broad appeal of recurring memorable
enemies. Do not copy the proprietary Nemesis implementation or its protected
presentation."* This document follows that instruction.

The good news is that what the patent claims and what makes the system *feel*
good are not the same thing. Nobody remembers Shadow of Mordor for its
hierarchy data structure. They remember that an orc they failed to kill came
back scarred, named, and angry. That experience is not owned by anyone, and it
can be produced by better machinery than Mordor used.

## Where this project can go further

Mordor's memory is a flag table. An orc records "player used fire" and gains a
burn scar plus a fear of fire. The consequence is authored, not simulated.

This project already has systems Mordor never had, and they are the reason the
Hunt System can be deeper rather than merely different:

| Already built here | What Mordor did instead |
| --- | --- |
| `AnatomyComponent`: real zone health, blood volume, bleed rate, severed limbs, persistent snapshots | A scar flag on a template |
| Prosthetics with compatibility, cost and maintenance rules | Cosmetic armour variation |
| A faction economy with supply chains and wealth | Abstract power ranking |
| A Character Tree of real typed relations | Implicit hierarchy |
| The desolate internet and the CellOutz Wire | Nothing equivalent |
| Tree of Life alignment (Ascent/Limbo/Descent, Sin-pulls) | Nothing equivalent |

## The six mechanisms

### 1. The wound is the memory

A rival does not remember "the player hurt me." The rival *has* an injury, and
the adaptation is derived from it. Mara losing a left arm is not a flag, it is
a zone at zero health in a persistent anatomy snapshot. What follows is
simulation, not scripting:

- the injury degrades her driving and combat ratios via `mobility_ratio()` and
  `combat_ratio()`, which already exist;
- her faction must *pay* for a replacement, drawing on faction wealth;
- the Choir of Marrow are the ones who sell it, which creates a debt and a
  relationship she did not previously have;
- the installed prosthetic changes her combat style, silhouette and ELO;
- the World Index and her dossier update because they read the same record.

This is the loop §21 of the Codex asks one Captain to prove. It is partially
implemented today as `next_adaptation`.

### 2. Promotion fills a real vacancy

Killing a captain leaves an actual hole in an actual hierarchy. The replacement
is not generated from a template: it is someone who already existed in the
world, with their own relations, wounds and history, who was plausibly
positioned to take the post.

Per Codex §7, rank is not combat skill. Promotion weighs influence, wealth,
faction loyalty and who owed whom — so the successor may be a weaker fighter
with better connections, and the player may find that *more* dangerous.

### 3. Grudges travel along real edges

Mordor orcs simply know what you did. Here, knowledge propagates:

- **Witnesses.** Events already record participants; they must also record
  witnesses. An act with no surviving witness does not enter faction knowledge.
- **Relation edges.** A grudge spreads along the Character Tree from witness to
  ally to faction, decaying and distorting with distance.
- **The Wire.** The surviving internet is a second transmission channel with
  its own latency and unreliability.

This creates a mechanic Mordor has no equivalent for: **you can cut the
transmission.** Kill the witness before they report. Discredit the feed. Let a
wounded rival escape knowing they will spread a version of events that is
wrong in your favour. Information being partial, late or false is already a
core pillar (§13) — the Hunt System is where it becomes tactical.

### 4. Distortion

Each retelling mutates the record. What the world believes about an encounter
should drift from what the event log actually says. The player's own
reputation becomes a rumour they cannot directly edit, and the Compendium can
display a confident account that is simply untrue.

### 5. Alignment drift

Implemented today. Faction birth sets a baseline pull on the Ascent/Descent
axis and personal bonds and grudges drift a subject from it. A rival pushed
far enough toward Descent becomes something structurally different — not a
higher-level version of the same enemy, but a different kind of problem.

### 6. Bonds use the same machinery

Per Codex §8, friends are the mirror, not a separate feature. Bonds propagate,
distort and promote through the same code paths. A friend who witnesses a
kindness spreads it; a friend promoted into a faction post becomes leverage.

## Implementation order

Each step is playable on its own.

1. **Witness records** on events. Cheap, and everything downstream needs it.
2. **Propagation pass**: grudge/bond spreading along relation edges with decay.
3. **Adaptation from anatomy**: derive the rival's next state from real injury
   plus faction wealth, replacing the hand-written `next_adaptation` string.
4. **Vacancy and promotion** when a ranked subject dies.
5. **LimboAI behaviour trees** for tactic adaptation — currently installed and
   entirely unused. Hand-rolling this a second time is the larger cost.
6. **Distortion layer** on retellings, surfaced through the Wire and Compendium.

## Territory

Rivals hold territory, but not fortresses. Factions contest two separate
things — **signal** (feeds, masts, presses, the chaotic media amalgamation) and
**ground** (camps, towns, yards, raided Rust-style with a crew assembled from
real bonds, debts and shared grudges). Signal control gates how grudges
propagate, which couples this system directly to the territory game.

Specified in `DESIGN/FACTIONS.md`.

## Boundary

Do not reproduce Mordor's specific claimed architecture: its named hierarchy
tiers, fort assault structure, follower/betrayal command layer, or its
distinctive presentation of these. Original terminology, original mechanics,
original presentation. The test to apply is not "does this feel like Mordor"
but "does this produce an enemy the player will talk about afterwards."
