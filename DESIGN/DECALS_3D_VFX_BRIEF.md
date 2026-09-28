# BLOOD DECAL SET — 3D + VFX BUILD BRIEF
**Target: hand-authored, procedurally-built decals. No generated imagery, no AI textures in the shipped asset.**

Paste this whole document into Claude and start with: *"Build the deliverable list in section 11. Ask me nothing until the file skeleton exists."*

---

## 0. What this document is

Eight blood decals for a PS2-era low-poly horror game (Godot 4). Currently they exist only as flat 1024×1024 PNG references. This brief replaces them with:

1. **Real 3D geometry** — a shallow relief mesh per decal, not a flat card.
2. **Procedurally authored maps** — silhouette, height, wetness, colour. Built from noise and node graphs, hand-editable, no AI.
3. **Animated node VFX** — the decals breathe, spread, dry and drip at runtime.
4. **A TouchDesigner patch spec** — the authoring surface for the maps and for the "code and effects" pass.
5. **A retexture contract** — so the art can be swapped to hand-painted or photographed plates later without touching geometry, shaders or animation.

The flat references are **proportion references only**. Do not trace them. Every silhouette below is regenerable from the recipes in section 4.

---

## 1. Locked constraints

**Palette (do not add hues):**

| Role | Hex | Use |
|---|---|---|
| Dried blood | `#461009` | outer edges, crust, old stains, 60–75% of every ink mask |
| Arterial red | `#a8281a` | fresh cores, spray, drag leading edge, 15–30% |
| Highlight wet | `#c9433a` | specular bloom on fresh blood only, <5% |
| Copper | `#b0552a` | rust marks, ferrous staining adjacency |
| Bone | `#e6d4ac` | bone shards, teeth, tile grout |
| Acid green | `#b4da48` | ritual/marked decals only, never on plain blood |
| Near-black | `#060b09` | ground, shadow, crust underside |

**World scale:** 1 Godot unit = 1 m. A human hand is 0.19 m wide; a boot print 0.28 m long; a body pool 1.6 m across. Every decal is authored at its true world size and the atlas is resolutioned accordingly (section 9).

**Surface vocabulary:** concrete, painted metal, tile, sand, wet brick, rusted steel. The decal must read correctly on all six.

**Style:** crunchy, dithered, low-fi. Decals must survive being seen at 2 m (relief and normal detail) and at 0.3 m (looks hand-made, not scanned).

---

## 2. How a decal is built — three layers

Every decal is the same stack. Build the stack once, then instance it eight times.

### Layer A — geometry (one of two paths)

**Path 1, Flat Decal (default, ~90% of instances).** A 2-triangle quad, 0.001 m above the surface, custom spatial shader, no lighting pass of its own (it fakes it). Cheapest, batchable, no z-fighting if offset is consistent.

**Path 2, Relief mesh (hero instances only: the wet pool, the drag smear, the handprint).** The silhouette extruded 2–4 mm with a bevelled rim, subdivided 2× for the wet normal. This is what makes blood read as *liquid on a floor* rather than a sticker.

Relief mesh recipe (identical for all eight, only the mask differs):

```
1. Take the mask PNG (1024², 8-bit, white = coverage).
2. Blur the mask 2 px. Threshold at 0.5 -> the "crown" contour.
3. Blur the original mask 12 px. Threshold at 0.5 -> the "film" contour.
4. Extrude crown by 3 mm, film by 0.6 mm. Boolean union.
5. Bevel the crown rim 0.8 mm, 2 segments, angle 45°.
6. Subdivide the top face twice with Catmull-Clark, crease the border at 1.0.
7. Retopo target: 400–900 tris for a handprint, 1500–2500 for the pool, 3000 for the drag smear.
```

### Layer B — material

One shader, `blood_decal.gdshader`, shared by all eight. Slots:

| Slot | Source | Notes |
|---|---|---|
| `mask_tex` | procedural silhouette | white = ink |
| `wetness_tex` | procedural | white = fresh/glossy, black = dried |
| `normal_tex` | procedural | micro crust + meniscus |
| `flow_tex` | procedural | RG = flow direction, B = spread speed |
| `orm_tex` | packed | R occlusion, G roughness, B metallic (metal = 0 everywhere) |

