extends Node

## AG5.30. Loot is reachable as inventory without navigating the surveillance
## phone, and selection operates on the exact shared Carry object.
##
## Slices 17-19 (DESIGN/AGENT_SPLIT_49). The bag is a board now: weapons and
## carried things occupy slots in reading order, a 2D cursor and the mouse move
## over them, and a slot answers with the verb its own kind has — wield a racked
## weapon, take up a whole limb, fit an organ, bolt in hardware. Every one of
## those must leave the live Carry / arsenal / anatomy changed and nothing
## copied into a second list.

const FIELD_INVENTORY := preload("res://systems/field_inventory.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func click_event(at: Vector2, double := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.double_click = double
	event.position = at
	return event


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	# `field_inventory` hangs off a CanvasLayer, so its anchors resolve against
	# the viewport rather than a parent Control. Headless starts that viewport at
	# the 64 px minimum; the capture fixtures set the window for the same reason.
	get_window().size = Vector2i(1280, 720)
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	hunt.set_physics_process(false)
	await get_tree().physics_frame
	for _frame in 3:
		await get_tree().process_frame
	var carry: Carry = hunt.handheld.carry
	var panel: FieldInventory = hunt.field_inventory
	carry.take_chunk({"layer_name": "skin", "zone": "torso", "subject_id": "inventory_probe"})
	carry.take_chunk({"layer_name": "limb", "whole_limb": true, "zone": "left_arm", "subject_id": "inventory_probe"})

	print("AG5.30 - O reaches the actual bag without raising the phone")
	hunt._unhandled_input(key(KEY_O))
	check(hunt.panel_mode == "inventory" and panel.visible, "O opens the direct field inventory")
	check(not hunt.handheld.is_open, "the Black Mirror stays pocketed")
	check(panel.carry == hunt.handheld.carry, "field and phone expose the same Carry instance")
	check(panel.body == hunt.player_rig and panel.arsenal == hunt.arsenal, "the screen reads the live body and weapons rather than copied display data")
	# The same trap that made `hud_transience_test` pass on a 0x0 screen: a bare
	# Control under a plain Node measures nothing, and every rect comparison
	# below would be free. Prove the board has a real screen first.
	check(panel.size.x > 600.0 and panel.size.y > 300.0, "the board is measured on a real screen (%dx%d)" % [roundi(panel.size.x), roundi(panel.size.y)])

	print("AG5.31 - the inventory head opens the one real Wetwire index")
	panel.handle_input(key(KEY_B))
	check(panel.zoom >= 0.0 and not panel.brain_index_open, "B first zooms into the skull")
	panel._process(panel.ZOOM_SECONDS + 0.05)
	check(panel.visible and panel.brain_index_open, "B on the inventory head opens the built-in Wetwire Brain Index")
	check(not hunt.handheld.is_open, "the brain remains reachable even when the handheld is not raised")
	panel.handle_input(key(KEY_B))
	check(not panel.brain_index_open, "the same head control returns to the live body inventory")

	print("Slice 17 - the bag is a board of slots, not a list")
	var weapons: Array[String] = panel.weapon_slots()
	check(weapons.size() >= 3, "the issued weapons have slots (%d)" % weapons.size())
	check(panel.slot_count() == weapons.size() + carry.items.size(), "a slot exists for every racked weapon and every carried thing (%d)" % panel.slot_count())
	check(str(panel.slot_entry(0).get("source", "")) == "weapon", "the rack leads the board")
	var first_bag := panel.slot_for_bag(0)
	check(str(panel.slot_entry(first_bag).get("source", "")) == "bag", "and the bag follows it (first bag slot %d)" % first_bag)
	check(int(panel.slot_entry(first_bag).get("item_index", -1)) == 0 and str(panel.slot_entry(first_bag).get("label", "")) == "SKIN (TORSO)", "slot %d is the exact first carried object" % first_bag)

	var rect: Rect2 = panel.bag_rect()
	check(rect.size.x > 200.0 and rect.size.y > 200.0, "the bag compartment measures %0.0fx%0.0f" % [rect.size.x, rect.size.y])
	var layout := panel.grid_layout(rect)
	var columns := int(layout.columns)
	var rows := int(layout.rows)
	check(columns >= 2 and rows >= 2, "%d columns x %d rows fall out of the compartment" % [columns, rows])
	var a := panel.slot_rect_in(rect, 0)
	var b := panel.slot_rect_in(rect, 1)
	check(a.size.x > 40.0 and a.size.y > 40.0, "a cell is big enough to hold a name and a number (%0.0fx%0.0f)" % [a.size.x, a.size.y])
	check(is_equal_approx(a.position.y, b.position.y) and b.position.x > a.position.x, "the first two slots share a row, left to right")
	var next_row := panel.slot_rect_in(rect, columns)
	check(next_row.position.y > a.position.y and is_equal_approx(next_row.position.x, a.position.x), "slot %d starts the next row under slot 0" % columns)
	check(rect.encloses(a) and rect.encloses(next_row), "and neither cell runs out of the compartment")
	var hits := panel.visible_slot_rects(rect)
	check(hits.size() == mini(panel.slot_count(), columns * rows), "every occupied slot on this page has a hit area (%d)" % hits.size())

	panel.selected = 0
	panel.handle_input(key(KEY_RIGHT))
	check(panel.selected == 1, "right crosses to the next slot")
	panel.handle_input(key(KEY_LEFT))
	check(panel.selected == 0, "left comes back")
	panel.handle_input(key(KEY_DOWN))
	check(panel.selected == columns, "down moves a whole row (%d)" % panel.selected)
	panel.handle_input(key(KEY_UP))
	check(panel.selected == 0, "and up returns")
	panel.selected = panel.slot_count() - 1
	panel.handle_input(key(KEY_RIGHT))
	check(panel.selected == panel.slot_count() - 1, "the last slot holds instead of wrapping to the first")

	var limb_slot := panel.slot_for_bag(1)
	panel.selected = 0
	panel.handle_input(click_event(panel.slot_rect_in(rect, limb_slot).get_center()))
	check(panel.selected == limb_slot, "a click selects the slot under the pointer")
	panel.selected = limb_slot
	panel.handle_input(click_event(panel.slot_rect_in(rect, limb_slot).get_center(), true))
	check(not panel.visible and hunt.carried_limb_index == 1, "a double click is the same verb as ENTER, not a quieter one")
	hunt._unhandled_input(key(KEY_O))
	check(panel.visible, "sanity: O brings the board back up")

	# A board with one page hides what is on the next one; the cursor must pull
	# the page with it rather than walk off the visible cells.
	for _index in 24:
		carry.take_chunk({"layer_name": "skin", "zone": "torso", "subject_id": "grid_probe"})
	var crowded := panel.slot_count()
	panel.selected = crowded - 1
	var scrolled := panel.grid_layout(rect)
	check(int(scrolled.first_row) > 0, "the board scrolls once the bag outgrows one page")
	var chosen := Rect2()
	for hit in panel.visible_slot_rects(rect):
		if int(hit.slot) == crowded - 1:
			chosen = hit.rect
	check(chosen.size.x > 0.0 and rect.encloses(chosen), "and the chosen slot stays on screen")
	carry.items = carry.items.filter(func(item): return str((item as Dictionary).get("from", "")) != "grid_probe")
	carry.save_to_history()
	panel.selected = 0
	panel.grid_scroll_row = 0

	print("AG5.30 - navigation changes real pocket/equipment state")
	panel.selected = panel.slot_for_bag(0)
	panel.handle_input(key(KEY_P))
	check(bool((carry.items[0] as Dictionary).get("pocketed", false)), "P pockets the selected small item through Carry's capacity rules")
	panel.selected = panel.slot_for_bag(1)
	panel.handle_input(key(KEY_ENTER))
	check(hunt.panel_mode.is_empty() and not panel.visible, "activating a wieldable object returns to play")
	check(hunt.carried_limb_index == 1 and hunt.carried_limb_model != null, "the selected limb—not merely the first available item—is wielded")

	print("Slice 18 - a weapon slot puts it in the hand")
	hunt._unhandled_input(key(KEY_O))
	check(panel.visible, "O reopens the board over the carried limb")
	check(panel.held_bag_index == 1, "the board knows the hand is holding the limb")
	check(panel.slot_foot(panel.slot_entry(panel.slot_for_bag(1))) == "IN HAND", "and the limb's own slot says so")
	check(panel.slot_foot(panel.slot_entry(panel.slot_for_weapon(hunt.arsenal.current_id))) != "IN HAND", "while no racked weapon claims the hand")
	var shiv_slot := panel.slot_for_weapon("shiv")
	if shiv_slot < 0:
		hunt.arsenal.acquire_melee("shiv")
		shiv_slot = panel.slot_for_weapon("shiv")
	check(shiv_slot >= 0, "the den's shiv has a rack slot")
	var bag_before := carry.items.size()
	var equipped: Array[String] = []
	panel.weapon_equipped.connect(func(weapon_id: String): equipped.append(weapon_id))
	panel.selected = shiv_slot
	panel.handle_input(key(KEY_ENTER))
	check(hunt.arsenal.current_id == "shiv", "ENTER on a weapon slot wields that exact weapon")
	check(equipped.has("shiv"), "and the world is told which one took the hand")
	check(carry.items.size() == bag_before, "the rack is a view, not a second bag")
	check(panel.visible, "equipping leaves the board up so the rest of the kit can still be read")
	check(hunt.carried_limb_index == -1 and hunt.carried_limb_model == null, "a racked weapon drops the improvised limb it replaced")
	check(panel.held_bag_index == -1 and panel.slot_foot(panel.slot_entry(shiv_slot)) == "IN HAND", "and the board moves IN HAND onto the weapon")

	print("Slice 19 - organs and hardware go in from the board")
	check(hunt.player_rig != null and hunt.player_rig.anatomy != null, "sanity: the live body is on the panel")
	var heart: Dictionary = carry.take_chunk({"layer_name": "organ", "organ_id": "heart", "zone": "torso", "subject_id": "organ_probe", "condition": 0.6})
	var heart_slot := panel.slot_for_bag(carry.items.find(heart))
	panel.selected = heart_slot
	panel.handle_input(key(KEY_ENTER))
	check(carry.items.find(heart) < 0, "a harvested heart leaves the bag")
	var heart_health := float(hunt.player_rig.anatomy.organs["heart"]["health"])
	var heart_ceiling := float((AnatomyComponent.ORGANS["heart"] as Dictionary).health)
	check(absf(heart_health - heart_ceiling * 0.6) < 1.0, "and beats in the body at the condition it was kept (%0.0f)" % heart_health)
	check(str(panel.get_meta("last_result", "")).contains("HEART"), "the plate says what went in")

	var eye: Dictionary = carry.take_chunk({"layer_name": "cybernetic", "implant": "rangefinder eye", "zone": "head", "subject_id": "implant_probe", "condition": 1.0})
	var eye_slot := panel.slot_for_bag(carry.items.find(eye))
	panel.selected = eye_slot
	panel.handle_input(key(KEY_ENTER))
	check(carry.items.find(eye) < 0, "implanted hardware leaves the bag too")
	var bolted := false
	for site in hunt.player_rig.anatomy.installed_parts:
		var part: Dictionary = hunt.player_rig.anatomy.installed_parts[site]
		if str(part.get("name", part.get("id", ""))).to_lower() == "rangefinder eye":
			bolted = true
	check(bolted, "and is bolted into the body it was fitted to")

	print("Slice 19 - a bag with no body on screen refuses instead of crashing")
	var route_panel: FieldInventory = FIELD_INVENTORY.new()
	add_child(route_panel)
	route_panel.size = Vector2(1280, 720)
	var lung: Dictionary = carry.take_chunk({"layer_name": "organ", "organ_id": "right_lung", "zone": "torso", "subject_id": "vat_probe", "condition": 0.9})
	var lung_index := carry.items.find(lung)
	route_panel.open_inventory(carry, null, null)
	route_panel.selected = lung_index
	check(route_panel.selected == lung_index, "with no rack the first slot is the first bag item")
	route_panel.handle_input(key(KEY_ENTER))
	check(carry.items.find(lung) >= 0, "an organ stays in the bag when there is no body to fit it to")
	check(str(route_panel.get_meta("last_result", "")).contains("NO BODY"), "and the plate says why")
	route_panel.queue_free()

	if not panel.visible:
		hunt._unhandled_input(key(KEY_O))
	check(panel.visible, "sanity: the board is up for the close test")
	check(hunt._close_active_interface() and hunt.panel_mode.is_empty() and not panel.visible, "the universal interface close lowers inventory cleanly")
	print("FIELD_INVENTORY_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
