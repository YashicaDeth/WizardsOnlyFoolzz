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

// player-81: the player's garment, painted on in rest space so it is fitted
// by construction (PlayerLook). 0 none (everyone else), 1 patient smock and
// shorts, 2 vat bodysuit, 3 bandage wraps and loincloth.
instance uniform float garment_mode = 0.0;
instance uniform vec4 garment_a : source_color = vec4(0.0);
instance uniform vec4 garment_b : source_color = vec4(0.0);
// How much of the base's painted muscle relief shows below the neck.
instance uniform float muscle = 1.0;
// The base's rest landmarks (metres of the model): neck, hip, knee and ankle
// heights; shoulder, elbow and wrist reach along X, and the neck's depth.
uniform vec4 marks_y = vec4(1.52, 0.97, 0.54, 0.087);
uniform vec4 marks_x = vec4(0.212, 0.463, 0.706, -0.04);

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

// Signed distance into the garment (positive = covered), which cloth
// (0 = a, 1 = b) and how wrapped (for the bandage stripes).
vec3 garment(vec3 r) {
	float ax = abs(r.x);
	float neck_y = marks_y.x;
	float hip = marks_y.y;
	float knee = marks_y.z;
	float ankle = marks_y.w;
	float shoulder = marks_x.x;
	float elbow = marks_x.y;
	float wrist = marks_x.z;
	float front = smoothstep(marks_x.w - 0.01, marks_x.w + 0.02, r.z);
	float neck_radius = length(vec2(r.x, r.z - marks_x.w));
	float head = (neck_y + 0.035) - r.y;
	float on_arm = ax - (shoulder - 0.02);
	if (garment_mode < 1.5) {
		// Smock: a scoop at the front of the neck, short sleeves, hem at the
		// upper thigh. Drawstring shorts under it to above the knee.
		float neckline = neck_y - 0.035 - 0.06 * front * clamp(1.0 - ax / 0.1, 0.0, 1.0);
		float neck = max(neckline - r.y, neck_radius - 0.095);
		float top = min(min(r.y - (hip - 0.2), (shoulder + 0.13) - ax), min(neck, head));
		float shorts = min(min(r.y - (knee + 0.1), (hip + 0.03) - r.y), -on_arm);
		return top > 0.0 ? vec3(top, 0.0, 0.0) : vec3(shorts, 1.0, 0.0);
	}
	if (garment_mode < 2.5) {
		// Bodysuit: high collar, wrist to ankle.
		float neck = max((neck_y + 0.005) - r.y, neck_radius - 0.095);
		float suit = min(min((wrist - 0.035) - ax, r.y - (ankle + 0.04)), min(neck, head));
		return vec3(suit, 0.0, 0.0);
	}
	// Wraps: a loincloth, then strips round the chest, the forearms and the
	// shins, spiralling.
	float cloth = min(min(r.y - (knee + 0.24), (hip + 0.05) - r.y), -on_arm);
	if (cloth > 0.0) {
		return vec3(cloth, 1.0, 0.0);
	}
	float chest = min(min(r.y - (hip + 0.02), (neck_y - 0.11) - r.y), (shoulder + 0.015) - ax);
	float forearm = min(ax - (elbow - 0.06), (wrist - 0.03) - ax);
	float shin = min(min(r.y - (ankle + 0.045), (knee - 0.05) - r.y), -on_arm);
	float turn = 0.0;
	float along = 0.0;
	float best = chest;
	turn = atan(r.z, r.x) / 6.2832;
	along = r.y;
	if (forearm > best) {
		best = forearm;
		turn = atan(r.z - marks_x.w + 0.03, r.y - neck_y + 0.065) / 6.2832;
		along = ax;
	}
	if (shin > best) {
		best = shin;
		turn = atan(r.z - marks_x.w, ax - 0.114) / 6.2832;
		along = r.y;
	}
	return vec3(best, 0.0, fract(along * 30.0 + turn * 1.0));
}

