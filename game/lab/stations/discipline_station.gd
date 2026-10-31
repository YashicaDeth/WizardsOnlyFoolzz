extends Node3D

## Backlog mechanics-lab station: Duelist and Shade are deliberately isolated
## here until Greg chooses whether either belongs in the facility route.

const TITLE := "DISCIPLINES"
const VERB := "DUELIST / SHADE"
const BODIES := preload("res://lab/stations/bodies_station.gd")
const THROWABLE := preload("res://systems/shade_throwable.gd")

## Sensible defaults kept together as dials (DESIGN/REMASTER_LOG.md).
const DIALS := {
	"riposte_seconds": 1.0,
	"riposte_damage": 2.0,
	"takedown_range": 2.15,
	"behind_dot": -0.55,
	"darkness_seconds": 8.0,
	"throw_speed": 13.0,
}

var lab: Node3D
var active := "off"
var target: BaselineHuman
var target_holder: Node3D
var booth_light: OmniLight3D
var darkness_left := 0.0
var riposte_left := 0.0
var riposte_target: BaselineHuman
var takedowns := 0
var throws := 0
var throwable_hits := 0
var refused_takedowns := 0


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	_build_booth()
	_spawn_target()


func press() -> String:
	activate("duelist" if active == "off" else ("shade" if active == "duelist" else "off"))
	return "DISCIPLINE %s" % active.to_upper()


func activate(id: String) -> void:
	active = id if id in ["duelist", "shade"] else "off"
	darkness_left = 0.0
	booth_light.light_energy = 2.4
	if lab != null and lab.has_method("_discipline_changed"):
		lab.call("_discipline_changed", active)


func status() -> String:
	return "%s  TAKEDOWNS %d  THROWS %d/%d" % [active.to_upper(), takedowns, throwable_hits, throws]


func _process(delta: float) -> void:
	riposte_left = maxf(0.0, riposte_left - delta)
	if riposte_left <= 0.0:
		riposte_target = null
	if darkness_left > 0.0:
		darkness_left = maxf(0.0, darkness_left - delta)
		booth_light.light_energy = 0.05
	elif booth_light != null:
		booth_light.light_energy = 2.4
	if target == null or not is_instance_valid(target) or target.anatomy.dead:
		_spawn_target()


func open_riposte(rig: BaselineHuman) -> void:
	if active != "duelist" or rig == null:
		return
	riposte_target = rig
	riposte_left = float(DIALS.riposte_seconds)


func modify_melee(packet: Dictionary, rig: BaselineHuman) -> Dictionary:
	var result := packet.duplicate(true)
	if active == "duelist" and riposte_left > 0.0 and rig == riposte_target:
		result.damage = float(result.get("damage", 0.0)) * float(DIALS.riposte_damage)
		result.impulse = float(result.get("impulse", 0.0)) * 1.25
		result["riposte"] = true
		riposte_left = 0.0
		riposte_target = null
	return result


func takedown() -> Dictionary:
	if active != "shade" or target == null or not is_instance_valid(target):
		return {"accepted": false, "reason": "discipline"}
	var to_player: Vector3 = lab.player.global_position - target.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var forward := -target.global_basis.z
	forward.y = 0.0
	var behind := distance > 0.001 and forward.normalized().dot(to_player.normalized()) <= float(DIALS.behind_dot)
	if distance > float(DIALS.takedown_range) or not behind:
		refused_takedowns += 1
		return {"accepted": false, "reason": "behind" if distance <= float(DIALS.takedown_range) else "range"}
	var head := target.parts.get("head") as Node3D
	var at := head.global_position if head != null else target.global_position + Vector3.UP * 1.5
	var report := target.hit_at(at, 120.0, 18.0, "blunt", forward)
	takedowns += 1
	report["accepted"] = true
	report["takedown"] = true
	return report


func toggle_darkness() -> bool:
	if active != "shade":
		return false
	darkness_left = 0.0 if darkness_left > 0.0 else float(DIALS.darkness_seconds)
	booth_light.light_energy = 0.05 if darkness_left > 0.0 else 2.4
	return darkness_left > 0.0


func throw_from(origin: Vector3, direction: Vector3):
	if active != "shade":
		return null
	# Keep this preload-local so a fresh worktree does not need the generated
	# global class cache before the station can parse.
	var thrown = THROWABLE.new()
	thrown.name = "ShadeThrowable%d" % throws
	lab.add_child(thrown)
	thrown.launch(origin, direction, float(DIALS.throw_speed))
	thrown.impacted.connect(func(_body: Object, report: Dictionary) -> void:
		if bool(report.get("hit", false)):
			throwable_hits += 1)
	throws += 1
	return thrown


func throw_from_camera():
	return throw_from(lab.camera.global_position - lab.camera.global_basis.z * 0.35, -lab.camera.global_basis.z)


func _spawn_target() -> void:
	if target_holder != null and is_instance_valid(target_holder):
		target_holder.queue_free()
	target = BODIES.dummy(self, "shade_target_%d" % Time.get_ticks_msec(), Vector3(0, 0, -3.4), PI, 6)
	target_holder = target.get_parent() as Node3D


func _build_booth() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("15171b")
	dark.roughness = 0.9
	for spec in [
		[Vector3(6.0, 0.12, 5.0), Vector3(0, 0.02, -2.6)],
		[Vector3(6.0, 0.15, 5.0), Vector3(0, 3.0, -2.6)],
		[Vector3(0.15, 3.0, 5.0), Vector3(-3.0, 1.5, -2.6)],
		[Vector3(0.15, 3.0, 5.0), Vector3(3.0, 1.5, -2.6)],
	]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[0]
		box.material = dark
		mesh.mesh = box
		mesh.position = spec[1]
		add_child(mesh)
	booth_light = OmniLight3D.new()
	booth_light.position = Vector3(0, 2.4, -2.8)
	booth_light.light_color = Color("94a9b4")
	booth_light.light_energy = 2.4
	booth_light.omni_range = 6.0
	add_child(booth_light)
