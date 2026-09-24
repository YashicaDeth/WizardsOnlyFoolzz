extends Node

## The title screen's live logo (Greg: re-animate the real logo), past the
## content warning, for the movie writer:
##   Godot --write-movie DIR/f.png --fixed-fps 30 --quit-after 300 res://tests/title_logo_capture.tscn

func _ready() -> void:
	WorldHistory.world_minute = WorldClock.OPENING_MINUTE
	WorldHistory.update_subject("settings", {"gore": "FULL", "violence_acknowledged": "yes"}, "capture_setup")
	await get_tree().process_frame
	var menu := preload("res://country_town_menu.tscn").instantiate()
	get_tree().root.add_child.call_deferred(menu)
	await get_tree().process_frame
	get_tree().current_scene = menu
	# Hover the first door once the menu has typed on, to show the blood.
	await get_tree().create_timer(4.2).timeout
	var first: Button = menu.menu_buttons[0]
	first.mouse_entered.emit()
