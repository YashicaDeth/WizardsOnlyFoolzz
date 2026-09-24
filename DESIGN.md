# Living design notes

20 September implementation note: the opening's missing later procedure reveal
now comes from the body rather than a flashback or lore card. Filing the intake
sheet installs CellOutz's existing wetwire hardware in the player's real head
before the wake event; it names the Growing Floor intake as installer and keeps
its generated serial. The first X-ray in the Hunt now sweeps the player's own
rig as well as other bodies and catches that tower feeding back from inside the
skull, holding its serial and "installed while you were under" in the field
register long enough to read. The recollection is derived from the installed
part and records once, so a world without the procedure cannot receive the
exposition and repeated scans cannot manufacture repeated memories.

19 September implementation note: the underground derby now opens with the
gore festival the demo route previously named but never showed. During the
colosseum's existing pre-heat lockout, the player remains in the real cab and
watches an institutional press turn the previous human entrant into three
strapped, bone-visible meat slabs marked as lot 0C-7. The apparatus retracts
into the roof before the horn, so the spectacle neither becomes a cutscene nor
an arena obstacle. It is confined to the captured-player colosseum; the surface
derby does not inherit it. This supplies AP1.4's missing concrete beat and a
candidate for P4.4, but P4.4 remains open until playtesting shows it is actually
the moment a player retells.

Art-direction decisions are indexed in `ART-DIRECTION-MINDMAP.md`. It is the
boundary between confirmed visual rules, safe implementation work and choices
that still require Greg; the detailed material brief remains
`ART-DIRECTION.md`.

Player-experience decisions from the 18 September interview are preserved in
`DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`. It supersedes older prose
where that prose treats a map area as merely a “holding,” assumes land can only
be given to ascent or corruption, makes the derby mandatory, or presents the
J birthday/resonance screen as an established ordinary-play action. Stable
internal and save identifiers are not renamed by that vocabulary correction.

The implementation dependency graph, whole-game mechanics mind map and safe
parallel ownership boundaries live in `ARCHITECTURE/SYSTEM_MAP.md`. It replaces
the obsolete Derby-only map and should be the first routing document read
before dispatching parallel Orca workers; the checklist remains the detailed
ledger rather than a substitute architecture.

18 September implementation note: connected local territory work now has one
visible consequence before the still-unresolved political or supernatural land
decision. Resolving one order fractures the affected polygon on MAP; resolving
the complete local set adds a living decision-open border. The same canonical
place state raises broken claim stakes and a restrained field beacon in the
walked settlement. None of these marks changes the recorded owner. They expose
the power vacuum the player earned without silently choosing who inherits it.
MAP and the physical district both consume `local_work_state` from the same
place record, and `holding_work_integration_test` covers the complete transition.
Player-facing language should call these bounded world areas territories; the
older `holding` name remains only where changing stable code/save identifiers
would create migration risk.

18 September implementation note: the Black Mirror's convenience now has the
corporate threat promised by the map direction. Once CellOutz has issued its
repossession order, opening MAP publishes a persisted 96-metre acquisition
cell with a 72-metre uncertainty radius rather than the player's exact
coordinate. The Ashbloom sheet renders that as a broken red search ring with
the real player offset somewhere inside it. Remaining inside the same cell
cannot spam the ledger; crossing a cell boundary updates the bounty. That
boundary crossing now uses the same compact player-action receipt route as
smoking, inspection and local territory work, coalescing the bounty mutation
and publication into one persistence transaction. The first
published area commissions two named CellOutz bailiffs through the ordinary
encounter-body pipeline, so they have anatomy, loot, perception and persistent
outcomes rather than existing as map icons. A living contract blocks duplicate
spawns; a later ping can commission replacements only after the previous team
is dead, escaped, spared or recruited.

18 September implementation note: the surface territory now has a factual
first layer without pre-empting the player's later control/transfer decision.
The five settlements already generated in the Ashbloom each belong to one named,
persistent territory. Their borders are a Voronoi partition of the actual
settlement centres clipped to the actual 470-by-370-metre region, so the map
cannot invent a province whose town stands outside it. Exploration reveals a
whole territory once, records its existing holder and world timestamp, and then
continues fine street survey inside it. On MAP, unknown territories retain faint
complete silhouettes while a newly known territory develops outward from its
settlement over 1.4 seconds, gaining its holder colour and name as one weighted
event. This establishes land, ownership and discovery; it deliberately does
not decide whether local people, the player, a faction or nobody inherits it. The
first border crossing carries the territory row, canonical place, published
local work and reveal event through one player-action receipt and one outer
persistence transaction; observation inside already known land remains a read,
not another save.

18 September implementation note: a revealed surface territory is now one
first-class place everywhere, not a polygon trapped inside MAP. Its canonical
WorldHistory record carries the same holder, reveal time, field note and world
position into INDEX, where land receives a live polygon survey instead of a
fabricated human portrait. The same record can be pinned as a filed card on the
Board and strung into an existing theory; its card retains the current holder
and field evidence. This is the shared seam future local law, jobs and ownership
changes must use rather than creating parallel map-pin or quest-place state.

18 September implementation note: downed-person decisions in the Hunt now
enter the existing witness pipeline with the exact surface jurisdiction where
they occurred. Execute, spare and recruit no longer write around local law.
The world position resolves to one canonical territory and its current holder;
only a living nearby witness can carry the account, the account still takes
WitnessLedger's real delay to arrive, and only the ground-holder's own faction
can answer it. The faction judges the act from its existing Tree position, so
Ashline ground may punish mercy while Gate Lantern ground punishes execution.
One incident can be remembered only once per territory, even if two witnesses
report it. The resulting unrest lives on the same place record MAP, INDEX and
the Board already share. When that memory crosses its threshold, the holder
sends two generated, persistent people through the Hunt's ordinary encounter
 pipeline. They have full anatomy, loot and resolution choices and walk a real
