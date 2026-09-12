shader_type spatial;

// DESIGN/FINAL_V.md §16, Path B: Vertex Animation Texture playback, for the
// Blender deformation Godot cannot rig — melting, splitting, fracturing,
// anything out of geometry nodes. The mesh's own per-frame vertex positions
// are baked into a texture in Blender; this reads them back in the vertex
// stage rather than carrying a skeleton for geometry that never had one.
//
// Infrastructure only. There is no melting/fracturing rig in the project yet
// to bake a real VAT texture from, so this follows the standard convention —
// one column per vertex, one row per frame, RGB an offset normalised into
// `offset_min`..`offset_max` — rather than being verified against real
// content. It has not been asked to deform anything yet; it exists so the
// day a Blender rig can export one, there is already something to read it.
//
// Expects UV2.x to carry each vertex's own column, normalised 0..1 as
// `vertex_index / (vertex_count - 1)` — baked once at export time, the same
// way a lightmap UV is baked rather than computed live. Does not attempt to
// correct normals for the deformation; a production bake would want a second
// texture for those, which nothing here needed yet.

uniform sampler2D vat_texture : filter_linear, repeat_disable;
uniform float frame_count = 1.0;
uniform float fps = 24.0;
uniform vec3 offset_min = vec3(-1.0, -1.0, -1.0);
uniform vec3 offset_max = vec3(1.0, 1.0, 1.0);
uniform float playback_offset = 0.0;
uniform bool loop_playback = true;

void vertex() {
	float progress = TIME * fps / max(frame_count, 1.0) + playback_offset;
	progress = loop_playback ? fract(progress) : clamp(progress, 0.0, 1.0);
	vec3 packed_offset = texture(vat_texture, vec2(UV2.x, progress)).rgb;
	VERTEX += mix(offset_min, offset_max, packed_offset);
}
