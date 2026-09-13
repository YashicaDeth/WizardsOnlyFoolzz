# Six agents, one game — the split

Written 2026-09-13. Supersedes the four-seat table in `AGENT_SPLIT.md` for
allocation only; **every rule in that file still applies** and is not repeated
here. Read `AGENT_SPLIT.md`, `AGENT_BRIEF.md` and `CHECKLIST.md` first.

`CHECKLIST.md` is at **1,122 open / 513 done** across 51 working sections. This
is how the remaining work divides six ways without two agents touching the same
file family.

**Give each agent only the lane below that names it.** Each lane is written to
be read cold.

---

## The rules that cost us the most

1. **Your own worktree. Always.** `git worktree add ../atg-lane-N -b lane-N`.
   Working directly in `P:\GameDev\AllusionsTooGrandeur` has broken the build
   three times.
2. **Never `git add -A`.** Five other agents have work in flight.
3. **One owner per file family.** The tables below are the authority. Need a
   file you do not own? Ask for an API, do not reach in.
4. **Never claim a visual result you have not looked at.** Capture the PNG, open
   it, say what is in it. Windowed Godot runs need `--position 2240,320`.
5. **Tick your own checklist lines in your own commits**, and write the `vN+1`
   line when you close a `vN`.

---

## The allocation at a glance

| Lane | Name | Sections | Open |
| --- | --- | --- | --- |
| **1** | The body and the hand | B, M, O, V, AD, AF, AN | 167 |
| **2** | The look | A, G, G7, H, W, X, AB, AC, AS | 164 |
| **3** | The cosmology and the law | E, K, AA, AE, AI, AJ, AQ, AU, AV | 201 |
| **4** | The spine and the economy | F, J, Q, R, T, U, AK, AL, AR | 180 |
| **5** | The screens and the voice | C, D, I, L, N, S, Y, AM, AT | 212 |
| **6** | The demo and what ships | P, Z, AG, AH, AO, AP, AW | 198 |

---

## Lane 1 — the body and the hand

*How the game feels to move and to fight in.* Greg's stated priority.

| Owns | |
| --- | --- |
| `game/bone_yard_hunt.gd` | camera, input, combat resolution |
| `hunter_motor.gd`, `hunter_body_motion.gd`, `limb_momentum.gd` | movement |
| `hunter_arsenal.gd`, `ballistics.gd` | weapons |
| `impact_feel.gd`, `clinch.gd`, `combat_response.gd`, `kill_cam.gd`, `downed_resolution.gd` | the hit |
| `anatomy_component.gd`, `body_mesh.gd`, `gore_chunks.gd`, `wound_catalog.gd`, `blood_veil.gd` | the body |
| `vehicle_interior.gd`, `dash_cluster.gd`, `field_camera.gd` | driving from inside |

Order of work:

1. **AD** — jumping, vaulting, wall running, and a HUD with nothing floating in
   a corner. There are already `wall_run_test.gd` and `anatomy_traversal_test.gd`
   in `game/tests/` — run them before you write anything.
2. **AF** — a round is a raycast today. Make it a thing that travels.
3. **AN** — the body is the weapon.
4. **O** and **M** — combat and camera, both mid-ladder.
5. **V** — the road. ⚠ `arcade_vehicle.gd` chassis and visuals belong to Lane 2.
   You own the inside of the car, they own the outside of it.

---

## Lane 2 — the look

*What the world is made of.* The standing complaint is "everything looks like
boxes", and three texture passes did not fix it, because a texture does not
change an outline. Read `silhouette.gd` first.

| Owns | |
| --- | --- |
| `world_look.gd`, `silhouette.gd`, `celloutz_grunge.gd`, `art_set.gd` | materials and dressing |
| `ashbloom_world_generator.gd`, `ashbloom_pathfinder.gd` | region geometry |
| `arcade_vehicle.gd`, `rift_derby.gd` | chassis and derby visuals |
| `light_warp.gd`, `world_clock.gd`, `contaminated_air.gd`, `garments.gd` | night and weather |
| `psychedelic_rig.gd`, `game/shaders/**`, `point_cloud.gd` | the pipeline |
| `game/art/derived/**` | generated textures |

Order of work:

1. **AS** — night. The handheld throws real light, raising it occupies a hand,
   and its light is what gives you away. Anvil crawlers, not flashes.
2. **AB** — destruction, then **AC** once AB is landed. **AC1.1 is still blocked
   on Greg**: simulated fluid, or painted fluid done well?
3. **G / G7** — the arena. Recorded failure: `ARENA_SCALE` 2.15 and 2.45 both
   emptied the heat out of the fight. It needs authored geometry, not a scale.
4. **W**, **X**, **H**, then the **A** tail.

**Not negotiable:** never write to `C:\Users\Greg\Desktop\Art Collections`. It is
read-only source. Derived art goes to `game/art/derived/` and must rebuild from
scratch.

---

## Lane 3 — the cosmology and the law

*The biggest design surface and the least built.* Read `DESIGN/COSMOLOGY.md`
before writing a line.

| Owns | |
| --- | --- |
| `wire_net.gd`, `carry.gd`, `player_faction.gd` | reach, rank, selling |
| `cosmology_factions.gd`, `demon_hierarchy.gd`, `demon_ambition.gd`, `ascent_entities.gd` | who is out there |
| `the_four_horsemen.gd`, `godhead.gd`, `gods.gd`, `modern_gods.gd`, `sephiroth.gd` | the tiers above |
| `goetic_seals.gd`, `natal_sigil.gd`, `ritual_app.gd`, `ritual_ledger.gd`, `meditation.gd` | the practice |
| `substances.gd`, `undying_flame.gd`, `boons.gd` | the materia |
| `DESIGN/COSMOLOGY.md`, `FACTIONS.md`, `RITUAL_AND_KARMA.md` | |

