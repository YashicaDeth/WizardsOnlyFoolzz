extends Node

## MeshBudget caps primitive segment counts by size and never raises them, and
## the PerfProbe autoload applies it to every mesh that enters the tree.

const MESH_BUDGET := preload("res://systems/mesh_budget.gd")

var failures := 0


func _check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func _ready() -> void:
	var small := SphereMesh.new()
	small.radius = 0.05
	small.height = 0.1
	MESH_BUDGET.trim(small)
	_check(small.radial_segments < 64 and small.radial_segments >= MESH_BUDGET.RADIAL_MIN, "a knuckle-sized default sphere drops from 64 segments (%d)" % small.radial_segments)
	_check(small.rings <= small.radial_segments, "its rings drop with it (%d)" % small.rings)

	var big := CylinderMesh.new()
	big.top_radius = 2.0
	big.bottom_radius = 2.0
	MESH_BUDGET.trim(big)
	_check(big.radial_segments == MESH_BUDGET.RADIAL_MAX, "a tank-sized cylinder keeps the full cap (%d)" % big.radial_segments)

	var tuned := SphereMesh.new()
	tuned.radius = 1.0
	tuned.radial_segments = 8
	tuned.rings = 4
	MESH_BUDGET.trim(tuned)
	_check(tuned.radial_segments == 8 and tuned.rings == 4, "a mesh someone tuned low is never raised")

	var live := MeshInstance3D.new()
	var live_mesh := SphereMesh.new()
	live.mesh = live_mesh
	add_child(live)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(live_mesh.radial_segments < 64, "a mesh entering the tree is trimmed by the autoload hook (%d)" % live_mesh.radial_segments)

	print("MESH_BUDGET_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
