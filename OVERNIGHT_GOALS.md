# Overnight goals — 29 September 2026

Picked from `DESIGN/dust-to-bones.html` (the Dust to Bones ledger) and the
unticked `CHECKLIST.md` lines it points to. Every item here can be finished
without a decision from Greg. Anything the ledger lists as his (the 18 open
questions, key art, sound language, the doctor's name, death fiction, the
Board, fluid, rollover, facility age, tier names, routes list) is left out on
purpose.

## Rules for the run

- Branch `claude/playtest-build` only. Commit each item on its own; never
  `git add -A`; never push, merge or rebase.
- Load the project skills first: wof-lane-hygiene, wof-verify-by-looking,
  wof-wire-before-polish, running-headless-godot.
- Done means: a test or capture that fails without the change, opened and
  looked at, and the core suite still green. Tick the matching CHECKLIST
  line with the commit hash when there is one.
- An item that turns out to need Greg's call: stop that item, write the
  question under "Blocked" at the bottom of this file, move on.
- Work in order within a group; the groups can go in any order after A.

## A — Carried over from the last run

1. Tank: fade or delay the brain-hack kaleidoscope while the camera pitches down into the tank.
2. Tank: raise the grown torso's texture resolution / fix filtering so skin stops going blocky up close.
3. Tank: capture looking down with seams, cysts and patches readable; open it.
4. Pad: track last-used device (keyboard/mouse vs pad) in `pad_bridge.gd`.
5. Pad: prompt labels read from that device — Cross/Square/Circle/Triangle, R2/L2, Options.
6. Pad: switch the field HUD key strip, intake hints and pause menu to the device labels.
7. Pad: test that a pad press flips labels and a key press flips them back.
8. Hunt perf: profile the ~7 ms physics-loop cost per script with `process_cost_probe.gd`; list the top five.
9. Hunt perf: move the worst per-frame loop to a lower tick or event-driven update.
10. Hunt perf: the second-worst loop, same treatment.
11. Hunt perf: count draw calls; batch or MultiMesh the repeated props.
12. Hunt perf: HLOD/visibility ranges on distant district props.
13. Hunt perf: re-measure after each change and record the numbers in X.

## B — The dust: built, tested, called by nothing

