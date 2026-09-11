extends Control


func _ready() -> void:
	print("ALLUSIONS_SETUP_OK")
	print("Project: ", ProjectSettings.globalize_path("res://"))
	print("User data: ", OS.get_user_data_dir())
	var launch := get_node_or_null("LaunchPlayLab")
	if launch:
		launch.pressed.connect(_launch_play_lab)


func _launch_play_lab() -> void:
	get_tree().change_scene_to_file("res://prototype_lab/lab.tscn")
