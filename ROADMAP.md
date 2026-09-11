# Roadmap

## How this project is worked

Greg owns art direction, world, taste and every final decision. AI agents are
engineering partners, per the Master Codex Handoff §26.

**Git is now the handoff protocol.** The repository sat at zero commits while
three divergent copies of the same scripts accumulated in an older workspace.
That is the failure mode to avoid: two agents editing the same tree with no
history, and no way to tell current work from abandoned work. Rules that follow
from it:

- Commit after each increment that runs. Never leave a working tree uncommitted
  between agent sessions.
- One agent in the tree at a time. Before handing to another agent, commit.
- `P:\GameDev\AllusionsTooGrandeur` is the only source of truth. The
  `C:\Users\Greg\Documents\ChatGPT\AllusionsTooGrandeur Game` copy is superseded
  and should not be edited.
- Verify before claiming. `--headless --quit-after` runs catch runtime errors;
  say what was actually checked and what was not.

**Picking up interrupted work.** The prior agent stopped mid-task on the vehicle
physics rework: the player chassis was converted to force-based rigid-body
control, the AI cars were not. Recovering that required reading the chassis
docstring against the AI update loop, not re-deriving the design. Unfinished
handoffs should be recorded here, in this file, at the point they are dropped.

## Current milestone

World Zero foundations. In fiction the first region is **The Ashbloom Expanse**,
inside the wasteland realm **Limbo**: the Bone Yard derby opens into a
post-nuclear Australian landscape of runaway fungal ecology, decayed
cybernetics, raider roads, stalker territories and buried anatomical industry.

### Implemented foundation

- Persistent universal event/history store with save-safe subject migration.
- Mara Voss's continuing rival state, injury, grudge, ELO and encounter memory.
- Faction/character seed population: Ashline Wreckers, Black Mile, Soft Rot
  Communion, Choir of Marrow, and the ascending Gate Lanterns.
- Zoomable Living Kinship Web with Vessel / Deep X-ray dossiers.
- Tree of Life axis on the X-ray scan: the anatomy view doubles as an
  as-above-so-below reading, with faction Sin-pulls and personal bond/grudge
  drift deciding where a subject sits between Ascent and Descent.
- Deterministic Ashbloom districts, 40+ enterable shells, 18 Reality Misfires.
- Anatomy component: zone health, blood volume, bleed rate, pain,
  consciousness, treatment, limb disability, persistent snapshots.
- Directional mid-fight severing: cut, shear and ballistic force build separate
  sever stress, physical limbs inherit the blow direction, blunt-disabled limbs
  remain attached, and one-armed NPCs continue fighting with reduced output.
- Hostile escape behaviour, loot caches, collision-aware hunter, dodge, melee.
- Shared camera-relative HunterMotor and movement lab: corrected WASD,
  normalized diagonals, acceleration/braking, floor snap, slopes, directional
  dodge, instant perspective switching and wall-safe third-person camera.
- Authored Bone Yard environment kit (233 meshes) with selective collision.
- Physical AI wreckers on the player's chassis, and the shared `WorldLook`
  environment/material system.

## Sequenced backlog

Ordered so each tier makes the next one look and feel better. Their own §30
rule applies: one system at a time, proven in gameplay.

### Tier 1 — make the core loop feel good

Nothing else is worth polishing until a ram feels like a ram.

1. **Sound rework.** Every player is currently non-positional
   `AudioStreamPlayer`, so engine, impacts, crowd and wind all play flat
   regardless of location. Move to `AudioStreamPlayer3D` with attenuation and
   a reverb bus for the quarry; layer engine by load rather than pitching one
   sine; separate impact layers by severity and material (panel, glass, meat).
   Do not block this on FMOD — see plugin strategy below.
2. **Gore and the ram payoff.** Front-end destruction that escalates to
   crushing the driver inside the cab: frontal high-speed impacts after the
   bumper and hood have shed should kill and gore the driver, with the death
   written into world history like any other. Ragdoll response on detached
   parts and bodies. Postal 2 excess, Wrought Flesh/Kenshi biopunk interiors.
3. **Driving feel.** Now that impacts persist: weight transfer, tire slip,
   speed-linked camera shake and FOV, brake/scrape effects, and a decision on
   whether the upright angular lock stays (it currently prevents rolling).

### Tier 1a — impact feel, added 2026-09-11, **completed 2026-09-11**

Cars ground into each other at near-zero speed and stayed there, draining every
collision of meaning. Three causes, all in `arcade_vehicle.gd`, all fixed:

- **Grip was eating the hit.** The lateral tire force was an uncapped spring —
  a car T-boned at 8 m/s generated 40 m/s² of counter-force and cancelled the
  knock inside one frame. Grip is now a friction limit. This was the single
  biggest cause and was not the one originally diagnosed here.
- **Sustained drive turned contact into a shove**, so restitution never acted.
  Drive and steering are now cut briefly on impact.
- **Nothing broke a stalemate.** Two cars leaning on each other never reach the
  impact threshold. A continuous repulsion force does not fix this — the drive
  servo out-pushes it and re-closes the gap. After a sustained press the pair is
  now kicked apart as a discrete event with a slew, so they part and re-engage
  as a scored blow.
- **Destruction scales with the square of closing speed**, so a committed ram
  strips panels on the first contact. Impacts also carry a `self_share` so the
  car that drove into the other wears the damage.
