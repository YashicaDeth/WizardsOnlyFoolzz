shader_type spatial;
// Lab-48. The body's skin under the X-ray: a thin radiograph film rather than
// translucent flesh. Additive and unshaded like the XraySpecimen plate, so the
// outline reads at the silhouette (fresnel) and the organs and bone inside
// carry the picture. Depth-tested: the film is only where the body is.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 film : source_color = vec4(0.32, 0.56, 0.5, 1.0);
uniform float base = 0.03;
uniform float edge = 0.6;
uniform float edge_power = 2.4;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, edge_power);
	ALBEDO = film.rgb * (base + edge * rim);
}
