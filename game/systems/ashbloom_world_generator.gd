class_name AshbloomWorldGenerator
extends Node3D

const STREET_LIGHT := preload("res://systems/street_light.gd")

const REGION_SIZE := Vector2(470, 370)
const ROAD := Color("27221c")
const WALLS := [Color("392a20"), Color("403326"), Color("2c3028"), Color("442722")]
const SIGNS := ["EAT AT VANTA'S", "NO GODS OVER 8FT", "NIX FIX", "SOFT ROT MOTEL", "BLACK MILE TAX", "CELLOUTZ RELAY"]

## The five settlements. Named here rather than inside `generate()` so anything
## that needs to know where people live reads the same list the buildings are
## built from — A4.1's district lights being the first such caller.
const DISTRICT_CENTERS := [Vector3(-150, 0, -122), Vector3(130, 0, -122), Vector3(-155, 0, 0), Vector3(135, 0, 0), Vector3(65, 0, 115)]

var generated_buildings: Array[Node3D] = []
var lots: Array[Rect2] = []
var _holding_state_root: Node3D
var _holding_state_signature := ""


func generate(seed_value: int = 774013) -> void:
	# Regeneration replaces only this generator's owned geometry.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	generated_buildings.clear()
	lots.clear()
	_holding_state_root = null
	_holding_state_signature = ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_road(Vector3(0, -0.32, 0), Vector3(18, 0.24, REGION_SIZE.y))
	_build_road(Vector3(0, -0.28, -72), Vector3(REGION_SIZE.x, 0.22, 15))
	_build_road(Vector3(-112, -0.27, 74), Vector3(12, 0.22, 170))
	for district in 5:
		var district_center: Vector3 = DISTRICT_CENTERS[district]
		for lot in 8 + district * 2:
			@warning_ignore("integer_division")
			var offset := Vector3(float(lot % 4) * 24.0 - 36.0, 0, float(lot / 4) * 22.0 - 33.0)
			var width := rng.randf_range(8.0, 17.0)
			var depth := rng.randf_range(7.0, 15.0)
			var height := rng.randf_range(3.8, 8.5)
			var lot_center := Vector2(district_center.x + offset.x, district_center.z + offset.z)
			lots.append(Rect2(lot_center - Vector2(width, depth) * 0.5, Vector2(width, depth)))
			_build_enterable_shell(district_center + offset, Vector3(width, height, depth), WALLS[rng.randi_range(0, WALLS.size() - 1)], SIGNS[rng.randi_range(0, SIGNS.size() - 1)])
			if lot % 2 == 0:
				var light_at := Vector3(lot_center.x - width * 0.5 - 1.3, 0, lot_center.y + depth * 0.5 + 1.7)
				_build_street_light("street_light_d%d_l%d" % [district, lot], light_at, clampf(height * 0.55, 3.4, 5.2))


## Local work has to change the walked place, not merely its dossier. These
## deliberately modest field marks show that the old claim is failing without
## pretending the player has already made the later ascent/corruption choice.
## Rebuilding is signature-gated because Hunt asks every frame while contracts
## are live; a state transition should change geometry once, not churn nodes.
func apply_holding_work_states(rows: Array) -> void:
	var signature_parts: Array[String] = []
	for row: Dictionary in rows:
		if not bool(row.get("revealed", false)):
			continue
		var state := str(row.get("local_work_state", "held"))
		if state in ["disrupted", "ready_for_decision"]:
			signature_parts.append("%s:%s" % [str(row.get("id", "")), state])
	signature_parts.sort()
	var signature := "|".join(signature_parts)
	if signature == _holding_state_signature:
		return
	_holding_state_signature = signature
	if _holding_state_root != null and is_instance_valid(_holding_state_root):
		remove_child(_holding_state_root)
		_holding_state_root.queue_free()
	_holding_state_root = Node3D.new()
	_holding_state_root.name = "HoldingWorkState"
	add_child(_holding_state_root)
	for row: Dictionary in rows:
		var state := str(row.get("local_work_state", "held"))
		if not bool(row.get("revealed", false)) or state not in ["disrupted", "ready_for_decision"]:
			continue
		_build_holding_state_mark(row, state)


