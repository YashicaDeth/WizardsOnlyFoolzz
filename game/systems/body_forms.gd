class_name BodyForms
extends RefCounted

## Nudity and its censor (Greg, 24 September: "then from there we can make
## nudity and censors"; the censor is a body-cam glitch and is on by default).
##
## The rig's flesh is a set of revolved limbs with no anatomy of its own, so a
## body with its clothes off read as a mannequin. This adds the forms the
## intake's ANATOMY row already asks about -- chest, groin, buttocks -- shaped
## by the rig's frame and anatomy, built clinically in its own flesh, and only
## where nothing is worn over them.
##
## `AnatomyPresentation` decides how they are shown. In MOSAIC (the default)
## each exposed region carries a volume whose shader re-reads the screen
## behind it as a breaking body-cam feed: the shape and the blood survive,
## the detail does not. EXPLICIT shows the forms as they are. Both modes are
## complete: every region has a form and a censor, or neither.

const GLITCH := preload("res://systems/censor_glitch.gdshader")

## The region, the zones whose clothing covers it (any one of the sets), where
## its censor volume sits on the torso, and its size. Front is -Z.
const REGIONS := {
	"chest": {"covered_by": [["torso"]], "at": Vector3(0.0, 0.12, -0.095), "size": Vector3(0.32, 0.17, 0.15)},
	"groin": {"covered_by": [["torso"], ["left_leg", "right_leg"]], "at": Vector3(0.0, -0.33, -0.03), "size": Vector3(0.2, 0.15, 0.17)},
	"buttocks": {"covered_by": [["torso"], ["left_leg", "right_leg"]], "at": Vector3(0.0, -0.27, 0.095), "size": Vector3(0.27, 0.17, 0.13)},
}

static var _glitch_material: ShaderMaterial


## Rebuild the forms and censors on `rig` for what it is wearing now.
static func refresh(rig: BaselineHuman) -> void:
	var torso := rig.parts.get("torso") as MeshInstance3D
	if torso == null or not is_instance_valid(torso):
		return
	for child in torso.get_children():
		var child_name := str(child.name)
		if child_name.begins_with("Nude_") or child_name.begins_with("Censor_"):
			torso.remove_child(child)
			child.queue_free()
	var explicit := AnatomyPresentation.is_explicit()
	for region: String in REGIONS:
		if not exposed(rig, region):
			continue
		_build_form(rig, torso, region)
		if not explicit:
			_build_censor(torso, region)


## Nothing worn over a region: no set of its covering zones is all clothed.
static func exposed(rig: BaselineHuman, region: String) -> bool:
	var spec: Dictionary = REGIONS.get(region, {})
	var no_shell: Array = rig.wardrobe.get("no_shell", [])
	for zones: Array in spec.get("covered_by", []):
		var all_covered := true
		for zone: String in zones:
			all_covered = all_covered and float(rig.wardrobe.get(zone, 0.0)) > 0.2 and not (zone in no_shell)
		if all_covered:
			return false
	return true


static func censored(rig: BaselineHuman, region: String) -> bool:
	var torso := rig.parts.get("torso") as Node3D
	return torso != null and torso.get_node_or_null("Censor_" + region) != null


static func _glitch() -> ShaderMaterial:
	if _glitch_material == null:
		_glitch_material = ShaderMaterial.new()
		_glitch_material.shader = GLITCH
		_glitch_material.render_priority = 10
	return _glitch_material


static func _build_censor(torso: MeshInstance3D, region: String) -> void:
	var spec: Dictionary = REGIONS[region]
	var box := BoxMesh.new()
	box.size = spec.size
	var node := MeshInstance3D.new()
	node.name = "Censor_" + region
	node.mesh = box
	node.position = spec.at
	node.material_override = _glitch()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torso.add_child(node)


static func _form(parent: Node3D, name_: String, at: Vector3, radius: float, squash: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = at
	node.scale = squash
	node.material_override = material
	parent.add_child(node)


## The forms themselves: simple and clinical, sized by the rig's frame (0 the
## narrowest, female-framed; 1 the broadest) and shaped by its anatomy.
static func _build_form(rig: BaselineHuman, torso: MeshInstance3D, region: String) -> void:
	var flesh: Material = torso.material_override
	var frame := rig.frame_factor
	match region:
		"chest":
			var fullness := clampf((0.55 - frame) / 0.4, 0.0, 1.0)
			for side in [-1.0, 1.0]:
				if fullness > 0.1:
					_form(torso, "Nude_chest_%d" % int(side), Vector3(side * 0.075, 0.115, -0.105), 0.05 + 0.03 * fullness, Vector3(1.0, 0.92, 0.85), flesh)
				else:
					_form(torso, "Nude_chest_%d" % int(side), Vector3(side * 0.08, 0.13, -0.105), 0.075, Vector3(1.1, 0.6, 0.32), flesh)
		"groin":
			var anatomy := rig.anatomy_sex
			if anatomy in ["male", "intersex"]:
				_form(torso, "Nude_groin", Vector3(0.0, -0.335, -0.085), 0.034, Vector3(0.85, 1.1, 0.95), flesh)
			if anatomy in ["female", "intersex", "unformed", "reconstructed"]:
				_form(torso, "Nude_groin_mound", Vector3(0.0, -0.3, -0.09), 0.045, Vector3(1.1, 0.7, 0.45), flesh)
			if anatomy == "reconstructed":
				var scar := MeshInstance3D.new()
				scar.name = "Nude_groin_scar"
				var line := BoxMesh.new()
				line.size = Vector3(0.07, 0.004, 0.004)
				scar.mesh = line
				scar.position = Vector3(0.0, -0.3, -0.112)
				var mark := StandardMaterial3D.new()
				mark.albedo_color = Color("5a2320")
				scar.material_override = mark
				torso.add_child(scar)
		"buttocks":
			for side in [-1.0, 1.0]:
				_form(torso, "Nude_buttock_%d" % int(side), Vector3(side * 0.07, -0.27, 0.085), 0.08, Vector3(1.0, 1.0, 0.75), flesh)
