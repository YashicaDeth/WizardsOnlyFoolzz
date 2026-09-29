extends Node3D
## ModelSkin: Greg's generated, rigged examiner (Higgsfield / Meshy from his M1
## turnaround sheet, 29 September) riding on a BaselineHuman.
##
## The rule this obeys (WORKING_NOW.md): a generated model on a person is a SKIN
## on BaselineHuman's zones, never a replacement for the rig. Gore, wounds,
## dismemberment, organs and the X-ray kill cam are all BaselineHuman's, so:
##
##  - the model's one skinned mesh is split into the rig's six zones by bone
##    weight, so each zone shows or hides on its own;
##  - a zone shows the SKIN only while it is pristine: no wound mark, no
##    exposed layer, not severed, above the bruise line, and no X-ray. While it
##    shows the skin, the rig's own flesh, garment and gear on that zone are
##    hidden and the skin takes the bruise tint the flesh would have had;
##  - the first time anything gory happens to a zone, that zone goes straight
##    back to the rig's own body, which is exactly what it showed before this
##    file existed. Nothing here draws a wound, so nothing here can hide one.
##
## Motion comes from the generated walk and idle clips (the meshes inside those
## files are 339-triangle proxies; only their clips are used). A wind-up raises
## the arms through a SkeletonModifier3D so the fight's telegraphs stay legible,
## and his scalpel and syringe ride his hands while those arms show the skin.
##
## `attach()` returns null, touching nothing, when the media is missing (an LFS
## checkout without it), and the caller keeps the drawn examiner.

const MODEL := "res://art/generated/characters/examiner.glb"
const CLIPS := {
	"idle": "res://art/generated/characters/examiner_idle.glb",
	"walk": "res://art/generated/characters/examiner_walk.glb",
}
## Measured (tests/model_capture --mode=skeleton): head_end at 180.7 cm.
const MODEL_HEIGHT := 1.8
const WALK_SPEED := 1.4
const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
const ZONE_OF_BONE := {
	"Head": "head", "head_end": "head", "headfront": "head",
	"neck": "torso", "Hips": "torso", "Spine": "torso", "Spine01": "torso", "Spine02": "torso",
	"LeftShoulder": "torso", "RightShoulder": "torso",
	"LeftArm": "left_arm", "LeftForeArm": "left_arm", "LeftHand": "left_arm",
	"RightArm": "right_arm", "RightForeArm": "right_arm", "RightHand": "right_arm",
	"LeftUpLeg": "left_leg", "LeftLeg": "left_leg", "LeftFoot": "left_leg", "LeftToeBase": "left_leg",
	"RightUpLeg": "right_leg", "RightLeg": "right_leg", "RightFoot": "right_leg", "RightToeBase": "right_leg",
}
## What the rig keeps showing on a zone the skin covers: nothing of its own
## except the things only gore creates (which appear only once the zone has left
## skin mode anyway).
const KEEP := ["Wounds", "LayerExposure"]
const BRUISE_TINT := Color("b06a78")
## How far along the hand, from the wrist, a held tool is centred. His idle hand
## is an open palm, so a tool seated in the palm is buried in the flesh: this
## puts most of it out past the fingertips, where it can be seen.
const HAND_TOOL_REACH := 0.17


## Cocks the upper arms back by the given radians about the skeleton's lateral
## axis, after the animation has posed them (the fight's wind-up telegraph).
class ArmRaise extends SkeletonModifier3D:
	var raise := {"RightArm": 0.0, "LeftArm": 0.0}

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		if skeleton == null:
			return
		for bone_name: String in raise:
			var amount: float = raise[bone_name]
			if absf(amount) < 0.001:
				continue
			var bone := skeleton.find_bone(bone_name)
			if bone < 0:
				continue
			var parent := skeleton.get_bone_parent(bone)
			var parent_turn := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
			var extra := Quaternion(Vector3.RIGHT, amount)
			skeleton.set_bone_pose_rotation(bone, parent_turn.inverse() * extra * parent_turn * skeleton.get_bone_pose_rotation(bone))


var body: BaselineHuman
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var raise_modifier: ArmRaise
var zone_meshes: Dictionary = {}
var zone_materials: Dictionary = {}
var triangles_by_zone: Dictionary = {}
var modes: Dictionary = {}
var retired := false

var _hidden: Dictionary = {}
var _last_position := Vector3.ZERO
var _speed := 0.0
var _clip := ""
var _bruise: Dictionary = {}
var _tools: Dictionary = {}


## The skin for `host`, or null (nothing touched) when the media is missing.
static func attach(host: BaselineHuman) -> Node3D:
	if host == null or not ResourceLoader.exists(MODEL):
		return null
	for clip: String in CLIPS:
		if not ResourceLoader.exists(str(CLIPS[clip])):
			return null
	var skin: Node3D = load("res://systems/model_skin.gd").new()
	host.add_child(skin)
	if skin.build(host):
		return skin
	host.remove_child(skin)
	skin.free()
	return null


func build(host: BaselineHuman) -> bool:
	name = "ModelSkin"
	body = host
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return false
	model = scene.instantiate() as Node3D
	if model == null:
		return false
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source: MeshInstance3D = null
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			source = node as MeshInstance3D
			break
	if skeleton == null or player == null or source == null or not _load_clips():
		return false
	if not _split(source):
		return false
	# Faces -Z like the rig, and stands as tall as the rig does. The rig's own
	# root scale (the examiner's tall, gaunt proportions) then applies to both.
	model.rotation.y = PI
	model.scale = Vector3.ONE * (_rig_height() / MODEL_HEIGHT)
	raise_modifier = ArmRaise.new()
	raise_modifier.name = "ArmRaise"
	skeleton.add_child(raise_modifier)
	_last_position = body.global_position
	_play("idle", 1.0)
	return true


## Where the rig's head ends, from the same layout its parts were built from.
func _rig_height() -> float:
	var layout: Dictionary = body.get("_layout") if body.get("_layout") != null else {}
	var head: Dictionary = layout.get("head", {})
	if head.is_empty():
		return MODEL_HEIGHT
	return float((head.at as Vector3).y + (head.size as Vector3).y * 0.5)


## The generated walk and idle clips, retargeted by bone name (same rig), made
## to loop, and made in-place (no root drift) so the body root owns movement.
func _load_clips() -> bool:
	var library := player.get_animation_library("")
	if library == null:
		library = AnimationLibrary.new()
		player.add_animation_library("", library)
	for clip: String in CLIPS:
		var holder := (load(str(CLIPS[clip])) as PackedScene).instantiate()
		var source_player := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var best: Animation = null
		if source_player != null:
			for animation_name in source_player.get_animation_list():
				var candidate := source_player.get_animation(animation_name)
				if best == null or candidate.length > best.length:
					best = candidate
		if best == null:
			holder.free()
			return false
		var animation := best.duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":Hips") and animation.track_get_key_count(track) > 0:
				var first: Vector3 = animation.track_get_key_value(track, 0)
				for key in animation.track_get_key_count(track):
					var value: Vector3 = animation.track_get_key_value(track, key)
					animation.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, animation)
		holder.free()
	return true


