shader_type spatial;
render_mode cull_disabled;

// Cloth and foliage in the weather station: sway grows with height up the
// mesh (pinned at y = 0) and with `wind`, which the weather state sets.

uniform vec4 tint : source_color = vec4(0.4, 0.1, 0.06, 1.0);
uniform float wind = 0.0;
uniform float height = 2.0;
uniform float stiffness = 1.0;
uniform float wetness = 0.0;
uniform float alpha_cut = 0.0;
// Cloth hangs from its top edge; foliage is rooted at its foot.
uniform bool pinned_top = false;

void vertex() {
	float lift = clamp(VERTEX.y / max(height, 0.01), 0.0, 1.0);
	if (pinned_top) { lift = 1.0 - lift; }
	float gust = sin(TIME * (1.6 + wind * 3.0) + VERTEX.x * 2.3 + NODE_POSITION_WORLD.x) * 0.5 + 0.5;
	float flutter = sin(TIME * 11.0 + VERTEX.y * 7.0 + VERTEX.x * 5.0) * 0.12 * wind;
	float bend = (0.05 + wind * (0.6 + gust * 0.9)) * lift * lift / stiffness;
	VERTEX.z += bend + flutter * lift;
	VERTEX.x += sin(TIME * 2.2 + VERTEX.y * 3.0) * 0.08 * wind * lift;
}

void fragment() {
	ALBEDO = tint.rgb * mix(1.0, 0.55, wetness);
	ROUGHNESS = mix(0.9, 0.3, wetness);
	if (alpha_cut > 0.0) {
		float leaf = step(0.35, fract(sin(dot(floor(UV * 9.0), vec2(12.9898, 78.233))) * 43758.5453));
		if (leaf < 0.5) { discard; }
	}
}
