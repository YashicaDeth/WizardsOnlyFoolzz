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


# --- Greg, 26 September (question boxes): a crouch-slide, and small falls. ---

## Sprint + Ctrl: a burst forward that slows over about a second.
const SLIDE_SECONDS := 1.0
const SLIDE_SPEED := 7.0
## Falls hurt only past this drop, and never more than FALL_MAX blood.
const FALL_SAFE_METRES := 2.5
const FALL_MAX := 15.0


static func sliding(body: CharacterBody3D) -> bool:
	return body != null and float(body.get_meta("slide_left", 0.0)) > 0.0


## Starts a slide when the body is on the floor and sprinting. The direction
## is where it is already moving, or where it faces if it is barely moving.
static func try_slide(body: CharacterBody3D, yaw: float, sprinting: bool) -> bool:
	if body == null or busy(body) or sliding(body) or not sprinting or not body.is_on_floor():
		return false
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var along := flat.normalized() if flat.length() > 1.0 else Basis(Vector3.UP, yaw) * Vector3.FORWARD
	body.set_meta("slide_left", SLIDE_SECONDS)
	body.set_meta("slide_dir", along)
	WorldHistory.record_event("player_slid", {})
	return true


## While sliding the slide owns the body's horizontal speed; returns true
## so the host skips its own steering this frame.
static func slide_step(body: CharacterBody3D, delta: float) -> bool:
	if not sliding(body):
		return false
	var left := maxf(0.0, float(body.get_meta("slide_left", 0.0)) - delta)
	body.set_meta("slide_left", left)
	var along: Vector3 = body.get_meta("slide_dir", Vector3.FORWARD)
	var speed := SLIDE_SPEED * lerpf(0.35, 1.0, left / SLIDE_SECONDS)
	body.velocity.x = along.x * speed
	body.velocity.z = along.z * speed
	return true


## Call after move_and_slide. Tracks the fastest fall while airborne and, on
## landing, returns the blood it costs (0 for anything under 2.5 m).
static func landing_damage(body: CharacterBody3D) -> float:
	if body == null or busy(body):
		return 0.0
	if not body.is_on_floor():
		body.set_meta("fall_speed", maxf(float(body.get_meta("fall_speed", 0.0)), -body.velocity.y))
		return 0.0
	var speed := float(body.get_meta("fall_speed", 0.0))
	body.set_meta("fall_speed", 0.0)
	var drop := speed * speed / (2.0 * GRAVITY)
	if drop <= FALL_SAFE_METRES:
		return 0.0
	var hurt := clampf((drop - FALL_SAFE_METRES) * 6.0, 1.0, FALL_MAX)
	WorldHistory.record_event("player_fall_hurt", {"drop": snappedf(drop, 0.1), "blood": snappedf(hurt, 0.1)})
	return hurt
