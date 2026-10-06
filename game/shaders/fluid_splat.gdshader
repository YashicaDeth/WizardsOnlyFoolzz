shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

// FluidSurface's first pass: every blob of FluidBody's pour as a camera-facing
// kernel, added into a float buffer the composite reads (fluid_surface.gdshader):
//   R = density (sum of kernel weights)
//   G = density-weighted view depth less `origin` (G / R + origin is a
//       smoothed depth; relative so half floats keep millimetres)
//   B = thickness (sum of weighted chord lengths, for the red absorption)
// Overlapping kernels sum into one field, so neighbours merge into one surface
// instead of reading as beads. The instance basis carries the blob's size
// (x column length) and its stretch along the velocity (y column).

uniform float radius = 0.11;
uniform float origin = 0.0;

varying vec2 corner;
varying float view_z;
varying float size;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 side_v = (MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
	vec3 along_v = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	size = length(side_v);
	float stretch = length(along_v) / max(size, 0.0001);
	vec2 flat_along = along_v.xy;
	float in_plane = length(flat_along) / max(length(along_v), 0.0001);
	vec2 major = length(flat_along) > 0.0001 ? normalize(flat_along) : vec2(0.0, 1.0);
	vec2 minor = vec2(-major.y, major.x);
	float r = radius * size;
	float long_r = r * (1.0 + (stretch - 1.0) * in_plane);
	corner = VERTEX.xy * 2.0;
	vec3 at = centre + vec3(minor * corner.x * r + major * corner.y * long_r, 0.0);
	view_z = -centre.z - origin;
	POSITION = PROJECTION_MATRIX * vec4(at, 1.0);
}

void fragment() {
	float d2 = dot(corner, corner);
	if (d2 >= 1.0) {
		discard;
	}
	float w = (1.0 - d2) * (1.0 - d2) * (1.0 - d2);
	float chord = radius * 0.7 * size * sqrt(1.0 - d2);
	ALBEDO = vec3(w, w * view_z, w * chord);
	ALPHA = 1.0;
}
