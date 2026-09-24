shader_type canvas_item;
// Photo mode grades (item 6). 1 DIGICAM: a 2000s pocket camera -- blown
// highlights, warm cast, chroma smeared across 8x8 JPEG blocks, sensor noise,
// a soft vignette. 2 MONO: hard black and white with grain.

uniform int mode = 1;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	vec3 colour = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(colour, vec3(0.299, 0.587, 0.114));
	float noise = hash(floor(px) + fract(TIME) * 91.0) - 0.5;
	vec2 centred = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(centred, centred) * 0.9;
	if (mode == 1) {
		// Chroma comes from the block's centre, luma stays per pixel.
		vec2 block_uv = (floor(px / 8.0) * 8.0 + 4.0) * SCREEN_PIXEL_SIZE;
		vec3 block = texture(screen_tex, block_uv).rgb;
		float block_luma = dot(block, vec3(0.299, 0.587, 0.114));
		vec3 chroma = block - block_luma;
		vec3 graded = vec3(luma) + chroma * 1.25;
		graded = graded * 1.18 + 0.03;
		graded *= vec3(1.06, 1.0, 0.9);
		graded = 1.0 - exp(-graded * 1.6);
		graded += noise * 0.05;
		COLOR = vec4(graded * mix(1.0, vignette, 0.6), 1.0);
	} else {
		// Lift the shadows before the S-curve: the Hunt is dark, and a straight
		// threshold crushed a dusk scene to black.
		float lifted = pow(max(luma, 0.0), 0.6) + noise * 0.1;
		float contrast = smoothstep(0.05, 0.8, lifted);
		COLOR = vec4(vec3(contrast * vignette), 1.0);
	}
}
