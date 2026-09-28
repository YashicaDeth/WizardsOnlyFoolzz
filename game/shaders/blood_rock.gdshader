shader_type spatial;
render_mode cull_disabled;

// The dry falls' rock (blood_waterfall_exit.gd): stone streaked with old
// and new blood. Everything is in world space, so a box, a displaced sheet
// and a tree stump all streak at the same scale and line up where they meet.
// Streaks run down vertical faces from a random start height; flat ground
// collects blotches instead; a `channel` band carries blood that is still
// running (animated downward) where the waterfall used to fall.

uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 rock_light : source_color = vec4(0.31, 0.27, 0.24, 1.0);
uniform vec4 rock_dark : source_color = vec4(0.075, 0.065, 0.06, 1.0);
uniform vec4 blood_wet : source_color = vec4(0.34, 0.012, 0.02, 1.0);
uniform vec4 blood_dry : source_color = vec4(0.17, 0.035, 0.03, 1.0);
uniform float streak_amount : hint_range(0.0, 1.0) = 0.5;
uniform float streak_top = 2.0;
uniform float pool_amount : hint_range(0.0, 1.0) = 0.35;
uniform float channel_center_x = 0.0;
uniform float channel_half_width = 0.0;
uniform float flow_speed = 0.6;
uniform float detail_scale = 0.35;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return texture(detail, p.zy * detail_scale).rgb * w.x
		+ texture(detail, p.xz * detail_scale).rgb * w.y
		+ texture(detail, p.xy * detail_scale).rgb * w.z;
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec3 d = triplanar(wpos, n);
	float lum = dot(d, vec3(0.3333));
	// Bedding planes: the falls were cut through layered stone.
	float strata = fbm(vec2((wpos.x + wpos.z) * 0.05, wpos.y * 0.7));
	float macro = fbm(vec2(wpos.x * 0.03 + wpos.z * 0.04, wpos.y * 0.06 + wpos.z * 0.01));
	float tone = clamp((lum - 0.35) * 2.2 + (strata - 0.5) * 1.4 + (macro - 0.5) * 1.2 + 0.5, 0.0, 1.0);
	vec3 rock = mix(rock_dark.rgb, rock_light.rgb, tone);

	float steep = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	// Streaks: narrow columns along the face, each starting at its own height
	// and running all the way down.
	float across = wpos.x * 0.9 + wpos.z * 0.9;
	float column = floor(across * 1.3);
	float start = streak_top - hash1(column) * 9.0;
	float lane = fbm(vec2(across * 2.4, wpos.y * 0.08));
	float streak = smoothstep(1.0 - streak_amount * 0.55, 1.04 - streak_amount * 0.55, lane);
	streak *= smoothstep(start + 0.4, start - 0.6, wpos.y) * steep;
	// Flat ground and ledges: blotches where it pooled and dried.
	float pool = smoothstep(1.0 - pool_amount * 0.5, 1.03 - pool_amount * 0.5, fbm(wpos.xz * 0.28 + 3.1)) * (1.0 - steep);

	// The old watercourse: blood still running down it.
	float channel = 0.0;
	if (channel_half_width > 0.0) {
		float edge = channel_half_width * (0.75 + 0.5 * vnoise(vec2(wpos.y * 0.4, 2.0)));
		channel = 1.0 - smoothstep(edge * 0.6, edge, abs(wpos.x - channel_center_x));
		float run = fbm(vec2(wpos.x * 1.6, wpos.y * 0.35 + TIME * flow_speed));
		channel *= smoothstep(0.25, 0.55, run);
	}

	float blood = clamp(max(max(streak, pool), channel), 0.0, 1.0);
	float wet = clamp(channel + streak * 0.35, 0.0, 1.0);
	vec3 blood_colour = mix(blood_dry.rgb, blood_wet.rgb, wet);
	ALBEDO = mix(rock, blood_colour, blood);
	ROUGHNESS = mix(0.92, mix(0.55, 0.12, wet), blood);
	SPECULAR = mix(0.3, 0.75, blood * wet);
}
