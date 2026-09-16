extends Node

## Smoking organ/UI seam: the body owns the stain, the contextual X-ray reads
## it, and the top-right player instrument reveals only resources that exist.

const HUD := preload("res://systems/gothic_field_hud.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var anatomy := AnatomyComponent.new()
	add_child(anatomy)
	anatomy.configure("player")
	var clean := anatomy.inhale_smoke(1.1, 0.0, "cigarette")
	check(float(clean.stain) > 0.0, "a clean cigarette draw leaves a small real lung stain")
	var health_after_clean := float(clean.health)
	var harsh := anatomy.inhale_smoke(1.1, 1.0, "cigarette")
	check(float(harsh.health) < health_after_clean, "a harsh draw costs more lung tissue")
	check(float(harsh.stain) > float(clean.stain), "and darkens the same organs further")

	var saved := anatomy.snapshot()
	var restored := AnatomyComponent.new()
	add_child(restored)
	restored.configure("restored")
	restored.restore(saved)
	check(is_equal_approx(float(restored.lung_state().stain), float(harsh.stain)), "lung darkness survives a body save and restore")
	restored.replace_organ("left_lung", {"id": "clean_graft"})
	check(float((restored.organs.left_lung as Dictionary).smoke_stain) == 0.0, "replacing a lung clears that organ's accumulated stain")
	check(float(restored.lung_state().stain) < float(harsh.stain), "the X-ray immediately reads the replacement rather than an old meter")

	var hud := HUD.new()
	add_child(hud)
	hud.set_state({
		"blood": 0.62, "stamina": 18.0, "pain": 12.0, "consciousness": 90.0,
		"smoking": true, "lung_fill": 0.72, "lung_cough": 0.8,
		"lung_health": float(harsh.health), "lung_stain": float(harsh.stain),
		"magick_unlocked": false, "magick": 0.9,
	})
	check(hud.lung_linger > 0.0 and hud.lung_fill > 0.7, "using the lungs opens a contextual lower-left X-ray")
	check(hud.mood_name() == "CHOKING", "the top-right face reports the body's acute emotion")
	check(not hud.magick_unlocked, "magick has no empty locked bar before it exists")
	hud.set_state({"lung_cough": 0.0, "smoking": false, "stamina": 12.0, "magick_unlocked": true, "magick": 0.45})
	check(hud.mood_name() == "WINDED", "the portrait changes with the next strongest live body state")
	check(hud.magick_unlocked and is_equal_approx(hud.magick, 0.45), "working a ritual reveals the magick fluid reservoir")

	print("SMOKING_LUNG_UI_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
