extends Node

## AB1.2. Proves `street_light.gd`'s full loop end to end: condition lives in
## `WorldHistory` through `world_damage.gd`, a hit moves the visible break
## state through the design doc's own four-stage ladder, glass sheds exactly
## once as real `world_debris.gd`-tracked wreckage, and none of it happens
## twice for the same crossing.

const STREET_LIGHT := preload("res://systems/street_light.gd")
const WORLD_DAMAGE := preload("res://systems/world_damage.gd")
const WORLD_DEBRIS := preload("res://systems/world_debris.gd")
const WORLD_LOOK := preload("res://systems/world_look.gd")

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
	WORLD_DEBRIS.clear_pool(STREET_LIGHT.DEBRIS_POOL)

	var light: StreetLight = STREET_LIGHT.new()
	add_child(light)
	light.build("street_light_9")
	await get_tree().physics_frame

	check(not WorldHistory.subject("street_light_9").is_empty(), "building the fixture registers a real WorldHistory subject")
	check(is_equal_approx(light.condition(), 1.0), "a fresh fixture reads fully intact")
	check(light.band() == "intact", "and the band agrees (\"%s\")" % light.band())
	check(light.get_node("Arm/Lamp").visible and light.get_node("Arm/Glass").visible, "an intact fixture shows a lit lamp and its glass")

	var grazed: Dictionary = light.strike(0.05, "grazed")
	check(bool(grazed.get("ok", false)) and light.band() == "intact", "a light graze does not cross out of intact")

	var dimmed: Dictionary = light.strike(0.35, "vehicle_impact")
	check(str(dimmed.get("band", "")) == "flickering" and bool(dimmed.get("crossed_band", false)), "a real hit crosses into flickering (\"%s\")" % str(dimmed.get("band", "")))
	check(light.get_node("Arm/Lamp").visible, "flickering still shows a (dimmer) lamp rather than going dark outright")

	var broken: Dictionary = light.strike(0.35, "vehicle_impact", Vector3.RIGHT)
	check(str(broken.get("band", "")) == "sparking", "a further hit crosses into sparking (\"%s\")" % str(broken.get("band", "")))
	check(not light.get_node("Arm/Lamp").visible and not light.get_node("Arm/Glass").visible, "sparking turns the lamp dark and hides its own glass mesh")
	await get_tree().physics_frame
	check(WORLD_DEBRIS.pool_count(STREET_LIGHT.DEBRIS_POOL) == 1, "the glass sheds as exactly one real debris piece")

	light.strike(0.05, "grazed")
	await get_tree().physics_frame
	check(WORLD_DEBRIS.pool_count(STREET_LIGHT.DEBRIS_POOL) == 1, "a further hit inside the same band does not shed a second piece")

	var overkill: Dictionary = light.strike(5.0, "explosion")
	check(str(overkill.get("band", "")) == "hanging" and is_equal_approx(light.condition(), 0.0), "overkill floors condition at zero and reads as hanging by its cable")
	await get_tree().physics_frame
	check(WORLD_DEBRIS.pool_count(STREET_LIGHT.DEBRIS_POOL) == 1, "skipping straight to the worst state still only ever sheds the one piece")
	check(not light.get_node("Arm").rotation.is_zero_approx(), "the fixture visibly droops rather than only reporting a number")

	var recent := WorldHistory.recent_events(10)
	check(recent.any(func(event): return str(event.get("type", "")) == "object_damaged" and str(event.get("details", {}).get("subject_id", "")) == "street_light_9"), "every hit is recorded in WorldHistory, not just mutated on the node")

	var slow_bump: Dictionary = light.impact(1.5, Vector3.FORWARD)
	check(not bool(slow_bump.get("ok", true)), "a slow vehicle graze through the impact() path does no damage")
	var second_light: StreetLight = STREET_LIGHT.new()
	add_child(second_light)
	second_light.build("street_light_10")
	var fast_hit: Dictionary = second_light.impact(9.0, Vector3.FORWARD)
	check(bool(fast_hit.get("ok", false)) and second_light.condition() < 1.0, "a real vehicle impact reaches the same struck path as a direct strike")

	WORLD_LOOK.set_quality_name("ULTRA")
	var ultra := STREET_LIGHT.debris_budget()
	WORLD_LOOK.set_quality_name("PERFORMANCE")
	var performance := STREET_LIGHT.debris_budget()
	check(performance < ultra and performance == STREET_LIGHT.MAX_DEBRIS_PERFORMANCE, "performance mode caps streetlight glass below ultra (%d vs %d)" % [performance, ultra])
	WORLD_LOOK.set_quality_name("HIGH")

	light.queue_free()
	second_light.queue_free()
	WORLD_DEBRIS.clear_pool(STREET_LIGHT.DEBRIS_POOL)
	print("STREET_LIGHT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
