shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// One soft billow of kicked-up ash: a ragged round blob that thins toward its
// edge. Per-instance fade arrives through INSTANCE_CUSTOM.r / albedo alpha.

uniform vec4 tint : source_color = vec4(0.78, 0.74, 0.68, 1.0);
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	// Always face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) + (noise(UV * 5.0) - 0.5) * 0.45;
	float body = smoothstep(1.0, 0.25, r);
	float wisps = noise(UV * 9.0 + seed) * 0.5 + 0.5;
	ALBEDO = tint.rgb * (0.8 + 0.2 * wisps);
	// Never fog the lens: ash within ~2 m of the camera thins to nothing, so a
	// dodge with the camera at the eye (first person, or a third-person camera
	// pushed in by a wall) cannot fill the frame. Caught in-scene.
	float from_eye = -VERTEX.z;
	ALPHA = body * wisps * fade * tint.a * smoothstep(0.8, 2.0, from_eye);
}
