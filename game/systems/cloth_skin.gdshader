shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// imp-60: a garment worn on a RiggedBody's human skin. The colour is the
// garment's own (ClothingShell: style, wear and blood soak), carried per
// instance; this adds what plain colour lacked: a weave, folds where cloth
// gathers, grime toward the hems and wear on the high points. Laid out in the
// body's REST space (CUSTOM0) so it rides the body. Back faces culled: the
// double-sided plain material self-shadowed into a dot pattern on the closed
// skin mesh.

uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
// How much of the body's shape shows through the cloth (more read as bare).
uniform float body_shape : hint_range(0.0, 1.0) = 0.12;
uniform float weave : hint_range(0.0, 1.0) = 0.5;
uniform float folds : hint_range(0.0, 1.0) = 0.6;
uniform float grime : hint_range(0.0, 1.0) = 0.5;

instance uniform vec4 cloth_colour : source_color = vec4(0.2, 0.2, 0.18, 1.0);
// A flak vest worn over the torso (alpha 0 = none): FacilityGuardPost's kit,
// fitted to the body instead of a box. Plate is the trauma plate front and back.
instance uniform vec4 vest_colour : source_color = vec4(0.0);
instance uniform vec4 plate_colour : source_color = vec4(0.0);
instance uniform vec4 belt_colour : source_color = vec4(0.0);
// The garment above and below the waist line (alpha 0 = no line).
instance uniform vec4 upper_colour : source_color = vec4(0.0);
instance uniform vec4 lower_colour : source_color = vec4(0.0);
instance uniform float seed = 0.0;
// Rest height where coat or shirt meets trousers.
uniform float waist_line = 0.93;
// Boots on a clothed leg, up to this rest height (0 = none); HunterAppearance's
// boot leather.
uniform float boot_top = 0.16;
uniform vec3 boot_colour : source_color = vec3(0.145, 0.137, 0.122);

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
	for (int octave = 0; octave < 3; octave++) {
		total += value_noise(p) * amplitude;
		p = p * 2.07 + vec3(4.1, 1.3, 7.7);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	rest = CUSTOM0.xyz;
}

void fragment() {
	vec3 p = rest + vec3(seed * 5.17, seed * 2.33, seed * 8.41);
	vec3 colour = cloth_colour.rgb;
	if (upper_colour.a > 0.0) {
		colour = rest.y > waist_line ? upper_colour.rgb : lower_colour.rgb;
	}
	// Folds: stretched along the limb, darker in the gathers.
	float gather = fbm(p * vec3(9.0, 2.5, 9.0));
	colour *= mix(1.0, mix(0.72, 1.12, gather), folds);
	// Weave: a fine cross grain that only reads up close, faded out once a
	// pixel spans more than a thread so it never shimmers at range.
	float grain = value_noise(p * 260.0) * 0.5 + value_noise(p * vec3(520.0, 40.0, 520.0)) * 0.5;
	float near = 1.0 - smoothstep(0.25, 0.8, length(fwidth(p)) * 260.0);
	colour *= mix(1.0, mix(0.86, 1.08, grain), weave * near);
	// Grime toward the hems (cuffs, trouser legs) and in patches.
	float low = 1.0 - smoothstep(0.1, 0.6, rest.y);
	float cuffs = smoothstep(0.62, 0.72, abs(rest.x));
	float patch = smoothstep(0.5, 0.8, fbm(p * 3.0 + vec3(2.0)));
	float dirt = clamp((low * 0.6 + cuffs * 0.4 + patch * 0.5) * grime, 0.0, 0.8);
	colour = mix(colour, colour * vec3(0.55, 0.5, 0.42), dirt);
	// Blood soaked in (ClothingShell's soak, alpha of cloth_colour): dried
	// stains running down the front and caught in the cuffs, not a pink tint.
	float soak = cloth_colour.a;
	float stain_noise = fbm(p * vec3(6.0, 2.5, 6.0) + vec3(9.0));
	float front = smoothstep(-0.02, 0.08, rest.z) * 0.06;
	float edge = 0.68 - soak * 0.5 - front;
	float stain = smoothstep(edge, edge + 0.05, stain_noise) * step(0.001, soak);
	colour = mix(colour, vec3(0.075, 0.01, 0.008) * mix(0.7, 1.2, gather), stain * 0.92);
	// Boots, with a darker sole.
	float boot = step(rest.y, boot_top) * step(0.001, boot_top);
	float sole = step(rest.y, 0.025);
	colour = mix(colour, boot_colour * mix(0.8, 1.05, gather) * (1.0 - sole * 0.5), boot);
	float kit = boot * 0.4;
	// The vest: chest to waist inside the armholes, a plate proud of it front
	// and back, a belt at the hips. Rest space: the body faces +Z, y up.
	if (vest_colour.a > 0.0) {
		float vest = step(0.97, rest.y) * step(rest.y, 1.43) * step(abs(rest.x), 0.2 - smoothstep(1.3, 1.43, rest.y) * 0.08);
		float plate = step(1.1, rest.y) * step(rest.y, 1.36) * step(abs(rest.x), 0.12);
		float plate_edge = plate * (1.0 - step(1.115, rest.y) * step(rest.y, 1.345) * step(abs(rest.x), 0.105));
		vec3 vested = vest_colour.rgb * mix(0.85, 1.05, gather);
		vested = mix(vested, plate_colour.rgb * mix(0.9, 1.0, grain), plate);
		vested *= 1.0 - plate_edge * 0.45;
		colour = mix(colour, vested, vest);
		kit = max(kit, max(vest * 0.5, plate));
	}
	if (belt_colour.a > 0.0) {
		float belt = step(0.9, rest.y) * step(rest.y, 0.965);
		float buckle = belt * step(abs(rest.x), 0.03) * step(0.05, rest.z);
		colour = mix(colour, belt_colour.rgb, belt);
		colour = mix(colour, vec3(0.32, 0.29, 0.24), buckle);
		kit = max(kit, belt * 0.7 + buckle * 0.3);
	}
	ALBEDO = colour;
	METALLIC = kit * 0.12;
	ROUGHNESS = clamp(0.88 + dirt * 0.1 - grain * 0.06 - kit * 0.2 - stain * 0.25, 0.5, 1.0);
	SPECULAR = 0.3;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = body_shape;
}
