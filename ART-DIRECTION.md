# CellOutz visual direction

**Superseded 2026-09-11.** The original brief called for "a battered toybox version of a roadside combat game" in sun-bleached copper and teal salvage paint. The Bone Yard kit and the scrap skiff were authored to that spec, which is exactly why they read as toys. The direction below replaces it. Existing assets are now provisional and scheduled for regrime.

## Biopunk apocalyptic

Wrecked, organic and wrong. The world is not a colourful salvage yard — it is an industrial corpse being reclaimed by something biological. Machines have been repaired with material that was recently alive; the line between vehicle, building and body is not clean anywhere.

Palette: bone and nicotine, dried blood, oxidised iron, bruise purple, sickly fungal green, tar black. Colour arrives as **contamination**, not as paint — a bloom of spore green across a panel, a rust weep down a wall, arterial red where something bled. Saturated hues appear rarely and mean something when they do. No cheerful primaries, no clean teal, no toy plastic.

Surfaces: nothing uniform, nothing new. Every panel carries rust bloom, weld scar, patch plate, biological staining or growth. Wet where it should be dry. Matte and chalked where it should be glossy. Readability comes from silhouette and value contrast rather than from bright local colour.

Vehicles: the derby cars should look *grown into* rather than assembled — stripped chassis with exposed mechanism, bone and sinew lashings, grafted organic components, fungal bloom in the wheel wells, dried spatter no one washed off. A car that has killed people and shows it. They should not read as karts.

Scale and space: the arena is a quarry, not a playpen. Distances should feel punishing, sightlines long, the far edge hazed out. Cramped geometry reads as a prototype level no matter how well lit.

Reference register: Cruelty Squad's nauseating body-modification palette, Wrought Flesh's meat-and-organ industry, Kenshi's sun-destroyed wasteland, S.T.A.L.K.E.R.'s contamination, Half Sword's unglamorous physical brutality. Tonal references only.

## Asset drop format

Put character or vehicle assets in `game/art/inbox/<asset-name>/` with the model (`.glb` preferred), textures (`.png`, `.jpg`, or `.webp`), a short license/source note, and one reference image. Blender can inspect and normalize the model; Godot can then import the cleaned `.glb`.

For a first character handoff, the useful minimum is:

- a neutral A-pose or T-pose model;
- separate driver/head, torso, left-arm, right-arm, and vehicle/body meshes if damage separation is desired;
- 2K albedo, normal, and roughness/metallic textures when available;
- a note naming the material slots and the intended scale.

Do not send private account credentials. A shared folder or a zip of the asset pack is enough.

## Gore and body-horror tone

Gore reads as excessive and darkly funny rather than grimdark-serious, closer to Postal 2's over-the-top splatter than to restrained realism. Layer in a biopunk grossness on top of that — wet, organ-forward, wrong-looking interiors in the vein of Kenshi's persistent limb loss and Wrought Flesh's meat/organ handling, and Cruelty Squad's garish, nauseating body-modification aesthetic. Wounds and exposed anatomy should look authored and specific per zone (see `DAMAGE-SYSTEM-CONCEPT.md` and `game/systems/anatomy_component.gd`), not a single reused blood decal. These are tonal references only; no assets or code are extracted from them.

## Comic register: grimy satire

The world is crude, grimy and willing to offend — early South Park's blunt absurdism and Postal 2's deadpan social commentary, where the joke and the horror arrive in the same breath. Humour is load-bearing, not decoration: a disembowelling and a petty argument about parking should be able to happen in the same thirty seconds.

Aim the satire at institutions and power — the factions, their doctrines, the surviving corporate internet, bureaucracy that outlived its purpose, the Sins-as-hierarchies already in `DESIGN.md`. That structure is already built for it: a rail-gang that runs tolls, an anatomical faith that rewrites allegiance through surgery, and a Wire feed reporting on the player are satirical targets with real mechanical teeth. Punching at systems is what gives this register its bite; slurs aimed at real groups are just noise, and they would flatten a world this specific into something generic.

## UI language

The game HUD should borrow the rough menu energy of old PC action games while remaining CellOutz: chunky card panels, offset labels, tiny status chips, hand-drawn arrows, and floating scrap badges. Menus should be functional first; texture, grain, decals, and animated paper jitter are the finishing pass.

### Density: the interface is a made object

The target is not a clean engine HUD with a texture on it. It is an intricate, layered, hand-composited artefact — the kind of thing built up in Photoshop across dozens of layers — that happens to be functional. Interfaces have personality (Master Codex §29), so build them the way a person would build a poster.

Layer vocabulary, roughly back to front:

- **Substrate.** Scanned paper, carbon copy, receipt roll, photocopier grime, toner banding, a fold or a coffee ring. Never a flat fill.
- **Print artefacts.** Halftone dots, misregistration, ink bleed, overprint where two colours cross, crop and registration marks in the margins.
- **Structure.** Chunky card panels, rules, boxed tables, form fields that look stamped rather than drawn.
- **Data.** The actual live numbers, set in the cleanest type on the page so readability survives everything under it.
- **Annotation.** Someone else's handwriting: circled values, marker underlines, a crossed-out old figure with the new one beside it, initials, a date stamp.
- **Physical residue.** Tape, staples, a curling sticker corner, a punch hole, a torn edge where a section was ripped away.
- **Wear.** Grain, scratches, a scuff where a thumb sits, slight animated jitter so the paper is never perfectly still.

Density is the point: serial numbers, barcodes, tiny legends, form codes, part numbers, footnotes nobody needs to read. Intricacy sells the world as one that existed before the player, and it gives the compendium and the Wire somewhere to hide detail. The discipline that keeps it from becoming noise: **the live data layer stays clean and high contrast, everything else is texture underneath it.** Readable at a glance, endless on inspection.

Diegetic framing: the HUD is a CellOutz product someone installed in a salvaged car. It carries branding, a model number, damage, and a previous owner's modifications. Different factions and eras run different interface generations — a Choir of Marrow surgical readout should not look like an Ashline derby dash.

### Placeholders that read as finished

Every placeholder is art-directed to the final tone and then explicitly flagged as swappable. No grey boxes, no untextured primitives left to stand in for a look, no "we will style it later" — provisional work should already feel like the world, so the game can be judged honestly at any moment and so a missing asset is a quality decision rather than a hole.

The working rule:

- Provisional assets are authored to the real palette, wear level and register. If it ships in a screenshot, it looks intentional.
- Every provisional asset is tracked, not remembered. Record it in the manifest with what it stands in for and what would replace it.
- Replacement is a swap, not a rewrite. Keep the same material slots, socket names and scale so an authored `.glb` drops into the metadata the systems already reference (see the asset drop format above, and `DAMAGE-SYSTEM-CONCEPT.md` on named damage sockets).
- Procedural now, authored later, same silhouette. The vector HUD, the generated audio and the primitive gore all exist to prove the system; each has an authored replacement path that must not require touching gameplay code.

This is what "feels real but awaiting replacement" means in practice: the seams are in the pipeline and the manifest, never in the frame.
