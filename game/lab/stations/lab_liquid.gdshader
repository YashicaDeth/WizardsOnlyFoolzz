shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

// The liquid station's tank fluid: thin where you look through little of it,
// near-black where you look through a lot (read from the depth buffer), and a
// surface that keeps moving. `slosh` tips the top after a blow.

uniform vec4 shallow : source_color = vec4(0.62, 0.06, 0.04, 0.5);
uniform vec4 deep : source_color = vec4(0.10, 0.0, 0.01, 0.97);
uniform float depth_scale = 1.8;
uniform float half_height = 1.0;
uniform float wobble = 0.025;
uniform float slosh = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void vertex() {
	float top = smoothstep(half_height * 0.8, half_height, VERTEX.y);
	float wave = sin(TIME * 2.7 + VERTEX.x * 7.0) * cos(TIME * 2.1 + VERTEX.z * 6.0);
	VERTEX.y += top * (wave * wobble + slosh * VERTEX.x * sin(TIME * 9.0));
	VERTEX.xz *= 1.0 + sin(TIME * 1.3 + VERTEX.y * 3.0) * 0.006;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 far = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	far.xyz /= far.w;
	float thickness = clamp(VERTEX.z - far.z, 0.0, 8.0);
	float t = 1.0 - exp(-thickness * depth_scale);
	vec2 bend = NORMAL.xy * 0.025 * (1.0 - t);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + bend, 1.5).rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(behind * shallow.rgb * 1.4, deep.rgb, t) + rim * vec3(0.18, 0.03, 0.02);
	ALPHA = clamp(mix(shallow.a, deep.a, t) + rim * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	EMISSION = deep.rgb * 0.25 + shallow.rgb * 0.06;
}
