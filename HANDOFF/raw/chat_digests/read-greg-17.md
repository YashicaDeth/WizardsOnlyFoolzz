# read-greg-17 — notes (chunk covers 2026-09-28 07:21 → 14:27)

Chunk is ~90% tooling: StarNet login/429 troubleshooting (voice transcripts), Profit Foundry heartbeats (other project, skipped), Orca removal, and pasted agent output (Claude lighting/parry-spark logs, a Codex-written Claude prompt). Greg's own game content is thin. Pasted agent text below is marked (agent) and is NOT his requirement.

## 1. REQUIREMENTS
- 2026-09-28 14:15 — Priority is the first 30 minutes, made great with external tools: "let's just get back to making this first thirty minutes of the game amazing using touch designer comfy UI and other things."
- 2026-09-28 14:15 — Wants a playable build to playtest now: "probably should let me play the game and we can play test it right now."
- 2026-09-28 09:22 — Wants a dedicated workspace ("room") for the game and the ledger, and to make the game official: "build another room specifically for working on the game and the ash to bonesa dust to bones ledger and making the game officak". (Later superseded for StarNet, see §3/§7.)
- 2026-09-28 13:53 — Codex should merge the newest changes and ask him questions he can answer by voice: "get codex to dual fix the game adding all the newest changes asking me questions then i can use voice mode on chatgpt".
- Context only (agent, 14:08 Codex prompt that Greg pasted to Claude, so he endorsed it as a brief): keep Wetwire reachable by clicking the head or pressing B, gothic cabinet + house typeface; preserve sword arm, contact cut planes, directional guard/parry, 1P/3P commitment rules, correct calibres, sniper X-ray kill flow; lighting pass = harsh green-white ceiling pools, dark between pools, tension flicker, ≤1/3 permanent lamp failures, red rotating strobes + one klaxon at vat breach, Support Unit alarm drives tension. Next priorities: atmosphere, parry spark, room readability/silhouettes, environmental destruction, sound/animation feedback.

## 2. DISLIKES / REJECTIONS
- 2026-09-28 10:04 — Orca: "orca is a waste of tokens"; "lets unmerge all our agents from orca and then run starnet no orca".
- 2026-09-28 14:06 — "cut Orca. No more Orca. We don't need to use Orca, bro." Repeated 14:22: "disregard orca and grind this project".
- 2026-09-28 10:10 — Idle/useless agents: "MANAGE ALL THE AGENTS GET RID OF DSUMB ONES". (Pasted ChatGPT context: "lots of rouge agents that arent being prompted and arent really doing much".)
- 2026-09-28 14:15 — StarNet if it doesn't speed things up: "if you know Starnet won't work, and it won't make any of the game creation faster ... just ignore Starnet".
- 2026-09-28 08:33 — StarNet login loop: "OAuth polling keeps failing, bro ... This is so dumb" (tooling, not game).

## 3. DECISIONS
- 2026-09-28 08:40 — Split StarNet into two fenced agents: "Run one isolated engineer ... Wizards Only, lock it to that repo only, then ... a second isolated engineer for Foundry live ... no peeking, no edits across projects." Budget ~$12 of $20 to the game agent.
- 2026-09-28 08:45 — StarNet model: Qwen3 Coder Next (accepted agent suggestion, "Yeah").
- 2026-09-28 10:42 — StarNet setup: add P:\GameDev\wof-latest as root; "Rules for every brief" from DESIGN/STARNET_BRIEFS_2026-09-28.md as shared instructions; briefs 1–6 to six agents, brief 7 (Foundry) spec/listing only; "Each agent pushes its own starnet/<lane> branch and does not merge. Pause the factory-recon team if credits drop under $5."
- 2026-09-28 14:15 — Superseding: StarNet "was just a pipe dream idea ... Those can't work right now, probably" → drop it unless it makes building faster.
- 2026-09-28 13:36 — On lighting-session recovery choice (resume cloud session vs rebuild): "Try again".
- Open question raised by agent in this chunk (near-black vs faint silhouette) — answered later 2026-09-29: faint readable cold-rim silhouette (DESIGN.md:1578-1584).

