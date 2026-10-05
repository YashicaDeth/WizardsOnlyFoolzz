# greg-19 notes (2026-09-30 00:14 → 2026-10-04 01:05)

Chunk is 47 KB / 834 lines, not 105 KB. Read every line. Most of it is agent output that Greg pasted from one agent to the other (Claude ↔ Codex relay). Only his own typed lines are quoted below. The Profit Foundry heartbeats, the ChatGPT conversation about a cmd.exe pop-up, and the business-workspace remarks are skipped: they are about other projects.

## 1. REQUIREMENTS
- 2026-09-30 00:19 — Turn the psychophrenia sandbox into a test bed for both 1st- and 3rd-person combat: "making the pscyophrenia sandbox into somewhere were we can test combat for third person and first person". The reason: the sword "breaks in third person".
- 2026-09-30 00:56 — Begin on the combat and fighting themselves, then launch the playtest once Codex finishes: "can we start working on the actual combat and fighting itself right now launch the playtest when codex is ready".
- 2026-09-30 01:29 — The sandbox must run cleanly: "the performance of the sczhiphrenia sandbox is terrible make sure its clean".
- 2026-09-30 02:47 — Real 1v1 fights in the sandbox, and bodies must not overlap: "you should be able to fight 1v1 and its not just they all rush to kill you and merge into eachother".
- 2026-09-30 03:23 (long voice-style message). Sub-requirements:
  - Third person should play like a Soulslike: "making the third person kind of like a Souls-like and omnidirectional, but you're like locked in place as a character."
  - Support a PS4 controller over USB, mapped to Dark Souls / Bloodborne controls: "map it to Dark Souls controls for the like fighting and the big swings… or Bloodborne".
  - Shift runs in third person. He thinks Space is dodge and jump may not be needed: "if you can't jump, but you can dodge by pressing space". He was unsure whether dodge is Tab or Space.
  - Stances differ per weapon, more weapons get added, the sandbox is the test bed, then everything moves into the full game: "the stances are different and we can start making like different weapons".
  - Quality bar: "as much like how Dark Souls 1 2 3 Bloodborne… except that make it way less buggy, super clean".
  - Ragdolls: "we want the ragdolls to be funny, but also, like, have weight… deaths… very realistic."
  - Anatomy and gore at "extreme accuracy", with fights and disarming. He has a reference developer's ragdoll video to send (never sent: "can't log into Instagram").
  - Long-term escalation: cybernetics, "like Elden Ring modded fighting… dueling in midair… double jumps"; massive attacks that send a target flying into a ragdoll with a big wound, "not heaps far… but we want to make it like an anime type fight."
- 2026-09-30 05:16 — Sword variety made with Higgsfield: "use higgsfield please to generate working sword models". Style: "if dark souls and cyberpunk had a baby… not ttoo heavy on cyberpunk… mad max esq apocyalpyse alive".
- 2026-10-04 00:59 — A way to read every agent's chats about the game: "setup a way to use and read all chats from all different agents that have been working on wizonlyfoolz". Use the remaining capacity and "my 836 higgsields credits to finish the demo as best a possible".

## 2. DISLIKES / REJECTIONS
- 2026-09-30 00:19 — The sword breaks in third person: "there is decent sword combat but it breaks in third person".
- 2026-09-30 01:29 — Sandbox performance: "the performance of the sczhiphrenia sandbox is terrible".
- 2026-09-30 01:52 — The bisect was taking too long: "bisect sandbox cpu is taking a while should be taking so long" (he means "shouldn't").
- 2026-09-30 02:47 — Enemies mob you and clip into each other: "they all rush to kill you and merge into eachother".
- 2026-09-30 03:23 — He doesn't want the bugs of the Souls games: "make it way less buggy, super clean". He doesn't want knockback too far: "not heaps far or anything, like a realistic".
- 2026-09-30 01:16 (to Codex) — Ignore the market-radar reminder during game work: "just ignore this reminder please and keep wroking on the game".

## 3. DECISIONS
- 2026-09-30 00:37 — "go". This accepts Claude's proposal:
  - First person keeps mouse-drag swings.
  - Third person uses button attacks aimed by movement or lock-on.
  - Space = roll, LMB tap = light, LMB hold = heavy, RMB = guard, Z = lock-on.
  - A Souls roll with i-frames and a stamina cost.
  - Split: Codex builds roll and moveset, Claude builds the 3rd-person body, camera and wiring.
  - He answered "go" to both questions (control changes? 1st person buttons too?) without changing anything, so the proposal stands as written.
- 2026-09-30 03:23 — Model the controls on Dark Souls / Bloodborne and test on a PS4 pad. Shift = run in 3rd person. Space = dodge, possibly with no jump. He was tentative about this, so it is not firm.
- 2026-09-30 03:23 — Ragdolls should be funny but weighty, and realistic. Knockback is anime-flavoured but stays short.
- 2026-09-30 05:16 — Weapon art: Dark Souls × light cyberpunk × Mad Max apocalypse, generated with Higgsfield.
- 2026-09-30 05:03 (prompt to Codex, Greg-sent) — Codex runs DESIGN/COMBAT_LOOP_GOAL.md continuously: "Stop only when I say". At most one windowed Godot on the right monitor for playtests. Decisions that are his go in WORKING_NOW.md.
- 2026-10-04 01:02 — Capacity deadline: "2 chat accounts… buisness workspaces limits run out on oct 11th to like 9th". Spend the capacity before then.
- No answer found in this chunk: whether downed-but-alive bodies should ragdoll (Claude raised it at 02:47 as his call).

