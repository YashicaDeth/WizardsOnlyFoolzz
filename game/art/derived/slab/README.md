# slab — architecture textures

Drop `.png` sheets in this folder and the game picks them up on next run.
No import step, no code change, no naming convention beyond the extension.

## What lands here

Walls, floors, iron, concrete, pipe — every architectural surface built with
`WorldLook.surface(colour, kind, seed)` where kind is one of:

    rust    corroded wet iron, structural steel, pipework
    dirt    scabbed concrete, grating filth, floor grime
    bone    load-bearing structure, ribs, arches, struts
    paint   institutional signage, painted plate, markings

`chrome` and `glass` deliberately do NOT take these sheets: a grime texture
over polished steel or pressure glass reads as dirt on the camera lens rather
than as a surface.

## What to make

These are **detail sheets layered over** the procedural contamination, not
replacements for it. The base colour, the rust bloom and the green growth are
already generated per-surface; your sheet adds the hand-made grain on top.

- Seamless/tiling works best — they are applied triplanar with no UVs.
- Square, and small. The look is PS1-era crunch (`TEXTURE_FILTER_NEAREST`);
  256x256 or 512x512 is plenty and anything larger is thrown away by the
  filter.
- Greyscale or near-greyscale reads best. The tint comes from the surface
  underneath; a strongly coloured sheet fights it and goes muddy.
- High-frequency detail: pitting, scratch, pour lines, weld seam, stain edge.
  Broad soft gradients disappear under the procedural layer.

## How one gets chosen

`ArtSet.pick("slab", seed)` indexes the sorted file list by seed, so a given
wall picks the same sheet every run. More sheets means more variety across the
level; one sheet means every rust surface shares a grain.

## If this folder is empty

Nothing happens. The game renders exactly as it does today. The art is a layer
over the procedural look, never a dependency of it.
