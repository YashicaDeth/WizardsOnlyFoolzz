shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx, shadows_disabled;

// FluidSurface's second pass: screen-space fluid. A full-screen quad reads the
// splat buffer (fluid_splat.gdshader) and draws one continuous surface where
// the summed density crosses `iso`: the kernel-weighted depth is the smoothed
// surface depth, its screen gradient the normal (bent outward by the density
// gradient at the rim, so edges round off), the summed chords the thickness.
// Shading: lit by the scene's own lights (glossy), the floor behind refracted
// through it and absorbed by thickness (red passes, the rest dies), and it
// writes its own depth so walls, the tank stub and props hide it correctly.
// After the classic screen-space fluid renderers (van der Laan, Green and
// Sainz 2009, "Screen Space Fluid Rendering with Curvature Flow"; Green, GDC
// 2010), with the bilateral blur replaced by the kernel-weighted mean depth.

uniform sampler2D field : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.002, 0.003);
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 colour : source_color = vec4(0.42, 0.04, 0.03, 1.0);
uniform float iso = 0.32;
// Beer-Lambert per metre of fluid, per channel scale below.
uniform float absorb = 26.0;
uniform float refraction = 0.035;
uniform float front = 0.05;
// The splat pass stores depth less this (see fluid_splat.gdshader).
uniform float origin = 0.0;
uniform float bulge_scale = 2.5;

vec3 view_at(mat4 inv_projection, vec2 uv, float z) {
	vec4 ray = inv_projection * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
	vec3 dir = ray.xyz / ray.w;
	return dir * (z / max(-dir.z, 0.0001));
}

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

void fragment() {
	vec4 f = texture(field, SCREEN_UV);
	float rho = f.r;
	if (rho < iso * 0.55) {
		discard;
	}
	float z = f.g / rho + origin - front;
	vec3 here = view_at(INV_PROJECTION_MATRIX, SCREEN_UV, z);
	// Neighbour depths; a neighbour off the surface borrows ours, and each
	// axis takes the nearer side so the silhouette does not smear.
	vec2 dx = vec2(texel.x * 2.0, 0.0);
	vec2 dy = vec2(0.0, texel.y * 2.0);
	vec4 fr = texture(field, SCREEN_UV + dx);
	vec4 fl = texture(field, SCREEN_UV - dx);
	vec4 fd = texture(field, SCREEN_UV + dy);
	vec4 fu = texture(field, SCREEN_UV - dy);
	float zr = fr.r > iso * 0.3 ? fr.g / fr.r + origin - front : z;
	float zl = fl.r > iso * 0.3 ? fl.g / fl.r + origin - front : z;
	float zd = fd.r > iso * 0.3 ? fd.g / fd.r + origin - front : z;
	float zu = fu.r > iso * 0.3 ? fu.g / fu.r + origin - front : z;
	vec3 ddx = view_at(INV_PROJECTION_MATRIX, SCREEN_UV + dx, zr) - here;
	vec3 ddx2 = here - view_at(INV_PROJECTION_MATRIX, SCREEN_UV - dx, zl);
	if (abs(ddx2.z) < abs(ddx.z)) ddx = ddx2;
	vec3 ddy = view_at(INV_PROJECTION_MATRIX, SCREEN_UV + dy, zd) - here;
	vec3 ddy2 = here - view_at(INV_PROJECTION_MATRIX, SCREEN_UV - dy, zu);
	if (abs(ddy2.z) < abs(ddy.z)) ddy = ddy2;
	vec3 n = normalize(cross(ddy, ddx));
	if (dot(n, -here) < 0.0) n = -n;
	// The density is a smooth sum (no ratio, so no half-float noise): read
	// as a height field it rounds the body over like a tube, and at the rim,
	// where the mean depth is flat, it is all there is.
	vec2 g = vec2(fr.r - fl.r, fd.r - fu.r);
	vec3 bulge = normalize(vec3(-g.x, g.y, 0.0) * bulge_scale + vec3(0.0, 0.0, 1.0));
	vec3 rim_n = normalize(vec3(-g.x, g.y, 0.0) / max(length(g), 0.0001) + vec3(0.0, 0.0, 0.35));
	float edge = 1.0 - smoothstep(iso, iso * 3.0, rho);
	n = normalize(mix(n, bulge, 0.55));
	n = normalize(mix(n, rim_n, edge * 0.8));

	float thick = max(f.b, 0.004);
	vec3 transmit = exp(-thick * absorb * vec3(0.32, 1.7, 1.8));
	vec2 bend = n.xy * vec2(1.0, -1.0) * refraction * clamp(thick * 12.0, 0.2, 1.0);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - bend, 1.5).rgb;
	float facing = clamp(dot(n, normalize(-here)), 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 5.0);

	NORMAL = n;
	LIGHT_VERTEX = here;
	ALBEDO = colour.rgb * (1.0 - transmit.r) * 0.6;
	ROUGHNESS = 0.09;
	SPECULAR = 0.75;
	METALLIC = 0.0;
	EMISSION = behind * transmit * (1.0 - fresnel) + colour.rgb * 0.05;
	ALPHA = smoothstep(iso * 0.55, iso * 1.15, rho);
	vec4 clip = PROJECTION_MATRIX * vec4(here, 1.0);
	DEPTH = clip.z / clip.w;
}