## 4. STILL OPEN?
- **3rd-person sandbox body, camera and lock-on — BUILT.** tests/third_person_sandbox_test.gd; systems/souls_roll.gd and systems/sword_moveset.gd (Codex 7bfea594).
- **Knockback and corpse ragdoll — BUILT.** systems/knockback.gd and systems/ragdoll_body.gd with tests (Codex 6e785fcd).
- **Ragdoll corpse sliding about 6 m — PARTLY.** The stances brief took it over ("ragdoll container still inherits a translated parent"). On 2026-09-30 03:33 Claude said "corpses still slide too far". I did not confirm a final fix. zz_ragdoll_probe.gd is still in tests/.
- **Duel 1v1 / pack and no merging — BUILT.** tests/sandbox_duel_test.gd. J toggles the mode (commit 9cc8a831).
- **Sandbox performance / 7 fps — PARTLY.**
  - PartViewer render gating is in systems/pulmonary_diagnostic.gd:103.
  - tests/psy_lab_perf.gd and tests/psy_lab_soak.gd exist.
  - Session 284daf93 06:36: "The 7 fps stutter: mostly fixed" (it was a hit freeze of 150 ms–1.4 s).
  - Prompts to keep looping on it were still being sent at 09:30.
- **PS4 / Dark Souls–Bloodborne pad mapping — BUILT.** systems/souls_pad.gd (R1 light, R2 charged heavy, L1 guard, L2 parry, Circle roll / hold-to-sprint) and systems/pad_bridge.gd, both with tests. Never verified with Greg's real pad, by me or in the logs I read.
- **Stances and different weapons — PARTLY.** systems/combat_stance.gd (procedural poses) and tests/combat_stance_test.gd. "shiv"/"fists" are in hunter_arsenal.gd and held_gear.gd. One-hand / two-hand tables came from Codex's stances brief. Whether all of it reached the full game route is unverified.
- **Higgsfield swords — BUILT.**
  - Four GLBs in art/generated/items: chassis_greatsword, leafspring_longsword, sawback_sabre, railspike_estoc.
  - Listed in systems/generated_model.gd:96 (SWORDS). hunter_appearance.gd:54 arms bodies with them, and third_person_sandbox_test checks it.
- **Midair duels, double jumps, cybernetic escalation, launch attacks — NOT FOUND.** No double_jump/midair/aerial in game/*.gd. He framed it as a later goal.
- **Disarming — NOT CHECKED in depth.** Mentioned in passing. Not grepped.
- **Reference ragdoll video — never sent** (Instagram login).
- **Read-all-agent-chats tool — BUILT.** P:/GameDev/AgentHub/agenthub.py (search/sessions/show) and data/greg_said.md. This task uses them.
- **Using up Higgsfield credits to finish the demo — ongoing.** I can't verify it from the repo. DESIGN/HIGGSFIELD_DEMO_PROMPTS.md exists.

## 5. WORLD / LORE / NAMES (his spelling)
- "pscyophrenia sandbox" / "sczhiphrenia sandbox" — his spellings of the psychophrenia sandbox (the psy lab).
- "post facility escape game" — his name for the main route (the facility escape).
- "wizonlyfoolz" (2026-10-04) — his short name for the game. The ChatGPT context also calls it WizardsOnlyFoolz/Starnet.
- "StarNet", "orca", "powershell" — tools he named for reading the chats.
- Weapon aesthetic: "dark souls and cyberpunk had a baby", "mad max esq apocyalpyse".
- Tone references: Dark Souls 1/2/3, Bloodborne, Elden Ring (modded), "anime type fight".
- Sword names were coined by agents, not by him: chassis greatsword, leaf-spring longsword, sawback sabre, rail-spike estoc.

## 6. STYLE OF WORKING
- He relays between agents by hand, pasting one agent's report into the other's chat ("this is what claudes doing", "codex did this", "i forgot ot prompt you").
- He wants agents to coordinate without waiting on him: "launch the playtest when codex is ready" (2026-09-30 00:56).
- His prompts to Codex always say "Headless only — no Godot windows on my screen" (2026-09-30 00:35, 01:30, 03:57). At 05:03 that loosened to at most one windowed Godot on the right monitor for playtests. Claude's memory note said "self-playtesting is now allowed". That note is agent text, not his words.
- He wants combat to be clean and of high quality, not just working: "way less buggy, super clean" (03:23).
- He doesn't want slow investigations: "should be taking so long" (01:52).
- Use as much capacity as possible before it expires: "use as much tokens as we can and use up… my 836 higgsields credits" (2026-10-04). The ChatGPT text he pasted adds a caveat against junk output, but those are not his words.
- He wants continuous loops that stop only on his word, with his decisions listed in WORKING_NOW.md (05:03).

## 7. CONTRADICTIONS
- **Dodge key.** On 00:37 he approved Space = roll. On 03:23 he asked whether dodge is "tab or space", and suggested Space dodge with no jump. Compatible, but still unsettled. The pad build uses Circle for roll.
- **Jump.**
  - 03:23 early: "if you can't jump" in third person, i.e. no jump.
  - Same message, later: "dueling in midair… double jumps".
  - Newest-wins doesn't settle it, because both are in one message. Read it as no jump now, aerial combat as a later escalation.
- **Knockback.** "sends a player flying… go flying" against "not heaps far… realistic". He wants a short, weighty, anime-flavoured launch.
- **Ragdolls.** "funny" against "very realistic". He wants both: comedic physics with real weight.
- **Windows on screen.** Headless-only (00:35–03:57) against one right-monitor window for playtests (05:03). The newer one wins: one window on the right monitor is allowed for playtests.
