class_name VatBodyPreview
extends SubViewportContainer

## A body witness for the intake form.  It is deliberately constructed from
## the same BaselineHuman + HunterAppearance path as an overworld person, but
## it lives in its own tiny World3D so filing a form cannot mutate the real
## world, write ledger events, or depend on the player existing already.

const BASELINE_HUMAN := preload("res://systems/baseline_human.gd")
const HUNTER_APPEARANCE := preload("res://systems/hunter_appearance.gd")

const VIEW_SIZE := Vector2i(300, 440)

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var rig: BaselineHuman
var last_config: Dictionary = {}
var _clock := 0.0
var _signature := ""


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
	camera.position = Vector3(0.0, 1.12, -3.0)
	camera.fov = 34.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.90, 0.0), Vector3.UP)

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
	glass_mesh.height = 2.05
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
	glass.position = Vector3(0.0, 0.92, 0.0)
	stage.add_child(glass)

	var medium := MeshInstance3D.new()
	var medium_mesh := CylinderMesh.new()
	medium_mesh.top_radius = 0.67
	medium_mesh.bottom_radius = 0.67
	medium_mesh.height = 1.92
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
	medium.position = Vector3(0.0, 0.90, 0.0)
	stage.add_child(medium)

	# Collar and base only. A ring at the specimen's own head height would sit
	# straight across its face, which is the one thing this panel exists to show.
	for rib in [-0.02, 0.10, 1.80, 1.92]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.72
		torus.outer_radius = 0.78
		torus.material = WorldLook.surface(Color("2e2419"), "bone", 940 + int(rib * 10.0))
		ring.mesh = torus
		ring.position = Vector3(0.0, rib, 0.0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		stage.add_child(ring)

	# The tube. Greg's brief: "a tube in your mouth that's visible too." It hangs
	# from the tank's crown into the face, so the state the player is in is
	# visible on the body they are choosing rather than only described.
	var feed := MeshInstance3D.new()
	var feed_mesh := CylinderMesh.new()
	feed_mesh.top_radius = 0.020
	feed_mesh.bottom_radius = 0.016
	feed_mesh.height = 0.60
	feed_mesh.material = WorldLook.surface(Color("6b5a4a"), "flesh", 944)
	feed.mesh = feed_mesh
	# Off the centre line and down to the seated rig's mouth (head sits at y
	# 1.28 once the rig's own offset is added). Dead centre and thicker, it
	# bisected the face the panel exists to let the player read.
	feed.position = Vector3(0.055, 1.60, -0.115)
	feed.rotation_degrees = Vector3(10, 0, 0)
	stage.add_child(feed)


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
	config["seated"] = true
	last_config = config.duplicate(true)
	rig = BASELINE_HUMAN.new()
	rig.name = "IntakeSpecimen"
	rig.position = Vector3(0.0, 0.12, 0.0)
	stage.add_child(rig)
	var identity := str((normalized.get("appearance", {}) as Dictionary).get("name", "THE HUNTER"))
	rig.build("intake_preview_" + identity, config)
	var appearance_node := HUNTER_APPEARANCE.new()
	appearance_node.name = "PreviewAppearance"
	rig.add_child(appearance_node)
	appearance_node.configure(rig, normalized.get("appearance", {}) as Dictionary)


func _process(delta: float) -> void:
	_clock += delta
	if rig != null and is_instance_valid(rig):
		# Just enough movement to establish this as a body in a vat, not a menu
		# sprite.  It never spins all the way around or interrupts face reading.
		rig.rotation.y = sin(_clock * 0.42) * 0.22
		rig.rotation.z = sin(_clock * 0.66) * 0.025
