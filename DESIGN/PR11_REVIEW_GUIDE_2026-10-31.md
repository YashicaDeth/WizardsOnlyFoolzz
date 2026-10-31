# PR #11 review guide — the `launch-latest` lane

`claude/launch-latest` → `codex/primary`. OPEN, **MERGEABLE**, 1,612 files,
**+173,719 / −1,943**.

That number is the whole problem: nobody reviews this as one diff, and the
branch cannot be cut into a "core" PR (see *Why there is no `lane/core`*). So
this guide does the only other honest thing — it gives the lane the seams a
branch split would have given it: fifteen chunks in dependency order, each with
the files worth reading and the suite that proves it, plus the six traps that
cost me real time while measuring it.

Everything below was run, not remembered. Gate results are from a clean
worktree at `b3e84180`.

---

## 0. Run a gate before you trust it

```bash
tools/run_tests.sh rigged_body_test player_look_test sword_moveset_test knockback_test
```

`tools/run_tests.sh` treats the **exit code** as the verdict and counts `FAIL`
lines on top of it, because the suites do not agree on how to report. That was
not paranoia: the note *"vehicle_damage prints failures=0 while every check is
skipped"* is true, and the reason is in trap T3. Exit code is the only signal
that survives a scene that never loaded.

Two rules for anyone reviewing this branch:

1. **Run gates on a clean worktree.** The shared checkout has in-progress edits
   that will read as body-block regressions (T1).
2. **A suite that errors does not fail — it hangs.** 200s timeout, exit 124,
   nothing printed (T2).

---

## 1. Body rig and melee core — read this first

The spine of the PR. `rigged_body.gd` (+1,611 — the largest single system
here) builds the anatomical body; `baseline_human.gd` (+383) owns the wound and
organ path that everything else calls.

| file | + | what it decides |
| --- | --- | --- |
| `game/systems/rigged_body.gd` | 1,611 | joints, zone extents, flesh, ragdoll handoff |
| `game/systems/nerve_rig.gd` | 746 | the exposed nerve/insulation look |
| `game/systems/melee_driver.gd` | 570 | stamina, buffering, guard, hitstop |
| `game/systems/sword_moveset.gd` | 411 | authored phases driving the rig |
| `game/systems/baseline_human.gd` | 383 | `hit()` — the 10-argument wound path |
| `game/systems/round_trails.gd` | 360 | the swing arc |
| `game/systems/player_look.gd` | 117 | which body the player wears |
| `game/systems/knockback.gd`, `souls_mover.gd`, `souls_roll.gd`, `souls_pad.gd`, `ragdoll_body.gd`, `scar_ledger.gd`, `organ_meshes.gd` | — | movement, dodge frames, ragdoll, scars, organ meshes |

**Gate** (all green at `b3e84180`, exit 0, `failures=0`):

| suite | checks |
| --- | --- |
| `rigged_body_test` | 36 |
| `player_look_test` | 23 |
| `sword_moveset_test` | 24 |
| `knockback_test` | — |
| `souls_roll_test` | — |
| `souls_pad_test` | — |

Also worth running: `ragdoll_body_test`, `scar_ledger_test`,
`melee_grip_clearance_test`, `two_handing_test`, `heavy_guard_break_test`,
`body_motion_test`, `third_person_head_test`.

`sword_moveset_test` **quits on its own** (line 119) and prints 24 checks — it
never hung here. That report came from `codex/primary`, where its motion
dependency does not exist.

---

## 2. Arms, weapons, ADS and reload

The first-person half: hands that stretch to the weapon, a gun that comes off
the sights through a reload, and clips that survive a re-select.

