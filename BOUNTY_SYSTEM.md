# Allusions to Grandeur — bounty-centred design update

## Latest user direction - 9 September 2026

This clarification supersedes earlier forced-camera rules below: the game should feel Fallout-like in third person, with a player-controlled switch to first person and back. Combat and loot systems are central pillars alongside economies, distinct factions, and the persistent bounty/rival system. Keep one protagonist and the two-world concept unless the user changes them; camera choice is no longer tied to a realm. Exact faction names, economy rules, weapon balance and loot progression remain design decisions, not approved implementations.

Version 2 · 2026-09-09

## Confirmed new priority

Greg explicitly asks to make the game revolve around a bounty / nemesis-style system. Retain one protagonist crossing two worlds, reflected friendships, persistent bodies, social history and the living art book. This is a design update, not implemented gameplay.

## Proposed Hunt specification

### The core loop

Read a lead → investigate a person → prepare → hunt or be hunted → decide their fate → live with the aftermath → discover the next connection. Exploration, combat, friendship, economy and the archive all feed this loop. A bounty is a reason to engage with a person who already has a place in the world.

### Persistent identity

Give each significant NPC a stable ID, name, species, appearance, occupation, faction, relationships, equipment, injuries and event history. Their identity survives realm changes, retreat and save/load. The player’s knowledge is a separate record: unknown facts stay unknown until discovered.

### Bounty contracts

Proposed contract fields: issuer, target ID, reason, evidence, objective, reward, expiry or cancellation rule, and settlement state. Start with one authored issuer and a simple objective. Later consider capture, protection, retrieval or investigation contracts. These objective variants are proposals, not recovered requirements.

### Rival formation

An encounter, betrayal, injury, mercy or witnessed act can seed a personal arc. Interpret the event through the character’s existing motives and relationships. A person may seek revenge, avoid the player, bargain, train or change allegiance. Do not force every survivor into the same revenge response.

### Hunt arcs in both directions

The player tracks targets; rivals can pursue the player. Proposed arc states: dormant → investigating → preparing → pursuing → confrontation → aftermath → cooldown or closure. Each transition needs a world cause, usable information and a readable clue. Start with one rival and one active pursuit.

### Ratings, rank & threat

Keep hidden combat ability, faction rank, public reputation and relationship intensity separate. An injured veteran can hold high rank while temporarily weakened. Threat presentation should use what the player knows. The Elo formula, visibility, promotion thresholds and progression curve remain undecided.

### Bodies tell the history

A surviving target can carry scars, loss of function or a replacement part from an earlier encounter. Species, mutations, organs, bones and prosthetic compatibility influence their available adaptations. Start with one injury and one adaptation before simulating fingers, internal organs and extensive surgery.

### Friends mirror rivals

Record help, trust, shared experiences, debts and betrayal through the same history system. An ally can give a lead, warn of a hunter, offer refuge or help secure a repair. These are proposed expressions of the confirmed friendship/rivalry reflection; friendship is not just negative hostility.

### Jobs, factions & the economy

Bounties need an issuer and resources. Jobs explain where targets go, who depends on them and what their disappearance changes. Later, supply disruptions and faction disputes can create contracts. Begin with one issuer, one merchant and a small stock ledger; a complete self-running economy comes later.

### One person across two worlds

The same protagonist crosses the forced first-person and third-person realms. Proposed rule: stable character and event IDs span both worlds. Decide whether a target travels physically, has a counterpart or only leaves evidence across the boundary. Do not duplicate a target accidentally because the camera changes.

### The book as an investigation tool

A discovered portrait, changed timestamp, hidden figure or annotation can reveal a clue about a target. Link each clue to an actual event and track whether the player discovered it. Unlock the person on the character tree and map gradually. Clicking a discovered detail may trigger a mission, as requested in the phone chat.

### Fictional rituals & karma

The user’s chaos-magick and “as above, so below” direction informs reciprocal consequences, symbolism and strange world events. Proposed implementation: authored event rules with visible traces, not an unexplained universal good/evil score. Exact rites, costs and consequences remain open.

