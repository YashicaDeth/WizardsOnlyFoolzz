# Generated assets

Greg, 25 September 2026: "let them all use Higgsfield to generate." Every
generated asset in the game gets one line here, so it can always be told
apart from Greg's own art and replaced by it.

| File | Tool | Prompt | Date | Lane | For |
|---|---|---|---|---|---|
| `generated/sigils/rune_demonic.png` | Higgsfield | 1a, the rune, demonic | 2026-09-25 | A (breakout) | The sigil that takes your brain. Checkerboard was baked in; keyed by colour (red iron kept) and hole-filled. |
| `generated/sigils/metatron_plate.png` | Higgsfield | 1d, Metatron's cube | 2026-09-25 | D (loading screens) | Sacred-geometry loading plate. Baked checker cut with a circle mask. |
| `generated/sigils/sri_yantra_plate.png` | Higgsfield | 1d variation, Sri Yantra | 2026-09-25 | D (loading screens) | Sacred-geometry loading plate. Baked checker cut with a circle mask. |
| `generated/anatomy/xray_skull_bullet.png` | Higgsfield | 3b, skull and brain | 2026-09-25 | D (kill cam) | X-ray kill-cam plate. Black background, no alpha needed. |
| `generated/anatomy/xray_ribcage_bullet.png` | Higgsfield | 3b, ribcage and heart | 2026-09-25 | D (kill cam) | X-ray kill-cam plate. Black background, no alpha needed. |

Still to bring in (shared in chat as previews only; drop the files into
`game/art/generated/`): the doctor portrait (2a; crop the garbled text), the
full-body X-ray with chip (3a; crop the stamps), the septagram plate, the
natal chart, the Tree of Life and the heart X-ray.

Second set (25 September), waiting on `lfs.github.com` to push. Converted
and held outside the repo until then:

| File | Tool | Prompt | Date | Lane | For |
|---|---|---|---|---|---|
| `generated/video/loop_rune_pulse.ogv` | Higgsfield (Seedance) | V2, rune heartbeat | 2026-09-25 | A | Breakout sigil, load-in flash, title |
| `generated/video/loop_vat_xray_body.ogv` | Higgsfield (Seedance) | V1, X-ray body in the vat | 2026-09-25 | A | Torture load-in, intake right panel |
| `generated/video/loop_pyramid_orbit.ogv` | Higgsfield (Seedance) | V3, 33-tier pyramid orbit | 2026-09-25 | D | Pyramid loading screen, World Index |
| `generated/video/loop_satellite_scan.ogv` | Higgsfield (Seedance) | V4, satellite scan | 2026-09-25 | D | Phone MAP page |
| `generated/video/killcam_kidney.ogv` | Higgsfield (Seedance) | G7, kidney kill cam | 2026-09-25 | D | Kill cam |
| `audio/generated/hf_*.wav` (8) | Higgsfield (Seed Audio) | Section 9 sound list | 2026-09-25 | A | Names to confirm with Greg |

## Asset-generator imports

From the tools in DESIGN/ASSET_TOOLS.md. Placeholder until Greg's own art.

