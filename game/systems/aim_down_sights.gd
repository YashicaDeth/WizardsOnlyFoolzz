class_name AimDownSights
extends RefCounted

## Greg, 4 October: "fix the aiming so we're actually aiming down a barrel ...
## and clicking the controller stick makes you scope further down the sight".
##
## The camera does not go looking for the gun. The eye stays where the body
## puts it (the first-person eye), and the held model is carried onto the
## camera's own line so its rear sight sits a stock-weld in front of the eye
## and its front sight lies on the same axis. That keeps the crosshair, the
## view and the round on one line: the round leaves along `line_direction`
## from `line_origin`, which is the line through both sights.
##
## Stage 1 is the shouldered sight. Stage 2 is "further down the sight": the
## eye closes on the rear sight and the field narrows again. L3 on the pad
## (PadBridge turns it into SHIFT) and SHIFT on the keyboard step between the
## two; letting go of the aim always comes back out to stage 1 next time.

## Where the sights are, in each built weapon's own authored space (muzzle
## along +Z, the convention `HeldGear.build_weapon` writes before its half
## turn). Used only when the model carries no `sight_rear` / `sight_front`
## marker of its own (models-03 adds those; they win when present).
const SIGHTS := {
	# Top of the rear notch and the front blade `HeldGear._build_sidearm` builds.
	"sidearm_model": [Vector3(0.0, 0.058, 0.010), Vector3(0.0, 0.0585, 0.178)],
	# The generated BREACH NINE has no modelled sights: its top line, measured
	# off the scaled model (bounds top 0.082, muzzle at z 0.111).
	"breach_nine_model": [Vector3(0.0, 0.080, -0.070), Vector3(0.0, 0.080, 0.111)],
	# Along the receiver top (0.035) to the muzzle; the barrel top (0.029)
	# falls away under the line, so the bore reads as a rib running out.
	"shotgun_model": [Vector3(0.0, 0.035, 0.0), Vector3(0.0, 0.035, 0.745)],
}
## Eye relief (metres from the rear sight back to the eye) and field of view,
## per stage. A pistol is held out at arm's length; a long gun is welded to
## the cheek, so its rear sight is almost at the eye.
##
## Fix-56 (Greg, 5 Oct: "the iron sights block the whole screen"): the pistol
## was pulled to 0.34 / 0.24 m, so its two grip hands, their cuffs and both
## sleeves filled the lower two thirds of the view. Out at a real two-hand
## extension (0.50 / 0.40 m) the sight picture is a small notch-and-post at
## the centre, as in a modern shooter, and the hands sit under it.
const STAGES := {
	"pistol": {"relief": [0.50, 0.40], "fov": [56.0, 44.0]},
	"long": {"relief": [0.13, 0.085], "fov": [54.0, 40.0]},
	"rifle": {"relief": [0.13, 0.085], "fov": [42.0, 20.0]},
}
const STAGE_RATE := 6.0
const KICK_DECAY := 9.0

var stage := 1
var deep_blend := 0.0
var kick := 0.0
## The aimed line, as of the last pose. World space.
var line_origin := Vector3.ZERO
var line_direction := Vector3.FORWARD
var has_line := false


static func weapon_class(weapon_id: String) -> String:
	match weapon_id:
		"shotgun": return "long"
		"sniper": return "rifle"
	return "pistol"


## L3 / SHIFT while aimed. Returns the stage now asked for.
func step_zoom() -> int:
	stage = 2 if stage == 1 else 1
	return stage


func reset() -> void:
	stage = 1


func add_kick(amount := 1.0) -> void:
	kick = minf(kick + amount, 1.6)


func advance(delta: float, aiming: bool) -> void:
	if not aiming:
		stage = 1
	deep_blend = move_toward(deep_blend, 1.0 if aiming and stage == 2 else 0.0, delta * STAGE_RATE)
	kick = move_toward(kick, 0.0, delta * KICK_DECAY * maxf(kick, 0.25))


func fov(weapon_id: String) -> float:
	var pair: Array = (STAGES[weapon_class(weapon_id)] as Dictionary).fov
	return lerpf(float(pair[0]), float(pair[1]), deep_blend)


func relief(weapon_id: String) -> float:
	var pair: Array = (STAGES[weapon_class(weapon_id)] as Dictionary).relief
	return lerpf(float(pair[0]), float(pair[1]), deep_blend)


## Mouse / stick look slows with the narrower field so the reticle keeps the
## same feel on screen at every stage.
static func look_scale(current_fov: float, base_fov: float) -> float:
	return clampf(tan(deg_to_rad(current_fov) * 0.5) / tan(deg_to_rad(base_fov) * 0.5), 0.15, 1.0)


