shader_type spatial;
// The alarm's one-second white depth / X-ray flash over the player's camera
// (Greg, 2026-09-24). The Black Mirror's LiDAR depth image
// (black_mirror_depth.gdshader), taken as it is, with one addition: the depth
// buffer is read correctly under the Compatibility renderer too, where depth
// is not reversed and maps to NDC as raw * 2 - 1. Unchanged, the Black Mirror
// version read every pixel as "near" there and drew a flat white frame (seen
// on the first capture of this flash).
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float near_range = 0.4;
uniform float far_range = 38.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

void fragment() {
	float raw = texture(depth_texture, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float distance_m = -view.z / view.w;
	float t = clamp((distance_m - near_range) / (far_range - near_range), 0.0, 1.0);
	float grey = 0.96 - 0.96 * pow(t, 0.7);
	vec2 cell = fract(FRAGCOORD.xy / 3.0) - 0.5;
	float dot_mask = mix(0.55, 1.0, step(length(cell), 0.36));
	float sweep = fract(TIME * 0.9);
	float band = smoothstep(0.02, 0.0, abs(SCREEN_UV.y - sweep)) * 0.4;
	float f = fract(distance_m * 0.5);
	float contour = smoothstep(0.04, 0.0, min(f, 1.0 - f)) * 0.22 * (1.0 - t);
	ALBEDO = vec3(clamp(grey * dot_mask + band + contour, 0.0, 1.0));
	ALPHA = 1.0;
}
