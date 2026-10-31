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
// drug-70: inside this radius (of the half-screen) the frame is not folded,
// with a soft band outside it. 0 folds everything, as before.
uniform float kaleidoscope_clear : hint_range(0.0, 1.5) = 0.0;

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

// drug-70: the dials the materia classes needed that the first six did not
// have. Every one is neutral at 0, so a scene that never names them pays a
// branch each and sees nothing.

// 1b. Palette cycling: the LUT key scrolls, cycles per second. Only does
// anything while `lut_strength` is up.
uniform float palette_cycle = 0.0;
// 2b. A left/right mirror fold, 0 or 1 (blended between). Cheaper and plainer
// than the kaleidoscope, and what a body-stone reads as.
uniform float mirror_fold : hint_range(0.0, 1.0) = 0.0;
// 5b. Melt: the frame drips down along noise columns.
uniform float melt_strength : hint_range(0.0, 0.2) = 0.0;
// 7. Beat-locked pulse. `beat_level` is fed by `AudioReactive` (the audio bus
// spectrum, 0-1 and already smoothed); `pulse_strength` is how far the frame
// breathes in on it. A pulse is a push, not a cut: it is the other half of
// what "beat-locked" meant in FINAL_V's table.
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.0;
uniform float beat_level : hint_range(0.0, 1.0) = 0.0;
// 8. Saturation, -1 grey to +1 oversaturated.
uniform float saturation_shift : hint_range(-1.0, 1.0) = 0.0;
// 9. Darkness from the edge in. The deliriant dial: the light goes first.
uniform float darkness : hint_range(0.0, 1.0) = 0.0;
// 10. Detachment: the world shrinks away into the middle of the screen with
// nothing around it. The dissociative dial.
uniform float tunnel : hint_range(0.0, 1.0) = 0.0;
// 11. Figures at the edge of vision. Never in the middle of the frame, never
// lit, never there when you would look straight at them.
uniform float edge_figures : hint_range(0.0, 1.0) = 0.0;

float hash11(float x) {
	return fract(sin(x) * 43758.5453123);
}

// A standing shape: head and a tapered body, in a box `size` tall, feet at
// `foot`. Returns coverage 0-1 with a soft edge. Coordinates are aspect-
// corrected so a figure is not stretched by the screen.
float figure(vec2 p, vec2 foot, float size, float lean) {
	vec2 q = (p - foot) / size;
	q.x -= q.y * lean;
	float head = length(q - vec2(0.0, 0.86)) - 0.085;
	float width = mix(0.16, 0.07, clamp(q.y / 0.78, 0.0, 1.0));
	float body = max(abs(q.x) - width, max(-q.y, q.y - 0.78));
	float d = min(head, body);
	return 1.0 - smoothstep(0.0, 0.035, d);
}

