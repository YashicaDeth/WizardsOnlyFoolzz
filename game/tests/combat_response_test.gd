extends Node

const RESPONSE := preload("res://systems/combat_response.gd")
const ANATOMY := preload("res://systems/anatomy_component.gd")

var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition: failures.append(label)

func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var healthy := ANATOMY.new()
	healthy.configure("healthy")
	var light := RESPONSE.from_hit({"impulse": 8.0}, healthy, {"pain": 4.0})
	check(not bool(light.staggered), "a light touch does not stunlock a healthy fighter")
	var heavy := RESPONSE.from_hit({"impulse": 28.0, "heavy": true}, healthy, {"pain": 22.0})
	check(bool(heavy.staggered) and bool(heavy.interrupts_attack), "a committed heavy blow interrupts a windup")
	var wounded := ANATOMY.new()
	wounded.configure("wounded")
	wounded.zones.left_leg.health = 0.0
	wounded.zones.right_arm.health = 5.0
	var same_force := RESPONSE.from_hit({"impulse": 20.0}, wounded, {"pain": 55.0})
	check(bool(same_force.staggered), "lasting limb damage changes resistance to interruption")
	check(float(same_force.duration) > 0.0 and float(same_force.duration) <= 1.05, "recovery is readable but bounded")
	print("COMBAT_RESPONSE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
