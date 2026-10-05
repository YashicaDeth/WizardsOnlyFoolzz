# greg-18 notes (2026-09-28 14:27 → 2026-09-29 11:09)

Source: AgentHub/data/chunks/greg-18.md, read in full (1356 lines). Most of the chunk is pasted agent output and hourly "profit-foundry" heartbeats (CellOutz business, skipped). Greg's own typed words are few. The main one is the voice-mode playtest monologue (09-28 14:34, pasted 4 times).
Repo checks were run read-only against P:/GameDev/worktrees/launch-latest/game.

## 1. REQUIREMENTS
- 09-28 14:27: get the 30-minute demo playable now. "get shit done for goshsake on this 30 min demo i want to be abler to play it already"
- 09-28 14:34 (playtest): the vat-room wires must become real wires. "Rip all the wires out, which still need to be turned into wires"
- 09-28 14:34: the player should not reach the examiner this early, and access should be earned. "you shouldn't really be able to get to, like, the doctor's examiner so quick"
- 09-28 14:34: killing the examiner should give staff access. "I should have staff access or whatever"
- 09-28 14:34: freed subjects should do more than repeat lines. He seems to want to be able to kill them. "it's not like I can kill them, because they just say Keep walking"
- 09-28 16:12: the opening is a facility breakout taught through tutorial steps. "intitally we should be trying to break out the facility and we have to take proper tutorial steps"
- 09-28 17:20: wants a checklist of what is done and not done for the first 30 minutes ("gothic face visible, blah blah, blah nerve rig").
- 09-29 00:01: Higgsfield should make 3D models too, not just images. "not just image generatyion but 3d models ect"
- 09-29 00:42: generated or rigged models must keep top-level gore and X-ray. "still have top gore and anatomy sniper elite four sniper elite five x-ray internal organs"
- 09-29 00:42: re-render and replace models with better ones, without breaking code. "we want to re-render everything replace the models with better stuff"
- 09-29 00:43: an in-game art gallery in the Brain Index, with the Hornee plush in the tab/inventory. "we want an art gallery in-game ... posters and like business cards ... click on and add"
- 09-29 00:44: gallery design: posters with tear-off tabs, and clicking a frame opens it large. Contents are posters, business cards and his art. "tear off tab and then clicking a frame opens a large yep"
- 09-29 06:35: launch the build with every agent's progress from that day merged. "launch the playable game with the most updated additions from all of todays progress"

## 2. DISLIKES / REJECTIONS
- 09-28 14:34: the transition is still bad and yellow. "we've got that shitty transition with the yellow whatever ... haven't actually fixed the transition screens"
- 09-28 14:34: the opening broadcast line is shown twice. "Hundreds of years in the perpetual... So it says it twice."
- 09-28 14:34: he dislikes the bubbles. "I don't really like the bubbles, but I love this so far."
- 09-28 14:34: there is a green square on the floor around the vat. "a green box around the vat on the ground, like a green square, but it's weird"
- 09-28 14:34: he was sent back to the start with no explanation. "I got sent back to the start. This is weird so far."
- 09-28 14:34: the hatch reads unclear. "I don't know what this is, like when you open the hatch."
- 09-29 00:42: the doctor model is "pretty like wacky".
- 09-29 00:42: no AI-generated clutter that breaks existing code. "don't make it too crazy ai ai, AI shit they're just like fucks up our whole code"
- 09-29 00:44: Claude and Codex should not be split into separate worktrees and branches. "you're constantly making me split bullshit off from each other"
- 09-29 06:53: do not open the game in the main window. "stop opening the game stuff in the main window"
- 09-28 14:27: Astra used up his usage limit before doing anything. "usage limit as been used up by astra before any words were even said"
- Praise, kept as a do-not-regress note (09-28 14:34): the spooky audio, the doctor's glasses, the wizard eyes, the depth scan / hold E rip-out, the glass smash and the "Get revenge" beat. "This is amazing so far."

