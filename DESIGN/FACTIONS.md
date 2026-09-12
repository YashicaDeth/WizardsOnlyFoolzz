# Factions, territory and raiding

## Two kinds of territory

Factions hold two different things, and they are contested in completely
different ways. This split is the reason the project does not need — and should
not build — a fortress siege loop.

| | **Signal** | **Ground** |
| --- | --- | --- |
| What it is | Feeds, forums, broadcast masts, presses, art and propaganda channels | Camps, towns, yards, workshops, roadhouses |
| How it is taken | Discredit, hijack, flood, out-publish, cut the mast | Raid it, with people |
| What it gives | Control of what the world *believes* | Control of what the world *has* |
| Lost by | Being disproven, outshouted, unplugged | Being overrun, or burned |

Holding one without the other is unstable, which is where most of the play
lives. A faction with all the guns and no signal is a rumour nobody believes. A
faction with all the signal and no ground starves.

## Signal territory: the amalgamation

A faction's media holdings are not a tidy corporate outlet. They are a chaotic
accretion of whatever survived and whatever was improvised after: a half-dead
forum somebody still moderates, an automated news bot nobody has turned off, a
propaganda art account, a numbers station, a printing press in a garage, a
relay mast someone cable-tied to a water tower. Art, news, conspiracy, advertising
and outright fabrication in the same stream, in the David Dees register set out
in `DESIGN/IN_GAME_INTERNET.md`.

**Taking signal territory is not an assault.** The routes are:

- **Out-publish.** Push your account's reach past theirs. Slow, non-violent,
  and the route available to a player who never wins a fight.
- **Discredit.** Prove a claim of theirs false, publicly. Their reach drops and
  everything else they have ever said becomes suspect.
- **Hijack.** Take the account or the transmitter rather than the argument.
  Needs physical access to a terminal or mast, which is where signal and ground
  touch.
- **Flood.** Drown the channel in noise so nothing propagates, yours included.
  A denial move, not a capture.
- **Cut.** Destroy the mast. Crude, permanent, and it removes coverage from the
  region for everyone, including you.

**Why it matters mechanically:** grudges propagate through channels
(`DESIGN/HUNT_SYSTEM.md`). Owning a faction's channel means owning how their
version of events spreads — or whether it spreads at all. Kill a captain
quietly and hold the local signal, and the faction may not learn who did it.
Lose the signal and your own reputation is written by people who hate you.

This is the replacement for capturing a fortress, and it is more interesting:
the territory is continuous, invisible, and cannot be defended with walls.

## Ground territory: camps and towns

No fortresses, no siege missions, no assault set-pieces. Factions live in
places that look like places — a scrapyard with a fence, a roadhouse, a
tunnel-mouth camp, a workshop town — and those places can be raided.

The register is Rust, not a mission select:

- **You choose the moment.** Raids are not offered. You decide when, and the
  world does not wait for you to be ready.
- **Timing is real.** Settlements have schedules: who is present, who is
  asleep, who is away on a supply run, who is drunk, when the shift changes.
  Scouting is the preparation phase, and it is most of the skill.
- **Defenders behave like residents**, not like a spawned encounter. They wake,
  panic, organise, flee with valuables, or die in doorways. Survivors remember,
  which feeds the Hunt System.
- **You raid for things.** Supplies, prosthetics, a prisoner, a terminal, a
  specific person. A raid with no object is just a massacre, and the world will
  treat you accordingly.
- **Consequences persist.** A burned camp stays burned. Its economic role
  collapses, prices move, the survivors relocate and carry the grudge, and the
  scrapyard economy absorbs the wreckage.

Holding ground is optional and expensive. You do not have to garrison anything;
often the point is to take what you came for and be gone.

## Raiding with people

The crew is the system. NPCs do not join through a recruitment menu — they join
because of history the simulation already records.

Routes into a crew:

- **Bonds.** The mirror of grudges (Codex §8). Someone whose life you saved,
  whose wound you treated, whose trade you honoured.
- **Shared enemies.** The strongest recruiter in the game. Anyone carrying a
  grudge against the target is a candidate, and the Character Tree already
  stores exactly that.
- **Debt.** You paid for their prosthetic. They owe the surgeon. You cover it.
- **Defection.** A demoted or humiliated faction member, especially one you
  humiliated *publicly* through the Wire — which is how the social layer feeds
  directly into a raid crew.
- **Hire.** Money, straightforwardly.
- **Coercion.** Leverage from something you exposed. It works, and it is
  unstable: coerced crew break under pressure and inform afterwards.

Crew are people, not units. They have their own wounds, mobility ratios,
courage, loyalties and opinions about the target. They can refuse a job. They
can die, and it is permanent, and the people who knew them will know who led
the raid. A crew member with a bond to someone inside the settlement is a
problem you should have checked for.

## Why this is not a fort system

Stated plainly so it stays true as the project grows:

- There is no fortress, no siege, no assault mission structure, no capture
  ceremony, and no step where a defeated rival is installed as the holder of a
  captured stronghold.
- Ground is raided for objects and left, not conquered and garrisoned through a
  hierarchy-assignment loop.
- The primary contested territory is informational and continuous, which has no
  equivalent in the systems being avoided.
- Crew come from simulated history — bonds, debts, grudges, defections — not
  from a domination mechanic applied to enemies.

The test remains the one in `DESIGN/HUNT_SYSTEM.md`: does this produce a story
the player will tell afterwards, using original mechanisms.

## Implementation order

1. **Faction ground presence.** Give the existing five factions real locations
   in the Ashbloom districts with residents, schedules and a reason to exist.
2. **Scouting and raid state.** Presence, alertness, and who is home.
3. **Crew recruitment** from existing bond/grudge/debt records, starting with
   one companion.
4. **Raid consequences**: persistent destruction, economic disruption, survivor
   memory, Wire coverage.
5. **Signal assets — built 2026-09-12.** Every Sin-faction now carries a
   `channel` field (`cosmology_factions.gd`/`bone_yard_hunt.gd`) and a tracked
   `signal_control` number, read fresh from the subject rather than cached
   (`wire_net.gd`'s `faction_signal_control()`).
6. **Signal actions — built 2026-09-12.** `wire_net.gd`'s `contest_channel()`:
   out-publish, discredit, hijack, flood, cut, each a real requirement against
   real state (reach, recorded evidence, physical access) rather than a cost
   paid to a menu. See `CHECKLIST.md` K4.4.
7. **Coupling.** Raids generating the events channels report on is still
   Codex's F-territory and unbuilt. The other half — signal control gating
   grudge propagation — has its read-only half built from this side:
   `wire_net.gd`'s `signal_reach_factor(faction_id)` returns `signal_control`
   as a 0-1 multiplier (a half-flooded channel carries a rumour half as far,
   not all-or-nothing). Whoever wires F2's propagation multiplies by it rather
   than reading `signal_control` a second way — an API offered, not an edit
   made into `world_history.gd` or wherever F2 actually lives.
