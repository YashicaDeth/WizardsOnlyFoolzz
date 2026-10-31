extends Node

## The field HUD in the live Hunt, for layout review rather than for a pass/fail
## gate: the top-right cluster and the bottom prompt band are both crowded, and
## crowding is only visible in a picture.
##
## `-- --out=DIR` writes `hud_field.png`. The body is put into a mid-fight state
## on purpose — low blood, spent stamina, a duty held, a hunt running — because
## the corner is least readable exactly when it matters most, and an idle HUD
## photograph would prove nothing.

## The longest sentence the prompt label is ever handed (`bone_yard_hunt`'s
## fleeing-body line), not the shortest, so the band is measured at its worst.
const PROMPT_TEXT := "NIX ARDEN IS BLEEDING OUT AND ESCAPING — CHASE FOR THEIR LOOT OR LET THEM GO."


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
	# A ritual already happened, so the third reservoir is real and has to fit.
	WorldHistory.record_event("ritual_completed", {})
	hunt.health = 42.0
	hunt.stamina = 17.0
	if hunt.player_rig != null and hunt.player_rig.anatomy != null:
		hunt.player_rig.anatomy.blood_remaining = hunt.player_rig.anatomy.blood_capacity * 0.31
		hunt.player_rig.anatomy.pain = 61.0
		hunt.player_rig.anatomy.consciousness = 34.0
	# The longest thing the prompt label is ever asked to say, so the band is
	# measured at its worst rather than at "HANDS".
	hunt.prompt.text = PROMPT_TEXT
	hunt.prompt.visible = true
	for _f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output := out_dir + "/hud_field.png"
	get_viewport().get_texture().get_image().save_png(output)
	print("CAPTURED: ", output)
	get_tree().quit()
