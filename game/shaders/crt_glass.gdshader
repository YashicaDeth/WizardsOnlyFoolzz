shader_type canvas_item;

// The glass in front of everything. Greg: *"curving on the screen to make a
// alien futuristic hud but still playabile and seamless"*, and *"slow
// degradation of crt distrortion"* between his two images.
//
// He already has a CRT plugin for After Effects and TouchDesigner, and said so.
// Doing it live instead buys the same three things `splash_attack.gdshader`
// bought by not baking the invert: the curvature responds to the window it is
// actually running in rather than to the frame size a render was exported at,
// the degradation can be *driven* — by a scene beat, a hit, an image switch —
// instead of being a fixed timeline, and it survives the picture underneath
// being swapped. A baked CRT pass is a decision; a live one is a dial.
//
// The constraint that shapes all of it is Greg's own, in the same sentence:
// "still playabile and seamless". A real CRT geometry does about 8% barrel and
// eats the corners. That is fine over a photograph and hostile over a menu, so
// this is built to sit under the readable layer rather than over it, and the
// defaults are set where the glass reads as glass and no straight line bends
// enough to be noticed while you are looking at something else.
//
// Everything scales off `degrade`, so one number takes it from "clean panel" to
// "the signal is going". That is the dial the two-image switch wants: the
// distortion can swell as the invert tears across and settle after it lands,
// rather than sitting at a constant level that stops being information.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// 0 = flat panel, 1 = the tube is failing. Everything below scales off this.
uniform float degrade : hint_range(0.0, 1.0) = 0.35;
// Barrel. Small by default for the reason in the header — this is the one
// uniform that can make the game unplayable if it is turned up thoughtlessly.
uniform float curvature : hint_range(0.0, 0.30) = 0.055;
// Scanline count down the screen. Tied to a count rather than a UV frequency so
// the lines stay the same thickness when the window is resized.
uniform float scanlines = 240.0;
uniform float scanline_depth : hint_range(0.0, 1.0) = 0.16;
// The shadow mask — RGB triads across. Very cheap, and the single strongest cue
// that a picture is on a tube rather than behind a filter.
uniform float mask_depth : hint_range(0.0, 1.0) = 0.10;
uniform float aberration : hint_range(0.0, 0.02) = 0.0022;
uniform float vignette : hint_range(0.0, 1.5) = 0.42;
uniform float bloom : hint_range(0.0, 1.0) = 0.22;
uniform float clock = 0.0;
// Master fade, so the glass can arrive with the rest of the cold open instead
// of being on at frame one.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
// How hard the picture rolls. A tube losing vertical hold slips the whole frame
// rather than blurring it, which is the "stop motion" register Greg asked for —
// discrete jumps that hold, not a smooth drift.
uniform float roll : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- geometry -----------------------------------------------------------
	// Barrel about the centre. Curvature grows a little with degradation, so a
	// failing tube also bulges — the two read as one thing going wrong rather
	// than as two effects layered.
	vec2 c = uv - vec2(0.5);
	float r2 = dot(c, c);
	float bow = curvature * (1.0 + degrade * 0.5);
	vec2 warped = c * (1.0 + bow * r2) + vec2(0.5);

	// --- stop-motion roll ---------------------------------------------------
	// Quantised time, not continuous. A tube that has lost hold jumps to a new
	// offset and *stays* there for a beat; interpolating between offsets turns
	// it into a wobble, which reads as underwater rather than as broken.
	float step_index = floor(clock * 7.0);
	float slip = (hash(vec2(step_index, 3.1)) - 0.5) * 0.020 * roll * degrade;
	// Only some steps slip at all. A permanent offset is just a misaligned
	// picture; the failure is that it is *intermittent*.
	slip *= step(0.62, hash(vec2(step_index, 11.7)));
	warped.y += slip;

	// A single bright band travelling down the frame, the way a mistimed tube
	// shows the retrace. Slow, and low-contrast, because this one is very easy
	// to overdo into a strobe.
	float bar = fract(uv.y * 0.9 - clock * 0.11);
	float retrace = pow(1.0 - abs(bar - 0.5) * 2.0, 24.0) * degrade;

	// --- sampling -----------------------------------------------------------
	// Chromatic aberration grows toward the edges, which is where a real lens
	// and a real tube both lose registration, rather than sitting uniform.
	float edge_weight = r2 * 4.0;
	vec2 push = normalize(c + vec2(1e-5)) * aberration * (0.35 + edge_weight) * (1.0 + degrade * 2.0);
	vec3 col;
	col.r = texture(screen_tex, warped + push).r;
	col.g = texture(screen_tex, warped).g;
	col.b = texture(screen_tex, warped - push).b;

	// Cheap bloom off the mip chain — the glow a phosphor has around anything
	// bright, which is most of what separates "emissive" from "printed".
	vec3 soft = textureLod(screen_tex, warped, 3.0).rgb;
	col += soft * soft * bloom;

	// --- the tube -----------------------------------------------------------
	// Scanlines. Modulated so they are strongest in the mid-tones: a real tube
	// shows its lines in the greys and blows through them in the highlights,
	// and flat lines over everything read as a screen-door texture pasted on.
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	float line = 0.5 + 0.5 * sin(warped.y * scanlines * 6.28318);
	float line_strength = scanline_depth * (0.4 + 0.6 * degrade) * (1.0 - luma * 0.55);
	col *= 1.0 - line * line_strength;

	// Shadow mask: RGB triads across. FRAGCOORD rather than UV so the triad is
	// one pixel wide at any resolution, which is what keeps it from moiring.
	float triad = mod(FRAGCOORD.x, 3.0);
	vec3 mask = vec3(
		triad < 1.0 ? 1.0 : 0.55,
		(triad >= 1.0 && triad < 2.0) ? 1.0 : 0.55,
		triad >= 2.0 ? 1.0 : 0.55);
	col *= mix(vec3(1.0), mask, mask_depth * (0.5 + 0.5 * degrade));

	col += vec3(0.55, 0.62, 0.70) * retrace * 0.10;

	// --- the edge of the glass ---------------------------------------------
	float vig = 1.0 - smoothstep(0.28, 0.95, r2 * 2.0) * vignette;
	col *= vig;

	// Past the bowed edge there is no picture, because the geometry pulled it
	// in. Black rather than clamped, so the curve has a real edge instead of
	// smearing the border pixel outward into a streak.
	vec2 past = step(vec2(0.0), warped) * step(warped, vec2(1.0));
	float inside = past.x * past.y;

	// Nothing above touches alpha, so the glass never dims what is behind it —
	// it replaces it. `reveal` cross-fades to the untouched picture instead of
	// to black, which is what lets it arrive without a flash.
	vec3 flat_col = texture(screen_tex, uv).rgb;
	COLOR = vec4(mix(flat_col, col * inside, reveal), 1.0);
}