| File | Tool | Model | Licence | Prompt | Date | Lane | For |
|---|---|---|---|---|---|---|---|
| `generated/items/hornee_plush.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 multiview from two cut-outs of Greg's own Hornee plush photos (front, back), hand and background removed by GPT Image 2.5 edit | 2026-09-29 | claude | Hornee as a 3D object: the plush in the Brain Index / companion |
| `generated/items/breach_nine.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (prompts in Higgsfield history, 29 Sep) | 2026-09-29 | claude | held item model: breach_nine |
| `generated/items/black_mirror.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (prompts in Higgsfield history, 29 Sep) | 2026-09-29 | claude | held item model: black_mirror |
| `generated/items/shiv.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (prompts in Higgsfield history, 29 Sep) | 2026-09-29 | claude | held item model: shiv |
| `generated/items/restraint.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (prompts in Higgsfield history, 29 Sep) | 2026-09-29 | claude | held item model: restraint |
| `generated/props/cctv.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (CCTV lifted from the M8 prop sheet) | 2026-09-29 | claude | lab set piece: cctv |
| `generated/props/surgical_lamp.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (CCTV lifted from the M8 prop sheet) | 2026-09-29 | claude | lab set piece: surgical_lamp |
| `generated/props/bone_drill.glb` | Higgsfield | per prompt | per Higgsfield terms | Tripo H3.1 image-to-3D from a GPT Image 2.5 image in the house PS2 style (CCTV lifted from the M8 prop sheet) | 2026-09-29 | claude | lab set piece: bone_drill |
| `generated/characters/examiner.glb` | Higgsfield | per prompt | per Higgsfield terms | Meshy multi-image to 3D, textured and rigged (A-pose, 1.8 m), from four views redrawn from Greg's M1 examiner turnaround sheet | 2026-09-29 | claude | the examiner's model (M1), replacing the stand-in |
| `generated/characters/examiner_walk.glb` | Higgsfield | per prompt | per Higgsfield terms | Meshy 3d_rigging with a canned walk clip (walk id 30 / idle id 0) on the examiner model | 2026-09-29 | claude | the examiner's walk animation |
| `generated/characters/examiner_idle.glb` | Higgsfield | per prompt | per Higgsfield terms | Meshy 3d_rigging with a canned idle clip (walk id 30 / idle id 0) on the examiner model | 2026-09-29 | claude | the examiner's idle animation |
| `generated/items/chassis_greatsword.glb` | Higgsfield | tripo_h3_1_image_to_3d | per Higgsfield terms | Tripo H3.1 image-to-3D (7k faces) from a GPT Image 2.5 side view: two-handed greatsword cut from rusted truck chassis steel, tyre-rubber grip, one dim red LED on a bolted circuit board; Dark Souls x light cyberpunk, Mad Max scavenger forge, PS2 style | 2026-09-30 | claude | sword variant: chassis_greatsword |
| `generated/items/leafspring_longsword.glb` | Higgsfield | tripo_h3_1_image_to_3d | per Higgsfield terms | Tripo H3.1 image-to-3D (7k faces) from a GPT Image 2.5 side view: longsword forged from a car leaf spring, exhaust-pipe crossguard, spark-plug pommel, faint dead cyan line in the fuller; Dark Souls x light cyberpunk, Mad Max scavenger forge, PS2 style | 2026-09-30 | claude | sword variant: leafspring_longsword |
| `generated/items/sawback_sabre.glb` | Higgsfield | tripo_h3_1_image_to_3d | per Higgsfield terms | Tripo H3.1 image-to-3D (7k faces) from a GPT Image 2.5 side view: curved sabre with a circular-saw-blade spine, cog-gear guard, taped grip; Dark Souls x light cyberpunk, Mad Max scavenger forge, PS2 style | 2026-09-30 | claude | sword variant: sawback_sabre |
| `generated/items/railspike_estoc.glb` | Higgsfield | tripo_h3_1_image_to_3d | per Higgsfield terms | Tripo H3.1 image-to-3D (7k faces) from a GPT Image 2.5 side view: estoc ground from railway rail, chain-link hilt, faded hazard paint, cracked capacitor wired to the grip; Dark Souls x light cyberpunk, Mad Max scavenger forge, PS2 style | 2026-09-30 | claude | sword variant: railspike_estoc |
| `generated/textures/tunnel_wall_512.png` | Higgsfield | gpt_image_2_5 | per Higgsfield terms | house-style seamless tileable facility tunnel wall texture (near-black steel, dried blood, copper, acid green), 1024 downscaled to 512 | 2026-10-04 | art-tunnels-07 | facility tunnel kit wall surface |
| `generated/textures/tunnel_floor_512.png` | Higgsfield | gpt_image_2_5 | per Higgsfield terms | house-style seamless tileable facility tunnel floor texture (near-black steel, dried blood, copper, acid green), 1024 downscaled to 512 | 2026-10-04 | art-tunnels-07 | facility tunnel kit floor surface |
| `generated/textures/tunnel_ceiling_512.png` | Higgsfield | gpt_image_2_5 | per Higgsfield terms | house-style seamless tileable facility tunnel ceiling texture (near-black steel, dried blood, copper, acid green), 1024 downscaled to 512 | 2026-10-04 | art-tunnels-07 | facility tunnel kit ceiling surface |
| `generated/textures/tunnel_door_512.png` | Higgsfield | gpt_image_2_5 | per Higgsfield terms | house-style seamless tileable facility tunnel door texture (near-black steel, dried blood, copper, acid green), 1024 downscaled to 512 | 2026-10-04 | art-tunnels-07 | facility tunnel kit door surface |
| `generated/tunnels/tunnel_door_frame.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (4k faces): square riveted near-black steel door frame for a 4 m tunnel, copper bolts, dried-blood rust; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit door piece: frame around the sliding door |
| `generated/tunnels/tunnel_vent.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (3k faces): rusted steel louvre vent grate in a copper-bolted frame, acid-green grime; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit vent piece: grate in the dead-end wall |
| `generated/tunnels/tunnel_pipe_run.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (4k faces): straight run of three rusted pipes and a copper cable bundle on wall brackets, valve wheel; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit pipe_run piece: pipes along the wall |
| `generated/tunnels/tunnel_lift_cab.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (5k faces): open freight elevator cage cab, riveted near-black steel posts, mesh sides, copper trim; PS2 low-poly | 2026-10-04 | art-tunnels-07 | facility lifts: cage dressing inside FacilityElevator cabs |
| `generated/tunnels/tunnel_rib.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (3k faces): rectangular portal rib of riveted steel I-beams with corner braces; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit: steel rib at every cell joint |
| `generated/tunnels/tunnel_bulkhead.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (4k faces): sealed square riveted steel bulkhead with crossbrace, capped pipe stub, hatch wheel; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit dead_end piece: end wall |
| `generated/tunnels/tunnel_lamp.glb` | Higgsfield | tripo_3d | per Higgsfield terms | Tripo text-to-3D (2k faces): caged ceiling bulkhead lamp on a copper mounting plate; PS2 low-poly | 2026-10-04 | art-tunnels-07 | tunnel kit: lamp cage over each lighting pool |
