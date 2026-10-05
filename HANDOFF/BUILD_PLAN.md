- 

- 

- 

Works order · v0.1 "Escape"4 Oct 2026

# Build Plan

The game plan holds every idea. This page holds only what gets built next, so there is **an actual game that works**: about 20 minutes, from pressing START to stepping out on the surface, on a pad or keyboard. Everything else is switched off for this build, not deleted. Parts come from free low-poly libraries on the internet wherever they exist, so nobody hand-builds what someone already made.

## 01What v0.1 is

In this build

- Menu, intro cutscene, short torture load-in

- Wake in the vat in real red liquid; quick intake (preset plus body and face)

- Brain screen: pick 2 of 2 working disciplines

- Breakout: tear cords, break glass, liquid floods out

- One facility map: vat floor, examiner office, service arcade, Lower Works

- Heated cleaver, shock staff, pistol; gore, sever, ragdoll on death

- Examiner boss, his keycard, the staff door

- A real elevator ride up; arrival on the surface ends the build

- Death respawns you in the vat with your bloodstain where you fell

- Simple inventory, one objective line, pause and settings, checkpoint saves

Switched off until v0.2+

- The other four disciplines, chip heat, brain skill board

- The Wire, the Board, the pyramid, territories, money

- Derby, drains route, doctor-chase route

- Drugs, cases and skins, voice NPCs, planes, Hornee

- Support Unit and bingyangers (they come back in v0.2)

- Text inspections, breach-tool puzzle, wall scan, fuse hunt, wound minigame

Why two disciplines: **Brawler** (heated cleaver and shock staff, heavy directional swings) and **Marksman** (pistol with aim down sights and VATS). They cover melee and guns with code that mostly exists already. The other four come one at a time once these two feel good.

## 02The big fix: real rigged bodies

Most of what looks broken (no head, huge shoulders, floating arms, limbs coming apart in ragdolls) comes from the bodies being assembled from loose procedural pieces with no skeleton. The fix is to use a **proper rigged low-poly humanoid** for every person and keep our anatomy system underneath it: wounds, organs and severing stay ours, they just ride on real bones.

- **Body:** a free CC0 rigged base character (Quaternius base characters, or a Mixamo-compatible low-poly human), with our PS1-style shader on top.

- **Animation:** Mixamo (free to use in games) and Quaternius animation sets for walk, run, attacks, hit reactions, deaths.

- **Ragdolls:** Godot's physical bones on that skeleton, with Jolt physics (built into Godot 4.4+). Tried in the mechanics lab first.

- **Gore:** each anatomy zone maps to a bone, so cuts, organs and severing follow the real skeleton.

## 03Where the parts come from

Free first, credited always, nothing ripped from commercial games. CC0 needs no credit but gets one anyway; CC-BY goes in `CREDITS.md` and the in-game credits.

 | Need | Source | Licence |

 | People | Quaternius base characters; Mixamo characters | CC0 · free for games |

 | Animations | Mixamo; Quaternius animation library | Free for games · CC0 |

 | Facility kit | Quaternius and Kenney modular sci-fi kits, our Higgsfield tunnel pieces, retextured grimy | CC0 |

 | Weapons and props | Poly Pizza, Quaternius, Kenney, CC0 low-poly models on Sketchfab | CC0 · CC-BY |

 | Textures | ambientCG and Poly Haven (already in use) | CC0 |

 | Anatomy | The CC-BY Sketchfab skeleton and organ models already listed for the X-ray | CC-BY |

 | Particles and VFX | Kenney particle pack, our own shaders | CC0 |

 | Sound | Freesound (CC0/CC-BY), Sonniss GDC bundles | Royalty free |

 | Cutscenes, plates, decals | Higgsfield (video, X-ray plates, blood and glass decals, surface vista) | Ours |

