class_name RiggedBody
extends Node3D

## RiggedBody: a rigged, animated low-poly humanoid under a BaselineHuman.
##
## Greg, 4 October: *"the body model in third person just has no head and for
## some reason the shoulders are massive"*, *"arms looking weird"*, and ragdolls
## whose limbs come apart. The procedural rig was six boxes posed by hand; this
## puts a real skeleton under them (Quaternius' Universal Animation Library
## mannequin, CC0, see CREDITS.md) without replacing any of the rig.
##
## The contract (WORKING_NOW.md, BUILD_BRIEFS Job 2): a model on a person is a
## SKIN on BaselineHuman's zones, never a replacement. So:
##
##  - The mannequin's skinned mesh is split into the rig's six zones by bone
##    weight (the same split ModelSkin does for the examiner). A zone shows the
##    skin while it is pristine; the first wound, exposed layer, prosthetic,
##    sever or X-ray hands that zone straight back to the rig's own body.
##  - Every zone rides the animated skeleton. Each zone part (and its hitbox)
##    is placed every frame along the chord between two BoneAttachment3Ds
##    (shoulder to palm, hip to sole, pelvis to neck, neck to crown), so
##    wounds, organs, bones and the X-ray layers - all children of the parts -
##    follow the animation instead of standing at the rest layout. Extra
##    segment hitboxes (upper arm, forearm, hand, thigh, calf, foot, neck) sit
##    on their own bones and carry the zone they belong to in `body_zone`.
##  - A severed limb hides its skin zone and the thrown limb carries a copy of
##    that zone's skin baked in the pose it was cut in.
##  - Death is a PhysicalBone3D ragdoll on the same skeleton, with cone joints
##    at the neck, spine, shoulders and hips and hinges at elbows and knees.
##    The zones keep riding the bones, so the corpse keeps every wound.
##
## Living knockdown keeps BaselineHuman's authored tip-over (Greg, round 13).

const MODEL := "res://art/characters/ual_mannequin.glb"
const ZONES := ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"]
## The mannequin faces +Z in its own space; the rig faces -Z.
const MODEL_BACK := Vector3(0, 0, -1)

## Semantic clip name -> the mannequin's clip. Job 3 drives fighting through
## `play_action()` with these names; anything not listed plays by its own name.
## Hit reactions from the back and sides, and a second death, have no clip in
## the free library: the sides and back are a procedural lean (`HitLean`) and
## the second death is the physics ragdoll.
const CLIPS := {
	"idle": "Idle", "walk": "Walk", "jog": "Jog_Fwd", "run": "Sprint",
	"crouch_idle": "Crouch_Idle", "crouch_walk": "Crouch_Fwd",
	"jump_start": "Jump_Start", "jump_loop": "Jump", "jump_land": "Jump_Land",
	"roll": "Roll", "hit_front": "Hit_Chest", "hit_head": "Hit_Head",
	"death": "Death01", "interact": "Interact", "pick_up": "PickUp_Table",
	"sword_idle": "Sword_Idle", "sword_attack": "Sword_Attack",
	"punch_jab": "Punch_Jab", "punch_cross": "Punch_Cross",
	"pistol_idle": "Pistol_Idle", "pistol_aim": "Pistol_Aim_Neutral",
	"pistol_shoot": "Pistol_Shoot", "pistol_reload": "Pistol_Reload",
	"spell_enter": "Spell_Simple_Enter", "spell_idle": "Spell_Simple_Idle",
	"spell_cast": "Spell_Simple_Shoot", "spell_exit": "Spell_Simple_Exit",
}
## Clips that hold their last frame and hand back to locomotion when done.
const ONE_SHOTS := ["Jump_Start", "Jump_Land", "Roll", "Hit_Chest", "Hit_Head", "Death01", "Interact", "PickUp_Table", "Sword_Attack", "Punch_Jab", "Punch_Cross", "Pistol_Shoot", "Pistol_Reload", "Spell_Simple_Enter", "Spell_Simple_Shoot", "Spell_Simple_Exit"]

