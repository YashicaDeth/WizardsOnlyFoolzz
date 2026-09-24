# The Vat — character creation, races, traits and the chart

Captured whole from Greg, 2026-09-11. Recorded before building because the
parts only mean anything together, per §10 of the brief.

## Why this goes in the vat

Two open problems close on one answer.

`ROADMAP.md` already carries **"the opening is cool but kinda lacklustre"** —
`vat_chamber.tscn` works and is under-directed. Separately the game has **no
character creation at all**: `bone_yard_hunt.gd` registers a `player` subject
with hardcoded values and that is the whole of it.

The creator is the direction the opening was missing. New Vegas' Doc Mitchell
is the reference Greg named: you are horizontal, someone is leaning over you
asking questions, and the entire character sheet gets built inside a scene that
is also the story's first beat. Here you are submerged in growth medium with a
feed tube in your mouth and umbilicals in your gut, and a handler with a
clipboard is filling in your intake form.

**You cannot speak.** The tube is in. That is not a limitation to work around,
it is the best joke available and it should be the spine of the sequence: the
handler asks, you answer by blinking or twitching a hand, and *he writes down
what he thinks you said*. Your character sheet is a document produced about you
by a bored man on a night shift. That is §13's pillar — information is partial,
late, manipulated or false — applied for the first time to the player's own
record, in the first five minutes.

## Four routes in

Any route lands in the same editable sheet. Nobody is forced through a
questionnaire to play.

1. **PRESET.** Authored characters with lore attached. Fast, canonical, and the
   one a returning player takes.
2. **RANDOM.** The decanting lottery. The vat gives you what it gives you, and
   the handler does not care.
3. **CHART.** Real birth date, time and place. Stats derive from the natal
   chart. Greg's name for it is "space racism" and the register is exactly
   that — the intake form asks for your birth time with total bureaucratic
   sincerity.
4. **INSTRUMENT.** The personality questionnaire, scored on real psychometric
   axes, bent toward the dark triad because of what you are being grown for.

## The chart route

`systems/natal_sigil.gd` already exists, already draws a wheel, and already has
Greg's own chart bound into the archive. It is the foundation; what is missing
is the chart producing *numbers*.

The reference Greg named is **Skyrim's standing stones** — a birth-determined
blessing that is felt all game and never has to be re-explained. That is the
right shape: one **Ruling House**, plus a stat distribution, plus a progression
start point.

- **Element balance** across the placements — fire, earth, air, water — maps to
  four attributes. A chart heavy in one element produces a specialist; an even
  chart produces a generalist with no peak.
- **Modality** — cardinal, fixed, mutable — sets a behavioural axis: how fast
  you commit, how hard you hold, how cheaply you change. This is a real
  mechanic against the Hunt System, where adaptation is the enemy's whole trick.
- **The ascendant sets clout**, not combat skill. It is how the world reads you
  before it knows anything, which is precisely what the Wire's reach number
  already models. A chart can hand you a face people trust and a body that
  cannot fight.
- **The ruling house is the skill tree's entry point.** See below.

Accuracy matters to Greg and should be taken seriously: real tropical zodiac,
real element and modality assignments, real rulerships. Full ephemeris-grade
planetary positions are a larger job than sun sign and a time-derived house
wheel, which is what the sigil computes today. **Decision needed:** ship the
derived wheel, or carry an ephemeris table for true planetary longitudes. The
first is buildable now; the second is what "most accurate" actually means.

## The instrument route

Real axes: the five-factor model, plus the dark triad — narcissism,
Machiavellianism, psychopathy. **Write original items.** Published inventories
are licensed instruments and this game carries Greg's real name; the axes are
scientific common property, the question wording is not.

The satire is in the scoring, not the questions. **The instrument is not
neutral and does not pretend to be.** It is onboarding for something being
grown to hunt people, so it reports high dark-triad scores as *aptitudes*,
congratulates you on them, and files the result. A player who answers honestly
and decently gets told, politely, that they are a poor fit for the role, and
then gets decanted anyway because the debt is already in the meat.

The output is real stats. That is what stops it being slop: the personality
test is load-bearing, so filling it in truthfully has consequences you feel
forty hours later.

## Opt-in modifiers — difficulty as belief

Greg's list: 5G, a neural chip, "all the vaccines." Each is an intake checkbox
with a short authored cutscene, and each is a real mechanical trade.

The pillar that makes this work is already written into
`DESIGN/IN_GAME_INTERNET.md`: **in a world that actually had an apocalypse, the
conspiracy poster is sometimes right.** So the chip *works*. It gives you Wire
connectivity without a mast, a map overlay, and the ability to be answered by
accounts that would otherwise ignore you — and it also means the Wire can trace
your position, a faction can task you remotely, and the mind-stamp path in
`ROADMAP.md` Tier 1d has a socket to press into. The paranoid were correct, the
trade is still obviously worth taking, and *that* is the joke.

Named fictionally, always: **NEURALACE**, the **mast tithe**, the **full
schedule**. Boundary, and it is not negotiable given the register: the target
is the institution shape — the company that owns the socket, the platform that
reads it, the clipboard that files it — never a real firm, and never a claim
about real medicine. The humour is that this world's apocalypse made the
cranks right. It is not an argument that they are.

