extends Node3D

var wreck: Node3D
var menu_environment: Environment
var ui_time := 0.0
var menu_buttons: Array[Button] = []
var graphics_presets := ["ULTRA", "HIGH", "PERFORMANCE"]
var graphics_index := 0
var render_scales := [1.0, 1.25, 1.5, 0.8]
var render_scale_index := 0
var color_modes := ["CELLOUTZ COPPER", "SALVAGE TEAL", "NIGHT BLOOD"]
var color_index := 0
var gore_modes := ["FULL", "REDUCED", "OFF"]
var gore_index := 0
var vsync_enabled := true

@onready var settings_panel: PanelContainer = $HUD/SettingsPanel
@onready var effects_button: Button = $HUD/SettingsPanel/VBox/Effects


func _ready() -> void:
	_build_country_town()
	$HUD/Play.pressed.connect(_start_game)
	$HUD/Settings.pressed.connect(_open_settings)
	$HUD/Quit.pressed.connect(get_tree().quit)
	$HUD/SettingsPanel/VBox/Back.pressed.connect(_close_settings)
	effects_button.pressed.connect(_toggle_effects)
	$HUD/SettingsPanel/VBox/Graphics.pressed.connect(_cycle_graphics)
	$HUD/SettingsPanel/VBox/Resolution.pressed.connect(_cycle_resolution)
	$HUD/SettingsPanel/VBox/AntiAliasing.pressed.connect(_cycle_antialiasing)
	$HUD/SettingsPanel/VBox/VSync.pressed.connect(_toggle_vsync)
	$HUD/SettingsPanel/VBox/ColorGrade.pressed.connect(_cycle_color_grade)
	$HUD/CellOutzSite.pressed.connect(_open_celloutz)
	menu_buttons = [$HUD/Play, $HUD/Settings, $HUD/Quit, $HUD/CellOutzSite]
	for button in menu_buttons:
		# Every button shares offset_left, but the labels were centred inside
		# their own differing widths, so the column read as ragged and broken.
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_entered.connect(_focus_button.bind(button))
		button.mouse_exited.connect(_unfocus_button.bind(button))
	_build_gore_setting()


## Gore belongs in settings rather than on a hotkey over the pit. The choice is
## stored as a subject so every scene reads the same answer, and so it survives
## the run like anything else the world remembers.
func _build_gore_setting() -> void:
	WorldHistory.register_subject("settings", {"gore": "FULL"})
	gore_index = maxi(0, gore_modes.find(str(WorldHistory.subject("settings").get("gore", "FULL"))))
	var button := Button.new()
	button.name = "Gore"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "GORE: %s" % gore_modes[gore_index]
	var box := $HUD/SettingsPanel/VBox
	box.add_child(button)
	box.move_child(button, box.get_child_count() - 2)
	button.pressed.connect(_cycle_gore.bind(button))


func _cycle_gore(button: Button) -> void:
	gore_index = (gore_index + 1) % gore_modes.size()
	button.text = "GORE: %s" % gore_modes[gore_index]
	WorldHistory.update_subject("settings", {"gore": gore_modes[gore_index]}, "settings_changed")


func _process(delta: float) -> void:
	ui_time += delta
	if wreck != null:
		wreck.rotate_y(delta * 0.28)
		wreck.position.y = 4.4 + sin(Time.get_ticks_msec() * 0.0014) * 0.22
	$HUD/Title.position.x = 46.0 + sin(ui_time * 0.72) * 4.0
	$HUD/SubTitle.modulate.a = 0.72 + sin(ui_time * 2.1) * 0.18


