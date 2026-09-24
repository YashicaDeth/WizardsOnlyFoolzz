# Bingyang, bingyangas and bingyangers

Terms defined by Greg, 24 September 2026. Decisions below are his; the section
marked **Assistant proposals** is not.

## Greg's words

> "bingyanga is a person who is apart of the mental and physical support unit
> in a facility and are insane like outlast paitents in the mental asylum while
> getting tortured"

> "a bingyanger is a broken out paitent like a ghoul from fallout who is mutated
> and insane clincically and can be positive or negative to the player randomly
> choosing and with voice lines talking to them and saying crazy lines"

> "they are some of the mutated people who have broken out of the vats to keep
> the vats orignal"

## Definitions

**Bingyang** *(the condition)*: the madness and mutation the vats and the
torture produce. It isn't a place or a faction; it's what is wrong with
someone.

**Bingyanga** *(plural bingyangas)*: someone with bingyang who is still held.
A vat subject who mutated and was moved into the facility's **Mental and
Physical Support Unit**, where they are tortured. They are clinically insane in
the way Outlast's asylum patients are: restrained, screaming, and not in
control of what is happening to them.

**Bingyanger** *(plural bingyangers)*: someone with bingyang who got out. A
mutated person broken out of the vats, like a ghoul in Fallout: visibly mutated
and clinically insane. Each one talks to the player in its own voice and says
crazy things, and each one is **randomly friendly or hostile** to the player.

They come from the same vats as the player. The vats stay the single origin:
the player is what came out whole, and bingyangers are what came out wrong.

## Decided (24 September)

- **One life, two stages.** Vat subject, then mutated, then moved into the
  Support Unit and tortured (bingyanga), then out (bingyanger).
- **The player frees them.** They don't break out on their own and aren't
  already loose when the player wakes. Letting one out is the player's choice.
- **Attitude re-rolls every meeting.** The same bingyanger can help you now
  and attack you the next time you meet.
- **Where, in the first 30 minutes:** all four places:
  - a Support Unit ward on the escape route (cells, restraint beds, bingyangas
    being tortured, cells you can open);
  - vats on the Growing Floor you can smash to free the subject inside;
  - seen through observation glass while the player is still captive in the
    vat;
  - loose in the tunnels: the ones you freed turn up again in the drain
    tunnels and Lower Works on the way out.
- **Friendly:** fights beside you, gives you things (a key card, a round, an
  organ, junk), tells you things (crazy talk that is sometimes true: a patrol
  route, a door code, another exit), distracts the guards.
- **Hostile:** attacks you, screams until the guards come, steals something
  you're carrying and runs, stalks you at a distance and taunts you.
- **Voices:** the game's own generated voice, the same pipeline as the
  examiner, pitched and distorted per bingyanger. Lines can be written and
  tested now.

### Decided later the same day

- **What they say:** horror (pleading, screaming about what was done to
  them, praying to nothing), funny-insane (non sequiturs, cheerful about the
  wrong things) and prophetic (cryptic lore about CellOutz, the vats, the
  Godhead, sometimes true). Not "about you" as its own register.
- **Freeing one from a vat, loud or quiet:** smash the glass with the
  restraint (fast, but the noise brings Hollis), or open the drain valve
  with E (quiet, but slow).
- **Look:** each one different, rolling its own mix of ghoul skin, growths
  (tumours, fused parts, an extra limb) and unfinished, half-grown bodies.
- **Mortality:** they die like anyone. Same anatomy, the guard can shoot
  them, the player can kill them, and the world records it.

## Assistant proposals, not confirmed

- **Freed from either place.** Greg chose both "the Support Unit ward" and
  "vats you can smash". Read together, smashing a vat frees a subject straight
  from the vat, and opening a cell frees a bingyanga from the Unit. Both
  produce a bingyanger.
- **The existing failed tanks are the smashable vats.** `vat_chamber.gd`
  already lines the aisle with tanks, "most of them failed", and SUBJECT 0C-4
  in the jammed tank "failed the same cycle you walked out of". Those are
  where the first bingyangers come from.
- **They meet the D-section gate.** A friendly bingyanger that distracts
  Hollis is a fifth way past the biometric door
  (`systems/facility_checkpoint.gd`). A hostile one that screams brings him
  down the aisle at you.
- **The mood re-rolls, but the world still keeps records.** Each meeting
  (what they did, what you did) goes into `WorldHistory` like any other fact.
  Only their attitude is rolled fresh.

## Still open

- Can a bingyanger be kept, as a companion or in the pet slot (like Hornee),
  or does it always drift off?
- Can the player become a bingyanga: recaptured and taken to the Unit, or a
  rebirth that goes wrong?
- What does killing one cost: karma, or witnesses?
- What CellOutz calls them officially, and whether the Wire reports on them.