## Where each zone part sits: along the chord from `top` to `bottom` (bone
## origins, each pushed out along the chord by `*_ext` metres of the model),
## turned by `anchor`. Arms end mid-palm and legs at the sole, so a weapon
## parented to the arm part's lower end is in the hand.
const ZONE_CHORDS := {
	"head": {"anchor": "Head", "top": "Head", "top_ext": 0.17, "bottom": "neck_01", "bottom_ext": 0.0},
	"torso": {"anchor": "spine_02", "top": "neck_01", "top_ext": 0.0, "bottom": "pelvis", "bottom_ext": 0.08},
	"left_arm": {"anchor": "upperarm_l", "top": "upperarm_l", "top_ext": 0.0, "bottom": "hand_l", "bottom_ext": 0.08},
	"right_arm": {"anchor": "upperarm_r", "top": "upperarm_r", "top_ext": 0.0, "bottom": "hand_r", "bottom_ext": 0.08},
	"left_leg": {"anchor": "thigh_l", "top": "thigh_l", "top_ext": 0.0, "bottom": "foot_l", "bottom_ext": 0.09},
	"right_leg": {"anchor": "thigh_r", "top": "thigh_r", "top_ext": 0.0, "bottom": "foot_r", "bottom_ext": 0.09},
}
## Which zone each skin bone's weight counts toward. Unlisted bones (fingers,
## toes) inherit from their nearest listed ancestor.
const ZONE_OF_BONE := {
	"root": "torso", "pelvis": "torso", "spine_01": "torso", "spine_02": "torso", "spine_03": "torso",
	"clavicle_l": "torso", "clavicle_r": "torso",
	"neck_01": "head", "Head": "head",
	"upperarm_l": "left_arm", "lowerarm_l": "left_arm", "hand_l": "left_arm",
	"upperarm_r": "right_arm", "lowerarm_r": "right_arm", "hand_r": "right_arm",
	"thigh_l": "left_leg", "calf_l": "left_leg", "foot_l": "left_leg", "ball_l": "left_leg",
	"thigh_r": "right_leg", "calf_r": "right_leg", "foot_r": "right_leg", "ball_r": "right_leg",
}
## Segment hitboxes: bone -> [zone, end bone (or "" for a fixed length), radius].
const SEGMENTS := {
	"neck_01": ["head", "Head", 0.06],
	"upperarm_l": ["left_arm", "lowerarm_l", 0.055], "lowerarm_l": ["left_arm", "hand_l", 0.045], "hand_l": ["left_arm", "", 0.045],
	"upperarm_r": ["right_arm", "lowerarm_r", 0.055], "lowerarm_r": ["right_arm", "hand_r", 0.045], "hand_r": ["right_arm", "", 0.045],
	"thigh_l": ["left_leg", "calf_l", 0.075], "calf_l": ["left_leg", "foot_l", 0.06], "foot_l": ["left_leg", "", 0.05],
	"thigh_r": ["right_leg", "calf_r", 0.075], "calf_r": ["right_leg", "foot_r", 0.06], "foot_r": ["right_leg", "", 0.05],
}
const SEGMENT_FIXED_LENGTH := 0.16

## The death ragdoll. bone -> [zone, joint, length end bone or metres, radius, mass].
## Lengths and radii are the model's own metres; joints: "root", "cone", "hinge".
const RAGDOLL := {
	"pelvis": ["torso", "root", "spine_02", 0.13, 14.0],
	"spine_02": ["torso", "cone", "neck_01", 0.14, 20.0],
	"Head": ["head", "cone", 0.22, 0.10, 5.0],
	"upperarm_l": ["left_arm", "cone", "lowerarm_l", 0.05, 2.5],
	"lowerarm_l": ["left_arm", "hinge", "middle_02_l", 0.045, 2.0],
	"upperarm_r": ["right_arm", "cone", "lowerarm_r", 0.05, 2.5],
	"lowerarm_r": ["right_arm", "hinge", "middle_02_r", 0.045, 2.0],
	"thigh_l": ["left_leg", "cone", "calf_l", 0.075, 9.0],
	"calf_l": ["left_leg", "hinge", "ball_l", 0.06, 5.0],
	"thigh_r": ["right_leg", "cone", "calf_r", 0.075, 9.0],
	"calf_r": ["right_leg", "hinge", "ball_r", 0.06, 5.0],
}
## Degrees, per axis of each bone's own frame: X is the bend (elbow, knee,
## and the forward/back swing of shoulder, hip, spine and neck), Y the twist
## along the bone, Z the sideways swing. Elbows and knees bend one way only, a
## few degrees past straight at most. All 6DOF: the cone-twist joint was
## measured blowing the head off the spine in Godot Physics about one death in
## four (the long spine-to-skull lever); 6DOF is what RagdollBody always used.
const JOINT_LIMITS := {
	"spine_02": [Vector2(-22, 22), Vector2(-14, 14), Vector2(-18, 18)],
	"Head": [Vector2(-35, 40), Vector2(-30, 30), Vector2(-30, 30)],
	"upperarm_l": [Vector2(-70, 70), Vector2(-35, 35), Vector2(-70, 70)],
	"upperarm_r": [Vector2(-70, 70), Vector2(-35, 35), Vector2(-70, 70)],
	"lowerarm_l": [Vector2(-4, 135), Vector2(-8, 8), Vector2(-4, 4)],
	"lowerarm_r": [Vector2(-4, 135), Vector2(-8, 8), Vector2(-4, 4)],
	"thigh_l": [Vector2(-60, 60), Vector2(-20, 20), Vector2(-40, 40)],
	"thigh_r": [Vector2(-60, 60), Vector2(-20, 20), Vector2(-40, 40)],
	"calf_l": [Vector2(-4, 130), Vector2(-5, 5), Vector2(-4, 4)],
	"calf_r": [Vector2(-4, 130), Vector2(-5, 5), Vector2(-4, 4)],
}
## A bone moving faster than this is a solver blow-up, not a fall: it is put
## back to the speed of the body it belongs to.
const RAGDOLL_MAX_SPEED := 14.0
const RAGDOLL_MAX_SPIN := 22.0
const BODY_LAYER := 1 << 6
const WORLD_MASK := 1
## Weighty, not floaty: little linear drag so it falls at gravity, a good deal
## of angular drag so limbs fold and stop rather than windmilling.
const RAGDOLL_LINEAR_DAMP := 0.12
const RAGDOLL_ANGULAR_DAMP := 3.2
const RAGDOLL_FRICTION := 0.92
const MAX_LAUNCH_SPEED := 6.0
const SETTLE_SPEED := 0.12
const SETTLE_SECONDS := 0.8
const RAGDOLL_FREEZE_SECONDS := 4.0
## What the rig keeps showing on a zone the skin covers, besides anything this
## file does not recognise as body (held weapons, tools, gear): nothing.
const BODY_PIECE_PREFIXES := ["Shoulder_", "Clavicle_", "Garment", "Censor_", "Nude_", "Tattoo_", "ForcedJester", "CollarLock", "BloodStreak"]
const HIT_LEAN_SECONDS := 0.42
const HIT_LEAN_ANGLE := 0.42


