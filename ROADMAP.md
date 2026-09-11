# Roadmap

## 11 September behavioral audit

Follow-up: exterior building-avoidance routing and collision bodies now serve encounter NPCs. Friendly healing/bond, paid trade and testimony interactions resolve persistently. Eighteen isolated behavioral checks pass. Interior navigation, authored encounter staging, live animation and visual quality checks remain pending.

Verified repairs: collision-aware hunter and open doorways; non-overlapping settlement lots; delayed melee hits; timed dodge movement; Mara attack cooldown; hidden rival hit rejection; collectible loot; inventory persistence; artwork moved to J to avoid WASD conflict; menu strike suppression; anatomy snapshot restoration; dead/escaped encounter suppression; visible derby countdown and terminal result state.

Earlier entries below describe prototypes, not a finished opening. Still outstanding: navigation-aware NPC chase, physical player-vehicle handling, full save/load loop tests, production character/gore rigs and organ simulation, four fully resolved Misfire branches, personal-art integration, and visual acceptance testing. The map and dossier remain schematic. A 15–20 minute polished slice is not complete.

## Current milestone

World Zero foundations is the development milestone. In fiction, the first region is **The Ashbloom Expanse**, inside the wasteland realm called **Limbo**: the Bone Yard derby opens into a huge post-nuclear landscape of runaway fungal ecology, decayed cybernetics, raider roads, stalker territories and buried anatomical industry.

Implemented foundation:

- Persistent universal event/history store with save-safe subject schema upgrades.
- Mara Voss's continuing rival state, injury, grudge, ELO and encounter memory.
- Original faction/character seed population spanning Ashline Wreckers, Black Mile, Soft Rot Communion and Choir of Marrow.
- Zoomable, pannable Living Kinship Web with selectable faces and relationships.
- Split Vessel / Deep X-ray dossiers showing wounds, organs and cybernetic modules.
- Expanded Ashbloom terrain landmarks, fungal towers and ruined storm pylons.
- Gothic field HUD, Living Map, World Index, animated CellOutz menus and derby presentation.
- Selective collision generated from the authored Bone Yard meshes, plus collision-bearing procedural building shells.
- Derby round win/loss state, exit flow, 64 reactive crowd silhouettes, driver anatomy hit areas and staged detachable doors, hood, bumpers and wheels.
- Runtime-generated placeholder engine, impact, crowd and wasteland ambience audio.
- Reusable anatomy component with body-zone health, blood volume, bleed rate, pain, consciousness, treatment hooks, limb disability and persistent snapshots.
- Hostile encounter escape behavior: wounded NPCs can flee and bleed out; catching them creates a persistent death record and loot cache, while escape preserves their changed body state.
- Five deterministic procedural settlement districts, more than forty enterable building shells and 18 seeded **Reality Misfires** ranging from social encounters to a hostile dead-weather entity.
- Conditional second Mara encounter with an industrial arm, rebuilt vehicle, increased health and two Ashline reinforcements.
- First reactive CellOutz Wire headline and first history/grudge-reactive Allusions artwork (`A`).

## Next bounded slice

Turn these verified prototypes into one polished 15–20 minute opening. Replace primitive damage/crowd/gore stand-ins with authored meshes, animation, materials and licensed or original production audio. Move the vector-only player onto a collision-aware character controller, add navigation and interior population, make loot collectible, give Reality Misfires authored resolution branches, and complete the derby-to-Mara save/load loop. Integrate Greg's supplied artwork into the prepared interactive Allusions layer and redesign the remaining stock Controls around that art.

## Deferred intentionally

Large-scale economy simulation, simulation-grade full body-part damage, multiplayer, BeamNG-scale vehicle deformation and seamless traversal of all Limbo remain separate feasibility milestones. The archive can represent these systems before every one has full gameplay simulation.
