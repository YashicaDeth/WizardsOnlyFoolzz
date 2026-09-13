class_name DamagePortrait
extends SubViewportContainer

## A live 3D bust of the driver in the HUD corner, turning slowly and taking the
## damage the player takes: blood, slump, a lost arm, an exposed jaw. Replaces a
## line of static title text with something that reports state at a glance.
##
## Damage-state portraits are an old HUD convention; this one is built from the
## project's own anatomy zones and materials.

const BLOOD := Color("6b0f0c")
const BONE := Color("cdbf9a")

var viewport: SubViewport
var rig: Node3D
var head: MeshInstance3D
var torso: MeshInstance3D
var arm_left: MeshInstance3D
var arm_right: MeshInstance3D
var spin := 0.0
var damage := 0.0
var shown_damage := 0.0
var wounds: Array[MeshInstance3D] = []
var shed_left := false
var shed_right := false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(168, 168)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	viewport = SubViewport.new()
	viewport.size = Vector2i(168, 168)
	viewport.transparent_bg = true
	# Its own world, or the bust is composited over whatever 3D scene the HUD
	# happens to be hanging in front of — in the derby that meant the quarry's
	# own ground and grandstand showing up behind the driver's head, inside a
	# bezel, which reads as a bug rather than as a portrait. The rig and the two
	# lights below are the entire contents of this world by design.
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = false
	add_child(viewport)

	var world := Node3D.new()
	viewport.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.0, 3.1)
	camera.fov = 38.0
	world.add_child(camera)

	var key := OmniLight3D.new()
	key.position = Vector3(1.4, 2.2, 1.8)
	key.light_color = Color("ffb271")
	key.light_energy = 2.6
	key.omni_range = 8.0
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.6, 1.2, 1.2)
	fill.light_color = Color("86a35c")
	fill.light_energy = 1.3
	fill.omni_range = 7.0
	world.add_child(fill)

	rig = Node3D.new()
	rig.position = Vector3(0, 0.45, 0)
	world.add_child(rig)

	# Cloth and plate use dry materials; only exposed skin gets the wet flesh
	# shader, or the whole bust glows like a lamp.
	torso = _part(rig, CapsuleMesh.new(), Vector3(0, 0.48, 0), Color("32291d"), Vector3(0.30, 0.52, 0.24), "dirt")
	_part(rig, SphereMesh.new(), Vector3(-0.26, 0.74, 0), Color("2b2318"), Vector3(0.16, 0.13, 0.15), "dirt")
	_part(rig, SphereMesh.new(), Vector3(0.26, 0.74, 0), Color("2b2318"), Vector3(0.16, 0.13, 0.15), "dirt")
	_part(rig, CapsuleMesh.new(), Vector3(0, 0.93, 0), Color("5a4a37"), Vector3(0.09, 0.07, 0.09), "flesh")
	head = _part(rig, SphereMesh.new(), Vector3(0, 1.08, 0), Color("6b5842"), Vector3(0.19, 0.22, 0.19), "flesh")
	# Welding visor: gives the head a front, so the bust has a facing.
	_part(head, BoxMesh.new(), Vector3(0, 0.1, 0.62), Color("14120f"), Vector3(0.95, 0.42, 0.3), "chrome")
	arm_left = _part(rig, CapsuleMesh.new(), Vector3(-0.33, 0.46, 0), Color("2b2318"), Vector3(0.11, 0.28, 0.11), "dirt")
	arm_right = _part(rig, CapsuleMesh.new(), Vector3(0.33, 0.46, 0), Color("2b2318"), Vector3(0.11, 0.28, 0.11), "dirt")
	arm_left.rotation.z = 0.22
	arm_right.rotation.z = -0.22
	set_process(true)


func _part(parent: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color, scale_value: Vector3, kind: String = "flesh") -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	mesh.material = WorldLook.surface(color, kind, int(at.x * 100.0) + 7)
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_value
	parent.add_child(instance)
	return instance


## 0 is untouched, 1 is wrecked.
func set_damage(ratio: float) -> void:
	damage = clampf(ratio, 0.0, 1.0)


func _process(delta: float) -> void:
	spin += delta * 0.55
	rig.rotation.y = sin(spin) * 0.65
	shown_damage = move_toward(shown_damage, damage, delta * 0.9)

	# Slump forward and list to one side as the driver fails.
	rig.rotation.x = shown_damage * 0.28
	head.rotation.z = shown_damage * 0.5
	head.position.y = 1.08 - shown_damage * 0.07
	torso.scale = Vector3(0.30 + shown_damage * 0.05, 0.52 - shown_damage * 0.07, 0.24)

	if shown_damage > 0.45 and not shed_left:
		shed_left = true
		arm_left.visible = false
		_stump(Vector3(-0.3, 0.6, 0))
	if shown_damage > 0.78 and not shed_right:
		shed_right = true
		arm_right.visible = false
		_stump(Vector3(0.3, 0.6, 0))

	var target_wounds := int(shown_damage * 7.0)
	while wounds.size() < target_wounds:
		var index := wounds.size()
		var angle := float(index) * 1.9
		var splat := _part(rig, SphereMesh.new(),
			Vector3(cos(angle) * 0.26, 0.45 + float(index) * 0.09, sin(angle) * 0.22 + 0.14),
			BLOOD, Vector3.ONE * (0.07 + float(index % 3) * 0.02))
		wounds.append(splat)


func _stump(at: Vector3) -> void:
	var stump := _part(rig, SphereMesh.new(), at, BLOOD, Vector3.ONE * 0.13)
	wounds.append(stump)
	var bone := _part(rig, CylinderMesh.new(), at + Vector3(0, -0.04, 0), BONE, Vector3(0.035, 0.09, 0.035))
	wounds.append(bone)
