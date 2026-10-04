shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;

// One blob of FluidBody's pour, drawn as a MultiMesh of spheres stretched
// along their velocity and overlapping their neighbours, so the stream reads
// as one gloopy rope rather than beads. Opaque (thick fluid in air is), with
// a wet fresnel rim and a hot specular.

uniform vec4 colour : source_color = vec4(0.36, 0.025, 0.02, 1.0);

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = colour.rgb * (0.55 + rim * 0.9);
	ROUGHNESS = 0.06;
	SPECULAR = 0.85;
	EMISSION = colour.rgb * 0.12;
}