## Bends the spine and neck away from a blow, after the animation has posed
## them: the hit reaction for directions the clip library has no clip for.
class HitLean extends SkeletonModifier3D:
	var axis := Vector3.ZERO
	var amount := 0.0

	func _process_modification() -> void:
		var skeleton := get_skeleton()
		if skeleton == null or absf(amount) < 0.001 or axis.length_squared() < 0.001:
			return
		for pair: Array in [["spine_02", 0.45], ["spine_03", 0.35], ["neck_01", 0.35]]:
			var bone := skeleton.find_bone(str(pair[0]))
			if bone < 0:
				continue
			var parent := skeleton.get_bone_parent(bone)
			var parent_turn := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
			var extra := Quaternion(axis.normalized(), amount * float(pair[1]))
			skeleton.set_bone_pose_rotation(bone, parent_turn.inverse() * extra * parent_turn * skeleton.get_bone_pose_rotation(bone))


var body: BaselineHuman
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var hit_lean: HitLean
var simulator: PhysicalBoneSimulator3D
## Optional driver whose `state`, `first_person`, `crouch_blend` and friends
## pick the clip (HunterBodyMotion). Found automatically as a sibling.
var motion_source: Node
var attachments: Dictionary = {}
var segment_hitboxes: Dictionary = {}
var physical_bones: Dictionary = {}
var zone_meshes: Dictionary = {}
var triangles_by_zone: Dictionary = {}
var modes: Dictionary = {}
var ragdolled := false
var ragdoll_settled := false
var max_launch_speed := 0.0
## False while the arms are someone else's (first-person arms).
var arms_driven := true
var model_scale := 1.0

var _back_local: Dictionary = {}
var _hidden: Dictionary = {}
var _last_position := Vector3.ZERO
var _speed := 0.0
var _clip := ""
var _action := ""
var _seen_hit := Vector4.ZERO
var _seen_attack := 0.0
var _lean_time := 0.0
var _quiet := 0.0
var _ragdoll_time := 0.0


## The rigged body for `host`, or null (nothing touched) when the model is
## missing. Call after `host.build()`.
static func attach(host: BaselineHuman) -> RiggedBody:
	if host == null or not is_instance_valid(host) or host.parts.is_empty() or not ResourceLoader.exists(MODEL):
		return null
	var rigged := RiggedBody.new()
	host.add_child(rigged)
	if rigged.build(host):
		host.rigged = rigged
		return rigged
	host.remove_child(rigged)
	rigged.free()
	return null


func build(host: BaselineHuman) -> bool:
	name = "RiggedBody"
	body = host
	# After whatever poses the rig's parts (HunterBodyMotion, pain posture), so
	# the skeleton has the last word on where a zone is.
	process_priority = 100
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return false
	model = scene.instantiate() as Node3D
	if model == null:
		return false
	model.name = "Mannequin"
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source: MeshInstance3D = null
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).skin != null:
			source = node as MeshInstance3D
			break
	if skeleton == null or player == null or source == null:
		return false
	model.rotation.y = PI
	model_scale = 1.0 if OS.get_environment("JOB2_NOSCALE") == "1" else _rig_height() / maxf(source.mesh.get_aabb().end.y, 0.5)
	model.scale = Vector3.ONE * model_scale
	if not _split(source):
		return false
	for clip_name in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump", "Sword_Idle", "Pistol_Idle", "Spell_Simple_Idle"]:
		if player.has_animation(clip_name):
			player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	_build_attachments()
	hit_lean = HitLean.new()
	hit_lean.name = "HitLean"
	skeleton.add_child(hit_lean)
	motion_source = _find_motion_source()
	_last_position = body.global_position if body.is_inside_tree() else Vector3.ZERO
	_seen_hit = _hit_signature()
	_play("Idle", 1.0)
	skeleton.force_update_all_bone_transforms()
	_drive_zones()
	_zones()
	return true


## Where the rig's head ends, from the same layout its parts were built from.
func _rig_height() -> float:
	var layout: Dictionary = body.get("_layout") if body.get("_layout") != null else {}
	var head: Dictionary = layout.get("head", {})
	if head.is_empty():
		return 1.76
	return float((head.at as Vector3).y + (head.size as Vector3).y * 0.5)


func _find_motion_source() -> Node:
	var holder := body.get_parent()
	if holder == null:
		return null
	var found := holder.get_node_or_null("HunterBodyMotion")
	return found if found != null and "state" in found else null


## One BoneAttachment3D per bone a zone or a segment needs; the zone's back
## direction is remembered in its anchor's own space at rest, so a twisting arm
## carries its wounds round with it.
func _build_attachments() -> void:
	var wanted: Array[String] = []
	for zone: String in ZONE_CHORDS:
		var spec: Dictionary = ZONE_CHORDS[zone]
		for key in ["anchor", "top", "bottom"]:
			if not wanted.has(str(spec[key])):
				wanted.append(str(spec[key]))
	for bone_name: String in SEGMENTS:
		if not wanted.has(bone_name):
			wanted.append(bone_name)
	for bone_name in wanted:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "Bone_" + bone_name
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		attachments[bone_name] = attachment
	for zone: String in ZONE_CHORDS:
		var anchor := skeleton.find_bone(str((ZONE_CHORDS[zone] as Dictionary).anchor))
		var rest := skeleton.get_bone_global_rest(anchor)
		_back_local[zone] = (rest.basis.inverse() * MODEL_BACK).normalized()
	for bone_name: String in SEGMENTS:
		var attachment := attachments.get(bone_name) as BoneAttachment3D
		if attachment == null:
			continue
		var spec: Array = SEGMENTS[bone_name]
		var length := SEGMENT_FIXED_LENGTH
		if not str(spec[1]).is_empty():
			length = _rest_distance(bone_name, str(spec[1]))
		var area := Area3D.new()
		area.name = "%s_hitbox_%s" % [spec[0], bone_name]
		area.set_meta("body_zone", str(spec[0]))
		area.set_meta("bone", bone_name)
		var shape_node := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = float(spec[2])
		capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
		shape_node.shape = capsule
		shape_node.position = Vector3(0, length * 0.5, 0)
		area.add_child(shape_node)
		attachment.add_child(area)
		segment_hitboxes[area.name] = area


