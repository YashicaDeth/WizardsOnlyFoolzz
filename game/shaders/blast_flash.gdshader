shader_type spatial;
// imp-63: the first instant of a blast (`BlastFx`). As a camera-facing card it
// is the fireball: a white-hot core going orange at its ragged edge and gone
// in a fraction of a second. As a flat card on the ground (`ring` = 1) it is
// the shock ring: a thin pale band of kicked-up dust racing outward.
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

// 0 at the blast, 1 when the card is gone.
uniform float age = 0.0;
uniform float ring = 0.0;
uniform float seed = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.9, 0.7);
uniform vec3 edge : source_color = vec3(1.0, 0.38, 0.08);
uniform vec3 dust : source_color = vec3(0.75, 0.68, 0.58);
uniform float energy = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	if (ring < 0.5) {
		float scale = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
	}
}

void fragment() {
	vec2 centred = UV * 2.0 - 1.0;
	float r = length(centred);
	float angle = atan(centred.y, centred.x);
	// A ragged rim: the edge pushed in and out by noise round the circle.
	float rag = noise(vec2(angle * 3.0, seed) + age * 2.0) * 0.35 + noise(centred * 6.0 + seed) * 0.2;
	float fade = (1.0 - age) * (1.0 - age);
	if (ring < 0.5) {
		float body = 1.0 - smoothstep(0.25, 0.95, r + rag * 0.6);
		vec3 colour = mix(hot, edge, smoothstep(0.0, 0.8, r + age * 0.9 + rag * 0.3));
		ALBEDO = colour * energy * body * fade;
	} else {
		float band = smoothstep(0.62, 0.86, r + rag * 0.15) * (1.0 - smoothstep(0.86, 1.0, r + rag * 0.1));
		ALBEDO = dust * band * fade * 0.8;
	}
}