route to the recorded scene of the acts—not to the player's magically current
coordinate. An unresolved team restores from WorldHistory when the scene is
rebuilt.

18 September implementation note: revealed surface territories now generate
local work without becoming quest icons. Each canonical place publishes one
claim-crew raid and one field-cache recovery as persistent job subjects in its
INDEX dossier; unknown land publishes nothing. The player explicitly takes an
order from that file. An accepted raid restores two stable named bodies through
the ordinary Hunt/anatomy/resolution path, while an accepted recovery restores
one identified loot cache at its saved coordinate. Only resolving those exact
people or physically collecting that cache advances the contract, and an
unfinished order survives rebuilding the scene. MAP reads those same active
records as a hollow raid diamond or bracketed recovery cache at the saved
coordinate, while the actual crew remain ordinary moving contacts; resolving
the order removes its objective without erasing the people or history. This
establishes a factual place → work → world → map → ledger route while leaving
the later decision about who receives reclaimed land deliberately open.
The canonical place also counts the connected outcomes: one completion makes
its local claim `disrupted`; both make it `ready_for_decision` and write that
threshold once. INDEX, MAP and the place's pinned Board card expose the same
state. Crucially, this does not change `held_by`: clearing two objectives earns
the later land act, but cannot silently choose a faction, local government or a
recipient for the player. Accepting and resolving that local work now travels
through the same compact player-action ledger as smoking, coughing and held-item
inspection. Existing territory event names remain available to current readers,
while one action id and one outer persistence transaction bind the job mutation,
the receipt and the resulting place-state change together.
District, objective and moving-contact labels now negotiate one shared set of
chart-space registers as they draw. They try positions around their actual mark,
fall back to the least-overlapping position when the area is genuinely dense,
and stay inside the physical bezel. This changes presentation only: contacts
retain their true coordinates and the satellite image remains the authority.
The whole-territory reveal is the pleasurable exploration payoff rather than an
administrative unlock. Its polygon develops outward from the settlement under
a pale cleaning lip that is strongest halfway across the glass, with short
streaks travelling behind the front and disappearing completely when the live
holder-coloured border settles. The movement is monotonic and does not wait for
the player to open a menu.

18 September implementation note: territory evidence now reaches the physical
Board through the actual input route. `P` on a revealed place in full-size
INDEX files it as land rather than a human photograph; `P` on PYRAMID can file
its holder faction; and the same action inside the Black Mirror's hosted INDEX
bubbles outward to the room's one Board instead of vanishing inside the device.
The player can string place → holder → person, with support read from the
place's `held_by` relation and the faction's existing person edge. No automatic
theory is authored and no string is drawn for the player.

17 September Black Mirror note: its seven apps are different instruments inside
one object, not seven unrelated UI compositions. The casing now owns a fixed
page grammar — header and footer rails, app identity and role, stable page
number, navigation hint, primary physical verb and a common inset work surface.
INDEX, MAP and WIRE keep their authored hosted content while RADIO, CARRY,
RITUAL and FIELD retain their native instruments inside those same bounds.
Moving between them is physical movement: a ribbed shutter travels across the
glass in the shortest direction, the old live page remains until full cover,
and only then does the next page activate beneath it and get revealed. No app
change may expose a hard visibility cut.

17 September implementation note: the opening now uses the authored underground colosseum rather than accidentally entering and resuming in the surface quarry. Its first territorial loop is live: four persistent facility holdings progress from controlled to surveyed to liberated through real opening/derby milestones; winning the underground heat liberates the Colosseum, unlocks its recovered INDEX file and causes CellOutz to circulate one persistent repossession order. The Black Mirror defaults to the facility MAP after this route exists, supports pointer and arrow selection plus `L` to the Ashbloom satellite, and restores the entire territory/file/bounty state through a quantum branch while a genuinely new world returns the facility to corporate control. Full contract and evidence are in `DESIGN/FACILITY_TERRITORY_SLICE.md`.

17 September implementation note: the Lockdown Grid is now the physical second
half of that underground heat. (“Service Ring” remains only as its stable save
id.) Each of the three existing tunnel chambers owns
a scanning CellOutz relay that can be shot with the cab's travelling rounds or
rammed with the vehicle. Eight wreckers no longer counterfeit territorial
liberation: the empty bowl remains driveable until all three relays are dark.
The cab's own instrument cluster shows relay state and acquisition pressure;
the final relay persists, unlocks the Lockdown Grid's recovered INDEX file and
escalates the existing repossession order rather than inventing a parallel
mission.

17 September implementation note: concrete presentation actions no longer
write around one another. `player_action_ledger.gd` is the receipt seam for a
smoking hit, resolved draw, cough, exhale, trick, lip transfer, fully consumed
object and held-item inspection. It preserves the existing event vocabulary so
factions and INDEX consumers do not migrate, adds a monotonic action id and
cheap per-kind counts, and batches its compact summary with the event into one
persistence flush. A complete draw remains one nested outer transaction across
dose, lungs, consumed geometry and all receipts.

18 September implementation note: that route now covers the remaining
deliberate movement and handling verbs too. A jump is receipted only when the
body actually leaves the floor; a dodge, wall-run kickoff and supported grip
change receive one receipt each; refused inputs receive none. The corresponding
autonomous consequences remain world events rather than counterfeit player
actions. A production-wide multi-write audit also closed the derived outcome
boundaries around landed combat response, law-team arrival, returning rivals,
holding-raid maintenance and CellOutz contractor dispatch. Subject mutation,
public fact and any spawned persistent people now commit together without
changing the established event vocabulary.

