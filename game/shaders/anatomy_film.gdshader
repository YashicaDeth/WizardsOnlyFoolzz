shader_type canvas_item;
render_mode blend_add;
// The loading screen's X-ray, as film that keeps failing (Greg, 2026-09-24):
// the anatomy "blurs and expands into datamosh, CRT effects ... goes out of
// focus and expands or dithers". One slow cycle per `period` seconds:
//   sharp -> out of focus and swelling -> datamosh blocks -> Bayer dither ->
//   back to sharp, with scanlines and a curved tube face throughout.

uniform float period = 7.5;
uniform float seed = 0.0;
uniform vec2 rect_size = vec2(760.0, 760.0);
// For captures: pin the cycle to one point instead of the clock.
uniform float phase_override = -1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bayer4(vec2 px) {
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

vec3 blurred(sampler2D tex, vec2 uv, float radius) {
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = 1.0 / (1.0 + float(x * x + y * y));
			sum += texture(tex, uv + vec2(float(x), float(y)) * radius).rgb * w;
			total += w;
		}
	}
	return sum / total;
}

void fragment() {
	float phase = phase_override >= 0.0 ? phase_override : fract(TIME / period + seed);
	float focus_loss = smoothstep(0.38, 0.55, phase) * (1.0 - smoothstep(0.86, 0.98, phase));
	float mosh = smoothstep(0.52, 0.66, phase) * (1.0 - smoothstep(0.78, 0.88, phase));
	float dither = smoothstep(0.7, 0.8, phase) * (1.0 - smoothstep(0.92, 1.0, phase));

	// A curved tube face: the picture bows toward the corners.
	vec2 centred = UV - 0.5;
	centred *= 1.0 + dot(centred, centred) * 0.12;
	// Swelling: the body expands toward the viewer as it loses focus.
	centred /= 1.0 + focus_loss * 0.55;
	vec2 uv = centred + 0.5;

	vec2 px = UV * rect_size;
	vec2 block = floor(px / 28.0);
	float tick = floor(TIME * 10.0);
	vec2 motion = vec2(hash21(block + tick * 0.01), hash21(block.yx + 5.1 + tick * 0.02)) - 0.5;
	uv += motion * 0.32 * mosh * step(0.3, hash21(block + 2.2));

	float split = 0.004 + 0.01 * mosh;
	vec3 c;
	if (focus_loss > 0.02) {
		float radius = focus_loss * 0.016;
		c = vec3(blurred(TEXTURE, uv + vec2(split, 0.0), radius).r,
				blurred(TEXTURE, uv, radius).g,
				blurred(TEXTURE, uv - vec2(split, 0.0), radius).b);
	} else {
		c = vec3(texture(TEXTURE, uv + vec2(split, 0.0)).r, texture(TEXTURE, uv).g, texture(TEXTURE, uv - vec2(split, 0.0)).b);
	}
	// Chunky: the dither works on 3x3 pixel cells so it reads at a distance.
	float levels = mix(48.0, 3.0, dither);
	c = floor(c * levels + bayer4(floor(px / 3.0)) * dither + 0.5) / levels;
	c *= 0.8 + 0.2 * sin(px.y * 3.14159);
	float outside = step(0.5, max(abs(centred.x), abs(centred.y)));
	COLOR = vec4(c * (1.0 - outside), 1.0) * COLOR;
}
