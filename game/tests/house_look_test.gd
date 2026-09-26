extends Node

## The house look (HouseLook autoload + shaders/dust_to_bones_look): it is on
## in every scene, below every HUD layer, and it picks the area's grade.

const SHADER := preload("res://shaders/dust_to_bones_look.gdshader")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var look = get_tree().root.get_node_or_null("HouseLook")
	check(look != null, "HouseLook is an autoload")
	check(look.layer < 0, "it draws below every HUD layer (%d)" % look.layer)
	check(look.rect.material is ShaderMaterial and (look.rect.material as ShaderMaterial).shader == SHADER, "it runs the Dust to Bones shader")
	check(look.rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and never eats a click")
	var uniforms := {}
	for entry in SHADER.get_shader_uniform_list():
		uniforms[str(entry.name)] = true
	var unknown: Array = []
	for key: String in look.GRADES:
		for parameter: String in look.grade_for(key):
			if not uniforms.has(parameter):
				unknown.append("%s.%s" % [key, parameter])
	check(unknown.is_empty(), "every grade sets real shader uniforms %s" % [unknown])
	WorldLook.environment("growing_floor")
	check(look.key_for_screen() == "growing_floor", "the vat room's preset picks its grade")
	WorldLook.environment("ossuary")
	check(look.key_for_screen() == "house", "an area with no grade of its own gets the house grade")
	var drains = load("res://old_drains.tscn").instantiate()
	add_child(drains)
	await get_tree().process_frame
	check(look.key_for_screen() == "old_drains", "a scene that shares a preset is still graded as itself")
	await get_tree().process_frame
	check(look.current_key == "old_drains", "and the grade follows the screen on its own")
	drains.queue_free()
	var growing: Dictionary = look.grade_for("growing_floor")
	check(float(growing.black_point) > float(look.BASE.black_point) and float(growing.pixel_size) == 2.0, "grades override the base and keep the rest")
	print("HOUSE_LOOK_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