| file | + | note |
| --- | --- | --- |
| `game/systems/held_gear.gd` | 560 | grips, sockets, two-handing |
| `game/systems/first_person_arms.gd` | 422 | hand pose, ADS drop, reload blend |
| `game/systems/vats_targeting.gd` | 343 | part selection through `hit()` |
| `game/systems/weapon_skins.gd` | 226 | per-weapon skins |
| `game/systems/aim_down_sights.gd` | 207 | sight alignment, sway |
| `game/systems/hunter_arsenal.gd` | 161 | `sidearm` reload 1.3s, damage 24 |
| `game/systems/vats_overlay.gd` | 118 | |

**Gate:** `fp_arms_test`, `aim_down_sights_test`, `held_weapon_sights_test`,
`model_held_items_test`, `arsenal_test`, `firearm_aim_test`,
`combat_blade_binding_test`, `vats_targeting_test`, `v01_weapons_test`.

The reload visuals are `pistol_reload_NN` frames from `fp_arms_capture` — a
windowed capture, so it proves nothing headless. If you are reviewing "is the
reload actually animated", that is where the answer lives.

---

## 3. Damage, blood, hit feel

Kill feedback as one system: the wound, the spray, the smear, the chunk, the
camera.

| file | + |
| --- | --- |
| `game/gore_demo.gd` | 953 |
| `game/blood_waterfall_exit.gd` | 876 |
| `game/systems/smoke_volume.gd` | 486 |
| `game/systems/blood_smear.gd` | 463 |
| `game/systems/blast_fx.gd` | 457 |
| `game/systems/blood_ledger.gd` | 406 |
| `game/systems/blood_trees.gd` | 258 |
| `game/systems/execution_beat.gd` | 247 |

`blood_flow.gd` carries the arterial-spurt API (`stroke_strength`,
`spurt_drops`, `spurt_velocity`) committed separately as `b3e84180` — the death
path in `rigged_body_test` needs it.

**Gate:** `blood_flow_test`, `blood_smear_test`, `blood_smear_drag_test`,
`blood_ledger_test`, `blood_ledger_hunt_test`, `blood_moves_test`,
`hit_flash_test`, `parry_spark_test`, `strike_fx_test`, `strike_smear_test`,
`strike_heading_test`, `gore_cam_test`, `gore_hitstop_test`, `impact_feel_test`,
`execution_beat_test`.

---

## 4. Vitals, inventory, field HUD

The organ model and the screen that reads it.

| file | + | note |
| --- | --- | --- |
| `game/systems/organ_system.gd` | 830 | organs, bleeding, perfusion |
| `game/systems/field_inventory.gd` | 715 | draws through `GothicFrame` |
| `game/systems/organ_meshes.gd` | 222 | |
| `game/systems/medical_monitor.gd` | 214 | |
| `game/systems/perfusion.gd` | 174 | |
| `game/systems/gothic_field_hud.gd` | 169 | |
| `game/systems/field_meds.gd` | 167 | |

**Gate:** `organ_system_test`, `vitals_test`, `vitals_cost_test`,
`field_inventory_test`, `field_meds_test`, `lock_readout_test`,
`corpse_inspect_test`, `medical_monitor_test`.

Both dependencies the inventory slice used to be missing —
`organ_system.gd` and `gothic_frame.gd` — are in this PR, so this is the first
branch where that slice can actually run (T5).

---

## 5. Facility escape route

The largest content chunk: the vat, the intake, the guards, the doctor, the
examiner, the exit.

| file | + |
| --- | --- |
| `game/vat_chamber.gd` | 2,271 |
| `game/lab/mechanics_lab.gd` | 1,401 |
| `game/systems/doctor_route.gd` | 1,161 |
| `game/systems/v01_encounters.gd` | 1,070 |
| `game/systems/examiner_fight.gd` | 938 |
| `game/doctor_vehicle_bay.gd` | 868 |
| `game/systems/bingyanger.gd` | 603 |
| `game/systems/facility_guard_post.gd` | 606 |
| `game/systems/v01_guard.gd` | 557 |
| `game/systems/facility_zone_identity.gd` | 523 |
| `game/systems/v01_sentinel.gd` | 498 |
| `game/systems/v01_foe.gd` | 495 |

