extends Node

## Job 5 production wiring: the real opening owns the one player while the
## facility map supplies every internal corridor and lift. No room handoff is
## needed before the true surface boundary.

const VAT := preload("res://vat_chamber.tscn")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var scene_at_start := get_tree().current_scene
	var vat := VAT.instantiate()
	add_child(vat)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var facility: Node3D = vat.facility_map
	check(facility != null and bool(facility.embedded), "the production vat embeds the one-map facility")
	check(facility.player == vat.player and facility.camera == vat.camera, "the opening player and camera persist into the facility")
	check(facility.tunnels != null and facility.lifts.has("transit") and facility.lifts.has("heat"), "the service artery and both v0.1 lifts are live")
	check(not facility.lifts.has("doctor"), "the out-of-scope doctor branch is switched off")
	var props := get_tree().get_nodes_in_group("facility_story_props")
	var arcade_props := props.filter(func(prop: Node) -> bool: return prop.get_meta("facility_zone", "") == "service_arcade")
	var works_props := props.filter(func(prop: Node) -> bool: return prop.get_meta("facility_zone", "") == "lower_works")
	check(arcade_props.size() >= 40, "the Service Arcade has structural bays, tanks, cables and monitors")
	check(works_props.size() >= 20, "the Lower Works has machinery, hanging services and monitors")
	check(facility.get_tree().get_nodes_in_group("facility_story_props").any(func(prop: Node) -> bool: return prop.get_meta("facility_story_prop", "") == "route"), "a physical route stripe links the thresholds")
	check(str(facility.objective_for(Vector3(14, 0, -2.5))).contains("SERVICE ARCADE"), "0C names the next walkable threshold")
	check(str(facility.objective_for(Vector3(28, -12, -90))).contains("HEAT ELEVATOR"), "0D names the heat elevator")
	check(str(facility.objective_for(Vector3(28, 20, -130))).contains("SURFACE GATE"), "the surface objective names its door")
	check(str(facility.objective_for(Vector3(28, 2, -122))).contains("HEAT ELEVATOR"), "mid-ride in the heat shaft still names the heat elevator")
	check(str(facility.location_for(Vector3(28, -12, -90))).contains("LOWER WORKS"), "the body-cam stamp follows the player into 0D")
	check(str(facility.location_for(Vector3(28, 20, -130))).contains("SURFACE"), "the body-cam stamp reaches the surface")
	var lamps := 0
	for child in facility.get_children():
		if child is SpotLight3D and child.position.y > -12.0 and child.position.y < -6.0:
			lamps += 1
	check(lamps >= 10, "Lower Works lamps hang low enough to reach the floor (%d)" % lamps)
	vat._open_staff_door(false)
	check(vat.staff_door_open and vat.staff_door_panel.position.z > vat.STAFF_DOOR_AT.z + 1.0, "the east staff door physically clears the artery opening")
	var objective: Label = vat.get_node("HUD/Objective")
	check(objective.autowrap_mode != TextServer.AUTOWRAP_OFF and objective.anchor_left < 1.0, "the one objective line wraps inside a responsive screen region")
	check(get_tree().current_scene == scene_at_start and not Interstitial.travelling, "wiring the production map causes no scene change or interstitial")
	print("FACILITY_ONE_MAP_ROUTE_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
