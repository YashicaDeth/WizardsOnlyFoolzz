shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

// The fluid inside a GlassTank: a column that drops as it drains (`level`),
// tips as it sloshes (`tilt`, driven by a damped spring in glass_tank.gd) and
// rings from where it was hit (`ripple_at`, `ripple_age`). Thin where you
// look through little of it, near-black where you look through a lot (depth
// buffer), and the background bent through it. Grown from lab_liquid.gdshader.

uniform vec4 shallow : source_color = vec4(0.62, 0.06, 0.04, 0.55);
uniform vec4 deep : source_color = vec4(0.10, 0.0, 0.01, 0.97);
uniform float depth_scale = 1.8;
uniform float half_height = 1.0;
uniform float level = 1.0;
uniform vec2 tilt = vec2(0.0);
uniform vec2 ripple_at = vec2(0.0);
uniform float ripple_age = 99.0;
uniform float ripple_amp = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying float top;
varying vec3 local_pos;

float ripple_height(vec2 p) {
	float r = length(p - ripple_at);
	float front = ripple_age * 0.9;
	float ring = sin((r - front) * 38.0) * exp(-abs(r - front) * 9.0);
	return ring * ripple_amp * exp(-ripple_age * 1.6);
}

void vertex() {
	float y01 = (VERTEX.y + half_height) / (2.0 * half_height);
	VERTEX.y = -half_height + y01 * 2.0 * half_height * level;
	top = smoothstep(0.98, 1.0, y01);
	float wave = sin(TIME * 2.7 + VERTEX.x * 7.0) * cos(TIME * 2.1 + VERTEX.z * 6.0) * 0.008;
	VERTEX.y += top * (dot(tilt, VERTEX.xz) + wave);
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = NORMAL;
	if (top > 0.5) {
		// Ripples live in the normal: the cap has no inner vertices to move.
		vec2 p = local_pos.xz;
		float e = 0.01;
		float dx = ripple_height(p + vec2(e, 0)) - ripple_height(p - vec2(e, 0));
		float dz = ripple_height(p + vec2(0, e)) - ripple_height(p - vec2(0, e));
		vec3 bumped = normalize(vec3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)));
		n = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(bumped, 0.0)).xyz);
		NORMAL = n;
	}
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 far = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	far.xyz /= far.w;
	float thickness = clamp(VERTEX.z - far.z, 0.0, 8.0);
	float t = 1.0 - exp(-thickness * depth_scale);
	vec2 bend = n.xy * 0.03 * (1.0 - t);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + bend, 1.5).rgb;
	float rim = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(behind * shallow.rgb * 1.4, deep.rgb, t) + rim * vec3(0.18, 0.03, 0.02);
	ALPHA = clamp(mix(shallow.a, deep.a, t) + rim * 0.3, 0.0, 1.0);
	ROUGHNESS = 0.05;
	SPECULAR = 0.75;
	EMISSION = deep.rgb * 0.25 + shallow.rgb * 0.06;
}
