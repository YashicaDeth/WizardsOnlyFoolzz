# greg-10 reader notes

Scope: Greg's own messages in `greg-10.md`, 2026-09-21, oldest first. Agent prose pasted into his messages is excluded as authority. Quotes are Greg's and under 25 words.

## 1. REQUIREMENTS

- [2026-09-21] Gore Sandbox and the real game must share presentation: "should have the same UI".
- [2026-09-21] Bodies need accurate pain and physical collapse: "Where's the like accurate, like pain and ragdoll system".
- [2026-09-21] Losing both legs must put a body down: "He is... should, you know... be on the ground but he's just... standing up".
- [2026-09-21] Damage must expose/destroy coherent anatomy, including organs, bones, head and limbs: "you can shoot like the organs out".
- [2026-09-21] Detached anatomy remains interactable: "you can pick... pick up the torso".
- [2026-09-21] Gore needs substantially more destruction: "It just needs to be so much more like... Destruction".
- [2026-09-21] Weapons must fit hands and have believable ready poses; the failure was "the swords are just way too big for their arms".
- [2026-09-21] Character creation's right-side body must be inside a red sci-fi 3D vat: "the model on the right ... should have a- be in a vat".
- [2026-09-21] The vat body needs an airway tube and suspension leads: "something- in his mouth covering his mouth like a tube" and "wires all- hanging him up".
- [2026-09-21] Intake changes must visibly affect the body; his direct check was "Where's the actual customization?"
- [2026-09-21] The intake UI should be invasive, bloody, veiny hardware rather than an office form: "super prototype-y" and "veiny, like stuff".
- [2026-09-21] The opening lab needs a big vat, computers, cameras, corner lights and piping: "crazy big computers with cameras". Its exit "needs like, access by a keycard".
- [2026-09-21] Vat subjects must use bodies rather than beans, and must not all face one direction: "fix all the beans and make sure the models are facing outward".
- [2026-09-21] The examiner/doctor must be interactable and leave as part of the opening: "whole entire escape... cutscene built where he walks away".
- [2026-09-21] The lab must lead into a larger playable map: "starting lab interrgearioon vart room begin out into a larger nap" [sic].
- [2026-09-21] The underground should use layered, ruined, grimy map principles drawn from Dark Souls and Psychonauts: "Dark Souls is like the inspiration ... for map design".
- [2026-09-21] The broader spatial model is closer to Fallout, with meaningful collision/destruction geometry: "we're gonna have more of a Fallout type map".
- [2026-09-21] The world map should support territory/outpost takeover loops like the cited Far Cry/Just Cause examples: "how you gotta, for the outposts".
- [2026-09-21] The in-game internet should reach the craft and density of the cited personal sites: "make the entire internet design like the quality and design of all these different websites".
- [2026-09-21] Internet art should be darker/eviler and use original procedural textures/assets: "procedurally generated and make like textures and assets".
- [2026-09-21] Gore Sandbox performance must be repaired alongside the opening: "fix perofmance issues in gore sandbox" [sic].
- [2026-09-21] No new sound direction was stated in this chunk.

## 2. DISLIKES / REJECTIONS

- [2026-09-21] No nonphysical death response: "There's no ragdoll physics, where's the ragdoll physics?"
- [2026-09-21] No malformed anatomy after damage: "it doesn't even look properly right".
- [2026-09-21] No oversized, downward-hanging swords: "held like directly down".
- [2026-09-21] The intake's clipboard/form look is rejected: "the menu looks really shitty and it looks like a gross clipboard".
- [2026-09-21] Fake customization is rejected: "there doesn't do jaw though, nothing actually changes".
- [2026-09-21] Do not start gameplay automatically before the intake is complete: "Oh my God... The game just started me anyway".
- [2026-09-21] The abrupt objective-only start is rejected: "now it just says, \"Escape the facility\", I didn't even do anything".
- [2026-09-21] Repeating green rings, glitched subjects and bean placeholders must go: "majority of them are actually beans, amazingly".
- [2026-09-21] The examiner cannot carry a nonsense prop: "for some reason he's got like a steering wheel in his hand".
- [2026-09-21] A route that blocks on a nonresponsive examiner is unacceptable: "So now I can't really do anything".
- [2026-09-21] The intake cannot be a passive bottom-left conversation: "Little chat box in the bottom left is just like boring".
- [2026-09-21] The player cannot simply begin outside containment: "There's no vat. I'm still al-alloud out of the damn vat".
- [2026-09-21] Breakout without visibly smashing the tube is wrong: "I don't even smash out of the glass tube".
- [2026-09-21] The underground vehicle space looked unfinished: "we're underground and the map looks absolutely terrible".
- [2026-09-21] Reload must not reverse the vehicle: "R makes the car drive backwards".
- [2026-09-21] The Gore Sandbox regression was unplayably slow: "It's laggy. Sucks. I hate it".
- [2026-09-21] Voice interaction was too slow for ongoing work: "keep going i think voice is just quite slow".