Harder difficulty comes from *declining* them: no chip means no overlay, no
signal off the masts, and the underbelly needs a physical terminal.

## The mirror

On a swing arm over the tank. Dark Souls' slider depth, played for stupidity.

Two rules make it this game's creator rather than a generic one:

- **The preview is wrong.** You are looking at yourself through growth medium
  and curved glass. The face you are editing is not quite the face you get, and
  it only resolves after you are decanted. Cosmetic, cruel, funny, free.
- **You edit under the skin too.** The X-ray dossier, `kill_cam.gd` and
  `baseline_human.gd` already draw the real skeleton and the real organ set, so
  the creator should let you choose them: bone density, organ set, blood type,
  and which cybernetics you were grown with. Cruelty Squad and Wrought Flesh is
  the register, and unlike a normal creator every choice here is visible later —
  the first time somebody opens you up, that is the set you picked.

## Races — what the Reset made

Not fantasy species. The world already specifies runaway fungal ecology, decayed
cybernetics, buried anatomical industry and the Ascent/Descent axis, so the
races are consequences of it. Each carries a silhouette change on the shared
rig, a metabolism, a social price, and a baseline pull on the Tree axis that
`WorldHistory.tree_alignment()` already supports.

- **DECANTED.** Vat-grown, the default. No kin, no history, a debt in the meat.
  Cheap to replace and everyone knows it.
- **SOFT ROT.** Mycelial graft. Recovers in spore-heavy air, suffers in clean
  air, and reads as contagious to everyone who is not Communion.
- **MARROW-CUT.** The Choir's surgery. Bone replaced to rewrite allegiance:
  durable, strong, and structurally owned by someone.
- **ROADBORN.** Raised on the highway, cybernetic since childhood, tolerant of
  fuel and radiation, illiterate in anything that is not a machine.
- **UNRESET.** Actually alive before the flash and should not be. Fragile, slow,
  and knows things nobody else can know — which is leverage, and a target.
- **LANTERN-BORN.** Gate Lantern stock, raised to the Ascent. Socially trusted,
  which the Hunt System can take away.

## Traits — the intake checkboxes

Project Zomboid's model: a point budget where positives cost and negatives
refund. The register is bureaucratic and crude. Every trait below hooks a
system that **already exists**, which is the bar for adding one.

| Trait | Effect | System it uses |
| --- | --- | --- |
| HOSPITAL STRENGTH | +2 physical, −2 composure; you do not feel the break until after | `anatomy_component` pain vs health |
| NO PAIN RECEPTORS | Pain never reports, so you do not know you are bleeding out | pain/blood volume split |
| CLERICAL ERROR | Part of your sheet is transcribed wrong. You are not told which part | the sheet itself |
| PRE-OWNED ORGANS | Free cybernetics; somebody holds the lien and will collect | cybernetics slots, debt |
| DOOMSCROLLER | Wire strain accrues faster, rumours reach you earlier | Wire strain, distortion |
| FAMOUS FOR SOMETHING | Start with clout and a face people recognise | Wire reach, witnesses |
| SPEAKS WHEN NERVOUS | Proximity voice carries further — to everyone | `proximity_voice.gd` radius |
| THE TUBE STAYED IN | Cosmetic, permanent, mild breathing penalty, never mentioned | rig attachment |

Greg's example was "retard strength, +2 strength and a mental debuff." That is
HOSPITAL STRENGTH above — same joke, same numbers, renamed, because
non-negotiable 3 in `AGENT_BRIEF.md` puts the satire on institutions and power
and never on a real group of people. The crudeness stays; the target moves.

## The skill tree is the chart

Greg's closing note, and it is the one that unifies four screens.

The Allusions artwork archive, the natal sigil, and progression may eventually
become one object inside the creator/progression route. They are deliberately
not exposed on `J` during ordinary play before the player has supplied a birth
or chosen the chart route. Your Ruling House is where you stand on the wheel. Progression is
**walking the wheel** — each house governs a domain, unlocking a house unlocks
what it governs, and the path you take between them is visible as a drawn
figure on your own chart. By the end of a run the sigil is a record of what you
became, which is the same "bodies remember" pillar pointed at the interface.

This is the same instinct as the handheld in `DESIGN/IN_GAME_INTERNET.md` —
stop having six fullscreen panels on six keys — and both should be built toward
each other rather than separately. Until that route exists, the underlying
artwork and sigil controls remain dormant rather than presenting Greg's
placeholder chart as the player's established identity.

## Build order

Nothing here is scheduled until the Wire and HUD pass in `ROADMAP.md` lands.
When it is taken, this order keeps each step playable on its own:

1. **The sheet.** A real `player` subject built from data instead of the
   hardcoded dict in `bone_yard_hunt.gd`. Everything below writes into it.
2. **Traits and the point budget.** Highest value per line of code, because
   every trait listed above drives machinery that is already built.
3. **The intake scene.** Handler, clipboard, blink-to-answer, mistranscription.
   This is also the fix for the under-directed opening.
4. **Races**, as rig silhouette plus metabolism plus Tree pull.
5. **The chart route**, deriving stats from `natal_sigil.gd`.
6. **The instrument route.**
7. **The mirror**, including the under-skin editor.
8. **Opt-in modifiers** and their cutscenes.
9. **The wheel as skill tree**, merged with the Allusions archive.
