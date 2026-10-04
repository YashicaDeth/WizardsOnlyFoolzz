class_name VatBodyPreview
extends SubViewportContainer

## A body witness for the intake form.  It is deliberately constructed from
## the same BaselineHuman + HunterAppearance path as an overworld person, but
## it lives in its own tiny World3D so filing a form cannot mutate the real
## world, write ledger events, or depend on the player existing already.

const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")
const VAT_FLOAT := preload("res://systems/vat_float.gd")

const VIEW_SIZE := Vector2i(300, 440)

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var rig: BaselineHuman
var last_config: Dictionary = {}
var _clock := 0.0
var _signature := ""
## 0 frames the whole specimen, 1 pushes in to the face. Greg on first launch:
## the face sliders "are pretty fake" -- the axes do move the skull, by a
## centimetre or two, on a body framed from three metres away.
var face_focus := 0.0
## The Brain Index hub turns the body with the mouse; this is added to the
## idle sway, and freezes the sway while someone is holding it.
var spin_offset := 0.0
var held := false
var _focus_target := 0.0
## Greg, 25 September: the specimen floats rather than borrowing the seated
## driver layout. The motion node is shared with the real Growing Floor vats.
const FLOAT_Y := 0.34
const CROWN_Y := 2.58
var _head_y := 1.27
var vat_float: Node
var _feed: MeshInstance3D
var _cables: Array[MeshInstance3D] = []
const BODY_EYE := Vector3(0.0, 1.20, -3.9)
const BODY_LOOK := Vector3(0.0, 1.05, 0.0)
const FACE_EYE := Vector3(-0.16, 1.33, -0.98)
const FACE_LOOK := Vector3(0.0, 1.27, 0.0)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	viewport = SubViewport.new()
	viewport.name = "VatBodyPreviewWorld"
	viewport.size = VIEW_SIZE
	viewport.transparent_bg = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	stage = Node3D.new()
	stage.name = "SpecimenStage"
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.name = "PreviewEnvironment"
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("100609")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("5a2521")
	world_environment.ambient_light_energy = 0.45
	environment.environment = world_environment
	stage.add_child(environment)

	camera = Camera3D.new()
	camera.name = "SpecimenCamera"
	# BaselineHuman's face is built on its local negative-Z side.
	camera.position = BODY_EYE
	camera.fov = 34.0
	stage.add_child(camera)
	camera.look_at(BODY_LOOK, Vector3.UP)

	_add_light("WarmKey", Vector3(-1.2, 2.3, -1.6), Color("d76d45"), 2.7, 6.0)
	_add_light("ColdFill", Vector3(1.3, 1.25, -1.2), Color("728d83"), 1.25, 5.0)
	_add_light("BloodRim", Vector3(0.0, 0.85, 1.4), Color("8e1714"), 1.4, 4.0)
	_build_tank()
	set_process(true)


