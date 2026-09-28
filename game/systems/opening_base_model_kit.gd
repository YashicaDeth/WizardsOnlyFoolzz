extends Node3D

## Modular placeholder geometry for the first 30 minutes.
##
## These forms translate the supplied concept plates into playable scale without
## treating generated pixels as final production art. Every mesh advertises a
## stable `material_slot` and `replacement_id`, so authored models or textures
## can replace the placeholder without changing scene choreography.

const MATERIAL_SLOTS := [&"bone", &"iron", &"flesh", &"glass", &"signal", &"screen"]

var materials: Dictionary = {}
var sway_nodes: Array[Node3D] = []
var _clock := 0.0


func _init() -> void:
	materials = {
		&"bone": _material(Color("b2a586"), 0.0, 0.78),
		&"iron": _material(Color("49372d"), 0.68, 0.44),
		&"flesh": _material(Color("5a211e"), 0.0, 0.54),
		&"glass": _glass_material(),
		&"signal": _emissive_material(Color("b51e18"), 3.2),
		&"screen": _emissive_material(Color("72a96f"), 2.1),
	}


func _process(delta: float) -> void:
	_clock += delta
	for index in sway_nodes.size():
		var node := sway_nodes[index]
		if is_instance_valid(node):
			node.rotation.z = sin(_clock * (0.42 + float(index % 4) * 0.07) + float(index)) * 0.035


func apply_material_overrides(overrides: Dictionary) -> void:
	for slot in overrides:
		if slot in MATERIAL_SLOTS and overrides[slot] is Material:
			materials[slot] = overrides[slot]
	_rebind_materials(self)


func build_opening_dressing(aisle_length: float = 22.0) -> void:
	name = "OpeningBaseModelKit"
	build_vat_crown(Vector3.ZERO)
	build_ritual_plinth(Vector3.ZERO)
	build_cable_spine(Vector3(0.0, 4.0, -aisle_length * 0.42), aisle_length + 4.0)
	build_service_gantry(Vector3(-6.75, 0.0, -4.8), aisle_length - 2.0)
	build_service_gantry(Vector3(6.75, 0.0, -4.8), aisle_length - 2.0, true)
	build_observation_cluster(Vector3(-5.9, 0.15, -1.8), -1.0)
	build_observation_cluster(Vector3(5.9, 0.15, -8.2), 1.0)


func build_vat_crown(at: Vector3) -> Node3D:
	var root := _module("VatCrown", "opening/vat_crown", at)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.42
	ring.outer_radius = 1.68
	ring.rings = 24
	ring.ring_segments = 10
	_mesh(root, "CrownRing", ring, Vector3(0, 3.68, 0), Vector3.ZERO, &"iron", "opening/vat_crown/ring")
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var rib := CapsuleMesh.new()
		rib.radius = 0.09
		rib.height = 0.88
		var position := Vector3(cos(angle) * 1.53, 3.95, sin(angle) * 1.53)
		_mesh(root, "CrownRib%02d" % index, rib, position, Vector3(0, angle, angle + PI * 0.5), &"bone", "opening/vat_crown/rib")
	for index in 4:
		var cable := CylinderMesh.new()
		cable.top_radius = 0.055
		cable.bottom_radius = 0.085
		cable.height = 1.55 + float(index % 2) * 0.42
		var angle := TAU * float(index) / 4.0 + 0.38
		var cable_node := _mesh(root, "FeedCable%02d" % index, cable, Vector3(cos(angle) * 1.18, 4.7, sin(angle) * 1.18), Vector3(0.06, angle, 0.0), &"flesh", "opening/vat_crown/feed_cable")
		sway_nodes.append(cable_node)
	return root


func build_ritual_plinth(at: Vector3) -> Node3D:
	var root := _module("RitualPlinth", "opening/ritual_plinth", at)
	var base := CylinderMesh.new()
	base.top_radius = 2.16
	base.bottom_radius = 2.32
	base.height = 0.18
	base.radial_segments = 24
	_mesh(root, "Plinth", base, Vector3(0, 0.02, 0), Vector3.ZERO, &"iron", "opening/ritual_plinth/base")
	for index in 12:
		var mark := BoxMesh.new()
		mark.size = Vector3(0.08, 0.025, 0.46 if index % 3 else 0.72)
		var angle := TAU * float(index) / 12.0
		_mesh(root, "Inlay%02d" % index, mark, Vector3(cos(angle) * 1.86, 0.125, sin(angle) * 1.86), Vector3(0, -angle, 0), &"signal", "opening/ritual_plinth/inlay")
	return root


