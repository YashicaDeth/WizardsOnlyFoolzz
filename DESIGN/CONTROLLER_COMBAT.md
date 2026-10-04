# Controller combat

## Greg's requirement (Round 10, 4 October 2026)

The Souls layout is the base everywhere, including the Hunt:

| Physical control | Melee verb | Firearm context |
| --- | --- | --- |
| R1 | light | main-hand light (not a second trigger) |
| R2 | heavy | fire |
| L1 | block | block |
| L2 | parry | aim |
| L2 + R2 | — | aimed X-ray / VATS |

The game is controller-first. A discipline may remap the verbs on those
physical controls, but it remaps on top of this base rather than replacing it
with scene-specific button checks.

## Implementation contract

`systems/combat_input_layer.gd` owns the Souls base as data. Its stable native
InputMap actions are `pad_combat_r1`, `pad_combat_r2`, `pad_combat_l1`, and
`pad_combat_l2`. `PadBridge` registers joypad events for those physical actions
without erasing an existing native binding, then resolves them through the
active layer and weapon context. The Hunt then
consumes semantic verbs through `_pad_combat_verb`; it does not inspect pad
button numbers.

A discipline manager installs a sparse override with:

```gdscript
PadBridge.set_combat_layer(discipline_id, {
    "melee": {CombatInputLayer.R2: "discipline_special"},
})
```

Omitted controls keep their Souls meaning. Changing a layer or weapon context
first releases every verb that was held under the old layer, preventing a
block, aim, or trigger from becoming stuck across a swap. The controller HUD,
one-time key hints, pause controls page, and Hunt key sheet ask the same active
layer for their glyphs.

Scenes not yet migrated to semantic combat still receive the resolved verb as
their established key/mouse fallback. That compatibility path is transitional;
new combat code should implement `_pad_combat_verb` or consume a discipline's
logical verbs, never synthesize its own shoulder mapping.

The current Hunt holds one arsenal item at a time. Therefore R1 correctly does
not fire while a firearm occupies that hand. When the confirmed Bloodborne
main-hand melee/off-hand gun loadout is implemented, it can route the already
present `light` verb to the main hand without changing this controller layout.

## Verification ownership

- `pad_bridge_test`: native physical actions, Souls meanings, firearm context,
  prompt glyphs, and safe mid-input discipline-layer changes.
- `souls_pad_test`: sandbox movement/combat plus R2 fire and L2 aim.
- `hunt_pad_layout_test`: the production Hunt's light, heavy, block, parry,
  fire, aim, and retained L2+R2 aimed-X-ray chord.
