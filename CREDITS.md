# Credits

Third-party files in this repository, with source, author and licence. Add a
row for every imported file (DESIGN/BUILD_BRIEFS.md, rule 2). Older per-folder
lists: `game/art/textures/lab/CREDITS.md` (ambientCG, CC0).

| File | Source | Author | Licence |
|---|---|---|---|
| `game/art/characters/ual_mannequin.glb` (`UAL1_Standard.glb` from "Universal Animation Library [Standard]", Unreal-Godot folder, no root motion; 65-bone skeleton, 43 clips; downloaded 2026-10-04) | https://quaternius.itch.io/universal-animation-library | Quaternius | CC0 1.0 |

## Code and shader references (no files copied)

- Glass fresnel/tint approach in `game/shaders/glass_tank.gdshader`: after the
  CC0 "PBR Glass" (https://godotshaders.com/shader/pbr-glass/) and "Colored
  Glass" (https://godotshaders.com/shader/godot-4-2-colored-glass/) shaders on
  godotshaders.com. Written fresh for the tank; no code copied.
- Fluid (`game/systems/fluid_body.gd`): looked at the MIT GPU SPH projects
  (Godot Asset Library 5116 "3D SPH Fluid Simulation",
  https://github.com/mdufaud/godot-simulations,
  https://github.com/thompsop1sou/godot-fluid-sim) and the buoyancy addon
  https://github.com/ueshita/godot-floatable-body. Not used: they need compute
  shaders, which do not run headless, so the test suite could not exercise
  them, and one tank's spill does not need tens of thousands of particles.
  The CPU SPH-lite pour and depth-grid pool are our own.
