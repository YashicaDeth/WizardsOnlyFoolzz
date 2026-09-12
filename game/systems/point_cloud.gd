class_name PointCloud
extends MultiMeshInstance3D

## Five of Greg's six TouchDesigner tutorials, as one thing.
##
## The list was: ".PNG into particles", "image to visual", "Animated .fbx into
## Particles" — *"for holograms and insane tvs and cutscenes possibly spirits in
## wizards view eyes"* — "Glitch Spider particle system", and "3D Matrix". Five
## videos, and underneath them one technique: **something becomes a field of
## points, and the points are then pushed around**. The differences are what the
## something is and which dial is up.
##
## So this is one system with three sources and a row of dials, rather than five
## systems. A picture becomes points. A mesh becomes points. A living body in
## the game becomes points, which is the spirit in the wizard's eye and also the
## thing on the screen of the insane TV. Turn `glitch` up and it is the spider;
## turn `fall` up and it is the matrix; turn `relief` up and a flat painting is
## a landscape you can walk around.
##
## **One draw call.** A `MultiMesh` of billboarded quads, every point's colour
## and displacement read out of a texture by the vertex shader. A hundred
## thousand points cost the CPU nothing per frame, which is the only reason this
## can be in a scene at the same time as the gore.
##
## The colour source is always "one texel, one point". For a picture that texel
## grid *is* the picture. For a mesh, `_bake_colours` packs each sampled point's
## own colour into a square texture and hands the point its texel. Same shader,
## no branch, and it means anything that can be written into a texture can drive
## a field — which is the seam a Vertex Animation Texture plugs into later.

const POINT_SHADER := preload("res://shaders/point_cloud.gdshader")

## Mirrors the shader's own defaults, the same contract `PsychedelicRig.NEUTRAL`
## keeps: anything not named here is not a dial this system has, and `set_dial`
## ignores it rather than erroring. Adding one means a line here and a uniform
## there, not a hunt through call sites.
const NEUTRAL := {
	"point_size": 0.02,
	"size_from_luma": 0.6,
	"alpha_floor": 0.03,
	"relief": 0.0,
	"spread": 0.0,
	"glitch": 0.0,
	"glitch_bands": 48.0,
	"glitch_rate": 11.0,
	"fall": 0.0,
	"fall_span": 6.0,
	"fall_rate": 0.22,
	"audio": 0.0,
	"audio_lift": 0.0,
	"audio_glow": 0.0,
	"swirl": 0.0,
	"presence": 1.0,
}

## Past this a field stops being worth its memory before it stops being worth
## its fill rate. Three hundred thousand quads is already more points than a
## 1080p screen has pixels to show them in.
const MAX_POINTS := 300000

var points := 0
var source: Texture2D

var _material: ShaderMaterial
var _dials: Dictionary = NEUTRAL.duplicate()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = POINT_SHADER
	material_override = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	multimesh.mesh = quad
	_apply_all_dials()


# ------------------------------------------------------------------ the sources
## A picture becomes points. `across` is the grid width; the height follows the
## image's own aspect so nothing is stretched.
##
## This is ".PNG into particles" and it is also the first half of "image to
## visual" — the second half is turning `relief` and `swirl` up afterwards.
func from_image(image: Image, across := 180, size := Vector2(4.0, 4.0)) -> void:
	if image == null or image.is_empty():
		push_warning("PointCloud: no image.")
		return
	var aspect := float(image.get_height()) / maxf(1.0, float(image.get_width()))
	var down := maxi(1, int(round(float(across) * aspect)))
	across = maxi(1, across)
	while across * down > MAX_POINTS:
		across = maxi(1, across / 2)
		down = maxi(1, down / 2)

	# The picture is the colour source directly: the grid and the texels line up
	# one to one, so a point reads its own pixel and nothing is resampled.
	var texture := ImageTexture.create_from_image(image)
	_set_source(texture)

	var span := Vector2(size.x, size.x * aspect) if size.y <= 0.0 else size
	multimesh.instance_count = across * down
	points = across * down
	_rng.seed = hash(image.get_size())
	var index := 0
	for row in down:
		for column in across:
			var u := (float(column) + 0.5) / float(across)
			var v := (float(row) + 0.5) / float(down)
			var at := Vector3((u - 0.5) * span.x, (0.5 - v) * span.y, 0.0)
			multimesh.set_instance_transform(index, Transform3D(Basis(), at))
			multimesh.set_instance_custom_data(index, Color(u, v, _rng.randf(), 1.0))
			index += 1
	_frame(span.length() * 1.5)
	set_dial("point_size", maxf(span.x / float(across), span.y / float(down)) * 1.6)