17 September verification note: the complete use-and-inspect reel exposed a
production perception defect rather than a capture-only problem. Reduced
consciousness added displacement onto the previous frame every update, turning
several ordinary smoking acts into an unreadable liquid screen. The Hunt now
derives that fullscreen dial afresh from live consciousness, keeping a harsh
pull visible but bounded. `captures/full_use_inspection_demo.mp4` records all
five smokeables, three weapons and a carried limb being used and distinctly
inspected in the real first-person scene with live audio.

17 September implementation note: changing view in the derby is physical camera travel through the car, not a teleport followed by a visibility swap. A heat begins in its cab; once chase view has been earned, the eye eases between the live seat and chase targets over 0.68 seconds while both interior and exterior shells remain present. Only arrival changes the view mask, preventing either half of the vehicle from vanishing around the moving camera. Sleep is likewise an action on a world object rather than a menu command: the Hunt's reachable bedroll advances the persistent clock to 07:00 and records the hours actually passed, while nearby living hostiles make rest impossible. Interface failure is anatomically local rather than a uniform hurt filter: head wounds disturb the portrait, torso wounds the anatomy/X-ray, arm wounds the held-object reliquary and leg wounds the navigation aperture, all derived from the live zone health so treatment repairs the same instrument. Project-owned editor diagnostics now have a zero-warning/error budget enforced by a repeatable headless-editor check; addon and engine-shutdown noise remain outside that ownership boundary.

18 September playtest note: passive stamina recovery is rest, not a subsidy paid during every action. Sprinting drains it; guarding, grappling, strike windup and dodging suspend recovery while their own authored costs run; only a genuinely free movement state restores it. A refused low-stamina blow must say why. Third-person collision follows the same physical rule as traversal: the readable mass of a wreck blocks both player and camera, and when no useful shoulder distance remains the continuous camera blend yields into the eye rather than filling the lens with the hunter or scenery. Open space restores the full locked shoulder composition automatically. Sword grips must also be visible facts: two-hand, one-hand and half-sword poses on the production mount have to change with the reach/control/damage numbers, including after inspection resets.

19 September performance direction: ordinary play is held to **60 FPS on
Greg's current RTX 2060 SUPER machine**. Thirty FPS is only the temporary floor
at which combat and gore can still be playtested; it is not the intended frame
budget. Higher rates, including 120 FPS where available, are welcome headroom
rather than permission to weaken simulation or presentation before measuring
their cost.

The opening's vehicle is likewise a continuous place, not permission to skip a segment. Arrival must render from the physical cab seat on the first frame. Cab/chase changes travel through the same live shell. In the starting facility the door remains under CellOutz control until the compound escape contract is actually cleared; trying it early produces an immediate in-world refusal without recording a departure. Once released, the eye travels seat to sill to standing, exterior bodywork is not revealed until the camera clears it, and driving-only instruments fade as the seat is left before the Ringmaster beat begins.

16 September implementation note: the Black Mirror's world light and the body carrying it are separate stealth observations. At night a hunter can follow the bright source before resolving its holder; cover, an empty battery, or physically pocketing the device removes that trail. Hostile pursuit reads this verdict directly, rather than leaving `player_unseen` as presentation-only state. The satellite map is deliberately the loudest page: twice the baseline battery draw and 1.3 times the emitted-light output, shown on the chassis as `SAT DRAW x2.0`, so opening it at night trades a wider readable pool for a longer detection signature. While a hosted page is braced with `L`, WASD carries the held object and its real beam around the same screen edge; this is a physical wrist/lighting action that recentres on release, not a free camera peek. The device's saved condition now answers live handling: incoming blows only damage it while raised, locate their cracks from the attacker's screen direction, and a deliberate drop adds its own lower-edge impact before the same serial leaves possession. A dropped device becomes a colliding world object carrying that serial, charge and wear; its world position survives reload and proximity interaction repossesses the same object.

15 September implementation note: the requested demo is now a runtime route in the same build, entered from a dedicated DEMO door beside PLAY. It uses the production opening scenes and an isolated demo history file. Its first authored ending is the CellOutz final invoice shown only after the real Hunt's first win; it records the ending and names the real-game roads withheld beyond it. This implements the explicit direction already recorded in section P, not a new creative-direction decision. Full route curation remains in progress.

11 September implementation note: user requests a redo of the production opening prompt. Prior feature lists are prototype descriptions, not proof of production completion. The player-controlled first/third-person camera choice supersedes the older forced-camera text below. Current artwork key is J; A remains movement. Detailed organs, authored rigs, navigation, production assets and completed encounter branches remain pending.

Status: early concept, not a locked game bible. Compiled from Greg's shared conversation and this task. Do not silently promote an assistant's suggestions into requirements.

## Explicit direction

- `World Zero` is the development milestone name, not necessarily an in-world place. The first implemented Limbo region is now called **The Ashbloom Expanse**: a far-future post-nuclear wasteland where irradiated fungal ecology and rot have overgrown decayed cyberpunk infrastructure. It contains raiders, violent drifters, stalkers, gangs, cults and competing factions. This is an original setting; reference works indicate desired scale, unease and ecological strangeness rather than content to reproduce.
- The character interface should become a massive zoomable web containing individuals, faces, factions, family/social links, rank, hidden ELO-like power, grudges, bonds and persistent memories.
- Selecting an important person should open a simultaneous two-slice dossier: an exterior body/portrait and a deeper X-ray/anatomy view showing organs, lasting damage, replacements and cybernetic parts.
- Rival state changes must survive encounters and feed story returns: injury, escaped/dead/active status, prosthetic changes, faction command, rank and remembered player actions.

