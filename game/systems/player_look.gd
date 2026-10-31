class_name PlayerLook
extends RefCounted

## player-81. Greg, 6 Oct: *"i genuinely hate the look of the player model at
## the moment"*. The player had worn the free base character as it came: a
## comic-book superhero (traps up to the ears, deltoids like melons, painted
## abs) in boxers, and in first person a glove and a sleeve whose world grain
## blew up into purple and green squares at arm's length.
##
## This is the player's look, worn on the same rigged base as every enemy
## (Greg, 5 Oct) and never replacing BaselineHuman's zones:
##
##  - BUILD. The base's mesh is slimmed toward ordinary proportions once per
##    model at load (`lean_mesh`): each vertex is drawn in toward the bones it
##    is weighted to (neck, traps, shoulders, arms, chest), so the skeleton,
##    the clips, the ragdoll, the hitboxes and the cut all stay exactly as they
##    were. The painted muscle relief is turned down on the flesh.
##  - GARMENT. Painted onto the flesh shader in the body's rest space, so it
##    is fitted by construction and rides every animation: the zone keeps its
##    flesh material (bruising, wounds handing back to the rig, X-ray) and a
##    story outfit (the jester set, worn in the Hunt) still covers it.
##  - FIRST PERSON. `restyle_hand` gives the first-person hands the same skin
##    tone and the look's own sleeve.
##
## Three looks for Greg to pick between (pause > DISPLAY / HUD > PLAYER LOOK).
## Placeholders until his character art lands.

const SETTINGS_ID := "settings"
const KEY := "player_look"
## Set on a BaselineHuman before `build()` to make it the player.
const META := "player_look"
const DEFAULT := "patient"
const ORDER := ["patient", "bodysuit", "wraps"]
## mode: the flesh shader's garment (1 smock and shorts, 2 bodysuit, 3 wraps).
## a: the main cloth, b: the second (shorts, piping, loincloth).
## sleeve: what the first-person forearm wears ("skin" = bare).
const LOOKS := {
	"patient": {"label": "PATIENT SMOCK", "mode": 1.0, "a": Color("6d7568"), "b": Color("3e4440"), "sleeve": "skin"},
	"bodysuit": {"label": "VAT BODYSUIT", "mode": 2.0, "a": Color("201d1f"), "b": Color("5a1a10"), "sleeve": "a"},
	"wraps": {"label": "BANDAGE WRAPS", "mode": 3.0, "a": Color("b3a585"), "b": Color("3b332c"), "sleeve": "wraps"},
}
## How much of the base's painted muscle relief (colour and normal map) the
## player keeps; enemies keep all of it.
const MUSCLE := 0.4
## The player's flesh, matching BaselineHuman's default tone under the
## facility light, for the first-person hands.
const HAND_FLESH := Color("765a48")

## The build: bone -> [end bone (the axis the flesh is drawn toward), how
## much of each axis' offset from that axis is kept, in model X, Y, Z]. A
## bone whose end is itself scales about its own origin.
const LEAN := {
	"pelvis": ["spine_01", Vector3(0.97, 1.0, 0.96)],
	"spine_01": ["spine_02", Vector3(0.95, 1.0, 0.93)],
	"spine_02": ["spine_03", Vector3(0.92, 1.0, 0.88)],
	"spine_03": ["neck_01", Vector3(0.86, 1.0, 0.84)],
	"neck_01": ["Head", Vector3(0.80, 1.0, 0.84)],
	"Head": ["Head", Vector3(1.04, 1.04, 1.04)],
	"clavicle_l": ["upperarm_l", Vector3(1.0, 0.74, 0.80)],
	"clavicle_r": ["upperarm_r", Vector3(1.0, 0.74, 0.80)],
	"upperarm_l": ["lowerarm_l", Vector3(1.0, 0.78, 0.80)],
	"upperarm_r": ["lowerarm_r", Vector3(1.0, 0.78, 0.80)],
	"lowerarm_l": ["hand_l", Vector3(1.0, 0.88, 0.88)],
	"lowerarm_r": ["hand_r", Vector3(1.0, 0.88, 0.88)],
	"thigh_l": ["calf_l", Vector3(0.90, 1.0, 0.90)],
	"thigh_r": ["calf_r", Vector3(0.90, 1.0, 0.90)],
	"calf_l": ["foot_l", Vector3(0.93, 1.0, 0.93)],
	"calf_r": ["foot_r", Vector3(0.93, 1.0, 0.93)],
}
## The female base is built lighter already: half the change.
const LEAN_FEMALE := 0.5