func _focus_button(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", 72.0, 0.18)
	tween.tween_property(button, "modulate", Color("ff7138"), 0.18)


func _unfocus_button(button: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", 50.0, 0.22)
	tween.tween_property(button, "modulate", Color.WHITE, 0.22)


func _start_game() -> void:
	# A run that has not begun starts on the Growing Floor; one already under way
	# resumes at the pit rather than replaying the decanting.
	var opening := preload("res://systems/opening_director.gd")
	if opening.reached("entered_pit"):
		get_tree().change_scene_to_file("res://rift_derby.tscn")
	else:
		get_tree().change_scene_to_file("res://vat_chamber.tscn")


func _open_settings() -> void:
	settings_panel.visible = true


func _close_settings() -> void:
	settings_panel.visible = false


func _toggle_effects() -> void:
	menu_environment.glow_enabled = not menu_environment.glow_enabled
	effects_button.text = "BLOOM: %s" % ("ON" if menu_environment.glow_enabled else "OFF")


func _cycle_graphics() -> void:
	graphics_index = (graphics_index + 1) % graphics_presets.size()
	var preset: String = graphics_presets[graphics_index]
	match preset:
		"ULTRA":
			get_viewport().scaling_3d_scale = 1.0
			get_viewport().msaa_3d = Viewport.MSAA_4X
			get_viewport().use_taa = true
			menu_environment.glow_enabled = true
		"HIGH":
			get_viewport().scaling_3d_scale = 0.9
			get_viewport().msaa_3d = Viewport.MSAA_2X
			get_viewport().use_taa = true
			menu_environment.glow_enabled = true
		_:
			get_viewport().scaling_3d_scale = 0.75
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().use_taa = false
			menu_environment.glow_enabled = false
	$HUD/SettingsPanel/VBox/Graphics.text = "GRAPHICS: %s" % preset


func _cycle_resolution() -> void:
	render_scale_index = (render_scale_index + 1) % render_scales.size()
	var scale: float = render_scales[render_scale_index]
	get_viewport().scaling_3d_scale = scale
	$HUD/SettingsPanel/VBox/Resolution.text = "RENDER SCALE: %d%%" % roundi(scale * 100.0)


func _cycle_antialiasing() -> void:
	if get_viewport().use_taa:
		get_viewport().use_taa = false
		get_viewport().msaa_3d = Viewport.MSAA_4X
		$HUD/SettingsPanel/VBox/AntiAliasing.text = "ANTI-ALIASING: MSAA 4X"
	elif get_viewport().msaa_3d != Viewport.MSAA_DISABLED:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		$HUD/SettingsPanel/VBox/AntiAliasing.text = "ANTI-ALIASING: OFF"
	else:
		get_viewport().use_taa = true
		get_viewport().msaa_3d = Viewport.MSAA_2X
		$HUD/SettingsPanel/VBox/AntiAliasing.text = "ANTI-ALIASING: TAA + MSAA 2X"


func _toggle_vsync() -> void:
	vsync_enabled = not vsync_enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	$HUD/SettingsPanel/VBox/VSync.text = "VSYNC: %s" % ("ON" if vsync_enabled else "OFF")


## Swaps the whole WorldLook preset rather than tinting one ambient colour. On a
## sky-sourced environment an ambient_light_color write does nothing at all,
## which is why this setting used to appear to do nothing.
func _cycle_color_grade() -> void:
	color_index = (color_index + 1) % color_modes.size()
	var mode: String = color_modes[color_index]
	var preset := "bone_yard"
	if mode == "SALVAGE TEAL":
		preset = "ashbloom"
	elif mode == "NIGHT BLOOD":
		preset = "ossuary"
	menu_environment = WorldLook.environment(preset)
	$WorldEnvironment.environment = menu_environment
	$HUD/SettingsPanel/VBox/ColorGrade.text = "COLOR: %s" % mode


func _open_celloutz() -> void:
	WorldHistory.record_event("celloutz_site_opened", {"source": "main_menu"})
	OS.shell_open("https://celloutz.xyz/")


func _build_country_town() -> void:
	# Was a hand-rolled Environment: a near-black background with a flat 0.5
	# colour ambient and one spotlight, which rendered the whole town as an
	# invisible dark mass. WorldLook is the shared look system the derby already
	# uses, and it carries a real sky to light against.
	menu_environment = WorldLook.environment("bone_yard")
	$WorldEnvironment.environment = menu_environment
	_add_mesh(BoxMesh.new(), Vector3(0, -0.5, 0), Vector3(70, 0.7, 70), Color("25170e"), 0.0)
	_add_mesh(BoxMesh.new(), Vector3(4, -0.1, 5), Vector3(11, 0.15, 62), Color("241f1a"), 0.0)
	for index in 13:
		_add_mesh(BoxMesh.new(), Vector3(4, 0.02, -25 + index * 5), Vector3(0.35, 0.03, 2.5), Color("ae8149"), 0.0)
	_build_building(Vector3(-14, 2.4, -6), Vector3(10, 4.8, 7), Color("4b2818"), "MERCY SERVO")
	_build_building(Vector3(16, 1.8, -14), Vector3(8, 3.6, 6), Color("332016"), "BONE YARD")
	for index in 11:
		var angle := TAU * float(index) / 11.0
		var tree := CylinderMesh.new()
		tree.top_radius = 0.25
		tree.bottom_radius = 0.42
		tree.height = 7.0 + float(index % 3)
		_add_mesh(tree, Vector3(cos(angle) * 29.0, 3.2, sin(angle) * 29.0), Vector3.ONE, Color("26180f"), 0.0)
	var tank := CylinderMesh.new()
	tank.top_radius = 2.0
	tank.bottom_radius = 2.0
	tank.height = 5.0
	_add_mesh(tank, Vector3(24, 6.0, 9), Vector3.ONE, Color("5d4532"), 0.0)
	for offset in [-1.2, 1.2]:
		_add_mesh(CylinderMesh.new(), Vector3(24 + offset, 2.2, 9), Vector3(0.25, 1.0, 0.25), Color("3b2920"), 0.0)
	wreck = Node3D.new()
	wreck.position = Vector3(1.5, 4.4, -3)
	add_child(wreck)
	var wreck_mesh := BoxMesh.new()
	wreck_mesh.size = Vector3(3.4, 1.25, 5.2)
	_add_mesh_to(wreck, wreck_mesh, Vector3.ZERO, Color("742018"), 0.0)
	_add_mesh_to(wreck, SphereMesh.new(), Vector3(0, 0.7, -0.5), Color("301f17"), 0.0)
	var floodlight := SpotLight3D.new()
	floodlight.position = Vector3(-7, 10, 8)
	floodlight.rotation_degrees = Vector3(-52, -25, 0)
	floodlight.light_color = Color("ff8a3c")
	floodlight.light_energy = 7.0
	floodlight.spot_range = 35.0
	add_child(floodlight)
	# One spotlight cannot light a town. The key light is what makes the
	# buildings, road and wreck read as forms rather than silhouettes.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -38, 0)
	sun.light_color = Color("ffcf9e")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _build_building(position_value: Vector3, size_value: Vector3, color: Color, sign_text: String) -> void:
	_add_mesh(BoxMesh.new(), position_value, size_value, color, 0.0)
	var sign := Label3D.new()
	sign.text = sign_text
	sign.position = position_value + Vector3(0, size_value.y * 0.2, size_value.z * 0.52 + 0.05)
	sign.font_size = 42
	sign.modulate = Color("d87635")
	sign.outline_size = 6
	add_child(sign)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emission: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	mesh.material = _material(color, emission)
	add_child(instance)


func _add_mesh_to(parent: Node3D, mesh: PrimitiveMesh, position_value: Vector3, color: Color, emission: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	mesh.material = _material(color, emission)
	parent.add_child(instance)


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3
	material.roughness = 0.78
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
