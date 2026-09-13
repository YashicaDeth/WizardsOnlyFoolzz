shader_type canvas_item;

// FINAL_V.md §16, "What to build first," item 1: one shader, six dials, all
// zero (or otherwise neutral) by default so this is a no-op until something
// asks it to be more. Drugs, meditation, the shadow realms and AS2's night
// warp are meant to be this shader at different dial values, never a system
// each.

// The live frame, auto-bound to whatever was drawn earlier this same frame —
// never this shader's own prior output, which is what `feedback_texture`
// below is for. Getting those two sources conflated is what "sampling its
// own previous frame" actually has to mean here: the live input must stay a
// single, non-accumulating frame, or every dial compounds every frame instead
// of the one dial built to do that on purpose.
uniform sampler2D source_texture : hint_screen_texture, filter_linear_mipmap;
// Bound from script to the whole game view's own last finished frame — see
// `psychedelic_rig.gd`. Deliberately the one input allowed to include this
// shader's own prior contribution.
uniform sampler2D feedback_texture : hint_default_black, filter_linear_mipmap;
uniform sampler2D lut_texture : hint_default_white, filter_linear;
uniform sampler2D noise_texture : hint_default_black, filter_linear_mipmap, repeat_enable;

// 1. Palette LUT. A 1D luminance-keyed lookup rather than a true 3D cube —
// enough dial to test against before a real cube LUT exists to sample.
uniform float lut_strength : hint_range(0.0, 1.0) = 0.0;

// 2. Kaleidoscope UV fold. Segments below 2 leaves the frame unfolded.
uniform float kaleidoscope_segments : hint_range(0.0, 24.0) = 0.0;
uniform float kaleidoscope_spin = 0.0;

// 3. Feedback: the previous frame, zoomed and spun, blended back in. The
// texture itself comes from `psychedelic_rig.gd`'s ping-ponged SubViewports —
// this shader only knows it is handed one.
uniform float feedback_strength : hint_range(0.0, 1.0) = 0.0;
uniform float feedback_zoom = 1.0;
uniform float feedback_spin = 0.0;

// 4. Chromatic separation.
uniform float chromatic_offset : hint_range(0.0, 0.05) = 0.0;

// 5. Noise displacement: warp, ripple, melt.
uniform float displacement_strength : hint_range(0.0, 0.3) = 0.0;
uniform float displacement_scroll = 0.3;

// 6. Beat-locked cuts: a hard hold on a hashed frame rather than a fade,
// because a cut that fades is not a cut.
uniform float cut_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float cut_seed = 0.0;
uniform float cut_rate = 8.0;

float hash11(float x) {
	return fract(sin(x) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;

	// 2. Fold the frame into wedges before anything samples it.
	if (kaleidoscope_segments >= 2.0) {
		float angle = atan(centered.y, centered.x) + TIME * kaleidoscope_spin;
		float radius = length(centered);
		float wedge = TAU / kaleidoscope_segments;
		angle = abs(mod(angle, wedge) - wedge * 0.5);
		centered = vec2(cos(angle), sin(angle)) * radius;
		uv = centered * 0.5 + 0.5;
	}

	// 5. Warp the sample point through a scrolling flow field.
	if (displacement_strength > 0.0) {
		vec2 flow = texture(noise_texture, uv * 0.6 + vec2(0.0, TIME * displacement_scroll)).rg - 0.5;
		uv += flow * displacement_strength;
	}

	// 4. Chromatic separation, sampled off the (possibly folded/warped) uv.
	vec3 color;
	if (chromatic_offset > 0.0) {
		vec2 dir = length(centered) > 0.0001 ? normalize(centered) : vec2(1.0, 0.0);
		color.r = texture(source_texture, uv + dir * chromatic_offset).r;
		color.g = texture(source_texture, uv).g;
		color.b = texture(source_texture, uv - dir * chromatic_offset).b;
	} else {
		color = texture(source_texture, uv).rgb;
	}

	// 1. Palette LUT, keyed on luminance.
	if (lut_strength > 0.0) {
		float luma = dot(color, vec3(0.299, 0.587, 0.114));
		vec3 graded = texture(lut_texture, vec2(luma, 0.5)).rgb;
		color = mix(color, graded, lut_strength);
	}

	// 3. Feedback: the other viewport's last finished frame, transformed and
	// blended back over the top. This is the one effect that cannot be faked
	// with a single pass — see `psychedelic_rig.gd`.
	if (feedback_strength > 0.0) {
		float spin = feedback_spin * TIME;
		mat2 rot = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin)));
		vec2 feedback_uv = (rot * centered) / max(feedback_zoom, 0.001) * 0.5 + 0.5;
		vec3 trailed = texture(feedback_texture, feedback_uv).rgb;
		// AU4.4. This was `mix(color, trailed, feedback_strength)`, which is a
		// low-pass filter with no energy going in: each frame is 72% of the
		// last one at 0.72, so after a second of held feedback every pixel has
		// converged on the average of the frame and the screen is flat grey.
		// That is what killed the first capture sheet's "everything" shot.
		//
		// A trail is an afterimage, not a crossfade. `max` can only ever
		// brighten, so the current frame's contrast survives intact and the
		// previous frame shows through exactly where the new one is darker -
		// which is what a phosphor actually does. Multiplying the trail by
		// `feedback_strength` is what makes it decay instead of ratcheting to
		// white: at 0.72 an afterimage is down to 4% after ten frames.
		color = max(color, trailed * feedback_strength);
	}

	// 6. Beat-locked cuts: about half of each beat holds on a flat hashed
	// colour instead of the frame underneath.
	if (cut_intensity > 0.0) {
		float beat = floor(TIME * cut_rate + cut_seed);
		float held = step(0.5, hash11(beat * 91.7));
		color = mix(color, vec3(hash11(beat * 12.9898)), held * cut_intensity);
	}

	COLOR = vec4(color, 1.0);
}