func _rest_distance(from_bone: String, to_bone: String) -> float:
	var a := skeleton.find_bone(from_bone)
	var b := skeleton.find_bone(to_bone)
	if a < 0 or b < 0:
		return SEGMENT_FIXED_LENGTH
	return skeleton.get_bone_global_rest(a).origin.distance_to(skeleton.get_bone_global_rest(b).origin)


## The skin mesh becomes one mesh per zone per surface, all on the same skeleton
## and skin, so each zone shows or hides on its own.
func _split(source: MeshInstance3D) -> bool:
	var mesh := source.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return false
	var skin := source.skin
	var bind_zone := PackedInt32Array()
	for bind in skin.get_bind_count():
		var bone_name := skin.get_bind_name(bind)
		var bone := skeleton.find_bone(bone_name) if not bone_name.is_empty() else skin.get_bind_bone(bind)
		bind_zone.append(ZONES.find(_zone_of_bone(bone)))
	var zone_lists: Dictionary = {}
	for zone: String in ZONES:
		zone_lists[zone] = []
		triangles_by_zone[zone] = 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bone_ids.is_empty():
			continue
		var stride := bone_ids.size() / vertices.size()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in vertices.size():
				indices[index] = index
		var vertex_weight := PackedFloat32Array()
		vertex_weight.resize(vertices.size() * ZONES.size())
		for vertex in vertices.size():
			for slot in stride:
				var weight := weights[vertex * stride + slot]
				var bind := bone_ids[vertex * stride + slot]
				if weight > 0.0 and bind >= 0 and bind < bind_zone.size() and bind_zone[bind] >= 0:
					vertex_weight[vertex * ZONES.size() + bind_zone[bind]] += weight
		var per_zone: Array[PackedInt32Array] = []
		for zone_index in ZONES.size():
			per_zone.append(PackedInt32Array())
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
			per_zone[best_zone].append_array([indices[triangle * 3], indices[triangle * 3 + 1], indices[triangle * 3 + 2]])
		var flags := int(mesh.surface_get_format(surface)) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		for zone_index in ZONES.size():
			var list := per_zone[zone_index]
			if list.is_empty():
				continue
			var zone_arrays := arrays.duplicate()
			zone_arrays[Mesh.ARRAY_INDEX] = list
			var zone_mesh := ArrayMesh.new()
			zone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, zone_arrays, [], {}, flags)
			var zone: String = ZONES[zone_index]
			triangles_by_zone[zone] = int(triangles_by_zone[zone]) + list.size() / 3
			var instance := MeshInstance3D.new()
			instance.name = "Skin_%s_%d" % [zone, surface]
			instance.mesh = zone_mesh
			instance.skin = skin
			instance.skeleton = NodePath("..")
			instance.extra_cull_margin = 2.0
			source.get_parent().add_child(instance)
			(zone_lists[zone] as Array).append(instance)
	for zone: String in ZONES:
		zone_meshes[zone] = zone_lists[zone]
		modes[zone] = ""
		_hidden[zone] = {}
	source.visible = false
	source.get_parent().remove_child(source)
	source.queue_free()
	return true


func _zone_of_bone(bone: int) -> String:
	var at := bone
	while at >= 0:
		var bone_name := skeleton.get_bone_name(at)
		if ZONE_OF_BONE.has(bone_name):
			return str(ZONE_OF_BONE[bone_name])
		at = skeleton.get_bone_parent(at)
	return "torso"


func _process(delta: float) -> void:
	if body == null or not is_instance_valid(body) or model == null:
		return
	if not ragdolled:
		_animate(delta)
	_drive_zones()
	_zones()


## Picks the clip from the motion source when there is one (the player), from
## the body's own speed otherwise (everyone else).
func _animate(delta: float) -> void:
	var moved := (body.global_position - _last_position)
	moved.y = 0.0
	_last_position = body.global_position
	_speed = lerpf(_speed, moved.length() / maxf(delta, 0.0001), 0.3)
	var react := _hit_signature()
	if react != _seen_hit:
		_seen_hit = react
		hit_react(body.get("_last_hit_direction") as Vector3, str(body.get("_last_hit_zone")))
	if _lean_time > 0.0:
		_lean_time = maxf(0.0, _lean_time - delta)
		var t := 1.0 - _lean_time / HIT_LEAN_SECONDS
		hit_lean.amount = sin(t * PI) * HIT_LEAN_ANGLE * (1.0 - t * 0.4)
	else:
		hit_lean.amount = 0.0
	if body.anatomy != null and (body.anatomy.dead or body.is_downed()):
		player.pause()
		return
	arms_driven = not (motion_source != null and bool(motion_source.get("first_person")))
	if not _action.is_empty():
		if player.is_playing() and player.current_animation == _action:
			return
		_action = ""
	var clip := _locomotion_clip()
	var rate := 1.0
	match clip:
		"Walk": rate = clampf(_speed / 1.4, 0.6, 1.8)
		"Jog_Fwd": rate = clampf(_speed / 3.2, 0.7, 1.5)
		"Sprint": rate = clampf(_speed / 5.5, 0.8, 1.4)
		"Crouch_Fwd": rate = clampf(_speed / 1.2, 0.6, 1.6)
	_play(clip, rate)