- One character, two worlds. The user explicitly clarified that this does not mean two-player co-op or switching between two player characters.
- One realm forces first-person play; its working metaphor is hell. Another forces third-person play; its working metaphor is heaven or a corrupted counterpart. Exact cosmology and names remain open.
- Hubs, main-world roaming, transitions and eventual overlap between perspectives are desired. How these work remains open.
- A dense, surprising, psychedelic, uncanny, occult and sometimes funny world. The experience should not feel crushing.
- The player is forced by the elites to wear a humiliating jester/gimp outfit. Its first implemented read is oversized black-wine gloves, poofy bone-and-blood cuffs, restraint hardware, bells, shoulder puffs and a locked ruff; the costume must remain visible in first-person hand interactions as well as on the body.
- The field HUD's corners have different bodily and world-facing jobs rather than repeating generic panels. The top-right carries an original mood reliquary with narrow vertical fluid reservoirs hanging beneath it for blood/health and dirty-water stamina; magick has no vessel at all until the player actually unlocks it. The lower-right is ultimately the scuffed Black Mirror phone physically poking from the jester costume's pocket, not a floating app panel. The lower-left belongs consistently to its live satellite/radar feed so spatial information never moves. Contextual anatomy appears beneath the top-left world/threat instrument when an organ is under pressure, beginning with lungs that visibly take smoke, trigger coughing on a harsh draw, retain dark staining between sessions and clear only when those lungs are replaced. Holding the pulmonary input draws that quick diagnostic forward into a paired, rotatable 3D model of the same live organs; it is direct inspection of the saved anatomy rather than a second health screen. Held weapons and ammunition should stay readable through the physical hands/gear rather than competing with the phone as another corner app.
- Ordinary first-person play is viewed through restrained ceremonial glass: a slight permanent fisheye bow darkens the extreme edges, while mirrored visceral-regal corner cartouches and thin bone rails form an elegant screen border. The interface itself remains sharp and unwarped, and the former centred location banner stays absent so the frame can breathe.
- The lower-right held-item readout is a slowly moving 3D reliquary fed by the real object in the player's hands, not a flat weapon-specific silhouette; guns, smokeables, tools and severed limbs all use the same presentation. Every object is centred and fit against its complete turning radius. Its seamless 22-second screensaver motion describes a full orbit without reading as a one-way shop turntable: brief yaw reversals, restrained pitch and roll, and breathing scale use 3/5/8 Fibonacci harmonics offset by the golden angle. The lower-left compact map is the same live satellite camera as the opened Black Mirror map, centred on the player and updated sparingly.
- Do not leave technical body-inspection fixtures unexplained in the playable route. The red witness mirror formerly standing in the Hunt's opening view is removed; a body mirror belongs in an authored room or explicit inspection interaction where its purpose is legible.
- Smoking is expressed through the persistent anatomy system, not a disposable effect icon: cigarettes, joints and spliffs are held in an open, splayed-finger grip and raised to the mouth, while inhaled smoke temporarily fills the lung X-ray and repeated use slowly stains and harms the actual saved lung organs. Exhaled smoke reads as layered drifting wisps rather than luminous beads; the hand and ember carry quiet breathing, ash accumulates on the consumed object, and occasional deterministic flicks shed it physically. The quick lung view eases fill, cough, tissue darkening and replacement recovery over a shallow volumetric organ drawing while retaining exact live anatomy values underneath.
- One-hand smokeables can remain held at an implied lip point without drawing a literal first-person mouth: the hand visibly transfers and releases the object onto its authored mouth anchor, the item settles with the player's breathing, the player can puff it hands-free, and the same gesture takes it back. The two-hand bong is deliberately excluded. Ember, bowl, lighter and inspection light must adapt their cast energy to daylight and severe overcast rather than producing night-strength glare and shadows in every exposure.
- The universal inspect action must reveal how an object is handled, not spin every prop through the same canned flourish. Paper, vape, bong, sword, long gun, sidearm and improvised body part each receive their own hand choreography; every visible wrist continues through a costumed forearm to an authored lower-frame entry, and even a carried severed limb is visibly gripped rather than floating from the arm rig.
- World time should breathe rather than race: the implemented day/night cycle is one full in-world day per real hour, with deliberate sleep and travel still able to pass time directly.
- The Ashbloom Expanse does not use the modern Roman calendar. Its civil calendar has three seasons (Ashfall, Emergence and Reaping), twelve original thirty-day months divided into ten-day decans, then five ominous Uncounted Days outside every month: the Fool, Wound, Mirror, Wire and Flame. This is an original setting system structurally informed by ancient Egyptian civil timekeeping, not a direct import of its religious names.
- High-quality code and deliberate art direction; generative imagery is not the foundation. Greg's own artwork should be central.
- Greg's own artwork is the visual foundation, not a decorative layer added
  after systems are complete. `ART-DIRECTION-MINDMAP.md` owns the intake and
  replacement map and distinguishes verified Greg sources, provisional work,
  references and open decisions.
- Soulslike combat and bosses, with eventual power, aggressive mobility and physical brutality. The player should not remain weak forever.
- Highly physical, exaggerated fictional violence with meaningful hitting and body systems. Different bosses may have different anatomy and rules.
- Persistent rivalries, bounties, ranks/hidden Elo-like ratings, distinct loot pools and an optional boss ladder.
- Friends form the reflected side of the rival system, inspired by the user's "as above, so below" principle.
- Important characters have jobs, ranks, relationships and meaningful positions in the world.
- A beautiful compendium/field-guide interface, unlockable character relationships/tree, and a developing map.
- Original fictional peoples/species, mutations, body parts, organs, bones, fingers, hands and feet; detailed modification and replacement/prosthetic compatibility.
- An NPC-driven cyclical and somewhat unpredictable economy. Chaos-magick ideas influence fictional world rules, karma and ritual mechanics; exact rules are not settled.
- Followers, friends, captives/slaves and religious or faction devotees are possible fictional social roles. Scope and mechanics need design.
- Base building, home decoration and relationships/story development inspired by the user's references. Survival-system depth is deliberately undecided.
- An in-game internet connected with CellOutz and the user's artistic universe.
- The Black Mirror's satellite map is an exceptionally invasive CellOutz security system. It can publish a target's approximate area, attach bounties and jobs to places, and let contractors work for or against the many issuers using that platform; looking through the map also means CellOutz can look back.
- The Black Mirror should initially favour MAP because the captured player
  begins inside surveilled territory. Freeing a place gradually exposes the
  reliable INDEX knowledge attached to it; MAP is therefore the pressure and
  INDEX is earned understanding, not two unrelated apps.
