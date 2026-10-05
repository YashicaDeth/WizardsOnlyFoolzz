# read-greg-11 — notes (chunk covers 2026-09-21 09:48 → 2026-09-22 10:32)

Source: P:/GameDev/AgentHub/data/chunks/greg-11.md, read in full (1544 lines). Most of the chunk is agent output Greg pasted between agents (Claude / Codex / OpenCode "muse spark"). I quote only text Greg typed himself, including the short notes he added at the end of a paste or between pasted lines. The project was then at P:/GameDev/AllusionsTooGrandeur. Typos in quotes are his own.

## 1. REQUIREMENTS

**Opening: vat, examiner, intake**
- 09-21 10:05: the game starts by waking in the vat. The examiner walks in, goes to a real-looking computer off to the side, and that computer starts the brainchip, which shows the character customisation. "make it start with waking up in the vat then the examiner guy comes in looks at you goes onto the computer which is insight but not slap directly infront of the vat"
- 09-21 10:05: the intake chat box is more visible (not bottom-left). Your choices change what the examiner says. It runs until every box is checked and confirmed, with no Space to change an answer, then it forces a yes. "your choices actually interact with what the exmainer is saying and contuines the game until youve checked every box"
- 09-21 10:05: fix the clipboard UI and change the look of the character customisation. "can we also fix the clipboard ui and change the ui of the character cusotrmisation"
- 09-21 11:05: the handler/examiner is shown looking at you on the left or right of the floating body, vat and character creation, not as a lone text box. "fix it so the handler is looking at you on the left or the right whatever wherever you can fit this floating body"; "not jsut have this rouge text box on the left"
- 09-21 10:01 (voice playtest): the text box is missing or hard to read, and "you can't really see the hand". The pressure gate soft-locks: "I reached the pressure gate and I pressed E and nothing happened and now I'm just stuck".

**Escape route and progression**
- 09-21 10:37: the "escape the facility" section has combat, and the UI is unlocked gradually. "the part where you gain all the ui slowly and surely as you progress"
- 09-21 12:06 (his note inside a paste): the world starts at night and is too dark after the derby. "it starts at night and you can harldy see anything when you leave the derby"
- 09-21 10:55: fix the satellite and make the map coherent. "i want the satellite fixed and the map to be coherent now"

**NPC AI and voice**
- 09-21 09:57: build the AI NPC Communication/Relationship spec (PDF) into the game. "hey make this awesome system in the game right now as quickly as you can"
- 09-21 10:55: run a local LLM (Ollama) and use it in the overworld, both in combat and in conversation with every character. "do the locla we can do that ... put this into the overworld of the game and make it work when combating or interacting with all the characters"
- 09-21 10:22: asked whether the AI replies with a voice model. 10:32: hold-V voice does not work. "it does not detect mmy actual hold v to speak its still a text box"
- 09-21 12:06 (in paste): "also in the overworld is the v bound yet"

**Gore and anatomy**
- 09-21 12:14: realistic gore across melee, sword, guns and bullet wounds. Bullets and cuts should go through clothes as part of the skin system. He points to SkinGore as the bar. "realistic gore we dont have clothes rn so bullet or cuts in clothes apart of the skin system"; "skin gore is crazy https://zulubo.github.io/SkinGoreWebBuild/"
- 09-21 12:16: "super realism gore brutalism ect system i want that still keeps a good gameplay and combat balkance"
- 09-21 12:47: execution finishers cut open the stomach and chest so you can tear organs out by hand, and you steal cybernetics and organs from kills. "cut open someones stomach and chest cavity to tear there organs out with our hands as excition stryle finshers that steal cybernetic and organ parts"
- 09-21 12:47: a sniper rifle whose instant kill triggers a slow-motion 3D X-ray kill cam that blows apart the eyes, brain and organs. "slow mo 3d kill effect that explodes the eyes brain and all the different parts of the organ"; reference games: "gta 5 rdr2 farcry ... hitman 4 sniper elite mortal combat style fatality"

**Melee combat**
- 09-21 14:29: "i think we should make the first person sword combat work like mordhau / that otherr really good for honour?"
- 09-21 14:38: the sandbox needs working GUI controls, no lag, every gun including the sniper, round (not square) body models, gore and mutilation physics, Mordhau swinging and the X-ray sniper kill. "fixed body models so they dont have square bodies"

