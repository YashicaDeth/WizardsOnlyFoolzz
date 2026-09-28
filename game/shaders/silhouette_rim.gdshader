shader_type spatial;
// Greg, 29 September (question box): in the dark rooms enemies keep a faint
// readable silhouette between the pools of light. A thin cold fresnel rim,
// added over the body and lit by nothing, so it reads the same in a pool and
// between them, and lights nothing around it. Fog is off because fog on an
// additive pass adds the fog colour again; the rim fades with distance itself.
// Both sides and `abs()`: the BaselineHuman rig's meshes are double-sided
// (cull disabled), wound the other way round, so culling back faces culled
// every face you can see, and a flipped normal would light the whole body.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 rim_color : source_color = vec3(0.52, 0.66, 0.72);
uniform float strength : hint_range(0.0, 2.0) = 0.45;
uniform float thinness : hint_range(1.0, 8.0) = 3.5;
// Metres: full rim up to `fade_start`, gone by `fade_end`.
uniform float fade_start = 16.0;
uniform float fade_end = 36.0;

void fragment() {
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float near = 1.0 - smoothstep(fade_start, fade_end, length(VERTEX));
	ALBEDO = rim_color * pow(1.0 - facing, thinness) * strength * near;
}