## The one skinned mesh becomes six, one per rig zone, all on the same skeleton
## and skin. Every triangle lands in exactly one zone: the one carrying most of
## the bone weight of its three vertices.
func _split(source: MeshInstance3D) -> bool:
	var mesh := source.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if vertices.is_empty() or bone_ids.is_empty() or weights.is_empty():
		return false
	var stride := bone_ids.size() / vertices.size()
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		indices.resize(vertices.size())
		for index in vertices.size():
			indices[index] = index
	var skin := source.skin
	var bind_zone := PackedInt32Array()
	for bind in skin.get_bind_count():
		var bone_name := skin.get_bind_name(bind)
		if bone_name.is_empty():
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(bind))
		bind_zone.append(ZONES.find(str(ZONE_OF_BONE.get(bone_name, "torso"))))
	var vertex_weight := PackedFloat32Array()
	vertex_weight.resize(vertices.size() * ZONES.size())
	for vertex in vertices.size():
		for slot in stride:
			var weight := weights[vertex * stride + slot]
			if weight > 0.0:
				var bind := bone_ids[vertex * stride + slot]
				if bind >= 0 and bind < bind_zone.size():
					vertex_weight[vertex * ZONES.size() + bind_zone[bind]] += weight
	var zone_indices: Dictionary = {}
	for zone: String in ZONES:
		zone_indices[zone] = PackedInt32Array()
	for triangle in indices.size() / 3:
		var best_zone := 0
		var best_weight := -1.0
		for zone_index in ZONES.size():
			var total := 0.0
			for corner in 3:
				total += vertex_weight[indices[triangle * 3 + corner] * ZONES.size() + zone_index]
			if total > best_weight:
				best_weight = total
				best_zone = zone_index
		var list: PackedInt32Array = zone_indices[ZONES[best_zone]]
		list.append(indices[triangle * 3])
		list.append(indices[triangle * 3 + 1])
		list.append(indices[triangle * 3 + 2])
		zone_indices[ZONES[best_zone]] = list
	var base := mesh.surface_get_material(0) as BaseMaterial3D
	var flags := int(mesh.surface_get_format(0)) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	for zone: String in ZONES:
		var list: PackedInt32Array = zone_indices[zone]
		triangles_by_zone[zone] = list.size() / 3
		var zone_arrays := arrays.duplicate()
		zone_arrays[Mesh.ARRAY_INDEX] = list
		var zone_mesh := ArrayMesh.new()
		zone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, zone_arrays, [], {}, flags)
		# The imported material is metallic and self-lit (it reads as a white
		# glow in a dark lab): plain cloth and skin, lit by the room.
		var material: BaseMaterial3D = base.duplicate() as BaseMaterial3D if base != null else StandardMaterial3D.new()
		material.metallic = 0.0
		material.roughness = 0.9
		material.emission_enabled = false
		zone_materials[zone] = material
		var instance := MeshInstance3D.new()
		instance.name = "Skin_" + zone
		instance.mesh = zone_mesh
		instance.skin = skin
		instance.skeleton = NodePath("..")
		instance.material_override = material
		instance.extra_cull_margin = 2.0
		source.get_parent().add_child(instance)
		zone_meshes[zone] = instance
		modes[zone] = ""
		_hidden[zone] = {}
	source.visible = false
	source.get_parent().remove_child(source)
	source.queue_free()
	return true


## His scalpel and syringe ride his hands while those arms show the skin, and go
## back to the rig's own arms the moment an arm drops out of skin mode.
func hold_tools(right_tool: Node3D, left_tool: Node3D) -> void:
	for pair: Array in [["right", right_tool, "right_arm", "RightHand"], ["left", left_tool, "left_arm", "LeftHand"]]:
		var tool := pair[1] as Node3D
		if tool == null:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "Hold_" + str(pair[0])
		attachment.bone_name = str(pair[3])
		skeleton.add_child(attachment)
		_tools[pair[0]] = {"node": tool, "home": tool.get_parent(), "home_transform": tool.transform, "zone": pair[2], "attachment": attachment, "at": "home"}


func set_windup(raise: float, syringe: bool) -> void:
	if raise_modifier == null:
		return
	var amount := clampf(raise, 0.0, 1.0)
	raise_modifier.raise["RightArm"] = amount * 1.9
	raise_modifier.raise["LeftArm"] = amount * 1.2 if syringe else 0.0


## He is beaten: the coat is the player's now, so the rig's own coatless body
## shows again, everywhere.
func retire() -> void:
	retired = true
	_zones()


func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body) or model == null:
		return
	if not retired:
		_locomotion(delta)
	_zones()


func _locomotion(delta: float) -> void:
	var moved := (body.global_position - _last_position).length()
	_last_position = body.global_position
	_speed = lerpf(_speed, moved / maxf(delta, 0.0001), 0.35)
	if body.is_downed() or body.anatomy.dead:
		player.pause()
		return
	if _speed > 0.5:
		_play("walk", clampf(_speed / WALK_SPEED, 0.7, 2.2))
	elif _speed < 0.25:
		_play("idle", 1.0)
	if not player.is_playing():
		player.play(_clip)


func _play(clip: String, speed: float) -> void:
	if clip != _clip:
		_clip = clip
		player.play(clip, 0.25)
	player.speed_scale = speed


## True while `zone` may show the skin: nothing gory has happened to it, and
## nobody is looking through it.
func in_skin_mode(zone: String) -> bool:
	if retired or body.get("_xray") == true or body.severed.has(zone):
		return false
	if not (body.wound_marks.get(zone, []) as Array).is_empty() or int(body.zone_depth.get(zone, 0)) > 0:
		return false
	return body.call("_zone_fraction", zone) > BaselineHuman.BRUISE_RATIO


