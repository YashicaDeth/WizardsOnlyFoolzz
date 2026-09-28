shader_type canvas_item;
// The house look (Greg, 26 September: "reconceptualise the current look of
// the game" from the Higgsfield set, "without making things feel really AI
// gen"). Nothing generated is drawn: the concept art only set the numbers.
// What the in-world renders share, measured (DESIGN/LOOK_FROM_CONCEPTS.md),
// becomes a hardware limitation the game has, not a painting laid over it:
//
//   - a coarse framebuffer: the world resolves in chunky pixels, the HUD
//     above this layer stays sharp;
//   - a small colour depth with an ordered (Bayer) dither, which is where the
//     halftone-looking screen in every render comes from;
//   - a black floor that swallows most of the frame, colour held in the
//     lights and in the haze;
//   - per-area shadow / mid / highlight balance, desaturation, stepped grain.
//
// Drawn from a CanvasLayer below every HUD layer, so it grades the 3D view
// only. HouseLook (systems/house_look.gd) sets the uniforms per area.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Screen pixels per world pixel (2.0 at 720p is roughly a 640x360 buffer).
uniform float pixel_size = 2.0;
// Steps per channel before the dither. Low enough that fog and light falloff
// band, high enough that faces and signs still read.
uniform float levels = 26.0;
uniform float dither_strength : hint_range(0.0, 1.5) = 1.0;
uniform float black_point : hint_range(0.0, 0.3) = 0.03;
uniform float gamma : hint_range(0.5, 2.0) = 1.0;
uniform float exposure : hint_range(0.3, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// Colour balance per tonal range: 0.5 grey is neutral.
uniform vec3 shadow_balance : source_color = vec3(0.5);
uniform vec3 mid_balance : source_color = vec3(0.5);
uniform vec3 high_balance : source_color = vec3(0.5);
uniform float balance_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grain : hint_range(0.0, 0.2) = 0.025;
// Grain is re-rolled at this rate, not every frame: stop-motion, not static.
uniform float grain_rate = 12.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.3;

const mat4 BAYER = mat4(
	vec4(0.0, 12.0, 3.0, 15.0),
	vec4(8.0, 4.0, 11.0, 7.0),
	vec4(2.0, 14.0, 1.0, 13.0),
	vec4(10.0, 6.0, 9.0, 5.0)
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
	vec2 uv = (cell + 0.5) * max(pixel_size, 1.0) * SCREEN_PIXEL_SIZE;
	vec3 source = texture(screen_tex, uv).rgb;
	vec3 c = source * exposure;

	// Black floor first: everything under it is gone, the rest is restretched.
	c = max(c - vec3(black_point), vec3(0.0)) / (1.0 - black_point);
	c = pow(c, vec3(gamma));

	float l = luma(c);
	c = mix(vec3(l), c, saturation);

	float shadow_w = 1.0 - smoothstep(0.0, 0.35, l);
	float high_w = smoothstep(0.45, 1.0, l);
	float mid_w = clamp(1.0 - shadow_w - high_w, 0.0, 1.0);
	vec3 balance = (shadow_balance - 0.5) * shadow_w + (mid_balance - 0.5) * mid_w + (high_balance - 0.5) * high_w;
	c += balance * balance_amount * mix(0.35, 1.0, l);

	vec2 centred = SCREEN_UV - 0.5;
	c *= 1.0 - dot(centred, centred) * vignette * 1.6;

	float stepped = floor(TIME * grain_rate);
	c += (hash(cell + stepped * 17.13) - 0.5) * grain;

	// Ordered dither into a short colour depth, on the world-pixel grid.
	ivec2 b = ivec2(mod(cell, 4.0));
	float threshold = (BAYER[b.x][b.y] + 0.5) / 16.0 - 0.5;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5 + threshold * dither_strength) / levels;

	COLOR = vec4(mix(texture(screen_tex, SCREEN_UV).rgb, clamp(c, 0.0, 1.0), strength), 1.0);
}
