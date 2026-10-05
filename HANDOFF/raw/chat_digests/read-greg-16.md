# read-greg-16 — notes (chunk covers 2026-09-27 05:33 → 2026-09-28 07:20)

Read in full (1404 lines). Roughly 90% of it is not about the game: NINOMON/ULTRON "Profit Foundry" (Fiverr, Etsy/Printify, eBay, Redbubble, Katoomba website pitches), about 25 repeated `profit-foundry-market-radar` heartbeat prompts (automation text, not Greg), and a TouchDesigner/After Effects music-video request. Those are skipped except where they touch the game. The game material is listed below.

Note: the 2026-09-28 04:33 Lane B brief (codex 01a0a9a2) is a goal prompt Greg pasted. It refers to "Greg's textures" in the third person, so an agent probably drafted it. Greg sent it as the order, so its items are listed as requirements, but the quotes there come from the brief, not from Greg typing.

## 1. REQUIREMENTS
- 2026-09-28 (Lane B brief): the vat panel is "one big 3D vat with you inside it." "Real liquid: blood, water and fluids that move, lit and refracting, at full frame rate."
- 2026-09-28 (brief): torture inside the vat: "wires in your head, the implant, a tube in your mouth, and zaps that flash your organs X-ray style."
- 2026-09-28 (brief): "customization as deep as Bloodborne: many face shape controls, each moving only its own feature."
- 2026-09-28 (brief): skin and clothing on Greg's textures; "genitalia (none, asexual, chosen with size, and the existing blur); your blood; and cybernetics."
- 2026-09-28 (brief): "Every choice visibly changes the body in the vat."
- 2026-09-28 (brief): proof for each slice is a capture, one new test, `--core` green, and the vat panel's frame time at 1080p. "Human-made assets only, credited in CREDITS.md."
- 2026-09-27 22:54 (voice): break the game into 15-minute blocks of three 5-minute parts (starting cutscene, main menus, gameplay), then the next 15. "what's the checklist? What's been done? … what's in final, what's in pre?"
- 2026-09-28 04:38: "give me a progress checklist of the first 30 minutes or just overall game since september 12"
- 2026-09-28 04:45: hand it to Codex to "find all the loose threads throughout the entire game so far"
- 2026-09-28 07:17 (voice, tooling): StarNet should run the foundry and "connect Wizards Only Foolz" as a separate area of one "massive... virtual factory". Codex proposed separate foundry and WOF wings under Onyx; Greg added a researcher, engineer, marketer and QA tester.

## 2. DISLIKES / REJECTIONS
- 2026-09-28 (brief): "No stacked rings." (Aimed at the old vat look made of torus rings.)
- 2026-09-27 22:54: running out of usage: "make sure you're not wasting token usage because we've been running out more recently"
- No other game dislikes appear in this chunk.

## 3. DECISIONS
- 2026-09-27 22:54: art comes last. "don't include the art because the art will be a final pass". Order: gameplay features nearly complete, then "an art pass, redo art pass, game pass, then it's finished."
- 2026-09-28 (brief): use the existing systems and do not rebuild them: vat_body_preview, face_model, body_forms, character_sheet, anatomy_presentation, BaselineHuman with organs, and the censor glitch. Lane B owns only its own files; vat_intake.gd belongs to Lane A, and hooks are requested on the board as "NEED B -> A".
- 2026-09-28 04:31: Codex does the reassessment ("do you think it's better to do with Codex to just reassess").
- (Non-game) 2026-09-27: websites are paid on launch with no deposit. Greg said "KEEP GRINDING MOST HANDS OFF APPROACH FOR ME" and the agent picked that default.

