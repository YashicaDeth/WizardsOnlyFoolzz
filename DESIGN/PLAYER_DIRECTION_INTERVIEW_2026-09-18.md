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

The player does **not** simply spawn into darkness or arrive at a detached
character-creation menu. An authored opening flows into a visible, heavily
surveilled and locked-down laboratory: bright enough to read, but bloodied,
gory, clinically humiliating and filled with esoteric institutional art. The
player is conscious inside a vat while a senior visiting doctor studies them.
A tube prevents ordinary speech or screaming; the implanted brain interface
can expose the player's answers to the examiner, making the examination itself
the frame for choosing name, body and initial character traits. Story beats,
brief playable observation and character creation should alternate in the
Bethesda-style rhythm Greg described rather than front-loading either a long
cutscene or a conventional setup screen.

The examiner is the government's highest-ranking visiting doctor: personally
cruel, but strangely sympathetic rather than clinically empty. His name and
full identity are withheld at first. He records the examination without
consent, tells the player the answers have taught the institution how to break
or kill them, and begins to leave before the next torture cycle. If an
exceptionally skilled player reaches and apparently kills him, medical
reconstruction can return him later with his memory and scars intact. The
victory remains true and begins a personal rivalry; resurrection is not a
cutscene retcon. His exact vehicle remains open.

Creation is distributed through the examination rather than presented as one
detached menu. It includes direct body/face/proportion customisation,
randomisation and reusable presets; body origin; anatomical sex options;
personality instrumentation; and birth date/place/time for a real natal chart.
The player's mechanical choices remain accurate. What can be wrong is the
government's insulting or politically distorted diagnosis of those choices.
The player freely chooses their body origin while the facility assigns its own
institutional classification. Exact birth time may be marked unknown rather
than fabricated. A first deliberate pass should take roughly 10–15 minutes;
saved presets give repeat players a much faster route.

The breakthrough is the player's own soul: accumulated suffering, refusal to
submit and the player's “inner demon” seize and rewrite the government brain
implant into the chaos-magick interface. **There is no separate unknown entity
granting or entering with the power.** The glass ruptures, restraints fail and
the player tears the tube out. The doctor is an urgent revenge target, not a
mandatory timed objective.

The player emerges naked, wounded and helpless. Explicit anatomy may be
enabled; a mosaic/censorship option provides an equally supported presentation.
The opening teaches systems through physical acquisition rather than tutorial
cards: a broken medical restraint/tool, humiliation clothing taken from a dead
failed subject, a biometric guard encounter, a powerful but ammunition-starved
firearm, then a prototype Black Mirror stolen from a restricted technology
room. The outfit begins as institutional degradation and can become the
player's owned identity. Biometric access admits coercing a living guard,
presenting an unconscious/dead body or removing the required hand/finger/head;
later implant spoofing is another earned answer.

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

The opening slice includes the meaningful facility routes—stealth,
exploration, cooperation/betrayal, direct violence and possible recapture into
the derby—until their exits reach the existing surface world. Different exits
may produce different surface starting positions and relationships. Avoiding
the derby is principally a mastery route, though a perceptive first-time player
is allowed to discover it. Death/revival during this opening remains a focused
design problem; until the game's death fiction is authored, ordinary reload is
the honest implementation rather than pretending the question is solved.

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
control, extract value and leave a vacuum, or worsen/desolate the area. Direct
player government is possible, but conspicuous new rule makes the territory a
more attractive target for rival factions. The exact grounded transfer act can
vary with the recipient rather than collapsing every political outcome into
one occult button.

Recovery should gradually improve population, happiness, productivity, work,
trade, lights, services, buildings and defensive strength. The player may set
broad priorities while inhabitants, resources and procedural construction
decide individual rebuilding. Even deliberate desolation can eventually
recover, but scars, foundations, survivors, reputation and the identity of
whoever rebuilt remain visible and recorded for a meaningful time.

Recovered settlements can face rare authored invasions, occasional simulation
campaigns and retaliation deliberately provoked by the player—not constant
maintenance spam. Allies may send a live request for help. Ignoring it can
allow reoccupation, but earlier work still matters through defenders,
resistance and relationships. Recovered territories can eventually contribute
people and resources to large player-led assaults, with the player able to set
preparation, leadership, objectives and tactical commands.

