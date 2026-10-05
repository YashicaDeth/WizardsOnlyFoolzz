# Greg's decisions (raw record, oldest first; when two disagree, the NEWER one wins)


---
# Source: data/greg_direction_2026-10-04_controller_combat.md

# Greg, 2026-10-04: controller-first combat and weapons (newest answer wins)

- Built for controller. Test pads: PS4 (USB) plugged in now, PS5 DualSense available. Must feel great on pad first; keyboard second.
- Currently playing Demon's Souls to learn combat. Playstyle must be CHOOSABLE with seamless transitions between:
  Doom-esque fast shooter  <->  Mordhau/Half Sword-style weighty melee  <->  soulslike (stamina, lock-on, dodge/parry)  <->  traditional shooter.
- VATS-like system built on the existing X-ray: slowed time, target cybernetic organs/parts, rupture and explode them
  (Sniper Elite kill-cam x Fallout VATS). Some parts armoured; parts give different stat effects. Not Diablo-loot-driven.
- Skill tree: node-based upgrades (Diablo / Baldur's Gate style), but SPECIAL PER WEAPON.
- Weapon models and textures must be remade/improved: "great".
- START SMALL: 2 melee-class weapons + 2 ranged-class weapons, then keep defining.

## Greg, 4 Oct, after playing: PROTECT THESE
- He is ENJOYING the intro sequence and the cutscenes. Do NOT change, re-time, or replace them. Any change near them needs a test showing they still play identically.
- The UI "is very sick" but needs work, especially the stats display. Improve it; keep its look (the red/copper CRT language).

## Greg, 4 Oct: THE FACILITY IS A REAL PLACE
- The underground facility the player must escape is a real, coherent, explorable place: one connected space (levels, tunnels, rooms, elevators/lifts walked in-world), not a chain of separate scenes with splash transitions. Escaping it IS the demo's spine.
- Not concept art: real playable geometry, textures, lighting, routes. Existing design to honour: DESIGN/ESCAPE_ROUTES.md, DESIGN/FACILITY_TERRITORY_SLICE.md, DESIGN/FIRST_30_REBUILD.md, DESIGN/FACTIONS.md.
- Elevators are REAL: you step in, the doors close, the cab genuinely descends/ascends through a visible shaft (moving platform, floor indicator, hum, light strips passing, shaft glimpsed through gaps) at a believable speed, then the doors open on the new level. The player stays in control (can look around; enemies/events can interrupt). No fade, no splash card.

## Greg, 4 Oct: Bloodborne approach + grips
- Guns work the Bloodborne way: melee in the main hand, gun in the off-hand (shoot to stagger/parry, visceral-attack follow-up), without dropping the blade. Full aim (ADS) is still available when you commit to a gun.
- Grip modes per weapon: ONE-HAND, TWO-HAND, DUAL-WIELD (different stats/moves/stamina per mode; switch quickly, ideally one button on pad).
- Weapon selection UI: either a weapon wheel, or the held weapon's own panel extending the current GUI that shows when you hold a weapon. Build on the existing GUI (hunt HUD / held-weapon display), keep its CRT look; must be fully pad-driven (hold a button for the wheel, stick to pick, release to equip; D-pad for quick grip swap).

## Greg's answers, 4 Oct (clarifying round 1)
- NEXT BUILD must contain: controller works everywhere; seamless facility + real elevators; aim down the barrel + good gun/sword models; third-person combat fixed + body head/shoulders. Everything else waits.
- No single default combat style. Core idea: the player's hacked BRAINCHIP "knows" multiple fighting/play styles; the skill tree has branches (violent/combative, stealth, MAGIC with ranged/throwables, etc.); switching between styles is seamless. Details still being clarified with Greg.
- Facility size: agent decides from DESIGN/FACILITY_TERRITORY_SLICE.md.
- Characters: placeholders only, NO Higgsfield for characters.

## DISCIPLINES (Greg, 4 Oct, clarifying round 2) - the chip system
- The hacked brainchip holds several DISCIPLINES (5+ in the first playable: e.g. Brawler, Duelist, Gunner, Shade/stealth, Wizard/chaos-magic; names open). Each is a full playstyle: movement, stamina rules, camera/aim, moves, its own skill-tree branch (violent/combative, stealth, magic...).
- Switching: bumper cycle (L1/R1-style) PLUS automatic default from the weapon you hold, wheel as override. Seamless, in-world, ~0.5 s chip glitch, no menus.
- THE BINDS CHANGE WITH THE ACTIVE DISCIPLINE: the same physical buttons mean different things per discipline (controller has limited buttons). HUD button hints follow the active layer.
- Cost: a CHIP HEAT meter, mixed with near-free swapping: swapping is cheap and fun but heats the chip; overheat = glitch/stagger. Balanced so it is a choice, not a punishment.
- MAGIC discipline: (a) chaos-magic ranged casting (sigil-drawn spells; costs blood/sanity, ties to substances), (b) combo with the X-ray VATS (slow time, mark organs, cast through the marked point), (c) summon/binding via the existing sigil-binding flow.
- Build on: combat_stance.gd (stances), hunter_arsenal.gd, PadBridge/InputMap, world_xray.gd, DESIGN/THE_BRAIN.md, existing skill tree work.

## Process answers, 4 Oct
- Keep the whole queue (reorder only). Tasks run in PARALLEL and auto-merge through the gate; on a merge conflict, REBASE onto the newest claude/launch-latest and resolve keeping BOTH sides' intent, then re-run the gate. Never drop another task's work to make yours pass.
- Every merged green wave gets a dated playable copy (already how the hub works).

## Round 3 answers, 4 Oct
- Swap glitch: screen tear + CRT static ~0.5 s, the HUD brain CRT pulses, modem/dial-up chirp + heartbeat. No time-slow hitch.
- Lethality: mixes "brutal for everyone" (Mordhau/Half-Sword) and "soulslike survivable but punishing", set PER DISCIPLINE (e.g. Shade/Gunner brutal glass-cannon, Brawler/Duelist soulslike pool).
- Shade (stealth): all three verbs: silent takedowns from behind (first), light/dark visibility using facility lighting pools (second), chip-hacking cameras/doors/CCTV (third).
- When Claude accounts return (16:54): do everything: AI playtest of the new build, push the 4 must-haves, and fix the sandbox (ragdoll/arms/gore).

## Round 4 answers, 4 Oct (reference image: data/greg_skilltree_reference_bg3_illithid.webp)
- Disciplines are PLAYSTYLES, not weapon classes. Do NOT tie a discipline to a weapon kind; any weapon can be used in any discipline (a discipline changes verbs, movement, stamina, camera, binds, special moves). Drop "auto default from held weapon" from the spec; keep bumper cycle (+ wheel).
- Names: Greg is not sure he likes the working names (Brawler, Duelist, Gunner, Shade, Wizard) and wants to ADD at least one more. Use placeholder ids until he picks; names are data, easy to change.
- SKILL TREE: Baldur's Gate 3 "Illithid Powers" style (the reference image): a creepy, dark, high-detail BRAIN as the board, nodes as round sigil icons sitting on its lobes, dim locked nodes, hover tooltip card, a currency counter at the side. Build it on our existing HUD brain (organ with a curved CRT, DESIGN/THE_BRAIN.md). Per-weapon trees are secondary; the main tree is per-discipline branches across the brain lobes. Fully controller-navigable (stick moves between nodes, A buys, tooltip follows).

## Round 5 answers, 4 Oct
- The EIGHT disciplines (pure playstyles): Soulslike Duelist, Mordhau/Half-Sword Brawler, Doom-style Berserker, Shade (stealth hunter), Chaos Wizard, Marksman/VATS Sniper, Trickster/Thrower, Puppeteer/Summoner. Names are working titles; Greg may rename.
- Skill-tree currency: primary BLOOD/SOUL FRAGMENTS (from kills and harvested organs), mixed with experience from fights, consumed substances and chip upgrades found in the world (all four feed it, fragments dominate).
- Locked nodes are visible from the start but with CORRUPTED/UNREADABLE labels until the player is near (adjacent) or owns them.
- ENEMIES USE DISCIPLINES TOO and must be actually HARD: a Shade enemy hides and stabs from behind, a Marksman keeps range and aims at your parts, a Duelist parries and punishes, a Berserker pressures, a Summoner binds allies, etc. Brutal-for-everyone lethality where it fits. Readable tells so hard is fair.

## Round 6 (supersedes the "EIGHT" list in Round 5)
- SIX disciplines, not eight: Soulslike Duelist; Mordhau/Half-Sword Brawler; Doom-style Berserker; SHADE (stealth hunter) which ALSO owns the Trickster kit (throwables, traps, improvised weapons, ricochets); CHAOS WIZARD which ALSO owns summoning/binding (the Puppeteer kit) plus sigil casting and the VATS combo; Marksman/VATS Sniper.
- Names remain working titles; adding one later is a single data entry.

## Round 7 answers, 4 Oct
- Brain board: one brain, each discipline owns a LOBE, plus a CENTRAL HUB of shared chip nodes (shared stats/perks) in the middle.
- Unlocks: the player PICKS 2 disciplines at the vat (character creation), the rest unlock during the escape/demo.
- Enemy damage in the first area: a mix of "3-4 hits" soulslike and "wounds degrade you" body-system damage (losing an arm/leg changes how you fight); mistakes punished, not instant-death unless a heavy hitter lands a clean blow.
- Death: Demon's Souls style: you drop your blood/soul fragments at the death spot (a bloodstain) and can recover them by reaching it; dying again before recovery loses them.

## Round 8 answers, 4 Oct
- Pick-2-disciplines happens on the BRAIN SCREEN right after the player breaks out of the vat: first look at the creepy brain board; wake two lobes.
- Third-person combat camera: Souls-style over-shoulder with lock-on that frames both fighters (existing _camera_combat_focus in bone_yard_hunt.gd is the base; fix it, do not replace the idea).
- NO demo wall/contract barrier at all: the game just keeps going, everything built is playable. Remove the invisible barrier and the demo-end wall as a blocker (keep any visible diegetic geometry that is genuinely a world edge). The demo_border/demo_wall tests must be updated to match this.
- Queue order unchanged (no deprioritisation).

## Round 9: manager rules, 4 Oct
- Failed tasks re-queue up to 3 times with escalating effort and the failure log attached (hub.py).
- Greg wants to follow/steer from his PHONE (Remote Control on for the main session) and be pinged efficiently, not spammed.
- "Next build" milestone = all 4 must-haves merged green AND AI playtest report shows no blocker AND vat-to-first-exit walkable with zero loading screens AND whole route playable pad-only AND Greg judges ADS/guns/sword acceptable.
- Account routing: Claude accounts for judgement/vision work, Codex for tests/mechanical work.

## Round 10: answers to the open queue/questions, 4 Oct
- Pad layout: SOULS layout everywhere incl. the Hunt (R1 light, R2 heavy, L1 block, L2 parry; with a gun R2 fires, L2 aims). Disciplines remap on top.
- Aimed X-ray / VATS trigger on the pad: keep L2+R2 squeezed together (as built).
- Four starter weapons confirmed: SHIV, ASHLINE CLEAVER, MERCY NINE, ASHLINE LONGVIEW.
- VATS part effects: keep the built split (arm/crippled arm=disarm; leg/lungs/spine=slow; eyes/head=blind; heart/liver/gut/brain=bleed/death) AND add: ears=deafen, jaw=silence (cannot call allies/scream), hands=fumble, spine hardware=stagger/knockdown chance (opens a visceral). Every enemy needs at least one part per effect.
- Examiner: YES, the generated M1 model is the examiner everywhere (at the glass, walking out) with surgical mask + loupes on top; intake close-up feed keeps the human face with lip sync.
- Player: YES generated player model with drop-away layers (face shapes, race, body horror, nudity censor, gore). NOTE conflict with "no Higgsfield for characters": build it WITHOUT new Higgsfield spend (code-built/placeholder body until a player sheet exists); the drop-away layer system is the real work.
- All other character questions (Hollis guard, doctor's car, fire axe, Hornee, ledger): use the recommended default in each queue/questions file; placeholders only, no Higgsfield.

## Round 11 answers, 4 Oct
- First minute after the brain screen: OVERWHELMING and GLITCHY: the chip floods in (static, tear, two styles flickering in the hands, heartbeat), then the player is thrown into the escape. Do not touch the existing intro/cutscenes: this starts only AFTER the brain pick screen.
- Bloodstain (death fragments): CREEPY: a pulsing organ/sigil on the floor with a heartbeat you HEAR before you see; red-copper glow rises as you approach.
- Chip heat meter: on the existing HUD brain; lobes heat up red as heat builds.
- Weapon wheel: RIB-CAGE wheel: slots are ribs around the HUD spine (on-theme body horror), pad-driven (hold, stick selects, release equips).

## Round 12 answers, 4 Oct
- Unlock moment: each later-unlocked discipline arrives with a "chip waking" beat (glitch + heartbeat + brain lobe lighting up); it is unlocked by progress in the escape.
- The vat pick CAN be mismatched: some pairs of starting disciplines have a downside (chip discord: e.g. extra heat or a swap penalty) and some pairs have a synergy bonus. Show the pair's rating on the brain screen before confirming (not a hard fail, a trade-off).
- The rib-cage weapon wheel also shows the ACTIVE discipline (a lit lobe marker on the wheel's spine) so you know your style at a glance.

## Round 13: answers to agent questions, 4 Oct evening
- Third person turns on at the BRAIN SCREEN with the two disciplines you wake; a discipline that wants third person uses it, first person is default until switched.
- Knockdown: keep the split: living knockdowns use the authored tip-over and get up; DEATH is a full ragdoll; living ragdoll only for big launches later.
- Examiner: a first run MUST beat him (~minute 6); his door stays shut until you are out and dressed; winning gives staff access.
- Black Mirror: in the den; once dressed, the wizard-eyes objective wave points at the weak wall (not skippable).
- Intake arcade-cabinet redesign: AFTER the first 30 minutes are right; for now bigger controls, rename, ink row, pad support.
- Player's starting sword: LEAFSPRING LONGSWORD (others stay on enemies).
- Hornee: summoned as a CHAOS WIZARD summon via the binding system (not a Brain Index button).
- Wanted next from agents: full control scheme per discipline; the brain board's six lobes with first 5 nodes each; first-5-minutes escape beat sheet; facility zone list with enemy placement.

## GREG'S OPENING VISION (4 Oct night, his words; this wins over every older opening design)
- Press START -> the intro CUTSCENE plays (post-apocalyptic perpetual-future world, the runes etc.; he likes it; do not change it). It must NOT spawn into the game with a "tap tap tap" jump.
- After the cutscene: you SLOWLY OPEN YOUR EYES, in FIRST PERSON, INSIDE A VAT. There is REAL LIQUID all around you with physics: red, a bloody vat; not a white/grey texture.
- The room is an experimentation room; today it is tiny and jammed with props. Make it properly sized and readable.
- The facility is ONE COHERENT MAP: you walk (elevators are physical rides) into whole new sections; no scene-swap "teleports". The different routes must work as he intended.
- Build a ROADMAP: collect every mechanic we know exists (from DESIGN docs, checklists, HANDOVER, ORCA, branches) into one roadmap with status.
- Use outside resources: GitHub plugins, Godot addons, agent/game-dev skills, no-clip.website style references, artifact sites; do not hand-roll what exists.
- ONE main game branch. Stop spawning copies. (See consolidation task.)

## THE ONE PLAN (4 Oct night)
Read P:/GameDev/AgentHub/data/GAME_PLAN.md: the combined plan from every chat, DESIGN.md, the Dust to Bones page and the 12 Sep Build Sheet. Build only the current slice.

## Greg, 5 Oct: the lab is "awesome"; keep refining and polishing it. Liquid and glass spec: data/greg_playtest_b_2026-10-05.md, task lab-46.

## Greg, 5 Oct: destruction is now Teardown-like with diggable ground and a 5-tier toughness scale (replaces 25 Sep "authored stages"). Spec: data/greg_playtest_b_2026-10-05.md; task lab-47.

## Greg, 5 Oct 01:55: Jolt for the whole game; player uses the same rigged base as enemies; acid rain is NOT an established concept (lab demo only, off in the game); when unsure, default behind a dial and note it.

## Greg, 5 Oct 02:10: v0.1 enemies, ending, Higgsfield 150, backlog, and "bingyanger"/"Support Unit" are placeholder joke names (no lore on them). See data/greg_playtest_b_2026-10-05.md.

## Greg, 5 Oct 02:25: vehicles with our destruction and BeamNG-style driving (task lab-53, backlog).


---
# Source: data/greg_playtest_2026-10-04.md

# Greg playtest, 4 Oct 2026 (controller, demo build)
- Controller buttons not properly bound; menus and binds not made FOR controller (PadBridge fakes keys/mouse).
- Map is horrendous, makes no sense, looks poor, has a dumb invisible "demo contract" barrier.
- Want a cohesive tunnel network for the underground facility (Higgsfield or similar) so the whole start section can be walked with NO splash transition screens for doors or elevators.
- Third-person combat is broken.
- Demo must reset to a fresh start every time (DONE on branch claude/menu-pad-fix: world_history.begin_demo wipes the demo save). Things past the vat break-out were bugged from stale state.
- The restraint you hold at the start is garbage.
- Third-person body model has no head and massive shoulders.


---
# Source: data/greg_playtest_b_2026-10-04.md

# Greg playtest B, 4 Oct 2026 evening (voice-dictated, wave3 build). His words win.
Screenshot: data/greg_playtest_b_screenshot_2026-10-04.webp (prompt "E CUT THE POWER LINE", objective box CLIPPED at the right screen edge "HE LEFT THRO...", "SERVICE ARCADE // STAFF ONLY", "A FIELD DRESSING AND FOUR ROUNDS // SOMEBODY HID THESE").
- He sped through the start because it is dumb/convoluted ("removing the wires"). "It's good, but it needs to be better."
- Why am I holding this stupid piece of a belt? I have no hands and then I crawl out. The VAT BREAKOUT is still shit and makes no sense.
- No LIQUID physics in the game. No DESTRUCTION physics.
- Movement is dumb: shift/ctrl sprint then slide.
- "Inspect what I hold" shows TEXT. He does NOT want text inspections.
- Objective says "Get revenge // he left through that door", then escape the facility, but the door says STAFF ACCESS REQUIRED: doesn't make sense.
- Fire axe: "I can't even hit with it. What am I supposed to do?" Pressing nearly every button.
- Wizard eyes are cool. Take the clothes off the subject: unclear (a spirit?). "awake, afraid".
- "Cut the power line": what does it do? "the line spits and dies, the bay goes dark". Hold forward, address a wound / dressing a wound: does not understand it. "All these little beans" (pickups/prompts). Convoluted and dumb.
- Frustration: usage is being spent and the game does not visibly change. Every task from now must show a visible change in the first 10 minutes, with before/after screenshots.

## Playtest C (same session, later). Screenshot: data/greg_playtest_c_screenshot_2026-10-04.webp
- Can bash the door with the shoulder and axe it: that works.
- EXAMINER BOSS: hit him twice and his HEAD is detached/broken (screenshot: head floating apart from a headless torso with jagged cloth planes). He dies fast. Not a boss fight.
- KEYCARD BUG: after killing the examiner "his key card and his codes are the staff door" but the player never gets a key: the staff door says it needs his key. "I literally killed him, where is his key." MUST FIX: killing him drops the keycard (visible, pick up), door opens.
- His cupboard: "Two field dressings and eight rounds" = underwhelming.
- NO INVENTORY / items menu at the start. Nothing shows what the player carries.
- Objective box still clipped at the right edge ("BEAT HIM, T...").
- Project folder is huge (~50 GB): he wants to know why.

## Playtest D (same night). Screenshots in images 9-12 of that chat; summary:
- Intro cutscene at the start played "ultra sped up" (check ATG/test speed flags or a time-scale leak).
- Outdoor Hunt map looks terrible (rusted blocks, mushrooms, black blob placeholder); changes agents made to the map are not visible.
- A random NPC dialogue popup (Rook Gantry: 'Put it down and walk away') appears with NO way to dismiss on his controls; trillions of UI elements on screen at once.
- Tab does not open the phone/menu. Inventory exists (FIELD INVENTORY, STAFF KEYCARD present in it) but he did not find how to open it; the staff door said it needed a key although the keycard IS in the inventory: the door check and the item disagree.
- BREACH TOOL: 'what is a breach tool', ugly model, cannot hold it, no arms, clicking does nothing. Breach the pressure gate puzzle ('hold J to scan the walls', vent, 'creep past it', 'lift fuse', 'reach the elevator') is incomprehensible. Wants the opening CUT DOWN to the actual game.
- Greg likes: the UI look and visual effects. He wants the game cut down to a small solid core.


---
# Source: data/greg_playtest_b_2026-10-05.md

# Greg, 5 Oct ~01:30, after first look at the mechanics lab
- "Genuinely this mechanics lab is awesome." Keep refining it to more quality, and polishing.
- The tank's liquid must NOT instantly dissipate. It must be an actual fluid, and the tank actual glass.
- Spill: pours out over a few seconds, spreads, pools; the pool PERSISTS (stays until drained, slowly toward a floor grate) - mix of "pour+pool+slow drain" and "stays like blood pools".
- Fluid, all of it "and more": a real surface in the tank that sloshes when hit or walked into and drops as it drains; a thick flowing pour (SPH-style particles that collide, gloopy, not loose beads); wading leaves ripples, splashes and wet footprints, things float; thick red see-through medium with refraction, bodies/objects float inside.
- Glass: real see-through glass with reflections; cracks spread with each hit before it breaks; shards fly, fall and stay on the floor with physics; liquid pressure helps burst it outward.
- Gameplay: the liquid conducts electricity: the shock staff on a wet floor shocks whoever stands in it.

# Greg, 5 Oct ~01:45: destruction (this REPLACES the 25 Sep "authored stages, not Teardown" answer; newest wins)
- Make destruction "as much like Teardown as possible", including the ground being DIGGABLE.
- Look: MIX: smooth ground digging (marching-cubes / SDF terrain), chunky VOXEL walls and buildings that break into cubes.
- A TOUGHNESS SCALE, 5 tiers: 1 soft (dirt, wood, flesh) / 2 medium (brick, drywall) / 3 hard (concrete, steel sheet) / 4 armoured (bunker, vault) / 5 sealed (elite bunkers, story doors). Melee breaks 1-2, guns 1-3, explosives 1-4, special charges 5.
- What beats the top tiers: explosives (charges, grenades, breach launcher), heavy carried tools over time (thermal drill, cutting torch), chaos magick at high altitude, vehicles ramming.
- Why: explore tunnel networks underground and BLAST your way into a hidden underground city network or an elite's buried bunker; central to raiding and warring (commanding small armies, faction group fights).

# Greg, 5 Oct ~01:55 (question boxes before sleep)
- Physics: SWITCH THE WHOLE GAME TO JOLT (ragdolls, debris, destruction). Re-run the tests after.
- Player body: the SAME rigged base body as enemies, customised by the intake.
- Acid rain: Greg is "not sure about acid rain being an actual concept". Keep it only as a lab demo behind a dial, OFF by default in the real game; do not build gameplay on it.
- Overnight: when unsure, pick a sensible default behind a dial and note it for Greg in DESIGN/REMASTER_LOG.md; do not stop.

# Greg, 5 Oct ~02:05: organs, cybernetics and the X-ray as ONE system
- Rupturable organs and a cohesive cybernetic + organ system that pairs with the X-ray. Bodies take realistic wounds: cut a hole in someone's chest, shoot their stomach open or their ribs, then MANUALLY rip out the heart or another organ, which you can see in X-ray mode.
- X-ray is how you PEEP someone's cybernetics before deciding to fight them. It shows: where implants and armour plates are; what each implant does (short tags: reflex booster, lung filter); how healthy their organs are and what is already damaged; their loot value.
- Ripping out: on a corpse (harvest) AND as a finisher on a downed living enemy, but ONLY through a wound you actually made: "you obviously need to damage them or be able to rip into their internal organs and skeletons". No hole, no rip.
- Ruptured organs fail in their own way: lungs = breathless, no sprint; heart = fast death; liver/gut = slow bleed; brain = drop. Cybernetic organs can be shorted or overloaded (the shock staff). You can swap harvested organs (natural or cybernetic) into yourself. Harvested organs sell on the market.
- Look: realistic and wet, Sniper Elite X-ray quality, low-poly but anatomically right.

# Greg, 5 Oct ~02:10 (v0.1 clarifications)
- v0.1 enemies, kept SMALL: 2-3 numbered CellOutz guards in the service arcade (shock staffs, pistols), one freed vat subject that turns hostile, the Lower Works sentinel (a machine with armour plates for the X-ray), plus the examiner boss.
- NAMES: "bingyanger" and the "Support Unit" are an inside joke / PLACEHOLDERS, not serious lore. Greg will write the facility and world lore later. Do not build lore, dialogue or UI text around those names; keep them as internal ids only.
- v0.1 ending: blinding daylight, silence then wind, WIZARDS ONLY FOOLS title drop over the first view, then a "to be continued" card.
- Higgsfield overnight: YES, up to ~150 credits, only for the brain-hack video, X-ray anatomy plates, blood and glass decals. Log every job in the ledger.
- When v0.1 jobs are done or blocked: polish passes (feel, sound, lighting, performance); a sound pass (footsteps, hits, ambience, examiner voice placeholder); start v0.2 (Black Mirror pickup; the placeholder support unit and freed subjects); more disciplines (Duelist, Shade) in the lab.

# Greg, 5 Oct ~02:20 (last questions)
- Weapon names: INDUSTRIAL PRODUCT names in the CellOutz catalogue style (examples he liked: HOTLINE CLEAVER, PRODSTAFF). Builders may use those two as working names.
- Facility look for v0.1: lighting (dark, harsh sick green-white pools, red only on danger), grimy real textures (no flat boxes) and story props (tanks, cables, monitors) ALL EQUALLY.
- Difficulty: hard but fair, soulslike, checkpoints close together.
- Morning report: detailed per job, then launch the newest build for him.

# Greg, 5 Oct ~02:25: vehicles
- The lab's vehicle pad means we need VEHICLE MODELS that use our destruction mechanics, with a BeamNG-style driving system (soft-body feel: real crumple, parts that bend and come off, engine damage).

# Greg, 5 Oct ~02:30: systems must combine (the flag example)
- He loves the flag waving in the wind in the lab. The goal once each mechanic works alone: they COMBINE. Example: the flag waves in the wind, you shoot it, the bullet rips a hole and it is slightly destroyed, and it keeps blowing in the wind, more scuffed. Every mechanic should interact with the others like this (wind x cloth x bullets x destruction x fire x liquid).

# Greg, 5 Oct midday
- "The map is the main thing in the demo that needs to be fixed." Facility map (job5) is the top priority.
- The examiner/doctor "looks wayyy too human-like, that cursed Higgsfield model sucks". Remove the generated Higgsfield examiner skin (model_skin / M1) everywhere. He uses the same stylised low-poly rigged base as everyone else, dressed as the examiner (stained coat, surgical mask, loupes), until Greg draws him.
- Teardown destruction and BeamNG-style vehicles are still not in the game (lab-47 building, lab-53 bumped to 98).
- VATS: wants a SLOWED-DOWN CUTSCENE of the bullet entering and rupturing (Sniper Elite kill cam: follow the round, X-ray through skin, organ/bone rupture). BUG: when aiming down the sights the gun's iron sights block the whole screen because the weapon models are scuffed (wrong scale/position/FOV).
- The Black Mirror phone "still does not cohesively work". Make it one working device: raise/lower, its pages (MAP, camera with night vision, inventory link) navigable on the pad, consistent look, no broken pages.
- The DEPTH MAP camera mode "practically does nothing" and is not the interesting TouchDesigner node-based look he wants (blob tracking / LiDAR grey-to-white point look, block-tracked boxes on bodies and objects, depth contours, scan lines that sweep; designed like a TD operator graph, built as a Godot shader).
- Wizard eyes: cool for now but "way too visually disgusting, some neon horrible green". Restyle: keep the spirit/faces idea, lose the neon green; use the house palette (bone, copper, deep red, a sickly desaturated green at most), subtle and readable.
- Executing a downed enemy is "still super bugged". Fix the execution/finisher on downed bodies (positioning, animation, damage, camera, the organ-rip finisher path).