## 3. DECISIONS
- 09-28 14:27: enemies in dark rooms keep a faint, readable silhouette (cold rim) instead of vanishing into near-black. Pasted choice: "Faint silhouette (Recommended)".
- 09-28 14:27: Codex was moved from Astra to Terra ("so im putting you on terra").
- 09-28 15:34 → 15:54: restart after the 5-agent limit blow-out. He did not pick an option explicitly, but replied "keep going ask hella questgions if needed". The agent continued one lane at a time (front door first).
- 09-28 16:12: the opening goal is to break out of the facility through tutorial steps. The pasted agent plan was one lesson per room (Growing Floor teaches the fight, Arcade teaches K/J sight and stashes, Lower Works teaches stealth).
- 09-28 17:30 (pasted): he will playtest once the checklist items are done.
- 09-29 00:01: use Higgsfield for 3D models, rigging and animation as well as images.
- 09-29 00:44: Claude and Codex share one folder and branch. The agent then set up WORKING_NOW.md on claude/playtest-build.
- 09-29 00:44: gallery contents are "posters and tabs, business cards, my art ... Your art my art collections".
- 09-29 04:23: ignore the Higgsfield NSFW block on vat bodies for now. "with the nsfw lets just ignore stuff like that for the time being"
- 09-29 05:15 (his Codex wrap-up brief, typed or relayed by him): commit only verified work; otherwise save a patch to P:/GameDev/Temp. Do not start Brief B. Hunt probe was 11.54 ms against a 6.25 ms target.
- 09-29 05:26 (brief he relayed): place generated models in this order: Black Mirror, restraint, CCTV/lamp/drill, then the examiner as a skin on BaselineHuman zones. After that, rebuild Hollis, the numbered guard and the player from his turnaround sheets.
- Unanswered in this chunk: Codex asked 09-29 02:43, "should I seal the examiner's door until a later return path". His 09-28 playtest remark ("shouldn't ... get to the examiner so quick") leans yes.

## 4. STILL OPEN?
| Item | Status | Evidence |
|---|---|---|
| Yellow transition | BUILT | systems/interstitial.gd:256-258 uses the datamosh wipe into the vat chamber; Codex 09-29 02:43 also recoloured wipes red/black |
| Broadcast line shown twice | BUILT (per agents) | front-door commit d283c4e4 (torture_load_in.gd); Codex 02:43 "spoken once" |
| Green square around vat | BUILT (per Codex) | Codex 09-29 02:43 "replaced by a dark round spill"; vat_chamber.gd:99 "Crawl through the spill" |
| Real cables, not beads | BUILT | vat_chamber.gd:542-556, LabCables tube with "Greg's playtest: real cables" |
| Subtler bubbles | NOT FOUND | no "bubble" match in vat_chamber.gd |
| Examiner reached too early / staff access | PARTLY | staff door is sealed until the keycard (vat_chamber.gd:2697-2699); the seal-until-later question is unanswered |
| Freed subjects killable / not just "Keep walking" | PARTLY | they flee to exits (claude 1f984e04 checklist "[x] Freed subjects run for the nearest exit"); "KEEP WALKING" line still in systems/bingyanger.gd:103; no kill evidence |
| Unexplained reset to start / OpeningDeath | NOT FOUND (wired) | systems/opening_death.gd exists, but only tests reference it, no route caller |
| Tutorial steps, one lesson per room | NOT FOUND (as named) | no tutorial/lesson system in route scenes; agent list 09-28 16:25 only |
| Gothic face visible under monitors | BUILT | gothic_field_hud.gd:231/380 `_draw_player_state(face_only)`; claude 34735752 09-28 18:31 "visible again, below the monitors" |
| Faint silhouette rim | BUILT | systems/silhouette_rim.gd, used in support_unit.gd and service_arcade.gd; tests/silhouette_rim_test.gd |
| Art gallery: posters, tear-off tabs, cards, large view | BUILT | systems/art_gallery.gd, wall_poster.gd ("[E] TEAR OFF A TAB"), gallery_view.gd, brain_index_hub.gd; tests/art_gallery_test.gd |
| Hornee plush in gallery | BUILT (per agent) | claude 09-29 04:23 "card in the Brain Index gallery, Space turns him into the spinning plush" |
| Generated models placed in game | PARTLY | systems/generated_model.gd FITs for shiv, black_mirror, restraint, cctv, surgical_lamp, bone_drill; GeneratedModel referenced only by held_gear.gd outside tests |
| Examiner as skin on BaselineHuman | PARTLY | systems/model_skin.gd; examiner_fight.gd:65 mentions ModelSkin; terminal examiner in vat_chamber not confirmed |
| Doctor model "wacky" | NOT FOUND | no follow-up in this chunk |
| Hunt at 160 fps (6.25 ms) | PARTLY | 11.54 ms on 09-29 05:15; claude 284daf93 09-30 02:15 "target is only met while idle" |
| Pad prompts (PS labels) | BUILT | systems/pad_bridge.gd:51-56 maps keys to CROSS/CIRCLE and tracks `using_pad` |
| Vat bodies (Higgsfield NSFW block) | NOT FOUND, deferred by Greg | 09-29 04:23 |
| "torstim" file | NOT FOUND | claude 284daf93 searched P:/GameDev; no match |