- **No reset key.** Per Greg's play test, a wedged car backs itself out and the
  heat resolves on a count rather than waiting on ENTER.

Covered by `tests/impact_test.gd` (10 checks). Note the bounds are part of the
contract: separation is asserted from both sides so a later tune cannot quietly
turn the pit into pinball.

### Tier 1a-next — captured from Greg 2026-09-11

Fired mid-session, recorded here rather than half-built.

- **Guns.** Ranged weapons alongside the melee work in Tier 1b — currently
  nowhere in this plan. Needs a decision on whether firearms are common enough
  to change encounter design, or scarce, jamming and mostly improvised, which
  fits a world where nothing is new. Ammunition is an economy item either way.
- **One baseline human model for every NPC — done 2026-09-11.**
  `systems/baseline_human.gd`. The vocabulary was not merely unshared, it
  actively disagreed: the derby tagged a driver hitbox `legs`, the hunt recorded
  Mara's wounds as `left arm` and `leg`, and `anatomy_component.gd` resolves
  anything it does not recognise to `torso` in silence — so a severed leg was
  recorded as a chest wound and nothing downstream could tell. Derby drivers
  skipped anatomy entirely and carried a loose `driver_health` int.
  The rig owns the vocabulary, the hit geometry and the anatomy together, and
  carries the gore: blood scaled by damage and by whether the weapon cuts or
  breaks, permanent compound fractures, organs leaving a destroyed chest,
  exposed bone at a severed joint. `head_anchor` is the consistent speaking
  position proximity voice needs. Derby drivers are migrated; **the Hunt
  Grounds encounter actors are not yet** — they are still bare capsules with an
  anatomy component and no hit geometry, so `bone_yard_hunt.gd` picks a zone by
  round-robin rather than by where the blow landed. That is the next step.

### Tier 1d — defeat, execution and subjugation, captured from Greg 2026-09-11

**Resolution increment completed 2026-09-11.** Generic Hunt Grounds opponents
now stop attacking and fleeing when the shared rig puts them down. At close
range the camera moves into an obstruction-aware over-shoulder confrontation
and three live, clickable choices stay tethered to the body while the rest of
the encounter keeps running. Execute feeds the victim's real zone and organ
snapshot into the X-ray camera and drops loot; spare stabilises without healing
the wounds; recruit requires an existing bond, consent or recognised debt. All
three write distinct histories. Mara still uses her authored retreat branch.

The same interaction now has a local **hold-V proximity voice transport**. It
captures microphone frames transiently, persists contact metadata without raw
audio, and emits the reply from the subject's head anchor. Recognition and
authored/TTS spoken replies remain the next voice stages; the current local
fallback acknowledges the exchange positionally and carries an in-world
subtitle.

Greg's requested anatomy expansion is now explicit: sword, fist and gun
contacts must all drive the same X-ray vocabulary, extended from the current
six broad zones into hands/fingers and named bones, with fracture patterns,
organ rupture and a richer authored blood/guts presentation. Do this by adding
resolution to the shared rig rather than separate weapon-specific gore systems.

The largest single design in the project so far. Recorded whole rather than
half-built, because the parts only mean anything together.

**The pillar is reciprocity.** Everything the player can do to another person can
be done to the player. Greg's framing: *most games don't let the things you do to
others happen to you.* This is already the stated rule for the Wire in
`DESIGN/IN_GAME_INTERNET.md` — the satire only works from inside the system — and
it now extends to the body. The player can be gored, dismembered, fitted with
bionics they did not choose, shackled, conscripted and mind-stamped.

**The keystone is a downed state, and nothing else here can be built first.**
Today combatants die or flee. Both sides need *defeated but not dead*: dropped,
disarmed, conscious enough to be looked at. Every branch below is a choice made
in that window, so the window is the system. Build it before any of the rest.

From the downed state, the resolution branches:

- **Execute.** Behead, or take the limbs. The X-ray kill cam in
  `systems/kill_cam.gd` already draws a plate with ribs fracturing in sequence
  and organs rupturing on delays — the Sniper Elite register Greg is after is
  largely built and is waiting for a trigger. Organs and a skeleton now exist
  per body, so the plate can show the real one.
- **Spare.** Leaves a living witness with a memory and a grudge, which is the
  more expensive choice and should read that way.
- **Recruit.** Consensual, earned through bonds or debts.
- **Mind-stamp ("MK Ultra").** Non-consensual recruitment through the handheld:
  a chip pressed into the brain, a psychedelic sequence of the subject's eyes
  going wrong, and afterwards they are an asset listed on the phone. Reachable,
  taskable, and remotely executable. This is a satire of technology and
  ownership, which is the register `ART-DIRECTION.md` already sets.
- **Targeted attack (VATS register).** Slowed, deliberate part selection feeding
  the same zone and organ geometry the rig already carries. Fallout's pause is
  the reference; the resolution is the anatomy we now have.

**Losing.** Defeat should rarely be a reload. The player who goes down can be
shackled, conscripted or stamped by whoever won — carrying that state into the
world rather than reverting it. The alternative is to die deliberately: forfeit
a large amount of carried loot and be re-decanted out of tar and nuclear oil,
Uruk-hai style, which ties straight back to the Growing Floor the game already
opens on. `vat_chamber.tscn` is the scene; the vat is already the birth.