Roughness contract, measured from the references and to be preserved:

- **Fresh blood:** roughness 0.08–0.16, specular 0.6, faint blue-white sheen on the meniscus.
- **Drying:** roughness ramps 0.16 → 0.62 as wetness fades.
- **Dried crust:** roughness 0.58–0.78, high-frequency micro-normal (crust) at 0.35 strength, occlusion 0.55.
- **Never** fully matte: even dried blood keeps a 0.55 roughness floor and a thin edge sheen.

### Layer C — animation nodes

Runtime-driven, not baked. Section 6 lists the node catalogue; each decal in section 4 declares which it uses. All animation is exposed as shader uniforms so it works identically on Path 1 and Path 2.

---

## 3. The "code and effects" pass (project-wide, applies to every asset)

The design notes require every asset to pass through an effects shader so the game reads as code and effects, not rendered art. Decals are the first assets to be built natively into it, so they lead.

`generated_mask.gdshader` — chain, in order:

1. **Edge trace** — Sobel on `mask_tex`, threshold 0.12, output as a 1 px bone-white (`#e6d4ac`) outline at 0.35 strength. Adds the drawn-diagram read.
2. **Dither/halftone** — 4×4 Bayer matrix on the final luma, 2 levels (on/off) blended at 0.45 so it reads as PS2 dithering, not printing. Halftone dots instead of Bayer when `halftone = 1.0`.
3. **Scanline + RGB split** — horizontal band every 2 px at 0.06 opacity; RGB channels offset ±0.6 px, scaled by `glitch_amount`.
4. **Feedback smear** — a `BackBufferCopy` sampled at `feedback_uv = uv - flow * 0.004`, mixed 0.35. This is what makes the blood feel like it's being drawn rather than painted.
5. **Slow data-mosh** — a 32×32 block-noise drive: `uv.x += step(0.5, noise) * mosh * 0.01` on 3–4 horizontal bands, animated at 0.2 Hz.

Expose: `glitch_amount`, `mosh`, `feedback_strength`, `dither_mode`, `edge_strength`. Default all to the values above; the horror areas (Support Unit, Lower Works) push `glitch_amount` to 0.4.

---

## 4. Per-decal specification

All seven delivered decals, plus the eighth you asked for that was never generated (D8). Measurements are from the actual 1024×1024 references (silhouette bounding box, ink coverage of frame, dominant colour clusters as share of ink).

### D1 — SPRAY
**Measured:** bbox 738×666 px, 1.11:1, ink 24.4% of frame. Clusters: near-black 8.2%, `#461009`-band 60%, `#a8281a`-band 16%. Mean ink (73,22,15).
**Reference note:** the delivered frame sits on **white**, not black — ignore its ground entirely, use the silhouette only.
**Form:** fine arterial mist. No relief, Path 1 flat decal. World size 0.9 × 0.8 m.
**Mask recipe:** two scales of noise. `Noise TOP` (simplex, 4 octaves, gain 0.55) at 11 px and 41 px feature size, each thresholded (0.62 and 0.71), unioned; then `Threshold` + 3 px `Blur` + `Threshold` at 0.35 to break the noise into discrete droplets. Drop any island under 6 px.
**Colour zones:** core `#a8281a`, mid `#461009`, dropout to near-black at the mask edge over 2 px.
**Animation:** `SPREAD` (mask dilates 4% over 6 s on spawn), `DRY` (roughness 0.12 → 0.66 over 45 s), `SPECK_DRIFT` (5% of droplets translate 1 px/s along flow).
**Passes through:** full effects chain, `glitch_amount` 0.15.