- CellOutz operates an openly occult, satirically evil corporate bounty
  platform. Its seal and liturgy remain open, but its malice is not hidden
  behind a neutral public-service presentation.
- The world map is divided into named, visibly bounded territories containing settlements, districts, outposts, camps and facilities. Exploration reveals them and later play can disrupt, recover, secure, reoccupy or desolate them by confronting fictional bandit camps, trafficker and organ-market networks, cartels, alien installations and other local power structures. Changed territories visibly evolve and produce new consequences, work and faction reactions rather than becoming one-time checklist icons.
- The first territorial art and implementation focus is the underground
  facility where the player is held, the route used to escape it, and the derby
  that follows. Do not design the whole overworld before this connected opening
  territory reads coherently.
- First-person combat begins heavy, physical, challenging and brawl-like,
  including deliberate firearm aiming. Earned third-person combat becomes more
  expressive and combo-oriented with readable movement between threats. Exact
  unlock conditions, combo vocabulary and the point where switching becomes
  available remain design work rather than settled lore.
- Allusions Too Grandeur is an extremely detailed unlockable book of images and lore, potentially accessible from the menu. Changing images, metadata, characters in art, hints and hidden lore were discussed.
- A violent demolition-derby activity with original world, vehicle, targets and presentation; it may take broad genre-level inspiration from arcade demolition derbies, but must not copy a specific game's protected content. BeamNG-level damage remains a research ambition needing a separate feasibility prototype.
- Persistent multiplayer/server ambitions were mentioned as a far-future possibility. Rust-like human proximity chat is a future multiplayer consideration, not part of the clarified current player model.

### Answered by Greg, 19 September 2026

Spoken answers to the questions that had been blocking work. Recorded here
because several had been asked across more than one session and the answer
kept being lost. Where Greg said he did not know, that is written down as not
knowing rather than filled in.

Two answers from the same conversation are **not repeated here** because they
already have homes: the 60 FPS budget is in the 19 September performance
direction above and in X1.2, and the vat opening is in
`DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`. Adding second copies of
either is how this repository became hard to read.

- **It is not a roguelike, and the question should stop being asked.** It is a
  save game — your game. There is a main story with an end goal, and a
  post-game after you beat it, and you can keep playing for as long as you
  want. Nothing about "what carries between runs" applies; there are no runs.
  This supersedes the roguelike-versus-persistence tension recorded in the
  checklist's open questions.

- **Greg's art lives at `C:\Users\Greg\Desktop\Art Collections`.** Real and
  populated — Affinity, Photoshop and After Effects sources alongside
  exports. A second, smaller set sits under the Desktop's Personal Media
  Folder in the edit-experiments and Allusions directories, including a
  post-major-work set he wants used. His Instagram account is also a usable
  source; **the exact handle still needs confirming** — he tried several
  spellings aloud and none should be guessed at.

- **What he actually wants from the art work is a commissioning tool.** An
  art and asset ledger, with modelling and texture entries, presented like
  the existing mind map: you click an entry and it tells you what the thing
  is, what it looks like *now*, and what he wants instead. The purpose is
  that he can hand it to friends and commission textures and assets from it.
  Explicitly **not needed right now** — recorded so it is not lost.

- **Liberating a holding.** A town is under occupation: bandits, a faction,
  demons, spirits. The player learns about it through a quest or through
  information found in the world, and the map shows where the occupiers'
  facilities are. Three routes out of it, and the choice is the content:
  - go there, talk to the occupying force, and help them hold the place —
    that is **giving in to corruption**, not liberation;
  - demand they let the people go, be refused, and take it by force;
  - tell the townspeople or their elder that an attack is coming, and have
    them fight alongside you.

- **Dialogue.** Proximity voice is the primary channel — the town can be
  talked to and argued with, and the third route above is meant to be won by
  actually persuading them. Pre-written Fallout-style options sit *underneath*
  as an alternative for players who want them. Greg is explicit about what to
  avoid: the Skyrim/Fallout pattern where you press through canned lines and
  it never feels like the question is yours.

- **Guns are unevenly available rather than simply common or absent.** Basic
  industrial firearms exist, but reliable high-quality weapons, condition,
  ammunition, attachments and catastrophic specialist rounds are valuable
  and scarce. The world is scrap and bionics. Crafting is how weapons get
  upgraded, not shops full of stock.

- **Most fighting is not gunfighting.** Cybernetic upgrades make bodies fast
  and strong, so combat is physical: leaping around each other, super
  strength, a bat that sends you flying in third person. The energy he is
  after is the Annoying Villager fight choreography, turned into something
  playable.

- **Combat stances, with a tree.** Stance changes playstyle — sneaky through
  to melee — and is meant to make the same weapon feel like a different game
  in different hands. Reference is **Nioh** (1/2/3) for multiple stances in a
  souls-like.

- **Carry becomes one inventory.** A character model on the right, inspectable
  in 3D, that clothes and armour go onto. Clicking its brain opens the brain
  index *inside* the inventory rather than as a separate screen. A weapons tab
  reaches guns, attachments and further customisation. A combat tab at the top
  reaches the stances. One screen, several tabs — not several screens.

- **celloutz.xyz: fictionalise it**, somewhat rather than wholesale. The
  in-world internet interface is still unbuilt and will be lore-heavy.