func _locomotion_clip() -> String:
	var source := motion_source
	if source != null:
		var state := str(source.get("state"))
		var attack_time := float(source.get("attack_time"))
		if state in ["attack", "shoot"] and attack_time > _seen_attack:
			var kind := str(source.get("attack_kind"))
			var clip := "Pistol_Shoot" if state == "shoot" else ("Punch_Cross" if kind in ["", "unarmed", "fist"] else "Sword_Attack")
			_seen_attack = attack_time
			play_action(clip, clampf(player.get_animation(clip).length / maxf(float(source.get("attack_duration")), 0.2), 0.8, 3.0))
			return clip
		_seen_attack = attack_time
		if float(source.get("roll_pose_override")) >= 0.0 or state == "dodge":
			return "Roll"
		if state == "air":
			return "Jump"
		if state == "reload":
			return "Pistol_Reload"
		if float(source.get("crouch_blend")) > 0.5:
			return "Crouch_Fwd" if _speed > 0.3 else "Crouch_Idle"
		if _speed < 0.35 and float(source.get("combat_pose")) > 0.5:
			return "Pistol_Idle" if str(source.get("combat_kind")) == "firearm" else "Sword_Idle"
	if _speed > 4.6:
		return "Sprint"
	if _speed > 2.3:
		return "Jog_Fwd"
	if _speed > 0.35:
		return "Walk"
	return "Idle"


func _play(clip: String, rate: float) -> void:
	if not player.has_animation(clip):
		clip = "Idle"
	if clip != _clip or not player.is_playing():
		_clip = clip
		player.play(clip, 0.2)
	player.speed_scale = rate


## Plays one clip (a semantic name from CLIPS, or the clip's own name) over the
## locomotion until it ends. Job 3's moveset drives fighting through this.
func play_action(action: String, rate := 1.0) -> bool:
	var clip := str(CLIPS.get(action, action))
	if player == null or not player.has_animation(clip) or ragdolled:
		return false
	_action = clip
	_clip = clip
	player.play(clip, 0.08)
	player.speed_scale = rate
	if ONE_SHOTS.has(clip):
		player.seek(0.0, true)
	return true


## The blow lands: a clip when the library has one for that side, and always a
## lean away from it.
func hit_react(direction: Vector3, zone := "torso") -> void:
	if direction.length_squared() < 0.0001 or skeleton == null:
		return
	var local := (skeleton.global_transform.basis.inverse() * direction).normalized()
	local.y = 0.0
	if local.length_squared() < 0.0001:
		return
	local = local.normalized()
	# Lean with the blow: rotate about the axis perpendicular to it.
	hit_lean.axis = Vector3.UP.cross(local)
	_lean_time = HIT_LEAN_SECONDS
	# The model faces +Z: a blow travelling -Z came from in front.
	if local.z < -0.5 and _action.is_empty():
		play_action("hit_head" if zone == "head" else "hit_front", 1.3)


func _hit_signature() -> Vector4:
	var direction: Vector3 = body.get("_last_hit_direction") if body.get("_last_hit_direction") != null else Vector3.ZERO
	return Vector4(direction.x, direction.y, direction.z, float(body.get("_last_hit_impulse")) + float(body.wound_marks.size()) * 0.001)


## Every zone part, its hitbox and its stump ride the skeleton.
func _drive_zones() -> void:
	for zone: String in ZONES:
		if not arms_driven and zone.ends_with("_arm"):
			continue
		var placed := zone_transform(zone)
		if placed == Transform3D():
			continue
		var part := body.parts.get(zone) as Node3D
		if part != null and is_instance_valid(part) and part.get_parent() == body:
			var keep := part.scale
			part.global_transform = placed
			part.scale = keep
		var hitbox := body.get_node_or_null("%s_hitbox" % zone) as Node3D
		if hitbox != null and hitbox.get_parent() == body:
			hitbox.global_transform = placed
		var stump := body.get_node_or_null("%s_stump" % zone) as Node3D
		if stump != null:
			var spec: Dictionary = ZONE_CHORDS[zone]
			var top := _point(str(spec.top), 0.0, Vector3.ZERO)
			stump.global_position = top
	if body.head_anchor != null and is_instance_valid(body.head_anchor):
		var head := zone_transform("head")
		if head != Transform3D():
			body.head_anchor.global_position = head.origin + head.basis.y.normalized() * 0.12


