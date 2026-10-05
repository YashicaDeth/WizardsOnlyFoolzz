shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// imp-60 (Greg, 5 Oct ~19:00: "improve the bodies further (checker skin,
// helmet heads, hunched idle, ankle gaps)"). The skin a RiggedBody shows on
// a pristine zone: the base character's own painted detail (face, lips,
// knuckles, muscle shading) re-toned to the body's flesh colour, with grime,
// sweat and old scars laid over it in the body's REST space (CUSTOM0), so
// they ride the limb instead of swimming through it when it moves. Noise,
// not a tiled texture: nothing repeats at any range.

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_disable;
// The base texture's average skin colour (linear). Dividing by it leaves the
// painted detail without the painter's skin tone.
uniform vec3 texture_skin = vec3(0.355, 0.163, 0.078);
uniform float detail_strength : hint_range(0.0, 1.5) = 0.85;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// Dials (REMASTER_LOG imp-60). 0 = clean.
uniform float grime : hint_range(0.0, 1.0) = 0.55;
uniform float sweat : hint_range(0.0, 1.0) = 0.5;
uniform float scars : hint_range(0.0, 1.0) = 0.5;
// Under the facility light everyone is a little sallow.
uniform vec3 pallor = vec3(0.86, 0.9, 0.82);

// The zone's flesh colour from BaselineHuman (bruising included).
instance uniform vec4 skin_tone : source_color = vec4(0.48, 0.39, 0.31, 1.0);
// Per body, so two people are not dirty in the same places.
instance uniform float seed = 0.0;

varying vec3 rest;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Turned off the axes: value noise on a plain lattice draws boxes.
const mat3 SKEW = mat3(vec3(0.788, 0.444, -0.426), vec3(-0.364, 0.892, 0.268), vec3(0.497, -0.085, 0.864));

float value_noise(vec3 p) {
	p = SKEW * p;
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(p) * amplitude;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	rest = CUSTOM0.xyz;
}

void fragment() {
	vec3 p = rest + vec3(seed * 7.13, seed * 3.71, seed * 5.29);
	vec3 painted = texture(base_texture, UV).rgb;
	vec3 detail = mix(vec3(1.0), painted / max(texture_skin, vec3(0.01)), detail_strength);
	vec3 colour = clamp(skin_tone.rgb * detail * pallor, vec3(0.0), vec3(1.0));
	// Blotchy tone: blood under the skin, never a pattern.
	float blotch = fbm(p * 9.0);
	colour *= mix(vec3(0.9, 0.93, 0.95), vec3(1.07, 0.98, 0.95), blotch);
	// Grime: worst at the feet, the hands and the lower legs, in patches.
	float low = 1.0 - smoothstep(0.05, 0.75, rest.y);
	float hands = smoothstep(0.55, 0.75, abs(rest.x));
	float patch = smoothstep(0.42, 0.78, fbm(p * 4.0 + vec3(3.0)));
	float dirt = clamp((patch * 0.75 + low * 0.6 + hands * 0.45) * grime, 0.0, 0.9);
	float speck = smoothstep(0.68, 0.85, value_noise(p * 90.0)) * grime * 0.25;
	colour = mix(colour, colour * vec3(0.42, 0.38, 0.33), dirt);
	colour *= 1.0 - speck;
	// Old scars: thin pale ridges where a ridged noise folds, in a few places.
	float ridge = 1.0 - abs(fbm(p * vec3(7.0, 16.0, 7.0)) * 2.0 - 1.0);
	float where = smoothstep(0.62, 0.7, fbm(p * 2.2 + vec3(11.0)));
	float scar = smoothstep(0.965, 0.995, ridge) * where * scars;
	colour = mix(colour, colour * vec3(1.35, 1.12, 1.08) + vec3(0.03, 0.012, 0.01), scar);
	ALBEDO = colour;
	// Sweat: brow, chest, armpits and back, in beads and sheets.
	float body_heat = smoothstep(1.0, 1.65, rest.y) * (1.0 - smoothstep(0.4, 0.6, abs(rest.x)));
	float sheen = smoothstep(0.45, 0.7, fbm(p * 14.0 + vec3(5.0))) * (0.35 + body_heat * 0.65) * sweat;
	float rough = texture(roughness_texture, UV).r;
	ROUGHNESS = clamp(mix(0.62, rough, 0.5) + dirt * 0.25 - sheen * 0.5 + scar * 0.1, 0.12, 1.0);
	SPECULAR = 0.42 + sheen * 0.3;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	// A little light through the ears and fingers.
	BACKLIGHT = vec3(0.2, 0.05, 0.03);
}
