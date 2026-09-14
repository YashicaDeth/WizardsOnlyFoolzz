shader_type canvas_item;

// The title backdrop, and the thing Greg described as "the blue invertred side
// attacking the screen".
//
// His reference image is one photograph with a vertical seam down the middle:
// the left half as shot, the right half inverted into cyan. Baking that would
// give a fixed seam. Done here instead, so the seam can *move* — it sweeps in
// from the right, tears chromatically as it travels, and the inverted half
// eats the frame rather than sitting in it.
//
// Everything is driven from `attack` (0 = untouched photograph, 1 = the invert
// has taken the whole screen) so the menu can drive it from a tween and the
// same shader covers the fade-in, the hold and the retreat.

uniform sampler2D backdrop : source_color, filter_linear_mipmap;
// 0..1. How far the inverted side has come across.
uniform float attack : hint_range(0.0, 1.0) = 0.0;
// 0..1. Master fade, so the whole plate can come up out of black.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float clock = 0.0;
// How hard the seam tears. In pixels of UV at the seam itself.
uniform float tear : hint_range(0.0, 0.08) = 0.022;
uniform vec3 invert_tint = vec3(0.35, 0.95, 1.0);

// Cheap value noise. The seam needs to jitter per-scanline rather than be a
// ruler-straight edge, which is what separates a glitch from a wipe.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// The seam. At attack 0 it sits just off the right edge; at 1 it has passed
	// the left one. Jittered per horizontal band so it reads as torn.
	float band = floor(uv.y * 120.0);
	float jitter = (hash(vec2(band, floor(clock * 9.0))) - 0.5) * 0.035 * attack;
	float seam = mix(1.08, -0.08, attack) + jitter;

	// Distance from the seam decides both the tearing and which side we are on.
	float d = uv.x - seam;
	float edge = 1.0 - smoothstep(0.0, 0.14, abs(d));

	// Chromatic displacement, strongest at the seam. The three channels are
	// sampled at different offsets, which is the whole look of his composite.
	float push = tear * edge * (0.6 + 0.4 * sin(clock * 3.1 + uv.y * 22.0));
	vec2 skew = vec2(push, 0.0);
	float r = texture(backdrop, uv + skew).r;
	float g = texture(backdrop, uv).g;
	float b = texture(backdrop, uv - skew).b;
	vec3 shot = vec3(r, g, b);

	// The inverted half. Not a plain 1-x: his is inverted *and* pushed to cyan,
	// so the invert is tinted rather than neutral.
	vec3 flipped = (vec3(1.0) - shot) * invert_tint;

	// Which side of the seam this pixel is on. Softened slightly so the join is
	// a torn edge rather than an aliased line.
	float side = smoothstep(-0.004, 0.004, -d);
	vec3 col = mix(shot, flipped, side);

	// A hot line riding the seam itself — the leading edge of the attack.
	col += vec3(0.45, 0.95, 1.0) * edge * edge * 0.55 * attack;

	// Scanline tearing just behind the front: whole bands slip sideways.
	float slip = step(0.82, hash(vec2(band, floor(clock * 14.0)))) * attack;
	if (slip > 0.0 && abs(d) < 0.25) {
		vec2 slipped = uv + vec2((hash(vec2(band, 7.0)) - 0.5) * 0.06, 0.0);
		col = mix(col, texture(backdrop, slipped).rgb, 0.55);
	}

	// Vignette, so the plate sits under type rather than competing with it.
	float vig = 1.0 - 0.55 * length((uv - 0.5) * vec2(1.15, 1.0));
	col *= vig;

	COLOR = vec4(col * reveal, reveal);
}