## Where `zone`'s part belongs this frame, in world space (orthonormal).
func zone_transform(zone: String) -> Transform3D:
	var spec: Dictionary = ZONE_CHORDS.get(zone, {})
	if spec.is_empty():
		return Transform3D()
	var anchor := attachments.get(str(spec.anchor)) as Node3D
	var top_node := attachments.get(str(spec.top)) as Node3D
	var bottom_node := attachments.get(str(spec.bottom)) as Node3D
	if anchor == null or top_node == null or bottom_node == null or not anchor.is_inside_tree():
		return Transform3D()
	var top := top_node.global_position
	var bottom := bottom_node.global_position
	var along := top - bottom
	if along.length_squared() < 0.000001:
		along = anchor.global_transform.basis.y
	var unit := along.normalized()
	var scale_now := anchor.global_transform.basis.get_scale().x
	top += unit * float(spec.top_ext) * scale_now
	bottom -= unit * float(spec.bottom_ext) * scale_now
	var y := (top - bottom).normalized()
	var back := (anchor.global_transform.basis.orthonormalized() * (_back_local[zone] as Vector3)).normalized()
	var z := back - y * back.dot(y)
	if z.length_squared() < 0.0001:
		z = y.cross(Vector3.RIGHT)
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), (top + bottom) * 0.5)


func _point(bone_name: String, ext: float, toward: Vector3) -> Vector3:
	var node := attachments.get(bone_name) as Node3D
	if node == null:
		return body.global_position
	return node.global_position + toward * ext


## True while `zone` may show the skin: nothing gory has happened to it, it
## carries no prosthetic, nobody is looking through it, and whoever owns the
## part has not hidden it (the first-person camera hides the head).
func in_skin_mode(zone: String) -> bool:
	if body.get("_xray") == true or body.severed.has(zone):
		return false
	if not arms_driven and zone.ends_with("_arm"):
		return false
	if body.anatomy != null and body.anatomy.installed_parts.has(zone):
		return false
	if not (body.wound_marks.get(zone, []) as Array).is_empty() or int(body.zone_depth.get(zone, 0)) > 0:
		return false
	return body.call("_zone_fraction", zone) > BaselineHuman.BRUISE_RATIO


func _zones() -> void:
	for zone: String in ZONES:
		var skin_mode := in_skin_mode(zone)
		var part := body.parts.get(zone) as MeshInstance3D
		var shown := skin_mode and part != null and is_instance_valid(part) and part.visible
		for instance: MeshInstance3D in zone_meshes[zone]:
			instance.visible = shown
			if shown:
				instance.material_override = _skin_material(zone, part)
		if part != null and is_instance_valid(part):
			if skin_mode:
				# BaselineHuman rewrites transparency on every zone refresh, so
				# this is asserted every frame.
				part.transparency = 1.0
				_hide_rig_pieces(zone, part)
			elif modes[zone] == "skin":
				_give_back(zone, part)
		modes[zone] = "skin" if skin_mode else "body"
	var segments_on := {}
	for zone: String in ZONES:
		segments_on[zone] = not body.severed.has(zone)
	for area: Area3D in segment_hitboxes.values():
		var on: bool = segments_on.get(str(area.get_meta("body_zone")), true)
		if area.monitorable != on:
			area.monitorable = on


## The skin wears what the zone wears: its garment where it has one, otherwise
## the zone's own flesh material - the world's grain and colour, bruising
## included, because BaselineHuman retints it on every blow.
func _skin_material(zone: String, part: MeshInstance3D) -> Material:
	var garment := part.get_node_or_null("Garment") as GeometryInstance3D
	if garment != null and garment.material_override != null:
		return garment.material_override
	return part.material_override


func _hide_rig_pieces(zone: String, part: Node3D) -> void:
	var hidden: Dictionary = _hidden[zone]
	for child in part.get_children():
		var piece := child as Node3D
		if piece == null or not piece.visible or hidden.has(piece):
			continue
		if _is_body_piece(str(piece.name)) or piece.has_meta("body_mod"):
			piece.visible = false
			hidden[piece] = true


func _is_body_piece(piece_name: String) -> bool:
	for prefix: String in BODY_PIECE_PREFIXES:
		if piece_name.begins_with(prefix):
			return true
	return false


## The rig's own body comes back exactly as it would have been.
func _give_back(zone: String, part: Node3D) -> void:
	var hidden: Dictionary = _hidden[zone]
	for piece in hidden.keys():
		if is_instance_valid(piece):
			(piece as Node3D).visible = true
	hidden.clear()
	(part as GeometryInstance3D).transparency = 0.62 if body.get("_xray") == true else 0.0
	if body.get("_xray") != true:
		body.call("_refresh_zone", zone)


## Called by BaselineHuman when a limb leaves whole: the thrown limb carries
## the zone's skin in the pose it was cut in, and the rig's own limb mesh
## steps back (its wounds, ink and bone stub stay on it and stay visible).
func skin_severed_limb(zone: String, limb: Node3D, visual: GeometryInstance3D) -> void:
	if limb == null or not is_instance_valid(limb):
		return
	var part := body.parts.get(zone) as MeshInstance3D
	var material: Material = _skin_material(zone, part) if part != null else null
	var baked_any := false
	for instance: MeshInstance3D in zone_meshes.get(zone, []):
		var baked := _bake_pose(instance)
		if baked == null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = "SeveredSkin"
		copy.mesh = baked
		copy.material_override = material
		limb.add_child(copy)
		copy.global_transform = skeleton.global_transform
		baked_any = true
	if baked_any and visual != null and modes.get(zone, "") == "skin":
		visual.transparency = 1.0


