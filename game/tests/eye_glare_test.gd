extends Node

const EyeGlare := preload("res://systems/eye_glare.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var glare := EyeGlare.new()
	add_child(glare)
	await get_tree().process_frame
	check(glare.material is ShaderMaterial, "the eye light is a shader layer, not a painted marker")
	var shader_material := glare.material as ShaderMaterial
	check(shader_material.get_shader_parameter("at") == EyeGlare.LEFT_EYE, "the glare starts at the measured left-eye coordinate")
	check(glare.z_index < 0, "the glare remains under the glass layer")
	glare.look_at_uv(Vector2(0.4, 0.3))
	check(shader_material.get_shader_parameter("at") == Vector2(0.4, 0.3), "its location can be corrected without changing the shader")
	glare.set_intensity(0.38)
	check(is_equal_approx(float(shader_material.get_shader_parameter("intensity")), 0.38), "intensity is independently tunable for a subtle bloom")
	glare.queue_free()
	print("EYE_GLARE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
