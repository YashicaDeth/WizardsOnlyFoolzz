shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// PiFrac-DEV Studio's "Glitch Spider particle system" reference — a burst of
// jagged cracks radiating outward from a point, like a spider's legs or
// shattering glass, with a glitchy colour split rather than one clean tint.
// `glitch_spider.gd` drives `intensity` up fast and lets it fade slower, and
// reseeds `seed_value`/`legs` each trigger so no two bursts crack the same way.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float seed_value = 0.0;
uniform float legs : hint_range(3.0, 12.0) = 7.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1)) + seed_value) * 43758.5453123);
}

// One leg: a jagged line radiating outward from the centre at `angle`,
// segmented and hashed rather than smooth, so it reads as a fracture rather
// than a drawn ray, and tapering off before it reaches the edge.
float leg(vec2 uv, float angle, float seed) {
	vec2 dir = vec2(cos(angle), sin(angle));
	vec2 perp = vec2(-dir.y, dir.x);
	float along = dot(uv, dir);
	float across = dot(uv, perp);
	if (along < 0.0) {
		return 0.0;
	}
	float segment = floor(along * 9.0);
	float jitter = (hash(vec2(segment, seed)) - 0.5) * 0.08 * along;
	float d = abs(across - jitter);
	float width = 0.008 + along * 0.012;
	float core = smoothstep(width, 0.0, d);
	float taper = 1.0 - smoothstep(0.3, 0.6, along);
	return core * taper;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float burst = 0.0;
	for (int i = 0; i < 12; i++) {
		if (float(i) >= legs) {
			break;
		}
		float angle = (float(i) / legs) * TAU + hash(vec2(float(i), seed_value)) * 0.3;
		burst += leg(uv, angle, seed_value + float(i) * 13.7);
	}
	burst = clamp(burst, 0.0, 1.0);
	// A glitchy colour split: mostly a cold fracture tint, with blocky
	// magenta tearing through part of it rather than one clean colour.
	vec3 tint = vec3(0.82, 0.9, 1.0);
	float tear = step(0.55, hash(vec2(floor(uv.x * 18.0), floor(uv.y * 5.0 + seed_value * 7.0))));
	vec3 glitch_tint = vec3(1.0, 0.18, 0.55);
	vec3 color = mix(tint, glitch_tint, tear * 0.4);
	ALBEDO = color;
	ALPHA = burst * intensity;
	EMISSION = color * burst * intensity * 8.0;
}
