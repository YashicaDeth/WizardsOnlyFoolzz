shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never;

// The destruction station's damage stages, drawn as a shell just outside a
// breakable: nothing at full integrity, hairline cracks as it is hit, wide
// dark fractures and missing chips just before it goes.

uniform float damage = 0.0;
uniform float seed = 1.0;
varying vec3 local_pos;

vec2 cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 h = vec2(dot(i + g, vec2(127.1, 311.7)), dot(i + g, vec2(269.5, 183.3)));
			vec2 o = fract(sin(h) * 43758.5453 + seed);
			float d = length(g + o - f);
			if (d < best) { second = best; best = d; } else if (d < second) { second = d; }
		}
	}
	return vec2(best, second);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos.xy + local_pos.z * 0.7;
	vec2 c = cell(p * mix(2.0, 5.0, damage));
	float edge = c.y - c.x;
	float width = mix(0.0, 0.09, damage);
	float crack = 1.0 - smoothstep(width * 0.5, width, edge);
	float chip = step(0.75, damage) * step(c.x, (damage - 0.75) * 1.4);
	ALBEDO = vec3(0.03, 0.025, 0.02);
	ALPHA = clamp(max(crack * step(0.05, damage), chip) * 0.92, 0.0, 1.0);
}
