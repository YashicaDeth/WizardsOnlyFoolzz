extends Node

## imp-67: on the real route (the production vat embedding the one-map
## facility) every zone facility.gd owns wears its own surface set, has a
## landmark and three to six story props, and adds no red outside danger.

const VAT := preload("res://vat_chamber.tscn")
const IDENTITY := preload("res://systems/facility_zone_identity.gd")
const ZONES := ["service_artery", "service_arcade", "transit_lift", "lower_works", "heat_lift"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var vat := VAT.instantiate()
	add_child(vat)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var facility: Node3D = vat.facility_map
	check(facility.identity != null, "the production route builds the zone identity")
	# Surfaces: every zone's own walls and floor wear its own set.
	var worn := {}
	for mesh: MeshInstance3D in facility.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as StandardMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var path := material.albedo_texture.resource_path
		if path.contains("/textures/facility/"):
			worn[path.get_file().get_slice("_", 0)] = true
	for zone: String in ZONES:
		for surface: String in IDENTITY.SURFACES[zone]:
			var set_name: String = IDENTITY.SURFACES[zone][surface][0]
			check(worn.has(set_name), "%s %s wears %s" % [zone, surface, set_name])
	check(IDENTITY.zone_at(Vector3(28, 0, -30)) != IDENTITY.zone_at(Vector3(28, -12, -100)), "the arcade and Lower Works are told apart")
	# Landmarks and story props, loaded from the CC0 files.
	var props := get_tree().get_nodes_in_group("facility_zone_identity")
	for zone: String in ZONES:
		var mine := props.filter(func(p: Node) -> bool: return p.get_meta("facility_zone", "") == zone)
		var landmarks := mine.filter(func(p: Node) -> bool: return p.get_meta("facility_story_prop", "") == "landmark")
		var heroes := mine.filter(func(p: Node) -> bool: return p.get_meta("facility_story_prop", "") == "hero")
		var story := heroes.size() + (1 if landmarks.size() > 0 else 0)
		check(landmarks.size() >= 1, "%s has a landmark" % zone)
		check(story >= 3 and story <= 6, "%s has 3-6 story props, not clutter (%d)" % [zone, story])
	var models := props.filter(func(p: Node) -> bool: return p.has_meta("facility_prop_source") and p.find_children("*", "MeshInstance3D", true, false).size() > 0)
	check(models.size() >= 15, "the Poly Haven props load with their meshes (%d)" % models.size())
	# The kit's generic drums and crates no longer repeat in both halls.
	var generic := get_tree().get_nodes_in_group("facility_story_props").filter(func(p: Node) -> bool:
		return ["drums", "crates", "pipes", "vent", "junction"].has(str(p.get_meta("facility_story_prop", ""))) \
			and ["service_arcade", "lower_works"].has(str(p.get_meta("facility_zone", ""))))
	check(generic.is_empty(), "the shared kit wall clutter is replaced by each hall's own set (%d left)" % generic.size())
	# Red only on danger: nothing this pass lights is red.
	var reds := 0
	for light: Light3D in facility.identity.find_children("*", "Light3D", true, false):
		if light.light_color.r > 0.5 and light.light_color.g < 0.25:
			reds += 1
	check(reds == 0, "no zone light is danger red")
	check(IDENTITY._flicker_level(5.4) < 0.2 and IDENTITY._flicker_level(1.0) > 0.8, "the stall sign fails and recovers")
	print("FACILITY_ZONE_IDENTITY_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