func build_cable_spine(at: Vector3, length: float) -> Node3D:
	var root := _module("CableSpine", "opening/cable_spine", at)
	var count := maxi(4, roundi(length / 1.35))
	for index in count:
		var z := -length * 0.5 + float(index) * length / float(count - 1)
		var vertebra := CapsuleMesh.new()
		vertebra.radius = 0.13
		vertebra.height = 0.58
		_mesh(root, "Vertebra%02d" % index, vertebra, Vector3(sin(float(index) * 0.72) * 0.12, 0.0, z), Vector3(PI * 0.5, 0, PI * 0.5), &"bone", "opening/cable_spine/vertebra")
		if index % 3 == 1:
			for side in [-1.0, 1.0]:
				var drop := CylinderMesh.new()
				drop.top_radius = 0.035
				drop.bottom_radius = 0.065
				drop.height = 0.95 + float(index % 4) * 0.18
				var node := _mesh(root, "Nerve_%02d_%s" % [index, "L" if side < 0.0 else "R"], drop, Vector3(side * 0.34, -0.55, z), Vector3(0, 0, side * 0.15), &"flesh", "opening/cable_spine/nerve")
				sway_nodes.append(node)
	return root


func build_service_gantry(at: Vector3, length: float, mirrored := false) -> Node3D:
	var root := _module("ServiceGantryR" if mirrored else "ServiceGantryL", "opening/service_gantry", at)
	var rail := BoxMesh.new()
	rail.size = Vector3(0.18, 0.18, length)
	_mesh(root, "UpperRail", rail, Vector3(0, 2.65, -length * 0.36), Vector3.ZERO, &"iron", "opening/service_gantry/rail")
	for index in maxi(3, roundi(length / 2.8)):
		var z := -float(index) * 2.8
		var upright := BoxMesh.new()
		upright.size = Vector3(0.14, 2.45, 0.14)
		_mesh(root, "Upright%02d" % index, upright, Vector3(0, 1.35, z), Vector3.ZERO, &"iron", "opening/service_gantry/upright")
		if index % 2 == 0:
			var lamp := BoxMesh.new()
			lamp.size = Vector3(0.11, 0.28, 0.42)
			_mesh(root, "WarningLamp%02d" % index, lamp, Vector3(-0.11 if mirrored else 0.11, 2.18, z), Vector3.ZERO, &"signal", "opening/service_gantry/warning_lamp")
	return root


func build_observation_cluster(at: Vector3, facing: float) -> Node3D:
	var root := _module("ObservationCluster", "opening/observation_cluster", at)
	root.rotation.y = facing * PI * 0.5
	var cabinet := BoxMesh.new()
	cabinet.size = Vector3(1.28, 1.78, 0.54)
	_mesh(root, "Cabinet", cabinet, Vector3(0, 0.9, 0), Vector3.ZERO, &"iron", "opening/observation_cluster/cabinet")
	for index in 3:
		var screen := QuadMesh.new()
		screen.size = Vector2(0.3, 0.28)
		_mesh(root, "Screen%02d" % index, screen, Vector3(-0.38 + float(index) * 0.38, 1.25, -0.282), Vector3.ZERO, &"screen", "opening/observation_cluster/screen")
	var hood := BoxMesh.new()
	hood.size = Vector3(1.48, 0.12, 0.78)
	_mesh(root, "Hood", hood, Vector3(0, 1.84, -0.06), Vector3(0.0, 0.0, -0.08 * facing), &"bone", "opening/observation_cluster/hood")
	return root


func build_pyramid_tier(at: Vector3, width: float, tier: int) -> Node3D:
	var root := _module("PyramidTier%02d" % tier, "index/pyramid_tier", at)
	var slab := BoxMesh.new()
	slab.size = Vector3(width, 0.24, maxf(0.7, width * 0.34))
	_mesh(root, "TierBody", slab, Vector3.ZERO, Vector3.ZERO, &"iron", "index/pyramid/tier_%02d" % tier)
	for side in [-1.0, 1.0]:
		var edge := BoxMesh.new()
		edge.size = Vector3(0.07, 0.08, maxf(0.72, width * 0.36))
		_mesh(root, "RankEdgeL" if side < 0.0 else "RankEdgeR", edge, Vector3(side * width * 0.47, 0.15, 0), Vector3.ZERO, &"signal", "index/pyramid/rank_edge")
	return root


func _module(node_name: String, replacement_id: String, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = at
	root.set_meta("placeholder_model", true)
	root.set_meta("replacement_id", replacement_id)
	add_child(root)
	return root


func _mesh(parent: Node3D, node_name: String, primitive: PrimitiveMesh, at: Vector3, rotation: Vector3, slot: StringName, replacement_id: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = primitive
	node.position = at
	node.rotation = rotation
	node.set_meta("placeholder_model", true)
	node.set_meta("material_slot", slot)
	node.set_meta("replacement_id", replacement_id)
	primitive.material = materials[slot]
	parent.add_child(node)
	return node


func _rebind_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D and child.has_meta("material_slot"):
			var slot: StringName = child.get_meta("material_slot")
			if materials.has(slot):
				(child as MeshInstance3D).material_override = materials[slot]
		_rebind_materials(child)


func _material(colour: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emissive_material(colour: Color, energy: float) -> StandardMaterial3D:
	var material := _material(colour, 0.15, 0.38)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	return material


func _glass_material() -> StandardMaterial3D:
	var material := _material(Color(0.22, 0.05, 0.045, 0.24), 0.05, 0.12)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
