extends Node

## The Brain Index hub in the real Hunt: CARRY (loadout skins, worn parts,
## carried items with their icons) and COMBAT (blood by style and weapon).
## `-- --out=DIR`.

func key(hunt, code: int, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	hunt._unhandled_input(event)


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1600, 900)
	WorldHistory.clear_history()
	var hunt = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _f in 5:
		await get_tree().physics_frame
	var carry: Carry = hunt.handheld.carry
	carry.items.append(WeaponSkins.mint("sidearm_celloutz_fade", 0.2, 900))
	SkinLoadout.apply(carry, carry.items.size() - 1)
	carry.items.append(WeaponSkins.mint("sword_saints_tooth", 0.1, 7))
	carry.items.append(SkinCase.case_item("wetwork_case"))
	carry.items.append({"label": "12 ROUNDS", "kind": "ammo", "mass": 0.6})
	carry.items.append({"label": "LIFT FUSE", "kind": "tool", "mass": 0.2})
	carry.items.append({"label": "SOMEONE'S LIVER", "kind": "organ", "mass": 1.4})
	carry.items.append({"label": "SALVAGED IMPLANT", "kind": "cybernetic", "mass": 0.9})
	# Slice 12: the three kinds that used to draw the same placeholder box.
	carry.items.append({"label": "EXAMINER KEYCARD", "kind": "key", "mass": 0.05})
	carry.items.append({"label": "CLOTH PATCH", "kind": "patch", "mass": 0.1})
	carry.items.append({"label": "BUNDLE OF RAGS", "kind": "goods", "mass": 0.4})
	carry.items.append(Outfit.part_item("jester_cap", 0.8))
	hunt.arsenal.apply_skins()
	hunt.blood_ledger.credit("sidearm", 180, "kill")
	hunt.blood_ledger.credit("sword", 90, "hit")
	# Tab is the field inventory since 26 September; the hub is Shift+Tab. This
	# fixture kept pressing Tab and so captured the wrong screen.
	key(hunt, KEY_TAB, true)
	for _f in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/hub_carry.png")
	key(hunt, KEY_RIGHT)
	for _f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/hub_combat.png")
	print("CAPTURED")
	get_tree().quit()