**Dialogue.** Both registers at once: prewritten choices, and proximity voice
chat during cutscenes and in the middle of a fight. Stage 1 of the voice
pipeline is unchanged and still buildable on its own.

Sequencing, so this can be built without one enormous drop:

1. Downed state on the rig, symmetric for player and NPC. Nothing else first.
2. Resolution interaction in that window: execute / spare / recruit. **Done for generic Hunt Grounds actors.**
3. Kill cam wired to real zones and organs on execute. **Done for generic Hunt Grounds actors.**
4. Player defeat routed to shackled rather than dead, plus the tar re-decanting.
5. Mind-stamp and the asset list on the handheld.
6. Targeted part selection.
7. Voice at stage 1, then dialogue trees.

### Found while doing the above, 2026-09-11

- **The derby had never worked as a fight.** The chassis scales steering
  authority by speed, so a stationary car cannot turn, and the AI set throttle
  from `clampf(alignment, 0, 1)` — zero whenever a car was side-on to its
  target. A car that ended up perpendicular could neither drive nor steer, ever.
  Measured: the nearest wrecker sat at exactly 12.6m for thirty seconds while
  the player took no damage. Compounding it, the charge term eased off as the
  gap closed, so wreckers that did arrive came in at walking pace and never
  reached the impact threshold. Both fixed; `tests/derby_balance_test.gd` now
  bounds the pit from both sides so neither an inert nor a lethal pit passes.
- **AI wreckers still cannot damage each other.** Only the player's chassis has
  its `impact` signal connected, so the third of the pit that fights amongst
  itself is theatre. Connecting every wrecker is cheap but changes pacing, so it
  wants a balance pass rather than a one-line change.
- **The menu colour setting had never worked.** It wrote
  `ambient_light_color` on a sky-sourced environment, which does nothing.

### Play-test feedback from Greg, 2026-09-11 — captured whole

Fired in a burst mid-session. Recorded here in full rather than half-built, per
the rule in §10 of the brief. Two were fixed the same session; the rest are
sequenced below and none of them are dropped.

**Fixed this session.**

- **"The map is still broken."** It was: `M` opened five lines of hardcoded
  prose describing districts. It is now `systems/living_map.gd`, a real chart
  drawn from the generated world — actual road spines, actual building
  footprints from `AshbloomWorldGenerator.lots`, the real Reality Misfire seeds,
  live contacts, and the player's heading. Ground is **surveyed by walking**:
  unwalked cells are hatched over and withhold what stands on them, and the
  survey persists in `WorldHistory` as `ashbloom_survey`.
- **"The third person is shit and not like DS3."** Three separate causes.
  The camera was parked 6.5 m dead behind the head with no smoothing, so it
  read as an RTS chase cam; there was **no lock-on at all**, so a swing at
  anyone circling you was guesswork; and aiming *at* the player cancelled any
  shoulder offset and re-centred the body every frame. Now: spring-damped
  over-the-shoulder framing aimed parallel to the look heading, lock-on on
  `Z` / middle mouse with wheel to cycle, the body turning to face a locked
  target, and a reticle on the mark. A locked target also wins the strike over
  a nearer body, which is the actual fix for "combat doesn't work".
- **Melee aim was resolving against a free world-space point**, so the zone
  opened depended on how far off-axis or how much higher the target stood. A
  level swing at someone on a kerb opened an arm. Aim now chooses *where on the
  body* the blow lands, relative to that body.

**Still outstanding, in the order they should be taken.**

1. **The derby crowds the player — fixed 2026-09-11.** Measured before
   touching it: five cars inside nine metres by twenty seconds, with eight of
   twelve wedged motionless. Two thirds of the pit hunted the player
   permanently (`spawn_index % 3 != 0`) with no cap and no ramp, and the
   remaining "duellists" chased the *nearest* vehicle, which in a scrum is the
   player again. Now at most three may hunt at once, the cap ramps in over
   twenty-two seconds, roles rotate every 2.6s so nobody is welded to the
   player's door, two cars circle at range, and the rest are paired off against
   named rivals. Re-measured: peak crowding 2, cars moving 7-10 of 12 instead
   of wedging, hull 100 -> 83 over the same thirty seconds. Bounded from both
   sides in `tests/derby_balance_test.gd`.
   Found while doing it: **the AI had a permanent three-point-turn deadlock.**
   A car pointed away from its target alternated reverse and creep-forward at
   full lock, both around one metre per second, forever — the nearest wrecker
   held 8.2m from a parked player for thirty seconds while the player took zero
   damage. The chassis scales steering authority by speed, so creeping is the
   worst possible response to facing the wrong way. Reversing now commits for a
   minimum time with hysteresis on the exit, and a slow car that needs to turn
   gets *more* throttle, not less. This is the third distinct instance of the
   same root cause in `arcade_vehicle.gd`'s speed-scaled steering; the next
   agent should suspect it first.
