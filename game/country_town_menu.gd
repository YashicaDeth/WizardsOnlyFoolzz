extends Node3D

var wreck: Node3D
var front_door: Node3D
var warning_card: Control
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
var gore_button: Button
var vsync_enabled := true
var intro_veil: ColorRect

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
	_build_sandbox_door()
	_build_front_door()
	_play_title_sequence()


## The title arrives as a sequence rather than sitting on top of a live menu
## on frame one.  The logo gets the first clear read; the street and controls
## only come in after it has landed.
func _play_title_sequence() -> void:
	intro_veil = ColorRect.new()
	intro_veil.name = "ColdOpenVeil"
	intro_veil.color = Color("080305")
	intro_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_veil.z_index = 20
	$HUD.add_child(intro_veil)
	$HUD/Title.modulate.a = 0.0
	$HUD/Presents.modulate.a = 0.0
	$HUD/Algiz.modulate.a = 0.0
	$HUD/Title.scale = Vector2(0.90, 0.90)
	for button in menu_buttons:
		button.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(0.22)
	tween.tween_property(intro_veil, "color:a", 0.14, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($HUD/Presents, "modulate:a", 0.95, 0.32)
	tween.tween_property($HUD/Algiz, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property($HUD/Title, "modulate:a", 1.0, 0.36)
	tween.parallel().tween_property($HUD/Title, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(intro_veil, "color:a", 0.0, 0.72)
	for button in menu_buttons:
		tween.parallel().tween_property(button, "modulate:a", 1.0, 0.32)
	tween.tween_callback(func() -> void:
		if is_instance_valid(intro_veil):
			intro_veil.queue_free())



## A way in to the gore sandbox from the front end.
##
## The menu could reach the derby and the decanting floor and nothing else, so
## the most complete system in the project - anatomy, severing, chunks, the
## X-ray - had no door on it at all and anyone handed a build would never find
## it. For a demo somebody sends to a friend that is the whole thing missing.
##
## Built in code rather than added to the scene so the column stays one source
## of truth about its own spacing: the new row is the Play button copied, and
## everything below it moves down by exactly one row height.
func _build_sandbox_door() -> void:
	var play: Button = $HUD/Play
	var row: float = play.offset_bottom - play.offset_top + 8.0
	for button: Button in [$HUD/Settings, $HUD/Quit, $HUD/CellOutzSite]:
		button.offset_top += row
		button.offset_bottom += row
	# Flags cleared on purpose: `duplicate()` copies signal connections by
	# default, and a copy of Play that is still wired to `_start_game` would send
	# anyone who pressed it to the decanting floor instead.
	var sandbox := play.duplicate(0) as Button
	sandbox.name = "Sandbox"
	sandbox.text = "GORE SANDBOX"
	sandbox.offset_top = play.offset_top + row
	sandbox.offset_bottom = play.offset_bottom + row
	sandbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUD.add_child(sandbox)
	sandbox.pressed.connect(func() -> void:
		Interstitial.travel("res://gore_demo.tscn", "the sandbox // seven of them"))
	sandbox.mouse_entered.connect(_focus_button.bind(sandbox))
	sandbox.mouse_exited.connect(_unfocus_button.bind(sandbox))
	menu_buttons.append(sandbox)

## The front end is a scene with junk falling through it, and the first thing
## the player is asked is what they are willing to look at. The violence tiers
## already existed; they were buried in a settings submenu nobody opens, which
## is a strange place to keep the one setting the whole game is about.
func _build_front_door() -> void:
	front_door = preload("res://systems/front_door.gd").new()
	front_door.name = "FrontDoor"
	add_child(front_door)
	front_door.camera.current = true

	warning_card = preload("res://systems/warning_card.gd").new()
	warning_card.name = "WarningCard"
	$HUD.add_child(warning_card)
	warning_card.chosen.connect(_on_violence_chosen)
	# Shown once per install. Returning players are not lectured twice; the
	# tier stays changeable in settings.
	if str(WorldHistory.subject("settings").get("violence_acknowledged", "")) == "yes":
		warning_card.hide()
	else:
		warning_card.open_card()


func _on_violence_chosen(mode: String) -> void:
	WorldHistory.update_subject("settings", {"violence_acknowledged": "yes"}, "violence_acknowledged")
	gore_index = maxi(0, gore_modes.find(mode))
	if gore_button != null and is_instance_valid(gore_button):
		gore_button.text = "GORE: %s" % mode


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
	gore_button = button


func _cycle_gore(button: Button) -> void:
	gore_index = (gore_index + 1) % gore_modes.size()
	button.text = "GORE: %s" % gore_modes[gore_index]
	WorldHistory.update_subject("settings", {"gore": gore_modes[gore_index]}, "settings_changed")


func _process(delta: float) -> void:
	ui_time += delta
	if wreck != null:
		wreck.rotate_y(delta * 0.28)
		wreck.position.y = 4.4 + sin(Time.get_ticks_msec() * 0.0014) * 0.22
	$HUD/Title.position.y = sin(ui_time * 0.72) * 2.0
	$HUD/Algiz.modulate.a = 0.72 + sin(ui_time * 2.1) * 0.18


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
		Interstitial.travel("res://rift_derby.tscn", "the bone yard // heat one")
	else:
		Interstitial.travel("res://vat_chamber.tscn", "the growing floor // decanting")


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
	# The front door owns its own composed street and camera.  This node still
	# owns the settings Environment, but it must not build its old blockout under
	# that camera: those legacy boxes were the floating orange geometry in the
	# title shot.
	menu_environment = WorldLook.environment("ossuary")
	$WorldEnvironment.environment = menu_environment


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
