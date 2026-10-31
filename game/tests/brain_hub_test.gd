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
	event.physical_keycode = code
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
	# The footer used to print one generic hint under all five tabs, so nothing
	# on screen said that ENTER did anything until you had already pressed it.
	for tab_name in BrainIndexHub.TABS:
		hunt.brain_hub.tab = BrainIndexHub.TABS.find(tab_name)
		var line: String = hunt.brain_hub.footer_line()
		if tab_name in ["BRAIN INDEX", "TASKS", "MAP"]:
			check(line.contains("ENTER OPENS"), "the footer names the handover on %s (%s)" % [tab_name, line])
		else:
			check(not line.contains("ENTER OPENS"), "the footer promises no handover on %s" % tab_name)
	hunt.brain_hub.tab = BrainIndexHub.TABS.find("CARRY")
	var carry_footer: String = hunt.brain_hub.footer_line()
	hunt.brain_hub.tab = BrainIndexHub.TABS.find("TASKS")
	check(carry_footer != hunt.brain_hub.footer_line(), "the footer is not one line reused under every tab")
	# Slice 12. Every kind the carrying systems write has its own mark and its
	# own colour. The bag used to draw one grey box for keycards, patches,
	# implants and loose goods alike, so four different objects looked the same
	# and the mark carried no information at all.
	var families := {
		"meat": ["organ", "limb", "chunk", "meat", "muscle", "fat", "skin"],
		"pill": ["substance", "smokeable", "drug"],
		"chip": ["cybernetic", "implant"],
	}
	var sharing := {}
	for kind in BrainIndex.CARRY_MARKS:
		var mark: String = BrainIndex.carry_mark({"kind": str(kind)})
		check(mark != BrainIndex.UNKNOWN_MARK, "%s has a mark of its own" % kind)
		check(BrainIndexHub.KIND_TINT.has(kind), "%s has its own colour in the bag" % kind)
		sharing[mark] = (sharing.get(mark, []) as Array) + [str(kind)]
	for mark in sharing:
		var at_mark: Array = sharing[mark]
		if at_mark.size() == 1:
			continue
		check(families.has(mark) and (families[mark] as Array).size() == at_mark.size(),
			"only the kinds that are one object share the %s mark (%s)" % [mark, at_mark])
	check(BrainIndex.carry_mark({"kind": "skin", "skin": "dry_blood"}) == "paint"
		and BrainIndex.carry_mark({"kind": "skin", "zone": "left_arm"}) == "meat",
		"the one kind that names two objects is split by what the item carries")
	# And the tab draws that list rather than keeping a second table of its own.
	var bag: Array = hunt.brain_hub.carry.items.duplicate()
	hunt.brain_hub.carry.items.clear()
	hunt.brain_hub.carry.items.append({"label": "EXAMINER KEYCARD", "kind": "key", "mass": 0.05})
	hunt.brain_hub.carry.items.append({"label": "CLOTH PATCH", "kind": "patch", "mass": 0.1})
	hunt.brain_hub.carry.items.append({"label": "SOMEONE'S LIVER", "kind": "organ", "mass": 1.4})
	var drawn: Array[String] = hunt.brain_hub.carry_marks()
	check(drawn.size() == 3 and drawn[0] == "key" and drawn[1] == "patch" and drawn[2] == "meat",
		"the CARRY tab draws each thing as itself (%s)" % [drawn])
	hunt.brain_hub.carry.items = bag
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
	# Slice 13. F1 names the page of the index you are actually reading. The
	# unit test covers the empty case; this drives the real scene so the wiring
	# cannot rot silently while keys_card_test still passes.
	hunt.world_index.open()
	hunt.world_index.page = 2
	key(hunt, KEY_F1)
	check(hunt.keys_card.reading == "WIRE", "F1 names the index page being read (%s)" % hunt.keys_card.reading)
	key(hunt, KEY_F1)
	hunt.world_index.close()
	hunt.world_index.visible = false
	print("BRAIN_HUB_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