14. `run_lifecycle.gd`: it contradicts "no runs". Retire it (or rename to the save's life) and update its test.
15. `OpeningDeath`: call it from the facility's death path so dying in the opening reloads honestly.
16. OpeningDeath: scene test that a death in the vat room reaches its reload.
17. `ContactEntities`: wire its entries into the Brain Index as files (read-only).
18. `AlgizReticle`: use it as the Hunt's aim reticle behind a setting; capture it.
19. `WofLockup`: put the title lockup on the boot splash / main menu; capture it.
20. `AshbloomSeals`: show the settlement seals on the satellite map markers.
21. `ParticlePortrait`: use it for the Brain Index hub's "you" portrait fallback.
22. `CabScreens`: mount on the derby cab; capture in `rift_derby`.
23. `RabbitHoleNavigator`: open it from the Wire page; capture.
24. `DemonAmbition`: feed the CellOutz hierarchy panel in the World Index.
25. `AudioReactive`: drive one world light or the nerve rig off the SFX bus (law 15); capture.
26. `WeaponBody`: route the guard's BREACH NINE through it; ballistics test stays green.
27. `TheRoom`: reachable from the Brain Index as a scene link (no new content).
28. `PlayerFaction`: attach to the post-handoff Ashbloom state so it exists after the Hunt starts.
29. `PyramidSociety`: back the rank pyramid page with it using neutral TIER 01–33.
30. For each wired system above: one line in the ledger's dust table marked wired, with commit.

## C — Vertebra 5 and the facility route (AX)

31. Clean up CHECKLIST AX: AX3.3, AX3.4, AX3.5 appear both ticked and unticked; drop the stale duplicates.
32. AX3.1: the broken restraint is the first inspectable, usable object; test it.
33. AX3.2: clothes from a dead failed subject go through body inventory; test the equip path.
34. AX3.3 in play: place `BiometricBarrier` + guard in a facility block-out room.
35. The door opens for a living guard (coerced); scene test.
36. …for a dragged unconscious guard; scene test.
37. …for a corpse; scene test.
38. …for the severed hand; scene test.
39. AX3.4 in play: the guard's BREACH NINE drops only from that guard; three rounds, no reload; test.
40. Each door method writes through `facility_routes` / player action ledger (AX4.6).
41. AX3.6: audit every intake/lab interface for a permanent all-controls overlay; remove any found.
42. AX4.3: grep for recapture cutscenes without a demonstrated cause; add the cause check.
43. AX4.6: each existing branch (elevator, derby, drains) resumes from the right stage after save/load; test.
44. AX5.2: external camera failure cases — cramped space, darkness, injury, interference — each a test.
45. AX1.5: time a scripted deliberate intake pass and a preset pass; record both.
46. Extend `first_run_walk_test.gd` through the biometric door once it exists.

## D — Walkthrough 2 bugs and asks still open

47. Carry icons: give each carried item class its own icon in the Brain Index hub.
48. Breach tool melee: the ram strikes through the shared combat path.
49. Intake: use the blank space; enlarge its text.
50. Intake: fix the name / tank line so it reads.
51. Lab: cables as bundled, branching wiring instead of one long tube (procedural).
52. Lab: more CCTV cameras along corridors.
53. Lab: doors you can open, not set dressing.
54. Lab: fix the floor light glitch.
55. Lab: overall lighting pass on the decant room and Lower Works; capture before/after.
56. Handheld: carry gets its own key, not a phone page.
57. Handheld: kinship web moves into the Brain Index hub; T freed.
58. Handheld: I and U open things that say what they are (titles on open).
59. Derby: kill cam as a slow-motion view of the actual body being gored, not the X-ray card.
60. Derby: bring the new HUD, block tracking and strike FX into the derby scene.

## E — The remaster queue

61. Animated intake pages: tab icons for ink, blood, metal.
62. Parts that swing out on gears between intake tabs.
63. Receipt paper: bounties print on their own stock.
64. …contracts on their own stock.
65. …job posters as flyer stock.
66. …business cards on card stock.
67. Posters on walls with tear-off tabs; a tab goes to Carry.
68. Cards from people land in Carry and on the Wire.
69. Block tracking on enemy awareness for enemies that have not yet seen you (unaware state).
70. Depth mode → photo mode: F10 works while the depth lens is up.
71. Photos land in the Brain Index album.
72. Photo evidence path: a photo can be attached to a contract (plumbing only; whether it counts stays Greg's).
73. Check the five look branches (hornee, kinship, prints, styles, cables): list what is left on each in this file. No merging.

## F — Combat, from the briefs and Greg's 24 Sep direction

74. Brief 2: combat keys become InputMap actions (strike, heavy, guard, dodge, interact, device), one per commit.
75. Pause menu rebinds them; persisted.
76. Field HUD key strip reads labels from InputMap.
77. Proof: rebind DODGE, capture strip before/after, dodge fires on new key.
78. O10.7: guard has a direction and can be flanked; test.
79. O10.6: a miss costs footing; test.
80. O10.8: disarm both ways; test.
81. O10.10: fatigue degrades guard instead of a bar.
82. O10.4: hitstop local to the two bodies; test the bystander keeps moving.
83. O10.5: gore/chunks on the exchange's clock.
84. Style switching live: martial / sword / gun / stealth selectable, stub trees.
85. Blood XP per style and per weapon from use and kills; saved.
86. Overkill destroys organs/cybernetics; clean kills keep them; test both.

## G — Performance (X) and vitals

87. X10.6: every SubViewport renders only when visible; audit and fix.
88. X10.5: gore, brass and debris capped and recycled; test the cap.
89. X10.4: static registries swept at scene change; test for leaks across two changes.
90. X10.11: add the perf probe as an optional suite step with a budget assert.
91. X1.3: confirm the 238 MB unreferenced plugin is unused; remove it from the export.
92. AX5.4: measure the facility route (vat → elevator) against 60 FPS; record.
93. Vat room: re-check the 4.8 ms after tank changes.

## H — Body and bag (N)

94. N4.2: equipping a weapon puts it in the hub body's hand.
95. N4.4: one-line description per carried item, in the game's voice.
96. N4.5: wounds and prosthetics show on the hub body.
97. N3.4: grown cybernetics and missing limbs show on the intake body.
98. N10.4: a severed limb takes its hardware with it; test.

## I — Front door and records

99. Write BONES.md: the ledger's spine, laws and dust table as text.
100. START_HERE: point to BONES.md; strip stale lines.
101. Update the ledger's counts (dust wired, AX ticks) from this run.
102. CHANGELOG entry for the night's work.
103. Examiner sheet: prepare it for Greg's sign-off (collect captures into one folder).
104. Record one Movie Maker MP4 of the first-run walk for Greg to watch.
105. Core suite + first-run walk green at the end; results at the bottom of this file.

## Blocked (fill in during the run)

- 9-13 (Hunt to 6.25 ms): hidden viewers fixed (8d15b724), frame 14.4 -> ~14 ms.
  The Hunt's own calls are 2.6 ms; the rest of physics is the engine, and
  geometry is already fog-culled and batched. Getting to 6.25 ms is a
  restructure of the Hunt, not a night's item.
- 14 RunLifecycle: it is the permanent-death recorder held for the death
  fiction. Retiring or renaming it answers "what happens when you die".
- 15-16 OpeningDeath: the facility already dies into VatRebirth ("death is
  rebirth in the claimant's vat", support_unit._die). OpeningDeath's suite
  calls that kind of explanation a counterfeit. Which one stands is the
  death question.
- 22 CabScreens: deliberately removed from the derby; derby_clean_hud_capture
  asserts it stays gone. Not dust.
- 38 severed hand at the reader: the barrier accepts it, but the facility
  hands over no blade yet (FacilityGuardPost notes). Where the first blade
  comes from is a level decision.
- 25 AudioReactive: what the radio should move in the Hunt (the trip dials
  are owned by altered perception every frame) is a look decision.

## Results (fill in at the end)

- 1-3 tank body: 7e167bda
- 4-7 pad prompts: 17e81b65
- 8, 87 hidden viewers: 8d15b724
- 18 algiz sight in the Gore Sandbox: 6518f624
- 74-77 combat keys rebindable: 6fa54756
- 31 AX duplicates removed from CHECKLIST: this commit
- 34-37, 39-40 already done before tonight (ledger was stale): FacilityGuardPost
  places Hollis, the reader and the door in the Support Unit and the arcade;
  facility_guard_post_test covers coerced, downed and dragged-hand access and
  the three-round BREACH NINE; BiometricBarrier ignores life state, so a
  corpse opens it (biometric_barrier_test).
- 73 look branches (all "WIP rescue", none merged, none finished):
  look-cables 4 commits (lab wiring: item 51), look-kinship 3 (kinship as a
  hub tab: 57), look-prints 3 (receipt posters and cards: 63-68),
  look-styles 4 (switchable styles, blood growth, loot kept: 84-86),
  look-hornee 3 (Hornee plush art), look-intake 3, look-index 1,
  qoder/look-tuning 2 (surface lighting). Those items are left to their
  branches rather than built twice here.
- Friends' demo checklist, the load-in (the live backlog: 92/100 done before
  tonight): Greg's four flashes + whispers, shorter and clearer ticked: 5740c77a
- 47, 56, 58 already done before tonight: hub draws an icon per kind; Tab is
  the carry view (Greg 26 Sep); F1 card names I (inspect) and U (cases).
- 19 WofLockup: already used -- store_assets_capture draws every Steam/itch
  plate with it (the ledger's scan skipped tests/). No change.
