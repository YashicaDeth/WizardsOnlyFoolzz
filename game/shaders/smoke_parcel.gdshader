shader_type spatial;
// drug-70: one parcel of `SmokeVolume`, drawn as a soft camera-facing card.
// Lit (smoke is only visible where light crosses it), translucent from behind,
// broken up by noise so a card never reads as a disc, and faded where it meets
// geometry so a plume against a wall or a body has no hard seam.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
// Overall opacity, a dial for the owner.
uniform float opacity = 0.32;
// A floor of its own light, so smoke in the dark is grey and not black.
uniform float ambient_floor = 0.06;
// Metres over which a card fades into what is behind it.
uniform float soft_distance = 0.12;

varying float v_age;
varying float v_seed;

void vertex() {
	float angle = INSTANCE_CUSTOM.x * 6.2831 + INSTANCE_CUSTOM.y * 1.4;
	float c = cos(angle);
	float s = sin(angle);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	float scale = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_age = INSTANCE_CUSTOM.y;
	v_seed = INSTANCE_CUSTOM.x * 7.3;
}

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float radial = 1.0 - smoothstep(0.0, 1.0, length(centred));
	radial *= radial;
	// Two octaves of grain, drifting apart with age, so a card frays into
	// wisps as it thins instead of staying a soft disc.
	vec2 drift = vec2(v_seed + v_age * 0.6, TIME * 0.03);
	float grain = texture(noise_texture, UV * 0.5 + drift).r * 0.65 + texture(noise_texture, UV * 1.3 - drift * 1.7).r * 0.35;
	float shape = radial * smoothstep(0.32 + v_age * 0.2, 0.85, grain + radial * 0.25);

	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = world.z / world.w;
	float soft = clamp((VERTEX.z - scene_z) / max(soft_distance, 0.001), 0.0, 1.0);

	ALBEDO = COLOR.rgb * 0.8;
	ROUGHNESS = 1.0;
	BACKLIGHT = COLOR.rgb * 0.3;
	EMISSION = COLOR.rgb * ambient_floor;
	ALPHA = clamp(COLOR.a * shape * soft * opacity, 0.0, 1.0);
}