**Gate:** `route_end_to_end_test`, `first_thirty_route_test`,
`facility_one_map_route_test`, `facility_walk_test`, `doctor_route_test`,
`doctor_chase_route_test`, `examiner_fight_test`, `examiner_keycard_test`,
`exit_reveal_test`, `vat_rebirth_test`, `vat_containment_test`,
`first_run_walk_test`, `first_run_lessons_test`.

Read `route_end_to_end_test` before the scenes: it is the one file that states
the intended order of the escape, and every scene here can be checked against
it rather than against taste.

---

## 6. Hunt, map, index, holdings

The overworld layer: what the hunter is sent to do and what the world remembers.

| file | + |
| --- | --- |
| `game/systems/event_director.gd` | 747 |
| `game/systems/signal_sight.gd` | 556 |
| `game/systems/brain_index_hub.gd` | 555 |
| `game/systems/brain_hack.gd` | 419 |
| `game/systems/event_parts.gd` | 326 |
| `game/systems/brain_screen.gd` | 287 |
| `game/systems/mission_card.gd` | 283 |
| `game/systems/xray_scan_overlay.gd` | 246 |

**Gate:** `brain_hub_test`, `pin_board_v2_test`,
`index_board_territory_route_test`, `holding_work_integration_test`,
`hidden_cache_test`, `threat_compass_test`, `signal_sight_test`,
`world_xray_test`, `xray_structures_test`, `overworld_events_hunt_test`,
`hunt_vision_keys_test`.

---

## 7. Input: pad, rebinding, hints

Small chunk, wide blast radius — it gates the pad work in every other chunk.

| file | + | note |
| --- | --- | --- |
| `game/systems/pad_bridge.gd` | 360 | **autoload `PadBridge`** |
| `game/systems/input_profile.gd` | 277 | **autoload `InputProfile`** |
| `game/systems/pad_keyboard.gd` | 243 | |
| `game/systems/key_hints.gd` | 146 | |
| `game/systems/combat_input_layer.gd` | 97 | |

Both autoloads are registered in `game/project.godot` `[autoload]`. That
registration is the whole reason pad tests can run at all — a branch carrying
the pad systems without that file silently no-ops instead of failing (T6).

**Gate:** `pad_bridge_test`, `souls_pad_test`, `combat_rebind_test`,
`look_settings_test`, `key_hints_test`, `menu_input_chooser_test`,
`hunt_pad_layout_test`, `intake_pad_walk_test`, `vat_pad_chain_test`,
`no_controls_strip_test`, `handheld_control_binding_test`.

---

## 8. Vehicles, arcade, derby

| file | note |
| --- | --- |
| `game/systems/vehicle_damage.gd` | crush, detach, engine tier |
| `game/systems/vehicle_driver.gd` | |
| `game/service_arcade.gd` (+564) | the arcade cabinet |
| `game/systems/round_cam.gd` | |

**Gate:** `vehicle_damage_test` — 16 real checks, green, with numbers
(`peak 18.1 m/s`, `crush 0.60 m`, three parts detached). Read T3: this suite's
reputation as a false green is a `codex/primary` artifact, not a live defect.

Also: `car_entry_test`, `derby_tunnels_test`, `derby_exit_test`,
`round_cam_test`, `arcade_cleaver_test`, `arcade_execution_test`,
`doctor_vehicle_bay_test`, `service_arcade_route_test`.

---

## 9. Destruction and materials

| file | + |
| --- | --- |
| `game/lab/stations/destruction_station.gd` | 360 |
| `game/systems/material_toughness.gd` | — |
| `game/systems/breakable_door.gd`, `breakable_prop.gd`, `weak_wall.gd`, `world_break.gd`, `glass_tank.gd`, `vat_smash.gd` | — |

**Gate:** `breakable_door_test`, `breakable_props_test`,
`destruction_toughness_test`, `destruction_fx_test`, `world_break_test`,
`vat_smash_test`, `weak_wall_test`, `mesh_budget_test`.

