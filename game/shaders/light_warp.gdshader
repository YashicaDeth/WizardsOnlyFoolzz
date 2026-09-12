shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A3.2: "Warping is a property of the light, not a post-process on the whole
// frame."
//
// AS2.1 said the light warps and distorts at night, and the first build of that
// read it as a screen effect: `psychedelic.gdshader`'s displacement dial pushed
// up by the hour, so at night the entire frame moved whether or not there was
// any light in it. That is backwards twice over. It warped the sky, the ground
// and the interface equally — none of which are light — and it left the nine
// sodium lamps that actually are light looking exactly as they do at noon. It
// also spent the one dial the game reserves for being on something, so a drug
// and a sunset became indistinguishable.
//
// This is the same idea built where it belongs: a shell of real geometry around
// one real light. Only the screen it actually covers is displaced, the strength
// falls off to nothing before its own silhouette, and a scene with no lamps in
// it gets no warping at all because there is nothing for the warping to be a
// property of.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_texture : repeat_enable;
// How far the air bends, in screen UV. Deliberately tiny: this reads as heat
// coming off something hot, not as a lens.
uniform float strength : hint_range(0.0, 0.05) = 0.010;
uniform float scroll : hint_range(0.0, 2.0) = 0.6;
// Scaled from outside by the hour, so a lamp at noon does nothing and the same
// lamp at one in the morning is the only thing in frame bending the air.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.52, 0.22);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.14;
// The lamp's own throw, in metres, set from `omni_range`. The falloff is
// measured against it rather than against the shell's geometry, so the two
// cannot drift apart.
uniform float reach = 13.0;
// A4.2. The cosine of a spot's outer angle, or -2 for a light that is a point.
// Which measure is right depends on the shape of the volume the light fills,
// and these are the only two shapes the game has.
uniform float cone_edge = -2.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ray = normalize(VERTEX);
	float bend;
	if (cone_edge > -1.5) {
		// A4.2. A spot fills a cone, and the one spot in this game is the handheld,
		// carried at the eye. From there the lit volume is not something the ray
		// passes near — it is the direction the ray points, so the measure is the
		// angle off the beam. A spot mounted out in the world would need the ray
		// against the cone's actual volume; there is no such light, and writing
		// that path now would be a second measure nothing exercises.
		vec3 axis = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
		float lit = clamp((dot(ray, axis) - cone_edge) / max(1.0 - cone_edge, 0.001), 0.0, 1.0);
		bend = lit * lit * amount;
	} else {
		// How near this view ray passes the lamp itself, which is the only measure
		// that behaves both outside the shell and inside it. Reading the chord
		// through the sphere instead — the obvious choice, and the one tried first —
		// is correct only from outside: standing among nine overlapping throws,
		// every direction has a long chord, so the whole frame wobbles and the
		// effect becomes the screen filter this segment exists to replace.
		vec3 lamp_view = (VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float along = dot(lamp_view, ray);
		if (along <= 0.0) {
			// The lamp is behind this ray. Air it is not lighting is air it does not bend.
			discard;
		}
		float miss = length(lamp_view - ray * along);
		// Squared, because hot air does not have an edge — and it is what removes
		// the shell's own silhouette, since the strength is already nothing there.
		float radial = clamp(1.0 - miss / max(reach, 0.001), 0.0, 1.0);
		bend = radial * radial * amount;
	}
	if (bend <= 0.001) {
		discard;
	}

	// Sampled in world space rather than in the shell's own coordinates: those
	// are identical from one shell to the next, so nine lamps would have been
	// nine copies of one pattern. Each one now reads the part of the field it is
	// standing in. Two samples at different rates, so the flow does not read as a
	// single sheet of noise sliding past.
	vec2 drift_a = vec2(TIME * scroll * 0.11, TIME * scroll * -0.19);
	vec2 drift_b = vec2(TIME * scroll * -0.07, TIME * scroll * -0.31);
	vec2 field = texture(noise_texture, world_position.xy * 0.31 + drift_a).rg
		+ texture(noise_texture, world_position.zy * 0.47 + drift_b).rg;
	vec2 offset = (field - vec2(1.0)) * strength * bend;

	vec3 lit = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = mix(lit, lit * tint, tint_strength * bend);
	ALPHA = 1.0;
}
