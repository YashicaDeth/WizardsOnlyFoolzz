# CellOutz visual direction

CellOutz should feel like a battered toybox version of a roadside combat game: sun-bleached copper, teal salvage paint, dirty cream UI paper, black ink labels, floating debug-like ornaments, and a light grain pass. The world stays readable at a glance, while small props carry the grunge.

## Asset drop format

Put character or vehicle assets in `game/art/inbox/<asset-name>/` with the model (`.glb` preferred), textures (`.png`, `.jpg`, or `.webp`), a short license/source note, and one reference image. Blender can inspect and normalize the model; Godot can then import the cleaned `.glb`.

For a first character handoff, the useful minimum is:

- a neutral A-pose or T-pose model;
- separate driver/head, torso, left-arm, right-arm, and vehicle/body meshes if damage separation is desired;
- 2K albedo, normal, and roughness/metallic textures when available;
- a note naming the material slots and the intended scale.

Do not send private account credentials. A shared folder or a zip of the asset pack is enough.

## UI language

The game HUD should borrow the rough menu energy of old PC action games while remaining CellOutz: chunky card panels, offset labels, tiny status chips, hand-drawn arrows, and floating scrap badges. Menus should be functional first; texture, grain, decals, and animated paper jitter are the finishing pass.
