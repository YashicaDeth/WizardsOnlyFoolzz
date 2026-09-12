shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;

// One shader behind five of the six TouchDesigner techniques on Greg's list,
// because five of them are the same technique with a different source:
//
//   ".PNG into particles | Reorder TOP explained"  - a still image becomes points
//   "TouchDesigner tutorial - image to visual"     - the same, moving
//   "Animated .fbx into Particles"                 - a mesh becomes points
//   "Glitch Spider particle system"                - those points, torn
//   "3D Matrix Tutorial"                           - those points, falling
//
// In TouchDesigner that chain is a TOP reordered into position and colour
// channels and fed to instancing. This is the same idea in the form Godot is
// good at: one `MultiMesh` of billboarded quads, one draw call, and a vertex
// shader that reads each point's colour and displacement out of a texture. A
// hundred thousand points cost one draw call and no CPU per frame.
//
// Every dial is at zero by default, the same rule `psychedelic.gdshader`
// follows, so a field that nobody has touched is an honest picture of its
// source and nothing else.

// Where the points read their colour, and their height if `relief` is up. For
// an image field this is the image. For a mesh field it is the baked surface
// colour. Either way: one texel, one point.
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// The point itself.
uniform float point_size = 0.02;
// How much of the size comes from how bright the texel is. At 1.0 the dark
// parts of a picture vanish and the bright parts carry it, which is what makes
// a photograph read as a cloud rather than as a grid.
uniform float size_from_luma : hint_range(0.0, 1.0) = 0.6;
// Below this the point is not drawn at all. The single most useful dial in the
// set: an image field is mostly background, and background costs real fill.
uniform float alpha_floor : hint_range(0.0, 1.0) = 0.03;

// Displacement along the field's own normal, by brightness. This is the whole
// of "image to visual" — a flat picture becomes a relief you can orbit.
uniform float relief = 0.0;
// Scatter, in metres, along a per-point random direction. Breaks the grid.
uniform float spread = 0.0;

// "Glitch Spider": horizontal bands torn sideways, re-picked on a stepped
// clock rather than a smooth one, because a glitch that eases is not a glitch.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_bands = 48.0;
uniform float glitch_rate = 11.0;

// "3D Matrix": the field falls in lanes and wraps, bright at the head of each
// stream and dark behind it.
uniform float fall : hint_range(0.0, 1.0) = 0.0;
uniform float fall_span = 6.0;
uniform float fall_rate = 0.22;

// The radio. One band of the spectrum, 0 to 1, pushing points off the surface
// and lifting their brightness with it.
uniform float audio : hint_range(0.0, 1.0) = 0.0;
uniform float audio_lift = 0.0;
uniform float audio_glow : hint_range(0.0, 4.0) = 0.0;

// Slow rotation about the field's normal, in radians per second. Cheap, and it
// is what stops a still field from reading as a texture on a quad.
uniform float swirl = 0.0;
uniform vec3 field_normal = vec3(0.0, 0.0, 1.0);
uniform vec3 field_centre = vec3(0.0, 0.0, 0.0);

// A dissolve, for cutscenes and for a spirit arriving or leaving: points below
// this threshold in their own random order are simply not there.
uniform float presence : hint_range(0.0, 1.0) = 1.0;

varying vec3 point_colour;
varying float point_alpha;

float hash11(float n) {
	return fract(sin(n * 78.233) * 43758.5453123);
}

vec3 hash31(float n) {
	return vec3(hash11(n), hash11(n + 11.7), hash11(n + 27.3));
}

void vertex() {
	// x,y is where this point reads the source. z is its own random number,
	// stable for the life of the field so a point does not re-roll every frame.
	// w is spare and carries a per-point weight for mesh fields.
	vec2 cell = INSTANCE_CUSTOM.xy;
	float seed = INSTANCE_CUSTOM.z;

	vec4 texel = textureLod(source_texture, cell, 0.0);
	float luma = dot(texel.rgb, vec3(0.299, 0.587, 0.114));

	// MODEL_MATRIX already carries the instance's own transform, so this is
	// where the point sits in the world before anything is done to it.
	vec3 world = MODEL_MATRIX[3].xyz;
	vec3 normal_dir = normalize(field_normal);
	vec3 random = hash31(seed * 137.0);

	world += normal_dir * (luma - 0.5) * relief;
	world += (random - 0.5) * 2.0 * spread;

	// Audio pushes points off the surface and brightens them together, which is
	// the difference between a visual that reacts and one that merely moves.
	world += normal_dir * audio * audio_lift * (0.35 + luma);

	if (swirl != 0.0) {
		vec3 from_centre = world - field_centre;
		float angle = swirl * TIME * (0.6 + 0.8 * seed);
		float c = cos(angle);
		float s = sin(angle);
		// Rodrigues about the field normal.
		from_centre = from_centre * c
			+ cross(normal_dir, from_centre) * s
			+ normal_dir * dot(normal_dir, from_centre) * (1.0 - c);
		world = field_centre + from_centre;
	}

	float alpha = texel.a * tint.a;

	if (glitch > 0.0001) {
		// One tear per band, re-picked on a stepped clock. Most bands stay put:
		// a field where everything is torn reads as noise, not as damage.
		float band = floor(cell.y * glitch_bands);
		float roll = hash11(band + floor(TIME * glitch_rate) * 31.7);
		float torn = step(1.0 - glitch * 0.55, roll);
		float throw_distance = (hash11(band + 5.0) - 0.5) * 2.0;
		world += normalize(cross(normal_dir, vec3(0.0, 1.0, 0.0)) + vec3(0.0001))
			* throw_distance * glitch * torn * 1.4;
		// The torn band loses its colour as well as its place.
		alpha *= mix(1.0, 0.45 + 0.55 * roll, torn);
	}

	if (fall > 0.0001) {
		// Lanes, not a sheet. Each column falls at its own rate and wraps.
		float lane = hash11(floor(cell.x * 256.0) + 3.0);
		float progress = fract(lane + cell.y + TIME * fall_rate * (0.45 + lane));
		world -= vec3(0.0, 1.0, 0.0) * (progress - 0.5) * fall_span * fall;
		// Bright at the head of the stream, fading down its tail.
		alpha *= mix(1.0, pow(1.0 - progress, 2.0) * 1.8, fall);
	}

	// The dissolve. A stable per-point threshold, so a field fading in arrives
	// in the same order every time rather than sparkling.
	alpha *= step(random.z, presence);

	point_colour = texel.rgb * tint.rgb * (1.0 + audio * audio_glow);
	point_alpha = alpha;

	// Billboard. The quad is rebuilt to face the camera, keeping the world
	// position worked out above.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		vec4(world, 1.0));

	float size = point_size * mix(1.0, luma, size_from_luma) * (0.65 + 0.7 * seed);
	// A point under the floor collapses to nothing rather than being drawn and
	// then discarded, which saves the fragment work as well as the pixel.
	size *= step(alpha_floor, alpha * luma + alpha * (1.0 - size_from_luma));
	VERTEX.xy *= size;
}

void fragment() {
	// A round point, not a square one. The quad is the cheapest primitive and
	// this is what stops it looking like one.
	vec2 from_middle = UV - vec2(0.5);
	float radius = length(from_middle) * 2.0;
	float edge = 1.0 - smoothstep(0.72, 1.0, radius);
	if (point_alpha * edge < 0.004) {
		discard;
	}
	ALBEDO = point_colour;
	ALPHA = point_alpha * edge;
}
