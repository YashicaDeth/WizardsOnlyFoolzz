class_name SecurityCamera
extends Node3D

## A CellOutz camera in the Support Unit's hallways (Greg, 24 September: "the
## cameras then film and track you"). His three answers for what a player can
## do about one:
##
## - **Sneak past it.** The cone is drawn in the world, lit on the floor, and
##   sweeps; a pillar between you and the lens breaks its sight.
## - **Break it.** Loud: the noise carries to anyone near, and it never films
##   anything again. The record keeps it broken after a death.
## - **Hack it**, later. Earned, not now: `hack()` is the hook and refuses.
##
## Seeing is not instant. The lens has to hold you for `LOCK_SECONDS` before it
## films you; until then the cone goes amber, which is the warning. Once it has
## you it turns red, stops sweeping and follows you, and the host's alarm hears
## `filmed`.
##
## The host drives it with one `step()` per frame and reads `sees()`.

signal filmed(camera: SecurityCamera, at: Vector3)
signal broke(camera: SecurityCamera, method: String)

const RANGE := 12.0
const HALF_ANGLE := deg_to_rad(19.0)
## How far below level the lens looks. The cone lands on the floor a few
## metres out, which is where the player reads it.
const PITCH := deg_to_rad(-24.0)
const SWEEP_SPEED := 0.42
const LOCK_SECONDS := 0.9
const FORGET_SECONDS := 2.5
const CALM := Color(0.55, 0.85, 1.0)
const WARY := Color(1.0, 0.72, 0.22)
const LOCKED := Color(1.0, 0.16, 0.10)
const LOOPED := Color(0.72, 0.25, 1.0)
const LOOP_SECONDS := 20.0
## How long the look has to be held on a lens to loop it.
const HACK_HOLD := 1.2

@export var camera_id := "support_camera"
## Yaw either side of the mount's facing that the sweep covers.
@export var sweep_half := deg_to_rad(38.0)

var broken := false
## 0 nothing, 1 filmed. Rises while the lens holds the player.
var lock := 0.0
var tracking := false
var looped_for := 0.0
var seen_player := false
var clock := 0.0
var head: Node3D
var lens: MeshInstance3D
var cone: MeshInstance3D
var cone_material: StandardMaterial3D
var lamp: SpotLight3D
var tally: OmniLight3D
var _lens_material: StandardMaterial3D
var _since_seen := 999.0
var _yaw := 0.0
var _exclude: Array[RID] = []


func build(id: String, phase := 0.0) -> void:
	camera_id = id
	clock = phase
	WorldHistory.register_subject(camera_id, {"kind": "camera", "state": "watching", "place": "support_unit"})
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.08, 0.45)
	arm_mesh.material = LabSurface.material("plate")
	arm.mesh = arm_mesh
	arm.position = Vector3(0, 0, -0.2)
	add_child(arm)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, -0.05, -0.42)
	add_child(head)
	var housing := StaticBody3D.new()
	housing.name = "Housing"
	housing.set_meta("security_camera", self)
	head.add_child(housing)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.24, 0.22, 0.46)
	body_mesh.material = WorldLook.surface(Color("2a2b2a"), "paint", 811)
	body.mesh = body_mesh
	housing.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.28, 0.5)
	shape.shape = box
	housing.add_child(shape)
	_exclude.append(housing.get_rid())
	lens = MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.07
	lens_mesh.bottom_radius = 0.07
	lens_mesh.height = 0.06
	var lens_material := StandardMaterial3D.new()
	lens_material.albedo_color = Color("0b0d10")
	lens_material.emission_enabled = true
	lens_material.emission = CALM
	lens_material.emission_energy_multiplier = 0.8
	lens_mesh.material = lens_material
	_lens_material = lens_material
	lens.mesh = lens_mesh
	lens.rotation.x = PI * 0.5
	lens.position = Vector3(0, 0, -0.24)
	head.add_child(lens)
	# The cone: a see-through wedge of light from the lens to its range. The
	# CylinderMesh is built along +y, so it is laid down the lens axis (-z).
	cone = MeshInstance3D.new()
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.02
	cone_mesh.bottom_radius = tan(HALF_ANGLE) * RANGE
	cone_mesh.height = RANGE
	cone_mesh.radial_segments = 24
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	cone_material = StandardMaterial3D.new()
	cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cone_material.albedo_color = Color(CALM, 0.14)
	cone_mesh.material = cone_material
	cone.mesh = cone_mesh
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.rotation.x = -PI * 0.5
	cone.position = Vector3(0, 0, -0.27 - RANGE * 0.5)
	head.add_child(cone)
	# And a real light down the same cone, so where it looks is lit on the
	# floor: that patch is what a sneaking player watches.
	lamp = SpotLight3D.new()
	lamp.light_color = CALM
	lamp.light_energy = 9.0
	lamp.spot_range = RANGE + 2.0
	lamp.spot_angle = rad_to_deg(HALF_ANGLE)
	lamp.spot_angle_attenuation = 0.6
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 0, -0.3)
	head.add_child(lamp)
	tally = OmniLight3D.new()
	tally.light_color = LOCKED
	tally.light_energy = 0.0
	tally.omni_range = 1.4
	tally.visible = false
	tally.position = Vector3(0, 0.16, -0.1)
	head.add_child(tally)
	head.rotation.x = PITCH
	if str(WorldHistory.subject(camera_id).get("state", "")) == "broken":
		_show_broken(false)


## Bodies the sight line passes through without being stopped (the host's own
## non-blocking props). The lens housing is already excluded.
func ignore(rid: RID) -> void:
	_exclude.append(rid)


## The lens's own position and look direction, in world space.
func eye() -> Vector3:
	return lens.global_position


func forward() -> Vector3:
	return -head.global_transform.basis.z


