shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled, cull_back;

// The censor as the body-cam breaking up (Greg, 24 September: "body-cam
// glitch", on by default). Whatever is behind this volume is re-read from the
// screen in coarse blocks: some blocks slip sideways like a datamosh, the
// channels split, scanlines run through it, and now and then a block goes
// REC-red. It hides detail and keeps the silhouette and the blood's colour.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float cell = 14.0;
uniform float rate = 11.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 res = VIEWPORT_SIZE;
	float tick = floor(TIME * rate);
	// Tape-like tearing: whole rows of the feed slip sideways by a random
	// amount each tick, then the picture is re-read in wide, short blocks.
	float row = floor(FRAGCOORD.y / (cell * 0.6));
	float slip = (hash(vec2(row, tick)) - 0.5) * cell * 3.0 * step(0.55, hash(vec2(row * 1.7, tick + 3.0)));
	vec2 px = FRAGCOORD.xy + vec2(slip, 0.0);
	vec2 size = vec2(cell * 1.7, cell * 0.6);
	vec2 block = floor(px / size);
	float h = hash(block + vec2(tick, tick * 0.37));
	vec2 uv = (block * size + size * 0.5) / res;
	// Datamosh: a few blocks carry the picture from the row above.
	if (h > 0.84) {
		uv.y -= size.y * 2.0 / res.y;
	}
	float split = 3.0 / res.x;
	vec3 color = vec3(
		texture(screen_texture, uv + vec2(split, 0.0)).r,
		texture(screen_texture, uv).g,
		texture(screen_texture, uv - vec2(split, 0.0)).b);
	// A cheap sensor: flattened colour, hard scanlines, grain.
	float luma = dot(color, vec3(0.3, 0.59, 0.11));
	color = mix(color, vec3(luma) * vec3(1.05, 0.95, 0.9), 0.45);
	color *= 0.72 + 0.28 * step(0.5, fract(FRAGCOORD.y / 3.0));
	color += (hash(FRAGCOORD.xy + tick) - 0.5) * 0.08;
	// Now and then a block drops out to the REC red of the body-cam.
	if (h > 0.97) {
		color = mix(color, vec3(0.88, 0.2, 0.12), 0.7);
	} else if (h < 0.03) {
		color *= 0.15;
	}
	ALBEDO = color;
}
