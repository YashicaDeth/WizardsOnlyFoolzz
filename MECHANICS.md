# Mechanics inventory

11 September verified controls: WASD movement with physical collision; J artwork; LMB strike (0.18-second windup, 0.72-second cycle); Space collision-aware dodge (0.28 seconds); E collects nearby loot once; menus suppress attacks. Mara uses a timed strike cooldown rather than a frame-dependent sine-wave attack. These are tuning baselines, not final combat balance.

## Latest user direction - 10 September 2026

Ashbloom should expand into a broad future nuclear wasteland with procedurally arranged towns and enterable buildings. Local travel can trigger memorable random encounters now named **Reality Misfires**, spanning friendly NPCs, strange social scenes, traders, hostile patrols and rare dead-god boss events. Body damage should support blood loss, organ/limb consequences, visible fictional dismemberment, persistent wounds and escape behavior: critically wounded enemies may run, continue bleeding and preserve their changed state; catching them can produce loot. The larger goals remain production-scale systems, while the current implementation is a verified mechanical foundation using authored environment assets and explicit placeholder geometry/audio where final content does not exist.

## Latest user direction - 9 September 2026

This clarification supersedes earlier forced-camera rules below: the game should feel Fallout-like in third person, with a player-controlled switch to first person and back. Combat and loot systems are central pillars alongside economies, distinct factions, and the persistent bounty/rival system. Keep one protagonist and the two-world concept unless the user changes them; camera choice is no longer tied to a realm. Exact faction names, economy rules, weapon balance and loot progression remain design decisions, not approved implementations.

This is the requested recap of Greg's current vision, not a promise that every feature is already specified or implemented. Desired systems are separated from decisions that remain open. DESIGN.md retains the reference games and wider context.

1. **One character, two worlds.** The same protagonist crosses between a hell-like realm and a heaven-like or corrupted counterpart. The metaphors can be literal or symbolic.
2. **Perspective as a world rule.** Some parts force first-person play and others force third-person play. The game eventually combines these experiences through travel and transitions. It is not currently a two-character or two-player design.
3. **Exploration and hubs.** Roam through main areas and return to places connecting the worlds. Layout, travel restrictions and the effect each world has on the other remain open.
4. **Soulslike fighting and bosses.** Dark Souls 3 is the primary combat reference, with the rough character of Prison of Husks. Exact stamina, dodging, guarding, parrying, lock-on and weapon movesets still need decisions; liking Souls does not automatically settle each rule.
5. **Growing into frightening power.** Blend deliberate fighting with Prototype-like third-person aggression, mobility and brutal power. Familiar enemies should eventually let the player feel strong. The exact progression and enemy-scaling rules are open.
6. **Physical hits, injuries and gore.** Hit placement and body differences should matter. Aim for fictional dismemberment and strong physical reactions, with special anatomy and rules for some bosses. The desired visual intensity is clear; what each injury actually does must be designed.
7. **Bodies and modification.** Original species/races, mutations, body parts, organs, bones, fingers, hands and feet. Replacing parts and compatible prosthetics are part of the wider body-system idea. We need limits that keep it readable and buildable.
8. **Persistent rivals.** Enemies can become recurring individuals with a history involving the player, rather than disposable anonymous encounters. Exact promotion, retreat, revenge and return rules are open.
9. **Bounties, ranks and ratings.** Hunting and reputation interact with rival status, ranks and an Elo-like rating. Whether ratings are visible, hidden or entirely in-world remains undecided. Bounty eligibility and rewards need world rules.
10. **Loot and an optional boss ladder.** Distinct loot pools and a ladder of challenging opponents support progression. Item rarity, crafting, equipment slots and loss-on-death are not yet settled.
11. **Friends as the counterpart to rivals.** Friendship and hostility should both develop through history, reflecting the 'as above, so below' idea. Relationship growth and recurring character development draw from Hades and the other social references.
12. **NPC lives and positions.** Important characters have jobs, ranks, connections and a place in society. The world should feel inhabited and capable of producing funny or strange encounters. How much happens away from the player is an open simulation question.
13. **Factions and religion.** Allegiances, fictional beliefs and religious groups can shape how the world treats the player. Joining, leading, founding and betraying groups are possibilities to define, not four approved implementations.
14. **Followers and command.** The player may gather and direct friends, followers, devotees or captives/slaves within the fictional setting. Group size, autonomy, recruitment, escape and command controls are not decided.
15. **World economy.** An NPC-driven economy that changes cyclically and unpredictably. Jobs, goods, status and events may connect, but production chains and market simulation have not been specified.
16. **Chaos-magick world rules.** Occult ritual, symbolic rules and a karma-like structure are part of the fictional universe. The concrete rules and their consequences are still for Greg to define. This is world design, not a claim about real-world magic.
17. **Base building.** Establish places that feel like home, with Valheim/Terraria-style attachment and possibilities for construction and expansion. Building materials, structural rules, harvesting and crafting depth remain open.
18. **Decoration and home life.** Personalise spaces, collect meaningful objects and develop relationships and stories around the home. Stardew-like comfort can coexist with the strange world. Mechanically effective ritual decoration is an assistant proposal, not a settled requirement.
19. **Survival at a chosen intensity.** Survival elements may support exploration and preparation, but the experience should not feel crushing. Hunger, thirst, upkeep, durability, raids, decay and punitive death recovery have not been approved as mandatory systems.
20. **Compendium, map and relationship tree.** Unlock information about places, species and characters through a carefully designed field guide, a developing map and a readable record of relationships.
21. **Allusions Too Grandeur art/lore book.** A detailed unlockable book of Greg's images and lore, possibly accessible from the menu. Images, their metadata, characters within art, changes and concealed hints can carry discoveries. Exact interaction is open.
22. **An in-game internet.** A fictional network tied to CellOutz and the artistic universe. It could carry authored pages and world information; live access to the real internet has not been requested as a mechanic.
23. **Demolition derby.** A violent vehicle activity inspired by SpongeBob's Boating Bash on Wii, with ambitions for much richer driving, crashes and gore. BeamNG-level damage is a research ambition needing a separate prototype, not an assumed engine feature. No retail game files have been extracted.
24. **Social chaos and humour.** Awkward, funny NPC interactions and unpredictable events matter alongside horror, drawing on Morrowind, Oblivion, Fallout 3 and Rust's social energy. Human proximity chat depends on future multiplayer, which is outside the current one-character single-player starting point.
25. **Dense discovery and changing tone.** Psychedelia, occult weirdness, uncanny places, strong character art, secrets, surprises and moments of comfort should give the player varied stimulation. This is an experience goal, not an instruction to flood every moment with effects or chores. Outlast is also an explicit horror reference; its specific mechanical influence remains open.

## Still to define before a full design is locked

World laws and cosmology; the actual repeatable player loop; travel and perspective boundaries; what persists between worlds; death and recovery; survival pressure; body-system granularity; progression and scaling; powers versus weapons; crafting depth; group size; economy scope; authored versus simulated dialogue; strongest specific Terraria and Fallout 3 influences; audio direction; eventual multiplayer.

## Proposed first playable slice

A small area in each world, one character with the required perspective in each, one weapon, one opponent who can become a persistent rival, one meaningful body injury, one travel point, a tiny home with a placeable object, and save/load. Add or reduce this after Greg's world-rule discussion. This is a proposal, not an approved full production scope.

The derby, a large economy and large follower groups get separate feasibility tests after movement and combat feel good. Preserve them in the vision instead of pretending they are cheap additions.
