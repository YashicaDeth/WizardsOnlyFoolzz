class_name XraySpecimen
extends SubViewport

## The loading screen's body, in actual 3D.
##
## Greg: *"we want the loading screens to be way more coherent with 3d visceral
## gore matrix loading screens and 3d organs bones xrays"*.
##
## The plate already had a specimen on it, but it was drawn in 2D with a fake
## Y-squash standing in for rotation — good enough to read as turning and never
## going to read as *radiographic*, because the thing that sells an X-ray is not
## the outline. It is **accumulation**: where two structures overlap, the film
## is brighter, and a ribcage seen through its own far side is the whole look.
## No 2D approximation gets that, so this renders a real rig into a viewport.
##
## It uses `BaselineHuman` rather than modelling a skeleton of its own, which is
## the same argument the rig was built for: the anatomy on the loading screen is
## then the anatomy of the world, and an organ that exists here is an organ you
## can rupture out there.

const RIG := preload("res://systems/baseline_human.gd")

## Additive, unshaded, depth-test off. Those three together are the radiograph:
## every surface adds light instead of occluding, so density reads as
## brightness and the far wall of the ribcage shows through the near one.
const BONE_TINT := Color(0.78, 0.86, 0.74)
const ORGAN_TINT := Color(0.72, 0.20, 0.16)
const FLESH_TINT := Color(0.18, 0.26, 0.22)

var spin_rate := 0.55
var clock := 0.0

var rig: Node3D
var _turntable: Node3D
var _beam: DirectionalLight3D
var _camera: Camera3D


static func make(specimen_seed: int = 0, resolution := Vector2i(760, 760)) -> XraySpecimen:
	var view := XraySpecimen.new()
	view.size = resolution
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_4X
	view._assemble(specimen_seed)
	return view


func _assemble(specimen_seed: int) -> void:
	var world := World3D.new()
	own_world_3d = true
	world_3d = world

	_turntable = Node3D.new()
	add_child(_turntable)

	rig = RIG.new()
	_turntable.add_child(rig)
	rig.build("interstitial_specimen", {
		"variation": 1 + absi(specimen_seed) % 24,
		"flesh": Color("7a6350"),
		"gore": false,
	})
	# Everything open. This is a scan, not a body.
	if rig.has_method("reveal_organs"):
		rig.reveal_organs(true)
	_radiograph(rig)

	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0.88, 3.15)
	_camera.rotation_degrees = Vector3(-4.0, 0, 0)
	_camera.fov = 42.0
	add_child(_camera)

	# One hard raking light. Unshaded materials ignore it, but the rig spawns
	# its own lit pieces for anything this pass cannot reach, and a scan with no
	# light at all loses the few surfaces that do shade.
	_beam = DirectionalLight3D.new()
	_beam.rotation_degrees = Vector3(-32.0, 34.0, 0.0)
	_beam.light_energy = 0.6
	_beam.light_color = Color(0.7, 0.9, 0.8)
	add_child(_beam)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.1, 0.14, 0.12)
	environment.ambient_light_energy = 0.5
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.25
	var camera_attributes := CameraAttributesPractical.new()
	_camera.environment = environment
	_camera.attributes = camera_attributes


## Walks the rig and replaces every surface with a radiographic one. Done as
## `material_override` so nothing about the rig itself is disturbed — the same
## body can be spawned into the world the ordinary way.
func _radiograph(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			mesh_instance.material_override = _film(_density_of(mesh_instance))
			# Nothing casts a shadow inside an X-ray.
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_radiograph(child)


## Bone is dense and stops the beam, so it prints brightest. Organs print warm
## and soft. Everything else is soft tissue, barely there — which is what makes
## the skeleton read through it.
func _density_of(mesh_instance: MeshInstance3D) -> Dictionary:
	var name_hint := mesh_instance.name.to_lower()
	var parent_hint := str(mesh_instance.get_parent().name).to_lower() if mesh_instance.get_parent() != null else ""
	var hint := name_hint + " " + parent_hint
	if hint.contains("bone") or hint.contains("skull") or hint.contains("rib") or hint.contains("spine"):
		return {"tint": BONE_TINT, "alpha": 0.62}
	for organ in ["heart", "lung", "liver", "gut", "brain", "kidney", "organ"]:
		if hint.contains(organ):
			return {"tint": ORGAN_TINT, "alpha": 0.40}
	return {"tint": FLESH_TINT, "alpha": 0.13}


func _film(density: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Additive is the whole trick: overlapping structures brighten instead of
	# hiding each other, which is exactly what a radiograph does.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.disable_receive_shadows = true
	var tint: Color = density["tint"]
	material.albedo_color = Color(tint.r, tint.g, tint.b, float(density["alpha"]))
	return material


## Turned on a table under the beam, and breathing. A specimen that only spins
## reads as an asset viewer; one that also rises and falls reads as alive, which
## is worse and therefore right.
func advance(delta: float) -> void:
	clock += delta
	if _turntable == null or not is_instance_valid(_turntable):
		return
	_turntable.rotation.y += delta * spin_rate
	_turntable.position.y = sin(clock * 1.6) * 0.012
	if _camera != null and is_instance_valid(_camera):
		# The rig lists back and forth a few degrees, so the scan never settles
		# into a turntable loop the eye can time.
		_camera.rotation_degrees.x = -4.0 + sin(clock * 0.37) * 3.0
		_camera.position.z = 3.15 + sin(clock * 0.23) * 0.22
