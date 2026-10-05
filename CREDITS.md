# Credits

Third-party files in this repository, with source, author and licence. Add a
row for every imported file (DESIGN/BUILD_BRIEFS.md, rule 2). Older per-folder
lists: `game/art/textures/lab/CREDITS.md` (ambientCG, CC0).

| File | Source | Author | Licence |
|---|---|---|---|
| `game/art/characters/ual_mannequin.glb` (`UAL1_Standard.glb` from "Universal Animation Library [Standard]", Unreal-Godot folder, no root motion; 65-bone skeleton, 43 clips; downloaded 2026-10-04; also used by the procedural vehicle door entry/exit body) | https://quaternius.itch.io/universal-animation-library | Quaternius | CC0 1.0 |
| `game/art/vehicles/kenney_car_kit/sedan.glb`, `suv.glb`, `debris-door.glb`, `debris-bumper.glb`, `debris-plate-a.glb`, `Textures/colormap.png` (Car Kit 3.1; `colormap_biopunk.png` is our regrade of `colormap.png`; lab-53, 2026-10-05) | https://kenney.nl/assets/car-kit | Kenney | CC0 1.0 (`License.txt` beside the files) |

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
- Destruction (`game/systems/voxel_structure.gd`, `dig_terrain.gd`, lab-47):
  looked at Zylann's Voxel Tools (https://github.com/Zylann/godot_voxel, MIT;
  GDExtension 1.7 for Godot 4.5+) as the diggable-terrain engine, and the
  surface-nets write-up by Mikola Lysenko ("Smooth Voxel Terrain (Part 2)",
  0fps.net, 2012) for the meshing. No files or code copied: the voxel grid,
  connectivity split and naive surface nets are our own GDScript, so they run
  in the headless suite on every lane without a native binary. Voxel Tools
  stays the named upgrade path for the real map's large terrain.
- Vehicle crumple (`game/systems/vehicle_damage.gd`, lab-53): impact-time
  vertex deformation after the spherical deformer in cloudofoz's
  godot-deformablemesh (https://github.com/cloudofoz/godot-deformablemesh,
  MIT) and the MeshDataTool approach in the Godot docs. Looked at node-beam
  soft bodies (BeamLab, https://github.com/zenkovich/beamlab, C++ at 2 kHz;
  BeamNG's own physics page, https://beamng.com/game/about/physics/) and
  rejected them for GDScript at 144 fps. No code copied.
