class_name JumpClimb
extends RefCounted

## Greg, 26 September: "jump and climb everywhere". The drains had it first
## (SPACE out of the channel, "you can't jump out of here, it's dumb"); this is
## the same verb for every first-person scene, so a ledge answers SPACE the same
## way in the vat room, the Support Unit and the sewers.
##
## SPACE on the floor: if there is a ledge between knee and chin height just
## ahead, the body hauls itself onto it; otherwise it jumps. The mantle state
## lives on the body as metadata, so a scene needs no extra fields.
##
##   JumpClimb.press(player, yaw)            # on SPACE
##   if JumpClimb.busy(player): return       # top of the movement step
##   JumpClimb.fall(player, delta)           # instead of its own gravity line

const JUMP_SPEED := 5.2
## Highest ledge you can haul onto, from the soles of the feet.
const MANTLE_REACH := 1.55
const MANTLE_SECONDS := 0.4
const GRAVITY := 18.0
## Capsule centre above the soles when a body has no capsule to read.
const FEET_OFFSET := 0.85


static func busy(body: CharacterBody3D) -> bool:
	return body != null and bool(body.get_meta("mantling", false))


## Returns "climb", "jump" or "" (in the air, or already hauling up).
## `strength` scales the jump (a body just out of a tank jumps weakly).
static func press(body: CharacterBody3D, yaw: float, strength: float = 1.0, event_name: String = "player_climbed") -> String:
	if body == null or busy(body) or not body.is_on_floor():
		return ""
	var half := feet_offset(body)
	var feet := body.global_position.y - half
	var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var space := body.get_world_3d().direct_space_state
	# Look down onto whatever is just ahead, from above head height.
	for reach: float in [0.55, 0.8]:
		var top: Vector3 = body.global_position + forward * reach
		var query := PhysicsRayQueryParameters3D.create(Vector3(top.x, feet + 1.95, top.z), Vector3(top.x, feet + 0.15, top.z))
		query.exclude = [body.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var rise: float = (hit.position as Vector3).y - feet
		if rise < 0.2 or rise > MANTLE_REACH * clampf(strength, 0.5, 1.0):
			continue
		body.set_meta("mantling", true)
		body.velocity = Vector3.ZERO
		var land: Vector3 = (hit.position as Vector3) + Vector3(0, half + 0.02, 0) + forward * 0.1
		var tween := body.create_tween()
		tween.tween_property(body, "global_position", Vector3(body.global_position.x, land.y + 0.1, body.global_position.z), MANTLE_SECONDS * 0.6).set_ease(Tween.EASE_OUT)
		tween.tween_property(body, "global_position", land, MANTLE_SECONDS * 0.4)
		tween.tween_callback(func() -> void: body.set_meta("mantling", false))
		WorldHistory.record_event(event_name, {"rise": snappedf(rise, 0.01)})
		return "climb"
	body.velocity.y = JUMP_SPEED * clampf(strength, 0.4, 1.0)
	return "jump"


## Half the body's capsule: how far its centre sits above its soles.
static func feet_offset(body: CharacterBody3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and (child as CollisionShape3D).shape is CapsuleShape3D:
			return ((child as CollisionShape3D).shape as CapsuleShape3D).height * 0.5
	return FEET_OFFSET


## Gravity that lets a jump leave the ground: the old one-liner pinned
## velocity.y to -2 on the floor, which cancelled any jump the same frame.
static func fall(body: CharacterBody3D, delta: float) -> void:
	if body.is_on_floor() and body.velocity.y > 0.0:
		return
	body.velocity.y = -2.0 if body.is_on_floor() else body.velocity.y - GRAVITY * delta


static func is_jump_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE
