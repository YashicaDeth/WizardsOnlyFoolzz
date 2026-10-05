shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Diggable soil (DigTerrain): the vertex colour carries depth (deeper is darker
// and redder); this breaks it up in world space so a cut face and the top read
// as packed, grimy dirt, not a flat plane. Clods, grit, wet blotches, stones.

uniform float scale = 1.6;
uniform vec3 grime : source_color = vec3(0.10, 0.075, 0.055);
uniform vec3 stone : source_color = vec3(0.32, 0.30, 0.27);
uniform float wet = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		sum += noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The tint is authored in sRGB (MaterialToughness colours).
	COLOR.rgb = pow(COLOR.rgb, vec3(2.2));
}

void fragment() {
	vec3 p = world_pos * scale;
	float clods = fbm(p * 2.0);
	float blotch = smoothstep(0.42, 0.7, fbm(p * 0.45 + vec3(7.1)));
	float grit = noise(p * 38.0);
	// Small stones: sparse bright cells of a fine lattice.
	vec3 cell = floor(p * 9.0);
	float pebble = step(0.93, hash(cell)) * smoothstep(0.5, 0.2, length(fract(p * 9.0) - 0.5));
	vec3 soil = COLOR.rgb * (0.7 + 0.6 * clods) * (0.85 + 0.3 * grit);
	soil = mix(soil, grime, blotch * 0.65);
	soil = mix(soil, stone * (0.7 + 0.3 * grit), pebble * 0.8);
	// Cut walls (steep faces) are fresher and a little lighter than the trodden top.
	float steep = 1.0 - abs(world_normal.y);
	soil *= mix(0.85, 1.05, steep);
	ALBEDO = soil * mix(1.0, 0.6, wet);
	ROUGHNESS = mix(0.96, 0.55, max(wet, blotch * 0.35)) - pebble * 0.2;
	SPECULAR = 0.3;
}
