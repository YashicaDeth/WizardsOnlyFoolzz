shader_type spatial;
render_mode cull_back;

// A hole the ground does not have (DESIGN/GOAL_LOOP_2.md 0.2b). The disc lies
// flat on the surface; every pixel follows the view ray down into a bowl under
// it and shades what the ray meets there, so from any angle it reads as a pit
// with walls and a dark bottom, without cutting the ground's mesh or collider.
// The disc is radius 1 in its own space; the node's scale sizes the hole.

uniform float depth = 0.55;
uniform vec3 soil : source_color = vec3(0.22, 0.17, 0.12);
uniform vec3 deep : source_color = vec3(0.025, 0.02, 0.015);

varying vec3 local_pos;
varying vec3 cam_local;

void vertex() {
	local_pos = VERTEX;
	cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

void fragment() {
	vec3 q = vec3(local_pos.x, 0.0, local_pos.z);
	if (dot(q.xz, q.xz) > 1.0) {
		discard;
	}
	vec3 dir = normalize(local_pos - cam_local);
	// A ray grazing the surface still has to go in, or it never finds a wall.
	dir.y = min(dir.y, -0.03);
	dir = normalize(dir);
	// March down to the bowl y = depth * (r^2 - 1): zero at the rim, -depth at
	// the centre, rising past the rim, which is what the ray meets as a wall.
	for (int i = 0; i < 48; i++) {
		if (q.y <= depth * (dot(q.xz, q.xz) - 1.0)) {
			break;
		}
		q += dir * 0.04;
	}
	float down = clamp(-q.y / depth, 0.0, 1.0);
	ALBEDO = mix(soil, deep, pow(down, 0.7));
	vec3 n = normalize(vec3(-2.0 * depth * q.x, 1.0, -2.0 * depth * q.z));
	NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(n, 0.0))).xyz);
	ROUGHNESS = 0.97;
}
