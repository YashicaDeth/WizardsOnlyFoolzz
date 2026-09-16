# Living design notes

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
- The field HUD's corners have different bodily and world-facing jobs rather than repeating generic panels. The top-right carries an original mood reliquary with narrow vertical fluid reservoirs hanging beneath it for blood/health and dirty-water stamina; magick has no vessel at all until the player actually unlocks it. The lower-right is ultimately the scuffed Black Mirror phone physically poking from the jester costume's pocket, not a floating app panel. The lower-left belongs consistently to its live satellite/radar feed so spatial information never moves. Contextual anatomy appears beneath the top-left world/threat instrument when an organ is under pressure, beginning with lungs that visibly take smoke, trigger coughing on a harsh draw, retain dark staining between sessions and clear only when those lungs are replaced. This quick diagnostic should later expand on a held input into a rotatable 3D model of the same live organs. Held weapons and ammunition should stay readable through the physical hands/gear rather than competing with the phone as another corner app.
- Ordinary first-person play is viewed through restrained ceremonial glass: a slight permanent fisheye bow darkens the extreme edges, while mirrored visceral-regal corner cartouches and thin bone rails form an elegant screen border. The interface itself remains sharp and unwarped, and the former centred location banner stays absent so the frame can breathe.
- The lower-right held-item readout is a slowly moving 3D reliquary fed by the real object in the player's hands, not a flat weapon-specific silhouette; guns, smokeables, tools and severed limbs all use the same presentation. Every object is centred and fit against its complete turning radius. Its seamless 22-second screensaver motion describes a full orbit without reading as a one-way shop turntable: brief yaw reversals, restrained pitch and roll, and breathing scale use 3/5/8 Fibonacci harmonics offset by the golden angle. The lower-left compact map is the same live satellite camera as the opened Black Mirror map, centred on the player and updated sparingly.
- Do not leave technical body-inspection fixtures unexplained in the playable route. The red witness mirror formerly standing in the Hunt's opening view is removed; a body mirror belongs in an authored room or explicit inspection interaction where its purpose is legible.
- Smoking is expressed through the persistent anatomy system, not a disposable effect icon: cigarettes, joints and spliffs are held in an open, splayed-finger grip and raised to the mouth, while inhaled smoke temporarily fills the lung X-ray and repeated use slowly stains and harms the actual saved lung organs.
- World time should breathe rather than race: the implemented day/night cycle is one full in-world day per real hour, with deliberate sleep and travel still able to pass time directly.
- The Ashbloom Expanse does not use the modern Roman calendar. Its civil calendar has three seasons (Ashfall, Emergence and Reaping), twelve original thirty-day months divided into ten-day decans, then five ominous Uncounted Days outside every month: the Fool, Wound, Mirror, Wire and Flame. This is an original setting system structurally informed by ancient Egyptian civil timekeeping, not a direct import of its religious names.
- High-quality code and deliberate art direction; generative imagery is not the foundation. Greg's own artwork should be central.
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
- The Black Mirror's satellite map is an exceptionally invasive security system owned by a fictional corrupt space/surveillance agency. It can publish a target's approximate area, attach bounties and jobs to places, and let contractors work for or against that institution; looking through the map also means the institution can look back.
- The world map is divided into named, visibly bounded holdings. Exploration reveals them and later play can reclaim/liberate them by dismantling fictional bandit camps, trafficker and organ-market networks, cartels, alien installations and other local power structures. Cleared holdings visibly improve and produce new consequences, work and faction reactions rather than becoming a one-time checklist icon.
- Allusions Too Grandeur is an extremely detailed unlockable book of images and lore, potentially accessible from the menu. Changing images, metadata, characters in art, hints and hidden lore were discussed.
- A violent demolition-derby activity with original world, vehicle, targets and presentation; it may take broad genre-level inspiration from arcade demolition derbies, but must not copy a specific game's protected content. BeamNG-level damage remains a research ambition needing a separate feasibility prototype.
- Persistent multiplayer/server ambitions were mentioned as a far-future possibility. Rust-like human proximity chat is a future multiplayer consideration, not part of the clarified current player model.

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