2. **The derby arena is too small — attempted, reverted, needs authored work.**
   "The map for the derby is way too tiny." A uniform `ARENA_SCALE` multiplier
   does not deliver it and the measurements are unambiguous: at 2.15 first
   contact came 28s into the heat with no damage landed inside thirty seconds,
   and at 2.45 the wreckers never reached the player at all — in both cases the
   nearest car *drifted outward* over time while eight to ten of twelve were
   driving. Holding the spawn ring tight while only the venue grew did not fix
   it, so the cause is in the authored oval, not in the spacing. `SPAWN_SCALE`
   now exists as the seam for this and is deliberately equal to `ARENA_SCALE`.
   Doing this properly means re-authoring the Bone Yard oval for a larger
   footprint and retuning the engagement cap against it together — the same
   Blender pass the cars need, not a constant change.
3. **Gore does not read in play — fixed 2026-09-11.** Three causes, none of
   them "the rig has no gore". The **Hunt Grounds never applied the GORE
   setting at all** — `_apply_gore_setting()` existed only in `rift_derby.gd`,
   so OFF did nothing once the player walked out of the pit and REDUCED leaked
   across as a static the hunt never reset. Blood **evaporated**: every drop
   had a life of about two seconds and left nothing behind, so a fight never
   marked the ground. And the **spray was tiny** — a 24-damage sword hit threw
   four drops. Blood that lands now becomes a persistent ragged spatter mark
   that stays for the scene, capped at 420 and recycled oldest-first; sprays are
   three to five times larger; and both scenes read the setting through one
   shared `BaselineHuman.apply_gore_setting()`.
   Covered by `tests/gore_test.gd` (10 checks) and captured. Two things worth
   knowing for the next pass: the marks are flat ground-projected meshes, so
   they do not climb walls or drape over bodies, and blood still only lands on
   the ground plane rather than on the geometry it actually hits.
4. **The opening is "cool but kinda lacklustre."** `vat_chamber.tscn` works but
   is under-directed — pacing, camera, sound and the handler's delivery.
5. **The seams read as dev tools — first pass done 2026-09-11.** Every scene
   change was a hard cut straight from one `.tscn` to another with nothing
   covering it. `systems/interstitial.gd` is now an autoload (so it survives the
   swap it is covering) and all five transitions route through it: menu -> derby,
   menu -> vat, vat -> derby, and both derby -> Hunt Grounds exits. The plate is
   the Tier 2.6 register — a procedural skeleton turning on the spot with its
   organs lighting and naming themselves in sequence, deadpan CellOutz transit
   paperwork, and a progress bar that admits it knows nothing.
   Still outstanding here: the transitions are covered, not seamless, and there
   is no streaming or preloading behind the plate — the hold is a fixed 1.45s
   rather than actual load progress. Reset keys and other debug affordances are
   still in the shipping input map (item 6).
6. **Player-facing reset keys and debug affordances** should come out of the
   shipping input map or be gated behind a developer flag.

### Captured from Greg 2026-09-11 — the 1.0 body

Fired while looking at the 0.1. Recorded whole, not built: this is the full
shape of the body system the project is aiming at, and most of it already has a
foundation in `baseline_human.gd` and `anatomy_component.gd`.

- **Bionics as real parts.** Not a stat bonus — a component with its own
  condition, compatibility, maintenance cost and social reading, occupying a
  zone the way a limb does. `install_prosthetic()` and the cybernetics slots
  exist; what is missing is the part catalogue, the economy around it, and the
  silhouette change on the rig.
- **Bones, organs and blood as one continuous system.** Zone health, organ
  rupture, bleed rate, fractures and blood volume all exist separately and are
  already wired to behaviour. The 1.0 version is these reading as one body in
  play: a broken arm that changes a swing, a punctured lung that changes a
  sprint, blood loss the player watches happen to themselves.
- **Specimen interaction is live.** The BODY page now separates hover preview
  from pinned selection, supports direct drag/zoom, renders authored organ
  silhouettes with wet tissue materials, and tears ruptured organs open in the
  mesh. These interactions operate on the live 3D part rather than a modal.
- **Dismemberment.** The first combat-verb slice is live: directional cut,
  shear and ballistic damage builds sever stress independently from limb health;
  crossing the threshold throws the real limb along the strike vector, leaves a
  stump, persists through save/load and keeps a surviving NPC in combat at a
  reduced attack cadence and damage. The thrown limb remains an identified world
  chunk: E lifts it into CARRY, slot 4 equips it as a degrading blunt weapon and
  a Soft Rot broker prices and buys that same persistent object. Next are
  reciprocal player dismemberment and deeper stump-specific movesets.

Nothing here is scheduled yet. It sits behind the Tier 1b combat work because
every item needs a fight that feels good to be legible inside.

### Reference pass from Greg, 2026-09-11 — captured whole

Greg sent screenshots from Postal 2, Half Sword, HAVKER-MAN X, Eternity Egg
and Prototype. All five are already in `DESIGN.md`'s influence register as
tonal references. What follows is the *transferable structure*, recorded so it
is not lost; none of it is a licence to reproduce another game's UI, art or
code, and a request to read a commercial game's source was declined.

**The common thread across all five:** interfaces are made objects — framed,
physical, built out of rendered 3D things rather than flat vector panels — and
the world is carried by crunchy saturated surfaces rather than by geometry.
This is what `ART-DIRECTION.md` already specifies under "the interface is a
made object" and "PS1/PS2-era low-poly surrealism"; the project had simply not
built it.

- **A pre-game warning card.** Postal 2 register, CellOutz voice. Cheap, sets
  the tone before anything else, and the game already has three violence tiers
  to warn about.