- **The "is the spawn too dark" question is retired, not answered.** Greg's
  reply was that the player does not simply spawn in at all — the opening is
  the vat and the examination, written up in
  `DESIGN/PLAYER_DIRECTION_INTERVIEW_2026-09-18.md`. The facility is lit
  enough to read: surveilled, locked down, esoteric, Outlast-horrific. So
  lighting effort belongs to building that, **not** to raising exposure on
  the current spawn, and `G7.1` should be closed as superseded rather than
  left waiting for a taste call on a scene that is being replaced.

- **World scale**: not enormous. Fallout 4 sized at the very most.

- **A7.4, does the chassis roll**: still open. Greg's answer was "I don't
  know", so it stays unanswered rather than being decided for him.

### Stated by Greg, 24 September 2026: how fighting, growth and trust connect

Said in one message during the Dust to Bones remaster. His words are
paraphrased closely; the last list is the assistant's reading, not his.

- **Many fighting styles, switched live.** Martial-art stances, swordfighting
  stances, and gun and weapon classes, each distinct and fluid, with
  "insane" graphics on top. Switching stance mid-fight is part of it.
- **Styles open skill trees, fed by use.** Each style or weapon earns its own
  experience, called **blood**, from killing with it or using it well.
  Weapons evolve through fighting experience, not shops.
- **How you fight decides what survives.** Going bloodthirsty blows bodies
  apart: organs and cybernetics (loot, not weapons) are destroyed with them,
  and so are the connections that person could have become on the
  relationship tree. Better-evolved weapons kill more cleanly for less
  damage, so skill starts to pay back in loot.
- **Stealth has its own reward.** In a mission, stealth can bring great loot
  benefit, against many enemies.
- **Playing safe can pay too:** working instead of fighting, befriending, and
  building a diplomatic relationship through proximity chat, missions,
  interaction and pre-written dialogue choices.
- **Trust can be spent.** Trust earned by diplomacy makes infiltration and
  betrayal possible, such as suddenly turning on people who trusted you.
  His example: working for a military camp that has been oppressing the
  locals, as in Fallout 4's story, then turning on it. They notice, or a
  cutscene before the fight plays.
- **Many small authored interactions.** Brief but featured moments like
  ambushes and betrayals, in the manner of Shadow of Mordor.
- **Boss rooms that know what you did.** Walking into a Dark Souls-style boss
  room; because you know or have tripped certain triggers, a character boss
  fight or custom cutscene written into that map area plays.
- **The kinship tree needs reworking** and moving somewhere better than its
  current key (T opens the Living Kinship Web), unless the key itself is
  reworked.
- **Hornee the zombie mutant.** Greg's handmade plush: stitched corduroy
  body, a bottle-cap eye and a metal-cap eye, pins, a black rose, a camo
  wrap and a charm on one ear. His edited artwork of it is titled "Zombie
  Minion". Sources: `C:\Users\Greg\Downloads\20260327_2103{04,09,16}.jpg`
  (front, front, back), the edited still and the animated edit (36 s,
  colour cycling between green and orange with a slow warp).
  - A **trading card** in the Brain Index, zoomable, using the artwork's
    textures, text, colour and type, with TouchDesigner-style effects.
  - Also a **spinnable 3D recreation** of the plush from his photos,
    switchable from the card ("the live thing"), with slight effects on the
    model so the two read as one. He will send more photos if needed.
  - **A minion that fights:** a small companion mutant or pet. The
    inventory needs a slot for it, where you customise and look at your pet.

Answers to follow-up questions, same day:

- **Stealth is its own fighting style** with its own blood and its own tree.
- **The Kinship web becomes a tab in the Tab hub**; T is freed.
- **Job posters are pasted on walls** in the Hunt, with tear-off tabs you
  take as a job. **Business cards are handed over by people you meet**,
  kept in Carry, and add a contact on the Wire.

- **The pyramid becomes 33 tiers** and is rebuilt as a 3D structure in the
  World Index that you spin, zoom and fly into, heavily inspired by the
  Shadow of Mordor / Shadow of War Nemesis army screen: "a subtle pyramid of
  different ranks". The reference is for layout feel only; the art is original.
  - **33 tiers in total:** 16 up, the waist (you), 16 down, keeping the
    existing double pyramid (Ascent above, Corruption below).
  - **Horseshoe power:** the tip at the top holds the most power, and so does
    the tip at the bottom, "being the most scum or worst of whatever". The wide
    middle is the crowd.
  - **Filled with everyone the world simulates, plus generated crowds** so it
    feels massive, the crowds densest in the middle tiers.
- **The World Index UI** is too small and cramped, overlaps and clips, is hard
  to navigate and looks dated. All four, to be fixed in the remaster.

- **The first 30 minutes** (Greg, in a chat with a friend he shared the same
  evening): "30 minutes of gameplay that leads with a strong story and
  gameplay bond", made of:
  - character creation, cutscenes and story;
  - a gameplay intro that teaches the basics while you escape the facility;
  - **multiple routes out** of the facility, still to be fully made;
  - **the derby is soft-scrapped and shelved as a different exit route**:
    a lower level of tunnels and drain networks, "super old", that brings
    you out in a different part of the map, so the overworld begins
    differently depending on how you left.

### Answered by Greg in question boxes, 24 September 2026 (night)

Asked in the Code tab because the Dust to Bones page's saved answers sit in
another account's organisation and could not be read from this one.

- **Death: you are reborn in a vat.** Whoever owns your body grows you back;
  the world does **not** rewind, so dying has consequences in it. This
  answers the page's `story-death` and replaces the opening's ordinary
  reload once it is built.
  - **And the character preset is kept**, so a death never costs a trip back
    through character creation: "don't forget the save character preset so
    you can reload it if you die without wasting time". `CharacterPresets`
    already has `save()`, `names()` and `apply()`, and the intake's PRESET
    route already reads them — but nothing in the game ever *saves* one, so
    the route answers "NO PRESET ON FILE" for everyone. The work is wiring,
    not building.
