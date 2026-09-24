shader_type canvas_item;

// Full-screen colour split and tearing, for the moment the doctor turns out
// to be light. `amount` is driven up at the reveal and eased back to zero.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 18.0);
	float row = floor(uv.y * 40.0);
	float tear = step(0.86, hash(row + tick * 3.1)) * (hash(row * 1.7 + tick) - 0.5) * 0.08 * amount;
	uv.x += tear;
	float offset = 0.012 * amount;
	float red = texture(screen_tex, uv + vec2(offset, 0.0)).r;
	float green = texture(screen_tex, uv).g;
	float blue = texture(screen_tex, uv - vec2(offset, 0.0)).b;
	vec3 colour = vec3(red, green, blue);
	float scan = 0.92 + 0.08 * sin(SCREEN_UV.y * 900.0);
	colour = mix(colour, colour * scan + vec3(0.0, 0.05, 0.07), amount);
	COLOR = vec4(colour, 1.0);
}