func from_texture(texture: Texture2D, across := 180, size := Vector2(4.0, 4.0)) -> void:
	if texture == null:
		return
	from_image(texture.get_image(), across, size)


## A mesh becomes points, scattered over its surface by area rather than by
## vertex — a vertex scatter puts a crowd of points on the dense parts of a
## model and none at all on a large flat face, which reads as a modelling error
## rather than as a cloud.
##
## This is "Animated .fbx into Particles" with the animation still to come: the
## seam for that is `_bake_colours`, which is already a per-point texture.
func from_mesh(mesh: Mesh, count := 24000, colour := Color(0.75, 0.85, 1.0)) -> void:
	if mesh == null:
		push_warning("PointCloud: no mesh.")
		return
	var sampled := _scatter_over(mesh, mini(count, MAX_POINTS))
	if sampled.is_empty():
		push_warning("PointCloud: the mesh has no triangles to scatter over.")
		return
	_lay_out(sampled, colour)


## A living thing in the game becomes points.
##
## Greg: *"holograms and insane tvs and cutscenes possibly spirits in wizards
## view eyes"*. This is that. Hand it a `BaselineHuman`, an NPC, a prop — any
## subtree with meshes in it — and it takes the shape the way it stands right
## now. Add the cloud as a child of the thing it copied and the ghost follows
## the body; add it anywhere else and the body walks out of its own spirit.
##
## Sampled once, on purpose. Re-scattering every frame is a Vertex Animation
## Texture and that is its own job (FINAL_V §16, item 4); a pose that follows
## its subject is most of the effect for none of the cost.
func from_node(root: Node3D, count := 16000, colour := Color(0.75, 0.85, 1.0)) -> void:
	if root == null or not is_instance_valid(root):
		return
	var meshes: Array[MeshInstance3D] = []
	_gather_meshes(root, meshes)
	if meshes.is_empty():
		push_warning("PointCloud: nothing under %s has a mesh." % root.name)
		return

	# Area per mesh, so a hand does not get as many points as a torso.
	var areas: Array[float] = []
	var total := 0.0
	for piece in meshes:
		var area := _surface_area(piece.mesh)
		areas.append(area)
		total += area
	if total <= 0.0:
		return

	var sampled: Array[Dictionary] = []
	var into := root.global_transform.affine_inverse()
	for index in meshes.size():
		var share := int(round(float(count) * areas[index] / total))
		if share <= 0:
			continue
		var piece := meshes[index]
		# Into the root's own space, so the cloud can be parented to the root
		# and travel with it.
		var to_root := into * piece.global_transform
		for entry: Dictionary in _scatter_over(piece.mesh, share):
			entry["at"] = to_root * (entry["at"] as Vector3)
			entry["colour"] = _mesh_colour(piece, colour)
			sampled.append(entry)
	if sampled.is_empty():
		return
	_lay_out(sampled, colour)


# ------------------------------------------------------------------ the dials
func set_dial(dial_name: String, value: float) -> void:
	if not _dials.has(dial_name):
		return
	_dials[dial_name] = value
	_material.set_shader_parameter(dial_name, value)


func dial(dial_name: String) -> float:
	return float(_dials.get(dial_name, 0.0))


func reset_dials() -> void:
	for key in NEUTRAL:
		set_dial(key, float(NEUTRAL[key]))


## Colour over the whole field. Alpha rides with it, which is the cheapest way
## to fade a whole spirit out without touching `presence`.
func set_tint(colour: Color) -> void:
	_material.set_shader_parameter("tint", colour)


## Which way the field faces, for `relief`, `swirl` and `audio_lift`. An image
## field is built in the XY plane and so faces +Z, which is the default.
func set_field(normal: Vector3, centre := Vector3.ZERO) -> void:
	_material.set_shader_parameter("field_normal", normal.normalized())
	_material.set_shader_parameter("field_centre", centre)


func _apply_all_dials() -> void:
	for key in _dials:
		_material.set_shader_parameter(key, _dials[key])
	_material.set_shader_parameter("tint", Color.WHITE)
	_material.set_shader_parameter("field_normal", Vector3(0, 0, 1))
	_material.set_shader_parameter("field_centre", Vector3.ZERO)


