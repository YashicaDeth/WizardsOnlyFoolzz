shader_type spatial;
render_mode cull_disabled;

// Weapon and garment skins, painted in the engine (Greg, 24 September:
// procedural patterns, each drop with its own seed, wear that keeps wearing).
// The game's meshes are generated and carry no UVs, so every finish is laid
// out in object space: a skin sits on the object and moves with it.

uniform int finish = 0;
uniform vec4 base_color : source_color = vec4(0.30, 0.31, 0.32, 1.0);
uniform vec4 accent_color : source_color = vec4(0.62, 0.20, 0.14, 1.0);
uniform vec4 third_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform float pattern_seed = 0.0;
uniform float pattern_scale = 14.0;
// 0 mint .. 1 battle-scarred: scratches through to bare metal (or thread).
uniform float wear = 0.1;
// Dried blood in the finish, from use.
uniform float blood = 0.0;
uniform float metal = 0.75;
uniform float gloss = 0.35;
// The object's longest side, so a fade runs end to end on a pistol or a sword.
uniform float span = 0.4;
uniform bool cloth = false;
uniform vec4 bare_color : source_color = vec4(0.55, 0.56, 0.57, 1.0);

varying vec3 obj;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419) + pattern_seed * 0.0137);
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
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return value;
}

// Distance to the nearest cell centre and the one after it, for inlay.
vec2 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash(i + g), hash(i + g + 3.1), hash(i + g + 7.7));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return vec2(d1, d2);
}

void vertex() {
	obj = VERTEX;
}

void fragment() {
	vec3 p = obj * pattern_scale + vec3(pattern_seed * 0.173, pattern_seed * 0.071, pattern_seed * 0.029);
	vec3 col = base_color.rgb;
	float m = metal;
	float r = 1.0 - gloss;
	vec3 glow = vec3(0.0);
	if (finish == 0) {
		// Camo: three stepped blotches.
		float n = fbm(p * 0.55);
		col = n < 0.42 ? base_color.rgb : (n < 0.56 ? accent_color.rgb : third_color.rgb);
	} else if (finish == 1) {
		// Fade: a clean run of colour along the object, seed sets where it starts.
		float t = clamp(0.5 + (obj.x + obj.y * 0.6 + obj.z * 0.8) / max(span, 0.05) * 1.2 + (pattern_seed / 1000.0 - 0.5) * 0.3, 0.0, 1.0);
		col = t < 0.5 ? mix(base_color.rgb, accent_color.rgb, t * 2.0) : mix(accent_color.rgb, third_color.rgb, t * 2.0 - 1.0);
		r *= 0.6;
	} else if (finish == 2) {
		// Marble: veins warped through the stone.
		float v = sin(p.x * 0.9 + p.y * 0.4 + fbm(p * 0.7) * 7.0);
		col = mix(base_color.rgb, accent_color.rgb, smoothstep(0.55, 0.98, abs(v)));
		col = mix(col, third_color.rgb, smoothstep(0.93, 1.0, abs(v)) * 0.8);
	} else if (finish == 3) {
		// Case-hardened: blue and gold oxide pooling over steel. The seed is the
		// whole value of a case-hardened skin: some are nearly all blue.
		float n = fbm(p * 0.45 + 11.0);
		float blue = smoothstep(0.35 + pattern_seed / 4000.0, 0.62, n);
		col = mix(base_color.rgb, accent_color.rgb, blue);
		col = mix(col, third_color.rgb, smoothstep(0.62, 0.8, fbm(p * 0.9 + 3.0)) * 0.7);
	} else if (finish == 4) {
		// Blood rust: corrosion eating in from blotches, wet red at the rims.
		float n = fbm(p * 0.6);
		col = mix(base_color.rgb, third_color.rgb, smoothstep(0.45, 0.6, n));
		col = mix(col, accent_color.rgb, smoothstep(0.58, 0.6, n) * (1.0 - smoothstep(0.6, 0.66, n)));
		r = mix(r, 0.95, smoothstep(0.45, 0.6, n));
	} else if (finish == 5) {
		// Circuit: traces on a dark board, the lit ones glow.
		vec3 q = fract(p * 0.5);
		float trace = step(0.92, max(q.x, q.y)) + step(0.94, max(q.y, q.z));
		col = base_color.rgb;
		float lit = step(0.6, hash(floor(p * 0.5)));
		col = mix(col, accent_color.rgb, clamp(trace, 0.0, 1.0));
		glow = accent_color.rgb * clamp(trace, 0.0, 1.0) * lit * 1.4;
	} else if (finish == 6) {
		// Bone inlay: bone tiles set in dark grout.
		vec2 c = cells(p * 0.5);
		float grout = 1.0 - smoothstep(0.02, 0.09, c.y - c.x);
		col = mix(base_color.rgb * (0.85 + 0.3 * hash(floor(p * 0.5))), third_color.rgb, grout);
		m = mix(0.0, metal, grout);
	} else if (finish == 7) {
		// Gold: polished, with an engraved scroll the light catches.
		float engraving = smoothstep(0.48, 0.5, abs(sin(p.x * 1.3 + fbm(p) * 4.0)) * 0.5 + 0.25);
		col = mix(base_color.rgb, accent_color.rgb, engraving * 0.5);
		m = 1.0;
		r = 0.18 + engraving * 0.15;
		glow = base_color.rgb * 0.06;
	} else if (finish == 8) {
		// Motley: the jester's harlequin diamonds.
		float a = floor((p.x + p.y) * 0.35);
		float b = floor((p.x - p.y) * 0.35 + p.z * 0.1);
		col = mod(a + b, 2.0) < 1.0 ? base_color.rgb : accent_color.rgb;
	} else if (finish == 9) {
		// Tiger stripe: hard bands along the object.
		float s = sin(p.y * 1.1 + fbm(p * 0.8) * 5.0);
		col = mix(accent_color.rgb, third_color.rgb, step(0.35, s));
	}
	if (cloth) {
		m = 0.0;
		r = max(r, 0.88);
	}
	// Wear: scratches and chips through the finish to what is under it. Worn
	// skins lose finish in more places and the chips get bigger.
	float chips = fbm(p * 2.6 + 40.0);
	float scratch = abs(sin((obj.x * 91.0 + obj.y * 57.0 + fbm(p * 1.4) * 6.0)));
	float bare = smoothstep(1.0 - wear * 0.55, 1.0 - wear * 0.5, chips) + step(0.995 - wear * 0.02, scratch) * step(0.15, wear);
	bare = clamp(bare, 0.0, 1.0);
	col = mix(col, bare_color.rgb, bare);
	r = mix(r, cloth ? 1.0 : 0.45, bare);
	// Blood dried into the finish, darkest where it pooled.
	float stain = smoothstep(1.0 - blood, 1.0 - blood + 0.12, fbm(p * 0.8 + 90.0));
	col = mix(col, vec3(0.22, 0.02, 0.02), stain * 0.85);
	r = mix(r, 0.7, stain);
	ALBEDO = col;
	METALLIC = m;
	ROUGHNESS = clamp(r, 0.05, 1.0);
	EMISSION = glow * (1.0 - bare);
}
