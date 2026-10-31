shader_type spatial;
render_mode cull_disabled;

// The surface of the rivers of blood below the dry falls
// (blood_waterfall_exit.gd): deep and glossy, moving along `flow`, with dark
// clots riding on it. A little emission keeps it reading as red in shadow
// rather than going to black like water does.

uniform vec4 deep : source_color = vec4(0.10, 0.0, 0.008, 1.0);
uniform vec4 bright : source_color = vec4(0.50, 0.025, 0.035, 1.0);
uniform vec4 clot : source_color = vec4(0.06, 0.008, 0.012, 1.0);
uniform vec2 flow = vec2(0.0, -0.7);
uniform float clot_amount : hint_range(0.0, 1.0) = 0.5;
uniform float glow = 0.12;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = wpos.xz * 0.32 - flow * TIME * 0.5;
	float a = fbm(p);
	float b = fbm(p * 2.6 + 5.0 - flow * TIME * 0.35);
	vec3 colour = mix(deep.rgb, bright.rgb, smoothstep(0.3, 0.78, a * 0.6 + b * 0.4));
	float clots = smoothstep(0.66, 0.72, fbm(wpos.xz * 0.8 - flow * TIME * 0.22 + 11.0)) * clot_amount;
	colour = mix(colour, clot.rgb, clots);
	// Ripples from the noise slope, so the gloss catches the sky.
	float e = 0.08;
	float ax = fbm(p + vec2(e, 0.0)) - a;
	float az = fbm(p + vec2(0.0, e)) - a;
	vec3 wn = normalize(vec3(-ax * 3.0, 1.0, -az * 3.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = colour;
	ROUGHNESS = mix(0.06, 0.5, clots);
	METALLIC = 0.15;
	SPECULAR = 0.8;
	EMISSION = colour * glow;
}
