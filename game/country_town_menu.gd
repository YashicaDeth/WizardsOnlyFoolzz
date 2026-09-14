extends Node3D

const Quantum := preload("res://systems/quantum_saves.gd")

const MENU_PLATE := preload("res://systems/menu_plate.gd")
const DECANTING_PROLOGUE := preload("res://systems/decanting_prologue.gd")
const SPLASH_BACKDROP := preload("res://systems/splash_backdrop.gd")
const REGAL_FRAME := preload("res://systems/regal_frame.gd")
const CRT_GLASS := preload("res://systems/crt_glass.gd")
const EYE_GLARE := preload("res://systems/eye_glare.gd")

## Well below anything else so the picture is unambiguously the backdrop and
## every other canvas in the scene still draws over the 3D as normal.
const SPLASH_CANVAS_LAYER := -100
## Above the backdrop and the 3D world, below every readable canvas. See where
## the glass is built for why it cannot live on the backdrop layer itself.
const SPLASH_GLASS_CANVAS_LAYER := -50

var wreck: Node3D
var front_door: Node3D
var warning_card: Control
var menu_environment: Environment
var ui_time := 0.0
var menu_buttons: Array[Button] = []
var menu_plate: Control
var settings_plate: Control
var prologue: Control
var splash: ColorRect
var splash_frame: RegalFrame
var splash_glass: CrtGlass
var splash_glare: EyeGlare
var splash_glass_layer: CanvasLayer
var splash_layer: CanvasLayer
var branch_plate: Control
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
var branch_panel: PanelContainer
var branch_list: VBoxContainer
var branch_creating := false
## Kept unset in the game. The regression scene supplies it so departure UI can
## be tested without loading a whole destination world after the assertions.
var travel_request_override: Callable
## A menu can only leave once. Apart from preventing duplicate scene-load
## requests, this makes the old scene inert during the interstitial: controls
## such as Settings cannot continue receiving clicks after their panel has
## disappeared from view.
var menu_departing := false

@onready var settings_panel: PanelContainer = $HUD/SettingsPanel
@onready var effects_button: Button = $HUD/SettingsPanel/VBox/Effects