### Godot plugins

 | Plugin | Job | State |

 | Jolt physics | Stable ragdolls, debris, physics props | Built into Godot; test in lab, then switch |

 | Phantom Camera | Souls over-shoulder camera and lock-on framing both fighters | Add |

 | LimboAI | Enemy and examiner behaviour trees | Installed |

 | Dialogue Manager | Examiner lines and intake questions | Installed |

 | Terrain3D | The surface at the end of the build | Installed |

 | GdUnit4 | Tests | Installed |

Glass and walls break with pieces pre-cut in Blender's built-in Cell Fracture add-on, swapped in on the hit. Liquid is a shader surface inside the vat, GPU particles with collision for the pour, and pooling decals on the floor.

## 04The jobs, in order

Each job is one builder at a time on one piece. A job ends when the "done" line is true, not when the code compiles.

1

#### Mechanics lab
First · Oct 5

**Build:** One small test map inside the game: liquid tank, weather and acid rain, destruction wall, dummy row, vehicle pad.
**Parts:** Existing weather, blood pool, ground hole, breakable and vat-smash systems; CC0 props.
**Done:** Every station runs the same system the game uses, launched from `Start-MechanicsLab.cmd`.

2

#### Rigged bodies
Oct 5–6 · in the lab

**Build:** Swap the player and enemies onto a rigged CC0 humanoid; map anatomy zones to bones; physical-bone ragdolls on Jolt.
**Parts:** Quaternius or Mixamo body and animations.
**Done:** Head on, normal shoulders, arms right, a death ragdoll that stays in one piece unless something is cut off.

3

#### Moving and fighting
Oct 6–7 · in the lab

**Build:** Walk, sprint, crouch, jump, roll on the Souls pad layout; a heated vibro cleaver and a powered shock staff that hit, block and parry (the fire axe and sword are gone: 200 years on, nobody fights with a hardware-store axe); pistol with aim down sights; Phantom Camera lock-on.
**Parts:** Existing sword moveset, Souls roll, ADS; CC0 cleaver, staff and pistol models, retextured.
**Done:** You can kill a dummy and a fighting enemy with each weapon on the pad, and it feels weighty.

4

#### Waking in the vat
Oct 7–8

**Build:** After the intro, open your eyes underwater in red liquid; look down at your body; short intake on the pad; brain screen picks Brawler and Marksman; brain hack; tear cords; glass breaks; liquid floods; stand up.
**Parts:** Existing intake and vat scene; Higgsfield brain-hack video and decals; Cell Fracture glass.
**Done:** Four minutes from load-in to standing, every step clear on screen, no keyboard needed.

5

#### The facility, one map
Oct 8–9

**Build:** Vat floor, examiner office, service arcade and Lower Works joined by corridors on the facility grid, with the transit lift and the heat elevator as real rides.
**Parts:** Existing rooms; Higgsfield tunnel kit; CC0 modular sci-fi kit retextured with ambientCG grime.
**Done:** Walk from the vat to the elevator with zero loading screens and no invisible walls.

6

#### The examiner
Oct 9–10

**Build:** A real boss in his office: telegraphed scalpel and syringe attacks, about a 30-second fight. He drops his keycard; it opens the staff door; the cupboard has real loot.
**Parts:** Existing examiner fight; LimboAI; rigged body from job 2.
**Done:** Beating him always gives the card, and the door always takes it.

7

#### Death, saves, the screen
Oct 10

**Build:** Die and regrow in the vat; bloodstain at your corpse; checkpoint saves; simple inventory; one objective line; pause and settings; one-time button hints that match the pad.
**Parts:** Existing rebirth, field inventory, key hints and quantum saves.
**Done:** You can die, come back and carry on, and always know where to go.

8

#### Play it, fix it
Oct 10–11

**Build:** Greg plays the whole build on the pad. The five worst problems get fixed. Repeat.
**Done:** v0.1 is tagged and playable from `PLAY.cmd` before the account limits reset on 11 October.

### A feature is done when

- it works on the pad and on keyboard and mouse,

- there are no placeholder boxes in it,

- it holds 144 fps on Greg's machine,

- someone looked at it running, not just at a test result,

- and Greg played it and it felt right.