### D2 — POOL
**Measured:** bbox 840×640 px, 1.31:1, ink 16.9%. Clusters: `#461009` 53%, dark olive 15%, `#b0552a`-adjacent 14%. Mean ink (66,39,32) — the most neutral/dirtiest of the set, correct for a pool on dirty concrete.
**Form:** **Path 2 relief**, 2500 tris. World size 1.6 × 1.2 m. This is the hero wet decal.
**Mask recipe:** one large low-frequency simplex field (3 octaves, gain 0.4) thresholded at 0.48 for the body; a second field at 16 px thresholded at 0.6 adds the rim irregularity; boolean union; 6 px blur across the whole union so the rim is *soft*, not stepped.
**Colour zones:** centre 22% of the mask at `#a8281a` → `#c9433a` (fresh, glossy), a 30 px transition ring, then `#461009` crust, with the last 4 px darkening to near-black. Meniscus: 1.5 mm brightest rim at the outer edge.
**Animation:** `WET_CORE` (glossy region pulses 0.06 roughness at 0.05 Hz — almost imperceptible, sells "still liquid"), `DRY` (wet region shrinks 40% over 90 s), `RIPPLE` (one 12 mm expanding ring on player footstep within 0.5 m).
**Passes through:** effects chain at `glitch_amount` 0.1. The pool is the one decal that should *mostly* escape the effects pass — it's a real object, not a diagram.
**Retexture slots:** this is where hand art pays off most — swap `wetness_tex` and `normal_tex` for a photographed plate.

### D3 — DRAG SMEAR
**Measured:** bbox 818×818 px, 1.00:1, ink 12.5%. Clusters: `#a8281a` 39%, `#461009` 52%. Mean ink (100,25,15) — the second most saturated, correct: a smear is fresher than a pool.
**Form:** Path 2 relief, 3000 tris, 2 mm max height. World size 2.4 × 1.2 m (long axis along +X).
**Mask recipe:** the only decal with **directional structure**. Build a 1D ramp along X at 0.4 gain, multiply it into a 24 px directional noise stretched 6:1 along X, threshold 0.55; then add 4 streak lines (thin 8 px masks, each offset 40–120 px on Y, lengths staggered 60–90%) unioned in. Result: parallel smears tapering to nothing at the +X end.
**Colour zones:** saturated at the −X (start) end, drying progressively toward +X — colour ramps `#a8281a` → `#461009` across the drag direction, and *roughness ramps with it* (0.18 → 0.68). The taper must be a both-colour-and-gloss gradient, not just alpha.
**Animation:** `FLOW` (UV scrolls 0.15/s along +X while spawn is animating), `DRY` (roughness sweep start→end over 60 s), `TAIL_ERODE` (last 20% of the mask dissolves into droplets after 30 s).
**Passes through:** effects chain at 0.25 — the scanline is most visible here and looks right.

### D4 — HANDPRINT
**Measured:** bbox 642×814 px, 0.79:1, ink 15.8%. Clusters: `#a8281a` 44%, `#461009` 41%. Mean (100,25,15).
**Form:** Path 2 relief, 900 tris. World size 0.20 × 0.25 m. This one is seen at 0.3 m, so the geometry carries it.
**Mask recipe:** hand skeleton, then chaos. Palm = rounded polygon 0.11 × 0.10 m. Four fingers 0.02 m wide × 0.075–0.095 m, splayed 8–22°, plus a thumb at 40°. Each finger is its own rounded capsule. Union, then apply a 3 px simplex warp (displacement 1.5 px) so the edges aren't mechanically clean, then 1.5 px blur. **Add the wrist drag:** a 0.06 × 0.04 m smear behind the palm, 40% opacity, offset 0.03 m toward the sl- direction.
**Colour zones:** fingers end in darker `#461009` (thinner film, drying first); palm holds `#a8281a` with a glossy patch; three 2 mm drip beads under the palm at the wrist edge.
**Animation:** `DRY` (45 s), `PRESS` (on spawn, mask scales 0.94 → 1.0 over 0.25 s with an 8% opacity fade — the print "stamps").
**Passes through:** effects chain at 0.2.
**Marked variant (ritual areas):** same geometry, `#b4da48` substituted into the wetness-driven emission channel at 0.5, `glitch_amount` 0.5. This is the only legal green use.

