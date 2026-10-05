# Greg chunk 05 notes

Scope: `greg-05.md`, 2026-09-16 to 2026-09-18. Agent prose pasted inside Greg's messages and repeated goal-system boilerplate are excluded as Greg-authored requirements.

## 1. REQUIREMENTS

- 2026-09-16 — Hands/held objects: hands must have credible world-consistent anatomy. Exact: “hand anatomy should be good and accurate to the game world”.
- 2026-09-16 — Smoking: the cigarette should travel naturally between hand and mouth; it can stay at the mouth, be puffed hands-free, and be toggled back. Exact: “you should also be able to hold the ciggerate in your mouth and puff it”. The bong is a possible exception.
- 2026-09-16 — Lighting: lighter/flame effects must respond to current daylight, weather and surroundings instead of retaining night-strength glare. Exact: “make it match the weather and sourrunding”.
- 2026-09-16 — Map/world: the first territorial focus should be the captive underground facility, its escape, and the derby. Exact: “starting undergrouind facility you have to escape from and do the derby in”.
- 2026-09-16 — CellOutz/platform tone: the surveillance/bounty organisation is overtly evil and occult rather than neutral. Exact: “openly satirically evil and openly occult corporate bounty platform”.
- 2026-09-16 — Art direction: create a separate art-direction mind map because Greg's own work should underpin the game. Exact: “i want alot of the stuff in ther game to be my own”.
- 2026-09-16 — Combat: first person should be difficult, physical and brawl-like. Exact: “combat in first person i want to be like a challenge and brawl”.
- 2026-09-16 — Combat/camera: the player can switch to a Soulslike, combo-oriented third person influenced by Shadow of Mordor. Exact: “your able to switch into third person of the game wherere it will be soulslike with combos”.
- 2026-09-16 — Weapons: guns need deliberate aiming. Exact: “also aiming with the guns”.
- 2026-09-16 — Tone: balance horror and comedy rather than committing to only one. Exact: “probably the best balance of horror comedy ect”.
- 2026-09-16–18 — No separate Greg-authored requirement in this chunk for named characters, HUD design, tunnel topology, final exits, sound mix, or frame-rate target. Those subjects appear only in pasted agent goal text or not at all.

## 2. DISLIKES / REJECTIONS

- 2026-09-16 — The existing cigarette/mouth/hand alignment is visibly wrong. Exact: “right now its kinda off”.
- 2026-09-16 — Daytime lighter effects are far too bright and cast an obvious glimmer/shadow. Exact: “in the day its super bright”.
- 2026-09-16 — The Black Mirror page concept/presentation was unclear. Exact: “page kinda confusing”.
- 2026-09-16 — He did not understand the “Service Ring” label or what happened there. Exact: “what is the service ring i dont really understand whats going on here”.
- 2026-09-16 — He was not ready to approve the shutter without seeing it. Exact: “im not sure about the shutter show me an examplke”.
- 2026-09-17 — A supposedly long goal ending after 25 minutes was unacceptable. Exact: “damn it only took u 25 minutes fuck”.

## 3. DECISIONS

- 2026-09-16 — On the proposed territorial MAP loop: agreed, but placed its first implementation in the underground starting facility/escape/derby. Exact: “i agree but probably the starting undergrouind facility”.
- 2026-09-16 — On the organisation's presentation: chose an openly satirical, evil, occult corporate bounty platform. Exact: “openly satirically evil and openly occult corporate bounty platform yah”.
- 2026-09-16 — On unresolved art direction: do not guess it; make a separate mind map and centre Greg's own material. Exact: “we need to make a seperate art document where its a mindmap”.
- 2026-09-16 — On combat: first-person challenge/brawl, switchable third-person Soulslike combos, and gun aiming. Exact: “also aiming with the guns”.
- 2026-09-16 — On tone: pursue a horror/comedy balance. Exact: “probably the best balance of horror comedy ect”.
- 2026-09-16 — MAP leading into INDEX through freeing places remained tentative, not answered. Exact: “im honestly not sure maybe the map and it leads into the index”.
- 2026-09-16 — No final Black Mirror transition was selected; he asked to see a shutter example and queried a corruption sound. Exact: “corruption sound?”
- 2026-09-18 — He approved continuing efficient ledger routing after the movement-action list was presented. Exact: “reckon work on this tell me how it is”.

## 4. STILL OPEN?

Later-session checks used `agenthub.py search --human`; implementation checks used read-only grep in `P:/GameDev/worktrees/launch-latest/game`.