## 3. DECISIONS

- [2026-09-21] The immediate work package was opening-route repair plus Gore Sandbox performance, sent to both agents: "sending this to both agents".
- [2026-09-21] Website references named: Melonking, Zyntax, Textures/Neocities, Salted Slug, The Rift, OMG.LORD resources, The Base Mesh and Noclip.
- [2026-09-21] The website goal was influence rather than literal duplication at first: "Oh, not a copy".
- [2026-09-21] Internet execution may use procedural generation to create a custom mock version: "make your own copy mock version using it".
- [2026-09-21] Map references named: Dark Souls areas, Psychonauts, Fallout 3/New Vegas, Schedule 1, Just Cause, Red Dead, Skyrim, GTA, Bully and Far Cry.
- [2026-09-21] Map-reference priorities: destroyed architecture, griminess, collision-readable geometry, vertical/layered spaces and large-scale overworld routing.
- [2026-09-21] Far Cry/Just Cause-style outpost takeover was selected as a map-system reference: "how you gotta, for the outposts".
- [2026-09-21] He later explicitly permitted direct reference-site/game asset use for this personal build: "We're gonna use assets from these games"; see contradiction below.
- [2026-09-21] Continue in text rather than voice for efficiency: "keep going i think voice is just quite slow".

## 4. STILL OPEN?

- [2026-09-21] **PARTLY -- accurate gore, pain, severing and ragdolls.** Requirement: "accurate, like pain and ragdoll system". Production has shared anatomy/severing/X-ray in `game/systems/baseline_human.gd`, corpse physics in `game/systems/ragdoll_body.gd`, and the wired sandbox in `game/gore_demo.gd`. Later Greg still asked for better pain/ragdoll/gore on 2026-09-27 (session `01a0dd89`), and performance/physics work continued on 2026-09-30 (`01a0e110`).
- [2026-09-21] **BUILT -- Gore Sandbox shares core body and HUD systems.** Requirement: "should have the same UI". `game/gore_demo.gd` instantiates `gothic_field_hud.gd` and `BaselineHuman`; parity coverage exists in `gore_sandbox_systems_parity_test.gd` and `gore_sandbox_combat_parity_test.gd`.
- [2026-09-21] **PARTLY -- weapon fit and pose.** Complaint: "swords are just way too big". `game/gore_demo.gd` and `game/systems/sword_moveset.gd` contain production sword mounts/moves, but no grep evidence proves the visual scale/grip complaint is resolved; no render was inspected.
- [2026-09-21] **PARTLY -- Gore Sandbox performance.** Requirement: "fix perofmance issues in gore sandbox". Budgets and cleanup are covered by `game/tests/sandbox_recovery_test.gd`; later session `01a0e110` still measured heavy-gore performance and identified ongoing scene/HUD cost, so this is not closed.
- [2026-09-21] **BUILT -- vat/intake/examiner/breakout to Service Arcade.** Requirements include "be in a vat", a mouth tube, wires, visible breakout and examiner departure. `game/vat_chamber.gd` production-wires intake, examiner departure, mouth cord, umbilicals, glass blows and the transition to `service_arcade.tscn`; `game/systems/vat_body_preview.gd` builds the tank and visible mouth tube. Evidence tests include `vat_body_preview_test.gd`, `vat_containment_test.gd`, `vat_smash_test.gd`, `intake_variance_test.gd` and `service_arcade_route_test.gd`.
- [2026-09-21] **PARTLY -- opening visual quality and subject replacement.** Complaint: "majority of them are actually beans". Current code has `VatHorror`, `LabVat`, `BaselineHuman` subjects and lab cabling, but later 2026-09-28 reassessment (`01a0dd89`) still called for selective visual rebuilding of the floating body, mouth tube and skull leads. Code presence does not prove the current look.
- [2026-09-21] **BUILT -- larger underground route.** Requirement: "begin out into a larger nap" [sic]. `service_arcade.gd` hands the pressure gate to `buried_city.tscn`; `buried_city.gd` implements Lower Works and the heat-elevator surface handoff to `bone_yard_hunt.tscn`. Search found later route work in session `01a0a9a2` (2026-09-21 12:33) and cross-room verification in `cd109751`/`ses_f3c2` (2026-09-26).
- [2026-09-21] **PARTLY -- in-game internet/Web aesthetic.** Requirement: "make the entire internet design like the quality and design of all these different websites". `wire_browser.gd` and `wire_site_catalog.gd` implement distinct sites, profiles, links and aesthetic metadata, but repo grep found no production caller for `WireBrowser` and no Melonking/Neocities/Texturetown references outside tests. Built as a subsystem, not proven in the route.
- [2026-09-21] **PARTLY -- large territory/outpost map loop.** Requirement: "how you gotta, for the outposts". `facility_territory.gd`, `ashbloom_holdings.gd` and production calls in `bone_yard_hunt.gd` provide territories, settlements, raids/caches and liberation state. This is substantial infrastructure, but not evidence that the cited broad outpost/takeover experience or final large map is complete.
- [2026-09-21] **NOT FOUND -- direct copied assets from cited commercial games/sites.** Request: "We're gonna use assets from these games". Repo grep found no named Noclip/Melonking/Neocities asset wiring. Current `DESIGN.md` instead requires original, user-supplied or appropriately licensed assets, so this request was superseded rather than left to implement.