### D5 — DRIPS
**Measured:** bbox 881×841 px, 1.05:1, ink 41.7% (the densest of the set). Clusters: near-black 44%, `#461009` 33%, `#a8281a` 14%. Mean (57,18,12).
**Reference note:** delivered on a **white** ground — silhouette only.
**Form:** Path 1 flat, 2-triangle quad with an animated height shell in the shader (drips are liquid, geometry would be wrong). World size 0.6 × 0.6 m, tiling vertically.
**Mask recipe:** 5–9 vertical streams, each a rounded 1D gradient from the top edge, widths 6–18 px, spacing irregular, lengths 40–95% of frame. Each ends in a **bulb**: radius = width × 1.6, positioned at the stream end. Then a horizontal 2 px blur to soften. Streams must not be parallel — vary X start ±12 px.
**Colour zones:** stream body `#461009`, bulbs `#a8281a` with the brightest 2 px at the bulb's lower face (gravity gloss), tails fading to near-black at the top where the film is thinnest.
**Animation:** the most animated decal. `DRIP_FALL` (each bulb's Y advances 0.02/s, resets to stream start on reach, staggered phases), `BULB_GROW` (radius +8% over 3 s before release), `DRY` (60 s), `TRAIL_DRY` (trail behind a fallen bulb ramps roughness in 4 s).
**Passes through:** effects chain at 0.2.

### D6 — ARTERIAL ARC
**Measured:** bbox 885×488 px, 1.81:1, ink 6.3%. Clusters: `#a8281a` 16%, `#461009` 48%, bright wet 1%. Mean (89,21,12).
**Form:** Path 1 flat. World size 1.2 × 0.65 m. Sparse by design — 6.3% coverage, this decal is mostly negative space.
**Mask recipe:** ballistic build, not noise. A quadratic Bézier arc from (0.1, 0.55) to (0.95, 0.25) bowing upward, stroke width 14 px tapering to 3 px along the arc. Then emit along the arc: 90 particles with velocity tangent, spread ±14°, decay — this produces the fine mist tail. Add 12 heavy leading droplets at the arc's first 25%. Everything else is noise-free.
**Colour zones:** thick head `#a8281a` → `#c9433a` gloss, arc body `#461009`, mist tail 1 px dots fading to near-black.
**Animation:** `ARC_DRAW` (reveal along the Bézier over 0.7 s on spawn — the splash "writes" itself), `MIST_SETTLE` (tail droplets drift 3 px downward over 8 s then freeze), `DRY` (30 s).
**Passes through:** effects chain at 0.3.

### D7 — FOOTPRINT TRAIL
**Measured:** bbox 620×266 px, 2.33:1, ink 2.1% (sparsest). Clusters: `#461009` 53%, `#a8281a` 14%. Mean (86,24,19).
**Form:** Path 1 flat, but built as **7 discrete decal instances**, not one texture — each print is its own quad so the engine can place them along a real path and vary each independently. Geometry per print: rounded foot polygon (heel ellipse 0.06 × 0.05 m, ball 0.075 × 0.045 m, 5 toe blobs) with a 2 px warp.
**Mask recipe (per print):** the polygon above; arch in the middle left mostly empty (weight on the ball and heel); 30% opacity film connecting them.
**Colour/gloss zones — this is the point of the decal:** print 1 (oldest) at `#461009`, roughness 0.72, opacity 0.55. Print 7 (newest) at `#a8281a` with a `#c9433a` core, roughness 0.14, opacity 1.0. Interpolate across the chain. The trail reads as *time* — the player can see how recently someone passed.
**Animation:** `AGE` (a single float per print; drives roughness, hue lerp and opacity together), `SMUDGE` (if the player walks over a print, blend it 30% toward the player's own direction).
**Passes through:** effects chain at 0.2.

### D8 — SPATTER ON TILE (requested, never generated)
**Form:** Path 2 relief, 1200 tris, 1.5 mm. World size 1.0 × 1.0 m.
**Mask recipe:** high-velocity spatter — 40–70 droplets, radius distribution power-law (many at 3–6 px, three or four at 18–30 px), radial placement from a centre with density falling as r⁻¹·⁵, a handful of 30 px **satellite stains with tails** (each tail 20–45 px, direction radially outward, width tapering).
**Unique requirement:** the tile must show through. Mask opacity maxes at 0.85 in droplet centres and 0.35 in the thin film between, so the grout lines stay readable underneath.
**Colour zones:** droplets `#a8281a` core with 2 px `#461009` rim (surface tension), film `#461009` at 30%, three droplets pushed to near-black as fully dried.
**Animation:** `DRY` (50 s), `BEAD` (four designated droplets keep a 0.1 roughness gloss permanently — they never dry), `DRIP_RUN` (one droplet releases and runs down the tile in the grout channel).
**Passes through:** effects chain at 0.2.

---

## 5. Shared node library (build once, reuse everywhere)

Every procedural map in section 4 is assembled from these primitives. Implement them once.

| Node | File | Inputs | Output | Key params |
|---|---|---|---|---|
| `n_fbm` | `nodes/n_fbm.gdshader` | — | grayscale | `octaves` 3–4, `gain` 0.4–0.55, `scale_px` |
| `n_bezier_stroke` | `nodes/n_stroke.gdshader` | control points | stroke mask | `width`, `taper`, `samples` |
| `n_radial_burst` | `nodes/n_burst.gdshader` | — | droplet field | `count`, `falloff`, `power_law` |
| `n_vertical_stream` | `nodes/n_stream.gdshader` | — | drip mask | `count`, `min_w`, `max_w`, `bulb_scale` |
| `n_capsule_poly` | `nodes/n_capsule.gdshader` | point list | rounded polygon | `radius`, `samples` |
| `n_warp` | `nodes/n_warp.gdshader` | mask + field | warped mask | `displacement_px` |
| `n_erode_islands` | `nodes/n_erode.gdshader` | mask | cleaned mask | `min_area_px` |
| `n_crust_normal` | `nodes/n_crust.gdshader` | mask | normal | `freq`, `strength`, `wet_mask` |

Determinism: every node seeds from a single `u_seed` uniform. Decal instance N uses `seed = base_seed + N`. This lets you regenerate identical art on any machine, and vary per instance in-engine.

---

## 6. Animation node catalogue

These are the animatable "nodes" for the decals — implement each as a shader uniform driven by `AnimationPlayer` or a single `DecalVFX` script node with a config resource.

| Node | Uniform(s) | Effect | Typical duration |
|---|---|---|---|
| `SPAWN_STAMP` | `stamp_progress` | mask scales 0.94→1.0, opacity 0→1 | 0.25 s |
| `SPREAD` | `spread` | mask dilates along `flow_tex` | 4–8 s |
| `FLOW` | `flow_speed` | UV scroll along flow | continuous |
| `DRY` | `dryness` | wetness ↓, roughness ↑, hue → `#461009` | 30–90 s |
| `WET_CORE` | `core_pulse` | roughness oscillation on the fresh core | 0.05 Hz |
| `DRIP_FALL` | `drip_phase[]` | bulb Y advance, reset on arrrival | loop, staggered |
| `BULB_GROW` | `bulb_scale` | +8% radius before release | 3 s |
| `RIPPLE` | `ripple_r` | expanding ring from an event position | 0.6 s |
| `ARC_DRAW` | `reveal` | procedural reveal along a curve | 0.7 s |
| `AGE` | `age[]` | per-instance time since creation (the print trail) | 0→∞ |
| `TAIL_ERODE` | `erode` | rear of a smear dissolves into droplets | 30 s |
| `MARKED` | `mark_intensity` | `#b4da48` emission + `glitch_amount` boost | ritual areas only |

Rules: `age` never decreases; `dryness` is monotonic per instance; no node may alter geometry at runtime on Path 2 meshes (morph only via shader); `drip_phase` array length is fixed at build time for pooling.

---

## 7. TouchDesigner patch specification

One patch, `blood_decals.toe`, generating every map. This is the authoring surface — hand-tweak here, export to the game. No generative models anywhere in the chain.

**Structure (named exactly as below so the export script can find them):**

```
/blood_decals
  /generators
    /D1_spray      ... /D8_spatter   (eight networks, each: fbm -> threshold -> blur -> erode_islands)
    /shared                          (n_fbm, n_warp, n_crust_normal as reusable baseCOMPs)
  /compositors
    /mask_out      (8 Null TOPs, each exporting 1024², 8-bit, sRGB off)
    /wetness_out   (8 Null TOPs, 1024², 8-bit)
    /normal_out    (8 Null TOPs, 1024², 8-bit, normal map, sRGB off)
    /flow_out      (8 Null TOPs, 1024², 8-bit, RG encoded)
    /orm_out       (pack: R=occlusion, G=roughness, B=0)
  /effects
    /generated_mask   (the section 3 chain, preview only)
  /export
    /file_out         (one per map: 1024² PNG, 16-bit where normal)
```

**Per-generator chain, in order** (this is the literal node list for D1 and D2; the others swap the middle):

```
Noise TOP (simplex, 4 oct)      ->  Level TOP      ->  Threshold TOP   ->
Blur TOP (2 px)                 ->  Threshold TOP  ->  Erode/Island TOP ->
Warp TOP (uses shared n_fbm)    ->  Blur TOP       ->  Null TOP (mask_out)
```

**Parameter table to expose in every generator:** `octaves`, `gain`, `scale_px`, `threshold_hi`, `threshold_lo`, `blur_px`, `min_island_px`, `warp_px`, `seed`. Nine knobs, no more — if a shape needs a tenth, it's a new generator.

**Cook settings:** all generators cook at 30 Hz for authoring; set every `Null TOP` to `Cook always = OFF` and export only on a pulse. Resolution 1024² everywhere except the normal maps (2048² for D2, D4 — the two hero reliefs).

**Export naming contract** (goes in the same folder structure the game uses):

```
decal_<id>_mask.png      1024  (2048 for D2/D4)
decal_<id>_wet.png       1024
decal_<id>_normal.png    2048  (D2/D4 only; 1024 otherwise)
decal_<id>_flow.png      512   (RG)
decal_<id>_orm.png       1024  (R/G/B packed)
```

**The effects pass in TD as well:** wire `/compositors/mask_out` through the `generated_mask` chain to preview exactly what the game will show. If the TD preview and the game disagree, the game is wrong — the shader is the source of truth.

**Loops:** if you'd rather author the animated node behaviour visually, each `DRY`/`DRIP_FALL`/`SPREAD` cycle can be rendered as a short loop TOP here and baked to a flipbook; the flipbook then replaces the runtime uniform on low-end targets. Export flipbooks as 8×8 atlases, 1024², `decal_<id>_flux.png`.

---

## 8. Godot 4 integration

**Files to produce:**

```
assets/decals/
  blood_decal.gdshader          the shared material shader
  generated_mask.gdshader       the project-wide effects pass
  decal_set.tres                a Resource: one entry per decal id, all params
  DecalInstance.gd              per-instance driver (age, dryness, phase, seed)
  meshes/d1_spray.mesh ... d8_spatter.mesh
  maps/decal_*.png
```

**Shader skeleton** (`blood_decal.gdshader` — spatial, transparent, unshaded, custom light faked):

```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D mask_tex : hint_default_black;
uniform sampler2D wet_tex  : hint_default_black;
uniform sampler2D normal_tex : hint_default_black;
uniform sampler2D flow_tex : hint_default_black;
uniform sampler2D orm_tex  : hint_default_black;

uniform vec3 dried_col     : source_color = vec3(0.275, 0.063, 0.035); // #461009
uniform vec3 arterial_col  : source_color = vec3(0.659, 0.157, 0.102); // #a8281a
uniform vec3 wet_hi_col    : source_color = vec3(0.788, 0.263, 0.227); // #c9433a
uniform vec3 marked_col    : source_color = vec3(0.706, 0.855, 0.282); // #b4da48

uniform float dryness       : hint_range(0.0, 1.0) = 0.2;
uniform float spread        : hint_range(0.0, 1.0) = 0.0;
uniform float flow_speed    : hint_range(0.0, 1.0) = 0.0;
uniform float stamp         : hint_range(0.0, 1.0) = 1.0;
uniform float mark_intensity: hint_range(0.0, 1.0) = 0.0;
uniform float uv_seed       : hint_range(0.0, 64.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    vec3 flow = texture(flow_tex, uv).rgb;
    uv -= flow.rg * flow_speed * TIME * 0.15;
    uv = mix(uv, (uv - 0.5) / max(0.05, 1.0 - spread) + 0.5, 1.0); // SPREAD dilate

    float m = texture(mask_tex, uv).r;
    m = smoothstep(0.5 - 0.06 * (1.0 - stamp), 0.5 + 0.06, m);

    float wet = texture(wet_tex, uv).r * (1.0 - dryness);
    vec3 col = mix(dried_col, arterial_col, wet);
    col = mix(col, wet_hi_col, wet * wet * 0.7);

    vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
    vec3 o = texture(orm_tex, uv).rgb;
    float rough = mix(0.72, 0.12, wet);

    ALBEDO = mix(col, marked_col, mark_intensity * wet);
    ALPHA = m * (0.55 + 0.45 * wet) * stamp;
    ROUGHNESS = rough;
    METALLIC = 0.0;
    NORMAL_MAP = n * mix(1.0, 0.35, wet);
    EMISSION = marked_col * mark_intensity * 0.5;
}
```

Notes: `ALPHA` fading with dryness is what makes old stains read as *thin* on the floor. On Path 2 meshes, switch `render_mode` to opaque and delete the `ALPHA` line — the silhouette is geometry there.

**Placement:** Path 1 decals as `MeshInstance3D` quads, `position.y += 0.002` above the surface, aligned to the surface normal. Batch by material; eight decals = eight `MultiMeshInstance3D` where the same decal repeats. Path 2 reliefs as normal `MeshInstance3D` under a `StaticBody3D` group.

**Per-instance driver:**

```gdscript
class_name DecalInstance extends Node3D
@export var decal_id : int
@export var spawn_wetness := 1.0
@export var dry_duration := 45.0
var age := 0.0
func _process(delta: float) -> void:
    age += delta
    var dryness := clamp(age / dry_duration, 0.0, 1.0)
    var mat := (get_child(0) as MeshInstance3D).get_active_material(0) as ShaderMaterial
    mat.set_shader_parameter("dryness", dryness)
    mat.set_shader_parameter("uv_seed", float(decal_id))
    mat.set_shader_parameter("stamp", clamp(age / 0.25, 0.0, 1.0))
```

**Performance targets:** decal draw calls under 8 for the whole level via multimesh; Path 2 reliefs under 40 k tris total; no decal casts shadows; no decal writes depth. The effects pass is one full-screen quad at half resolution, composited before the UI.

---

## 9. Atlas and resolution budget

- Decal maps live in a **2048² atlas** per map type (`mask`, `wet`, `normal`, `orm`), 4 columns × 2 rows, one cell per decal — 512² per decal at 2048², or 1024² per cell at a 4096² atlas for the hero pair. D2 and D4 get their own 1024² textures rather than atlas cells, because they're seen at 0.3–0.8 m.
- UV convention: each decal's cell is authored with **1 px of bleed** on all sides; the shader samples with `textureLod(…, 0.0)` to avoid mip bleed across cells.
- `flow` maps stay at 512² per decal and are never atlased (they need anisotropy).
- Total VRAM target: under 24 MB for the full set including flipbooks.

**World-size → texel-density rule:** aim for **≥ 512 texels per metre** at the player's closest habitual distance. Handprint at 0.20 m and 1024² = 5120 texels/m, correct. Pool at 1.6 m and 1024² = 640 texels/m, correct. Trail prints at 0.28 m each and a 512² cell = 1828 texels/m, fine.

---

## 10. Retexture contract (hand art, no AI)

The geometry, shaders, animation and placement never change. To replace the art with your own, you supply maps under the same names:

| Give me | Format | Notes |
|---|---|---|
| `decal_<id>_mask.png` | 8-bit grayscale, PNG | white = ink. Keep the **same silhouette bbox proportions** from section 4, or geometry will no longer line up. |
| `decal_<id>_wet.png` | 8-bit grayscale | white = fresh. Pure metadata — a hand-painted mask works fine. |
| `decal_<id>_orm.png` | 8-bit RGB | R occlusion, G roughness, B = 0. Honour the roughness bands in section 2 or the wet look breaks. |
| `decal_<id>_color.png` *(optional)* | 8-bit RGB | only if you want painted colour instead of the two-tone ramp. Sets a `use_color_tex` flag in `decal_set.tres`. |
| `decal_<id>_normal.png` *(optional)* | 8-bit RGB normal | for photographed reliefs. |

Rules for hand art: square power-of-two, sRGB off for normal/orm, on for colour, no baked-in lighting, no alpha in the mask (ship alpha as a separate channel if needed), and the mask must be a closed silhouette — holes in the middle will make the relief mesh non-manifold.

**Photograph workflow if you shoot real blood stand-ins:** shoot flat-on, diffuse light, no specular, on a matte mid-grey card at 45°, then in TouchDesigner: `Level` to normalise, `Chroma Key` on the card grey into the mask, `Edge` + `Blur` for the wetness falloff, `Normal Map TOP` for normals, `Channel Mix` for the ORM pack, `Blur` for the flow field from the mask gradient. Export through the same `file_out` nodes. Same filenames, and nothing downstream notices.

---

## 11. Deliverables Claude should produce

1. `nodes/` — the eight primitive `.gdshader` files from section 5, each with a `u_seed` and the documented params.
2. `blood_decal.gdshader` — as specced in section 8, Path 1 and Path 2 variants.
3. `generated_mask.gdshader` — the five-stage effects chain, with the uniforms listed in section 3.
4. `DecalInstance.gd` + `decal_set.tres` — driver and parameter resource, eight entries.
5. `meshes/` — the eight meshes; D1, D5, D6, D7 are quads; D2, D3, D4, D8 are reliefs built by the section 2 recipe.
6. `blood_decals.toe` structure — a written node list per section 7 that a TD-literate person can build in an afternoon; every generator's nine exposed params, every export node's path.
7. `tools/export_decals.py` — reads the TD export folder, validates the naming contract, writes the ORM pack if missing, checks power-of-two and reports any silhouette whose bbox deviates more than 5% from the section 4 measurements.
8. `ATLAS.md` — the atlas layout and the exact UV rects for each decal cell.

Do not invent new decals, new colours or new animation nodes. If something in this brief is internally inconsistent, stop and say which line contradicts which — do not silently pick one.

---

## Appendix — measured reference data

| ID | bbox px | aspect | ink % of frame | mean ink RGB | dominant clusters (% of ink) | delivered ground |
|---|---|---|---|---|---|---|
| D1 spray | 738×666 | 1.11:1 | 24.4 | (73,22,15) | `#461009` 60, `#a8281a` 16, black 8 | white — ignore |
| D2 pool | 840×640 | 1.31:1 | 16.9 | (66,39,32) | `#461009` 53, olive 15, `#b0552a` 14 | black ✔ |
| D3 drag | 818×818 | 1.00:1 | 12.5 | (100,25,15) | `#461009` 52, `#a8281a` 39 | black ✔ |
| D4 handprint | 642×814 | 0.79:1 | 15.8 | (100,25,15) | `#a8281a` 44, `#461009` 41 | black ✔ |
| D5 drips | 881×841 | 1.05:1 | 41.7 | (57,18,12) | black 44, `#461009` 33, `#a8281a` 14 | white — ignore |
| D6 arc | 885×488 | 1.81:1 | 6.3 | (89,21,12) | `#461009` 48, `#a8281a` 16 | black ✔ |
| D7 trail | 620×266 | 2.33:1 | 2.1 | (86,24,19) | `#461009` 53, `#a8281a` 14 | black ✔ |
| D8 spatter | — | ~1:1 | target 10–18 | — | — | not generated |

All seven were delivered at 1024×1024. D1 and D5 came back on white grounds — a generation defect, not a design choice; their proportions are still valid, their backgrounds are not.