- **A 3D diegetic front end.** The menu as an object in a real scene the camera
  moves around, rather than buttons on a backdrop.
- **A violence-level selector as an authored opening choice**, replacing the
  buried FULL/REDUCED/OFF text setting the game already has.
- **A framed HUD and map.** Physical bezel — pipes, rust plate, screws — around
  the live view, and the Living Map presented as a salvaged object rather than
  a chart floating on black.
- **Location-based travel** on the map: named discovered places with a
  description panel, alongside the existing survey chart.
- **Mutation and evolving cybernetics.** Prototype's third-person power fantasy
  and Maneater's evolving mutations: cybernetics that *evolve* rather than being
  installed once, organ and limb upgrades as a progression axis, and — by the
  reciprocity pillar — the player getting gored and needing emergency
  replacements. This extends the "1.0 body" note above and sits behind Tier 1b.
- **Traversal:** running up buildings and walls.
- **Weapon and cybernetic selection sliders**, and killing that flows without
  breaking out to a menu.

### The tutorial look — Greg, 2026-09-11

His words: *"the boxes and squares of everything being super basic and almost
tutorial level, same as the font"* and *"no more of this tutorial look"*. Two
specific causes, both cheap relative to their impact, and the second has been
hiding in plain sight all session:

1. **Every interface in the game is set in Godot's default font.**
   `ThemeDB.fallback_font` appears in the map, the resolution form, the kill
   cam, the HUD, the warning card and the interstitial. Nothing announces
   "engine default" louder, and every reference Greg sent has a distinctive
   display face. Fix: a generated stroke/stencil display alphabet drawn in code
   for headers and numerals, keeping a legible face for body copy. No font file
   to licence, and the letterforms become part of the CellOutz identity.
2. **Primitive silhouettes.** Boxes and capsules with no secondary form. The
   contamination pass gave them surfaces; they still need bevels, greebles,
   leaning, broken corners and attached junk so the *outline* stops reading as
   a primitive. This is a generator change, not an authored-asset change.

**Roguelike elements, also captured:** Greg wants the Hunt/nemesis system to
carry roguelike structure — runs, escalating rivals, loot that matters per run.
This sits with the Hunt System rework in Tier 3 rather than as a separate
system, and needs a decision on what persists between runs versus what resets,
given that "bodies remember" is a pillar.

**The clinch as a social verb, captured:** Greg wants to hold someone in the
grapple and *talk* to them — rob them, force them to take abuse, or persuade
them to join. The clinch already exists and already resolves into the downed
window; extending it into a hold-and-negotiate state connects grappling,
dialogue, the resolution form and recruitment into one verb. This is the
highest-value single feature in the captured list because four systems that
already exist would start talking to each other.

### Base building — Greg's own doubt, and the call, 2026-09-11

Greg: *"if there were to be a building aspect which I find might be excessive
it would need to have the attention to detail of Valheim."* He is right on both
halves, and the second half is what settles it.

**Valheim's building is not a feature, it is a pillar.** Its structural
integrity simulation — the thing everyone actually praises — plus snapping,
piece tiers, weather decay and the comfort/rested loop that ties building back
into survival, was core work for a team of five iterated over years. Bolted
onto this project it would either be shallow (and Greg would hate it, because
he has named the standard) or it would consume the combat and Hunt System work
that the game's whole identity rests on. `DESIGN.md` §17 keeps it as a desire;
this entry records the scope decision, not a silent drop.

**The reduced version worth building instead, per non-negotiable 4.** What
Valheim actually delivers is *attachment* — a place that is yours, that you
return to, that shows what you have done. This project can produce that without
a structural simulation, because it already has the machinery:

- `DESIGN/FACTIONS.md` already specifies **ground territory**: camps, towns,
  yards and roadhouses that are raided rather than besieged.
- `WorldHistory` already persists subjects, and recruitment already produces
  people who are loyal to the player.

So: **claim and invest in a place, rather than place walls piece by piece.**
Take a camp, and it becomes yours. The people recruited out of the downed
window live there. What you spend on it changes what it produces, who it
attracts and how it reads when you come back — and a raid can take it off you.
That is Valheim's attachment and Rust's stakes, built out of systems that exist,
and it costs a fraction of a build grid.

Free-form construction stays available as a later addition on top of a claimed
camp, if it is ever worth the cost. It should not be the way the feature is
introduced.

### Outstanding UI work Greg named, 2026-09-11

From a play screenshot of the derby: *"the car and bottom left and top left and
the hunt signal is aids and the hull integrity honestly I hate it all"*, and
separately *"the world index needs a UI badly it looks shit"*. All correct, and
all the same root cause — these were built before the project had a visual
language, and now it has one (`celloutz_type.gd`, the framed-plate vocabulary,
the contamination materials) they are the parts that have not been brought over.

- **World Index** — a bare `PanelContainer` with a default-font `Label`. The
  single worst offender in the game; it is a Godot default with text in it.
- **Hull integrity, hunt signal, damage bust, contact radar** — the derby HUD
  corners. They need the framed-object treatment and the display face.
- **The derby arena and the cars.** The cars are still smooth boxes and the
  venue still reads as a painted oval on a flat plane. This is the Blender work
  already recorded under "Derby art pass"; no amount of shader work replaces it.

