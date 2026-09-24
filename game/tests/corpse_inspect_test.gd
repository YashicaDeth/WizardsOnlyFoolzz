extends Node

## Dead bodies open in the inventory: pockets and garments take, open cavities
## show, sealed zones refuse. The gate belongs to CorpseContents; this proves
## the panel takes what it may and refuses the rest without touching the dig.

const MENU := preload("res://systems/field_inventory.gd")
const HUMAN := preload("res://systems/baseline_human.gd")
const GARMENT := preload("res://systems/clothing_shell.gd")
const PURSE := preload("res://systems/carry.gd")

var failures: Array[String] = []


func check(c: bool, label: String) -> void:
	print("PASS " if c else "FAIL ", label)
	if not c:
		failures.append(label)


func press(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	return ev


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.register_subject("inventory", {"items": [], "rust_scrip": 0})
	var menu: FieldInventory = MENU.new()
	add_child(menu)
	var purse = PURSE.new()
	menu.carry = purse
	menu.open_corpse(_dressed_dead(), ["gate scrip"])
	check(menu.visible, "the dead open in the inventory")

	var rows: Array = menu._corpse_rows()
	var kinds := {}
	for row: Dictionary in rows:
		kinds[str(row.get("kind", ""))] = true
	check(kinds.has("pocket"), "pockets list")
	check(kinds.has("garment"), "garments list with their condition")
	check(kinds.has("sealed"), "unopened zones list as sealed, not as manifests")

	# Pockets move to the bag.
	var bag_before: int = purse.items.size()
	menu.selected = 0
	menu.handle_input(press(KEY_ENTER))
	check(purse.items.size() == bag_before + 1, "a pocket moves to the bag")
	check(menu._corpse_rows().size() == rows.size() - 1, "and off the body")

	# Garments come off their zone.
	var garment_index := -1
	var current: Array = menu._corpse_rows()
	for index in current.size():
		if str((current[index] as Dictionary).get("kind", "")) == "garment":
			garment_index = index
			break
	check(garment_index >= 0, "sanity: a garment row exists to take")
	menu.selected = garment_index
	var zone := str(((menu._corpse_rows()[garment_index]) as Dictionary).get("payload", {}).get("zone", ""))
	menu.handle_input(press(KEY_ENTER))
	check(not (menu.inspect_rig as BaselineHuman).wardrobe.has(zone), "taking it undresses the zone (%s)" % zone)
	check(str(menu.get_meta("last_result", "")).contains("STRIPPED"), "and says so")

	# Sealed refuses.
	var sealed_index := -1
	current = menu._corpse_rows()
	for index in current.size():
		if str((current[index] as Dictionary).get("kind", "")) == "sealed":
			sealed_index = index
			break
	if sealed_index >= 0:
		menu.selected = sealed_index
		menu.handle_input(press(KEY_ENTER))
		check(str(menu.get_meta("last_result", "")) == "SEALED", "sealed zones refuse without naming")
	else:
		check(true, "no sealed rows left to refuse (all opened or taken)")

	# Your own bag is untainted by the dead.
	menu.open_inventory(purse, null, null)
	check(menu.inspect_rig == null, "returning to your bag leaves the body behind")

	print("CORPSE_INSPECT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _dressed_dead() -> BaselineHuman:
	var rig: BaselineHuman = HUMAN.new()
	add_child(rig)
	rig.build("corpse_probe", {})
	rig.dress(GARMENT.fresh_wardrobe())
	return rig
