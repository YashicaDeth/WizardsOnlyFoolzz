shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// The doctor, once the player knows what he is: light, not a man. Cyan
// scanlines climbing in world space, a fresnel rim, a flicker, and glitch
// bands that tear the mesh sideways. The three colour channels read the
// scanlines at slightly different heights, so every line splits into a red /
// cyan fringe the way a cheap projector's does. Used by `doctor_vehicle_bay.gd`
// on the doctor and by `hologram_call.gd` on the call's miniature.

uniform vec4 tint : source_color = vec4(0.30, 0.95, 1.0, 1.0);
uniform float strength : hint_range(0.0, 3.0) = 1.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float line_density = 25.0;
uniform float split = 0.012;

varying vec3 world_pos;

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Glitch bands: a few horizontal slices, re-picked ten times a second,
	// shoved sideways by an amount that grows with `glitch`.
	float tick = floor(TIME * 10.0);
	float band = floor(w.y * 6.0);
	float pick = hash(band + tick * 7.1);
	float tear = step(0.82 - glitch * 0.4, pick) * (hash(band * 3.3 + tick) - 0.5);
	VERTEX.x += tear * (0.05 + glitch * 0.35);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Scanlines run in screen space (a projector's raster, and even on a flat
// roof where world height never changes), `line_density` pixels apart / 10.
float lines(float y) {
	float s = sin((y * line_density * 0.01 - TIME * 3.2) * 6.2831);
	return 0.35 + 0.65 * smoothstep(0.1, 0.9, s * 0.5 + 0.5);
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.8);
	float px = split * 100.0;
	float r = lines(FRAGCOORD.y + px);
	float g = lines(FRAGCOORD.y);
	float b = lines(FRAGCOORD.y - px);
	float flicker = 0.82 + 0.18 * sin(TIME * 47.0) * sin(TIME * 13.0);
	flicker *= 1.0 - glitch * 0.6 * step(0.5, hash(floor(TIME * 24.0)));
	// A slow bright sweep up the body, the projector re-drawing him.
	float sweep = smoothstep(0.06, 0.0, abs(fract(world_pos.y * 0.35 - TIME * 0.45) - 0.5));
	vec3 base = tint.rgb * vec3(r * 0.9 + 0.1, g, b) * (0.28 + rim * 1.1);
	base += vec3(1.0, 0.25, 0.35) * (r - b) * 0.18 * (1.0 + glitch * 2.0);
	base += tint.rgb * sweep * 0.5;
	ALBEDO = base * flicker * strength;
}