func _zones() -> void:
	for zone: String in ZONES:
		var skin_mode := in_skin_mode(zone)
		var part := body.parts.get(zone) as MeshInstance3D
		(zone_meshes[zone] as MeshInstance3D).visible = skin_mode
		if part != null and is_instance_valid(part):
			if skin_mode:
				# BaselineHuman rewrites transparency on every zone refresh, so
				# this is asserted every frame.
				part.transparency = 1.0
				_hide_rig_pieces(zone, part)
				_tint(zone)
			elif modes[zone] == "skin":
				_give_back(zone, part)
		modes[zone] = "skin" if skin_mode else "body"
	_place_tools()


func _hide_rig_pieces(zone: String, part: Node3D) -> void:
	var hidden: Dictionary = _hidden[zone]
	for stale in hidden.keys():
		if not is_instance_valid(stale):
			hidden.erase(stale)
	var carried := []
	for side: String in _tools:
		carried.append(_tools[side].node)
	for child in part.get_children():
		var piece := child as Node3D
		# His tools are not the rig's body: they stay, and move to his hand.
		if piece != null and piece.visible and not KEEP.has(str(piece.name)) and not carried.has(piece):
			piece.visible = false
			hidden[piece] = true


## The rig's own body comes back exactly as it would have been.
func _give_back(zone: String, part: Node3D) -> void:
	var hidden: Dictionary = _hidden[zone]
	# BaselineHuman frees and rebuilds garments and wound holders, so some of
	# what was hidden may be gone: untyped, and checked, never assumed.
	for piece in hidden.keys():
		if is_instance_valid(piece):
			(piece as Node3D).visible = true
	hidden.clear()
	part.transparency = 0.62 if body.get("_xray") == true else 0.0
	if body.get("_xray") != true:
		body.call("_refresh_zone", zone)


## The bruising the flesh would have shown, on the skin: darker and pinker as
## the zone's health falls toward the bruise line.
func _tint(zone: String) -> void:
	var ratio: float = body.call("_zone_fraction", zone)
	var bruising := clampf((1.0 - ratio) / (1.0 - BaselineHuman.BRUISE_RATIO), 0.0, 1.0)
	if is_equal_approx(bruising, float(_bruise.get(zone, -1.0))):
		return
	_bruise[zone] = bruising
	(zone_materials[zone] as BaseMaterial3D).albedo_color = Color.WHITE.lerp(BRUISE_TINT, bruising * 0.85)


func _place_tools() -> void:
	for side: String in _tools:
		var entry: Dictionary = _tools[side]
		if not is_instance_valid(entry.node) or not is_instance_valid(entry.home):
			continue
		var tool := entry.node as Node3D
		var wanted := "hand" if modes.get(entry.zone, "") == "skin" and not retired else "home"
		if wanted == entry.at:
			continue
		entry.at = wanted
		if wanted == "hand":
			tool.reparent(entry.attachment, false)
			# The attachment lives in the model's centimetre space, scaled by the
			# rig: undo that so the tool keeps its size in metres, lie it along
			# the hand, and seat it in the fist.
			var scale_now: Vector3 = (entry.attachment as Node3D).global_transform.basis.get_scale()
			tool.scale = Vector3.ONE / scale_now
			tool.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			tool.position = Vector3(0.0, HAND_TOOL_REACH, 0.0) / scale_now
		else:
			tool.reparent(entry.home as Node, false)
			tool.transform = entry.home_transform as Transform3D


func _exit_tree() -> void:
	if body == null or not is_instance_valid(body):
		return
	for zone: String in ZONES:
		var part := body.parts.get(zone) as MeshInstance3D
		if part != null and is_instance_valid(part) and modes.get(zone, "") == "skin":
			_give_back(zone, part)
	for side: String in _tools:
		var entry: Dictionary = _tools[side]
		if entry.at == "hand" and is_instance_valid(entry.node) and is_instance_valid(entry.home):
			(entry.node as Node3D).reparent(entry.home as Node, false)
			(entry.node as Node3D).transform = entry.home_transform as Transform3D