The shape, so you do not reinvent it: **CellOutz** are the underground demon
faction, **wizardsonlyfoolz** the ascending mage collective — as above, so below.
The player is a CellOut wizard, half demon and half angel, hunting to get God's
attention. The Four Horsemen rotate through CellOutz leadership; the Seven
Deadly Sins are a lesser tier. Karma and magic **deliberately bastardise
Thelema** and are explicitly not Crowley's reading.

Order of work: **AA** (the land takes a side) → **AJ** (chaos magick v2) →
**AE** (nobody has ever come to arrest anybody) → **K** / **E** remainder →
**AI**, **AU**, **AV**, **AQ**.

⚠ **K2 is still blocked**: Greg has not named the four Horsemen.
⚠ You will want `world_history.gd`. **Lane 4 owns it.** Ask for an API.

---

## Lane 4 — the spine and the economy

*The ledger everything else reads, and what money does.* Nobody but you adds
fields to `WorldHistory`.

| Owns | |
| --- | --- |
| `world_history.gd` | the ledger |
| `rival_registry.gd`, `rival_tactics.gd`, `defeat_router.gd` | rivals and what defeat means |
| `run_lifecycle.gd`, `route_endings.gd`, `extraction.gd`, `witness_ledger.gd` | the run |
| `asset_network.gd`, `broken_web.gd`, `signal_field.gd`, `wire_radio.gd`, `satellite_view.gd` | the wire |
| `motherboard.gd`, `keys_card.gd`, `front_door.gd`, `character_archive.gd` | the bank and the door |
| `game/tests/**` | |

Order of work: **AL** (the bank, and what runs under the street) → **AK** (the
agency that owns the sky) → **AR** (the tree, and the work) → **R**, **Q**,
**T**, **U** → **F** and **J** remainder.

⚠ **All of T is blocked** on the open question: *what persists between runs?*
Roguelike structure and "bodies remember" pull against each other. Start on AL
and AK, which do not depend on the answer.

**F4.2 note:** LimboAI is adopted narrowly, in `rival_tactics.gd`, for a layer
that did not exist. Do not port the working encounter state machine into
behaviour trees.

---

## Lane 5 — the screens and the voice

*The interface as its own medium.* House rule **I0**: no screen is a list of
text in a box. It never meant *no information* — that misreading stripped every
readout out of the derby. A gauge is an object.

| Owns | |
| --- | --- |
| `handheld_device.gd`, `black_mirror.gd`, `cab_screens.gd` | the devices |
| `world_index.gd`, `living_map.gd`, `pin_board.gd` | the map and the Board |
| `celloutz_type.gd`, `celloutz_hud.gd`, `celloutz_menu_fx.gd`, `code_rain.gd`, `gothic_field_hud.gd` | the vocabulary |
| `radial_menu.gd`, `crystal_ball.gd`, `warning_card.gd`, `subject_icon.gd` | |
| `vat_chamber.gd`, `vat_intake.gd`, `intake_direction.gd`, `hunter_appearance.gd`, `character_sheet.gd` | the vat |
| `body_inspector.gd`, `part_viewer.gd`, `world_xray.gd`, `xray_cursor.gd`, `xray_specimen.gd`, `damage_portrait.gd`, `implant_catalog.gd` | reading a body |
| `proximity_voice.gd`, `cast_names.gd` | speech |

Order of work: **C** (kill the six-panel problem) → **I** → **L** → **N** →
**S** → **D**, **AM**, **AT**, **Y**.

⚠ **I0.9 is blocked** on cast display names.
⚠ **I3 is blocked**: is celloutz.xyz mirrored or fictionalised?
⚠ Open question for L: is the Board a physical wall you walk to, or does it live
on the black mirror?

---

## Lane 6 — the demo and what ships

*The only lane judged on whether a stranger can play it.* Largest section in the
file (**P**, 45 open) and the one everything else eventually funnels into.

| Owns | |
| --- | --- |
| `opening_director.gd`, `opening_audio.gd`, `interstitial.gd` | the opening |
| `country_town_menu.gd`, `pause_gate.gd`, `dev_affordances.gd` | front of house |
| `reality_misfire_director.gd`, `interactive_allusions_artwork.gd` | |
| `export_presets.cfg`, `P:\GameDev\build\**`, `game/captures/**`, `game/reports/**` | |

Order of work — deliberately start on the parts that do not wait on other lanes:

1. **AO** (the world as it fell), **AH** (the Cloud, and the room you remember it
   from), **AP** (the captured spirit) — 104 open between them, all yours alone.
2. **AG** — the 12 September playtest findings, 22 still open.
3. **P** — the demo. Integration; expect to chase the other five lanes.
4. **Z** and **AW**. `Z1.1` is done: `P:\GameDev\build\windows\WizardsOnlyFools.exe`
   runs. Zipping that folder is how you hand the game to somebody.

**Rule 3 is your rule more than anyone's: every hard cut is a bug.**

---

## Still blocked on Greg

These do not stop work, but each changes what gets built:

1. The four **Horsemen's names** — blocks K2 (Lane 3).
2. **Cast display names** — blocks I0.9 (Lane 5).
3. **celloutz.xyz**: mirror the real site or fictionalise it — blocks I3 (Lane 5).
4. **What persists between runs** — blocks all of T (Lane 4), shapes the demo.
5. **AC1.1**: simulated fluid, or painted fluid done well — blocks AC (Lane 2).
6. Is the **Board** a physical wall, or does it live on the black mirror (Lane 5).