**Gore sandbox**
- 09-21 10:01: "The gore sandbox is insanely, insanely laggy, and I don't even think any of the gore or anything has changed."
- 09-21 15:13 and 15:12: the sandbox should play and feel like the main overworld. "making it look and be the same feel playerwise as the maingame overworlsd"; "make it all match and the same please"
- 09-21 15:20: what differs is "the hand models and the ui screen right left ect".

**Inventory, Brain Index, contacts**
- 09-21 10:43: "we want the inventory ui like this" (he attached a reference image, which I cannot see).
- 09-21 10:54: the Brain Index is opened by clicking the player model's head in the inventory. "the brainchgip thing thats accessible through clicking where the l;ayer model would be in the inventory"
- 09-21 14:54: "i want clothes to work in the new carry inventory menu"
- 09-21 14:55: the Brain Index stores memories, drug experiences and the means to contact characters. The old T/U menu with the X-ray body slider becomes a contact screen (phone, brain, spirit or entity). "brainindex also stores memories and drug expeirences and the way to contact characters"; "drug experiences where you learn and meet entites"
- 09-21 15:27: "i want the relationship tree thing in there too"
- 09-21 14:59: "also do we have a looting body menu yet"
- 09-21 15:28: keys 1-9 (the weapon/item wheel) are not linked to the inventory. "you pretty quickly cant reaccess the guns you loaded in on your character"

**Weapons and economy**
- 09-21 14:56: open a weapon from the inventory to add attachments, Rust-style but redone as post-apocalyptic, plus bullet types. "add weapon attachments like rust attachments basically same ones but remade to be post apocalyptic and bullet types"
- 09-21 14:56: digital cases with a slot-machine opening, a 1% gold drop like CS:GO, then a currency system. "a digital slot machine case box loot box opening system ... rare 1% gold csgo case style thing"
- 09-21 15:00: remake the gun and sword models using textures from his art-collections folder, and make them skinned. "quickly remake the gun and sword models then go into my art collections folder texture is and make it skinned"
- 09-21 15:19: use free model/texture sources from GitHub for weapons, and use his art folders (for example "the archive") as examples.

**Clothes**
- 09-21 14:47 (a question, so it shows what he wants): "are the clothes like humilation ritual outfits jester outfit clown outfits dunce caps torn up shitty apoclayptic clothes"

## 2. DISLIKES / REJECTIONS
- 09-21 10:01: the examiner computer blocks the vat: "why is there this computer in front of the thing?"
- 09-21 10:01: the pressure gate soft-locks (see above). The gore sandbox is "insanely, insanely laggy" and the gore is unchanged.
- 09-21 10:01: the intake text is unreadable: "there's just not like a text box to the left".
- 09-21 11:05: "this rouge text box on the left" (the handler shown only as a text box).
- 09-21 12:06 (in paste): the handler talks too much: "he just begins talking at you spouting too myuch dialopuige". Also "the sandbox is still insanley laggy".
- 09-21 12:28: the NPC voice/dialogue: "its pretty scuffed it juyst spams the same voicelines"
- 09-21 15:19: the current gun and sword models: "its just placeholder slop rn"
- 09-21 14:45: "the gore sandbox is broken right now whats going on"
- 09-21 14:38: square, faceted body models.
- 09-21 10:32: hold-V is "still a text box".
- 09-21 12:06 (in paste): night start and darkness after the derby.