### Loot & the optional ladder

Distinct loot pools and an optional boss ladder support the wider Hunt structure. Proposed rewards depend on the contract, target and outcome. Store settled contract IDs so reloading cannot pay a reward twice. Keep a repeatable challenge ladder separate from whether an individual is permanently dead in the world.

### Closure, death & return

A rivalry must be allowed to end. Define death, survival, retirement, reconciliation and disappearance distinctly. Do not silently resurrect a confirmed dead target to extend an arc. Any supernatural return needs an explicit world rule, a recorded event and its own presentation. Death rules are still open.

### Pacing without crushing the player

Protect moments of home life, exploration and humour. Proposed pursuit cooldowns and limits prevent every encounter from becoming a new ambush. Familiar opponents should eventually demonstrate the player’s earned strength. Named rivals can adapt in specific ways without making all progression feel cancelled.

### A playable proof

Proposed first Hunt slice: one issuer, one target, one friendly witness, a small area in each realm, one weapon, one persistent injury, one return encounter and one changed artwork. Demonstrate a full arc and save/load before adding crowds, procedural dialogue or a large economy.

## How the supporting systems connect

- **Combat & bosses:** Resolve confrontations with readable contact, deliberate fighting and eventual aggressive power.
- **Bodies, species & mutations:** Make each target’s history and adaptations visible and mechanically relevant.
- **Exploration & two realms:** Turn routes, sightings and realm transitions into investigation decisions.
- **Friends, followers & home:** Provide relationships and refuge between hunts; larger command groups remain a later study.
- **Jobs, factions & ranks:** Explain motives, access, contract issuers and changing social positions.
- **Economy:** Give rewards, equipment, repairs and political disputes material consequences.
- **Art book, Compendium & character tree:** Reveal evidence, record discovered histories and show who connects to whom.
- **Fictional internet:** Carry authored bounty notices, rumours, counterclaims and clues tied to world state.
- **Rituals & karma:** Provide the world’s strange symbolic rules once their concrete effects are designed.
- **Derby & driving:** Remain a separate feasibility track; a vehicle-related contract is a later proposal.
- **Multiplayer:** Preserve as a future study after a satisfying single-player world exists.

## Future acceptance checks

- A target retains the same identity, injury and memory after leaving a realm and loading a save.
- A rival cannot pursue based on a fact they never witnessed or learned; uncertain rumours remain distinguishable from fact.
- A resolved or cancelled contract cannot pay twice, reappear as active or target a permanently closed character by mistake.
- Every injury adaptation and arc transition has a recorded cause and can be explained through game clues.
- A friendly outcome produces a meaningful consequence using the same shared history as a hostile outcome.
- The artwork changes only when its linked event occurs; original source artwork remains intact.
- The first-person and third-person encounters both communicate attacks, damage and interaction clearly.
- Pursuit pressure can subside; returning home and exploring without an immediate ambush remain possible.

## Inspirations

