shader_type canvas_item;

// The frame around the cold open. Greg: *"ad a border that matches is 3d
// visceral organs bloody ect but regal"*, and *"make the edges blended and more
// different and gamified then the orignal 2 images"*, and *"curving on the
// screen to make a alien futuristic hud but still playabile and seamless"*.
//
// Those are three asks and they are one problem: what happens at the edge of the
// picture. Right now the answer is nothing — `splash_attack.gdshader` ends on a
// binary `step()` mask, so his photograph is a rectangle with a hard cut around
// it sitting in black, which is the single thing that makes it read as a pasted
// image rather than as a screen.
//
// The load-bearing idea here is the one that reconciles "visceral" with "regal",
// because those pull against each other: viscera is asymmetric and regalia is
// not. So the vasculature is **mirrored about the midpoint of each side**. Real
// organs are never symmetric; the moment you make them symmetric they stop
// reading as a wound and start reading as heraldry — a coat of arms cut out of
// an animal. That is the whole trick, and it is why this is a shader rather than
// a painted border: the symmetry has to be exact to work, and exact is cheap in
// a shader and expensive by hand.
//
// Drawn as a separate pass over whatever is beneath rather than inside the photo
// shader. That is partly composition and partly traffic: several agents are in
// the cold open at once, and a frame that paints over the seam works no matter
// what any of them do to the picture underneath.

// The opening the picture shows through, in units of the screen's short axis
// on BOTH axes (so x runs past 1.0 on a widescreen window).
uniform vec2 opening = vec2(1.035, 0.80);
// Corner rounding of that opening, in the same units. Kept small: the picture
// behind it has square corners, and a frame rounded harder than its picture lets
// the picture's own corners poke out past the ornament — which was visible as a
// bright right-angle at the top-left and top-right of the first fitted render.
uniform float radius : hint_range(0.0, 0.4) = 0.022;
// How far the frame reaches outward from the opening.
uniform float thickness : hint_range(0.01, 0.6) = 0.20;
// How far the frame reaches *inward* over the picture. This is the feather that
// kills the hard rectangle: the ornament overlaps the photograph's own edge, so
// there is no seam left to see.
uniform float bite : hint_range(0.0, 0.25) = 0.090;

// Barrel warp. Applied to the frame's own geometry so the opening bows like
// glass. Deliberately small — Greg asked for curvature and for "still playable"
// in the same sentence, and past about 0.06 straight UI lines start to bend
// enough to notice while reading them.
uniform float curvature : hint_range(0.0, 0.25) = 0.045;

// Tissue is dark. These are deliberately well below the reds in Greg's
// photograph so the frame sits *behind* the picture in depth rather than
// competing with it — the picture is the subject and the frame is the mount.
uniform vec3 meat : source_color = vec3(0.185, 0.028, 0.026);
uniform vec3 deep : source_color = vec3(0.035, 0.008, 0.012);
uniform vec3 vessel_hue : source_color = vec3(0.42, 0.055, 0.05);
// The regal half. Bone rather than gold: the project's ink is already bone and a
// true gold reads as fantasy rather than as the reliquary this is after.
uniform vec3 regal : source_color = vec3(0.92, 0.84, 0.66);
uniform vec3 wet : source_color = vec3(1.0, 0.86, 0.82);

// Swags along each half-side. A count, not a frequency, so the rhythm stays put
// when the opening is resized. Low on purpose: a lobed silhouette needs few
// enough lobes that each one is a shape you can see, or it turns back into the
// ripple the first cut produced.
uniform float lobes = 4.0;
// How far the lobes displace the frame edge, in the same units as `thickness`.
uniform float lobe_depth : hint_range(0.0, 0.12) = 0.026;
uniform float vessel_gain : hint_range(0.0, 1.5) = 0.85;
uniform float gloss : hint_range(0.0, 2.0) = 0.9;
uniform float clock = 0.0;
// Master fade so the frame can arrive with the rest of the cold open.
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
// A slow swell, like something breathing behind the picture.
uniform float pulse : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