void fragment() {
	vec2 uv = UV;
	// 7. The pulse breathes the whole frame in toward its middle.
	if (pulse_strength > 0.0) {
		uv = (uv - 0.5) * (1.0 - pulse_strength * beat_level * 0.06) + 0.5;
	}
	// 10. Detachment shrinks the frame before anything else touches it.
	if (tunnel > 0.0) {
		uv = (uv - 0.5) * (1.0 + tunnel * 0.9) + 0.5;
	}
	// 2b. Mirror fold.
	if (mirror_fold > 0.0) {
		uv.x = mix(uv.x, 0.5 - abs(uv.x - 0.5), mirror_fold);
	}
	vec2 centered = uv * 2.0 - 1.0;

	// 2. Fold the frame into wedges before anything samples it.
	if (kaleidoscope_segments >= 2.0) {
		float angle = atan(centered.y, centered.x) + TIME * kaleidoscope_spin;
		float radius = length(centered);
		float wedge = TAU / kaleidoscope_segments;
		angle = abs(mod(angle, wedge) - wedge * 0.5);
		vec2 folded = vec2(cos(angle), sin(angle)) * radius;
		float fold = kaleidoscope_clear > 0.0 ? smoothstep(kaleidoscope_clear, kaleidoscope_clear + 0.3, radius) : 1.0;
		centered = mix(centered, folded, fold);
		uv = centered * 0.5 + 0.5;
	}

	// 5. Warp the sample point through a scrolling flow field.
	if (displacement_strength > 0.0) {
		vec2 flow = texture(noise_texture, uv * 0.6 + vec2(0.0, TIME * displacement_scroll)).rg - 0.5;
		uv += flow * displacement_strength;
	}
	// 5b. Melt: columns of the frame slide down at their own rate.
	if (melt_strength > 0.0) {
		float column = texture(noise_texture, vec2(uv.x * 3.0, 0.37)).r;
		uv.y -= melt_strength * column * (0.5 + 0.5 * sin(TIME * 0.4 + column * 6.0)) * uv.y;
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
		vec3 graded = texture(lut_texture, vec2(fract(luma + TIME * palette_cycle), 0.5)).rgb;
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

	// 8. Saturation around the frame's own luminance.
	if (saturation_shift != 0.0) {
		float grey = dot(color, vec3(0.299, 0.587, 0.114));
		color = max(mix(vec3(grey), color, 1.0 + saturation_shift), vec3(0.0));
	}

	// 7. The beat lifts the frame a little as well as pushing it.
	if (pulse_strength > 0.0) {
		color *= 1.0 + pulse_strength * beat_level * 0.25;
	}

	vec2 screen = UV * 2.0 - 1.0;
	// 10. Outside the shrunken frame there is nothing.
	if (tunnel > 0.0) {
		float edge = max(abs(screen.x), abs(screen.y));
		color *= 1.0 - smoothstep(1.0 / (1.0 + tunnel * 0.9) - 0.12, 1.0 / (1.0 + tunnel * 0.9), edge) * tunnel;
	}

	// 11. Figures at the edge. Each holds its place for a few seconds, then is
	// somewhere else; they sit only in the outer fifth of the frame, and a
	// figure fades as the frame's middle gets closer to it.
	if (edge_figures > 0.0) {
		float aspect = SCREEN_PIXEL_SIZE.y / max(SCREEN_PIXEL_SIZE.x, 0.000001);
		vec2 p = vec2(UV.x * aspect, 1.0 - UV.y);
		float cover = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float slot = floor(TIME / (2.6 + fi * 0.9) + fi * 17.0);
			float t = fract(TIME / (2.6 + fi * 0.9) + fi * 17.0);
			float side = step(0.5, hash11(slot * 3.1 + fi));
			float x = mix(0.03 + hash11(slot * 5.7 + fi) * 0.12, 0.85 + hash11(slot * 7.3 + fi) * 0.12, side) * aspect;
			float size = 0.42 + hash11(slot * 9.1 + fi) * 0.3;
			float there = step(0.35, hash11(slot * 1.3 + fi * 4.0)) * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.8, 1.0, t));
			cover = max(cover, figure(p, vec2(x, 0.02), size, (hash11(slot + fi) - 0.5) * 0.25) * there);
		}
		float periphery = smoothstep(0.35, 0.75, abs(screen.x));
		color *= 1.0 - cover * periphery * edge_figures * 0.92;
	}

	// 9. Darkness: a vignette that eats inward and crushes what it leaves.
	// The edge keeps a dim floor rather than going to black, because what
	// stands at the edge (dial 11) has to have something to stand against.
	if (darkness > 0.0) {
		float r = length(screen * vec2(1.0, 0.8));
		float eaten = smoothstep(1.25 - darkness * 1.05, 1.35 - darkness * 0.6, r);
		color *= mix(1.0, 0.2, eaten) * (1.0 - darkness * 0.45);
	}

	COLOR = vec4(color, 1.0);
}