## The panel captioned itself "PREVIEW IS THROUGH GLASS" while showing a body
## on a flat black background: there was no glass, no medium and no tube, so
## the caption was doing the work the image was supposed to do. This builds the
## container the caption was already claiming -- the same tank the player is in,
## seen from outside, which is the whole point of the right-hand panel.
func _build_tank() -> void:
	var glass := MeshInstance3D.new()
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.72
	glass_mesh.bottom_radius = 0.72
	glass_mesh.height = 2.75
	glass_mesh.cap_top = false
	glass_mesh.cap_bottom = false
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.34, 0.11, 0.08, 0.17)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.metallic = 0.4
	glass_material.roughness = 0.12
	glass_mesh.material = glass_material
	glass.mesh = glass_mesh
	glass.position = Vector3(0.0, 1.27, 0.0)
	stage.add_child(glass)

	var medium := MeshInstance3D.new()
	var medium_mesh := CylinderMesh.new()
	medium_mesh.top_radius = 0.67
	medium_mesh.bottom_radius = 0.67
	medium_mesh.height = 2.62
	medium_mesh.cap_top = false
	medium_mesh.cap_bottom = false
	var medium_material := StandardMaterial3D.new()
	medium_material.albedo_color = Color(0.36, 0.022, 0.014, 0.16)
	medium_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	medium_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	medium_material.emission_enabled = true
	medium_material.emission = Color(0.19, 0.008, 0.004)
	medium_material.emission_energy_multiplier = 0.55
	medium_mesh.material = medium_material
	medium.mesh = medium_mesh
	medium.position = Vector3(0.0, 1.25, 0.0)
	stage.add_child(medium)

	# Collar and base only. A ring at the specimen's own head height would sit
	# straight across its face, which is the one thing this panel exists to show.
	# Elongated (Greg, 2026-09-24): a column taller than the body, not a jar.
	for rib in [-0.02, 0.10, 2.52, 2.64]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 0.78
		torus.material = WorldLook.surface(Color("2e2419"), "bone", 940 + int(rib * 10.0))
		ring.mesh = torus
		ring.position = Vector3(0.0, rib, 0.0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		stage.add_child(ring)

	# Real curved hoses follow the moving anatomy. A straight cylinder made the
	# mouth feed read as a rigid pole and left the requested skull wiring absent.
	_feed = _hose(0.013, Color("7a6552"), 944)
	_feed.name = "MouthFeed"
	for index in 3:
		var lead := _hose(0.009 - index * 0.0015, Color("201a1c"), 950 + index)
		lead.name = "SkullLead%d" % index
		_cables.append(lead)


func _hose(radius: float, tint: Color, seed_value: int) -> MeshInstance3D:
	var hose := MeshInstance3D.new()
	hose.mesh = ImmediateMesh.new()
	hose.material_override = WorldLook.surface(tint, "flesh", seed_value)
	hose.set_meta("radius", radius)
	stage.add_child(hose)
	return hose


const HOSE_SEGMENTS := 12
const HOSE_SIDES := 6


func _hang(hose: MeshInstance3D, from: Vector3, to: Vector3, sag: Vector3) -> void:
	var control := from.lerp(to, 0.5) + sag * 2.0
	var radius: float = hose.get_meta("radius", 0.01)
	var rings: Array = []
	for step in HOSE_SEGMENTS + 1:
		var t := float(step) / HOSE_SEGMENTS
		var point := from.lerp(control, t).lerp(control.lerp(to, t), t)
		var tangent := (control - from).lerp(to - control, t).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length() < 0.01:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var normal := side.cross(tangent).normalized()
		var ring: Array = []
		for corner in HOSE_SIDES:
			var angle := TAU * float(corner) / HOSE_SIDES
			var out := side * cos(angle) + normal * sin(angle)
			ring.append([point + out * radius, out])
		rings.append(ring)
	var mesh := hose.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in HOSE_SEGMENTS:
		for corner in HOSE_SIDES:
			var next := (corner + 1) % HOSE_SIDES
			var a: Array = rings[step][corner]
			var b: Array = rings[step][next]
			var c: Array = rings[step + 1][corner]
			var d: Array = rings[step + 1][next]
			for vertex in [a, c, b, b, c, d]:
				mesh.surface_set_normal(vertex[1])
				mesh.surface_add_vertex(vertex[0])
	mesh.surface_end()
	hose.set_meta("from", from)
	hose.set_meta("to", to)
	hose.visible = true


func _span_hoses() -> void:
	var all_hoses: Array = [_feed] + _cables
	if rig == null or not is_instance_valid(rig):
		for hose in all_hoses:
			if hose != null:
				hose.visible = false
		return
	var head := rig.parts.get("head") as Node3D
	var torso := rig.parts.get("torso") as Node3D
	if head == null or not is_instance_valid(head):
		return
	var head_at := head.global_position
	var forward := -rig.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var mouth := head_at + forward * 0.11 + Vector3.DOWN * 0.075
	var side := forward.cross(Vector3.UP).normalized()
	var feed_top := Vector3(0.0, CROWN_Y, 0.0) + side * 0.34 + forward * 0.22
	_hang(_feed, feed_top, mouth, side * 0.10 + forward * 0.08 + Vector3.DOWN * 0.16)
	var back := -forward
	var targets := [head_at + back * 0.10 + Vector3.UP * 0.03, head_at + back * 0.08 + Vector3.DOWN * 0.12]
	if torso != null and is_instance_valid(torso):
		targets.append(torso.global_position + back * 0.12 + Vector3.UP * 0.18)
	var tops := [Vector3(-0.30, CROWN_Y - 0.2, 0.0) + back * 0.62, Vector3(0.28, CROWN_Y - 0.15, 0.0) + back * 0.64, Vector3(0.04, CROWN_Y - 0.3, 0.0) + back * 0.66]
	for index in _cables.size():
		_hang(_cables[index], tops[index], targets[index], back * (0.10 + index * 0.04) + Vector3.DOWN * (0.34 + index * 0.08))


func _add_light(label: String, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	stage.add_child(light)


## Reads the form without calling CharacterSheet.apply_to_world().  A preview
## must be completely side-effect free: cycling a jaw is not a player action.
func present_sheet(sheet: CharacterSheet) -> void:
	var appearance: Dictionary = sheet.appearance.duplicate(true)
	appearance["name"] = sheet.display_name
	present({
		"race": sheet.race,
		# The ANATOMY row used to stop here: the sheet held it, the form drew it
		# back, and the body never saw it. It reaches the rig now, so cycling
		# that row visibly changes the specimen in the tank.
		"anatomy_sex": sheet.anatomy_sex,
		"appearance": appearance,
		"anatomy": {
			"blood_type": str(sheet.under_skin.get("blood", "O-RUST")),
			"skeleton": str(sheet.under_skin.get("skeleton", "standard")),
			"organ_set": str(sheet.under_skin.get("organs", "standard")),
		},
	})


func present(record: Dictionary) -> void:
	var normalized: Dictionary = record.duplicate(true)
	var next_signature := JSON.stringify(normalized)
	if next_signature == _signature and rig != null and is_instance_valid(rig):
		return
	_signature = next_signature
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	var config: Dictionary = BASELINE_HUMAN.config_from_subject(normalized)
	config["gore"] = false
	config["seated"] = false
	last_config = config.duplicate(true)
	rig = BASELINE_HUMAN.new()
	rig.name = "IntakeSpecimen"
	rig.position = Vector3(0.0, FLOAT_Y, 0.0)
	stage.add_child(rig)
	var identity := str((normalized.get("appearance", {}) as Dictionary).get("name", "THE HUNTER"))
	rig.build("intake_preview_" + identity, config)
	var appearance_node := HUNTER_APPEARANCE.new()
	appearance_node.name = "PreviewAppearance"
	rig.add_child(appearance_node)
	appearance_node.configure(rig, normalized.get("appearance", {}) as Dictionary)
	vat_float = VAT_FLOAT.new()
	rig.add_child(vat_float)
	vat_float.setup(rig, Vector3.ZERO, 0.67, 0.0, 2.62, 944, false)
	var head := rig.parts.get("head") as Node3D
	if head != null and is_instance_valid(head):
		_head_y = head.global_position.y


## N4.2: the weapon you have out is in this body's hand, on the hunters'
## wrist (HunterAppearance), parented to the arm.
## Empty puts it away.
func hold(weapon_id: String) -> void:
	if rig == null or not is_instance_valid(rig):
		return
	var arm := rig.parts.get("right_arm") as Node3D
	if arm == null:
		return
	var old := arm.get_node_or_null("HeldWeapon")
	if old != null:
		old.free()
	if weapon_id.is_empty():
		return
	var weapon := HeldGear.build_weapon("breach_nine" if weapon_id == "facility_sidearm" else weapon_id)
	if weapon == null:
		return
	weapon.name = "HeldWeapon"
	# Hanging from the fist and out to the side, facing the glass: the
	# hunters' forward mount points it straight at this camera.
	weapon.position = Vector3(0.0, -0.34, -0.07)
	weapon.rotation = Vector3(0.0, 0.0, PI * 0.62)
	arm.add_child(weapon)


## True on the FACE tab: the camera eases in to the head and back out.
func set_face_focus(on: bool) -> void:
	_focus_target = 1.0 if on else 0.0


func _process(delta: float) -> void:
	_clock += delta
	face_focus = move_toward(face_focus, _focus_target, delta * 1.8)
	if vat_float != null:
		vat_float.rotation_bias.y = spin_offset + (0.0 if held else sin(_clock * 0.42) * 0.15 * (1.0 - face_focus * 0.85))
		vat_float.advance(delta)
	var head := rig.parts.get("head") as Node3D if rig != null and is_instance_valid(rig) else null
	if head != null:
		_head_y = head.global_position.y
	if camera != null:
		var t := ease(face_focus, -2.0)
		var face_eye := FACE_EYE + Vector3(0.0, _head_y - FACE_LOOK.y, 0.0)
		var face_look := Vector3(FACE_LOOK.x, _head_y, FACE_LOOK.z)
		camera.position = BODY_EYE.lerp(face_eye, t)
		camera.look_at(BODY_LOOK.lerp(face_look, t), Vector3.UP)
	_span_hoses()


## Where each body part sits in this preview's own pixels, for clicking a part
## (the hub). Front-facing parts only: something turned away is not offered.
func part_positions() -> Dictionary:
	var out := {}
	if rig == null or not is_instance_valid(rig) or camera == null:
		return out
	for zone in rig.parts:
		var part := rig.parts[zone] as Node3D
		if part == null or not is_instance_valid(part) or not part.is_visible_in_tree():
			continue
		if camera.is_position_behind(part.global_position):
			continue
		var at := camera.unproject_position(part.global_position)
		# Viewport pixels to this container's pixels (stretch keeps them equal
		# in size, but the ratio is kept honest in case it is shrunk).
		var ratio := size / Vector2(viewport.size) if viewport.size.x > 0 else Vector2.ONE
		out[zone] = at * ratio
	return out
