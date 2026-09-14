shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// AS4.3/AS4.4. The long horizontal crawl across the underside of a storm,
// not a flash — several jagged near-horizontal branches built from hashed
// segment jitter rather than noise, so it reads as bolts travelling sideways
// and not as fog. Everything that makes it a *crawl* rather than a line that
// simply appears is driven from `storm_weather.gd`, every frame, as plain
// floats: `front` (0..1) is how far the crawl has travelled since the strike
// began, and `intensity` is the strike's own fade. Nothing here reads engine
// time directly, so one script stays the single place a strike's timing lives.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float front : hint_range(0.0, 1.0) = 0.0;
uniform float seed_value = 0.0;
uniform bool red = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1)) + seed_value) * 43758.5453123);
}

// One branch: a jagged, mostly-horizontal line at a given vertical offset,
// visible only behind the travelling `front`.
float branch(vec2 uv, float y_offset, float seed) {
	float y = y_offset + (hash(vec2(seed, 1.0)) - 0.5) * 0.15;
	float segment = floor(uv.x * 9.0);
	float jitter = (hash(vec2(segment, seed)) - 0.5) * 0.1;
	float line_y = y + jitter;
	float d = abs(uv.y - line_y);
	float core = smoothstep(0.012, 0.0, d);
	float glow = smoothstep(0.09, 0.0, d) * 0.35;
	float window = smoothstep(front - 0.55, front, uv.x) * smoothstep(front + 0.08, front, uv.x - 1.0);
	return (core + glow) * window;
}

void fragment() {
	vec2 uv = UV;
	float bolt = 0.0;
	for (int i = 0; i < 4; i++) {
		bolt += branch(uv, 0.28 + float(i) * 0.16, seed_value + float(i) * 17.0);
	}
	bolt = clamp(bolt, 0.0, 1.0);
	vec3 tint = red ? vec3(0.85, 0.14, 0.16) : vec3(0.82, 0.88, 1.0);
	ALBEDO = tint;
	ALPHA = bolt * intensity;
	EMISSION = tint * bolt * intensity * 6.0;
}