## The built weapon inside a mount from `HunterArsenal._build_weapon_model`.
static func gear_of(mount: Node3D) -> Node3D:
	for child in mount.get_children():
		if child is Node3D and str(child.name).ends_with("_model"):
			return child as Node3D
	return null


## Rear and front sight, in the mount's local space.
static func sight_points(mount: Node3D) -> Array:
	var rear := mount.find_child("sight_rear", true, false) as Node3D
	var front := mount.find_child("sight_front", true, false) as Node3D
	if rear == null or front == null:
		rear = mount.find_child("anchor_sight_rear", true, false) as Node3D
		front = mount.find_child("anchor_sight_front", true, false) as Node3D
	var to_mount := mount.global_transform.affine_inverse()
	if rear != null and front != null and rear.is_inside_tree():
		return [to_mount * rear.global_position, to_mount * front.global_position]
	var gear := gear_of(mount)
	if gear == null:
		return []
	var local: Transform3D = gear.transform
	if SIGHTS.has(str(gear.name)):
		var pair: Array = SIGHTS[str(gear.name)]
		return [local * (pair[0] as Vector3), local * (pair[1] as Vector3)]
	# Anything else: sight along the top of the model, parallel to its bore.
	var box := _local_bounds(gear, Transform3D.IDENTITY)
	if box.size == Vector3.ZERO:
		return []
	var top := box.position.y + box.size.y
	var mid := box.position.x + box.size.x * 0.5
	return [local * Vector3(mid, top, box.position.z + box.size.z * 0.35), local * Vector3(mid, top, box.position.z + box.size.z)]


static func _local_bounds(node: Node3D, to_root: Transform3D) -> AABB:
	var box := AABB()
	var started := false
	for child in node.get_children():
		if not child is Node3D or str(child.name).begins_with("anchor_"):
			continue
		var child_transform: Transform3D = to_root * (child as Node3D).transform
		var part := AABB()
		if child is VisualInstance3D:
			part = child_transform * (child as VisualInstance3D).get_aabb()
		var below := _local_bounds(child as Node3D, child_transform)
		if below.size != Vector3.ZERO:
			part = below if part.size == Vector3.ZERO else part.merge(below)
		if part.size == Vector3.ZERO:
			continue
		box = part if not started else box.merge(part)
		started = true
	return box


## The global transform that puts the mount's rear sight `relief` metres in
## front of the eye with its front sight on the camera's forward axis, the
## weapon upright in the view.
func sight_transform(mount: Node3D, view: Transform3D, eye_relief: float) -> Transform3D:
	var points := sight_points(mount)
	if points.size() < 2:
		return mount.global_transform
	var rear: Vector3 = points[0]
	var bore: Vector3 = (points[1] as Vector3) - rear
	if bore.length_squared() < 0.000001:
		return mount.global_transform
	var gear := gear_of(mount)
	var up_hint: Vector3 = gear.transform.basis * Vector3.UP if gear != null else Vector3.UP
	var z_axis := -bore.normalized()
	var x_axis := up_hint.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	var weapon_frame := Basis(x_axis, y_axis, z_axis)
	var view_basis := view.basis.orthonormalized()
	var basis := view_basis * weapon_frame.transposed()
	var rear_target := view.origin - view_basis.z * eye_relief
	return Transform3D(basis, rear_target - basis * rear)


## Carry `mount` from wherever the hand put it (`hip`, sway included) onto
## the sight line by `blend`. `sway` is the hand's own lag in world space; a
## shouldered weapon keeps a little of it. Records the aimed line.
func pose(mount: Node3D, view: Transform3D, weapon_id: String, blend: float, sway := Vector3.ZERO) -> void:
	if mount == null or not is_instance_valid(mount) or not mount.is_inside_tree():
		has_line = false
		return
	var hip := mount.global_transform
	var aimed := sight_transform(mount, view, relief(weapon_id) + kick * 0.035)
	# Muzzle climb: a pitch about the rear sight, then let back down.
	if kick > 0.0:
		var points := sight_points(mount)
		if points.size() >= 2:
			var pivot: Vector3 = aimed * (points[0] as Vector3)
			var climb := Basis(view.basis.x.normalized(), kick * 0.045)
			aimed = Transform3D(climb * aimed.basis, pivot + climb * (aimed.origin - pivot))
	aimed.origin += sway * 0.22
	if blend > 0.0:
		mount.global_transform = hip.interpolate_with(aimed, clampf(blend, 0.0, 1.0))
	var points_now := sight_points(mount)
	if points_now.size() >= 2:
		var rear_world: Vector3 = mount.global_transform * (points_now[0] as Vector3)
		var front_world: Vector3 = mount.global_transform * (points_now[1] as Vector3)
		line_direction = (front_world - rear_world).normalized()
		line_origin = rear_world
		has_line = true
	else:
		has_line = false
