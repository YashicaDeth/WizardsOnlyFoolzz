shader_type canvas_item;

// Greg, 28 September: inside the tank, the room seen through the medium and
// the glass: a slow wobble, a murky tint that darkens at the edges, faint
// light rippling through. `amount` fades it in and out with the tank; `panic`
// makes the wobble worse.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float panic : hint_range(0.0, 1.0) = 0.0;
uniform float blood : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float wobble = (0.004 + panic * 0.006) * amount;
	uv.x += sin(uv.y * 18.0 + TIME * 1.3) * wobble;
	uv.y += cos(uv.x * 14.0 + TIME * 1.1) * wobble * 0.8;
	vec3 room = textureLod(screen_tex, uv, 0.5 * amount).rgb;
	// The medium: amber-green murk, heavier at the edges of the glass.
	vec3 murk = mix(vec3(0.16, 0.22, 0.12), vec3(0.38, 0.03, 0.02), blood);
	float edge = smoothstep(0.35, 0.95, length((SCREEN_UV - 0.5) * vec2(1.3, 1.0)));
	vec3 seen = mix(room * vec3(0.9, 1.0, 0.85), murk, 0.18 + edge * 0.45);
	// Light rippling through the liquid.
	float caustic = sin(uv.x * 40.0 + TIME * 2.0) * sin(uv.y * 34.0 - TIME * 1.6);
	seen += vec3(0.05, 0.07, 0.04) * max(caustic, 0.0) * (1.0 - edge);
	COLOR = vec4(mix(room, seen, amount), amount);
}
