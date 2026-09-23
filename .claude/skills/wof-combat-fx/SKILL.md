---
name: wof-combat-fx
description: Add or change a combat visual or sound effect in Wizards Only Fools (trails, smears, sparks, rings, dust, swing audio) the way the existing ones are built - an additive component fed from one place, a gallery shot, a behaviour test and a frame-cost number. Use when asked to make fighting look, feel or sound better, or to add any per-swing, per-hit or per-dodge effect.
metadata:
  project: AllusionsTooGrandeur
---

# Combat effects

Eight effects already follow this shape. Copy it; do not invent a new one.

| Component | Fed from | Reads |
|---|---|---|
| `StrikeTrail` (arc + cable) | `_update_strike_fx()` | held weapon, `arm.commitment()` |
| `StrikeSmear` (afterimages) | `_update_strike_fx()` | weapon + measured tip |
| `StrikeAudio` (whoosh, crack) | `_update_strike_fx()` | tip speed, commitment |
| `LockRing` (ground wire) | `_update_strike_fx()` | `_camera_combat_focus()` |
| `DustPuff` (dodge ash) | `_dodge()` | `dodge_direction` |
| `HitFlash` (contact star) | melee hit, beside `_spawn_blood` | `strike_dir`, damage |
| `ThreatCompass` (edge arcs, HUD) | enemy wind-up in the actor loop | attacker position, wind-up progress |
| `LockReadout` (X-ray body over the lock, HUD) | `_update_strike_fx()` | locked actor's AnatomyComponent zones — never a health bar |

## Rules

1. **An additive `class_name` component** in `game/systems/`. It reads state
   and draws; it never changes combat numbers. `bone_yard_hunt.gd` gets only a
   declaration, a `new()` beside the others, and one feed call — it is
   touched by four branches.
2. **Pooled or one mesh.** `ImmediateMesh` redrawn per frame, or a fixed pool
   of nodes. Never a node per hit.
3. **Reads real motion.** Trails come from the weapon's measured tip
   (`StrikeTrail.tip_local`), not a guessed offset; effects draw nothing when
   the weapon is still.
4. **Hitstop is off-limits** unless Greg asks: `impact_feel.gd` v4 records
   his "loud is not the same as satisfying".
5. **Contact is inside the body.** A hit marker needs `no_depth_test`.
6. **Sound is synthesized** (`creating-godot-procedural-audio`), routed with
   `AudioBus.route(player, "Bodies")`, and the commit says it was not heard.
7. **References are inspiration.** Greg's Garden of Giants clips set the
   bar (omnidirectional, cable-whip, smear, smoke); every asset is original.

## Prove it

- Stage it in `prototype_lab/strike_fx_gallery.tscn`. Trigger one-shot
  effects a few frames before `--shot` so the capture cannot fall between
  them. Crop and zoom the result and look (`wof-verify-by-looking`).
- One `tests/<name>_test` covering: nothing when idle, something when
  driven, bounded pool, gone after its life. Run randomised tests more than
  once; measure relative to spawn, not absolute position.
- Cost: `strike_fx_gallery.tscn -- --perf` (vsync off, five fighters, on vs
  off). Last measured: trail + cable + smear = 0.33 ms/frame.
