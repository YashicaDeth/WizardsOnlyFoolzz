# Player direction interview — 18 September 2026

This document preserves Greg's answers to the player-experience interview. It
is authoritative for the direction below. It does not turn unanswered prompts
or implementation suggestions into lore.

Provenance is explicit where it matters:

- **Confirmed** — Greg stated the direction directly or approved it in the goal.
- **Working recommendation** — a practical layout or interpretation proposed in
  response; useful for implementation, but still open to visual feedback.
- **Open** — deliberately unresolved and not authority to invent an answer.
- **Implementation note** — what the current build does, not a design mandate.

## Vocabulary

`holding` is an internal territory/save identifier, not the preferred word in
player-facing copy.

- **Territory** — a bounded part of the world map.
- **Settlement** — an inhabited town or community inside a territory.
- **District** — a smaller named part of a city or underground network.
- **Outpost, base or camp** — a faction's local source of control.
- **Facility** — a substantial institutional site such as the opening complex.

Code and save identifiers containing `holding` remain stable unless a deliberate
migration is written. UI and new design prose should use the specific term above.

## Opening experience

The opening should make the player feel imprisoned, tortured and humiliated,
then fill them with the drive to become free and seek revenge. The player is an
experimental, repeatedly revived entity whose soul remains bound to Earth. The
larger prison-world and Godhead ideas should unfold through play rather than
delay the first comprehensible objective:

> **ESCAPE THE FACILITY**

Character creation belongs inside the institution's attempt to manufacture or
reconstruct the player. A concise sequence of repeated suffering builds an
ember-like magical force in the soul. The first playable breakthrough may be a
vision, memory or newly gained ability that lets the player break containment.
The full screenplay, named authority figure and exact breakthrough remain open.

The opening facility is a large connected underground world, not a linear lab:

- industrial prison and occult corporate laboratory;
- trafficking tunnels, catacombs and underground settlements;
- elevators, maintenance networks and routes into the wider world;
- keys, codes, hacking, destructible barriers and later ability gates;
- several escape approaches with persistent consequences.

The underground derby is one possible route after capture, not the mandatory
route for every play style. Cooperation followed by betrayal, exploration,
stealth and an extraordinarily difficult direct assault are also valid. A rare
early victory must be remembered rather than undone to protect a fixed plot.
If a recapture occurs, an established containment mechanism should cause it;
the game must not invalidate a successful playable escape with an arbitrary
cutscene loss.

The derby is the institution's attempted public humiliation: prisoners,
experiments and constructed fighters are consumed as entertainment in an
underground vehicular colosseum. Turning its winning vehicle against the
facility is a possible spectacular escape and a reason senior powers notice the
player.

## Factions and hierarchies

There is no single universal pyramid. Government, military, elites, raiders,
demons, angels and other major powers have their own hierarchies, with alliances
and overlaps between them. Leadership vacancies and relationships should change
those structures rather than preserve fixed quest characters.

CellOutz is fundamentally the demon faction: the ones who got “out of the
cell.” Its corporate products and bounty platform express demonic culture.
The platform can carry work published by many characters and factions; reward,
access and relationship effects depend on who issued it and their rank and
resources. Demons are cynical, contractual, tricky, amused by corruption and
comparatively direct about ugly acts, but individual demons can be practical,
restrained, exhausted or tired of performing evil.

Angels are not automatically benevolent. They are proud, self-deifying and can
be institutionally corrupt in a different register. Their exact relationship
to wizardsonlyfoolz remains open.

The player may work with opposed powers while pursuing the larger aim of
freedom from repeated earthly rebirth and the Godhead's consciousness.

## Territory change

Liberation is a progression, not one captured icon and not a binary
ascent-versus-corruption menu choice:

1. **Oppressed** — a local structure dominates people and resources.
2. **Disrupted** — operations, officers, income or supply have been damaged.
3. **Power vacuum** — former control has failed, but normal life has not returned.
4. **Recovering** — people, trade, services and construction begin to return.
5. **Secured or contested** — a community, faction or the player maintains control.
6. **Reoccupied** — an enemy wins an actual later campaign.
7. **Desolated** — population and infrastructure have been deliberately ruined.

Local controlling structures can include fictional military bases, bandit
camps, cartels, traffickers, organ markets and alien installations. Removing
one can improve nearby life without instantly resolving the whole territory.
The player may support local self-rule, install a faction or individual, claim
control, extract value and leave a vacuum, or worsen/desolate the area. The
exact transfer act and its cost are deliberately unresolved.

Recovery should gradually improve population, happiness, productivity, work,
trade, lights, services, buildings and defensive strength. Procedural rebuilding
must preserve history: scars, foundations, survivors, reputation and the identity
of whoever rebuilt remain visible and recorded.

Recovered settlements can face occasional meaningful invasions, not constant
maintenance spam. Allies may send a live request for help. Ignoring it can allow
reoccupation, but earlier work still matters through defenders, resistance and
relationships. Recovered territories can eventually contribute people and
resources to large player-led assaults.

Willing recruitment and psychic/neural domination are distinct. A dominated
character remembers coercion, carries different social consequences and can
break control or betray the player.

Corruption may poison weather, land, architecture, population, vegetation and
infrastructure. The distribution and severity still need an art-direction pass.

