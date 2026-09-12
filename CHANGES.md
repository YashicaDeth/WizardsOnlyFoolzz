# What changed

The build record for **Wizards Only Fools**, newest first. Every entry is a real change with the reason it was made; the tag says which part of the game it touched.

**245 changes** · **43,220 lines of game code** · **415 of 812 planned pieces built** across 46 areas

---

## 2026-09-12

- **gore chunks actually freeze during hitstop, verified and recorded** `combat feel`
  The code (GoreChunks.hold()/release(), called from bone_yard_hunt.gd's _physics_process whenever impact_feel.holding() is true) already closed this - a real freeze/resume scheme using RigidBody3D.freeze rather than a delta multiply, exactly what O2.7 v3's own explanation said gore would need - but CHECKLIST.md still had it unchecked, with O2.7 v3's own explanation paragraph orphaned under O2.8's line instead of its own, incorrectly implying gore was…
- **The rework: the game finally knows what it is about**
  Greg sent eighteen pages. It is the first document in this project that answers why rather than what, and it settles four of the five questions that have been formally blocked on him.
- **teach the F-keys, and crack the glass where it lands** `the handheld`
  C2.7: jump_to_mode() has reached a page directly since C2.6 v2 and nothing on the device itself ever said so. Each tab now prints the F-key that jumps to it directly.
- **Large update 001**
- **the Wire prints on glass, not the same paper as the dossier** `look and feel`
  _draw_plate() grimed the same paper substrate under FILE, PYRAMID, BODY and WIRE alike - one plate for every page meant one substrate for every page, and the Wire is not paper. The physical registry itself (the notched shape, the tabs, the tape) stays one shared object on purpose, since that is what A0's 'one made object' already asked for - only what it is printed on now differs. WIRE prints on black_mirror.gd's black glass (the same surface every…
- **one currency with a real issuer, a market of people, and real debt** `rituals`
  carry.gd's economy existed in pieces (sale_value priced by kind/condition/ stolen, faction standing already refused deals, liens already followed stolen goods) but nothing tied it into a reason to get up in the morning.
- **a round becomes a thing that travels** `guns`
  Greg, twice: "the combat system apart of the gun system ect and weapons so bullet weapon and firing ect are all realistic bullets and reload with the things", and then "bullets shells fall on the floor aggressively as the bullet destroys the map".
- **CHANGES.md: a build record somebody who is not us can read**
  Greg: "it would be super cool if you can get a working history of the versions and changelogs and updates on the code and the commits for my github page so my freinds can understand the changes instead of me just yapping about nothing".
- **the game gets an hour** `weather and the hour, look and feel`
  A9.7 v2 was a small ask - "stations have a schedule; the dial is the same at 3am as at noon" - and turned out to be blocked on something nobody had noticed was missing: there is no time of day in this game. No clock, no day, no night, no hour anything can ask for. W1.1 has been sitting unticked with five separate things quietly depending on it. A9.7 stations keeping hours. W1.4 factions keeping hours. AB2.4 damage repairing over a month. AJ4.3 a…
- **the panel fails intermittently instead of having failed** `look and feel`
  Greg: "dead pixels and scanlines are static; a failing panel flickers".
- **the grime belongs to the run it is in** `look and feel`
  Greg: "grunge is seeded per screen and identical every session - it should remember the run it is in". Every drawn surface derives its damage from a constant written into the call site, so a panel's grime was the same grime in every save anybody had ever loaded. Deterministic per frame is correct and was the entire point; deterministic per universe was an accident nobody noticed, because there has only ever been one save to look at.
- **the face gets kerning, measured off its own strokes** `look and feel`
  Greg: 'the stencil has no kerning pairs - every letter sits on the grid, so AV and TA gap'. Correct, and visible from across the room: two diagonals leaning away from each other leave a triangle of white that a flat advance does nothing about.
- **the blow becomes something you perform** `the body as weapon`
  Greg, to the playtester: "i wanna make the hands kinda floppy... the combat with the floppy arms as swords is so fun, i want to rework that system into something new but keeping that fun of the movement". TaKeS, same thread: "the gun swivels with where you aim, and sorta moves around with the momentum".
- **the handler varies decanting to decanting, and reacts to race** `making a character`
  D3.5: _speak() indexed every IntakeDirection pool with handler_line % pool.size(), and handler_line always started at zero - so the first idle line was the same line every single decanting, then the same second, forever. A line_offset rolled once per scene in _ready() shifts every pool's index instead, so which line starts each context varies decanting to decanting, while IntakeDirection.line_for() stays exactly as deterministic as…
- **sitting still, the slow half of the substance/meditation pairing** `factions and standing`
  New systems/meditation.gd. E6 built the fast half (substances.gd) — costs the body, reaches the entity layer quickly. This is the slow half: costs only time.
- **a clerical error can be audited, at a real cost** `making a character`
  _mistranscribe() overwrote one field on the sheet with a wrong value and threw the true one away in the same statement, so CLERICAL ERROR was undiscoverable in principle - there was nothing left anywhere to check the wrong sheet against.
- **the Wire's deeper social layer, mostly already built and uncredited** `the Wire`
  Audited five of six against the actual code rather than rebuilding blind: wire_net.gd's contact() already sends a DM to one account (Q1.1) with a chance formula reading reach, broker/leverage routes and grudge (Q1.2); TIERS' per-tier answers ceiling already makes a Crown answer differently and far less often than a nobody (Q1.3); act()'s "swarm" already moves grudge, exposure and reach together on one real event (Q1.5); SIGNAL_UNDERBELLY/band routing…
- **Second playtest: the satellite, the map's cost, and the sprint jitter**
  TaKeS on the map: "sort of? I can tell theres somthing behind it". He was right in a more literal way than he meant. The satellite renders correctly - and from two hundred metres up the whole region sits inside the Ashbloom's fog, so it returns a flat grey sheet. Then the chart draws its entire symbol set on top in solid fills, so what little came through was behind an opaque plan of itself.
- **a permanent death is a rich recorded event, not a reload** `death and what persists`
  New systems/run_lifecycle.gd. Deliberately does not touch T1.1 ("what persists between runs") — that stays blocked on Greg, and this does not guess an answer by building T1.3's inheritance or T1.5's run shape on top of it. record_death() captures what the world actually knew at the moment: the real cause, where the run had reached (OpeningDirector), what was being carried (Carry), and where the subject stood on the axis (tree_alignment()) — one…
- **celloutz.xyz fictionalised and reachable on the Wire** `screens`
  I3.1 was blocked on a real decision, not a fictional one - country_town_menu.gd already OS.shell_open's the actual live celloutz.xyz, so this wasn't purely a creative call to make alone. Asked Greg directly: fictionalise it. The in-game version is CellOutz-the-corporation (the company that makes the handheld and the Wire itself), not a reproduction of the real page.
- **the player's own faction, the third ladder** `your own faction`
  New systems/player_faction.gd. found() makes the player a real WorldHistory faction founder holding CROWN on the exact same pyramid/rank machinery every Sin and wizardsonlyfoolz already run — never a parallel rank system for the player's own faction. Deliberately not a FACTION_TREE_AXIS entry (that table is authored, world_history.gd, Codex's file); standing() computes the real average tree_alignment() of whoever has actually joined instead, since…
- **modern gods and a real, disagreeing verdict on a kill** `chaos magick`
  New systems/modern_gods.gd. AJ3: four gods this world actually worships — The Engagement, The Market, The Quota, The Brand — as real WorldHistory subjects (kind: "god") with a real accumulating attention field, same shape ascent_entities.gd already proved. AJ1 (sigils naming a god) isn't built, so get_attention() is offered rather than wired to anything yet, same relationship ritual_app.gd has to the seals it doesn't draw.
- **put the driver back in the car, with instruments** `playtest fixes`
  Greg, in the seat: "the derby thing is so whack rn no hud or hull not progressing out of the car animation no shooting through first person no direction of controls". Four complaints, two causes.
- **record the handheld lean-in as done, with reference captures** `screens`
  The mechanic (handheld_device.gd's lean/lean_override/LEAN_KEY, holding L to grow the device up to 1.32x while a hosted panel is open) and its test (tests/handheld_lean_test.gd, 3/3) were already written and landed in a merge before this commit could record them - this adds the checklist entry and a resting/leaned reference pair (captures/i0_10_v2_handheld_map_resting.png, i0_10_v2_handheld_map_leaned.png) showing the same Living Map hosted at both sizes.
- **update**
- **another big update**
- **lesser demons want something of their own, derived from real state** `the cosmology`
  New systems/demon_ambition.gd. A lesser demon (DemonHierarchy.is_lesser_ demon()) either wants to settle a real, strong grudge it already carries (>=15 strength) or, lacking one, seeks patronage from whichever Sin's signal_control is currently weakest — ties K5.1 into K4.4/K4.6 as one story rather than three: contesting a Sin's channel doesn't just anger its captain and its Horseman, it makes the Sin a target for opportunists too.
- **a theory's claim is set in a real font, not the display face** `screens`
  The pin board's theory cards drew their whole claim - two or three full sentences, the one piece of text on the entire board a player actually has to read to engage with L5/L6 at all - in CellOutzType at 8.5px condensed, the same stencil face as the card's own title. That is exactly the mistake warning_card.gd and world_index.gd's dossier memory already avoided for their own paragraphs.
- **real friction for genuinely climbing both ladders at once** `the cosmology`
  Per Greg's direction: distinct from K3.1's answer, which deliberately leaves the Tree axis itself freely reversible until an ending locks it. This is about real standing instead — wire_net.gd's _build_account() now halves reach once a subject holds genuine command-relation weight (>=20 strength, DUAL_LADDER_THRESHOLD) in a Descent faction and in wizardsonlyfoolz at the same time. A small toe in the other ladder does not trigger it; only real…
- **what is clickable is real state now, not a side effect of painting** `screens`
  _link_rects only ever existed because _draw_file() and _draw_post() happened to append to it while drawing wound rows, implant rows and post-author rows - rebuilt every paint and thrown away right after. A click arriving before the first frame had drawn read an empty list, and nothing but the renderer itself could ever ask what was currently pointable.
- **run the door the player actually leaves through** `playtest fixes`
  The last playtest bug open was a warning rather than a sighting: the game might crash after the derby. It does not, and now something proves that every run.
- **code rain now only runs on the WIRE page of the World Index** `screens`
  FILE, PYRAMID and BODY had the same falling rain behind them as WIRE - a dossier, a career chart and an anatomy are not a network, and the rain ran full time regardless of which page was open, which is exactly the decoration-on-every-page problem this item names. _wire_glow eases toward 1 only while PAGES[page] == "WIRE" and back to 0 on every other page (Motion.blend, the same easing every other transition in this file already uses), folded into the…
- **sidelines are their own clusters, and the mainlines audit clean** `the board`
  L6.3: leads() has recorded every supported string since L3.2, but nothing ever read a set of them as anything - each was an isolated pair with no way to tell a genuine sideline apart from a weak attempt at a mainline. sideline_clusters() groups the lead graph by union-find and reports which theory ids (if any) each cluster's own nodes are strung to: zero is a pure side story, one feeds a single mainline, and two or more - the case L6.3 named directly -…
- **a published theory can actually be retracted** `the board`
  The checklist and the last commit already described retract() as done, but the function did not exist yet - publish() was still a one-way door. This is the real implementation it was describing:
- **three more from the playtest** `playtest fixes`
  AG1.4 — "idk if there's a full screen option." There was not. SCREEN sits beside VIOLENCE in settings, F11 works anywhere because that is the key every player tries before looking for a setting, and it is restored at startup — a setting that saves and is never reapplied is a setting that does not work. The row reads the window rather than the saved value, so it cannot disagree with reality.
- **Holy Cow**
  big imrpvoements little time hehehee
- **fix the three bugs the first playtester found** `playtest fixes`
  Somebody who is not Greg played the build, and found more in an hour than a day of reading the code did.
- **Update the agent brief for the evening state**
  The checklist has grown from 17 sections to 32 since this file was written, the version ladder now governs how anything gets ticked, and six new sections need owners. Written so an agent can be pointed at it cold and know what changed without reading the whole session.
- **the player feels their own hitstop** `combat feel`
  scale_for() only ever reached the encounter loop's actor_delta, so the player — the other half of every exchange they are in — kept ticking at full speed through their own hitstop. The point of a local freeze is that both bodies in contact feel it. Windup, attack cooldown, the arsenal and the rig animation now run on the player's own scaled clock.
- **adopt LimboAI for the layer that did not exist** `the hunt`
  Greg asked whether to start using LimboAI, which has been sitting in the project unused at 119MB. The answer taken here is narrow on purpose: do not port what already works. The encounter AI is a state string with branches, it functions, and rewriting it into behaviour trees is risk for no player-visible gain.
- **the player is the other half of their own hitstop** `combat feel`
  scale_for() only ever reached the encounter loop's actor_delta. The player kept ticking attack_cooldown, dodge_cooldown, arsenal reload and the rig's own walk/swing animation at full speed through a hit they are the other participant in, which is backwards: a local freeze is supposed to say the blow met resistance for both bodies in contact, not just the one on the receiving end.
- **the reveal stops snapping** `look and feel`
  The veil was binary per cell, so the boundary between walked and unwalked was a hard staircase — which is the opposite of what Greg described. He asked for something like cleaning a massive window, and a window does not clear one square at a time.
- **the satellite is real, and the player is a head rather than an arrow** `look and feel`
  Six of A10 ticked, each verified by looking at the capture rather than by trusting that the code ran. The map now draws the actual region underneath its chart: terrain, contamination pools, roads and building footprints in their own colours, with the districts, contacts, survey block and scale bar still reading over the top.
- **Checklist: remove the stale duplicate B v2 list**
  Audited all six items on request rather than assuming: B1.9v2 (organ deformation), B4.10v2 (carrion eating rot), B4.11v2 (blood persisting across scene swaps), B6.7v2 (compound vs closed fracture), B6.8v2 (internal vs external bleeding) and B2.7v2 (pain driving posture) are all genuinely built and tested — part_viewer.gd's collapsed-lung assembly, carrion_scavenger.gd, baseline_human.gd's blood-evidence persistence and pain-posture application, and…
- **the slots, and what you are not supposed to touch** `cybernetics`
  Greg's idea, and the best expression of this game's own premise that has come up: slots for the spine and the body's cybernetic organs, filled and locked at decanting, and pulling one warns you first — "you don't want to go rogue yet do you".
- **Record AB2, AB3, AC, AD, AE and S2**
  A large set of ideas written down before any of it is built, with the priority Greg named kept intact: the first person comes first.
- **the map becomes the world seen from above, and AA records what it is for** `look and feel`
  satellite_view.gd renders the actual region into the map from a camera in the scene the player is standing in — one world, not a second copy to keep in step. Zooming does not scale a picture; it flies the camera down, and past a threshold it tilts forward until it is looking at the horizon. That is why there is no separate street view: it is the same camera at the bottom of its own descent, arriving at 1.68m, the same eye height the player's own camera…
- **give the Board a door** `the board`
  Greg: "the pinboard i forgot how you even access the pinboard."
- **the location crest and hunt thread finally get I0.6's own rule** `cameras and driving`
  The vitals were fixed last pass; the location crest (top centre) and hunt thread (top right) were the two floating fixtures still left over — both permanent regardless of whether they had anything current to say. I0.6 already killed the identical problem on the derby's own hunt readout ("a rival arrives when they change, not permanently"); the on-foot HUD in gothic_field_hud.gd never got the same treatment because it is a separate file from the derby's…
- **the rail is pointable** `screens`
  Greg: "fix the game so you can click when your in the tab screens... i get the up down arrows ect but make it clickable its just too restrictive" — and "making when you hover the mouse the menus are highlighted, but not fully pressed like they are when they are clicked".
- **the game exports and the exe runs** `shipping`
  Greg asked which branch his friends should launch, and the honest answer was "none of them" — nothing had ever been exported, so running this meant installing Godot 4.7.2, cloning, and opening project.godot in the editor. That is a developer workflow, not something you send a mate.
- **reshape the shotgun and sidearm off the sword's own trick** `cameras and driving`
  The cleaver already read clean because it is simple: one axis, one small tilt. The shotgun and sidearm still carried a shared -0.72 rad tilt on each piece, authored back when the hand itself was unrotated — on top of root's own counter-rotation (added when the sword was fixed) that compounded into three boxes each pointing a different direction, reading as one stacked blob rather than a held weapon.
- **update**
- **the swing bonus finally reads the arc it returns** `combat feel`
  swing_side has alternated every swing since O5.1 and swing_momentum() already handed it back in its own return dictionary, but the power bonus itself only ever checked whether you stepped toward where you were looking — the arc's own direction was tracked and completely unused. A cut thrown while side-stepping with the blade's own travel read identically to one thrown side-stepping against it.
- **verify armor was already in the resolution, not add it** `combat feel`
  Audited rather than built. apply_hit() already reads installed.armor scaled by the implant's own condition and reduces applied damage by it, on every rig — written this session under B2.2/B2.3, and the v2 claim that armour and plating were not in the resolution at all simply predates that work. This project's plating is surgical rather than worn, which fits the biopunk register: a ceramic sternum or a load-bearing spine cage out of implant_catalog.gd…
- **hitstop stops being the world's problem** `combat feel`
  v1 stopped time with Engine.time_scale, which works and is wrong. Your cleaver landing froze every other fight in the region, the traffic and the weather along with it. Hitstop is supposed to say *this blow met resistance*; a global freeze says *the world paused for you*, which is a different and much cheaper feeling.
- **the guard now has a front** `combat feel`
  guard_absorb() never took an attacker position at all, so raising the guard toward whatever you were looking at somehow also covered your back — there was no such thing as flanking the player, only whether the guard button was held. It now takes the attacker's position and checks it against a real frontal arc, 100 degrees either side of where you are actually facing; outside that arc the blow goes through whole, as if the guard was never raised toward…
- **Bigboy**
- **enemies get real footing instead of a binary lock** `combat feel`
  The player has had a continuous footing meter since O5.7 — whiffs, blocks and shoves all chip it, recovery is gradual, and stumbling below STUMBLE_AT has real consequences. Enemies still ran on the older staggered state alone: a hit either interrupted them outright past a fixed severity threshold or left no mark on them at all. Three medium hits and zero hits read identically right up until a fourth one crossed the line.
- **feat: summon carrion into the Hunt Grounds**
- **feat: show damaged vertebrae on the shared spine**
- **Repair celloutz_type after a bad conflict resolution**
  My own mistake, and worth recording. Codex and Agent C both touched celloutz_type.gd, and I resolved the conflict with the same union-and-dedupe heuristic I had been using for CHECKLIST.md — keep both sides, drop lines whose first 24 characters repeat.
- **feat: persist blood evidence across scene swaps**
- **feat: make 33 vertebrae a shared injury system**
- **feat: let carrion follow rot and count 33 vertebrae**
- **the clinch grabs a limb now, not an abstraction** `combat feel`
  Rob and recruit already connected to a held body — F7.2 lets you take something off somebody you are holding, and persuade/threaten already read pain and fading consciousness. Hold and force did not: the tug-of-war already softened their resistance for arm damage in general through combat_ratio(), but the clinch had no concept of which specific limb it actually had. Grabbing an arm that was fine and one already broken produced an identical contest.
- **feat: make pain change posture before movement**
- **feat: reveal internal bleeding only by X-ray**
- **the reigning Horseman has real behaviour of their own** `the cosmology`
  wire_net.gd's _retaliate() now also raises the reigning Horseman's own grudge (via TheFourHorsemen.current_reign()) whenever any Sin CellOutz commands is contested — half what the Sin's own captain feels directly, since it is once removed, but the same real grudge field the Hunt System already reads. A Horseman is no longer just a name and a doctrine variant: enough contested Sins under their reign and they accumulate exactly the grudge that makes any…
- **Put O v2 back in section O**
  It had been anchored on the same section header as D's second pass, so both landed in D — which read as D having ten v2 items and O having none. Caught by generating the page and looking at the tab labels rather than by trusting the insert.
- **feat: distinguish closed and compound fractures**
- **a contested Sin retaliates through its own captain's real grudge** `the cosmology`
  "The Sins are named and placed but do not act on the world." wire_net.gd's contest_channel() now raises the targeted faction's own captain's grudge toward whoever contested it, scaled by severity (flood 4, out-publish 6, discredit 10, hijack 15, cut 20 — a permanently cut mast is remembered harder than an afternoon of flooding). Deliberately not a scripted counter- raid: grudge is the exact field RivalRegistry/F2 propagation already read, so this makes…
- **The version ratchet, and v2 for I, L and O**
  Greg, two corrections that turn the version idea into a working system rather than a numbering scheme:
- **the device remembers, and no two are broken alike** `the handheld`
  Three of section C's second pass, and the first proof that the version system finds real work rather than generating wishes.
- **Mara's fight was a flat counter behind a real body** `combat feel`
  Generic hostiles already had this — anatomy.dead/downed derive from real zone and blood state, verified by the encounter_actors path. The canonical Mara fight did not: melee correctly wounded her BaselineHuman rig (a comment already there records that fix), but whether the fight actually ended ran off enemy_health, a separate flat counter that only ever subtracted a fixed number regardless of which zone took it. The prosthetic surge subtracted 30 from…
- **Fix: CharacterSheet.randomise() was not actually seed-reproducible**
  Found this landing N2's lottery test: pool.shuffle() draws from Godot's global RNG, not the function's own seeded rng, so a fixed seed produced a different build depending on how much global random state other systems had already burned through — passed in one worktree, failed the same seed after merging into the shared tree where more autoloads run first. Each trait is rolled independently regardless of pool order, so the shuffle was never doing…
- **feat: render compressed lungs as authored assemblies**
- **feat: add ritual seal roster data**
- **overspending is now possible, and a broken run is marked, not hidden** `cybernetics`
  character_sheet.gd's toggle_trait() used to hard-block on cost via can_take() — which is exactly what made "overspending is possible and the game lets you do it" (N1.3) false. can_take() now only checks the trait exists and isn't already taken; the old budget check survives as is_affordable() for whoever wants to warn on a choice rather than block it. vat_intake.gd's existing HOT colour on points_left() <= 0 already reacts to this with no UI change needed.
- **feat: add authored ritual seal vocabulary**
- **chore: verify Tree-only karma reading**
- **v2 passes for the five sealed sections**
  Greg: "in the checklist make v2s for everything."
- **Versions: a tick is not a finish line**
  Greg: "make it so you can click and change the a1 to a1v2 and its a new set of things to reimprove upon the mechanics... up to v3 or v10 would be the go with this work system just recycling and reupgrading code over and over."
- **the opening reframed, one handler line, verified visually** `the cosmology`
  DESIGN/COSMOLOGY.md: "the opening reframed: CellOutz grew you, which is why the debt is in the meat." The existing handler line already said the debt was in the meat; nothing said whose meat it started as. Added the next beat to vat_chamber.gd's BEATS array — a pure clock-driven subtitle list with no coupling to the phase/movement state machine it lives beside, confirmed by reading _update_beats() and _update_sequence() before touching it, so this is a…
- **sitting still, and the equipment screen** `factions and standing, cybernetics`
  Two things from Greg, written down before either is built.
- **Fill the alphabet to Z, and write down the remaster**
  Greg: "get the checklist to letter z in ideas then make it complete then remaster it in a new way where we combine all the ideas together... then all those link into this new checklist of the game mechanic being a true thing we can combine."
- **the wizardsonlyfoolz Law, Book and founder, approved by Greg** `the cosmology`
  Drafted and approved 2026-09-12. Orrin Vail, "the First Frequency," gets three official biographies (ascended from a relay tower / a pre-Flash engineer who never came back down / never existed at all, the name a rotating paid title) published side by side and mutually contradictory on purpose — the founder whose biography does not survive checking, made concrete rather than asserted. The Law is one line ("There is no static, only those who have not yet…
- **the Four Horsemen, named by Greg, on a scored rather than scripted rotation** `the cosmology`
  New systems/the_four_horsemen.gd. War, Famine, Pestilence and Death are real WorldHistory person subjects under CellOutz, each with a real command grip on one of the four original Sin-factions (War/Ashline Wreckers, Famine/Black Mile, Pestilence/Soft Rot, Death/Choir of Marrow) rather than an invented stat. War holds CROWN to start.
- **seals grown from a seed, not traced from Mathers** `factions and standing`
  goetic_seals.gd was deliberately data-only — 72 names, ranks and numbers out of the 1904 Lesser Key of Solomon, verified against a primary source, with a comment naming celloutz_type.gd as the file that would eventually draw them. Per this project's originality non-negotiable, the roster is free public domain material but the historical sigils are not something this project reproduces, so there is nothing to transcribe here — an original generator instead.
- **verify held-and-hurt rather than rebuild it** `combat feel`
  This one was already built, by F7, before O5 was written down. Pain and fading consciousness already feed hold_strength; hold_strength already feeds both persuasion and coercion; a strong enough clinch already produces consent; and _accepts_recruitment in the downed-resolution window already reads that consent. The chain was complete and I had written none of it.
- **put the weapons down** `combat feel`
  "The body is the weapon system" was a claim this build could not support. The arsenal hands the player a cleaver, a shotgun and a sidearm at spawn and never takes any of them away, so unarmed was not a state the game could be in. You could beat somebody with a severed limb — which is a good thing to be able to do — but you could never simply hit them.
- **wizardsonlyfoolz gets a real member, ranks/paid grades don't need the blocked half** `the cosmology`
  wizardsonlyfoolz had zero real (kind: "person") members, so its own WireNet.pyramid() read as a genuinely empty order — not because anything is broken, but because nothing had ever joined. Registered wren_ashby, paid into the bottom rank rather than promoted, giving the same generic pyramid/buy-in machinery every Sin already uses a real headcount to work with here too.
- **add the regression test for the shared tree's enemy AI changes** `combat feel`
  O4.1/O4.2/O4.3 (commitment punishment, orbit spacing, wound-scaled combat) landed in bone_yard_hunt.gd and CHECKLIST.md already from this same shared checkout. Adding the test that was built alongside them: tests/enemy_ai_test.gd (5 checks) verifying the attack-clock pressure while the player is mid-windup, that a second hostile orbits at a stand-off distance rather than stacking into melee once the first one holds it, and that the actor already in the…
- **FACTIONS.md step 7: offer the propagation-gating read, don't wire it blind**
  wire_net.gd's new signal_reach_factor(faction_id) returns signal_control as a 0-1 multiplier rather than a yes/no gate, so a half-flooded channel can carry a rumour half as far instead of either the full distance or none of it. This is the "signal control gates grudge propagation" half of FACTIONS.md step 7 that lives on my side of the seam; the other half (F2's actual propagation, and raids generating the events channels report on) is Codex's…
- **the player can be put off balance too** `combat feel`
  Enemies have had a staggered state for a long time. The player had nothing, and that asymmetry is most of why a brawl read as one body hitting statues: you could over-commit, whiff, get your blow turned, take a shove that threw you seven metres, and still be standing exactly as square as when you started.
- **point at the ending content it was waiting on, now that it exists** `factions and standing`
  route_endings.gd's ascended_continue (E7.2) is exactly the hand-off E5.3 named as missing when E5 was first built this session. No new code — just ticking it off now that the dependency is real instead of leaving it looking unstarted.
- **a swing carries momentum** `combat feel`
  Every blow in the game was identical regardless of what the body was doing when it was thrown — the same damage standing still, backpedalling, or running somebody down. That is what makes melee read as a button rather than as a weight on the end of an arm, and it is the half of "the combat needs reworking" that hitstop did not touch.
- **the ladder-lock default made explicit, and God's attention named** `the cosmology`
  K3.1 was answerable from what route_endings.gd already does rather than a new mechanic: tree_alignment() never closes on its own, but check()'s own lock does — the first ending reached is permanent, and the other threshold is silently ignored afterward. Documented as a default worth confirming or overriding, not a claim that the design question is settled. Test extended to actually prove the lock: a subject who signs away and then drifts all the way…
- **camera rituals, verified against the same photo contract publish_photograph() uses** `factions and standing`
  New systems/ritual_app.gd. Three rites (rite_of_bael, rite_of_paimon, and Greg's own worked example — five gored heads — as rite_of_the_filed_tooth), each keyed to a real seal from goetic_seals.gd and paying its reward through boons.gd rather than a bespoke reward system: E2 (seals), E3 (rituals) and E4 (boosts) are one system per DESIGN/RITUAL_AND_KARMA.md, not three, and this is that stated once in code.
- **walk them, and hold them in the way** `combat feel`
  The clinch was already most of a brawl — press, talk, lean, take, break, with advantage fought over between your arms and theirs and a real cost for losing it. O5.3 and O5.6 were effectively already true; the checklist just had not caught up. What it could not do was *move*, and a person you cannot move is a conversation rather than a position.
- **the seal roster as data, verified against a primary source** `factions and standing`
  New systems/goetic_seals.gd. The 72 Ars Goetia entries (name, rank, Mathers' traditional number) are public domain per DESIGN/RITUAL_AND_KARMA.md and are free to use as data — non-negotiable 1 only requires the drawn glyphs themselves to be original code, which stays Agent A's celloutz_type register (E2.1/E2.4, not touched here). Fetched and checked against a primary reference rather than transcribed from memory, since citing the wrong name for…
- **the vitals were the literal corner widget the rule names** `cameras and driving`
  Every other element in gothic_field_hud.gd earned its keep as an artefact — the weapon well is a torn recess, the hunt thread is an eye on a socket — but the vessel/breath vitals were still a plate pinned to the top-left corner with no relationship to anything else on screen. That is exactly what M1.6 and I0 call out: well-drawn UI is still UI if nothing ties it to the world.
- **the counter-rotation was tuned against arm_raise's old value** `cameras and driving`
  Two agents fixed the same invisible-weapon bug from different angles this session — one shallowed hunter_body_motion.gd's arm_raise from 1.14 to 0.62 rad, the other counter-rotated hunter_arsenal.gd's weapon models against the old 1.14. The merge kept both, which meant the counter-rotation was now wrong by the full difference and had quietly pushed the weapon back toward the bottom edge of frame — passing the frame test's generous margin but reading as…
- **Settle why Hunt Grounds captures come back black**
  Two captures of the real hunt scene came back near-black while the live game looks bright, and the first time I put it down to the ashbloom sky being dark by design. That is a guess, and guessing the same thing twice is how a real bug survives, so this measures it instead.
- **the five signal-territory routes, built against real state** `the cosmology`
  wire_net.gd's new contest_channel() is DESIGN/FACTIONS.md's "a Sin holds a channel, not a keep" made mechanical:
- **the weapon models were invisible at the corrected FOV, not just unconvincing** `cameras and driving`
  hunter_arsenal.gd's three weapon models were positioned and never touched again after M4.1-M4.3 corrected the first-person FOV and eye height. Measured rather than eyeballed: at the corrected numbers the old local offset put every weapon outside the camera frustum entirely, and its rotation was authored against an unrotated hand — but hunter_body_motion.gd's arm_raise pitches the hand ~65 degrees forward for the first-person pose, so the blade was…
- **both route endings detected and written once** `factions and standing`
  New systems/route_endings.gd: check() reads real accumulated tree_alignment() and permanently records which pole a subject actually reached (Descent's demon_signed near CellOutz's own -0.95, Ascent's ascended_continue near wizardsonlyfoolz's 0.92) — written exactly once via route_ending_recorded, so a second check never re-fires the event or contradicts the first answer.
- **derby floodlights stop re-tinting the pit's own contamination colour** `sound and the pit`
  The eight floodlights alternated orange and green per light, which painted whatever stood nearest whichever one was overhead - competing with the contamination colour regrime() and WorldLook.surface() already carry on the authored materials, and a real part of why the pit reads close to monochrome. Lights are now a single practical warm-white; colour now comes from the surfaces.
- **drugs with a real body cost and a real door to the entity layer** `factions and standing`
  New systems/substances.gd: Marrow Dust, Choir Bloom and Static Hymn, each built from what Ashbloom actually has lying around rather than a real drug renamed (non-negotiable 1). Pays into the same anatomy_state ledger boons.gd already pays boosts into.
- **engine load bands and impact severity layering** `sound and the pit`
  procedural_derby_audio.gd gains a third engine_strain layer gated above 72% effort, so redline arrives as a distinct band rather than one more tone crossfaded across the whole range - a stripped chassis with an engine that only ever whines louder doesn't sell "stripped chassis" either. play_impact now stacks a shared low-end impact_body layer onto the material voice once a hit passes 50% intensity, so a severe hit differs from a light one by added…
- **stripped mechanism, bone lashings and fungal bloom on the derby cars** `sound and the pit`
  Silhouette.dress_vehicle() hangs an exposed engine/driveshaft/sill kit, bone struts with sinew lashings, and wheel-well fungal bloom onto both the player skiff and the AI wreckers, since regrime() only ever remapped material names already baked into the glTF and could not add geometry.
- **a guard you hold, and a parry you time** `combat feel`
  Dodging already worked and was already consulted on incoming damage, so evasion was real. It was also the only defensive option, and one option is a reflex rather than a decision — you either rolled or you ate it.
- **an injured body now looks injured** `combat feel`
  The mechanics of limb damage were already in and already working: mobility_ratio() slows a broken leg, combat_ratio() weakens a broken arm, and both have driven movement and damage output for a while. What was missing is the last word of the checklist line — *visibly*. Nothing showed until a limb actually came off, so in every ordinary fight, which is nearly all of them, a man with a shattered forearm stood exactly like a man who had just walked in.…
- **lesser demons are RivalRegistry's rivals, reread, not respawned** `the cosmology`
  DESIGN/COSMOLOGY.md's four tiers (Leadership/Sins/Captains/Lesser demons) were prose describing a hierarchy nothing could answer "which tier is this subject" about. New systems/demon_hierarchy.gd is a read-only classifier, not a generator: a lesser demon is any RivalRegistry-produced rival (F4.1) with no faction, a Captain is whoever a Sin's own relations already name as its commander, and Leadership is whoever actually holds CellOutz's CROWN rank —…
- **the unlock could never fire, the camera cut hard, the weapon read as a slab** `cameras and driving`
  third_person_unlocked() counted boss kills by reading a "subject" key off npc_resolution events; every writer uses "subject_id", so the loop always saw an empty string and the unlock condition could never pass regardless of what the player did. Fixed, and paired with a felt moment (impact_feel kick plus a one-shot WorldHistory-gated line) so the unlock lands as something that happened rather than a permission flip discovered by trying F.
- **audit confirms no good/evil number ever hits the screen** `factions and standing`
  character_archive.gd's _draw_tree_alignment() draws tree_alignment() only as a marker position between ASCENT/LIMBO/DESCENT labels; nothing in the dossier prints the number. Audit, not a build — ticking it off rather than leaving it looking unstarted when the design constraint is already held.
- **temporary boosts with a real, escalating body cost** `factions and standing`
  DESIGN/RITUAL_AND_KARMA.md: boosts are always temporary and paid in the body or in standing, never a currency. New systems/boons.gd is the machinery E2 (rituals) and E6 (drugs) will hang boosts off of once their own content exists — neither is built yet, so this invents no ritual or drug, only the rule.
- **build the cabin, and write down the brawl properly** `cameras and driving`
  The derby has always been a chase camera looking at a box with wheels, which makes the car a thing you steer. vehicle_interior.gd makes it a place you are sitting in: dashboard, transmission tunnel, A-pillars raked in at the edges of the glass, a welded two-spoke wheel, a left hand on the rim and a right hand holding a pistol up near the windscreen.
- **fix ascent_entities bugs and land the checklist entry** `factions and standing`
  The prior commit ("K: the ascent entities, landed from the shared tree") swept up this file before two bugs in it were fixed:
- **the ascent entities, landed from the shared tree** `the cosmology`
  Agent C's work, written into the main checkout rather than its own worktree because it never moved there. Committed here rather than left to be lost or overwritten — the third time this has happened today, and the reason their branch still reads as zero commits.
- **P2b: the demo's edges are the world refusing you**
  Greg: "more exploration would be locked off and features in the demo but then in the mainline its playable."
- **one build, two doors, and a wall** `the demo`
  Greg corrected the demo design almost immediately, and the correction is better than what I wrote.
- **the thirty-minute demo** `the demo`
  Greg: "the next big section needing to be added will be making the game a 30 minute demo seperate to the orignal version."
- **One launcher, and the dead demo scenes removed**
  Greg: "clean up older demo versions of older builds and make one main launch because i keep losing the current file."
- **give CellOutz, wizardsonlyfoolz and the missing Sins real subjects** `the cosmology`
  FACTION_TREE_AXIS has held celloutz and wizardsonlyfoolz since the M/N/O capture, and Pride/Lust/Sloth have had no faction at all while the other four Sins were "already half in the code" per DESIGN/COSMOLOGY.md. Both were two names in a table, which is exactly the K1.2/K1.3 gap.
- **Wizards Only Fools, and M1.5 — landed from the shared tree**
  Two pieces of work that were sitting uncommitted in the main checkout rather than in a worktree, because the agents launched for B and C started in this directory before being moved. Committed here rather than discarded: the work is sound, it is only in the wrong place.
- **the Expanse never said how big a person is** `cameras and driving`
  A doorway is the only object in an exterior that reliably states human scale, and this generator did not have one. The "door" was a gap between two wall segments that both ran floor to roof, so on an 8.5 m shell the opening was 8.5 m tall and 2.4 m wide. Nothing anywhere in the region stated a human dimension, which is why the shells read as enormous or tiny depending on what the player last looked at — and at FOV 78 that ambiguity is the whole image…
- **Write the four-way split down**
  Greg is running three Claude accounts plus Codex. This is the division of the remaining work so four agents can grind in parallel without fighting over the same files: one owner per file family, one worktree each, narrow commits, and everybody ticks their own checklist lines.
- **the wide FOV was a fisheye and the eye was too low** `cameras and driving`
  Greg asked for perspective that holds up in the game's own universe. Two faults, one of them mine from an hour earlier.
- **combat had no moment of contact** `combat feel`
  Greg has said the combat needs reworking in four separate sessions. Three previous passes answered it by fixing what got hit — aim resolution, lock-on, which limb the zone resolved to, how much gore came off. All real bugs, none of them the complaint, because the complaint was never about accuracy.
- **Combat: make melee presses committed actions**
- **Combat: let bodily damage create punish openings**
- **keep debug controls out of shipping builds** `enemies that remember`
- **Capture today's directives as sections M, N and O**
  Three things Greg specified in the last stretch, written down before any of them is built, because the second half of an idea is the part that gets lost.
- **turn downed people into taskable assets** `the hunt`
- **The index you were actually opening was never the one I rebuilt**
  Greg, on seeing the index in a live build: "fix this im tired of it". He was right to be, and the reason it kept coming back is worse than a styling miss.
- **make deliberate death cost the carried run** `the hunt`
- **make defeat persist as capture** `the hunt`
- **Track the .uid files for F4's new scripts**
  Godot regenerates these on every import, so leaving them untracked makes the tree dirty for whoever opens the project next.
- **let survivors become rivals through their wounds** `the hunt`
- **the volume sliders were doing nothing** `sound and the pit`
  Greg asked to fix the entire game's sound. The first thing measurement found was not a missing effect — the mixer was not connected to the game.
- **the career is the wall, and a theory can end the game** `the board`
  Each theory is a route, and a route is a handful of conditions on the world: take something off a body and keep it; sell one and see who does not ask where it came from; three, because a pattern is three. Nothing tracks the player through them and nothing is stored. The board asks WorldHistory at the moment it is opened, which is what makes L5.2 true in the literal sense — there is no quest list in this game because there is nothing for one to list.
- **Polish the live interstitial preview**
- **The loading screen becomes an actual X-ray**
  Greg: "we want the loading screens to be way more coherent with 3d visceral gore matrix loading screens and 3d organs bones xrays".
- **let death open a real succession** `the hunt`
- **publishing a theory, and the bill for being wrong** `the board`
  A theory leaves the wall through the Wire actions that already existed. Every string holding it up is checked: all supported and it goes out as an expose, one bad connection and the whole thing is a fabrication, because the weakest claim in a story is the one that gets checked.
- **the wall is yours, and a string is a claim** `the board`
  L1 built the board by reading WorldHistory, which quietly made it a view of the world rather than one person's reading of it. Inverted: the authored theories are up because they were on the wall when the player found the room, exactly one card is theirs, and nothing else appears unless they put it there. Pinned off the index, off a photograph — which carries the contents that were actually in frame, so a picture on a wall of speculation is the one…
- **give the derby arena back** `screens`
- **the Board — the storyline as a wall, not a quest log** `the board`
  Greg: "the main game storyline career option thing is a conspiracy theory pin board of all the ideas etc, in the Charlie Always Sunny style conspiracy board" — "and that links everything in."
- **the map stops explaining itself** `screens`
  The chart carried a legend: seven coloured dots with words beside them, plus a control strip, both in the system fallback font. That key existed because every contact on the sheet was the same dot in a different colour, so the fix was to draw the marks rather than restyle the list. A hostile is a triangle pointing at you, an ally a closed ring with a centre, a neutral an open ring, a body is struck out, a cache is a square. The key is gone.
- **CARRY holds objects, not rows** `screens`
  The handheld's CARRY page was a spreadsheet — name, condition and weight in aligned columns with half the page blank. You are carrying pieces of people and it read like a delivery manifest, which is the presentation that makes it ordinary.
- **make wreckers land real hits** `sound and the pit`
- **The body finally reads the sheet you filled in**
  Greg: "nothing with the character creation modelling gets made". He was right, and it was worse than cosmetic.
- **Capture the Board: the storyline as a conspiracy pin board**
  Greg: the main storyline and career is a conspiracy pin board, Charlie's wall, red string — and it links everything in. Recorded whole before building any of it, because the second half is the part that matters.
- **the surviving internet is places, not a feed** `screens`
  The Wire is a scrolling column of posts, which is what a platform looks like. DESIGN/IN_GAME_INTERNET.md asks for the other thing as well — dead forums, automated shops still taking orders nobody fills, a business with no surviving employees — and that is not a feed. It is a set of places, each built by a different person with different taste and different competence.
- **direct the playable opening** `sound and the pit`
- **Document and close the G4 silhouette pass**
- **the boxes were never the buildings** `sound and the pit`
  Greg has said "everything looks like boxes" in three sessions, and it kept being answered with surfaces — contamination on the albedo, fog pulled back, the region routed through the material system. All of that was worth doing and none of it touched the complaint, because a texture does not change an outline. A box with brilliant grime on it is still a box.
- **the handheld becomes a mirror you look into** `screens`
  Greg re-specified the device: *"the internet portal through the black mirror phone device with a jester design on the back of the black cracked mirror you look into."* That is a different object from what was there, and the difference is not decoration.
- **everything printed on the index is pointable** `screens`
  I5.1 already made body parts clickable. This extends the same idea to the rest of what the dossier prints, through one mechanism rather than three.
- **the feed is hostile, your own tools are not, and that is the joke** `screens`
  Section I's dark-pattern split, built as a real difference in behaviour rather than as a line of copy — the satire only lands if the two things actually behave differently when you use them.
- **the interface is a thing a bleeding person is holding** `screens`
  Two of section I, six segments, both built on state the game already tracks rather than on new UI bookkeeping.
- **Give the menu sky, fix the AI cornering, and write the derby bug down**
  Three things, one of them an admission.
- **Escape stops the game, and the axis finally has two ends**
  Two things, and the second is Greg's.
- **Keep test output out of the tree**
  .test_appdata/ and artifacts/ are Godot user-data and capture PNGs written by test runs. They were untracked and got swept into the previous commit by a blanket 'git add -A'. Ignored rather than deleted: the capture PNGs are how visual checks get looked at, they just do not belong in history.
- **Greg's artwork reaches the screen** `sound and the pit`
  The pipeline built eight body sheets, six plates and three Wire collages out of his own collection last session, and nothing loaded any of them — G1 looked finished in the filesystem and unchanged in the game.
- **the axis you sit on is the price you are quoted** `factions and standing`
  Karma already moved you along the Tree (E1.1) and the dossier already drew it. This is the half where it is felt. Nothing new is stored and no number is shown: FACTION_TREE_AXIS already holds where each faction sits and tree_alignment() already says where you sit, so the price is the distance between two numbers that both existed already.
- **Track the .uid files for this session's new scripts**
  Godot 4.4+ writes a .uid beside every script and this project already tracks 51 of them. The ones for clinch, extraction, field_camera, world_xray, intake_direction, the two catalogues and the new test scripts were left untracked, so a fresh checkout would regenerate different ids and break the references that point at them.
- **Rewrite the cold handoff against what the game now is**
  The old one was written at 138fe4f and is three sections and sixteen commits out of date - it still lists B6.2 as the critical path and 113/253 as the count.
- **Greg's artwork becomes a texture set** `sound and the pit`
  Unblocked - the collection is Desktop/Art Collections, 43 real artworks once the Photoshop and After Effects installs sitting in the same folder are excluded.

## 2026-09-11

- **a body that is the size the sheet says, and an intake that is directed** `making a character`
  D4.2. Every race has carried a build factor since D4.1 and the rig never read it, so a Marrow-Cut and an Unreset stood exactly the same height. build() now scales the zone layout - offsets along with sizes, which is what keeps the feet on the floor, because the legs sit at half their own height above the origin. Organs, bones, hitboxes and stumps all follow, since they are built from that layout. The player rig reads its race off the filed sheet.
- **the camera takes evidence, not screenshots** `the handheld`
  A photograph is not an image. It is a record of what was genuinely in shot - Godot's own frustum test, so it agrees with what the player could actually see - and what state those bodies were genuinely in, read off the same rig the fight happened to. N takes it. The caption is generated from the contents, so it can never claim anything the body was not doing.
- **the X-ray looks at the world, and B becomes C2** `bodies and gore`
  xray_cursor.gd has said since it was written that seeing inside a body should be a constant available verb rather than a mode. It was only ever true inside the dossier, where the body in front of you is a diagram.
- **grudges travel the edges that actually exist** `the hunt`
  F1 built witnesses who walk home. What they did on arrival was write one line into their faction's file and stop. The story now carries on from them along the relation graph the index has drawn since A2.4 - and only along it, so somebody with no edge to anyone never hears a thing.
- **the clinch becomes a social verb** `the hunt`
  Having hold of someone was a wrestling match - press until they drop. It is now a conversation you are winning, and which verb works depends on who you have become.
- **the Tree axis accumulates from what you did** `factions and standing`
  The Ascent/Descent axis has been computed, stored and drawn on the dossier since the index was built, and the only thing that ever moved it was the faction you were born into. DESIGN/RITUAL_AND_KARMA.md has said all along that karma is not a new number - it is this axis, made to mean something.
- **Blood is spatter again, not sheeting**
  Every landed drop left a mark about three metres across. With MAX_SPLATS at 420 a real fight buried its own floor in overlapping red, which is why the gore read as flat translucent sheets instead of a body coming apart.
- **Let the radio be turned off**
  Reported from play: the radio blares and keeps blaring after you get out of the car. It was worse than that - it had never been possible to turn it off at all.
- **reciprocity, and what a stump costs** `bodies and gore`
  The player was the one body in the world that fought and ran exactly as well with one leg as with two. The rig had been recording where they were hurt since it was built and nothing ever read it back.
- **rob cybernetics off a body** `bodies and gore`
  Robbing is a dig, not a loot roll. Hardware sits at Layer.CYBERNETIC and an organ one above it, so reaching either means going through everything on top - and a body already opened in the fight is faster because zone_depth (B4.3) is subtracted from the work, which is that ratchet finally paying for itself. Hold F over anything downed or dead in reach. The tool sets both speed and what survives: hands are slow and ruin a third of the part, a blade is…
- **finish chunk physics and layers (B4.5-B4.9)** `bodies and gore`
  Zones now show the deepest layer they were ever cut to, not just inside the chunks that came off - an authored patch on the zone mesh itself, and the bone-through-skin read now persists off the same zone_depth memory instead of only the current health ratio. Fixed a real ordering bug on the way: _refresh_zone ran before _shed_chunks wrote the new depth, so the exposure mark was always one hit behind.
- **implants and wounds become real parts with real zones** `bodies and gore`
  Two keyword-guessing tables in body_inspector.gd (IMPLANT_ZONE_WORDS, WOUND_ZONE_WORDS) inferred where hardware and injuries sat from substrings in their names. Replaced both with authored catalogues: implant_catalog.gd (18 named implants, each with a zone, armour, max condition and mesh profile) and wound_catalog.gd (zone and severity per wound). Hardware now degrades from damage to its zone and that condition is a real number everywhere it used to…
- **Make body inspection tactile and organs distinct**
- **Make severed limbs usable and damage icons legible**
- **Make dismemberment a live combat verb**
- **Add a cold handoff document**
  Greg is moving the checklist to another model, so this is the thing that has to survive the move: what the project is, the four traps that cost an hour each if you do not know them, the workflow that actually finds bugs, and the checklist state with the one remaining critical-path item called out.
- **what is in the way, and what that sounds like** `look and feel`
  A9.2 adds the third axis to reception. It already depended on how close the dial is and how close you are standing; now it depends on what is *between* you and the transmitter, and the two kinds of obstruction behave differently on purpose.
- **the world only knows what somebody carried home, and you have a sheet** `the hunt, making a character`
  F1 is the cheapest thing in the Hunt System and everything else depends on it, which is why HUNT_SYSTEM.md lists it first. witness_ledger.gd draws the distinction the whole design rests on: there are now two records. What happened - WorldHistory, complete and true, the game's memory rather than anybody's - and what is *known*, per faction, always a subset, always later, usually wrong. NPCs act on the second.
- **the wheel, what you carry, and whether you have signal** `the handheld`
  C2, and the honest answer to the constraint rather than the easy one. Greg wanted Prototype's weapon wheel with time dilation *and* soulslike difficulty, and those pull against each other: a wheel that slows the world but not you is a reaction advantage handed out on a button. So the dilation slows everything including the player - it buys reading time, not reflexes, and you cannot open it to dodge - and it runs off a budget that drains while held and…
- **one object holds the interface, and it has a radio** `the handheld, look and feel`
  C1. DESIGN/IN_GAME_INTERNET.md opens by naming this problem - four unrelated fullscreen panels on four keys, nothing connecting them. The handheld already existed and did not solve it: it drew convincing junk hardware and then filled its screen with `_mode_lines()`, arrays of strings summarising panels that already existed and were far better. It was a *fifth* interface rather than the replacement for the other four, and it is exactly the "boxes of…
- **the map becomes an object, the car becomes a car** `look and feel`
  A7 is the one that mattered. Greg has said three times in different words that the derby is broken, and the venue was re-authored twice against it and measured *worse* both times. That was the clue: the arena was never the problem. The chassis was a single rigid box held up by a physics material, driven by a central force and turned by a yaw torque applied straight to the body. Nothing about it behaved like a car, so no arena could feel right around it.
- **make the index usable as well as legible** `look and feel`
  A8.4 first, because the rest depends on it. systems/celloutz_motion.gd is the one place easing rates live, named for what they are for rather than by value - a panel arriving, a selection travelling, a readout counting, a list scrolling. Its `approach` is frame-rate independent, unlike the lerp(a, b, delta * rate) everyone writes, which quietly behaves differently at 30fps and 144fps. New interface code picks a named rate instead of inventing a number.
- **rebuild the derby HUD, and A1.3 for the windscreen** `look and feel`
  Greg on the old one: "the car and bottom left and top left and the hunt signal is aids and the hull integrity honestly I hate it all." All fair - every readout was ThemeDB.fallback_font on a clean rounded panel, built before the project had a visual language.
- **Rework the checklist into segments you can check off**
  Greg wants to drive the build one step at a time rather than by feature, so the list is now segmented: every item broken into sittings, each sized to be built, verified, captured if visual, and committed on its own. Say a segment id and that is the whole protocol.
- **pieces of people that know what they are** `bodies and gore`
  Greg flagged this as the important one and he was right - it is the item three other unbuilt things depend on.
- **the cursor is a tool, and one of its buttons sees through people** `bodies and gore`
  Greg: "once you use the custom mouse it has a circular xray button you can click just for a gross factor and visceral elements."
- **Regrime the interface: Fallout and biopunk, not cyberpunk**
  Greg's read: "it's a bit too cyberpunk internet heavy, should be more fallout and biopunk post nuclear cynical insane online communities and corrupt evil world." He was right and the tell was the palette - thin bright teal vector lines on near-black is a sci-fi terminal, not a document that has been in a wet building for four years.
- **Make the body inspectable: parts leave the diagram and turn**
  B1 and B2. The anatomy system is the most complete thing in this project and the least visible - zones, organs, bones, bleed, fractures and implants all simulated, and the only place any of it surfaced was a kill cam that fires after the fight is over.
- **Capture the interface art direction, rebuild the checklist**
  Greg's UI direction arrived across several bursts and needed writing down as a standard rather than a mood. DESIGN/INTERFACE_DIRECTION.md:
- **Put turning heads in the index, and stop the page cutting**
  Greg: "i want the players or nemesis in the system to be icons at least spinning in 3d even if its just the head and then from there the 3d model is spinning with the xrays."
- **Rebuild the World Index as three pages**
  Greg's read was "the world index needs a UI badly it looks shit". It was a PanelContainer holding one default-font Label full of newline-joined prose, showing the most interesting data in the build.
- **Build the Wire, and unblock headless testing**
  Two things, and the second is the one that cost the time.
- **Capture the vat as character creation**
  Greg fired a full character-creation design mid-session. Recorded whole in DESIGN/CHARACTER_CREATION.md rather than half-built, per the brief's rule.
- **Bind Greg's own chart into the archive**
  The Allusions screen is his archive, so the mark the game binds should be his. 11 January 2007, small hours — Capricorn, and the wheel marks it. J now cycles the archive: artwork study, natal sigil, closed.
- **Draw the natal sigil, and record the Nemesis answer**
  DESIGN.md §16 already puts chaos magick in the world's rules and world_history.gd already reads every subject on an Ascent/Limbo/Descent axis. systems/natal_sigil.gd draws both: a twelve-house wheel with hand-built sign glyphs, bodies placed deterministically from a birth date, the classical aspects between them, and then the actual chaos magick operation performed on the result — strike out every repeated meeting point and bind what is left into one…
- **Give the game a typeface, and keep the pit honest**
  Greg's read was that the whole thing looks "tutorial level, same as the font". The font half was exactly right and had been hiding in plain sight all session: every interface in this project — the map, the resolution form, the kill cam, the HUD, the warning card, the transit plate — was set in ThemeDB.fallback_font, Godot's default UI face.
- **Give the game a front door**
  Built from the register across everything Greg sent this session: Postal 2's crude notice before the game and its menu with junk tumbling through it, HAVKER-MAN X's sense that an interface is a physical thing, Eternity Egg's UI made of rendered objects rather than flat panels. None of their art, layout or code is reproduced; a request to read a commercial game's source was declined.
- **Put textures on the world, and stop the fog eating them**
  Greg's read was "the map looks cubic and sucks". The geometry was not the problem: HAVKER-MAN X, which he sent as a reference, is also built from boxes. The problem was that every albedo in this project was a flat colour.
- **Add the clinch, and make a beating visible**
  Combat had no contact-range verb. Everything resolved at sword reach or not at all, so two people standing on top of each other swung through one another — the Half Sword register Greg keeps pointing at is bodies actually colliding, and there was no equivalent.
- **Give the named characters bodies, land blood where it hits, load for real**
  Three of the limits from the checklist, plus the one Greg named while I was in here.
- **Cover the seams with a transit plate**
  Every scene change was a hard cut straight from one .tscn to another with nothing over it — the menu into the derby, the vat into the derby, the derby into the Hunt Grounds. Greg's read was that the game feels like a set of dev tools rather than one place, and that he would take loading screens over nothing. He is right that covering the swap is the cheap correct answer: it costs nothing and buys a beat the world can talk during.
- **Make the gore read, and make the floor remember**
  Greg reported gore not working in play. The rig did carry it; three other things were wrong.
- **Stop the derby piling twelve cars onto the player**
  Measured before touching it: five wreckers inside nine metres by twenty seconds, with eight of twelve wedged motionless. Two thirds of the pit hunted the player permanently, with no cap and no ramp, and the remaining duellists chased the nearest vehicle — which in a scrum is the player again.
- **Make the map a map, and third person a fight**
  Greg's play test named two things twice: the map was still broken and the third person was not readable as combat. Both were true.
- **Add anatomy-driven hunter arsenal**
- **Repair hunter movement and camera**
- **Add live downed resolution and proximity voice**
- **Add a handover PDF for continuing the project elsewhere**
  A cold-start briefing for an agent picking this up outside this session: the architecture contracts, what already exists, the verification commands, the Tier 1d design and the known gaps stated plainly.
- **Add the downed state: defeated without being dead**
  The keystone for everything Greg described — execute, spare, recruit, mind-stamp, being shackled instead of killed. None of it can exist without a window in which the fight is over and the person is still there, because every one of those is a choice made inside that window.
- **Replace the capsule bodies with real anatomy: mesh, skeleton, physical limbs**
  The rig was pills and spheres. BodyMesh generates proportioned geometry from elliptical profiles instead — shoulders wider than the waist, a calf that swells and tapers to an ankle, a forearm narrower than a bicep. A capsule cannot express any of that, and the difference is most of what makes a body read as a body. Generated rather than authored because the zones and their seated and standing layouts are defined in code; a static GLB would need…
- **Give the player and the hunted real bodies, and make aim decide the wound**
  Encounter actors were bare capsules with an anatomy component bolted on and no hit geometry at all, which is why melee picked a zone with (event_count + index) % 6 — aiming at a head and aiming at a knee produced the same rotation of wounds. They run the baseline rig now, and a swing resolves against where the camera is actually looking. Verified both ways: looking up opens the head, looking down takes a leg.
- **Give bodies organs, so a torso hit stops being a torso hit**
  A zone tracks whether a limb still works; an organ decides how you die. Without that split, two chest wounds of equal damage are interchangeable, and the difference between a gut wound and a heart shot is something the fiction claims rather than something the simulation produces.
- **Record the rig, the derby deadlock and what is still outstanding**
  Notes the correction that matters for whoever reads this next: the zone vocabulary was not merely unshared, it disagreed, and AnatomyComponent resolved unknown names to torso in silence. Also records the two findings that came out of chasing Greg's menu report — that the derby had never worked as a fight, and that the menu colour setting had never done anything — plus the honest gaps: Hunt Grounds actors are not migrated to the rig yet, and AI wreckers…
- **Make the pit actually fight, fix the menu, move gore into settings**
  Chasing Greg's report that the menu was broken turned up a deadlock that meant the derby has never worked as a fight.
- **Put anatomy on derby drivers, add visceral damage, kill the boot boom**
  Derby drivers now run the baseline rig instead of a driver_health integer, so a blow resolves to the zone it actually landed on and the wound is written to the driver's subject. Rebuilding that driver restores it — a wrecker that left the last heat with a ruined leg comes back with it. That is "bodies remember" working on a procedurally spawned nobody rather than a hand-authored character, which was the whole point of the rig.
- **Add one baseline human rig with a single zone vocabulary**
  Every call site built its own body with its own zone names, and they disagreed: the derby tagged a driver hitbox "legs", the hunt recorded Mara's wounds as "left arm" and "leg", and AnatomyComponent only knows left_arm / left_leg / right_leg. Names it does not recognise resolve to "torso" in silence, so a severed leg was recorded as a chest wound and nothing downstream could tell. Derby drivers skipped anatomy entirely and carried a loose driver_health…
- **Record Tier 1a, capture guns and the baseline rig, add the CellOutz store**
  Marks Tier 1a complete with the correction that matters for anyone reading it later: the dominant cause of weightless rams was the uncapped lateral grip force, not the restitution setting this roadmap originally blamed.
- **Stop the derby needing a reset key**
  Greg's read on the play test: having to reset things constantly "feels super ingenuine, like not a game". He is right — a reset key is a test-harness affordance covering for a pit that stalls.
- **Give derby impacts weight: separation, lockout and real destruction**
  Rams read as weightless because the chassis cancelled them faster than the solver could express them. Three causes, all in arcade_vehicle.gd:
- **Rewrite the agent brief as a complete cold handover**
  Captures the two outstanding asks as priority tiers: impact feel (cars grind at near-zero speed instead of bouncing apart, and destruction is far too conservative for the closing speeds involved) and the inspection interface (one pointing verb for body and vehicle, where the hovered part lifts out of the flat schematic as a turning 3D object rather than opening a window).
- **Add the pit radio and route the menu into the opening**
  Every driver in the heat is on one open channel and none of them should be. Chatter is provoked by what actually happens -- who rammed whom, who just died, who is bleeding out -- so the radio reads as a running commentary on the fight rather than a loop playing underneath it. Calls arriving during cooldown are dropped rather than queued, so a pile-up cannot produce a backlog of stale barks. Barks are authored strings; the same call sites take voice…
- **Add the opening: waking in the vat on the Growing Floor**
  The game had systems and no way in. This is the first authored sequence.
- **Overhaul the derby HUD: damage bust, hull schematic, contact radar**
  Replaces the static title block with a live 3D bust of the driver in its own SubViewport, turning slowly and taking the damage the player takes: blood, forward slump, a shed arm with exposed bone at 45% and the second at 78%. A damage-state portrait reports condition at a glance where "CELLOUTZ // BONE YARD" reported nothing.
- **Rescale and regrime the Bone Yard to the biopunk direction**
  The toybox brief is superseded. ART-DIRECTION.md called for "a battered toybox version of a roadside combat game" in sun-bleached copper and teal salvage paint, which is precisely why the kit reads as toys: the assets were authored correctly to the wrong brief. Replaced with a biopunk apocalyptic direction — contamination rather than paint, nothing uniform or new, vehicles grown into rather than assembled.
- **Add the handheld device and the anatomical kill cam**
  Handheld: the Wire from DESIGN/IN_GAME_INTERNET.md, built as a salvaged CELLOUTZ Field Wire with Index, Map, Tree, Wire and Carry as modes on one object instead of four fullscreen panels on four keys. It does not pause the world. Screen damage is seeded once per device, so the same dead pixels and cracks appear every time it is raised. The Wire tab derives clout from ELO and grudge and gates access on it: high-clout accounts do not answer mentions or…
- **Positional derby audio and the front-end crush kill**
  Audio: every player was a non-positional AudioStreamPlayer, so the engine, impacts, crowd and wind played flat in the listener's head wherever they happened. Engine is now two AudioStreamPlayer3D layers parented to the chassis with doppler tracking, crossfaded by load so cruising and flooring it differ. Impacts play from a six-voice positional pool with panel, glass, heavy and meat variants. Crowd noise sits in the grandstands. Ambience stays…
- **Replace fort capture with signal territory and camp raiding**
  Greg's call, and a better solution than avoidance. Factions hold two kinds of territory contested in different ways: signal (feeds, masts, presses, the chaotic media amalgamation) taken by out-publishing, discrediting, hijacking, flooding or cutting; and ground (camps, towns, yards) raided Rust-style with a crew assembled from bonds, debts, defections and shared grudges the simulation already records.
- **Design the Wire: handheld device, internet and social layer**
  Consolidates three problems into one feature. The Index, Map, Tree and artwork are four unrelated fullscreen panels on four keys; the desolate internet from Codex section 13 is barely built; and the Hunt System needs a transmission channel for grudges plus a way to act on rivals at range.
- **Make the X-ray a scan tool with a draggable divider**
  The dossier split the body into two small side-by-side panes. It now renders one large body: the scan underneath, the flesh clipped over it, and a divider you drag to peel the body open. Polygon clipping runs through Geometry2D.intersect_polygons so both layers share one drawing path.
- **Make the anatomy dossier visceral rather than schematic**
  The Deep X-ray was flat vector silhouettes with blobs for organs. It now runs generated tiling textures: cellular noise for wet tissue, a scanline and speckle pass for scan interference, both tiled through polygon UVs with TEXTURE_REPEAT_ENABLED.
- **Tune the Bone Yard look against rendered captures**
  The first WorldLook pass was tuned blind and overcorrected: cutting light ~4x, switching to ACES and adding contrast at once rendered the pit almost black, because the authored kit runs 0.025-0.3 albedo and needs real light to read.
- **Sequence the backlog, plugin strategy and voice-chat pipeline**
  Captures the full set of outstanding direction in one place: gore and the ram payoff, driving feel, the wake-up-to-wasteland opening, first-person body UI, procedural interstitials, the nemesis rework and NPC proximity voice chat, ordered so each tier improves how the next one reads.
- **Fix weightless rams and unify the house look**
  Two root causes behind "the derby feels dead and looks souless":
- **Remove stray root-level bone_yard_hunt duplicate**
  game/bone_yard_hunt.gd is the version project.godot actually loads (res:// resolves under game/); the root copy sat outside the project tree, was 368 lines behind, and could not be loaded by the engine.
- **Initial commit: World Zero foundations baseline**
  Snapshot of the Bone Yard derby, anatomy/gore system, Ashbloom world generation, Living Kinship Web, World Index/Living Map, and CellOutz menu presentation as they stand per ROADMAP.md's "11 September behavioral audit". Vendored plugin binaries (FMOD, LimboAI, Terrain3D) are gitignored and reinstalled via setup/ scripts rather than tracked.
