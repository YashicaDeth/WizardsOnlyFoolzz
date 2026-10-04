shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;

// GlassTank's wall. Real glass reads by three things the old flat-alpha tube
// had none of: the background bent through it (screen-texture refraction),
// a green-grey edge where you look through the thickness sideways (fresnel
// plus tint), and the environment caught in it (low roughness, high specular).
// Fresnel/tint approach after the CC0 "PBR Glass" and "Colored Glass" shaders
// on godotshaders.com (see CREDITS.md); written fresh for this tube.
//
// Cracks: up to four impacts, each a star of radial cracks plus broken rings,
// grown by `crack` (0 intact .. 1 about to go). After the burst `stub` > 0 and
// everything above the jagged line in `stub_line` is discarded: the part that
// stays standing, its edge matched to the shards that flew.

uniform vec4 tint : source_color = vec4(0.80, 0.90, 0.86, 1.0);
uniform float edge_tint = 0.55;
uniform float bend = 0.03;
uniform float radius = 0.7;
uniform float half_height = 1.0;
uniform float crack = 0.0;
uniform vec4 impacts[4];
uniform float stub = 0.0;
uniform float stub_line[12];
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

varying vec3 local_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// The tube unrolled: arc length round, height up.
vec2 unroll(vec3 p) { return vec2(atan(p.z, p.x) * radius, p.y); }

float crack_at(vec2 here, vec4 impact) {
	if (impact.w <= 0.0) return 0.0;
	vec2 d = here - unroll(impact.xyz);
	float wrap = 6.2831853 * radius;
	d.x = d.x - wrap * round(d.x / wrap);
	float len = length(d);
	float reach = impact.w * (0.18 + crack * 0.75);
	if (len > reach) return 0.0;
	float a = atan(d.y, d.x) / 6.2831853;
	float wobble = noise(vec2(len * 9.0, impact.x * 13.0)) * 0.12;
	float spoke = abs(fract(a * 11.0 + wobble + hash(impact.xy) ) - 0.5) * 2.0;
	float width = 0.035 * (1.0 - len / reach) + 0.006;
	float radial = 1.0 - smoothstep(width * 0.5, width, (1.0 - spoke) * len * 4.0);
	// Broken rings, the conchoidal steps round the impact.
	float ring_n = len * (14.0 - crack * 4.0) + noise(d * 20.0) * 0.6;
	float ring = (1.0 - smoothstep(0.0, 0.07, abs(fract(ring_n) - 0.5) * 2.0 - 0.9)) * step(0.5, noise(vec2(floor(ring_n), a * 9.0)));
	ring *= step(0.4, crack);
	// The white bruise at the point of impact.
	float bruise = 1.0 - smoothstep(0.0, 0.03 + crack * 0.03, len);
	return clamp(max(max(radial, ring * 0.8), bruise), 0.0, 1.0) * smoothstep(reach, reach * 0.7, len);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 here = unroll(local_pos);
	if (stub > 0.0) {
		float a = (atan(local_pos.z, local_pos.x) / 6.2831853 + 0.5) * 12.0;
		int i = int(floor(a)) % 12;
		float line = mix(stub_line[i], stub_line[(i + 1) % 12], fract(a));
		if (local_pos.y > line) discard;
	}
	float cracked = 0.0;
	for (int i = 0; i < 4; i++) cracked = max(cracked, crack_at(here, impacts[i]));
	float facing = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec2 offset = NORMAL.xy * bend * (0.4 + fresnel * 2.0) + vec2(cracked * 0.01);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + offset, cracked * 2.0).rgb;
	vec3 glass = behind * mix(vec3(1.0), tint.rgb, 0.35 + fresnel * edge_tint);
	ALBEDO = mix(glass, vec3(0.78, 0.82, 0.8), cracked * 0.85);
	// Mostly see-through face-on, so the fluid behind (also transparent, and
	// not in the screen texture) still shows; the edges go thick and green.
	ALPHA = clamp(0.06 + fresnel * 0.75 + cracked * 0.8, 0.0, 1.0);
	ROUGHNESS = mix(0.02, 0.35, cracked);
	SPECULAR = 0.9;
	METALLIC = 0.0;
	RIM = 0.2;
	EMISSION = vec3(0.6, 0.62, 0.6) * cracked * 0.08;
}