## Perspective, combat and traversal

First person is embodied, precise and more demanding, but ordinary fights must
remain brutal-and-manageable rather than nearly suicidal. It is strongest for
roleplay, shooting, sniping, hand-cast magic and optional close combat.

Third person is an earned combat stance, not merely another camera angle. It
provides stronger crowd awareness, readable character animation, fluid combos,
lock-on, dodging, executions and expressive traversal. Most actions can remain
available in both perspectives with different strengths. A deployable
cybernetic/360-degree camera is a promising explanation, particularly for
collision, darkness, interference and hostile surveillance, but it is not yet
permanent lore.

Combat should balance deliberate weapon positioning with expressive combos.
Stamina exhaustion should be embodied through breath and reduced capability,
but its exact failure behaviour remains open.

Grappling should begin with readable basic actions and expand through learned
boxing or wrestling techniques. Physics make bodies responsive; inputs should
still express an intended clinch, throw, takedown or control rather than produce
unreadable accidental wrestling.

Gun fights should be anatomy-driven and longer than the current casual one-shot
encounters without becoming health-bar attrition. Armour, mutation, organs,
bones, blood loss, limb function, incapacitation and supernatural anatomy must
visibly explain durability. Different characters need believable power classes.

## Inspection and smoking

Inspection has one discoverable input grammar but bespoke choreography for each
object class. The world continues moving. Visual condition, function, ownership,
anatomy and hidden knowledge should be composed around the object instead of
appearing as generic coloured text at the bottom of the screen.

The cigarette is the first gold-standard smoking interaction. The bong remains
another candidate benchmark rather than a confirmed second-place ordering. The
cigarette needs convincing hand-to-mouth and lip placement,
persistent length/ember/ash, repeated puffs, a mouth-held state compatible with
weapons, and a chance to be disturbed or knocked loose by impacts and movement.
Cigarettes are primarily atmospheric. Joints, spliffs and bongs may create a
stronger green/woozy presentation without making the game unplayable. Permanent
addiction and long-term balance remain open.

## Interface and the Black Mirror

**Confirmed:** the interface should be structurally clean enough to receive Greg's own art,
textures and collage work. It should be relatively quiet in ordinary play and
become oppressive contextually rather than covering every corner permanently.

**Working recommendation for the next structural pass:**

- Top right: emotion/state portrait with narrow vertical body-resource columns.
- Top left: contextual anatomy and implant diagnostics.
- Bottom left: phone-derived local map/radar whose precision reflects access.
- Bottom right: a physical carried-device/item presence, not an oblong inventory well.
- Centre: mostly empty outside aiming and interaction.
- Border: artistic game framing, not currently literal eyewear.

The Black Mirror is useful, desirable and compulsory. The player resents being
chained to the same device that enables surveillance and control. Phones are
common, but advanced AI/LLM neural integration is not universal, and the
player's device can be valuable to other people.

At interview time, the G/phone interaction, unexplained J birthday/resonance
flow and incomplete pointer/keyboard navigation were specifically rejected.
Birthday, role and related resonance choices belong in proper character
creation rather than an unexplained ordinary-play panel. Useful underlying
resonance systems may remain dormant until that route exists. The present
Ritual and Wire presentation is also unapproved rework material even where its
underlying systems remain useful.

**Implementation note:** commits `b9af4ef` and the subsequent J access repair
made all seven phone tabs clickable/directly reachable and removed the natal
chart from ordinary Hunt play. Broader phone, Ritual and Wire presentation
remain open to the narrated playtest.

## Reference field

The reference field includes *Cruelty Squad*, *Fallout 3*, *Prototype*,
*Alien*, *The Thing*, *Postal 2*, *Grand Theft Auto IV/V*, *Silent Hill 1/2*,
*Princess Mononoke*, *Nausicaä*, *The Mighty Boosh*, Basquiat, Jesse Moynihan,
*The Midnight Gospel*, *The Walking Dead* comics, *Shadow of Mordor/War* and
*Valheim*. These are inputs with different functions, not a request to flatten
the project into one generic “grimy surreal horror” style. A separate visual
mind-map pass remains required.

## Deliberately unresolved

- the practical or supernatural act that transfers a territory;
- what prevents every territory being given freely to one favourite faction;
- the opening screenplay and named authority figures;
- whether third person is literally an external cybernetic camera;
- exact stamina-collapse behaviour;
- permanent addiction and drug balance;
- angel/wizardsonlyfoolz relationship;
- final visual hierarchy and territory-corruption art direction.

These questions should be recorded when encountered. They do not block work on
controls, current combat readability, animation anatomy, inspection grammar or
the factual territory states that precede the transfer decision.

## Evidence still requested

The next narrated playtest should gather observations rather than reopen the
abstract interview:

1. Press G and say what was expected.
2. Navigate every Black Mirror page.
3. Press J and identify any remaining comprehension break.
4. Shoot several enemy types and call out trivial or spongey wounds.
5. Fight the same encounter in first and third person.
6. Grapple and compare intended movement with the result.
7. Mouth-hold a cigarette and attempt to use a weapon.
8. Inspect several distinct item classes.
9. Open MAP and explain what each visible mark appears to mean.
10. Name interface elements that are instinctively ignored.