### Nemesis / Shadow of Mordor — the standing answer, 2026-09-11

Greg linked a Shadow of Mordor video and asked for it to be studied and added.
Recording the answer here so it does not have to be re-litigated each time:

- Videos cannot be watched by the agent, and a commercial game's code will not
  be read — that request was made and declined earlier in the same session.
- More importantly, **`DESIGN/HUNT_SYSTEM.md` is an entire document about not
  doing this.** Warner Bros holds US Patent 10,926,179 on the Nemesis System,
  in force into the mid-2030s, and that document already states deliberately
  studying it to reproduce it is the most legally exposed thing this project
  could build — on a game carrying Greg's real name.
- **The experience he wants is not blocked, and is already designed.** The six
  mechanisms in `HUNT_SYSTEM.md` — the wound as the memory, promotion into real
  vacancies, grudges travelling along relation edges, distortion on retelling,
  alignment drift, bonds on the same machinery — are largely *unbuilt*. Witness
  records on events is step one and is cheap. That is the work; it does not
  need a reference video.

### The Wire social layer and the rank pyramid — captured 2026-09-11

Greg wants the faction hierarchy screen and the in-game internet to be the same
satirical object: ranks and a pyramid-scheme conspiracy register, plus social
media stalking, DMing and harassment as *mechanics*, with an RNG of replies
weighted by how "verified" or high-status an account is, and a dark-web
underbelly beneath the ordinary feeds.

Most of this is already specified and unbuilt rather than new:

- `DESIGN/IN_GAME_INTERNET.md` already defines the Wire, the David Dees
  paranoid-collage register, dead forums, bots arguing with bots, and a social
  layer where actions against a rival each carry a real cost.
- `DESIGN/FACTIONS.md` already defines **signal territory** — feeds, masts,
  presses — taken by out-publishing, discrediting, hijacking, flooding or
  cutting. A pyramid-scheme faction is a signal faction with a recruitment
  mechanic attached, which the recruitment path out of the downed window
  already produces.
- `HUNT_SYSTEM.md` already defines promotion into real vacancies, which is the
  rank pyramid's actual data.

So the work is: **a rank view drawn from real subjects**, and **the Wire as a
playable surface** — accounts with reach, replies weighted by status, and
harassment/stalking as costed actions against fictional NPCs. Note the
presentation must be original: a faction hierarchy is nobody's property, but
Shadow of Mordor's specific presentation of one is, per the standing answer
recorded above.

**Not yet decided:** how the dark-web layer is gated. Coverage is already a
property of *place* in the Wire design (no signal in the caves), so the natural
answer is that the underbelly needs a physical access point rather than a menu
toggle — but that is a design call for Greg.

### The Vat as character creation - captured 2026-09-11

Greg's largest single capture since the downed state, and it closes the open
"the opening is cool but kinda lacklustre" item by answering it with a system
rather than a polish pass. Written whole in `DESIGN/CHARACTER_CREATION.md`.

The shape: the vat *is* the creator. New Vegas' Doc Mitchell, except you have a
feed tube in your mouth and cannot speak, so a handler fills in your intake form
from your blinking and sometimes writes down the wrong thing. Four routes into
a sheet - authored preset, random decanting, a real natal chart, or a
personality instrument bent toward the dark triad - plus Project Zomboid trait
budgeting, a mirror with sliders that lies because you are looking through goo,
an under-the-skin editor choosing the skeleton and organ set the kill cam will
later show, six races that are consequences of the Reset rather than fantasy
species, and opt-in conspiracy modifiers (a neural lace, the mast tithe, the
full schedule) where taking them is mechanically correct *and* hands the Wire a
way to trace you.

Two things in it are load-bearing beyond character creation:

- **The chart produces numbers.** `natal_sigil.gd` already draws the wheel and
  already holds Greg's own chart; what is missing is elements mapping to
  attributes, modality to a commitment axis, and the ascendant to Wire clout.
  Skyrim's standing stones is the named reference. **Open decision:** a derived
  house wheel (buildable now) versus a real ephemeris table, which is what
  "most accurate" actually means.
- **The skill tree is the chart.** Progression walks the houses of your own
  natal wheel, merging the `J` artwork archive, the sigil and the skill tree
  into one object. Same unify-the-interface instinct as the handheld, and the
  two should be built toward each other.

Not scheduled until the Wire and HUD pass below lands.

### Tier 1b — combat, added 2026-09-11

**Movement prerequisite completed 2026-09-11.** The original Hunt controller
interpreted `Input.get_vector`'s negative forward axis backwards, so W moved
against the camera. `systems/hunter_motor.gd` is now the shared convention
boundary and `tests/movement_lab.tscn` is the playable proving course. Its 11
checks cover exact cardinal directions, camera yaw, diagonal normalization,
floor snap, slope configuration, camera obstruction and physical travel.

Greg's required next-slice order is now authoritative:

1. WASD repair and movement lab — **done**.
2. First-person body and locomotion: authored silhouette, face/hands/feet,
   layered wounds/prosthetics/clothing, animation set, foot and weapon-hand IK.
3. Physical first-person feel: breathing, shoulders, weight, restrained head
   motion, footsteps, landing compression and animation-driven attacks.