- **Routes out, for the demo: just the two that are built** — the heat
  elevator, and the drain tunnels the derby became. More routes later.
  Answers `rm-routes` for now.
- **The loose opening pieces: the biometric door and the guard's gun
  first** (AX route beat 5, AX3.3–AX3.4). `BiometricBarrier` and
  `FacilityGuardLoadout` are written and tested and have no production
  caller. The honest opening death and the mosaic option wait.
  - *Built 24 September (assistant placement, not yet Greg's call):* Hollis
    stands at a biometric D-section door across the Service Arcade, between
    the staff card and the pressure gate. With the ram at his chest he palms
    the reader himself and drops the gun; rammed down (three swings), his
    hand is dragged to the reader. Either way his gun goes into Carry with
    three rounds. His shots bleed the player to 25% and no further until the
    vat rebirth exists. Removing his hand waits on a blade. Open: where the
    door should really sit, and whether the ram should be able to force it.
- **Merge once verified.** Each look lane merges into this branch one at a
  time with the core suite re-run after every step, then this branch goes
  into `codex/primary`. Answers `rebuild-merge`.
- **Sequence.** When the first 30 minutes work end to end, both routes
  included and out into the overworld, the next thing is **the next 30
  minutes**: "furthering the tutorial and starting stage of the gameplay".
  Nothing in minutes 30–60 is started before minutes 0–30 are right.

### Answered by Greg in question boxes, 24 September 2026 (cloud session)

- **Hollis's door wants tissue.** The breach ram cannot force the D-section
  biometric door; only his hand, his body, removed anatomy or (later) an
  implant spoof opens it.
- **Hollis escalates.** Asked whether his gun should warn, wound or kill,
  Greg picked all three; read here as an escalation: warning shots first,
  wounds if you keep coming, and lethal once dying exists (then vat rebirth,
  and he remembers you). The current build does wounds only, floored at 25%.
- **Rebirth: you wake in the vat of whoever claims you.** Whichever faction
  holds your debt or your body at the time grows you back (CellOutz, a
  rival, a cult), so where you wake depends on who owns you.
- **Nothing carried survives death.** Gear, the gun and clothes stay where
  you died, to be looted or recovered; the body resets. The character
  preset, memories and the world's record of you carry over.
- **Hollis's look:** placeholder now; fix clothing so garments actually
  render on every rig (today they show only as a thin outline); a real
  CellOutz security model later, one Greg provides or picks.
- **Build order asked for: all of it.** Death as vat rebirth with the preset
  saved; the opening's wires beat (END ALL SUFFERING, tear the umbilicals
  out, GET REVENGE) ported onto the reworked vat; the lab's lighting and
  floor light glitch; the VFX pack.
- *Built 24 September (the wires beat):* the drain no longer breaks the glass.
  The body hangs in the four umbilicals under END ALL SUFFERING while the
  tank's clock stops; the player looks at a wire and presses E, and the third
  tug tears it out (pain, blood, its own sound). GET REVENGE follows the last
  wire, and then the glass goes. A regrown body goes through it too.
  Assistant choices, open to Greg: three tugs per wire, and that neither title
  has a speaker (CellOutz's slogan or the player's own impulse is undecided).
- **Workflow:** merge each verified piece into `claude/dust-to-bones-look`,
  and send a split-zip Windows build after each piece.

### Answered by Greg in question boxes, 24 September 2026 (routes out)

- **The heat elevator goes up to the overworld.** With the derby shelved
  as an exit, the Lower Works lift carries the player up and out into the
  Ashbloom Expanse near the facility, not into the colosseum heat.
- **The drain tunnels are a new walkable route:** an old ("super old")
  drain network reached from Lower Works that surfaces in a different part
  of the map, so the overworld starts differently depending on how you
  left. These are the demo's two routes out.
- **The floor light glitch was the pale pixel disc under the broken tank**
  (the breakout puddle). Fixed: a dark, wet puddle.
- **Job posters and business cards wait** until minutes 0-30 work end to
  end; they live in the Hunt.
- *Built 24 September (assistant choices, open to Greg):* the heat
  elevator surfaces at the old vehicle-sallyport point the derby used; the
  drain hatch sits on the Lower Works floor east of the lift; the drains are
  laid out as the three districts `FacilityRoutes` already named for the
  maintenance ascent (waste gallery, maintenance cistern, storm outfall) and
  surface where that route always said (west of the start), carrying its
  relationship changes (Gate Lanterns up, CellOutz down). Nothing threatens
  the player in the drains yet.

### Answered by Greg in question boxes, 24 September 2026 (what next)

- **Next, all four, then minutes 30-60:** a better examiner model and the
  readable name line on the intake; animated, skeuomorphic intake pages;
  the combat overhaul; and threats in the old drains so the second route
  costs something. Once these are done, minutes 0-30 count as right enough
  to start minutes 30-60 (furthering the tutorial and the starting stage).

### Answered by Greg in question boxes, 24 September 2026 (the examiner)

- **The examiner has an ordinary human face**, not the player's grown-wrong
  tank face: matched eyes, no exposed teeth.
- **His coat is stained and bloodied** from the procedures, not clean white.
- **The name line becomes a proper header** over the vat panel, bigger and
  more prominent than a caption.
- **Better lip sync now:** jaw and lips move with the vowels and consonants
  of what he is saying, on the new face.

### Answered by Greg in question boxes, 24 September 2026 (intake GUI)

- The SUBJECT / TANK name header is its own band above the vat picture.
- The examiner reads well now (ordinary face, stained coat, lip sync): keep.
- Next on the intake GUI: animated tabs, the answer box and transcript, and
  the stats strip. Keep the current red/copper palette and CellOutz type.

### Answered by Greg in question boxes, 24 September 2026 (intake GUI detail)

- **Tabs print in:** switching to an intake tab feeds the page out line by
  line like a thermal receipt printer, ink still wet.