## 4. STILL OPEN?
Repo checked read-only at P:/GameDev/worktrees/launch-latest.
- One 3D vat with real refracting liquid, no stacked rings: **PARTLY.** `game/systems/vat_body_preview.gd:78-150` adds glass, a medium, a tube and BloodRim light, and keeps "collar and base only" rings (line 120). No refraction shader turned up in the vat files, and no 1080p frame-time number was found.
- Tube in the mouth: **BUILT.** `vat_body_preview.gd:134` ("a tube in your mouth that's visible too"); `vat_intake.gd:10, 811, 1396` ("TUBE IN: YOU CANNOT SPEAK").
- Wires in the head, the implant, X-ray organ zaps in the vat: **PARTLY / unverified.** `vat_horror.gd:72` has "wired"/"cord" phases. I did not confirm the X-ray zap inside the vat panel.
- "Many face shape controls": **PARTLY.** `face_model.gd:36` has 7 axes (brow, jaw, cheek, eyes, nose, mouth, grown_wrong), and `tests/face_model_test.gd` exists. That is well short of Bloodborne depth.
- Genitalia none/asexual/size + blur: **PARTLY.** `character_sheet.gd:171` has ANATOMY_SEX_FILED and `body_forms.gd` has nudity plus censor glitch. No size control was found (grep "genital" returned nothing).
- Cybernetics as a vat choice: **PARTLY.** It exists as a character-sheet field (`character_sheet.gd:9, 593`). I did not confirm it changes the vat body.
- CREDITS.md: **NOT FOUND** at the repo root or under game/.
- First-30 / since-Sept-12 progress checklist: **BUILT.** `DESIGN/CHECKLIST_2026-09-26.md` and `DESIGN/CHECKLIST_FRIENDS_DEMO_2026-09-28.md`; session claude 1f984e04 (2026-09-28 18:10, "Greg's to-do list, first 30 minutes").
- Loose-thread sweep: **BUILT.** `DESIGN/LOOSE_THREAD_TRIAGE_2026-09-28.md`.
- StarNet wing for WOF: **BUILT (tooling).** `DESIGN/STARNET_BRIEFS_2026-09-28.md`; `DESIGN.md:1514, 1530` (StarNet moved to the sound pass, then out of usage).

## 5. WORLD / LORE / NAMES (his spelling)
- "Wizards Only Foolz" (2026-09-28 07:17, voice transcript; the brief writes "Wizards Only Fools"); repo YashicaDeth/WizardsOnlyFoolzz.
- Lane A = intake screen (vat_intake.gd); Lane B = vat panel and customization (from the brief, per DESIGN/SWARM.md).
- Tooling names, not game lore: StarNet ("my Orca"), Onyx, Scout (researcher), ULTRON, NINOMON, Astra, Foundry Boot Deck. Keep CELLOUTZ separate: "SEPERATE TO CELLOUTZ NOT SUPPOSED TO INCPORAPRATE MY OWN ART" (2026-09-27, said about the money project, not the game).
- Aesthetic reference for a separate music-video job, not the game: "Yabujin core, crazy aesthetic" (2026-09-27 23:02).

## 6. STYLE OF WORKING
- 2026-09-27 22:54: "you have to use Ponytail… and agent skills and game dev skills", "to make sure you're not wasting token usage".
- 2026-09-27 22:54: wants checklists "in the most concise way".
- 2026-09-27 05:37: "tell me everything super quick concise consitently".
- 2026-09-27 07:46 / 07:52: hands-off, run until usage is spent: "MOST HANDS OFF APPROACH FOR ME"; "gogogo… for the rest of your ussage".
- 2026-09-28 06:01: when an agent pushes back: "just do it the way I wanna do it". In that case the agents still refused to copy other sellers' designs (money project).
- 2026-09-28 04:31: uses one agent to reassess and then passes the result to another (Claude → Codex).
- 2026-09-27 07:36: "open the ga,me for me also". He expects agents to launch the game for him; for headless agents this conflicts with the current no-window rule.

## 7. CONTRADICTIONS
- 2026-09-27: he wants token efficiency ("not wasting token usage") but also tells agents to burn the rest of their usage ("for the rest of your ussage") and to run "50+ agents" (the latter on the money project).
- 2026-09-27: art is a final pass to be excluded from checklists, yet the 2026-09-28 Lane B brief demands vat liquid and refraction quality and Greg's textures now. Partial resolution: the vat brief is about systems and visibility of choices, not final art.
- 2026-09-28 07:18: agent count. Codex advised starting with 3 (Onyx, researcher, engineer); Greg then added a marketer and a QA tester, and earlier asked for 50+. His newest word was to add QA.
