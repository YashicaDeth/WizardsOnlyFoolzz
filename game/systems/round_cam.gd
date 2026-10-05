class_name RoundCam
extends Node

## Fix-56. Greg, 5 October (midday): an aimed X-ray shot wants "a slowed-down
## cutscene of the bullet entering and rupturing" -- follow the round from the
## muzzle, slow time, cut to X-ray as it enters the skin, show the organ or the
## bone rupturing, then hand play back.
##
## `KillCam` (the 2D plate) stays the execution's finisher; `GoreCam` is the
## derby's orbit. This is the firearm's: a camera of its own trails a drawn
## round from where it left the barrel to where it landed on the body, the
## body goes to the lab-48 X-ray (`BaselineHuman.reveal_organs` / `see_through`
## and `OrganSystem.sync_visuals`) just before contact, and the struck organ
## swells and bursts -- or, with no organ behind the hit, the bone splinters.
## The wound, the skull burst and the blood the hit already made are the real
## ones; this only slows them down and points a camera at them.
##
## Additive, like `GoreCam`: the host calls `trigger()` after the hit has
## resolved, checks `active` where it would check its own cutscenes, and the
## view comes back to whatever camera was current. Any button skips.

signal finished(skipped: bool)

## Unscaled seconds, start to hand-back.
const DURATION := 2.6
## The world's clock while it plays: the ragdoll, the blood and the burst
## move at this share of real speed.
const SLOW_SCALE := 0.08
## The round reaches the skin here; the X-ray cut comes just before it.
const FLIGHT_END := 1.0
const XRAY_AT := 0.8
const RUPTURE_AT := 1.15
## The view starts handing back here; the X-ray lifts with it.
const RETURN_AT := 2.25
## A skip is not read for this long, so the release of the shot that
## earned the camera cannot end it.
const SKIP_GRACE := 0.15
## The camera stops this far short of the skin; the orbit after is this wide.
const STOP_SHORT := 0.65
const ORBIT := 1.0
## How far the struck organ swells before it goes.
const SWELL := 1.3

## DIAL. How often it plays. A VATS round that lands always earns it; an
## ordinary killing shot earns it this share of the time; never two within
## `COOLDOWN` real seconds of each other. Zero turns a kind off.
static var vats_chance := 1.0
static var kill_chance := 0.35
const COOLDOWN := 6.0
static var force_in_tests := false

const BONE := Color("dbe7cd")
const FILM := Color("7fc8e8")
const ARTERIAL := Color("8e0f0b")
const COPPER := Color("b87333")

var active := false
var clock := 0.0
var skipped := false
var camera: Camera3D
## What the overlay prints: "VATS // HEART", "MERCY NINE // BRAIN".
var caption := ""
var xray_on := false
var ruptured := false