4. Concise HUD: cut visible prose by roughly 60%, two original font voices,
   icons/meters/tooltips and gameplay-model 3D anatomy/equipment previews.
5. Living Survey: the generated world rendered into original map tiles with
   2D-to-tilted-3D zoom, fog of war, sightings and filters. No Google imagery
   or copied interface.

**Arsenal foundation completed 2026-09-11.** The hunter can equip a sword,
shotgun or sidearm with 1–3, use with LMB/RMB and reload with R. Firearm traces
are world-occluded and feed the struck BaselineHuman zone/organ state, so
shotgun dismemberment is accumulated ballistic sever stress crossing a damaged
limb's directional threshold. Magazines, reserves, spread, timing, knockback, downing,
flight, death, persistence and history are live. Production weapon meshes,
animation-driven handling, muzzle/impact treatment and enemy firearms remain.

10. **Physical melee.** Half Sword's register — momentum-driven swings, real
    contact, unglamorous brutality and heavy dismemberment — but it has to
    actually *work*, which Half Sword's first-person control notably does not.
    Swing direction and force from input, weapon mass and reach mattering,
    contact resolved against the anatomy zones that already exist.
11. **Dodge and roll.** DS3/Elden Ring vocabulary — i-frames, stamina cost,
    directional commitment — with more player control than either: cancel
    windows, shorter recovery, and a step distinct from a full roll.
12. **Seamless first/third person.** Not a camera toggle. Per Codex §19 the
    perspective carries meaning: first person is Self/Perception, third is
    Body/Spatial. The transition should be continuous, and combat must be fully
    usable in both.
13. **Weapons, limbs and organ upgrades.** HAVKER-MAN X-style bionics and
    Cruelty Squad implants, but far more customisable. Every weapon, limb and
    organ is a distinct part with its own trade-offs, compatibility and social
    reading, feeding `anatomy_component.gd`'s existing cybernetics slots and the
    prosthetic economy in `DESIGN/HUNT_SYSTEM.md`.

### Tier 1c — the inspection interface, added 2026-09-11

The dossier and the vehicle readout become one interaction pattern: a schematic
you can point at, where the hovered part lifts out of the diagram as a real 3D
object turning in place.

- Hovering a zone on the body diagram pops that part — organ, limb, bone — out
  of the flat schematic into a small 3D viewport beside it, rotating slowly,
  showing its real condition from `anatomy_component.gd`.
- The same pattern serves the car: hover a panel on the hull schematic and that
  part lifts out as a turning 3D component with its own damage state.
- The transition between flat diagram and popped 3D part is the interaction, so
  it must be continuous — the part appears to leave the diagram, not to open a
  window. No hard cuts, no separate modal.
- This unifies the X-ray dossier, the cab hull screen and the upgrade interface
  under one verb: point at a part, inspect the part.

### Tier 2 — the opening Greg described

4. **Opening sequence.** Wake in a dingy interior; forced to win the derby to
   get out; walk out through a large facility; exit into the Ashbloom
   wasteland. This is the first authored narrative spine and it reuses the
   existing derby → Hunt Grounds transition rather than a new scene graph.
5. **First person and body UI.** Character model visible in first person,
   breathing and health readouts driven by the existing anatomy component
   (blood volume, pain, consciousness already exist and are unused by the HUD).
   Walking must not feel broken — this is a feel pass, not new systems.
6. **Procedural interstitials and menus.** Postal 2-register loading screens:
   trippy screensaver anatomy, skeletons, X-ray plates, drawn in code from the
   same primitives the dossier and `kill_cam.gd` already use. The start and
   pause menus move to the same register — crude, grimy, funny, closer to a
   Postal 2 menu than to a clean engine front end.

### Derby art pass — outstanding

The toybox brief is superseded and the venue has been rescaled, regrimed and
relit, but the authored geometry itself is unchanged. Still outstanding:

- **The cars are karts.** `scrap_skiff.glb` is a smooth box silhouette. Per the
  new direction they need stripped chassis, exposed mechanism, bone and sinew
  lashings, fungal bloom in the wheel wells and dried spatter. This is Blender
  work on `art/scrap_skiff_v1/`, not a material swap.
- **Runtime regrime is a stopgap.** `WorldLook.REGRIME` remaps the old material
  names at load. Re-exported assets should carry the biopunk palette natively
  and simply stop matching those keys.
- The pit still reads close to monochrome red. Contamination colour — spore
  green, bruise purple — needs to arrive through authored surfaces, not only
  through light colour.

### Tier 3 — systemic depth

7. **Hunt/Nemesis rework.** Today Mara is one hardcoded character whose state
   is mutated by ad-hoc dict writes in two scenes. It needs to become a system:
   rivals generated from real events, tactic adaptation, promotion and
   recruitment, grudges that propagate through factions. This is what LimboAI
   is for and it is currently unused.
8. **Ashbloom exterior.** Terrain3D for real landscape instead of procedural
   boxes; Proton Scatter for the grime and debris fields that make a wasteland
   read as inhabited.
9. **Proximity voice chat with NPCs.** Pipeline below.

### Deferred intentionally

Large-scale economy simulation, simulation-grade organ damage, multiplayer,
BeamNG-scale deformation, and seamless traversal of all Limbo.

## Plugin strategy

Seven plugins are installed and **none are referenced by any script**. 415MB of
that is three GDExtensions doing nothing. This is the cheapest available
upgrade to the project.