---

## 10. Rooms and set pieces

98 files, 57 scripts: `game/facility.gd` (+1,127), `game/support_unit.gd`
(+1,123), `game/service_arcade.gd`, `game/old_drains.gd` (+521),
`security_camera.gd` (+447), `face_monitor.gd` (+444), `curiosity_bot.gd`
(+936), `hologram_call.gd` (+362), `support_guard.gd` (+305), `dig_terrain.gd`
(+287), `splinter_monk_look.gd` (+287), `lab_cables.gd` (+218),
`voxel_structure.gd` (+509).

**Gate:** mostly scene-level — `curiosity_bot_test`, `slide_fall_test`,
`power_wires_test`, `lab_layout_test`, `station_placement_test`,
`security`/`camera_hack_test`.

This chunk is where "does it look right" is the only real test. Treat the
`*_capture.gd` scripts as the evidence, not the pass lines.

---

## 11. Menus, HUD chrome, skins, photo mode

136 files, 82 scripts: `devsite`-adjacent menu work, `case_menu`,
`skin_market`/`skin_case`/`skin_loadout`, `photo_mode`, `run_card`,
`transition_kit`, `menu_blood`, `front_door`, `country_town_menu`,
`opening_*`, `torture_load_in`.

**Gate:** `case_menu_test`, `photo_mode_test`, `menu_blood_test`,
`transition_kit_test`, `skin_case_test`, `outfit_test`,
`opening_greeting_test`, `opening_handoff_test`, `pause_test`,
`torture_load_in_test`, `type_layout_test`.

---

## 12. Character look and clothing

`clothing.gd`, `character_sheet.gd` (+84), `character_archive.gd`,
`hunter_appearance.gd`, `outfit.gd`, `tank_body_marks.gd`,
`implant_boot_hud.gd`, plus `flesh_skin.gdshader` / `cloth_skin.gdshader`.

**Gate:** `body_look_test`, `clothing_shell_test`, `outfit_test`,
`tank_body_marks_test`, `character` sheet tests.

---

## 13. Art, shaders, audio

**351 files, 14,386 added lines — and only 10 scripts.** This is 8% of the
diff that no suite meaningfully gates: textures, `.glb`, `.import`, and the
shader set (`xray_shell`, `skin_pattern`, `censor_glitch`, `flesh_skin`,
`cloth_skin`).

**Gate:** `ambient_audio_test`, `sight_audio_test`, `strike_audio_test`,
`logo_fx_test`, `fluid_surface_sound_test`, `v01_sound_pass_test` cover the
audio half. The art half is reviewed by opening it, and `mesh_budget_test` is
the only numeric guard on cost.

---

## 14. Route and QA harness

150 files, 90 scripts — the tools that let the rest be checked:
`game/tests/playbot.gd` (+623), `capture_scene.gd` (+168), `perf_probe.gd`
(+79), `process_cost_probe.gd`, `viewport_audit.gd`, `psy_lab_soak.gd`.

**Gate:** none — this *is* the gate. Review it for what it can and cannot see:
headless runs draw nothing, so every `*_capture` needs a windowed run
(`render_one.cmd <scene>`), and a capture script that quits 2 on headless is
working correctly.

---

## 15. Docs, tools, handoff

134 files, **+51,880 — 30% of the entire diff is prose.** `DESIGN/` (53 files),
`HANDOFF/raw/chat_digests/` (19), `sites/celloutz.xyz/`, build scripts
(`Build-Exe.ps1`, `Play-Latest.*`), `.github` templates.

Skim, do not read. The one rule: a design doc that claims something is done is
not evidence — that is what the gate tables above are for.

---

## Why there is no `lane/core`

I measured it rather than argued it. On a scratch checkout of the lane, remove
the body block — `knockback`, `sword_moveset`, `melee_driver`, `rigged_body`,
`player_look`, `souls_mover/roll/pad`, `scar_ledger`, `organ_meshes`,
`round_trails`, `fp_combat_audio`, `combat_input_layer`, `first_person_arms` —
and run the import:

