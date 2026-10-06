# Feature checklist (Greg's wants that fit the project)

Status 6 Oct 2026. [x] in the game, [~] partly / lab only, [ ] not yet.
Builders: this is the scope. A feature that is not on this list needs Greg's yes.
Pitch: a genre-bending soulslike with interesting combat disciplines;
cyberpunk-ish post-apocalyptic biopunk occult horror; pad first.

## v0.1 "Escape" demo (finish before anything else)
- [x] START, controller-or-keyboard chooser, intro cutscene (never changed)
- [x] Short pad-only NEURAL INTAKE
- [ ] Customisation that feels real: face sliders on real shape keys, build and height, skin/scars/grime/hair, choices with small gameplay effects (cust-91)
- [ ] Inventory that works: Souls-style grid in Pause plus d-pad quick slots; equip weapons, organs, implants; route pickups land in it (inv-90)
- [~] Wake in first person in red liquid; tear cords, glass cracks and bursts, flood (vat room pass imp-66 queued)
- [~] Pick 2 of 4 disciplines on the brain screen (Brawler, Marksman, Duelist, Shade; Greg 6 Oct), active in the route (dec-89, route-88)
- [x] Examiner boss: telegraphed scalpel/syringe, parry and riposte, desperate phase, keycard opens the staff door
- [~] One facility map with real lifts, no loading screens: artery, arcade, Lower Works, heat lift (map-84 landed 5c18d817: lit Lower Works, arcade cover, lift panels; lift cab rides still near-black)
- [x] Enemies: numbered guards, freed vat subject, sentinel (shoot the eye, hit the core)
- [~] Death: short vat regrowth, then the nearest checkpoint (Greg 6 Oct, dec-89); bloodstain should be a dark pulsing organ-sigil, not the orange ghost
- [x] Ending: daylight, silence then wind, title drop, TO BE CONTINUED card (fix-78 tidies it)
- [ ] A real pad playtest by Greg start to finish, the five worst problems fixed, tag v0.1-escape

## Combat (soulslike core)
- [x] Souls layout everywhere: R1/R2 attacks, L1 block, L2 parry, Circle roll, R3 lock-on
- [x] HOTLINE CLEAVER (heated vibro cleaver), PRODSTAFF (shock staff), MERCY NINE pistol
- [x] Aim down the barrel, stick-click to zoom further
- [x] Hitstop, stagger, riposte windows
- [~] VATS: L2+R2 slow-mo targeting and a bullet kill cam (works; the iron sights still block the screen)
- [~] Executions on downed enemies; ragdoll on every death and execution on the route (Greg 6 Oct, dec-89)
- [~] First-person arms: swings, block, recoil, reload (the sleeves, gloves and cleaver still look like stand-ins)
- [ ] Off-hand guns, 1H / 2H / dual wield, a weapon wheel (Bloodborne approach)
- [ ] Cleaver heat and staff charge as real resources, plus extra staff moves (Greg's call)
- [ ] Third-person combat camera that works as well as first person

## Disciplines (playstyles, not weapon classes)
- [x] Brawler, Marksman
- [~] Duelist (parry into riposte), Shade (rear takedowns, throwables, darkness, stalking crouch): lab station only
- [ ] Wizard (includes summoner), and the other two of the six
- [ ] A strong look for each: stance, trail, swap flash, HUD lobe, brain-screen card (imp-65 + Higgsfield art-69)
- [ ] An Illithid-style skill tree per discipline; unlock by playing (you can also unlock early)

## Body, organs, cybernetics
- [~] Every person shares one rigged low-poly base; flesh skin, real faces (faces smeared, neckline jagged: fix-74)
- [ ] A player model Greg likes (player-81: 2-3 looks to pick from)
- [~] Wounds open the chest/stomach/ribs; rip organs out by hand; install them in yourself or sell them (lab only)
- [~] X-ray scan: implants, armour, organ health, loot value (lab only)
- [~] Cybernetics short out from the shock staff (lab only)
- [ ] The whole organ/X-ray system on the route guards and the examiner
- [x] Jolt physics, ragdolls, body cutting

## World physics (Teardown / BeamNG)
- [~] Real liquid that pours, pools, drains, ripples, conducts shock, with sound (still beady; remaster queued)
- [~] Real glass: cracks in stages, bursts, shards stay
- [~] Voxel walls, 5 toughness tiers, diggable ground with soil layers, charges (lab only)
- [ ] Destruction in the facility: a weak wall to a stash, an armoured door that needs a charge
- [~] Smoke, sparks, dust (imp-63 built; landing it is queued)
- [~] BeamNG-style cars with crumple, loose parts, GTA door entry, jammed or torn doors (lab only)
- [ ] Systems combine: cloth flag in the wind, bullets tear it; liquid puts out fire; wet floors change footsteps (lab-54)
- [ ] Underground cities, bunkers, raiding (later, after v0.1)

## Black Mirror (the phone)
- [~] Raise and lower with one button; MAP page, night-vision camera, link to inventory (v02-51 now priority 95)
- [ ] TouchDesigner-style depth camera: LiDAR depth, contours, scan line, tagged boxes on bodies, useful in the dark
- [ ] Picked up in the examiner office as part of the demo

## Look, HUD, feel
- [~] Each facility zone its own identity; harsh green-white light pools; red only for danger; grimy story props
- [~] HUD face: BODYCAM by default (Greg 6 Oct; X-ray and mask stay in Pause); the 3 vials reworked into a readable rack (imp-68)
- [~] Wizard eyes in a palette Greg likes (the neon green was rejected)
- [~] Drugs: three classes, tolerance, a TouchDesigner-style trip, smoking with real smoke (lab only; the Hunt still uses old smoking)
- [ ] Sound pass: swings, hits, liquid, glass, ambience mixed and heard by Greg (polish-50)
- [ ] 144 fps on the RTX 2060 SUPER across the whole route at 1080p, measured

## Mechanics lab
- [x] Stations: liquid, bodies/X-ray/organs, destruction/digging, weapons, cars, disciplines, drugs/smoke
- [ ] Decluttered into labelled bays, the Start menu teleports to each, short neutral text (tidy-80)

## After v0.1 (ideas that fit, need Greg's go)
- [ ] More escape routes: drains, a doctor chase
- [ ] The surface: the first real world area past the gate
- [ ] An AI playtester bot playing the route every night (a playbot base exists)
- [ ] Acid rain stays a lab demo only, not in the game
