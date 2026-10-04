shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

// FluidBody's floor sheet: a subdivided plane lifted by the depth grid
// (`field.r`, metres) plus the ripple grid (`field.g`). Transparent where it
// thins to a film, the floor bent through it, dark where it is deep, and a
// cold flash over the whole connected wet area while it is live (`shock`).

uniform sampler2D field : filter_linear, repeat_disable;
uniform float cell = 0.12;
uniform float texel = 0.015625;
uniform float film = 0.0025;
uniform float lift = 0.02;
uniform vec4 shallow : source_color = vec4(0.55, 0.05, 0.035, 0.78);
uniform vec4 deep : source_color = vec4(0.12, 0.0, 0.01, 0.97);
uniform float shock = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying float depth;
varying vec3 world;

float h(vec2 uv) {
	vec2 f = texture(field, uv).rg;
	return f.r + f.g * step(film * 0.5, f.r);
}

void vertex() {
	vec2 f = texture(field, UV).rg;
	depth = f.r;
	VERTEX.y += lift + h(UV);
	float l = h(UV - vec2(texel, 0.0));
	float r = h(UV + vec2(texel, 0.0));
	float u = h(UV - vec2(0.0, texel));
	float d = h(UV + vec2(0.0, texel));
	NORMAL = normalize(vec3(l - r, 2.0 * cell, u - d));
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float d = texture(field, UV).r;
	// A ragged wet edge instead of the grid's soft blob.
	float edge = film * (0.5 + noise(world.xz * 9.0) * 0.9);
	float cover = smoothstep(edge * 0.6, edge * 1.4, d);
	if (cover <= 0.01) discard;
	float t = smoothstep(0.002, 0.035, d);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + NORMAL.xz * 0.04, 1.0).rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 arc = vec3(0.55, 0.75, 1.0) * shock * (0.4 + 0.6 * noise(world.xz * 14.0 + TIME * 30.0));
	ALBEDO = mix(behind * shallow.rgb * 1.3, deep.rgb, t) + arc * 0.3;
	ALPHA = clamp(cover * mix(shallow.a, deep.a, t) + rim * 0.15, 0.0, 1.0);
	ROUGHNESS = 0.04;
	SPECULAR = 0.8;
	EMISSION = deep.rgb * 0.2 + arc;
}