- **Answer box:** his line bigger and typed out at reading pace with a
  cursor; answers drawn as blink choices (eye icons), not plain buttons;
  earlier lines kept above as a faded scrolling transcript.
- **Stats strip:** each stat a small gauge that fills, animating when a
  choice changes it, with the change flashing (+0.4).
- A new Windows build after these three.

### Answered by Greg in question boxes, 24 September 2026 (in-game HUD)

- Next GUI pass: the in-game HUD (vat, arcade, Lower Works, drains).
- It becomes a **body-cam OSD**: REC dot, timestamp, vitals as a thin
  readout, the objective as a stamped line; matching the Outlast lab look.
- Prompts become a **drawn [E] key cap with the verb, placed near the thing**
  in the world, not a line of text at the bottom.
- The intake is good for now.

Open: one of Hornee's eyes is a real drink brand's bottle cap with its
wordmark. Keep it on the shipped model, or swap it for an in-world mark?

Assistant reading, not confirmed: this is one loop. Blood XP rewards
fighting; precise, evolved weapons protect the loot and the people a
fight would otherwise destroy; kinship and trust are the other currency,
earned by not fighting and spent by betrayal. The ambiguities worth asking
about are whether diplomacy has a tree of its own, and whether "many
enemies" means stealth missions field more of them.

## Influence register

These entries describe what Greg said he values; proposed extraction is labelled. Liking a reference does not automatically import every mechanic from it.

| Reference | Stated interest / scope |
| --- | --- |
| Dark Souls 3 | Primary combat reference: fighting and bosses. |
| Dark Souls 2 | Worldbuilding and atmosphere. |
| Prison of Husks | Its rough/"bootleg" Soulslike combat style, visual style and world. |
| Everhood 1 and 2 | Psychedelia; Undertale-like influence expressed in a new style. |
| Undertale | Related tonal reference; exact systems not specified. |
| Fran Bow | Occult, weird, surreal qualities. |
| Kenshi | Worldbuilding, races, bodies/body parts; independent-world and group-system implications need further specification. |
| Hades | Character development. |
| Sally Face | Art design. |
| Rust | Stimulating social unpredictability, proximity chat and funny shared play. |
| Terraria | Loves the whole game; specific priority systems still need unpacking. |
| Valheim | Broad enthusiasm, especially building, relationships/story emerging around a home. Avoid assuming all survival systems are wanted. |
| Stardew Valley | Decoration and relationship/home-life possibilities. |
| Prototype 1 | Third-person gore and power, to blend with Soulslike fighting. |
| Postal 2 | Gruesomeness; earlier conversation also names sandbox freedom as an assistant interpretation. |
| Paint the Town Red | Gore and physical combat destruction. |
| SpongeBob's Boating Bash (Wii) | Derby style and feel. Greg asked about extracting game files; no extraction was performed. |
| BeamNG.drive | High-quality driving and damage physics as an ambition, not a ready-made transplant. |
| Morrowind and Oblivion | Especially their humour. |
| Fallout 3 | Favourite Fallout and the primary Fallout reference. Exact favourite moments still need discussion. |
| S.T.A.L.K.E.R. | Art, creepiness, uncanny atmosphere. |
| Alice: Madness Returns | Additional art/atmosphere reference; exact features still to discuss. |
| HAVKER-MAN X | Confirmed title from the developer's Steam page; precise favourite features still to discuss. |
| Cruelty Squad | Early reference for style, violence and the experimental blend. |
| Older Silent Hill games | Early horror/atmosphere reference. |
| Wrought Flesh | Biopunk organ/flesh-crafting body horror; grossness and internal-anatomy focus for the anatomy/gore system, not its crafting loop specifically. |

## Assistant proposals, not confirmed rules

- Share body, equipment and history across the two realms; determine exceptions explicitly.
- Give a home a counterpart in each world, possibly with cross-world decoration consequences.
- Use decoration/keepsakes/arrangements as a fictional ritual language, while allowing purely aesthetic decoration.
- Start with light survival: food effects and expedition preparation. Hunger penalties, decay, raids and upkeep remain undecided.
- Let earned power overwhelm familiar minor enemies while major enemies challenge the player's strengths.
- Build accurate weapon contacts and damage zones before increasing visual gore detail.
- Use one persistent population and event history so injuries, rivals, relationships, jobs, loot and discoveries connect.
- Separate actual knowledge from rumours and symbolic interpretations in the book/compendium.
- Build a small first-person/third-person encounter and a separate vehicle-physics experiment before a large world.

## Proposed first gameplay milestone

One small space in each realm; one controllable character crossing between them; basic melee combat; one lasting injury; one rival whose history survives a save/load. Placeholder art is acceptable for mechanical verification. This is the next proposed milestone, not a claim that these features exist now.

## Open decisions

World rules; realm identity and transition rules; what persists across realms; death and recovery; exact survival depth; strongest Terraria/Fallout 3 influences; progression curve; melee/gun/power balance; world scale; commandable group size; authored versus simulated dialogue; art asset selection; sound/music; eventual multiplayer.

## Development constraints

- Preserve the entire vision in writing while implementing bounded, testable parts.
- Use original, user-supplied or appropriately licensed assets and code; reference retail games for their observable design, not as portable engine source.
- Do not claim a bridge is connected, a game is playable or a feature is complete until verified.
- Technical test scenes are disposable engineering scaffolding, not approved final art direction.
- Do not copy the previous assistant's claims about legal protection, models or tool capability as established facts.
- Other personal chats have not all been reviewed. This document does not claim a complete personal-chat audit.

## Sources

- User's shared conversation: https://chatgpt.com/share/6aa02558-6538-83ec-8ddc-96f57f5ba58d
- Clarifications and references in the current Codex conversation.
- HAVKER-MAN X developer description: https://store.steampowered.com/app/3645540/HAVKERMAN_X/