// Signed distance to a rounded rectangle. Negative inside.
float rounded_rect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// Work in a space where one unit is one unit in both axes, so the ornament
	// is not stretched on a 16:9 window. x carries the aspect.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	// `opening` is already in units of the short axis on both axes — the same
	// units `p` is in, since p.x was just scaled by the aspect. Multiplying x by
	// the aspect a second time here made a 1.035-wide opening 0.92 against a
	// screen half-width of 0.888, pushing both side runs off the edge of the
	// screen; the frame looked thin at the top and bottom because those were the
	// only runs still fully on it.
	vec2 half_size = opening * 0.5;

	// Barrel warp. Pushing the sample point *inward* with radius bows the
	// opening outward, which is the direction a CRT bulges.
	float r2 = dot(p, p);
	p *= 1.0 - curvature * r2;

	float d0 = rounded_rect(p, half_size, radius);

	// Position along whichever side we are on, -1..1, and its mirror. `sym` is
	// the regal coordinate: ornament written against it is automatically
	// symmetric about each side's midpoint.
	bool vertical_side = abs(p.x) * half_size.y > abs(p.y) * half_size.x;
	float along = vertical_side ? p.y / max(half_size.y, 1e-4) : p.x / max(half_size.x, 1e-4);
	float sym = abs(clamp(along, -1.0, 1.0));

	// The regal device is the *silhouette*, not stripes drawn on the band.
	//
	// The first cut of this put bead-and-reel highlights across the frame and it
	// read as a barcode — hard bright verticals that said "radiator grille", not
	// "carving". Ornament at this scale has to be shape: a baroque cartouche is
	// recognisable from its lobed outline with all its surface detail removed,
	// and a lobed margin is also what the edge of an actual organ looks like. So
	// one low-frequency symmetric wave displaces the whole frame instead, and it
	// does the work of both halves of "visceral but regal" at once.
	float lobe = sin(sym * lobes * 3.14159);
	// Squared-off toward the crests so the lobes read as distinct swags rather
	// than as a sine wave, which is the difference between carving and ripple.
	lobe = sign(lobe) * pow(abs(lobe), 0.65);
	float d = d0 - lobe * lobe_depth;

	// Where we are across the frame band: 0 at the inner lip (over the picture),
	// 1 at the outer edge where it dissolves into the ground.
	float band = (d + bite) / (thickness + bite);

	// Everything past the outer edge, and everything well inside the opening, is
	// untouched — the picture shows through.
	if (band <= 0.0 || band >= 1.0) {
		COLOR = vec4(0.0);
		discard;
	}

	// Corners get their own weight so they can carry more mass, the way a
	// cartouche thickens where two runs of carving meet.
	float corner = smoothstep(0.72, 1.0, sym);

	float breath = 1.0 + 0.055 * pulse * sin(clock * 0.9 + sym * 3.0);

	// --- the meat -----------------------------------------------------------
	// Depth across the band: dark at the outer edge, lit toward the inner lip,
	// so the frame reads as a raised wet mass rather than a flat sticker.
	float thick = 1.0 - band;
	vec3 col = mix(deep, meat, pow(thick, 0.75) * breath);

	// Subsurface: red light bleeding through the thin parts, which is what makes
	// a membrane look like a membrane. Level is low on purpose — this is an
	// additive term and it was the main reason the first cut glowed.
	float sss = pow(max(1.0 - abs(band - 0.34) * 2.6, 0.0), 3.0);
	col += vec3(0.30, 0.035, 0.03) * sss * 0.30;

	// --- vasculature, mirrored ---------------------------------------------
	// Two octave sets at different scales so there are trunks and capillaries
	// rather than one uniform tangle. Written against `sym`, so the left half of
	// each side is the exact mirror of the right — the heraldry.
	vec2 vein_uv = vec2(sym * 7.0, band * 3.4);
	float trunk = fbm(vein_uv + vec2(0.0, clock * 0.02));
	float fine = fbm(vein_uv * 3.1 + vec2(11.3, 4.7));
	// Ridged noise turns the smooth field into filaments: the thin bright lines
	// are where the field passes through its midpoint.
	float veins = 1.0 - abs(trunk - 0.5) * 2.0;
	veins = pow(clamp(veins, 0.0, 1.0), 9.0);
	float capillary = 1.0 - abs(fine - 0.5) * 2.0;
	capillary = pow(clamp(capillary, 0.0, 1.0), 14.0);
	// Vessels thin out toward the outer edge, as they would running into tissue.
	float vein_mask = veins * (0.35 + 0.65 * thick) + capillary * 0.45 * thick;
	col = mix(col, vessel_hue, clamp(vein_mask * vessel_gain, 0.0, 1.0));

	// --- the regal half -----------------------------------------------------
	// One bone rule, hugging the inner lip. This is the line that makes the
	// opening read as deliberate — the difference between a framed picture and a
	// hole — and it lands exactly on the photograph's own hard cut, which is how
	// that cut stops being visible.
	//
	// Kept to a single thin line at low strength. The first cut ran two rules at
	// 0.72 and 0.4 and they read as a grey UI box drawn around the picture: a
	// bright closed rectangle reads as chrome no matter what is textured inside
	// it. The lobed silhouette above is now carrying the ornament, so this only
	// has to finish the edge.
	float rule = 1.0 - smoothstep(0.0, 0.030, abs(band - 0.115));
	// Broken where the lobes swing inward, so it is a moulding following a
	// carved edge rather than a rectangle stamped over one.
	rule *= 0.55 + 0.45 * smoothstep(-0.4, 0.6, lobe);
	col = mix(col, regal * 0.82, rule * 0.38);

	// Corner cartouches: the ornament gathers where the runs meet. Darker and
	// bloodier rather than brighter — mass, not highlight.
	float cartouche = corner * (1.0 - smoothstep(0.10, 0.70, band));
	col = mix(col, meat * 1.25, cartouche * 0.45);
	col = mix(col, deep, corner * smoothstep(0.55, 1.0, band) * 0.5);

	// --- wet ----------------------------------------------------------------
	// A specular lobe riding the band gradient, brightest where the vessels
	// stand proudest. Without this the whole thing reads as clay — but the first
	// cut added it at 0.30 on top of an already-additive subsurface term and the
	// frame came out glowing like a neon sign. Tissue is *dark* with small hot
	// highlights, so the lobe is narrow and the level is a third of what it was.
	float facing = 1.0 - smoothstep(0.05, 0.42, band);
	float spec = pow(clamp(facing * 0.7 + vein_mask * 0.9, 0.0, 1.0), 7.0);
	col += wet * spec * 0.11 * gloss;
	// A slow travelling sheen, so it looks lit by something rather than painted.
	float sheen = pow(max(0.0, sin(sym * 2.2 - clock * 0.35)), 16.0);
	col += wet * sheen * facing * 0.07 * gloss;

	// --- alpha: the blend Greg actually asked for ---------------------------
	// Inward, the frame fades out *over* the photograph, so its hard rectangular
	// cut is buried under ornament instead of being visible as a line.
	// Outward, it fades into the ground so the frame itself has no hard edge
	// either — otherwise this just moves the problem three centimetres.
	float inner_fade = smoothstep(0.0, 0.26, band);
	float outer_fade = 1.0 - smoothstep(0.68, 1.0, band);
	float alpha = inner_fade * outer_fade;

	// Torn rather than clean. The ground-side edge dissolves through noise so it
	// ends in tissue instead of in a vignette, which is the "more gamified than
	// the original two images" part — a clean feather would read as a Photoshop
	// glow sitting on top of his photograph.
	float rag = fbm(vec2(sym * 14.0, band * 2.0) + vec2(3.7, 9.1));
	alpha *= smoothstep(0.0, 0.42, 1.0 - band + (rag - 0.5) * 0.55);
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(col * reveal, alpha * reveal);
}
