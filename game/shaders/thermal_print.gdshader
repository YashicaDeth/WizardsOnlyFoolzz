shader_type canvas_item;
// Receipt paper (item 5, Greg 2026-09-24): whatever a surface draws under this
// rect -- light text on a dark panel -- is re-printed as ink on paper: 2-pixel
// dots, a Bayer threshold instead of smooth grey, saturated accents in red ink.
// One stock per surface, each distinct:
//   0 REGISTER  thermal receipt: off-white, torn zig-zag ends, fading streaks
//   1 FLYER     cheap coloured copy paper with tear-off tabs along the foot
//   2 CARD      heavy cream card stock, crisp ink, a pressed edge
//   3 FEED      continuous tractor-feed: green bars, sprocket holes, dot matrix

uniform int stock = 0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float dot_size = 2.0;
uniform vec2 rect_size = vec2(600.0, 400.0);

float bayer4(vec2 px) {
	int i = int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * rect_size;
	// Snap to the printer's dot grid.
	vec2 cell = floor(px / dot_size) * dot_size;
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 sample_uv = SCREEN_UV + (cell - px) / screen_px;
	vec3 under = texture(screen_tex, sample_uv).rgb;
	float lum = dot(under, vec3(0.299, 0.587, 0.114));
	float sat = max(max(under.r, under.g), under.b) - min(min(under.r, under.g), under.b);
	// Bright marks on the dark panel are what gets printed.
	// A hard cut: dim text prints solid, the panel grain below it prints nothing.
	float ink = smoothstep(0.12, 0.17, lum);

	vec3 paper;
	vec3 ink_black;
	vec3 ink_red = vec3(0.72, 0.10, 0.08);
	float fade = 1.0;
	float alpha = 1.0;
	if (stock == 0) {
		paper = vec3(0.93, 0.91, 0.86);
		ink_black = vec3(0.22, 0.22, 0.28);
		// Thermal paper fades in long horizontal streaks.
		fade = 0.72 + 0.28 * hash(vec2(0.0, floor(px.y / 7.0)));
		// Torn ends: a zig-zag bite out of top and bottom.
		float zig = abs(fract(px.x / 14.0) - 0.5) * 10.0;
		if (px.y < zig || px.y > rect_size.y - zig) { alpha = 0.0; }
	} else if (stock == 1) {
		paper = vec3(0.98, 0.83, 0.62);
		ink_black = vec3(0.10, 0.08, 0.08);
		// Tear-off tabs: cuts through the bottom fifth every 38 px.
		float tabs = rect_size.y * 0.8;
		if (px.y > tabs && mod(px.x, 38.0) < 1.5) { alpha = 0.0; }
	} else if (stock == 2) {
		paper = vec3(0.95, 0.92, 0.84);
		ink_black = vec3(0.07, 0.06, 0.06);
		float edge = min(min(px.x, rect_size.x - px.x), min(px.y, rect_size.y - px.y));
		paper *= 0.9 + 0.1 * smoothstep(0.0, 6.0, edge);
	} else {
		ink_black = vec3(0.16, 0.16, 0.2);
		// Green bars every two print lines, white in between.
		float bar = step(0.5, fract(px.y / 48.0));
		paper = mix(vec3(0.96, 0.97, 0.94), vec3(0.83, 0.93, 0.83), bar);
		// Sprocket margins with punched holes.
		float margin = 26.0;
		if (px.x < margin || px.x > rect_size.x - margin) {
			paper = vec3(0.94, 0.95, 0.92);
			vec2 hole = vec2(px.x < margin ? margin * 0.5 : rect_size.x - margin * 0.5, (floor(px.y / 24.0) + 0.5) * 24.0);
			if (length(px - hole) < 5.0) { alpha = 0.0; }
			ink = 0.0;
		}
		// Perforation line down each margin.
		if (abs(px.x - margin) < 0.6 || abs(px.x - (rect_size.x - margin)) < 0.6) { paper *= 0.8; }
	}
	float printed = step(bayer4(cell / dot_size), ink * fade);
	vec3 ink_colour = sat > 0.35 ? ink_red : ink_black;
	COLOR = vec4(mix(paper, ink_colour, printed), alpha);
}