# ------------------------------------------------------------------ the plumbing
func _set_source(texture: Texture2D) -> void:
	source = texture
	_material.set_shader_parameter("source_texture", texture)


## Points that came from geometry rather than from a picture still need a texel
## each, so their colours are packed into the smallest square texture that holds
## them and every point is handed its own.
func _lay_out(sampled: Array, fallback: Color) -> void:
	var count := mini(sampled.size(), MAX_POINTS)
	var side := maxi(1, int(ceil(sqrt(float(count)))))
	var colours := Image.create_empty(side, side, false, Image.FORMAT_RGBAF)
	colours.fill(Color(0, 0, 0, 0))

	multimesh.instance_count = count
	points = count
	_rng.seed = count * 7919
	for index in count:
		var entry: Dictionary = sampled[index]
		var at: Vector3 = entry.get("at", Vector3.ZERO)
		var colour: Color = entry.get("colour", fallback)
		var column := index % side
		var row := index / side
		colours.set_pixel(column, row, colour)
		multimesh.set_instance_transform(index, Transform3D(Basis(), at))
		multimesh.set_instance_custom_data(index, Color(
			(float(column) + 0.5) / float(side),
			(float(row) + 0.5) / float(side),
			_rng.randf(), 1.0))

	# A packed colour table has no spatial meaning, so a point reading halfway
	# between two texels would be handed a blend of two unrelated points. Each
	# point is given the exact centre of its own texel, where bilinear filtering
	# weights that texel at one and its neighbours at zero, so the linear sampler
	# the shader uses for real pictures returns exact colours here as well.
	_set_source(ImageTexture.create_from_image(colours))

	var bounds := AABB()
	for index in count:
		var at: Vector3 = (sampled[index] as Dictionary).get("at", Vector3.ZERO)
		bounds = bounds.expand(at) if index > 0 else AABB(at, Vector3.ZERO)
	_frame(maxf(bounds.size.length(), 1.0) * 1.5)


## The shader moves points a long way off their instance transforms, and Godot
## culls a `MultiMesh` by the box it was told about rather than by where the
## points ended up — so a field with `relief` or `fall` up disappears at the
## edge of the screen unless the box is generous.
func _frame(reach: float) -> void:
	custom_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)


func _gather_meshes(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).visible:
		into.append(node as MeshInstance3D)
	for child in node.get_children():
		_gather_meshes(child, into)


func _mesh_colour(piece: MeshInstance3D, fallback: Color) -> Color:
	var material := piece.material_override
	if material == null and piece.mesh != null and piece.mesh.get_surface_count() > 0:
		material = piece.mesh.surface_get_material(0)
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).albedo_color
	return fallback


func _surface_area(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var faces := mesh.get_faces()
	var total := 0.0
	var index := 0
	while index + 2 < faces.size():
		total += _triangle_area(faces[index], faces[index + 1], faces[index + 2])
		index += 3
	return total


func _triangle_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	return (b - a).cross(c - a).length() * 0.5


## Area-weighted scatter. A running total of triangle areas, then a binary
## search per point — so a triangle a hundred times bigger than its neighbour
## gets a hundred times the points, which is the whole difference between a
## scatter and a vertex dump.
func _scatter_over(mesh: Mesh, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if mesh == null or count <= 0:
		return out
	var faces := mesh.get_faces()
	if faces.size() < 3:
		return out

	var running: PackedFloat32Array = PackedFloat32Array()
	var total := 0.0
	var index := 0
	while index + 2 < faces.size():
		total += _triangle_area(faces[index], faces[index + 1], faces[index + 2])
		running.append(total)
		index += 3
	if total <= 0.0:
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = faces.size() * 31 + count
	for _point in count:
		var target := rng.randf() * total
		var low := 0
		var high := running.size() - 1
		while low < high:
			var middle := (low + high) / 2
			if running[middle] < target:
				low = middle + 1
			else:
				high = middle
		var corner := low * 3
		# Uniform inside the triangle. The square root is what stops points
		# bunching into one corner, which is the classic barycentric mistake.
		var r1 := sqrt(rng.randf())
		var r2 := rng.randf()
		var a := faces[corner]
		var b := faces[corner + 1]
		var c := faces[corner + 2]
		var at := a * (1.0 - r1) + b * (r1 * (1.0 - r2)) + c * (r1 * r2)
		out.append({"at": at})
	return out