## Whether the lens can see `point` now: in range, inside the cone, and nothing
## solid in the way except `body` itself (the player being looked at).
func sees(point: Vector3, body: Object = null) -> bool:
	if broken or head == null or not is_inside_tree():
		return false
	var to := point - eye()
	var distance := to.length()
	if distance > RANGE or distance < 0.05:
		return false
	if forward().angle_to(to) > HALF_ANGLE:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye(), point)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == body


## One frame. `point` is the player's chest, `body` the player itself.
func step(delta: float, point: Vector3, body: Object = null, alarm := false) -> void:
	if broken:
		return
	clock += delta
	if looped_for > 0.0:
		# Playing back an empty corridor. It keeps sweeping so nobody watching
		# the feed notices, and it sees nothing.
		looped_for = maxf(0.0, looped_for - delta)
		_yaw = sin(clock * SWEEP_SPEED) * sweep_half
		head.rotation.y = _yaw
		var glitch := 0.5 + 0.5 * sin(clock * 31.0 + sin(clock * 7.0) * 3.0)
		cone_material.albedo_color = Color(LOOPED, 0.05 + 0.08 * glitch)
		lamp.light_color = LOOPED
		_lens_material.emission = LOOPED * (0.4 + glitch)
		tally.visible = false
		return
	var seeing := sees(point, body)
	if seeing:
		_since_seen = 0.0
		lock = minf(1.0, lock + delta / LOCK_SECONDS)
	else:
		_since_seen += delta
		if _since_seen > FORGET_SECONDS:
			lock = maxf(0.0, lock - delta * 0.6)
	if lock >= 1.0 and not tracking:
		tracking = true
		if not seen_player:
			seen_player = true
			WorldHistory.record_event("support_camera_saw_player", {"camera_id": camera_id, "place": "support_unit"})
		filmed.emit(self, point)
	if tracking and _since_seen > FORGET_SECONDS and not alarm:
		tracking = false
	# While it has you it follows you, head and all; otherwise it sweeps.
	if tracking and _since_seen < FORGET_SECONDS:
		var local := to_local(point)
		var target_yaw := clampf(atan2(-local.x, -local.z), -sweep_half - 0.4, sweep_half + 0.4)
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 5.0, 0.0, 1.0))
		var level := Vector2(local.x, local.z).length()
		head.rotation.x = lerpf(head.rotation.x, clampf(atan2(local.y + 0.05, level), -1.2, 0.3), clampf(delta * 5.0, 0.0, 1.0))
	else:
		_yaw = sin(clock * SWEEP_SPEED) * sweep_half
		head.rotation.x = lerpf(head.rotation.x, PITCH, clampf(delta * 2.0, 0.0, 1.0))
	head.rotation.y = _yaw
	_tint()


func _tint() -> void:
	var colour := CALM
	if tracking:
		colour = LOCKED
	elif lock > 0.0:
		colour = CALM.lerp(WARY, clampf(lock * 2.0, 0.0, 1.0))
	var blink := 0.5 + 0.5 * sin(clock * 18.0) if tracking else 1.0
	cone_material.albedo_color = Color(colour, 0.13 + 0.1 * lock * blink)
	lamp.light_color = colour
	_lens_material.emission = colour
	tally.light_energy = 2.5 * blink if tracking else 0.0
	tally.visible = tracking


## LMB with something heavy. Loud, final and recorded. `from` is where the
## blow came from, so the host can spread the noise.
func smash(method := "struck") -> bool:
	if broken:
		return false
	_show_broken(true)
	WorldHistory.update_subject(camera_id, {"state": "broken", "broken_by": method}, "support_camera_broken")
	broke.emit(self, method)
	return true


func _show_broken(fresh: bool) -> void:
	broken = true
	tracking = false
	lock = 0.0
	cone.visible = false
	lamp.visible = false
	tally.light_energy = 0.0
	_lens_material.emission = Color.BLACK
	# Hanging off its bracket, lens down.
	head.rotation = Vector3(-1.2, 0.5, 0.6)
	if fresh:
		var spark := OmniLight3D.new()
		spark.light_color = Color("fff0c0")
		spark.light_energy = 6.0
		spark.omni_range = 3.0
		head.add_child(spark)
		var fade := create_tween()
		fade.tween_property(spark, "light_energy", 0.0, 0.4)
		fade.tween_callback(spark.queue_free)


## The hack hook (Greg, 24 September: cameras can be "hacked later, earned,
## not now"). Nothing grants it yet; what the hack does is his to decide.
## Greg, 24 September: once earned, "look and hold" -- the rewritten implant
## loops the camera's footage for LOOP_SECONDS, a sigil glitch on its lens,
## and then it is back. Earned means the soul actually seized the chip in the
## breakout (`implant_seized` on the player record); a player who refused
## nothing in the examination does not get this.
static func hack_earned() -> bool:
	return bool(WorldHistory.subject("player").get("implant_seized", false))


func hack(by := "player") -> Dictionary:
	if broken:
		return {"accepted": false, "reason": "NOTHING LEFT TO LOOP"}
	if not hack_earned():
		return {"accepted": false, "reason": "NO INTERFACE // NOT YET EARNED"}
	looped_for = LOOP_SECONDS
	lock = 0.0
	tracking = false
	WorldHistory.record_event("support_camera_looped", {"camera_id": camera_id, "by": by, "seconds": LOOP_SECONDS})
	return {"accepted": true, "seconds": LOOP_SECONDS}


func is_looped() -> bool:
	return looped_for > 0.0


## The housing a raycast hit, as the camera it belongs to.
static func camera_of(collider: Object) -> SecurityCamera:
	if collider is Node and (collider as Node).has_meta("security_camera"):
		return (collider as Node).get_meta("security_camera") as SecurityCamera
	return null
