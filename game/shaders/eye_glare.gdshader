shader_type canvas_item;
render_mode blend_add;

// Greg: *"can you make the eye on the left of the image glow and have a glare or
// bloom like lighting effect sublty in red in the bloom of a cross if blooms the
// right word"*.
//
// Bloom is the right word for the soft halo; the cross is a **star filter** —
// the four-pointed streak a real lens throws off a small bright source when it
// is stopped down, or that an anamorphic element throws along one axis. Two
// different things, and the ask wants both, so this is a core plus two crossed
// streaks rather than one blurred blob.
//
// Additive (`blend_add`), because a light source adds light. Alpha-blending a
// bright colour over the picture *replaces* what is under it, which is how you
// get a red sticker sitting on a photograph instead of something glowing inside
// it — the eye has to stay visible through its own glare.
//
// Positioned in UV rather than pixels so it stays on the eye at any window size,
// and placed under the CRT glass on purpose: the glare then gets the same
// curvature, bloom and aberration as everything else, which is what stops it
// reading as a separate layer pasted on top of the composition.

// Where the eye is, in screen UV. Defaults to the left eye of the room
// photograph, triangulated off the frame rather than eyeballed.
uniform vec2 at = vec2(0.467, 0.431);
uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.10);
// The halo. Small — this is an eye, not a lamp.
uniform float core_size : hint_range(0.002, 0.10) = 0.019;
// How far the arms of the cross reach.
uniform float arm_length : hint_range(0.01, 0.40) = 0.085;
// How tight the arms are. Small values make a sharper star.
uniform float arm_width : hint_range(0.001, 0.05) = 0.0062;
// Overall level. Greg said "sublty", and the number is the whole difference
// between a glint and a torch.
uniform float intensity : hint_range(0.0, 3.0) = 0.62;
// How much brighter the vertical arm is than the horizontal. Slightly uneven on
// purpose: a perfectly equal cross reads as a UI marker, and an uneven one
// reads as an optical artefact.
uniform float vertical_bias : hint_range(0.3, 2.0) = 0.78;
uniform float clock = 0.0;
// A slow swell. Small enough that it is felt rather than watched.
uniform float pulse : hint_range(0.0, 1.0) = 0.35;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// Square up the space so the cross is not stretched on a widescreen window.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - at) * vec2(aspect, 1.0);

	float r = length(d);

	// The halo. Gaussian rather than a linear falloff — a linear one has a
	// visible edge where it reaches zero, and the whole point of a bloom is that
	// it has no edge.
	float core = exp(-(r * r) / (core_size * core_size));
	// A wider, much fainter skirt under it. Real glare falls off over a long
	// distance; one Gaussian alone reads as a dot.
	float skirt = exp(-(r * r) / (core_size * core_size * 26.0)) * 0.22;

	// The cross. Each arm is tight across its own axis and falls off slowly
	// along it — exponential along the length, Gaussian across the width, which
	// is the shape a real star filter actually throws.
	float horizontal = exp(-(d.y * d.y) / (arm_width * arm_width)) * exp(-abs(d.x) / arm_length);
	float vertical = exp(-(d.x * d.x) / (arm_width * arm_width)) * exp(-abs(d.y) / arm_length) * vertical_bias;

	// The arms are cut off at the centre by the core, otherwise they cross into
	// a hard bright plus sign right where the halo already is.
	float arms = (horizontal + vertical) * smoothstep(0.0, core_size * 1.4, r);

	float amount = (core + skirt + arms * 0.55) * intensity;
	amount *= 1.0 + pulse * 0.18 * sin(clock * 1.6);

	// The core runs hotter than the tint toward white, because the middle of
	// anything this bright clips toward white in any real capture. Without it
	// the glare reads as flat red gel.
	vec3 col = mix(tint, mix(tint, vec3(1.0), 0.55), clamp(core * 1.2, 0.0, 1.0));

	COLOR = vec4(col * amount * reveal, 1.0);
}
