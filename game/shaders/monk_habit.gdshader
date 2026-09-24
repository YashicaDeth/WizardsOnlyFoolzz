shader_type spatial;
// The splinter monks' habit (DESIGN/OVERWORLD_EVENTS.md, Greg 24 September):
// Eastern Orthodox black-and-white habits with sigil-covered hoods, "blood
// stained and creased destroyed sigils ... instead of just white and black".
//
// Sampled triplanar in object space so it lands on any mesh the rig has,
// including the revolved garment shells, which carry no useful UVs. The sigil
// mask is drawn on the CPU from CellOutzType's seal strokes (see
// splinter_monk_look.gd), already broken; this shader creases, stains and
// frays everything on top.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D sigil_mask : filter_linear_mipmap, repeat_enable;
uniform sampler2D crease_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D blood_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 cloth_color : source_color = vec3(0.028, 0.025, 0.026);
uniform vec3 thread_color : source_color = vec3(0.74, 0.70, 0.62);
uniform vec3 blood_color : source_color = vec3(0.23, 0.028, 0.02);
uniform vec3 old_blood_color : source_color = vec3(0.12, 0.045, 0.03);
// 0 = a black habit with white sigils; 1 = a white cloth with dark sigils.
uniform float white_field : hint_range(0.0, 1.0) = 0.0;
uniform float sigil_scale = 2.6;
uniform float crease_scale = 1.4;
uniform float crease_depth : hint_range(0.0, 2.0) = 1.0;
uniform float blood_amount : hint_range(0.0, 1.0) = 0.45;
// Blood pools toward the hem: object-space height below which it thickens.
uniform float hem_height = -0.2;
uniform float hem_blood = 0.35;
uniform float fray : hint_range(0.0, 1.0) = 0.0;
uniform float seed_offset = 0.0;

varying vec3 obj_pos;
varying vec3 obj_normal;

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	vec2 off = vec2(seed_offset, seed_offset * 0.37);
	return texture(tex, p.zy * scale + off) * w.x
		+ texture(tex, p.xz * scale + off) * w.y
		+ texture(tex, p.xy * scale + off) * w.z;
}

void fragment() {
	vec3 n = normalize(obj_normal);
	float sig = triplanar(sigil_mask, obj_pos, n, sigil_scale).r;
	float crease = triplanar(crease_noise, obj_pos, n, crease_scale).r;
	float blood = triplanar(blood_noise, obj_pos + vec3(3.1), n, 0.9).r;
	float speck = triplanar(blood_noise, obj_pos * 3.7, n, 1.3).r;

	// Creases: ridged noise; valleys darken, ridges catch a little light.
	float ridge = 1.0 - abs(crease * 2.0 - 1.0);
	ridge = pow(ridge, 3.0);

	vec3 field = mix(cloth_color, thread_color * 0.92, white_field);
	vec3 ink = mix(thread_color, vec3(0.05, 0.035, 0.03), white_field);
	// The sigils are thread, worn through where the cloth folds most.
	float wear = smoothstep(0.55, 0.9, ridge) * 0.6;
	vec3 col = mix(field, ink, sig * (1.0 - wear));
	col *= mix(1.0, 0.55, smoothstep(0.35, 0.0, crease) * crease_depth);
	col += vec3(0.03) * ridge * crease_depth * (1.0 - white_field);

	// Blood: broad old stains, fresher cores, and a heavier soak at the hem.
	float hem = smoothstep(hem_height, hem_height - 0.5, obj_pos.y) * hem_blood;
	float stain = smoothstep(1.0 - blood_amount * 0.55 - hem, 1.0 - blood_amount * 0.38 - hem, blood);
	float fresh = smoothstep(0.8, 0.9, blood) * stain;
	float spatter = smoothstep(0.9, 0.95, speck) * blood_amount;
	vec3 stained = mix(old_blood_color, blood_color, fresh);
	col = mix(col, stained * mix(1.0, 1.9, white_field), clamp(stain * 0.9 + spatter, 0.0, 1.0));

	// Frayed: holes eaten into the cloth.
	if (fray > 0.0 && speck * ridge > 1.0 - fray * 0.35) {
		discard;
	}

	ALBEDO = col;
	ROUGHNESS = mix(0.93, 0.55, fresh);
	SPECULAR = 0.25;
	// A cheap crease normal: tilt by the noise gradient.
	vec2 e = vec2(0.02, 0.0);
	float cx = triplanar(crease_noise, obj_pos + e.xyy, n, crease_scale).r - crease;
	float cy = triplanar(crease_noise, obj_pos + e.yxy, n, crease_scale).r - crease;
	NORMAL_MAP = normalize(vec3(-cx * 6.0 * crease_depth, -cy * 6.0 * crease_depth, 1.0)) * 0.5 + vec3(0.5);
	NORMAL_MAP_DEPTH = 1.0;
}