## 3. DECISIONS
- 09-21 10:55: local Ollama for NPC dialogue (offered: local 8B vs a cloud key). "do the locla we can do that"
- 09-21 12:09–12:09: full permission to pull GitHub libraries and assets. "give you full permission to link and download inifinite github stuff for everything". 12:21: "start with plugging them all in". 12:25: "okay do it lets go"
- 09-21 12:18: Gaea: "yeah coudld use gaee find gorundbreaking stuff". The agents declined it. Greg did not answer again.
- 09-21 12:33 (end of a paste, 10:28 PM): use the plugins "without changing its scope too much".
- 09-21 12:32: to Claude's list (clock to morning, overworld conversation component, draw calls): "do theese all and then suggest more"
- 09-21 13:08 (11:08 PM): the next-work list (sniper→KillCam, extraction→cavity, vault fix, Vosk, profiling, Scatter): "do it all now"
- 09-21 12:16: to "pick one: clothing shell, combat animation/impact, or pooling": "do them all"
- 09-21 14:21: the procedural vs skinned-rig fork for combat animation got no explicit pick. He answered "do what you can about this while making it awesome let me know?", which leaves it open. Later he set the combat direction: "work like mordhau / ... for honour".
- 09-21 14:38: to "bind FP mouse guard + drag, TP committed swings?": "yes"
- 09-21 14:53: verify the sandbox binding and relaunch: "yes"
- 09-21 15:00: build the case system now: "make this"
- 09-21 15:23 (OpenCode's list, contact menu first): no explicit answer. Contact menu work went ahead.
- Not answered in this chunk: whether CRT is on or off by default (Claude defaulted it off); the combat skill-tree design (Claude would not start without him).

## 4. STILL OPEN? (checked against launch-latest/game, read only, and agenthub search)
| Request (date) | Status | Evidence |
|---|---|---|
| Vat wake → examiner → separate computer → brainchip intake (09-21) | BUILT | systems/vat_intake.gd:196,287,792 ("real vat, computer and examiner remain visible") |
| Handler silence between lines, not spamming (09-21) | BUILT | vat_intake.gd:75 "Enforced silence after a line" |
| Handler visible beside the floating body, not just a text box (09-21) | PARTLY | systems/examiner_look.gd, intake_watchers.gd exist; not checked visually |
| Pressure gate soft-lock (09-21) | BUILT | Codex 09-21 10:20 (auto-open with card); service_arcade.gd |
| UI gained gradually during escape (09-21) | PARTLY | Lower Works/buried_city.gd with Lift Fuse + sentinel (Codex 09-21 12:33); gradual UI unlock not verified |
| Morning start / not dark after derby (09-21) | BUILT | systems/world_clock.gd:65 `OPENING_MINUTE := 13.0 * MINUTES_PER_HOUR` |
| Satellite/map coherent (09-21) | PARTLY | systems/living_map.gd numbered UNSURVEYED sectors (Claude 09-21 11:05). Greg did not confirm |
| AI NPC spec + local Ollama in the overworld (09-21) | PARTLY | systems/npc_ollama_brain.gd, npc_conversation_component.gd used in bone_yard_hunt.gd; tests/standing_contact_test.gd |
| Hold-V voice (09-21) | PARTLY | systems/spoken_contact.gd, mic_level.gd (Vosk); real mic not verified |
| Evisceration finisher, hand organ tear, steal implants (09-21) | BUILT | systems/extraction.gd, systems/cavity.gd; Codex 09-21 14:05 "Finishing an extraction physically opens the chest" |
| Sniper + X-ray kill cam, skull/eyes (09-21) | BUILT | systems/hunter_arsenal.gd (ASHLINE LONGVIEW), systems/skull_burst.gd, tests/sniper_killcam_test.gd |
| Mordhau / For Honor sword combat (09-21) | BUILT | systems/blade_read.gd, tests/blade_read_test.gd, combat_blade_binding_test.gd |
| Parry sparks (09-22 agent list) | BUILT | systems/parry_spark.gd, tests/parry_spark_test.gd |
| Bullets/cuts through clothing (09-21) | BUILT | systems/clothing_shell.gd, clothing_integration_test.gd |
| Humiliation clothes: jester/clown/dunce (09-21) | BUILT | clothing_shell.gd (dunce), clothing.gd "humiliation" |
| Smooth (non-square) bodies (09-21) | BUILT | Claude 09-21 14:41 "Smooth the body normals" (committed with the sandbox binding) |
| Sandbox lag (09-21) | PARTLY | Codex 09-21 14:05: ~31→44 FPS; OpenCode 09-22: ~13 ms still unattributed |
| Sandbox matches the overworld: hands, arms, UI (09-21) | PARTLY | systems/sandbox_avatar.gd exists; agenthub claude 4946a758 15:42 "hand models — it was a colour and a scale" |
| Inventory UI like his image (09-21) | PARTLY | systems/field_inventory.gd; match to the image not verified |
| Brain Index via clicking the player head (09-21) | BUILT | field_inventory.gd:30,109,115,291 (head_hover, _toggle_brain_index) |
| Clothes in the carry inventory (09-21) | BUILT | OpenCode 09-21 15:14 "M mend cloth. Cloth cover rides each body row" |
| Contact menu: memories / drugs / entities (09-21) | BUILT | systems/contact_menu.gd, contact_entities.gd, tests/contact_menu_test.gd |
| Relationship tree (09-21) | PARTLY | systems/npc_relationship.gd exists. "tree" in hunt KEY_7 is blood_ledger.toggle_tree (weapon XP trees), not relationships |
| Body loot menu (09-21) | BUILT | systems/corpse_contents.gd, tests/corpse_loot_inspection_test.gd |
| 1-9 wheel linked to inventory (09-21) | PARTLY | Claude 09-21 15:37 "mouse wheel is now the weapon wheel"; bone_yard_hunt.gd:1797 only KEY_1-3 weapons, then fixed actions |
| Weapon attachment menu, Rust-style (09-21) | NOT FOUND (menu) | attachment points only (hunter_arsenal.gd:79 "AF10.10"); no attachment UI in field_inventory/case_menu |
| Switchable bullet types (09-21) | PARTLY | calibres in systems/ballistics.gd / penetration.gd; no load-switch UI found |
| Loot cases, 1% gold, currency (09-21) | BUILT | systems/case_menu.gd, loot_case.gd, skin_case.gd, weapon_skins.gd (OpenCode "Dead Cloud Exchange", U key) |
| Case spin/slot-machine reveal animation | NOT FOUND | OpenCode 09-21 15:14 "no spin animation on reveal (instant today)" |
| Remake gun/sword models from his art textures, skinned (09-21) | NOT FOUND | OpenCode stopped at a purple test pistol; asked for Quaternius packs. Not checked in later art |
| Combat skill trees (agent item, 09-21) | BUILT later | systems/blood_ledger.gd header "(Greg, 24 September 2026; rates and trees in BloodTrees)" |
| Low-wall vault failures (agent item) | BUILT | tests/vault_test.gd; Codex 09-21 14:05 "Low-wall vaulting regression is f[ixed]" |

## 5. WORLD / LORE / NAMES (his spelling, or the agents' where marked)
- "brainchip" / "brain chip", "brain index" / "brainindex": a head implant that holds memories, drug experiences and contacts.
- "the examiner guy" / "the handler": the vat examiner. The spec PDF calls him "The Doctor". Bible note via Claude: he is unnamed, so no "Dr. Thompson".
- "escape the facility", "the derby", "the overworld", "gore sandbox", "Service Arcade", "pressure gate".
- "relationship like contact/phone/brain/spirit contact or entity contact"; "entites" met through drug experiences.
- "humilation ritual outfits", "jester", "clown", "dunce caps", "torn up shitty apoclayptic clothes".
- "digital cases", "digital slot machine case box", "1% gold".
- Agent-coined in this chunk, not Greg's: Lower Works, Heat Elevator, Lift Fuse, ASHLINE LONGVIEW, Dead Cloud Exchange (Cache 25 / Tithe 60), Ashbloom, Bone Yard, Underground Colosseum, Wetwire index, BladeRead, Cavity, KillShot, SkullBurst.

## 6. STYLE OF WORKING
- 09-21: speed and volume. "keep going and help out we wwant as much progress possible!!"; "do it all now"; "keep working" (many times); "do them all".
- 09-21 09:49 / 13:51: wants each agent to watch the others and report on them. "show me if there has been any gameplay changesd or questions"; "see how claude and the opencode thing is going"
- 09-21: passes messages between agents by pasting output from one into another ("this is what cvlaudes doing", "help it out").
- 09-21: wants the game launched for him to test. "launch it properly"; "maybe launch the current game with the current version"; "launch the game quickly ill test then keep working". Rule 1 (headless only) now overrides this.
- 09-21 12:09: wants big existing libraries reused and adapted. "using already massive librarys of prewritten code systems which we can then change". Later limited: "without changing its scope too much".
- 09-21 15:00: asks to be told the controls when menus are ready. "if the menus work remind me of the controls"
- 09-21 11:53: asked which free OpenCode model is best for coding a Godot game, so cost matters to him. Claude's out-of-credits note (11:38) is context.
- 09-21 15:00 / 15:19: he does not want placeholder art ("placeholder slop").

## 7. CONTRADICTIONS
- 09-21 12:09 "download inifinite github stuff for everything" vs 12:33 "without changing its scope too much". The newer note limits the first.
- 09-21 12:14: he wants SkinGore-style skinned gore, and on 09-21 15:00 asks to "make it skinned". The agents reported that the bodies have no Skeleton3D, so skinning would break BodySlice. He never chose between the two (the 14:21 fork is unanswered). Rule 5 protects the gore.
- 09-21 12:18: "yeah coudld use gaee". The agents refused Gaea, and he did not press. It is open, not settled.
- 09-21 14:48: he tells OpenCode to leave the sandbox to Claude ("not sandbox if claude is gonna fix that"), but at 15:13 asks OpenCode how the sandbox is going. This is lane routing, not a design conflict.
- 09-21 10:01: "the best half hour of my life" is sarcasm. Do not read it as approval.
