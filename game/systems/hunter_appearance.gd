class_name HunterAppearance
extends Node

## Replaceable procedural hero detail mounted directly on BaselineHuman zones.
## These names are the contract for later authored meshes and blend shapes.

var rig: BaselineHuman
var details: Dictionary = {}


func configure(body_rig: BaselineHuman) -> void:
	rig = body_rig
	_build_face()
	_build_hands()
	_build_feet()
	_build_clothing()
	_build_prosthetic_readout()
	sync_from_anatomy()


func _build_face() -> void:
	var head := rig.parts.head as Node3D
	_sphere(head, "Eye_L", Vector3(-0.048, 0.035, -0.103), Vector3(0.031, 0.022, 0.014), Color("d1d5ac"), "bone")
	_sphere(head, "Eye_R", Vector3(0.047, 0.026, -0.106), Vector3(0.022, 0.030, 0.012), Color("83c6bd"), "chrome")
	_sphere(head, "Pupil_L", Vector3(-0.050, 0.034, -0.116), Vector3(0.008, 0.010, 0.006), Color("12090a"), "dirt")
	_sphere(head, "Pupil_R", Vector3(0.050, 0.026, -0.118), Vector3(0.006, 0.012, 0.005), Color("8d1b16"), "flesh")
	_box(head, "Mouth_Upper", Vector3(0, -0.052, -0.112), Vector3(0.105, 0.014, 0.014), Color("451311"), "flesh")
	_box(head, "Mouth_Lower", Vector3(0.010, -0.078, -0.110), Vector3(0.088, 0.013, 0.014), Color("65201b"), "flesh")
	for tooth in 5:
		var tooth_height: float = 0.012 if tooth == 3 else (0.021 if tooth not in [1, 4] else 0.017)
		_box(head, "Tooth_%d" % tooth, Vector3(-0.038 + tooth * 0.019, -0.063 + (0.008 if tooth in [1, 4] else 0.0), -0.121), Vector3(0.013, tooth_height, 0.009), Color("a99b72"), "bone")


func _build_hands() -> void:
	for side in [-1, 1]:
		var zone_id: String = "left_arm" if side < 0 else "right_arm"
		var arm := rig.parts[zone_id] as Node3D
		_box(arm, "%s_Hand" % zone_id, Vector3(0, -0.335, -0.008), Vector3(0.095, 0.095, 0.055), Color("795e49"), "flesh")
		for finger in 5:
			var length: float = 0.060 - absf(float(finger - 2)) * 0.006
			_box(arm, "%s_Finger_%d" % [zone_id, finger], Vector3((finger - 2) * 0.018, -0.402 - length * 0.5, -0.015), Vector3(0.012, length, 0.018), Color("765944"), "flesh")


func _build_feet() -> void:
	for side in [-1, 1]:
		var zone_id: String = "left_leg" if side < 0 else "right_leg"
		var leg := rig.parts[zone_id] as Node3D
		_box(leg, "%s_Boot" % zone_id, Vector3(side * 0.006, -0.455, -0.075), Vector3(0.12, 0.09, 0.23), Color("25231f"), "cloth")
		_box(leg, "%s_Toecap" % zone_id, Vector3(side * 0.006, -0.455, -0.17), Vector3(0.125, 0.07, 0.07), Color("655b4e"), "metal")


## AS3.4. The coat's own colour now comes from whatever layer `clothing.gd`
## says this subject is wearing rather than one constant every body in the
## game shared — real on the body in the ordinary camera right now, whatever
## a not-yet-built literal mirror elsewhere in the project would also show.
func _build_clothing() -> void:
	var torso := rig.parts.torso as Node3D
	var tint := Color(str(Clothing.stats(rig.anatomy.subject_id).get("tint", "29271f")))
	_box(torso, "Coat_Front", Vector3(0, -0.06, -0.105), Vector3(0.34, 0.50, 0.045), tint, "cloth")
	_box(torso, "Collar_L", Vector3(-0.09, 0.24, -0.12), Vector3(0.12, 0.16, 0.035), tint.darkened(0.18), "cloth", Vector3(0, 0, -0.28))
	_box(torso, "Collar_R", Vector3(0.085, 0.21, -0.12), Vector3(0.11, 0.20, 0.035), tint.darkened(0.32), "cloth", Vector3(0, 0, 0.28))
	_box(torso, "Torque_Strap", Vector3(0.08, 0.02, -0.136), Vector3(0.055, 0.56, 0.025), Color("8a4426"), "metal", Vector3(0, 0, -0.28))


## AS3.4. For a layer worn mid-scene rather than at the moment the body was
## first built — re-tints the same pieces `_build_clothing()` already made
## rather than rebuilding the coat from scratch.
func sync_from_clothing() -> void:
	var tint := Color(str(Clothing.stats(rig.anatomy.subject_id).get("tint", "29271f")))
	var pairs := {
		"Coat_Front": tint,
		"Collar_L": tint.darkened(0.18),
		"Collar_R": tint.darkened(0.32),
	}
	for piece_name: String in pairs:
		var piece := details.get(piece_name) as MeshInstance3D
		if piece == null or piece.mesh == null:
			continue
		piece.mesh.material = WorldLook.surface(pairs[piece_name], "cloth", piece_name.hash())


func _build_prosthetic_readout() -> void:
	for zone_id in rig.anatomy.installed_parts:
		var limb := rig.parts.get(zone_id) as Node3D
		if limb == null:
			continue
		for band in 3:
			_box(limb, "%s_ServoBand_%d" % [zone_id, band], Vector3(0, -0.16 + band * 0.16, 0), Vector3(0.19, 0.035, 0.205), Color("b07646") if band == 1 else Color("727b78"), "metal")


func set_mouth(open_amount: float, injury_bias := 0.0) -> void:
	var lower := details.get("Mouth_Lower") as Node3D
	if lower != null:
		lower.position.y = -0.078 - clampf(open_amount, 0.0, 1.0) * 0.035
		lower.rotation.z = injury_bias * 0.16


func sync_from_anatomy() -> void:
	for index in rig.anatomy.wounds.size():
		var wound: Dictionary = rig.anatomy.wounds[index]
		var mark_name: String = "Wound_%d" % index
		if details.has(mark_name):
			continue
		var host := rig.parts.get(str(wound.get("zone", "torso"))) as Node3D
		if host == null:
			continue
		var y: float = -0.18 + fmod(float(index) * 0.137, 0.36)
		_box(host, mark_name, Vector3(0.02 if index % 2 == 0 else -0.025, y, -0.105), Vector3(0.09, 0.014, 0.018), Color("70110e"), "flesh", Vector3(0, 0, -0.32 + index * 0.11))


func _box(parent: Node3D, piece_name: String, at: Vector3, dimensions: Vector3, tint: Color, kind: String, turn := Vector3.ZERO) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = WorldLook.surface(tint, kind, piece_name.hash())
	piece.mesh = mesh
	piece.position = at
	piece.rotation = turn
	parent.add_child(piece)
	details[piece_name] = piece
	return piece


func _sphere(parent: Node3D, piece_name: String, at: Vector3, dimensions: Vector3, tint: Color, kind: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.material = WorldLook.surface(tint, kind, piece_name.hash())
	piece.mesh = mesh
	piece.position = at
	piece.scale = dimensions * 2.0
	parent.add_child(piece)
	details[piece_name] = piece
	return piece
