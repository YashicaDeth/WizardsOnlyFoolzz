extends Node3D

## Station 4: a row of dummies for cuts, severing, ragdoll and the X-ray.
## The same `BaselineHuman` the Hunt and the sandbox use, with the death
## ragdoll on (`RagdollBody`) and the world's own look (`HunterAppearance`).
## The button turns the X-ray (`WorldXray`) on and off; a dummy that has died
## stands back up in its place after `RESPAWN_SECONDS`.

const TITLE := "BODIES"
const VERB := "X-RAY ON / OFF"
const COUNT := 4
const SPACING := 1.8
const RESPAWN_SECONDS := 25.0

var lab: Node3D
var rows: Array[Dictionary] = []
var xray := false


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	for index in COUNT:
		rows.append({"rig": null, "dead_for": 0.0})
		_spawn(index)


## A standing dummy at `at` (feet), turned to `facing`, with gore on whatever
## the world setting says. Shared with the weather station's acid dummies.
static func dummy(parent: Node3D, id: String, at: Vector3, facing: float, variation := 0) -> BaselineHuman:
	var holder := Node3D.new()
	holder.name = id
	parent.add_child(holder)
	holder.position = at + Vector3(0, 0.9, 0)
	holder.rotation.y = facing
	var rig := BaselineHuman.new()
	rig.name = "Rig"
	holder.add_child(rig)
	rig.position = Vector3(0, -0.9, 0)
	rig.build(id, {
		"flesh": Color("70201c") if variation % 2 == 0 else Color("586c3a"),
		"variation": variation * 13 + 5,
		"gore": BaselineHuman.apply_gore_setting(),
		"blood": 4300.0,
		"knockdown_travel": 0.42,
		"ragdoll": true,
	})
	HunterAppearance.style_world_rig(rig, id, false)
	return rig


func rigs() -> Array:
	var out: Array = []
	for row in rows:
		if row.rig != null and is_instance_valid(row.rig):
			out.append(row.rig)
	return out


func press() -> String:
	xray = not xray
	_sweep()
	return "X-RAY %s" % ("ON" if xray else "OFF")


func status() -> String:
	var standing := 0
	for rig: BaselineHuman in rigs():
		if not rig.anatomy.dead and not rig.anatomy.downed:
			standing += 1
	return "STANDING %d/%d   X-RAY %s" % [standing, COUNT, "ON" if xray else "OFF"]


func _process(delta: float) -> void:
	for index in rows.size():
		var rig := rows[index].rig as BaselineHuman
		if rig == null or not is_instance_valid(rig) or not rig.anatomy.dead:
			rows[index].dead_for = 0.0
			continue
		rows[index].dead_for = float(rows[index].dead_for) + delta
		if float(rows[index].dead_for) >= RESPAWN_SECONDS:
			_spawn(index)
	if xray:
		_sweep()


func _sweep() -> void:
	var from: Vector3 = lab.player.global_position if lab != null and lab.get("player") != null else global_position
	WorldXray.sweep(from, rigs(), xray)


func _spawn(index: int) -> void:
	var old := rows[index].rig as BaselineHuman
	if old != null and is_instance_valid(old):
		# The holder carries the rig and, once dead, its ragdoll.
		old.get_parent().queue_free()
	var at := Vector3((float(index) - float(COUNT - 1) * 0.5) * SPACING, 0, -1.6)
	rows[index].rig = dummy(self, "lab_dummy_%d_%d" % [index, Time.get_ticks_msec()], at, PI, index)
	rows[index].dead_for = 0.0