## 5. WORLD / LORE / NAMES

- [2026-09-21] **Gore Sandbox** -- Greg's name for the anatomy/destruction test space.
- [2026-09-21] **vat room / starting lab / interrogation vat room** -- his language for the opening containment/intake space.
- [2026-09-21] **doctor** -- the lone lab figure discussed in the opening; no personal name was supplied in this chunk.
- [2026-09-21] **underground heat** -- the then-current post-opening destination; he described being unable to reach it and later reaching it too abruptly.
- [2026-09-21] **internet / websites** -- the in-world network's desired form; the chunk does not coin a new canonical app/site name.
- [2026-09-21] No new faction, species or original settlement name was coined in this chunk. Dark Souls, Fallout, GTA, Far Cry, etc. are references, not WIZARDS ONLY FOOLS lore.

## 6. STYLE OF WORKING

- [2026-09-21] Parallel cooperation was wanted: "work hard with your brother" and "sending this to both agents".
- [2026-09-21] He wanted agents to monitor each other's active work: "have a look at what Claude's doing".
- [2026-09-21] He wanted a highly complete handoff prompt for Claude: "most advanced, most- most- ahead, most locked in, most best... Best ever prompt for Claude".
- [2026-09-21] He wanted live playtest narration to drive fixes: "should i call you and gamepl[ay tewst through anrration" [sic].
- [2026-09-21] He expected visible progress quickly: "How fast are you doing it?"
- [2026-09-21] Placeholder excuses had expired: "I understand it's just like starting base point" followed by "we need to remove these".
- [2026-09-21] Text continuation was preferred when voice slowed throughput: "keep going i think voice is just quite slow".
- [2026-09-21] No token, credit or explicit usage-budget instruction appears in this chunk.

## 7. CONTRADICTIONS INSIDE THIS CHUNK

- [2026-09-21] Reference use shifts from "Oh, not a copy" to "We're gonna use assets from these games". The former supports influence/original work; the latter asks direct reuse.
- [2026-09-21] He says "make your own copy mock version" using procedural assets, but later says "You can use all the assets from these ... worlds". Original recreation and extraction/reuse are materially different.
- [2026-09-21] He frames cited assets as acceptable when not reproduced, then says "We can, we can, we can" use game assets. The permitted boundary is internally unstable.
- [2026-09-21] "We can copy Schedule 1's drugs" conflicts with the earlier "not a copy" principle. No precise mechanic-only boundary is supplied in this chunk.
- [checked 2026-10-04] The newer project rule resolves these conflicts in favor of original/user-supplied/appropriately licensed assets; commercial references supply design principles, not portable content.