var _previous: Camera3D
var _hud: CanvasLayer
var _overlay: CanvasLayer
var _muzzle := Vector3.ZERO
var _impact := Vector3.ZERO
var _direction := Vector3.FORWARD
var _side := Vector3.RIGHT
var _rig: BaselineHuman
var _organ: Node3D
var _organ_scale := Vector3.ONE
var _zone := "torso"
var _keep_xray := false
var _slug: Node3D
var _debris: Array[Dictionary] = []
var _orbit_from := Transform3D.IDENTITY
var _handback_from := Transform3D.IDENTITY
var _hidden_labels: Array[Label3D] = []
var _film: Environment
static var _last_played_ms := -1000000


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Whether this shot earns the camera. `roll` is 0..1 (the caller's random
## draw, so a test can pin it); a shot that neither was aimed through VATS nor
## killed never does.
static func wanted(vats: bool, killed: bool, roll: float, seconds_since_last: float = INF) -> bool:
	# A cutscene that takes input away would make every other headless
	# suite that shoots somebody depend on a dice roll; off under
	# ATG_TEST_MODE unless a test asks for it (as `AmbientBed` does).
	if OS.get_environment("ATG_TEST_MODE") == "1" and not force_in_tests:
		return false
	if seconds_since_last < COOLDOWN:
		return false
	if vats:
		return roll < vats_chance
	if killed:
		return roll < kill_chance
	return false


static func seconds_since_last() -> float:
	return float(Time.get_ticks_msec() - _last_played_ms) / 1000.0


## `muzzle` is where the round left the barrel, `impact` where it met the
## body, `rig` the body (may be null: the flight still plays), `organ_id` the
## organ it burst ("" for a bone/limb hit), `zone` the zone it landed in.
## `hud` is put away for the shot. `keep_xray`: the player had the X-ray on
## already, so the body stays revealed afterwards.
func trigger(muzzle: Vector3, impact: Vector3, rig: BaselineHuman, organ_id: String, zone: String, label: String, hud: CanvasLayer = null, keep_xray := false) -> bool:
	if active or not is_inside_tree():
		return false
	var viewport_camera := get_viewport().get_camera_3d()
	if viewport_camera == null:
		return false
	active = true
	skipped = false
	clock = 0.0
	xray_on = false
	ruptured = false
	caption = label.to_upper()
	_previous = viewport_camera
	_muzzle = muzzle
	_impact = impact
	_direction = impact - muzzle
	if _direction.length_squared() < 0.0001:
		_direction = -viewport_camera.global_basis.z
	_direction = _direction.normalized()
	_side = _direction.cross(Vector3.UP)
	_side = _side.normalized() if _side.length_squared() > 0.0001 else Vector3.RIGHT
	_rig = rig if rig != null and is_instance_valid(rig) else null
	_zone = zone
	_keep_xray = keep_xray
	_organ = null
	if _rig != null and not organ_id.is_empty():
		_organ = _rig.organ_parts.get(organ_id) as Node3D
		if _organ != null and not is_instance_valid(_organ):
			_organ = null
	if _organ != null:
		_organ_scale = _organ.scale
	_last_played_ms = Time.get_ticks_msec()

	camera = Camera3D.new()
	camera.name = "RoundCamera"
	camera.fov = 50.0
	camera.near = 0.01
	get_parent().add_child(camera)
	# The X-ray's own lamp: cold, close, only while the film is on, so the
	# bone and the organs carry the frame instead of the yard's light.
	var lamp := OmniLight3D.new()
	lamp.name = "XrayLamp"
	lamp.light_color = Color("cfe6f0")
	lamp.light_energy = 3.0
	lamp.omni_range = 3.5
	lamp.shadow_enabled = false
	lamp.visible = false
	camera.add_child(lamp)
	_build_slug()
	_build_overlay()
	_hud = hud if hud != null and hud.visible else null
	if _hud != null:
		_hud.visible = false
	_hide_labels()
	var world_environment := get_viewport().world_3d.environment if get_viewport().world_3d != null else null
	if world_environment != null:
		# Under the X-ray the world drains to cold film; the body's bones and
		# glowing organs are what is left with any colour.
		_film = world_environment.duplicate() as Environment
		_film.adjustment_enabled = true
		_film.adjustment_saturation = 0.6
		_film.adjustment_brightness = 0.85
		_film.adjustment_contrast = 1.25
	_place(0.0)
	camera.make_current()
	Engine.time_scale = SLOW_SCALE
	return true


## World labels over the body (its name, its loot) are HUD in the world. The
## kill that earned the shot hangs its loot label a frame or two after the
## trigger, so this runs again over the opening frames.
func _hide_labels() -> void:
	for found in get_tree().root.find_children("*", "Label3D", true, false):
		var tag := found as Label3D
		if tag.visible and tag.is_inside_tree() and tag.global_position.distance_to(_impact) < 3.0:
			tag.visible = false
			_hidden_labels.append(tag)


func skip() -> void:
	if active:
		finish(true)


func _input(event: InputEvent) -> void:
	if not active:
		return
	# The cutscene owns input while it plays: nothing reaches the host.
	get_viewport().set_input_as_handled()
	if clock < SKIP_GRACE or event.is_echo():
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed:
		skip()


func _process(delta: float) -> void:
	if not active:
		return
	# Unscaled time, or the shot would also be slowed by its own effect.
	clock += delta / maxf(Engine.time_scale, 0.001)
	if clock >= DURATION:
		finish(false)
		return
	if not xray_on and clock >= XRAY_AT and clock < RETURN_AT:
		_set_xray(true)
	if not ruptured and clock >= RUPTURE_AT:
		_rupture()
	if xray_on and clock >= RETURN_AT:
		_set_xray(_keep_xray)
		xray_on = false
	if clock >= RETURN_AT:
		# Time comes back up with the view.
		Engine.time_scale = lerpf(SLOW_SCALE, 1.0, clampf((clock - RETURN_AT) / (DURATION - RETURN_AT), 0.0, 1.0))
	if clock < 0.5:
		_hide_labels()
	_tick_debris(delta)
	_place(clock)
	if _overlay != null:
		(_overlay.get_child(0) as Control).queue_redraw()


func finish(was_skipped := false) -> void:
	if not active:
		return
	active = false
	skipped = was_skipped
	Engine.time_scale = 1.0
	_set_xray(_keep_xray)
	xray_on = false
	if _organ != null and is_instance_valid(_organ):
		_organ.scale = _organ_scale
		if _rig != null and is_instance_valid(_rig):
			# The rig is the authority on whether a ruptured organ still shows.
			_rig.reveal_organs(_keep_xray)
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	_hud = null
	if is_instance_valid(_previous):
		_previous.make_current()
	for tag in _hidden_labels:
		if is_instance_valid(tag):
			tag.visible = true
	_hidden_labels.clear()
	for node in [camera, _slug, _overlay]:
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	for piece in _debris:
		if is_instance_valid(piece.node):
			(piece.node as Node).queue_free()
	_debris.clear()
	camera = null
	_slug = null
	_overlay = null
	finished.emit(was_skipped)


func _exit_tree() -> void:
	if active:
		Engine.time_scale = 1.0


## Where the struck thing is now: the organ, the zone it landed in, or the
## point of entry if the body has gone.
func _focus() -> Vector3:
	if _organ != null and is_instance_valid(_organ) and _organ.is_inside_tree():
		return _organ.global_position
	if _rig != null and is_instance_valid(_rig):
		var part := _rig.parts.get(_zone) as Node3D
		if part != null and is_instance_valid(part) and part.is_inside_tree():
			return part.global_position
	return _impact


## The round's place on the unscaled clock: quick out of the barrel, slowing
## to a crawl at the skin, then on through the body.
func _round_at(t: float) -> Vector3:
	if t <= FLIGHT_END:
		var u := clampf(t / FLIGHT_END, 0.0, 1.0)
		return _muzzle.lerp(_impact, 1.0 - pow(1.0 - u, 2.2))
	return _impact + _direction * (t - FLIGHT_END) * 0.22


func _place(t: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var round_at := _round_at(t)
	if _slug != null and is_instance_valid(_slug):
		_slug.global_position = round_at
		_slug.visible = t < RETURN_AT
	var view: Transform3D
	if t <= FLIGHT_END:
		# Riding behind and beside the round, and pulling up short of the
		# body so the round is seen going in rather than the camera going in.
		var u := clampf(t / FLIGHT_END, 0.0, 1.0)
		var stop := _impact - _direction * STOP_SHORT
		var along := 1.0 - pow(1.0 - u, 2.2)
		var rail := _muzzle.lerp(stop, along) if _muzzle.distance_to(_impact) > STOP_SHORT else stop
		var at := rail - _direction * 0.18 + _side * 0.1 + Vector3.UP * 0.05
		var look := (round_at + _direction * 0.4).lerp(_impact, smoothstep(0.4, 1.0, u))
		view = Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
		_orbit_from = view
	else:
		# Round the wound, slowly, from the side the round passed.
		var swing := ease(clampf((t - FLIGHT_END) / (RETURN_AT - FLIGHT_END), 0.0, 1.0), -1.4) * 0.9
		var focus := _focus()
		var out := (_side * cos(swing) - _direction * sin(swing)) * ORBIT + Vector3.UP * 0.18
		var at := focus + out
		view = Transform3D(Basis.looking_at(focus - at, Vector3.UP), at)
		var settle := clampf((t - FLIGHT_END) / 0.18, 0.0, 1.0)
		if settle < 1.0:
			view = _orbit_from.interpolate_with(view, smoothstep(0.0, 1.0, settle))
		_handback_from = view
	if t >= RETURN_AT and is_instance_valid(_previous):
		var back := clampf((t - RETURN_AT) / (DURATION - RETURN_AT), 0.0, 1.0)
		view = _handback_from.interpolate_with(_previous.global_transform, smoothstep(0.0, 1.0, back))
	camera.global_transform = view


func _set_xray(on: bool) -> void:
	xray_on = on
	if camera != null and is_instance_valid(camera):
		camera.environment = _film if on else null
		(camera.get_node("XrayLamp") as Light3D).visible = on
	if _rig == null or not is_instance_valid(_rig):
		return
	_rig.reveal_organs(on)
	_rig.see_through(on)
	OrganSystem.sync_visuals(_rig, on)
	if on and _organ != null and is_instance_valid(_organ) and not ruptured:
		# Ruptured by the hit already; it is shown whole until the round
		# reaches it, which is the moment the camera is about.
		_organ.visible = true


## The organ swells and goes, spraying; with no organ, the bone splinters.
func _rupture() -> void:
	ruptured = true
	var at := _focus()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if _organ != null and is_instance_valid(_organ):
		_organ.scale = _organ_scale * SWELL
		_spawn_debris(at, 26, ARTERIAL, Vector3(0.012, 0.012, 0.012), 1.8, rng)
	else:
		_spawn_debris(at, 9, BONE, Vector3(0.008, 0.008, 0.04), 1.2, rng)
		_spawn_debris(at, 14, ARTERIAL, Vector3(0.01, 0.01, 0.01), 1.4, rng)


func _spawn_debris(at: Vector3, count: int, tint: Color, size: Vector3, speed: float, rng: RandomNumberGenerator) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.35
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.6
	material.no_depth_test = true
	material.render_priority = 6
	var mesh := BoxMesh.new()
	mesh.size = size
	for index in count:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(piece)
		piece.global_position = at
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		# Mostly on along the round's line, the rest out in a cone.
		var cone := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var velocity := (_direction * 1.2 + cone).normalized() * speed * rng.randf_range(0.5, 1.2)
		_debris.append({"node": piece, "velocity": velocity, "spin": rng.randf_range(-9, 9)})


## Scaled time: the spray is part of the slowed world.
func _tick_debris(delta: float) -> void:
	if _organ != null and is_instance_valid(_organ) and ruptured:
		# Swollen at the hit, then it empties out.
		_organ.scale = _organ_scale * lerpf(SWELL, 0.2, clampf((clock - RUPTURE_AT) / 0.6, 0.0, 1.0))
	for piece in _debris:
		var node := piece.node as Node3D
		if not is_instance_valid(node):
			continue
		piece.velocity = (piece.velocity as Vector3) + Vector3.DOWN * 9.8 * delta
		node.global_position += (piece.velocity as Vector3) * delta
		node.rotate_x(float(piece.spin) * delta)


func _build_slug() -> void:
	_slug = Node3D.new()
	_slug.name = "RoundCamSlug"
	get_parent().add_child(_slug)
	_slug.global_basis = Basis.looking_at(_direction, Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = COPPER
	metal.metallic = 0.9
	metal.roughness = 0.25
	metal.emission_enabled = true
	metal.emission = COPPER.darkened(0.4)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.0045
	capsule.height = 0.019
	body.mesh = capsule
	body.material_override = metal
	body.rotation.x = PI * 0.5
	_slug.add_child(body)
	# The air it pushes: a short heat streak behind it.
	var streak := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.002
	tube.bottom_radius = 0.0003
	tube.height = 0.16
	streak.mesh = tube
	var haze := StandardMaterial3D.new()
	haze.albedo_color = Color(1.0, 0.86, 0.66, 0.28)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak.material_override = haze
	streak.rotation.x = PI * 0.5
	streak.position.z = 0.09
	_slug.add_child(streak)


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "RoundCamOverlay"
	_overlay.layer = 60
	get_parent().add_child(_overlay)
	var bars := _Bars.new()
	bars.cam = self
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bars)


## Letterbox, the X-ray's cold film over the frame while it is on, the caption
## in the house stencil, and the skip.
class _Bars extends Control:
	var cam: RoundCam

	func _draw() -> void:
		if cam == null or not cam.active:
			return
		var t := cam.clock
		var open := clampf(t / 0.2, 0.0, 1.0) * clampf((RoundCam.DURATION - t) / 0.3, 0.0, 1.0)
		var bar := size.y * 0.11 * open
		draw_rect(Rect2(0, 0, size.x, bar), Color.BLACK)
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color.BLACK)
		if cam.xray_on:
			draw_rect(Rect2(0, bar, size.x, size.y - bar * 2.0), Color(RoundCam.FILM, 0.12))
			for y in range(int(bar), int(size.y - bar), 4):
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.1), 1.0)
		if open > 0.5:
			CellOutzType.draw_text(self, Vector2(28, size.y - bar + bar * 0.32), cam.caption, 14.0, Color(RoundCam.BONE, open), 1.2)
			var hint := "ANY BUTTON SKIPS"
			CellOutzType.draw_text(self, Vector2(size.x - 28 - CellOutzType.width(hint, 9.0, 1.0), size.y - bar + bar * 0.4), hint, 9.0, Color(RoundCam.BONE, 0.5 * open), 1.0)