- **Middle-earth: Shadow of Mordor / the Nemesis reference:** Explicitly named in the original phone chat: memorable recurring enemies and bounty/rival histories. The new design centres those high-level goals in an original two-world Hunt system. Exact implementation is a new proposal.
- **---:** ---
- **Dark Souls 3:** Primary combat reference: fighting and bosses.
- **Dark Souls 2:** Worldbuilding and atmosphere.
- **Prison of Husks:** Its rough/"bootleg" Soulslike combat style, visual style and world.
- **Everhood 1 and 2:** Psychedelia; Undertale-like influence expressed in a new style.
- **Undertale:** Related tonal reference; exact systems not specified.
- **Fran Bow:** Occult, weird, surreal qualities.
- **Kenshi:** Worldbuilding, races, bodies/body parts; independent-world and group-system implications need further specification.
- **Hades:** Character development.
- **Sally Face:** Art design.
- **Rust:** Stimulating social unpredictability, proximity chat and funny shared play.
- **Terraria:** Loves the whole game; specific priority systems still need unpacking.
- **Valheim:** Broad enthusiasm, especially building, relationships/story emerging around a home. Avoid assuming all survival systems are wanted.
- **Stardew Valley:** Decoration and relationship/home-life possibilities.
- **Prototype 1:** Third-person gore and power, to blend with Soulslike fighting.
- **Postal 2:** Gruesomeness; earlier conversation also names sandbox freedom as an assistant interpretation.
- **Paint the Town Red:** Gore and physical combat destruction.
- **SpongeBob's Boating Bash (Wii):** Derby style and feel. Greg asked about extracting game files; no extraction was performed.
- **BeamNG.drive:** High-quality driving and damage physics as an ambition, not a ready-made transplant.
- **Morrowind and Oblivion:** Especially their humour.
- **Fallout 3:** Favourite Fallout and the primary Fallout reference. Exact favourite moments still need discussion.
- **S.T.A.L.K.E.R.:** Art, creepiness, uncanny atmosphere.
- **Alice: Madness Returns:** Additional art/atmosphere reference; exact features still to discuss.
- **HAVKER-MAN X:** Confirmed title from the developer's Steam page; precise favourite features still to discuss.
- **Cruelty Squad:** Early reference for style, violence and the experimental blend.
- **Older Silent Hill games:** Early horror/atmosphere reference.
- **Outlast:** Explicit broad reference for horror. Specific features and how they fit the combat/power progression remain open.
- **DayZ:** Named alongside Rust as a far-future multiplayer/server comparison, not the initial single-player scope.
- **Cloverpit:** The earlier web-game discussion references the physical framing of its slot machine as inspiration for a retro computer/CRT presentation.
- **“in bounty 2” — title unresolved:** Exact phrase from the body/species message. Preserve it for clarification rather than guessing which game was meant.

## Retrieval scope

50 recent task titles and available project list screened; no archived Codex tasks returned. Relevant accessible histories reviewed. This is not an account-wide export. The separate teganlane777 account is not accessible through the current tools.

Reviewed source threads: Game Development With Codex; Review convo and gaming plugins; Brainstorm gallery game concept; AI for Mobile Game Dev; latest ten turns of Printing Method Analysis; Explain repo auth and plugins; Bloodborne Character Creation (separate character-creator request). Some long assistant messages were truncated. Do not claim an exhaustive all-account audit.

## Plugins

- **Godot MCP — Tool surface available here; live editor not re-tested in this task.** Build and inspect the Hunt prototype’s scenes, nodes and game behaviour. Open the existing game project and verify editor/project identity before making scene changes. Keep the editor bridge out of release builds.
- **GitHub — Tools available here; repository access depends on connection.** Keep code, reviewed changes, issue records and the living design together. Use the correct connected repository; keep design changes alongside their implementation.
- **Blender — Local software and scripted workflow recorded in project setup; no Blender MCP tool verified here.** Author characters, weapons, environment pieces and artwork presentation objects. Use the existing installation, editable .blend sources and exported assets. Do not add a second bridge merely for its name.
- **Sites — Available website workflow.** Maintain the hidden roadmap and companion web experience. Preserve CellOutz’s existing hosting and assets; a roadmap edit is separate from a live upload.
- **Documents / PDF / Spreadsheets — Skills available in this session.** Write the design bible, export readable documents and explore economy or balance tables. Use them for concrete artifacts when needed. They are authoring tools, not systems shipped inside the game.
- **Figma — Optional plugin listed; not installed in this session.** Proposed use: design the bounty dossier, character tree and detailed book interface. Connect the account containing the design files; verify the connector’s actual tools and supported access before relying on a workflow.
- **Google Drive — Optional plugin listed; not installed in this session.** Proposed use: store and retrieve shared source notes, artwork references and an uploaded chat export. Connect the account that owns the relevant files. It does not by itself grant access to another ChatGPT account.
- **Trello — Optional plugin listed; not installed in this session.** Proposed use: organise the Hunt slice into small cards with completion criteria. Use one project board if wanted; no board or task is created by this roadmap. Verify available connector actions after connecting.

Optional connections are recommendations, not installed integrations. No game production bridge belongs in the release build.