## 5. WORLD / LORE / NAMES (his spelling or as he used them)
- Demo menu entry: "The Best Half Hour" (09-28 14:34).
- Opening broadcast: "Hundreds of years in the perpetual post-apocalypse".
- Vat UI: "Wizard eyes", "Depth scan", "hold E, rip out", "end all suffering", "tear the cord over your mouth", "Get revenge".
- Intake: "intake preset, quick start".
- The doctor / examiner (wears glasses). The elevator floors are B1, B2, B3, SU (surface).
- "Mental health and physical support unit" (the Support Unit) with cells; a "geyser"; "Found my old body".
- Freed subject line: "Keep walking. I'll keep walking."; "I'll grow you back."
- Hornee: his plush, rebuilt in 3D from his photos.
- Art pieces named by the agent from his Art Collections folder (his titles): CoverMeInMoss, dying in green, powers that be, war time, Spitrost, Cellout Wizards Only Fools, Pixel.
- Brain Index ("index brain"), the art gallery. Nerve rig and gothic face (HUD).
- Agent-side names in pasted text, not coined by him: BREACH NINE, Black Mirror (phone), Hollis, Dust to Bones ledger, Colosseum, Undercroft, Executive Breach, Maintenance Ascent.

## 6. STYLE OF WORKING
- 09-28 14:27: he wants agents to keep working while he can't playtest. "but cause work needs to be done i cant playtest"
- 09-28 14:28: he wants to know what is left. "get to work tell me what you still need to work on"
- 09-28 14:58: he asked for many agents ("open as many agents as you need"), then 7 minutes later at 15:05: "be token efficent". That 5-agent run hit the usage limit.
- 09-28 15:54: "keep going ask hella questgions if needed". Also 09-29 00:02 (in pasted text): "Ask me hella questions".
- 09-29 00:44: Claude and Codex should work back and forth in one place, fast. "should just be working back and forth kind of thing, like really fast"
- 09-29 00:42: protect existing code from AI-generated churn.
- Gore, organs and X-ray are a hard bar for any new model (09-29 00:42).
- Credits: spend Higgsfield credits (1000; a 300 cap was used by the agent) on 3D work. He called Higgsfield "a scam" for the billing but still wants to use it.
- 09-29 05:15: when usage runs low, wrap up cleanly. Commit only verified work and leave a handoff with numbers, what was tried and rejected, and pre-existing failures. Reports should be three lines.
- 09-29 06:53: never open the game in his main window.
- He uses voice mode for playtests and pastes one agent's output into another to coordinate them.

## 7. CONTRADICTIONS
- 09-28 14:58 "open as many agents as you need" vs 15:05 "be token efficent". The many-agent run burned the limit. Newest wins: be token efficient, one lane at a time.
- Earlier rules said each agent works in its own worktree and branch (the overnight run and Codex briefs). On 09-29 00:44 he called that "pretty dumb" and asked for one shared folder and branch. This also conflicts with the current harness rule 2 (own worktree per agent). The newest Greg answer is shared; the current harness setup overrides it for this fleet.
- 09-29 00:42 "re-render everything replace the models" vs, in the same message, "don't make it too crazy ... AI shit ... fucks up our whole code". Read together: replace models as skins only, without rewriting systems.
- 09-28 14:34: he praises being able to fight the examiner ("we can punch and fight him") but says reaching him is too quick. That is not a contradiction: keep the fight and gate the access.
