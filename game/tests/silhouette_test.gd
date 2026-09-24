extends Node

## Verifies the world generator produces dressed, settled building silhouettes
## and — since AB1.2 wired it in — real `StreetLight` fixtures at their lots.
## Runs as a scene rather than the bare `--script` `SceneTree` this file used
## to be: both `Silhouette.dress()` and `street_light.gd` read `WorldHistory`,
## an autoload that is only available inside the normal scene tree bootstrap,
## not under `--script`. See START_HERE.md on `validate_ashbloom.gd` for the
## same trap hit the same way.

const ASHBLOOM_WORLD_GENERATOR := preload("res://systems/ashbloom_world_generator.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	var generator: Node3D = ASHBLOOM_WORLD_GENERATOR.new()
	add_child(generator)
	generator.generate(774013)

	check(not generator.generated_buildings.is_empty(), "the world generator produces buildings")
	var first: Node3D = generator.generated_buildings[0]
	var mesh_count := 0
	for child in first.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	check(mesh_count >= 12, "a dressed building carries at least twelve meshes (%d)" % mesh_count)
	check(not first.rotation.is_zero_approx(), "a dressed building is settled off true rather than left standing plumb")

	var lights: Array[StreetLight] = []
	for child in generator.get_children():
		if child is StreetLight:
			lights.append(child)
	check(not lights.is_empty(), "AB1.2: the region actually contains real StreetLight fixtures, not just the class")
	if not lights.is_empty():
		var sample: StreetLight = lights[0]
		check(sample.band() == "intact", "a freshly generated streetlight reads intact through WorldHistory")
		check(not WorldHistory.subject(sample.subject_id).is_empty(), "each generated streetlight is its own real WorldHistory subject")

	print("SILHOUETTE_TEST_RESULT buildings=%d meshes=%d lights=%d failures=%d" % [generator.generated_buildings.size(), mesh_count, lights.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