static var _current := ""
static var _lean_cache: Dictionary = {}


## The chosen look's id.
static func current() -> String:
	if _current.is_empty():
		var chosen := str(WorldHistory.subject(SETTINGS_ID).get(KEY, ""))
		_current = chosen if LOOKS.has(chosen) else DEFAULT
	return _current


static func set_current(id: String) -> void:
	if not LOOKS.has(id):
		return
	_current = id
	WorldHistory.update_subject(SETTINGS_ID, {KEY: id}, "look_setting_changed")


static func cycle(direction := 1) -> String:
	var next: String = ORDER[posmod(ORDER.find(current()) + direction, ORDER.size())]
	set_current(next)
	return next


static func label(id := "") -> String:
	return str((LOOKS.get(id if not id.is_empty() else current(), {}) as Dictionary).get("label", ""))


## Marks `rig` as the player. Call before `rig.build()`. `pinned` wears that
## look whatever is chosen (galleries showing the looks side by side).
static func mark(rig: Node, pinned := "") -> void:
	if rig != null:
		rig.set_meta(META, pinned)


static func is_player(rig: Node) -> bool:
	return rig != null and is_instance_valid(rig) and rig.has_meta(META)


## The id of the look `rig` wears, "" for anyone who is not the player.
static func id_of(rig: Node) -> String:
	if not is_player(rig):
		return ""
	var pinned := str(rig.get_meta(META))
	return pinned if LOOKS.has(pinned) else current()


## The look `rig` wears, or {} for anyone who is not the player.
static func of(rig: Node) -> Dictionary:
	var id := id_of(rig)
	return LOOKS[id] if not id.is_empty() else {}


# ------------------------------------------------------------------ the build
## `mesh` (skinned by `skin` on `rig`, in the rig's rest space) drawn in to
## the lean build. Cached per `key`: every player built from the same model
## shares one mesh.
static func lean_mesh(mesh: ArrayMesh, skin: Skin, rig: Skeleton3D, key: String, amount := 1.0) -> ArrayMesh:
	if _lean_cache.has(key):
		return _lean_cache[key]
	if mesh == null or skin == null or rig == null or mesh.get_blend_shape_count() > 0:
		return mesh
	# Per bind: the axis start, end and kept fraction, or null (untouched).
	var axes: Array = []
	for bind in skin.get_bind_count():
		var bone_name := skin.get_bind_name(bind)
		if bone_name.is_empty():
			bone_name = rig.get_bone_name(skin.get_bind_bone(bind))
		var spec: Array = LEAN.get(bone_name, [])
		var bone := rig.find_bone(bone_name)
		var end := rig.find_bone(str(spec[0])) if not spec.is_empty() else -1
		if spec.is_empty() or bone < 0 or end < 0:
			axes.append(null)
			continue
		var kept: Vector3 = Vector3.ONE.lerp(spec[1] as Vector3, amount)
		axes.append([rig.get_bone_global_rest(bone).origin, rig.get_bone_global_rest(end).origin, kept])
	var lean := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if not vertices.is_empty() and not bone_ids.is_empty():
			var stride := bone_ids.size() / vertices.size()
			for vertex in vertices.size():
				var at := vertices[vertex]
				var moved := Vector3.ZERO
				for slot in stride:
					var weight := weights[vertex * stride + slot]
					var bind := bone_ids[vertex * stride + slot]
					if weight <= 0.0 or bind < 0 or bind >= axes.size() or axes[bind] == null:
						continue
					var axis: Array = axes[bind]
					var offset := at - _nearest_on(axis[0] as Vector3, axis[1] as Vector3, at)
					moved += offset * ((axis[2] as Vector3) - Vector3.ONE) * weight
				vertices[vertex] = at + moved
			arrays[Mesh.ARRAY_VERTEX] = vertices
		var format := int(mesh.surface_get_format(surface))
		var flags := format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		for channel in 4:
			flags |= format & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << (Mesh.ARRAY_FORMAT_CUSTOM_BASE + channel * Mesh.ARRAY_FORMAT_CUSTOM_BITS))
		lean.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays, [], {}, flags)
		lean.surface_set_material(surface, mesh.surface_get_material(surface))
		lean.surface_set_name(surface, mesh.surface_get_name(surface))
	_lean_cache[key] = lean
	return lean


