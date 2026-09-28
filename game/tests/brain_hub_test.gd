extends Node

## The Brain Index hub (Greg, 2026-09-24): Tab opens it over the Hunt, its
## tabs cycle in his order, and TASKS / MAP hand over to the real surfaces.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(hunt, code: int, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	hunt._unhandled_input(event)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 5:
		await get_tree().physics_frame
	# N4.5: a wound taken just now shows on the body in the vat.
	hunt.player_rig.anatomy.apply_hit("left_arm", 40.0, 0.0, "slash")
	var hurt: float = hunt.player_rig.zone_health("left_arm")
	# Greg, 26 September: the inventory is on Tab; the hub moved to Shift+Tab.
	key(hunt, KEY_TAB, true)
	check(hunt.panel_mode == "hub" and hunt.brain_hub.visible, "Shift+Tab opens the Brain Index hub")
	check(BrainIndexHub.TABS == ["CARRY", "COMBAT", "BRAIN INDEX", "TASKS", "MAP"] and hunt.brain_hub.tab == 0, "tabs in Greg's order, opening on CARRY")
	var hub_rig: BaselineHuman = hunt.brain_hub.body.rig
	check(hub_rig.zone_health("left_arm") <= hurt + 0.5 and hurt < 60.0, "the arm you were just cut on is hurt on the body in the vat (%.0f, %.0f)" % [hub_rig.zone_health("left_arm"), hurt])
	var hub_arm: Node3D = hunt.brain_hub.body.rig.parts.get("right_arm")
	check(hub_arm != null and hub_arm.get_node_or_null("HeldWeapon") != null, "the body in the vat holds the weapon you have out")
	key(hunt, KEY_RIGHT)
	check(hunt.brain_hub.tab == 1, "arrows move between tabs")
	hunt.brain_hub.tab = BrainIndexHub.TABS.find("MAP")
	key(hunt, KEY_ENTER)
	check(hunt.panel_mode == "map" and not hunt.brain_hub.visible, "the MAP tab hands over to the satellite map")
	key(hunt, KEY_TAB, true)
	check(hunt.panel_mode == "hub", "Shift+Tab from the map comes back to the hub")
	# Photo mode's pictures live behind the BRAIN INDEX tab.
	PhotoAlbum.dir = "user://photo_hub_test/"
	for old in PhotoAlbum.list():
		DirAccess.remove_absolute(str(old.path))
	var print_image := Image.create(64, 36, false, Image.FORMAT_RGB8)
	print_image.fill(Color(0.6, 0.2, 0.2))
	PhotoAlbum.save(print_image, {"caption": "HUB TEST"})
	hunt.brain_hub.tab = BrainIndexHub.TABS.find("BRAIN INDEX")
	key(hunt, KEY_ENTER)
	check(hunt.brain_hub.album.visible and hunt.brain_hub.album.photos.size() == 1, "Enter on BRAIN INDEX opens the photo album with the photo in it")
	key(hunt, KEY_ESCAPE)
	check(not hunt.brain_hub.album.visible and hunt.brain_hub.visible, "Escape puts the album away and leaves the hub open")
	key(hunt, KEY_TAB)
	check(hunt.panel_mode == "" and not hunt.brain_hub.visible, "and Tab again closes it")
	print("BRAIN_HUB_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