func _ready() -> void:
	_build_country_town()
	$HUD/Play.pressed.connect(_open_continue_runs)
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
	_build_run_doors()
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
	# Greg's own room, under the cold open. The inverted cyan half sweeps across
	# it live (see `splash_backdrop.gd`) rather than being a baked seam, so the
	# thing he called "the blue invertred side attacking the screen" actually
	# attacks instead of sitting still.
	# Greg: the backdrop should have "all the 3d fighting landscapes and other
	# stuff there too". As a HUD child it could not — a CanvasLayer always draws
	# over the 3D viewport, so his room hid the street, the falling debris and
	# the bodies completely.
	#
	# So the picture stops being an overlay and becomes the 3D *background*.
	# `Environment.BG_CANVAS` lets a canvas layer be what the 3D world is drawn
	# against, so the street and everything fighting in it now render on top of
	# the room instead of being erased by it.
	splash_layer = CanvasLayer.new()
	splash_layer.name = "SplashLayer"
	splash_layer.layer = SPLASH_CANVAS_LAYER
	add_child(splash_layer)
	splash = SPLASH_BACKDROP.new()
	splash.name = "SplashBackdrop"
	splash_layer.add_child(splash)
	# A1.8. Same frame as the cold open, in the restrained cut. The menu has six
	# lines of type sitting on this, and the frame has to lose that argument —
	# `ossuary` keeps the ornament and drops the vessel gain and the gloss rather
	# than running the band short, which is what leaks the photograph's hard edge
	# back in. It arrives a beat behind the picture so it reads as the room being
	# mounted rather than as one flat image fading up.
	splash_frame = REGAL_FRAME.new()
	splash_frame.name = "SplashFrame"
	splash_frame.set_variant("ossuary")
	splash_frame.fit_to_photo()
	splash_layer.add_child(splash_frame)
	# The eye. On the backdrop canvas so the glass above picks it up and bends it
	# with everything else, rather than sitting flat on top of a curved frame.
	splash_glare = EYE_GLARE.new()
	splash_glare.name = "SplashEyeGlare"
	splash_layer.add_child(splash_glare)
	# A1.9. Last of the three. The composition assembles — mark, picture, mount —
	# and only then does it turn out you have been looking at a screen the whole
	# time. Menu type is on $HUD, a different canvas entirely, so it never enters
	# the warp and stays as readable as it was.
	# Its own canvas, between the backdrop and the HUD, and the layer number is
	# the whole point.
	#
	# Inside `splash_layer` the glass degraded the picture correctly — bloom,
	# scanlines, aberration all landed — and its **geometry did nothing**: the
	# photograph stayed a dead-straight rectangle while the standalone harness
	# bowed the same shader hard enough to open black wedges in the corners.
	# That canvas is the 3D background via `BG_CANVAS`, so a screen-texture read
	# inside it sees its own canvas rather than the composited frame, and warping
	# the sample of a thing that is about to be re-projected warps nothing.
	#
	# On a layer of its own above it, the glass samples what has actually been
	# drawn — the room *and* the street and the bodies in front of it — so the
	# whole tableau curves together instead of a flat picture behind curved
	# nothing. Still below `$HUD` at 0, so the menu type never enters the warp.
	splash_glass_layer = CanvasLayer.new()
	splash_glass_layer.name = "SplashGlassLayer"
	splash_glass_layer.layer = SPLASH_GLASS_CANVAS_LAYER
	add_child(splash_glass_layer)
	splash_glass = CRT_GLASS.new()
	splash_glass.name = "SplashGlass"
	splash_glass_layer.add_child(splash_glass)
	_use_canvas_background()
	$HUD/TitleLogo.modulate.a = 0.0
	$HUD/Algiz.modulate.a = 0.0
	$HUD/TitleLogo.scale = Vector2(0.90, 0.90)
	$HUD/TitleLogo.pivot_offset = $HUD/TitleLogo.size * 0.5
	for button in menu_buttons:
		button.modulate.a = 0.0
	# The backdrop runs on its own tween, but the mark gets a clear read first:
	# CellOutz/Algiz/Wizards lands and holds, then the authored cyan invert tears
	# in from the left behind it rather than competing with the logo's entrance.
	splash.play(self, 1.15)
	# Behind the picture by the same beat the picture is behind the mark.
	splash_frame.play(self, 1.50)
	splash_glass.play(self, 1.90)
	splash_glare.play(self, 2.20)
	# The tube struggles as the authored invert tears across and recovers after
	# it lands, which is what makes the distortion information rather than
	# wallpaper. Timed to the backdrop's own attack rather than to a guess.
	splash_glass.surge(self, 0.85, 0.9, 2.1)
	var tween := create_tween()
	tween.tween_interval(0.22)
	tween.tween_property(intro_veil, "color:a", 0.14, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property($HUD/Algiz, "modulate:a", 1.0, 0.18)
	tween.parallel().tween_property($HUD/TitleLogo, "modulate:a", 1.0, 0.36)
	tween.parallel().tween_property($HUD/TitleLogo, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
func _build_run_doors() -> void:
	var play: Button = $HUD/Play
	play.text = "PLAY // SURVIVING WORLDS"
	var row: float = play.offset_bottom - play.offset_top + 8.0
	for button: Button in [$HUD/Settings, $HUD/Quit, $HUD/CellOutzSite]:
		button.offset_top += row * 3.0
		button.offset_bottom += row * 3.0
	var demo := play.duplicate(0) as Button
	demo.name = "Demo"
	demo.text = "DEMO // THE BEST HALF HOUR"
	demo.offset_top = play.offset_top + row
	demo.offset_bottom = play.offset_bottom + row
	demo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUD.add_child(demo)
	demo.pressed.connect(_start_demo)
	demo.mouse_entered.connect(_focus_button.bind(demo))
	demo.mouse_exited.connect(_unfocus_button.bind(demo))
	menu_buttons.append(demo)
	var new_game := play.duplicate(0) as Button
	new_game.name = "NewGame"
	new_game.text = "NEW GAME  //  SPLIT THE WORLD"
	new_game.offset_top = play.offset_top + row * 2.0
	new_game.offset_bottom = play.offset_bottom + row * 2.0
	new_game.alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUD.add_child(new_game)
	new_game.pressed.connect(_open_new_game)
	new_game.mouse_entered.connect(_focus_button.bind(new_game))
	new_game.mouse_exited.connect(_unfocus_button.bind(new_game))
	menu_buttons.append(new_game)
	# Flags cleared on purpose: `duplicate()` copies signal connections by
	# default, and a copy of Play that is still wired to `_start_game` would send
	# anyone who pressed it to the decanting floor instead.
	var sandbox := play.duplicate(0) as Button
	sandbox.name = "Sandbox"
	sandbox.text = "GORE SANDBOX"
	sandbox.offset_top = play.offset_top + row * 3.0
	sandbox.offset_bottom = play.offset_bottom + row * 3.0
	sandbox.alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HUD.add_child(sandbox)
	sandbox.pressed.connect(_open_gore_sandbox)
	sandbox.mouse_entered.connect(_focus_button.bind(sandbox))
	sandbox.mouse_exited.connect(_unfocus_button.bind(sandbox))
	menu_buttons.append(sandbox)
	# The column is set in the house type from here on. The buttons keep hit
	# testing, focus, the tween and every signal; they just stop drawing their
	# own text in the engine's fallback UI font.
	menu_plate = MENU_PLATE.new()
	menu_plate.name = "MenuPlate"
	$HUD.add_child(menu_plate)
	menu_plate.adopt(menu_buttons)
	_build_branch_panel()


func _build_branch_panel() -> void:
	branch_panel = PanelContainer.new()
	branch_panel.name = "QuantumBranches"
	branch_panel.set_anchors_preset(Control.PRESET_CENTER)
	branch_panel.offset_left = -236.0
	branch_panel.offset_top = -166.0
	branch_panel.offset_right = 236.0
	branch_panel.offset_bottom = 166.0
	branch_panel.visible = false
	branch_panel.z_index = 30
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("160706f2")
	skin.border_color = Color("9e2817")
	skin.set_border_width_all(2)
	skin.corner_radius_top_left = 8
	skin.corner_radius_top_right = 8
	skin.corner_radius_bottom_left = 8
	skin.corner_radius_bottom_right = 8
	skin.shadow_color = Color("000000cc")
	skin.shadow_size = 18
	branch_panel.add_theme_stylebox_override("panel", skin)
	$HUD.add_child(branch_panel)
	branch_list = VBoxContainer.new()
	branch_list.add_theme_constant_override("separation", 8)
	branch_panel.add_child(branch_list)


func _open_continue_runs() -> void:
	WorldHistory.enter_play_mode()
	_open_branch_picker(false)


func _open_new_game() -> void:
	WorldHistory.enter_play_mode()
	_open_branch_picker(true)


## P2.5. No slot picker and no configuration fork: DEMO selects its isolated
## ledger and enters the same `_start_game()` used by PLAY.
func _start_demo() -> void:
	if menu_departing:
		return
	WorldHistory.begin_demo()
	_start_game()


func _open_branch_picker(creating: bool) -> void:
	if menu_departing:
		return
	branch_creating = creating
	for child in branch_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "QUANTUM IMMORTALITY // %s" % ("BIRTH A WORLD" if creating else "CHOOSE A SURVIVING WORLD")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("e3a070"))
	branch_list.add_child(heading)
	var subhead := Label.new()
	subhead.text = "DEATH IS A RECORD. THE OTHER BRANCHES REMAIN."
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", 11)
	subhead.add_theme_color_override("font_color", Color("a85b43"))
	branch_list.add_child(subhead)
	for entry in Quantum.slots():
		var slot := int(entry.slot)
		var button := Button.new()
		button.custom_minimum_size = Vector2(430, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		var occupied := bool(entry.occupied)
		if creating:
			button.text = "  [%d]  %s" % [slot + 1, "OVERWRITE // %s" % entry.label if occupied else "UNWRITTEN WORLD"]
		else:
			button.text = "  [%d]  %s" % [slot + 1, str(entry.label) if occupied else "NO SURVIVING WORLD"]
			button.disabled = not occupied
		button.pressed.connect(_choose_branch.bind(slot))
		branch_list.add_child(button)
	var cancel := Button.new()
	cancel.text = "RETURN TO THE STREET"
	cancel.alignment = HORIZONTAL_ALIGNMENT_CENTER
	cancel.pressed.connect(func() -> void: branch_panel.hide())
	branch_list.add_child(cancel)
	# Greg named this screen alongside settings. Same treatment, but rebuilt
	# every time the picker opens rather than dressed once, because this list is
	# torn down and regenerated on each open — a plate adopted once would be
	# speaking for freed nodes the second time through.
	if branch_plate != null and is_instance_valid(branch_plate):
		branch_plate.queue_free()
	branch_plate = MENU_PLATE.new()
	branch_plate.name = "BranchPlate"
	branch_plate.compact = true
	branch_panel.add_child(branch_plate)
	var branch_rows: Array = []
	for child in branch_list.get_children():
		branch_rows.append(child)
	branch_plate.adopt(branch_rows)
	branch_panel.show()


func _choose_branch(slot: int) -> void:
	if menu_departing:
		return
	if branch_creating:
		var created := Quantum.begin_new(slot, "WORLD %02d" % (slot + 1))
		if created.is_empty():
			return
	else:
		if not Quantum.enter(slot):
			return
	branch_panel.hide()
	_start_game()

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
	$HUD/TitleLogo.position.y = sin(ui_time * 0.72) * 2.0
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
	if not _prepare_menu_departure():
		return
	# A run that has not begun starts on the Growing Floor; one already under way
	# resumes at the stage it actually earned rather than replaying decanting or
	# being sent back into a derby it has already won.
	var opening := preload("res://systems/opening_director.gd")
	var destination: Dictionary = opening.resume_destination()
	if opening.reached("won_derby"):
		_travel_from_menu(str(destination.scene), str(destination.caption))
		return
	if opening.reached("entered_pit"):
		_travel_from_menu(str(destination.scene), str(destination.caption))
		return
	# Greg: *"the starting cutscne needs to be lore accurate then have the part
	# where you can fully character customise"*. The second half was already
	# here — the Growing Floor is the character creation. The prologue is the
	# first half, and it only plays on the path that has never been walked, so a
	# resumed run is not made to sit through it.
	_play_decanting_prologue()


func _play_decanting_prologue() -> void:
	if prologue == null or not is_instance_valid(prologue):
		prologue = DECANTING_PROLOGUE.new()
		prologue.name = "DecantingPrologue"
		$HUD.add_child(prologue)
		prologue.finished.connect(func() -> void:
			_travel_from_menu("res://vat_chamber.tscn", "the growing floor // decanting"))
	prologue.play()


## The Gore Sandbox uses the exact same exit route as a regular run. The old
## direct `Interstitial.travel()` call let the Settings panel remain alive over
## the fade, so another click could still arrive before the scene was swapped.
func _open_gore_sandbox() -> void:
	if not _prepare_menu_departure():
		return
	_travel_from_menu("res://gore_demo.tscn", "the sandbox // seven of them")


## Close every transient menu surface before the loading plate appears and make
## every old control inert. The source scene is about to be removed; it must not
## be allowed to process a second button event while that happens.
func _prepare_menu_departure() -> bool:
	if menu_departing or Interstitial.travelling:
		return false
	menu_departing = true
	settings_panel.hide()
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if branch_panel != null and is_instance_valid(branch_panel):
		branch_panel.hide()
		branch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if warning_card != null and is_instance_valid(warning_card):
		warning_card.hide()
		warning_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_menu_buttons_enabled(false)
	return true


func _set_menu_buttons_enabled(enabled: bool) -> void:
	for button in menu_buttons:
		if button != null and is_instance_valid(button):
			button.disabled = not enabled
	for child in $HUD/SettingsPanel/VBox.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not enabled


## Kept separate from the preparation above so the decanting prologue can play
## after the UI has already become inert.
func _travel_from_menu(scene_path: String, travel_caption: String) -> void:
	if not menu_departing or Interstitial.travelling:
		return
	if travel_request_override.is_valid():
		travel_request_override.call(scene_path, travel_caption)
		return
	Interstitial.travel(scene_path, travel_caption)


## Greg: the settings screen looked "so lack luster". It was a default
## `PanelContainer` of grey engine buttons sitting at x=50 — directly on top of
## the menu column it was opened from — running off the bottom edge of a 720
## window, with BACK half out of frame. Dressed once, on the way in.
func _dress_settings_panel() -> void:
	if settings_plate != null:
		return
	# Off the column and inside the frame. Anchored to the centre so it holds
	# together at any window size instead of being pinned to a corner it was
	# measured against once.
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -196.0
	settings_panel.offset_top = -150.0
	settings_panel.offset_right = 196.0
	settings_panel.offset_bottom = 150.0
	settings_panel.z_index = 25
	# The same skin the quantum branch picker already uses, so the two panels on
	# this screen are recognisably the same object.
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("160706f2")
	skin.border_color = Color("9e2817")
	skin.set_border_width_all(2)
	skin.corner_radius_top_left = 8
	skin.corner_radius_top_right = 8
	skin.corner_radius_bottom_left = 8
	skin.corner_radius_bottom_right = 8
	skin.shadow_color = Color("000000cc")
	skin.shadow_size = 18
	skin.content_margin_left = 16.0
	skin.content_margin_right = 16.0
	skin.content_margin_top = 14.0
	skin.content_margin_bottom = 14.0
	settings_panel.add_theme_stylebox_override("panel", skin)
	var rows: Array = []
	for child in $HUD/SettingsPanel/VBox.get_children():
		rows.append(child)
	settings_plate = MENU_PLATE.new()
	settings_plate.name = "SettingsPlate"
	settings_plate.compact = true
	settings_panel.add_child(settings_plate)
	settings_plate.adopt(rows)


func _open_settings() -> void:
	if menu_departing:
		return
	_dress_settings_panel()
	settings_panel.visible = true


func _close_settings() -> void:
	settings_panel.visible = false


func _toggle_effects() -> void:
	menu_environment.glow_enabled = not menu_environment.glow_enabled
	effects_button.text = "BLOOM: %s" % ("ON" if menu_environment.glow_enabled else "OFF")


func _cycle_graphics() -> void:
	# Greg: "the FPS is about thirteen" fullscreen in the sandbox, and "the
	# settings look completely different when you enter Gore Sandbox or main
	# game". Both came from here. This only ever set `menu_environment.glow`,
	# so PERFORMANCE changed nothing that costs frames and changed nothing at
	# all outside this one screen — every other scene rebuilt its Environment
	# from scratch with volumetric fog and SSAO back on.
	#
	# Quality is now a single global on `WorldLook`, which every scene passes
	# through, so the setting reaches the Hunt, the derby, the vat and the
	# sandbox alike and the three of them stop disagreeing.
	graphics_index = (graphics_index + 1) % graphics_presets.size()
	var preset: String = graphics_presets[graphics_index]
	WorldLook.set_quality_name(preset)
	match preset:
		"ULTRA":
			get_viewport().scaling_3d_scale = 1.0
			get_viewport().msaa_3d = Viewport.MSAA_4X
			get_viewport().use_taa = true
		"HIGH":
			get_viewport().scaling_3d_scale = 0.9
			get_viewport().msaa_3d = Viewport.MSAA_2X
			get_viewport().use_taa = true
		_:
			get_viewport().scaling_3d_scale = 0.75
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().use_taa = false
	# Re-tune the live Environment too, so the change is visible on this screen
	# immediately rather than only after the next scene load.
	if menu_environment != null:
		WorldLook.apply_quality(menu_environment, WorldLook.PRESETS.get("front_door", {}))
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
	# "CELLOUTZ COPPER" is the default the door opens on, so it has to be the
	# door's own preset rather than `bone_yard` — otherwise touching the colour
	# setting once threw away the look the title screen was built around.
	var preset := "front_door"
	if mode == "SALVAGE TEAL":
		preset = "ashbloom"
	elif mode == "NIGHT BLOOD":
		preset = "ossuary"
	menu_environment = WorldLook.environment(preset)
	$WorldEnvironment.environment = menu_environment
	_use_canvas_background()
	$HUD/SettingsPanel/VBox/ColorGrade.text = "COLOR: %s" % mode


## Points the menu environment at the splash canvas. Called after the backdrop
## exists and again whenever the environment is swapped, because
## `WorldLook.environment()` hands back a fresh Environment each time and a new
## one does not remember that it was supposed to be showing a photograph.
func _use_canvas_background() -> void:
	if menu_environment == null:
		return
	menu_environment.background_mode = Environment.BG_CANVAS
	menu_environment.background_canvas_max_layer = SPLASH_CANVAS_LAYER


func _open_celloutz() -> void:
	WorldHistory.record_event("celloutz_site_opened", {"source": "main_menu"})
	OS.shell_open("https://celloutz.xyz/")


func _build_country_town() -> void:
	# The front door owns its own composed street and camera.  This node still
	# owns the settings Environment, but it must not build its old blockout under
	# that camera: those legacy boxes were the floating orange geometry in the
	# title shot.
	menu_environment = WorldLook.environment("front_door")
	$WorldEnvironment.environment = menu_environment
	_use_canvas_background()


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