static func _nearest_on(from: Vector3, to: Vector3, point: Vector3) -> Vector3:
	var along := to - from
	var length_squared := along.length_squared()
	if length_squared < 0.000001:
		return from
	return from + along * clampf((point - from).dot(along) / length_squared, 0.0, 1.0)


# ------------------------------------------------------------- first person
## Turns a `HeldGear.build_humiliation_hand` into the look's bare hand: skin
## where the glove was, the cuff and its puffs gone, the forearm sleeve in the
## look's own cloth (or skin, under a short sleeve). Keeps every node the
## first-person rig poses and stretches, so grips and swings are unchanged.
static func restyle_hand(hand: Node3D, id := "") -> void:
	if hand == null:
		return
	var look: Dictionary = LOOKS.get(id if not id.is_empty() else current(), LOOKS[DEFAULT])
	hand.scale = Vector3.ONE * 1.04
	hand.set_meta("player_look", id if not id.is_empty() else current())
	var cuff := hand.get_node_or_null("HumiliationCuff")
	if cuff != null:
		hand.remove_child(cuff)
		cuff.queue_free()
	var flesh := hand_flesh()
	var knuckle := hand_flesh(HAND_FLESH.darkened(0.08))
	var forearm := hand.get_node_or_null("FirstPersonForearm")
	for child in hand.find_children("*", "MeshInstance3D", true, false):
		var piece := child as MeshInstance3D
		if forearm != null and forearm.is_ancestor_of(piece):
			continue
		piece.material_override = knuckle if piece.name == "wrist" else flesh
	if forearm == null:
		return
	for child in forearm.get_children():
		if str(child.name).begins_with("EntryPuff"):
			(child as Node3D).visible = false
	var sleeve := forearm.get_node_or_null("TaperedSleeve") as MeshInstance3D
	if sleeve == null:
		return
	var shape := sleeve.mesh as CylinderMesh
	if shape != null:
		shape = shape.duplicate() as CylinderMesh
		var bare := str(look.sleeve) == "skin"
		# A forearm, wrist to elbow; a sleeve is a little fuller than the arm.
		shape.top_radius = 0.027 if bare else 0.031
		shape.bottom_radius = 0.037 if bare else 0.042
		shape.radial_segments = 14
		sleeve.mesh = shape
	match str(look.sleeve):
		"skin":
			sleeve.material_override = hand_flesh(HAND_FLESH, true)
		"wraps":
			sleeve.material_override = sleeve_cloth(look.a as Color, true)
		_:
			sleeve.material_override = sleeve_cloth(look.a as Color)


## Bare skin seen at arm's length: no world grain (at this range its texels
## are the size of a thumbnail), a soft roughness and a little self-light so
## the hand survives the facility's dark.
static func hand_flesh(tone := HAND_FLESH, forearm := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tone
	if forearm:
		# Darker toward the elbow, off at the screen edge (the cylinder's V
		# runs from the elbow end to the wrist), so it reads as a limb rather
		# than a lit pipe.
		var shade := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gradient.colors = PackedColorArray([Color(0.45, 0.42, 0.42), Color(0.85, 0.83, 0.82), Color.WHITE])
		shade.gradient = gradient
		shade.width = 4
		shade.height = 64
		shade.fill_from = Vector2(0.0, 0.0)
		shade.fill_to = Vector2(0.0, 1.0)
		material.albedo_texture = shade
	material.roughness = 0.62
	material.specular = 0.4
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.emission_enabled = true
	material.emission = tone
	material.emission_energy_multiplier = 0.05
	material.subsurf_scatter_enabled = false
	material.backlight_enabled = true
	material.backlight = Color(0.2, 0.05, 0.03)
	return material


## The look's cloth on a first-person sleeve: plain, with a fine wrap stripe
## for bandages.
static func sleeve_cloth(tint: Color, wrapped := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.9
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.1
	if wrapped:
		var stripes := GradientTexture2D.new()
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.8, 0.86, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0.92, 0.9, 0.86), Color(0.55, 0.5, 0.45), Color.WHITE])
		stripes.gradient = gradient
		stripes.width = 4
		stripes.height = 64
		stripes.fill_from = Vector2(0.0, 0.0)
		stripes.fill_to = Vector2(0.12, 1.0)
		material.albedo_texture = stripes
		material.uv1_scale = Vector3(1.0, 9.0, 1.0)
	return material