## 4. STILL OPEN?
- Lighting pass (RoomLights: pools, flicker, lamp deaths, breach strobes, klaxon, Support Unit alarm tension) — BUILT: game/systems/room_lights.gd, wired in vat_chamber.gd, service_arcade.gd, support_unit.gd, doctor_vehicle_bay.gd; tests/room_lights_test.gd (launch-latest). Brightness/strobe tuning visually unverified by me.
- Parry spark (warm core, embers, inside 1P view) — BUILT: game/systems/parry_spark.gd, used 3× in bone_yard_hunt.gd; tests/parry_spark_test.gd.
- Faint enemy silhouette in dark rooms — DECIDED (DESIGN.md:1581, 29 Sep); implementation not checked here → PARTLY/unknown (grep shows "silhouette" in service_arcade.gd, bone_yard_hunt.gd; not confirmed it's the cold rim).
- Wetwire via head click / B — BUILT (KEY_B in bone_yard_hunt.gd:1805, systems/field_inventory.gd, systems/case_menu.gd; brain_index.gd).
- TouchDesigner / ComfyUI used for the first 30 min — PARTLY: TouchDesigner bridge mentioned in session 01a0e110 (2026-09-30, "psychophrenia layer ... TouchDesigner bridge"); ComfyUI use not verified.
- StarNet game/ledger "rooms" + briefs 1–7 — PARTLY/abandoned: DESIGN/STARNET_BRIEFS_2026-09-28.md exists; DESIGN.md:1514/1530 shows StarNet moved to sound pass then "out of usage". Greg on 2026-10-04 (session 1f984e04) again lists "powershell or orca or starnet whatever is best".
- Playtestable build now — not checkable from this chunk; launch-latest exists.
- Dust to Bones ledger "official" — NOT FOUND as a game requirement in repo (separate project/ledger; not searched further).

## 5. WORLD / LORE / NAMES (his spelling)
- "Wizards Only Fools" / "wizonlyfoolz" / "WizardsOnlyFoolz" / "wiz only fools"; repo also "Allusions Too Grandeur" / "allusionstoograndeur".
- "ash to bones" corrected to "dust to bones ledger" (09:22) — branch claude/dust-to-bones-look.
- WIZ (lead agent), Onyx (StarNet router agent), Astra (his name for the Codex voice agent, 14:15), "my demon", "my sungod".
- Rooms named in pasted handoff (agent): vat chamber, Service Arcade, Support Unit, vehicle bay, the Hunt; Wetwire / Brain Index.
- Non-game: Profit Foundry / Foundry live / factory-recon, StarNet, Orca.

## 6. STYLE OF WORKING
- Max effort, burn tokens: "BYPASS AND ULTRACODE ON ... YOU CAN GO SICKO MODE WITH TOKENS" (10:13); "full token demonic mode" (14:22); "KEEP WORKING EXTRA HARD ASK QUESTIONS IF YOU NEE d" (14:22).
- Questions as boxes, otherwise just go: "ASK QUESTIONS IF YOU NEED QUESTION BOXES IF NOT GO DEMON TIME" (14:22); wants "around 10 plus questions" from Codex (14:15).
- Strict lanes: one agent per project, "no peeking, no edits across projects" (08:40); agents push own branch, don't merge (10:42).
- Kill idle/rogue agents; every agent needs a quest: "GET QUESTS INPLCACE ECT OF WORKING HARD" (10:10).
- Tools only if they make game creation faster (StarNet, Orca judged waste) (10:04, 14:15).
- Wants Codex and Claude both progressing in parallel: "Claude's doing shit but you need to be making crazy progress on the game" (14:15).
- Credit-aware: pause teams under $5 (10:42); Codex credits ran out 14:27.
- Endorsed (agent prompt he pasted): one coherent change at a time, test, look, commit; ask one creative question at a time.

## 7. CONTRADICTIONS
- StarNet: 08:40–10:42 invests in StarNet lanes/briefs → 14:15 "pipe dream ... just ignore Starnet". Newest in chunk wins: drop StarNet unless it speeds building. (Later 2026-10-04 he reopens "powershell or orca or starnet whatever is best".)
- Orca: 10:04 "run starnet no orca"/"waste of tokens" and 14:06 "No more Orca" are consistent inside the chunk; but 2026-10-04 (outside chunk) lists orca again as an option — newest wins there.
- Questions: "ask me around 10 plus questions" (14:15) vs "ASK QUESTIONS IF YOU NEED ... IF NOT GO" (14:22) and endorsed "one question at a time". Newest: ask only when needed, via boxes.
- Ledger name: "ash to bones" self-corrected to "dust to bones" in the same line.