void vertex() {
	rest = CUSTOM0.xyz;
}

void fragment() {
	vec3 p = rest + vec3(seed * 7.13, seed * 3.71, seed * 5.29);
	vec3 painted = texture(base_texture, UV).rgb;
	float below_neck = 1.0 - smoothstep(marks_y.x - 0.04, marks_y.x, rest.y);
	float relief = mix(1.0, muscle, below_neck);
	vec3 detail = mix(vec3(1.0), painted / max(texture_skin, vec3(0.01)), detail_strength * relief);
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
	// The garment over it.
	float cover = 0.0;
	float seam = 0.0;
	if (garment_mode > 0.5) {
		vec3 worn = garment(rest);
		cover = smoothstep(0.0, 0.003, worn.x);
		if (garment_mode > 2.5 && worn.y < 0.5) {
			// Each strip overlaps the last: a dark lap line, and the odd gap.
			float lap = smoothstep(0.78, 0.86, worn.z) * (1.0 - smoothstep(0.92, 1.0, worn.z));
			seam = max(seam, lap * 0.8);
			cover *= 1.0 - smoothstep(0.7, 0.76, fbm(p * 5.0 + vec3(19.0))) * 0.85;
		}
		// Hems and cuffs are doubled cloth: a darker line along every edge.
		seam = max(seam, (1.0 - smoothstep(0.004, 0.012, worn.x)) * 0.7);
		vec3 cloth = worn.y > 0.5 ? garment_b.rgb : garment_a.rgb;
		if (garment_mode > 1.5 && garment_mode < 2.5) {
			// Piping on the bodysuit's collar, cuffs and ankles.
			cloth = mix(cloth, garment_b.rgb, 1.0 - smoothstep(0.006, 0.01, worn.x));
		}
		if (garment_mode < 1.5 && worn.y < 0.5) {
			// The smock ties at the back.
			float back = 1.0 - smoothstep(marks_x.w - 0.04, marks_x.w - 0.01, rest.z);
			seam = max(seam, (1.0 - smoothstep(0.004, 0.009, abs(rest.x))) * back * 0.8);
		}
		// Folds where it gathers, grime low and at the hems, old stains.
		float fold = fbm(p * vec3(14.0, 5.0, 14.0) + vec3(2.0));
		cloth *= mix(0.78, 1.08, fold);
		cloth *= 1.0 - seam * 0.45;
		float stain = smoothstep(0.64, 0.8, fbm(p * 3.0 + vec3(31.0)));
		cloth = mix(cloth, cloth * vec3(0.55, 0.42, 0.36), stain * 0.55 * grime);
		cloth = mix(cloth, cloth * vec3(0.6, 0.56, 0.5), low * 0.5 * grime);
		colour = mix(colour, cloth, cover);
	}
	ALBEDO = colour;
	// Sweat: brow, chest, armpits and back, in beads and sheets.
	float body_heat = smoothstep(1.0, 1.65, rest.y) * (1.0 - smoothstep(0.4, 0.6, abs(rest.x)));
	float sheen = smoothstep(0.45, 0.7, fbm(p * 14.0 + vec3(5.0))) * (0.35 + body_heat * 0.65) * sweat;
	float rough = texture(roughness_texture, UV).r;
	ROUGHNESS = mix(clamp(mix(0.62, rough, 0.5) + dirt * 0.25 - sheen * 0.5 + scar * 0.1, 0.12, 1.0), 0.9, cover);
	SPECULAR = mix(0.42 + sheen * 0.3, 0.25, cover);
	// Cloth hides most of the muscle relief under it.
	NORMAL_MAP = mix(texture(normal_texture, UV).rgb, vec3(0.5, 0.5, 1.0), cover * 0.7);
	NORMAL_MAP_DEPTH = normal_strength * mix(1.0, muscle, below_neck);
	// A little light through the ears and fingers.
	BACKLIGHT = vec3(0.2, 0.05, 0.03) * (1.0 - cover);
}
