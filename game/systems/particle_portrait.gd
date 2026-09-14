class_name ParticlePortrait
extends GPUParticles3D

## The "image/mesh to particle cloud" technique — Greg's own references:
## anya maryina's "Animated .fbx into Particles" and ".PNG into particles |
## Reorder TOP explained", plus Tender World's "image to visual" for his own
## art. One texture in, one particle per texel out, via
## `shaders/particle_portrait.gdshader`.
##
## Two callers, one technique, because that is the whole point of it being
## one shader rather than two:
## - `from_texture()` — one of Greg's own derived art pieces (`ArtSet`)
##   rendered as a cloud. Static, but not frozen: the shader's own slow
##   drift keeps it from reading as a photograph made of dots.
## - `follow_node()` — any live `Node3D` (a rig, a prop) rendered through an
##   internal `SubViewport` into the same shader, every frame, which is the
##   honest equivalent of "an animated character becomes a particle cloud":
##   Godot has no live per-vertex particle read-back the way a TouchDesigner
##   TOP does, so a continuously rendered snapshot is what that technique
##   actually becomes in a game engine rather than an offline renderer.
##
## Deliberately not wired into any "wizard's eye" or TV display surface —
## nothing in the project owns that surface yet (see `DESIGN/THE_BRAIN.md`'s
## WETWIRE/planes system). This delivers the rendering technique itself,
## ready for whichever caller builds that surface; `glitch`/`glitch_seed`
## exist so that caller can drive agitation off whatever state means
## something to it, the same way the psychedelic rig's own dials work.

const PARTICLE_SHADER := preload("res://shaders/particle_portrait.gdshader")

var _shader_material: ShaderMaterial
var _follow_viewport: SubViewport
var _follow_camera: Camera3D


func _init() -> void:
	one_shot = false
	explosiveness = 1.0
	# Effectively "always on" rather than a burst that has to loop: every
	# particle is alive and reads its own texel every frame regardless of
	# where it sits in a lifetime nobody needs to care about here.
	lifetime = 100000.0
	local_coords = true
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = PARTICLE_SHADER
	process_material = _shader_material

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.045, 0.045)
	var draw_material := StandardMaterial3D.new()
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.vertex_color_use_as_albedo = true
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = draw_material
	draw_pass_1 = mesh


## A static source — one of Greg's own art pieces, or any other texture.
func set_source(texture: Texture2D, columns := 48, rows := 48) -> void:
	if _follow_viewport != null and is_instance_valid(_follow_viewport):
		_follow_viewport.queue_free()
		_follow_viewport = null
		_follow_camera = null
	amount = columns * rows
	_shader_material.set_shader_parameter("grid", Vector2(columns, rows))
	_shader_material.set_shader_parameter("source_texture", texture)
	restart()


## `ArtSet.pick(kind, seed_value)`'s exact interface — the same one
## `world_look.gd`'s detail layer already reads Greg's art through, so a
## particle portrait of his work is never a second way of loading it.
func set_source_from_art(kind: String, seed_value: int, columns := 48, rows := 48) -> void:
	set_source(ArtSet.pick(kind, seed_value), columns, rows)


## A live source: `target` is rendered into an internal SubViewport every
## frame and fed straight into the same shader, so an animated body reads as
## a moving cloud rather than a single captured pose.
func follow_node(target: Node3D, columns := 64, rows := 64, frame_size := Vector2i(256, 256)) -> void:
	if _follow_viewport != null and is_instance_valid(_follow_viewport):
		_follow_viewport.queue_free()
	_follow_viewport = SubViewport.new()
	_follow_viewport.name = "PortraitSource"
	_follow_viewport.size = frame_size
	_follow_viewport.transparent_bg = true
	_follow_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_follow_viewport)

	var mirrored := target.duplicate(DUPLICATE_USE_INSTANTIATION)
	_follow_viewport.add_child(mirrored)
	mirrored.transform = Transform3D.IDENTITY

	var aabb := _approximate_aabb(mirrored)
	# Most rigs are rooted at the feet, not the chest, so a cloud placed at
	# the caller's own origin for `target` would have half of it clipped
	# into the ground. Nudges this node's own local position rather than
	# assuming anything about where the caller put it.
	position.y += aabb.get_center().y
	_follow_camera = Camera3D.new()
	_follow_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_follow_camera.size = maxf(aabb.size.x, aabb.size.y) * 1.15
	# `look_at()` reads the node's global transform, which does not exist
	# until it is actually in the tree — added first, framed second.
	_follow_viewport.add_child(_follow_camera)
	_follow_camera.position = aabb.get_center() + Vector3(0, 0, maxf(aabb.size.z, 1.0) * 2.0)
	_follow_camera.look_at(aabb.get_center(), Vector3.UP)

	amount = columns * rows
	_shader_material.set_shader_parameter("grid", Vector2(columns, rows))
	restart()
	set_process(true)


func _process(_delta: float) -> void:
	if _follow_viewport != null and is_instance_valid(_follow_viewport):
		_shader_material.set_shader_parameter("source_texture", _follow_viewport.get_texture())


## Any dial named here; anything else is ignored — the same contract
## `psychedelic_rig.gd`'s `set_dial()` already keeps, so a caller driving
## both through one code path never needs a special case for this one.
func set_dial(dial_name: String, value: float) -> void:
	if dial_name in ["spread", "depth_scale", "glitch", "glitch_seed", "drift"]:
		_shader_material.set_shader_parameter(dial_name, value)


## `node`'s own frame, not the mesh's immediate parent's — a rig like
## `BaselineHuman` nests each zone's meshes several parents deep (root, zone
## container, mesh), and `transform` alone only ever sees the last of those.
## Reading `global_transform` and relying on `node` sitting at world-origin
## identity (true for a `follow_node()` duplicate, never true in general) is
## what makes the accumulated box actually line up with the body it is
## meant to be.
func _approximate_aabb(node: Node3D) -> AABB:
	var combined := AABB()
	var found := false
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		var mesh_instance := current as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box := mesh_instance.mesh.get_aabb()
		box = mesh_instance.global_transform * box
		if found:
			combined = combined.merge(box)
		else:
			combined = box
			found = true
	return combined if found else AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
