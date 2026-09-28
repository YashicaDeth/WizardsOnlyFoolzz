shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Concentric live-wire rings on the ground under a locked target. Each ring
// crackles along its length and the set breathes outward; `strength` fades
// the whole thing in and out as lock is taken and dropped.

uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 wire_colour : source_color = vec3(0.28, 0.95, 0.72);
uniform vec3 hot_colour : source_color = vec3(0.86, 0.34, 0.15);

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float glow = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float radius = 0.34 + fi * 0.24 + fract(TIME * 0.35 + fi * 0.33) * 0.06;
		// The wire jitters along its length, redrawn a dozen times a second.
		float step_t = floor(TIME * 12.0 + fi * 7.0);
		float jitter = (hash(floor(a * 14.0) + step_t * 3.1 + fi) - 0.5) * 0.035;
		float d = abs(r - radius - jitter);
		glow += smoothstep(0.022, 0.0, d) * (1.0 - fi * 0.22);
		glow += smoothstep(0.08, 0.0, d) * 0.18;
	}
	float edge = smoothstep(1.0, 0.85, r);
	vec3 c = mix(wire_colour, hot_colour, smoothstep(0.7, 0.95, r));
	ALBEDO = c * glow * 1.6;
	ALPHA = clamp(glow * edge * strength, 0.0, 1.0);
}
