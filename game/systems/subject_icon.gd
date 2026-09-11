extends SubViewport

## A person's head, turning in place, with an X-ray state.
##
## Greg's note on the rank pyramid: *"i want the players or nemesis in the system
## to be icons at least spinning in 3d even if its just the head and then from
## there the 3d model is spinning with the xrays"*. This is that, and it is the
## first working piece of the Tier 1c inspection interface — the rule there is
## that a part must appear to *leave* the diagram rather than open a window, so
## the icon has to be a real 3D object composited into the panel rather than a
## pre-rendered sprite.
##
## Each icon owns its own `World3D`. That is the cost of the approach and it is
## why they are pooled by the caller rather than created per row: six small
## worlds at 128x128 is cheap, sixty would not be.
##
## The X-ray state is not a filter over the flesh. The skull is a real mesh from
## `BodyMesh.skull()` — the same geometry the rig builds bones from — sitting
## inside a head that goes translucent, so what you see through is the actual
## anatomy the kill cam and the dossier already read from.

const BONE := Color("d8cdb4")
const FLESH := Color("9a6c5c")

var xray := false
var spin_speed := 0.55
var elapsed := 0.0

var _pivot: Node3D
var _head: MeshInstance3D
var _skull: MeshInstance3D
var _head_material: StandardMaterial3D
var _subject_id := ""


func _ready() -> void:
	size = Vector2i(128, 128)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	disable_3d = false

	_pivot = Node3D.new()
	add_child(_pivot)

	_head = MeshInstance3D.new()
	_head.mesh = BodyMesh.head(0.28)
	_head_material = StandardMaterial3D.new()
	_head_material.albedo_color = FLESH
	_head_material.roughness = 0.85
	_head.material_override = _head_material
	_pivot.add_child(_head)

	_skull = MeshInstance3D.new()
	_skull.mesh = BodyMesh.skull(0.28)
	var bone_material := StandardMaterial3D.new()
	bone_material.albedo_color = BONE
	bone_material.roughness = 0.6
	bone_material.emission_enabled = true
	bone_material.emission = BONE * 0.22
	_skull.material_override = bone_material
	_skull.visible = false
	_pivot.add_child(_skull)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.42
	camera.position = Vector3(0, 0.02, 1.2)
	add_child(camera)

	# Two lights, deliberately hard and off-axis. A single front light flattens
	# a low-poly head into a silhouette, which is exactly the "primitive" read
	# the whole art direction is trying to get away from.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24, 34, 0)
	key.light_energy = 1.5
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(12, -140, 0)
	rim.light_energy = 0.9
	rim.light_color = Color("f06428")
	add_child(rim)

	set_process(true)


func set_subject(subject: Dictionary, tone: Color) -> void:
	_subject_id = str(subject.get("name", ""))
	_head_material.albedo_color = FLESH.lerp(tone, 0.34)
	# A destroyed head shows it in the flesh state rather than only in the file.
	var anatomy: Dictionary = subject.get("anatomy", {})
	var zones: Dictionary = anatomy.get("zones", {})
	var head_zone: Dictionary = zones.get("head", {})
	var health := float(head_zone.get("health", 100.0))
	if health < 60.0:
		_head_material.albedo_color = _head_material.albedo_color.lerp(Color("6d1f16"), 1.0 - health / 60.0)
	# Every subject turns at a slightly different rate, seeded off their name, so
	# a row of icons does not read as one object repeated.
	spin_speed = 0.42 + float(hash(_subject_id) % 40) * 0.006


func set_xray(on: bool) -> void:
	xray = on
	_skull.visible = on
	_head_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
	_head_material.albedo_color.a = 0.24 if on else 1.0
	# Culling the front faces off the translucent shell stops the head reading as
	# a solid tinted ball with a skull hidden somewhere behind it.
	_head_material.cull_mode = BaseMaterial3D.CULL_FRONT if on else BaseMaterial3D.CULL_BACK


func _process(delta: float) -> void:
	elapsed += delta
	_pivot.rotation.y = elapsed * spin_speed
	# A slight nod, so it reads as something being turned over and looked at
	# rather than a model on a turntable.
	_pivot.rotation.x = sin(elapsed * 0.7) * 0.09