func _build_holding_state_mark(row: Dictionary, state: String) -> void:
	var centre2: Vector2 = row.get("at", Vector2.ZERO)
	var centre := Vector3(centre2.x, 0.0, centre2.y)
	var cluster := Node3D.new()
	cluster.name = "Claim_%s" % str(row.get("id", "unknown"))
	cluster.set_meta("holding_id", str(row.get("id", "")))
	cluster.set_meta("work_state", state)
	cluster.position = centre
	_holding_state_root.add_child(cluster)
	var open := state == "ready_for_decision"
	var tint := Color("a5c774") if open else Color("c76b49")
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var stake := MeshInstance3D.new()
		stake.name = "BrokenClaimStake_%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 3.4, 0.22)
		box.material = _material(tint.darkened(0.18), 0.22 if open else 0.08, "rust")
		stake.mesh = box
		stake.position = Vector3(cos(angle) * 9.0, 1.45, sin(angle) * 9.0)
		stake.rotation = Vector3(sin(angle) * 0.42, -angle, cos(angle) * 0.42)
		cluster.add_child(stake)
	var beacon := OmniLight3D.new()
	beacon.name = "ClaimStateBeacon"
	# Offset toward the district approach instead of burying the read inside the
	# settlement's existing centre structure.
	beacon.position = Vector3(0, 2.8, 7.0)
	beacon.light_color = tint
	beacon.light_energy = 1.35 if open else 0.55
	beacon.omni_range = 11.0 if open else 6.0
	beacon.shadow_enabled = false
	cluster.add_child(beacon)
	var label := Label3D.new()
	label.name = "ClaimStateLabel"
	label.position = Vector3(0, 3.65, 7.0)
	label.text = "DECISION OPEN" if open else "LOCAL CLAIM DISRUPTED"
	label.font_size = 30
	label.modulate = tint
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cluster.add_child(label)


## AB1.2. Wires `street_light.gd`'s already-proven break loop into the actual
## world rather than leaving it provable only in isolation — one lamp at every
## other lot's street frontage, where a bullet or a car can actually reach it.
## The subject id is derived from district and lot, not call order, so
## regenerating the same seed reads the same `WorldHistory` fixture back
## instead of minting a fresh one every load.
func _build_street_light(id: String, at: Vector3, height: float) -> void:
	var light: StreetLight = STREET_LIGHT.new()
	light.name = "StreetLight_%s" % id
	add_child(light)
	light.position = at
	light.build(id, height)


