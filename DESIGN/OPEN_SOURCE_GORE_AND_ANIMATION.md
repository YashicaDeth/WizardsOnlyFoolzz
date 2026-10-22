# Open-source building blocks for the body, the gore and the animation

Researched 2026-10-23 against the engine this project runs (**Godot 4.7.2**).
The question was not "is there a gore plugin" — there is not, in any state worth
depending on — but which maintained, permissively licensed pieces fill a gap
`game/systems/` does not already own.

The rule here is the same as `DESIGN/CARL_COMPARISON.md`: a row is only worth
taking when it names something we cannot already do, and "we already do this"
is a valid answer. Nothing below replaces `BaselineHuman`, `AnatomyComponent`,
`WoundMarks`, `BloodSmear`, `BloodPool`, `OrganSystem` or `RagdollBody`; every
one of those is more specific than anything in the open-source ecosystem.

## What is worth taking, in order

| # | Project | License | Engine | What it actually adds to *this* game |
|---|---|---|---|---|
| 1 | [Compatibility Decal Node](https://github.com/antzGames/Godot-Compatibility-Decal-Node) | MIT | 4.4–4.7, active 2026 | Instanced decals in the Compatibility renderer. Our blood is mesh-and-shader based (`BloodPool`, `BloodSmear`); this is the cheap way to put *many* small splats on world geometry without a mesh each. |
| 2 | Built-in [`Decal`](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html) | MIT (engine) | Forward+/Mobile | Same job where we are not on Compatibility. Prefer the engine before adding an addon. |
| 3 | [Concave Mesh Slicer](https://github.com/PiCode9560/Godot-4-Concave-Mesh-Slicer) | MIT | v2.0-stable, 2026 | Runtime cutting of *closed* meshes with a cross-section material. Directly relevant to limb stumps and cut props; must be tested on skinned body meshes before it is trusted. |
| 4 | [Smash The Mesh](https://github.com/cloudofoz/godot-smashthemesh) | MIT (beta) | up to 4.6 | Fragmenting a mesh into physics chunks with cached output — the same shape as `GoreChunks`, but authored per object. Candidate for bone/prop destruction, not for organs. |
| 5 | Built-in [ragdoll](https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html) + [`PhysicalBoneSimulator3D`](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html) | MIT (engine) | 4.x | Editor-authored physical bones. `RagdollBody` already does bespoke joint limits per zone; this is the reference to check our limits against, not a replacement. |
| 6 | [Phantom Camera](https://github.com/ramokz/phantom-camera) | MIT | ≥4.3, 2026 | Camera priorities and transitions. Useful for the kill-cam / scope-lens X-ray the comparison doc already scopes as presentation work. |
| 7 | [LimboAI](https://github.com/limbonaut/limboai) | MIT | matched GDExtension per engine version | Behaviour trees for enemies reacting to our anatomy events (a ruptured heart, a severed leg). Only worth it if the Hunt's brains outgrow their state machines. |
| 8 | [Godot Jolt](https://github.com/godot-jolt/godot-jolt) | MIT | built in since 4.4 | Better rigid-body stacks for gibs and severed limbs. Built-in Jolt first; the extension only if a specific joint interface is missing. |
| 9 | Built-in [retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html), `RetargetModifier3D`, [`BoneAttachment3D`](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html) | MIT (engine) | 4.4+ | The actual answer to "add animations for ripping organs out and fitting cybernetic parts": one animation library retargeted onto every body, and hardware parented to the bone it replaces instead of a hand-written transform. |
| 10 | Built-in IK (solver family landed in [4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)) | MIT (engine) | 4.6+ | Hand placement on a grabbed organ, foot planting on uneven ground. We run 4.7.2, so this is available without a plugin. |
| 11 | [Blood Spray Particles](https://github.com/profesorshader/shader-blood-spray-particles) | MIT | 4.x, 2026 | A particle shader for directional arterial spray. `BloodVeil` and `BloodSmear` decide *where*; this is only the look of the droplets. |

## What not to take

- **No drop-in gore or dismemberment framework exists** for Godot 4 that is
  maintained and permissively licensed. Every candidate either is a generic
  mesh tool or is somebody's prototype. Our anatomy is the differentiator; a
  plugin would be a downgrade.
- [godot-blender-exporter](https://github.com/godotengine/godot-blender-exporter)
  is **GPL-2.0-or-later**, experimental, and last active in 2024. Use Blender's
  own glTF export and Godot's importer instead.
- [OSIK](https://github.com/okaysalmon/ISOK) uses a **custom EULA**, not an OSI
  licence, and is WIP. Built-in IK covers the same need from 4.6.
- [V-Sekai active-ragdoll](https://github.com/V-Sekai/godot-active-ragdoll-physics-animations)
  states **no licence** on its page and was last touched in 2024. Study only.

## The order I would spend the next passes in

1. **Retargeting + `BoneAttachment3D`** — the prerequisite for the animation
   work Greg wants (rip-out, cybernetic swap), and it is engine-native.
2. **Decals for splatter** — blood that persists on walls and floors at a cost
   per-splat rather than per-mesh.
3. **Mesh slicing for stumps** — only if the cross-section reads better than
   the current stump geometry.
4. **Phantom Camera for the scope-lens X-ray** — presentation of a verb we
   already have.

Anything further down this list is a tool for a system we have not built yet.