## The zone's skin, skinned on the CPU in the skeleton's current pose, in the
## skeleton's space. Only what the zone's triangles use is kept.
func _bake_pose(instance: MeshInstance3D) -> ArrayMesh:
	var mesh := instance.mesh as ArrayMesh
	var skin := instance.skin
	if mesh == null or skin == null:
		return null
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or bone_ids.is_empty() or indices.is_empty():
		return null
	var stride := bone_ids.size() / vertices.size()
	var bind_pose: Array[Transform3D] = []
	for bind in skin.get_bind_count():
		var bone_name := skin.get_bind_name(bind)
		var bone := skeleton.find_bone(bone_name) if not bone_name.is_empty() else skin.get_bind_bone(bind)
		bind_pose.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind) if bone >= 0 else Transform3D.IDENTITY)
	var remap := {}
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var out_indices := PackedInt32Array()
	for index in indices:
		if not remap.has(index):
			var position := Vector3.ZERO
			var normal := Vector3.ZERO
			for slot in stride:
				var weight := weights[index * stride + slot]
				if weight <= 0.0:
					continue
				var pose := bind_pose[bone_ids[index * stride + slot]]
				position += (pose * vertices[index]) * weight
				if not normals.is_empty():
					normal += (pose.basis * normals[index]) * weight
			remap[index] = out_vertices.size()
			out_vertices.append(position)
			out_normals.append(normal.normalized() if normal.length_squared() > 0.0 else Vector3.UP)
			if not uvs.is_empty():
				out_uvs.append(uvs[index])
		out_indices.append(int(remap[index]))
	var baked_arrays := []
	baked_arrays.resize(Mesh.ARRAY_MAX)
	baked_arrays[Mesh.ARRAY_VERTEX] = out_vertices
	baked_arrays[Mesh.ARRAY_NORMAL] = out_normals
	if not out_uvs.is_empty():
		baked_arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	baked_arrays[Mesh.ARRAY_INDEX] = out_indices
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, baked_arrays)
	return baked


## Death: physics takes the skeleton. The zones keep riding it.
func die(hit_zone: String, impulse: float, direction: Vector3, attack_id := "") -> void:
	if ragdolled or skeleton == null or not is_inside_tree():
		return
	ragdolled = true
	arms_driven = true
	player.pause()
	hit_lean.amount = 0.0
	hit_lean.active = false
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	for bone_name: String in RAGDOLL:
		var spec: Array = RAGDOLL[bone_name]
		if body.severed.has(str(spec[0])) and str(spec[0]) != "torso":
			continue
		var made := _physical_bone(bone_name, spec)
		if made != null:
			physical_bones[bone_name] = made
	simulator.physical_bones_start_simulation()
	_ignore_loose_gore()
	body.limb_severed.connect(func(_zone: String, _report: Dictionary): _ignore_loose_gore.call_deferred())
	if body.anatomy != null:
		body.anatomy.organ_ruptured.connect(func(_organ: String, _state: Dictionary): _ignore_loose_gore.call_deferred())
	_launch(BaselineHuman.canonical_zone(hit_zone), impulse, direction, attack_id)


## Loose organs and thrown limbs are ordinary layer-1 bodies, and they are
## born inside the body they came out of: a corpse that collided with its own
## spilled brain was shoved out of it at hundreds of metres a second. The
## corpse ignores what fell out of it (gore chunks already have their own
## layer).
func _ignore_loose_gore() -> void:
	if not is_inside_tree() or physical_bones.is_empty():
		return
	var root: Node = body.call("_gore_root")
	var near := body.global_position
	for child in root.get_children():
		var loose := child as RigidBody3D
		if loose == null or loose.global_position.distance_to(near) > 3.0:
			continue
		var child_name := str(loose.name)
		if not (child_name.ends_with("_severed") or child_name.ends_with("_cut") or child_name.begins_with("organ_")):
			continue
		for physical: PhysicalBone3D in physical_bones.values():
			if is_instance_valid(physical):
				physical.add_collision_exception_with(loose)


func _physical_bone(bone_name: String, spec: Array) -> PhysicalBone3D:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return null
	var length := 0.0
	if spec[2] is String:
		length = _rest_distance(bone_name, str(spec[2]))
	else:
		length = float(spec[2])
	var radius := float(spec[3])
	var physical := PhysicalBone3D.new()
	physical.name = "Physical_" + bone_name
	physical.bone_name = bone_name
	physical.mass = float(spec[4])
	physical.friction = RAGDOLL_FRICTION
	physical.bounce = 0.0
	physical.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	physical.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
	physical.linear_damp = RAGDOLL_LINEAR_DAMP
	physical.angular_damp = RAGDOLL_ANGULAR_DAMP
	physical.collision_layer = BODY_LAYER
	physical.collision_mask = WORLD_MASK
	# The body sits halfway along the bone; its joint stays at the bone's root.
	physical.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length * 0.5, 0))
	if str(spec[1]) == "root":
		physical.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	else:
		physical.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		var limits: Array = JOINT_LIMITS.get(bone_name, [Vector2(-30, 30), Vector2(-20, 20), Vector2(-30, 30)])
		for axis in 3:
			var key: String = ["x", "y", "z"][axis]
			var range_deg: Vector2 = limits[axis]
			physical.set("joint_constraints/%s/linear_limit_enabled" % key, true)
			physical.set("joint_constraints/%s/linear_limit_upper" % key, 0.0)
			physical.set("joint_constraints/%s/linear_limit_lower" % key, 0.0)
			physical.set("joint_constraints/%s/angular_limit_enabled" % key, true)
			physical.set("joint_constraints/%s/angular_limit_lower" % key, range_deg.x)
			physical.set("joint_constraints/%s/angular_limit_upper" % key, range_deg.y)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	if bone_name == "Head":
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape_node.shape = sphere
	else:
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		# End to end on the bone: a capsule that started out past the toe ball
		# would start inside the floor and kick the corpse on its first step.
		capsule.height = maxf(length, radius * 2.0 + 0.01)
		shape_node.shape = capsule
	physical.add_child(shape_node)
	simulator.add_child(physical)
	return physical