func _build_road(at: Vector3, dimensions: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = _material(ROAD, 0.0, "dirt")
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


## M4.1. The scale vocabulary, stated once so the whole region agrees with it.
##
## A doorway is the only object in an exterior that reliably tells the eye how
## big a person is, and this generator did not have one: the "door" was a gap
## between two wall segments running from the floor to the roof, so on an 8.5 m
## shell the opening was 8.5 m tall. Nothing anywhere in the Expanse stated
## human scale, which is why the boxes read as either enormous or tiny
## depending on what the player last looked at — and at FOV 78 that ambiguity
## is the whole image.
const DOOR_HEIGHT := 2.15
const STOREY := 3.0
const PERSON_HEIGHT := 1.8


func _build_enterable_shell(at: Vector3, dimensions: Vector3, color: Color, sign_text: String) -> void:
	var building := Node3D.new()
	building.name = "Enterable_%03d" % generated_buildings.size()
	building.position = at
	building.set_meta("dimensions", dimensions)
	add_child(building)
	generated_buildings.append(building)
	# One immovable building is one physics body. The old layout created a
	# separate StaticBody3D for every wall, floor, roof and decorative storey
	# band: 654 server bodies for sixty shells. Collision detail still lives in
	# the same individual BoxShape3Ds, but they now share the transform and
	# lifetime of the building they belong to.
	var collision_body := StaticBody3D.new()
	collision_body.name = "Collision"
	building.add_child(collision_body)
	var wall_thickness := 0.45
	var half_x := dimensions.x * 0.5
	var half_z := dimensions.z * 0.5
	var door_width := minf(2.4, dimensions.x * 0.28)
	_add_wall(building, Vector3(-half_x + (dimensions.x - door_width) * 0.25, dimensions.y * 0.5, half_z), Vector3((dimensions.x - door_width) * 0.5, dimensions.y, wall_thickness), color)
	_add_wall(building, Vector3(half_x - (dimensions.x - door_width) * 0.25, dimensions.y * 0.5, half_z), Vector3((dimensions.x - door_width) * 0.5, dimensions.y, wall_thickness), color)
	# M4.1. The lintel. Without it the doorway is a slot to the roof and the
	# building states no scale at all.
	var head := minf(DOOR_HEIGHT, dimensions.y - 0.6)
	if dimensions.y > head + 0.3:
		_add_wall(
			building,
			Vector3(0, head + (dimensions.y - head) * 0.5, half_z),
			Vector3(door_width, dimensions.y - head, wall_thickness),
			color
		)
	_add_wall(building, Vector3(0, dimensions.y * 0.5, -half_z), Vector3(dimensions.x, dimensions.y, wall_thickness), color)
	_add_wall(building, Vector3(-half_x, dimensions.y * 0.5, 0), Vector3(wall_thickness, dimensions.y, dimensions.z), color)
	_add_wall(building, Vector3(half_x, dimensions.y * 0.5, 0), Vector3(wall_thickness, dimensions.y, dimensions.z), color)
	_add_wall(building, Vector3(0, -0.12, 0), Vector3(dimensions.x, 0.22, dimensions.z), Color("211a16"))
	_add_wall(building, Vector3(0, dimensions.y, 0), Vector3(dimensions.x + 0.7, 0.32, dimensions.z + 0.7), color.darkened(0.18))
	# G4. Texture does not change an outline. A box with brilliant grime on it is
	# still a box, and what reads at distance is the edge — so the edge gets
	# broken, hung with junk, and knocked off plumb.
	# M4.1. Floor lines every three metres. A blank wall of any height reads as
	# the same wall; banded, it reads as the number of storeys it actually is,
	# which is the second thing after a door that states scale.
	var storey := STOREY
	while storey < dimensions.y - 0.4:
		_add_wall(building, Vector3(0, storey, half_z + 0.06), Vector3(dimensions.x * 0.96, 0.14, 0.12), color.darkened(0.36))
		_add_wall(building, Vector3(half_x + 0.06, storey, 0), Vector3(0.12, 0.14, dimensions.z * 0.96), color.darkened(0.36))
		storey += STOREY
	_post_bill(building, dimensions, generated_buildings.size())
	Silhouette.dress(building, dimensions, generated_buildings.size(), Callable(self, "_greeble_material"))
	Silhouette.settle(building, generated_buildings.size())
	var sign := Label3D.new()
	sign.text = sign_text
	# Just above the lintel, where a shop sign actually hangs. At 72% of the
	# shell height it floated at a different altitude on every building and
	# reinforced nothing.
	sign.position = Vector3(0, minf(DOOR_HEIGHT + 0.55, dimensions.y - 0.4), half_z + 0.35)
	sign.font_size = 28
	sign.modulate = Color("e26a36")
	sign.outline_size = 5
	building.add_child(sign)


func _add_wall(parent: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var body := parent.get_node_or_null("Collision") as StaticBody3D
	if body == null:
		# Defensive fallback for small harnesses that call this helper directly
		# instead of constructing a complete enterable shell.
		body = StaticBody3D.new()
		body.name = "Collision"
		parent.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position = at
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = _material(color, 0.0)
	mesh_instance.mesh = box
	mesh_instance.position = at
	parent.add_child(mesh_instance)


## The whole region was built with its own flat material function and never
## touched `WorldLook` at all, so every wall, road and shell in the Ashbloom
## was a single untextured colour. That — not the box geometry — is why the
## region reads as a grey-box prototype: the same boxes with contaminated
## surfaces on them read as a ruined town.
var _surface_index := 0

## Adapter so `Silhouette` does not have to know about WorldLook.
func _greeble_material(tint: Color, kind: String, seed_value: int) -> StandardMaterial3D:
	return WorldLook.surface(tint, kind, seed_value)


func _material(color: Color, emission: float, kind := "rust") -> StandardMaterial3D:
	_surface_index += 1
	var material: StandardMaterial3D = WorldLook.surface(color, kind, _surface_index)
	material.emission_enabled = emission > 0.0
	if emission > 0.0:
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


## A10.1 / A10.15. Greg's own collaged art, in the world as texture rather than
## only on the index plates and the Wire, and posted rather than tiled.
##
## "With intent" is the part that decides how this is built. A sheet fed through
## `_apply_grain()` as a triplanar detail layer would repeat across every wall
## in the region, which turns a collage into wallpaper and says nothing. A bill
## nailed up beside a door says somebody put it there — so it is a quad, at
## reading height, on the face with the entrance in it, on one building in
## three. The two thirds without one are what make the third mean anything.
##
## Absent art changes nothing, per `art_set.gd`: a worktree with no derived
## sheets builds the same region it always did.
func _post_bill(building: Node3D, dimensions: Vector3, seed_value: int) -> void:
	if absi(seed_value) % 3 != 0:
		return
	var sheet: Texture2D = ArtSet.pick("plate", seed_value)
	if sheet == null:
		return
	var bill := MeshInstance3D.new()
	bill.name = "PostedBill"
	var quad := QuadMesh.new()
	# Roughly A1, the size a real posted bill is, and never scaled to the wall:
	# a poster that grows with the building it is on is a decal, not an object.
	quad.size = Vector2(0.62, 0.86)
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = sheet
	paper.roughness = 0.95
	paper.metallic = 0.0
	# Weathered down hard. This has been up a while, in the air A9 just filled
	# with contamination, and a clean print would read as the newest thing in
	# the region.
	paper.albedo_color = Color(0.58, 0.55, 0.48)
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material = paper
	bill.mesh = quad
	# Beside the door on the entrance face, at the height somebody would have
	# reached to put it there.
	var side := 1.0 if seed_value % 2 == 0 else -1.0
	bill.position = Vector3(side * minf(dimensions.x * 0.3, 2.2), 1.62, dimensions.z * 0.5 + 0.26)
	# Off square, because nobody posting a bill on a wall uses a spirit level.
	bill.rotation.z = deg_to_rad(float((seed_value * 13) % 9) - 4.0)
	bill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(bill)