| Plugin | Size | Status | Call |
| --- | --- | --- | --- |
| LimboAI | 109MB | Unused | **Adopt** for the nemesis rework (Tier 3.7). Behaviour trees are the right shape for rival tactics and adaptation, and hand-rolling that again would be the larger cost. |
| Terrain3D | 68MB | Unused | **Adopt** for the Ashbloom exterior (Tier 3.8). |
| Proton Scatter | 1.4MB | Unused | **Adopt** alongside Terrain3D for set dressing. |
| Dialogue Manager | 1.1MB | Unused | **Adopt** at Tier 2.4 when NPCs first speak. |
| gdUnit4 | 2MB | Unused | Optional. The hand-rolled `check()` asserts in `tests/opening_test.gd` work; migrate only if suites grow. |
| FMOD | 238MB | **Failing to load**, panel disabled | **Defer or drop.** It needs FMOD Studio plus authored banks, and its GDExtension currently errors on load. Native `AudioStreamPlayer3D` and audio buses deliver most of Tier 1.1 immediately. Revisit only when real authored audio exists. |
| Godot MCP | 476KB | Dev bridge | Keep, exclude from release builds. |

Note: the three GDExtensions also fail to copy their DLLs while the editor holds
them open, so headless runs load without them.

## Proximity voice chat pipeline

Greg's reference is Rust's proximity chat, redirected from multiplayer to NPCs.
Reduced-scope version that can ship inside single-player, staged so each step is
useful on its own:

1. **Positional speech.** NPC voice lines on `AudioStreamPlayer3D` with
   attenuation and an audible radius. Delivers the proximity feel before any
   microphone work, and is a prerequisite for everything below.
2. **Push-to-talk capture.** `AudioStreamMicrophone` into `AudioEffectCapture`
   on a dedicated bus. Hold a key, capture a buffer, release to submit. Gate it
   on an NPC being inside the conversational radius and facing the player.
3. **Local speech to text.** whisper.cpp as a subprocess or GDExtension over
   the captured buffer. Local keeps it free, offline and private; no per-word
   API cost during long playtests.
4. **Intent match, not open chat.** Map the transcript onto Dialogue Manager
   topics plus the subject's real `WorldHistory` state — grudge, bond, wounds,
   faction, Tree axis. Asking Mara about her arm should hit her actual recorded
   injury. This keeps NPCs in-world and inside their own knowledge rather than
   becoming a general chatbot, which matters for a world whose whole premise is
   that information is partial and sometimes false.
5. **Voice out.** Local TTS per faction/species timbre, played back through
   step 1, degraded through the existing audio treatment so it sits in the mix.

Failure handling is a design surface, not an error path: unrecognised speech
should get an in-character non-answer, because a world of dead forums and
half-working infrastructure is allowed to mishear.

## Headless testing - FMOD blocks it, and the fix is not in git

Found 2026-09-11 while trying to verify the Wire. Worth its own section because
it costs an agent an hour if they do not know it.

**Symptom.** A headless test run produces no output and never exits. It looks
like the test is hanging on world generation. It is not.

**Cause.** The FMOD *editor plugin* is disabled, but the FMOD **GDExtension
still loads on every run**, initialises, and opens a live-update socket on port
9264. With a Godot editor already open - the normal working setup - the second
instance cannot bind that port and FMOD retries forever, flooding stderr and
starving the test's own output. Three leaked `resolution_test` headless runs
were found spinning on this, each having burned about 28 CPU-minutes.

**Fix, applied locally.** Rename `game/addons/fmod/fmod.gdextension` (and its
`.uid`) to `.disabled`, and delete the fmod line from
`game/.godot/extension_list.cfg`. Headless runs then complete in seconds.

**This fix does not travel.** `.gitignore` excludes both `game/addons/fmod/` and
`game/.godot/`, so every fresh checkout and every other agent's tree hits it
again. Re-apply it locally, or take the plugin strategy's standing call and
drop FMOD properly - it is 238MB, referenced by no script, and its own row in
the table below already says "defer or drop".

**Side effect of the fix, and it is harmless.** With the extension disabled, the
addon's own editor scripts (`addons/fmod/tool/ui/*.gd`) fail to parse on a
reimport because the FMOD types they reference no longer exist. The editor
plugin is already disabled so nothing loads them at runtime, and game and test
runs are unaffected - but the errors appear in every `--editor --quit` log and
should not be mistaken for a new fault. Dropping the plugin outright removes
them, which is the standing call anyway.

**Second trap in the same area.** A new `class_name` global is not visible to a
headless run until the class cache is rebuilt: `WireNet` parsed as an
undeclared identifier until the project was reimported with
`--headless --editor --quit`. Run that after adding any new `class_name`.

## Open technical risks

- FMOD's GDExtension errors on load; the sound rework must not depend on it.
- Untextured procedural primitives carry the whole look. `WorldLook` triplanar
  noise mitigates it, but authored material work is still outstanding.
- The upright angular lock on the chassis prevents cars rolling; good arcade
  behaviour, possibly wrong for a demolition derby. Needs a feel decision.
- Only `rift_derby` has been migrated to `WorldLook`. The Hunt Grounds, menu
  and showcase still hand-roll environments and should be migrated with visual
  review on each.