- 2026-09-16 — **BUILT — articulated hands and mouth-held smoking.** Requirement: “hold the ciggerate in your mouth and puff it”. Evidence: `game/systems/held_gear.gd` builds a palm, four three-joint fingers and a thumb with smoke/lighter poses; `game/bone_yard_hunt.gd:3413` toggles lip-hold, excludes the bong, allows weapon use, and records the action. Greg was actively testing the Y interaction in session `01a0a9a2` on 2026-09-18 03:09.
- 2026-09-16 — **BUILT — daylight/weather-aware lighter.** Requirement: “make it match the weather and sourrunding”. Evidence: `game/bone_yard_hunt.gd:3848` derives close-prop light from `WorldClock.daylight()` and storm severity; `:3930` scales lighter energy.
- 2026-09-16 — **BUILT — first facility territory/MAP→INDEX loop.** Requirement: “starting undergrouind facility you have to escape from and do the derby in”. Evidence: `game/systems/facility_territory.gd` owns four persistent sectors, MAP/INDEX state and CellOutz reaction; `game/tests/facility_territory_test.gd` covers derby liberation, INDEX unlock, bounty and quantum restore; `game/systems/living_map.gd` consumes it.
- 2026-09-16 — **BUILT — art-direction mind map.** Requirement: “make a seperate art document where its a mindmap”. Evidence: `P:/GameDev/worktrees/launch-latest/ART-DIRECTION-MINDMAP.md` exists (21,738 bytes) and is referenced by `DESIGN.md`.
- 2026-09-16 — **BUILT — Service Ring clarity.** Dislike: “i dont really understand whats going on here”. Evidence: `game/systems/facility_territory.gd:39` keeps `service_ring` only as a save ID; the player-facing area is **THE LOCKDOWN GRID** with the explicit three-relay objective.
- 2026-09-16 — **PARTLY — Black Mirror transition decision.** Request: “show me an examplke”. Three equal-timing candidates and audio exist in `game/systems/handheld_device.gd`, `black_mirror_transition_audio.gd`, and `tests/handheld_transition_comparison_capture.gd`; a common page grammar and production shutter are wired. No later human search found Greg choosing shutter/corruption/carousel, and `handheld_device.gd:112` explicitly retains shutter until he chooses.
- 2026-09-16 — **PARTLY — first-/third-person combat target.** Requirement: “wherere it will be soulslike with combos kinda like shadow of mordor”. Evidence: `game/bone_yard_hunt.gd` has first/third-person switching, firearm aim, lock-on, combo tracking and committed directional attacks; `tests/third_person_sandbox_test.gd` exercises the shoulder camera, lock, sword sequence, guard and return to first person. Later Greg continued specifying and tuning Soulslike combat on 2026-09-30, so the broad feel/quality target is not finished merely because its mechanics exist.
- 2026-09-18 — **BUILT — efficient action-ledger routing.** Approval: “reckon work on this tell me how it is”. Evidence: `game/bone_yard_hunt.gd` records accepted jump, dodge, wall-run kickoff and grip-change actions; `jump_test.gd`, `wall_run_test.gd`, `third_person_dodge_test.gd`, and `two_handing_test.gd` check one receipt and refusal behavior.

## 5. WORLD / LORE / NAMES

- 2026-09-16 — **Black Mirror**, **MAP**, and **INDEX** are the named interface/world instruments discussed. Greg tentatively imagined MAP leading to INDEX through liberation: “maybe the map and it leads into the index”.
- 2026-09-16 — The first place is described, with his spelling, as the “starting undergrouind facility”; it includes the escape and the **derby**.
- 2026-09-16 — **Service Ring** was a presented term Greg rejected as unclear, not a name he endorsed: “what is the service ring”.
- 2026-09-16 — The surveillance organisation's lore role is an “openly occult corporate bounty platform”; Greg supplied no faction/company name in this chunk.
- 2026-09-16–18 — No character names, faction names, tunnel names, or exit names were coined by Greg in this chunk.

## 6. STYLE OF WORKING

- 2026-09-16 — Give agents real latitude within source-of-truth constraints. Exact: “i need you to want to work on what you want to”.
- 2026-09-16 — Make goals efficient and substantial enough to run for hours. Exact: “is there a goal you can run that you can verify will take many hours”.
- 2026-09-16 — Ask Greg for the information that would improve output instead of silently guessing. Exact: “tell me everythging you need to hear from me so we can get better work done”.
- 2026-09-17 — Continue useful goals without stopping early. Exact: “keep working on all the goals you can and want to”.
- 2026-09-17 — Use the available usage budget and do not prematurely close a persistent goal. Exact: “until usage limit make sure not to end the goal until you cant”.
- 2026-09-17 — Twenty-five minutes did not meet the promised long-run bar. Exact: “damn it only took u 25 minutes fuck”.
- 2026-09-17 — Gameplay proof and a playable build matter more than reports alone. Exact: “show me some gaemplay let me play”.
- 2026-09-18 — When he selects a priority, implement it and explain its actual state. Exact: “reckon work on this tell me how it is”.

## 7. CONTRADICTIONS INSIDE THIS CHUNK

- 2026-09-16 — Mouth-hold is internally ambivalent: “maybe not the mouth cause its a little weird” is immediately followed by “you should also be able to hold the ciggerate in your mouth”. The latter, more specific instruction wins; bong remains the exception.
- 2026-09-16 to 2026-09-17 — Stopping condition changed. He first requested an “efficent goal” and accepted a finite pasted goal, then replaced that working style with “until usage limit make sure not to end the goal until you cant”. Newest direction: keep progressing until the usage limit.
- 2026-09-16 — MAP/INDEX was not a hard contradiction but an unresolved tension: “im honestly not sure maybe the map” followed in the same message by agreement with the territorial MAP loop. Treat the loop/facility as decided; treat exact default-page and liberation handoff presentation as open at that date.
- 2026-09-16–18 — No contradiction between heavy first-person brawling and Soulslike third person: Greg explicitly wanted both modes. No contradictory character, tunnel, exit, HUD, sound, or performance answer appears in this chunk.