**19 files fail to compile**, including `baseline_human.gd` (`rigged`,
`ScarLedger`, `OrganMeshes`, `RoundTrails`), `bone_yard_hunt.gd` (`PlayerLook`,
`FirstPersonArms`), `mechanics_lab`, `service_arcade`, `facility_guard_post`,
`examiner_fight`, `v01_guard`, `v01_freed_subject`, `pause_gate`,
`doctor_route`, `xray_scan_overlay`, `held_gear`, `gore_demo`, `pad_bridge`.

The Hunt, the lab, the arcade and every guard call into the body block. Cutting
it out is not a smaller PR, it is a rewrite of every scene that has a person in
it. The seams above are the useful part of that split; the branch split is not
available.

---

## Traps

**T1 — the shared checkout will lie to you.** `player_look_test` in the main
working tree: `2 FAIL` + `TIMED OUT after 200s`. The same commit
(`b3e84180`) in a clean worktree: `PLAYER_LOOK_TEST_RESULT failures=0`, exit 0.
The cause is 594 uncommitted lines across `player_look.gd`, `bone_yard_hunt.gd`,
`round_trails.gd`, `held_gear.gd`, `anatomy_component.gd`, `rigged_body.gd`,
`vat_intake.gd` — in-progress player-82 work that is not mine and not the
lane's. `git worktree add` before believing any gate.

**T2 — an error in a test reads as a hang.** `player_look_test.gd:46` calls
`float(_param(player, "torso", "muscle"))`; when the look is not the base body
`_param` returns null, `float(null)` raises `Nonexistent 'float' constructor`,
the coroutine dies, and nothing calls `get_tree().quit()`. The harness waits
200s and reports a timeout instead of a failure. Any helper that can return
null needs to trip the `_finish()` path the way the null guard at lines 33–35
already does.

**T3 — `vehicle_damage` was a false green, and this PR is the fix.**
`game/systems/vehicle_damage.gd` does not exist on `codex/primary`
(`git cat-file -e origin/codex/primary:game/systems/vehicle_damage.gd` →
absent), so the scene cannot load, prints no checks and no failures, and a
summary that only greps for `failures=` reads that as a pass. On the lane the
suite runs 16 checks to green with real numbers. Believing the exit code
instead of the printout is what closes this class of bug.

**T4 — `hit()` is a 10-argument contract.** `baseline_human.gd:672`:
`hit(zone_id, damage, impulse, damage_type, organ_id, hit_direction,
joint_alignment, cut_point, cut_plane, attack_id)`. `rigged_body_test:169` and
`player_look_test:139` both pass all ten (`..., 1.0, null, null, "heavy"`). If
anyone ever does cut the body block, the callee and both callers have to move
together — which is the second reason the split fails.

**T5 — the inventory slice was unbuildable, not broken.** `field_inventory.gd`
draws through `GothicFrame` (lines 515–728) and needs `organ_system.gd`; both
are in this PR. Review it here, and do not re-report it as missing on primary.

**T6 — the input autoloads are the gate, not the systems.**
`game/project.godot` registers `InputProfile` and `PadBridge` under
`[autoload]`. A branch with the pad scripts but not that registration produces
no failures and no behaviour.

---

## Suggested order and budget

Read chunks **1 → 2 → 3 → 4 → 7** properly. That is the body, the hands, the
wound, the screen and the controls — every one of the six green suites lives
there. Then **5** (the route) against `route_end_to_end_test`,
then **6**, **9**, **8** by spot-check. Chunks **10–15** are content: open them,
do not read them.

The risk is not evenly spread. Ranked: the rig's `hit()` contract (T4), the
reload/ADS blend in `first_person_arms.gd`, the uncommitted player-82 rewrite
sitting in the shared checkout (T1), and the 351-file art/shader chunk that no
suite gates.
