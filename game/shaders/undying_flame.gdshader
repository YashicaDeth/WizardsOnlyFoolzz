shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

// A8.1. THE_REWORK §2: *"they see the essence of his spirit as it can't be
// banished by torturing, killing, violence — it stays in pure bright flames
// that are vibrant and melt the game's screen"*.
//
// The flame is drawn on the body, not over the frame. It is a `material_overlay`
// on the player's own zone meshes, so it follows every limb the anatomy system
// moves, is occluded by what occludes the player, comes apart with them when a
// limb does, and is absent from a frame the player is not in — none of which a
// screen overlay can do. That distinction is the whole segment: the spirit is a
// property of the body, and the one thing this game keeps saying about it is
// that it is still there when the body is not.
//
// Additive and unshaded on purpose. This is light leaving a person, so it does
// not take light, and it does not tint the flesh underneath: the zone material
// stays exactly what A5 made it and this burns on top.

uniform sampler2D flame_noise : repeat_enable, filter_linear;
// How hard the spirit is showing. Driven from the body's own condition, so a
// player who has been taken apart burns brighter than one who has not.
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec3 core : source_color = vec3(1.0, 0.93, 0.72);
uniform vec3 edge_color : source_color = vec3(1.0, 0.42, 0.12);
uniform float rise = 0.55;

varying vec3 local_position;
varying vec3 world_normal;


void vertex() {
	local_position = VERTEX;
	world_normal = NORMAL;
}


void fragment() {
	// Fresnel: brightest where the surface turns away, which is what makes a
	// body look like it is burning rather than painted. Without it the flame
	// sits flat on whatever face happens to point at the camera.
	float facing = 1.0 - clamp(abs(dot(normalize(world_normal), normalize(VIEW))), 0.0, 1.0);
	float limb = pow(facing, 2.1);

	// Two scrolls of one field, rising. The vertical rate differs from the
	// horizontal so the flame climbs rather than sliding sideways.
	vec2 slow = vec2(local_position.x * 1.9 + TIME * 0.06, local_position.y * 1.4 - TIME * rise);
	vec2 fast = vec2(local_position.z * 2.7 - TIME * 0.11, local_position.y * 2.2 - TIME * rise * 1.7);
	float body = texture(flame_noise, slow).r;
	float tongue = texture(flame_noise, fast).g;
	float fire = clamp(body * 0.65 + tongue * 0.75, 0.0, 1.0);

	// The tongues live at the silhouette; the core is a steady low burn over
	// the whole body, so a limb never goes completely dark between gusts.
	float burn = (0.18 + limb * 1.25) * fire * intensity;
	vec3 tint = mix(edge_color, core, clamp(limb * fire * 1.4, 0.0, 1.0));
	ALBEDO = tint * burn;
	ALPHA = 1.0;
}