## Same launch classes as RagdollBody, so a heavy blow throws a rigged corpse
## exactly as far as it throws a boxed one.
func _launch(hit_zone: String, impulse: float, direction: Vector3, attack_id: String) -> void:
	var heading := direction
	heading.y = 0.0
	heading = heading.normalized() if heading.length_squared() > 0.001 else -global_transform.basis.z
	var speed := clampf(maxf(impulse, 1.0), 1.0, RagdollBody.MAX_KILLING_IMPULSE) * RagdollBody.BASE_IMPULSE_SPEED
	var lift := 0.0
	var id := attack_id.strip_edges().to_lower()
	var launch_class := ""
	if id == "charged_heavy":
		launch_class = "poise_break"
	elif id in ["heavy", "running_attack", "roll_attack"]:
		launch_class = "heavy"
	elif id.begins_with("light_"):
		launch_class = "light"
	if RagdollBody.ATTACK_LAUNCH.has(launch_class):
		var profile: Dictionary = RagdollBody.ATTACK_LAUNCH[launch_class]
		speed = float(profile.speed)
		lift = float(profile.lift)
	var launch := heading * speed + Vector3.UP * lift
	if launch.length() > MAX_LAUNCH_SPEED:
		launch = launch.normalized() * MAX_LAUNCH_SPEED
	# Every bone leaves at the same speed, so no joint starts the fall already
	# torn; the struck part alone gets a turn, which is what folds the body
	# round the blow.
	for bone_name: String in physical_bones:
		var physical := physical_bones[bone_name] as PhysicalBone3D
		physical.linear_velocity = launch
		if str((RAGDOLL[bone_name] as Array)[0]) == hit_zone:
			physical.angular_velocity = Vector3.UP.cross(heading) * minf(speed * 0.5, 2.5)
	max_launch_speed = launch.length()


func _physics_process(delta: float) -> void:
	if ragdolled:
		_watch_ragdoll(delta)


func _watch_ragdoll(delta: float) -> void:
	if ragdoll_settled:
		return
	_ragdoll_time += delta
	_clamp_ragdoll()
	var quiet := true
	for physical: PhysicalBone3D in physical_bones.values():
		if is_instance_valid(physical) and physical.linear_velocity.length() > SETTLE_SPEED:
			quiet = false
			break
	_quiet = _quiet + delta if quiet else 0.0
	if _quiet >= SETTLE_SECONDS or _ragdoll_time >= RAGDOLL_FREEZE_SECONDS:
		ragdoll_settled = true
		# Laid to rest: Godot Physics never lets a jointed corpse go fully
		# still (it twitches at a few cm/s for good), so a settled corpse is
		# held by drag rather than left to crawl, as RagdollBody freezes its
		# own at FORCE_FREEZE_SECONDS.
		for physical: PhysicalBone3D in physical_bones.values():
			if is_instance_valid(physical):
				physical.linear_damp = 40.0
				physical.angular_damp = 40.0


## A safety net under the solver, not the motion: a bone faster than any blow
## or fall can make is put back to the mean speed of its corpse.
func _clamp_ragdoll() -> void:
	var mean := Vector3.ZERO
	for physical: PhysicalBone3D in physical_bones.values():
		mean += physical.linear_velocity
	mean /= maxf(1.0, float(physical_bones.size()))
	var ceiling := maxf(RAGDOLL_MAX_SPEED, max_launch_speed + 6.0)
	for physical: PhysicalBone3D in physical_bones.values():
		if physical.linear_velocity.length() > ceiling:
			physical.linear_velocity = mean.limit_length(ceiling)
		if physical.angular_velocity.length() > RAGDOLL_MAX_SPIN:
			physical.angular_velocity = physical.angular_velocity.limit_length(RAGDOLL_MAX_SPIN)


## The worst gap, in metres, between a ragdoll bone's root and the place its
## parent body says that root should be. A joint that held reads near zero.
func max_joint_gap() -> float:
	var worst := 0.0
	for gap: float in joint_gaps().values():
		worst = maxf(worst, gap)
	return worst


## Bone pairs whose distance is fixed by the skeleton whatever its pose: the
## two ends of a limb segment, and the hips on the pelvis.
const RIGID_PAIRS := [
	["upperarm_l", "lowerarm_l"], ["lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r"], ["lowerarm_r", "hand_r"],
	["thigh_l", "calf_l"], ["calf_l", "foot_l"], ["thigh_r", "calf_r"], ["calf_r", "foot_r"],
	["thigh_l", "thigh_r"], ["neck_01", "Head"], ["pelvis", "spine_02"],
]


## How far each rigid pair of bones has been pulled from its rest distance, in
## metres. Bones only turn at a joint; any distance here is a limb coming away.
func joint_gaps() -> Dictionary:
	var gaps := {}
	for pair: Array in RIGID_PAIRS:
		var a := attachments.get(str(pair[0])) as Node3D
		var b := attachments.get(str(pair[1])) as Node3D
		if a == null or b == null or body.severed.has(str(ZONE_OF_BONE.get(str(pair[0]), "torso"))):
			continue
		var rest := _rest_distance(str(pair[0]), str(pair[1])) * a.global_transform.basis.get_scale().x
		gaps["%s-%s" % pair] = absf(a.global_position.distance_to(b.global_position) - rest)
	return gaps