Willing recruitment and psychic/neural domination are distinct. A dominated
character remembers coercion, carries different social consequences and can
break control or betray the player.

Corruption may poison weather, land, architecture, population, vegetation and
infrastructure. The distribution and severity still need an art-direction pass.

## Perspective, combat and traversal

First person is embodied, precise and more demanding, but ordinary fights must
remain brutal-and-manageable rather than nearly suicidal. It is strongest for
roleplay, shooting, sniping, hand-cast magic and optional close combat.

Third person is a technological combat stance, not merely another camera angle.
Camera hardware is implanted from the beginning but imprisonment prevents the
player controlling it; the chaos rewrite exposes it and early play stabilises
it. The working physical form is a micro-camera/drone projected from a socket
at the back of the head, combining a real external viewpoint with the implant's
sensor reconstruction. It normally switches freely, but cramped interiors can
force it close or back into first person, while darkness, injury, interference
and particular enemies can disrupt it. A later free-flying drone mode is
possible but is not part of the first combat implementation. Third person
provides stronger crowd awareness, readable character animation, fluid combos,
lock-on, dodging, executions and expressive traversal.

Combat should balance deliberate weapon positioning with expressive combos.
Both perspectives resolve through the same anatomy, weapon condition, wound
depth and ballistics. First person supplies precision, manual positioning,
shooting, inspection, claustrophobic brawling and hand-cast magic; third person
supplies crowd awareness, lock-on, longer combo grammar, directional dodges,
throws, executions and expressive traversal. A bullet never changes damage
because the camera changed.

Stamina is charged for meaningful exertion rather than every ordinary action.
Exhaustion first produces breathing, weak guard, slower recovery and reduced
capability. Forcing an already exhausted body costs consciousness, stresses
muscle/heart and can eventually cause a stumble or collapse.

Grappling should begin with mouse and movement-key direction—grab, pull, push,
turn, restrain and strike—then expand through learned boxing or wrestling
throws and takedowns. Physics make bodies responsive; inputs still express an
intended action rather than producing unreadable accidental wrestling.

Gun fights should be anatomy-driven and longer than the current casual one-shot
encounters without becoming health-bar attrition. There are no rigid enemy
tiers or arbitrary boss-health multipliers: recognisable anatomy profiles make
durability legible through dense tissue, bone, armour, implants, displaced or
duplicated organs and supernatural regeneration. “Boss” describes an
encounter, not a social rank or hidden health multiplier. Actual destruction
of the brain remains decisive; weak ammunition may fail to reach it, while
rare destructive rounds can produce immediate catastrophic wounds. Important
lethal impacts may receive a brief physical slow-motion/X-ray presentation
without changing the result.

Most strangers begin cautious or neutral. Personality, faction, territory,
fear and the player's conduct escalate them; predators, raiders, traffickers
and desperate aggressors may hunt on sight. Sandbox bodies begin harmless and
become hostile only through a clear physical control.

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
chained to the same device that enables surveillance and control. The stolen
prototype cannot be discarded: over the game the player hacks it, makes it
theirs and cuts government control rather than throwing away a central tool.
It is held physically in the live world; an enlarged view retains real danger.
Its map can carry institutional manipulation and deliberate traps as well as
incomplete knowledge—the device's source and confidence must therefore be
legible rather than every marker being treated as divine truth. Phones are
common, but advanced AI/LLM neural integration is not universal, and the
player's device can be valuable to other people.

Inventory exists independently because it precedes the Black Mirror. It is one
body/equipment interface: the real dressed and wounded character, clothing,
armour, weapons, attachments and combat stances. Selecting the brain enters the
Brain Index inside the same object; memories, records, character documentation,
working theories and the conspiracy board live there. Body searching uses the
same physical grammar for pockets, clothing, weapons, implants, organs and
neural data. Inventory may slow the world but never makes danger disappear;
exact bindings wait for the binding audit rather than stealing another key.
Ordinary HUD furniture remains quiet while the player is safe and healthy,
then wakes for wounds, exhaustion, lungs, threats, navigation and operated
equipment. The artistic frame can physically degrade, crack and misregister
with the body/device state.

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
- the full opening screenplay and the examiner's deliberately hidden identity;
- the opening death/revival fiction beyond ordinary reload;
- final physical form and free-flight rules for the third-person micro-camera;
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
