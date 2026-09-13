class_name Motherboard
extends Node3D

## E2.4/E2.5. Greg: *"burn and bind seals should have their own animation
## based on real life, where the person's computer motherboard appears in 3D
## and the seals burn into the microscopic copper stuff as sigils on the
## board, like a full animation for it when a seal is burnt"*.
##
## The image is the whole point: a printed circuit board *is* a sigil,
## drawn in copper, mass-produced by the million. This is that board, built
## the same way every other object in this game is — procedural geometry
## from primitives, nothing imported — and the seal geometry it burns or
## binds is the exact same `CellOutzType.seal_strokes()` the 2D ritual app
## already draws, mapped onto the board's own surface rather than a second,
## unrelated shape invented for 3D.
##
## E2.6: burning is subtractive (a stroke on the near side of the front is
## gone, scorched into the copper, the way `draw_seal_burning` already
## removes strokes rather than dimming them) and binding is additive (a new
## copper trace grows across bare board, completing a circuit that was
## open). E2.7: a burn is drawn in char and stays — permanent damage to this
## specific board — a bind is drawn in raised, lit copper and also stays,
## because the board this ran on is spent either way; which one a rite gets
## is decided in `ritual_app.gd`, not here. This is only the instrument.

const CellOutzType := preload("res://systems/celloutz_type.gd")
const GoeticSeals := preload("res://systems/goetic_seals.gd")

const BASE_SIZE := Vector2(0.22, 0.16)
const BASE_THICKNESS := 0.006
const COPPER := Color("caa14a")
## E2.4 `v2`. Copper was the only metal on this board, and a real one has two.
## Copper is the etched trace — dull, tan, and everywhere. Gold is plating:
## ENIG on the pads, hard gold on the edge fingers and the chip legs, put
## exactly where something has to make contact and nowhere else. The
## difference matters here beyond accuracy, because the seal arrives in copper
## and leaves in gold, and that is how you read that it went *in*.
const GOLD := Color("d9b43c")
const SOLDER_MASK := Color("0b3d24")
const SILKSCREEN := Color("d8dcd4")
const CHAR := Color("120e0c")
const EMBER := Color("dc5827")

## Where the seal actually burns or binds — an open patch of board deliberately
## kept clear of the static traces below, the way a real board reserves a
## component-free area rather than routing copper edge to edge.
const SEAL_CENTER := Vector3(0.055, 0.0, -0.045)
const SEAL_RADIUS := 0.045

var _top_y: float
var _static: Node3D
var _live_mesh: MeshInstance3D
var _baked: Node3D

## E2.7. What this specific board carries forward. Each entry is
## `{"seed": int, "complexity": int}`; burnt and bound are kept separately
## because a burnt seal reads as a scar the board carries and a bound one
## reads as a working circuit, and nothing should have to re-derive which is
## which from colour alone.
var bound_seals: Array = []
var burnt_seals: Array = []

var _mode := ""
var _seed := 0
var _complexity := 6
var _front_angle := 0.0
var _duration := 1.0
var _elapsed := 0.0
var _strokes: Array = []

## E2.5. Where the seals go. Stored because the infusion needs a target and
## the chip is built inside `_build_board`, which used to keep it to itself.
var _chip_at := Vector3.ZERO
var _chip_pins: Array[MeshInstance3D] = []
var _chip_body: MeshInstance3D = null

## How many of the seventy-two are in the chip. Not a list: an infused seal
## leaves no scar on the board, which is the whole difference between
## infusing one and burning one.
var infused_seals := 0
var _queue: Array = []
var _per_seal := 2.0
var _current_number := 0
var _processing := false

signal seal_infused(number: int, name: String, total: int)
signal procession_finished(total: int)


func _ready() -> void:
	_top_y = BASE_THICKNESS * 0.5
	_static = Node3D.new()
	_static.name = "Static"
	add_child(_static)
	_baked = Node3D.new()
	_baked.name = "Baked"
	add_child(_baked)
	_build_board()
	_live_mesh = MeshInstance3D.new()
	_live_mesh.name = "LiveSeal"
	add_child(_live_mesh)
	set_process(false)


# --- E2.5: the board is a real board ---------------------------------------

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, metallic: float = 0.0, rotation_y: float = 0.0, emission: Color = Color(0, 0, 0), emission_energy: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = rotation_y
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.35 if metallic > 0.0 else 0.75
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	instance.material_override = material
	parent.add_child(instance)
	return instance


## A copper trace as a real object rather than a texture: a sequence of
## axis-aligned segments, the way an actual board is routed rather than
## wired point to point, with a square pad at each end.
func _trace(parent: Node3D, points: PackedVector2Array, width: float, height: float) -> void:
	for index in points.size() - 1:
		var a := points[index]
		var b := points[index + 1]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		if length < 0.0005:
			continue
		var angle := (b - a).angle()
		_box(parent, Vector3(length + width, height, width), Vector3(mid.x, _top_y + height * 0.5, mid.y), COPPER, 0.6, -angle)
	for point in points:
		_box(parent, Vector3(width * 1.8, height, width * 1.8), Vector3(point.x, _top_y + height * 0.5, point.y), COPPER, 0.6)


## Manhattan-routed, the way real copper is: seeded turns rather than a
## straight wire, laid down once per board rather than per frame.
func _routed_trace(rng: RandomNumberGenerator, from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var turns := rng.randi_range(1, 2)
	var cursor := from
	for turn in turns:
		var t := float(turn + 1) / float(turns + 1)
		var next := Vector2(lerpf(from.x, to.x, t), cursor.y) if turn % 2 == 0 else Vector2(cursor.x, lerpf(from.y, to.y, t))
		points.append(next)
		cursor = next
	points.append(to)
	return points


func _build_board() -> void:
	_box(_static, Vector3(BASE_SIZE.x, BASE_THICKNESS, BASE_SIZE.y), Vector3.ZERO, SOLDER_MASK)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4471
	# Static routing, filling the board except the seal's own reserved patch.
	var seal_flat := Vector2(SEAL_CENTER.x, SEAL_CENTER.z)
	var lanes := 9
	for lane in lanes:
		var y := lerpf(-BASE_SIZE.y * 0.42, BASE_SIZE.y * 0.42, float(lane) / float(lanes - 1))
		var from := Vector2(-BASE_SIZE.x * 0.46, y)
		var to := Vector2(BASE_SIZE.x * 0.46, y + rng.randf_range(-0.01, 0.01))
		var routed := _routed_trace(rng, from, to)
		var clear := true
		for point: Vector2 in routed:
			if point.distance_to(seal_flat) < SEAL_RADIUS * 1.25:
				clear = false
				break
		if clear:
			_trace(_static, routed, 0.0016, 0.0006)

	# The chip: a black package with pins down two sides, and a notch so it
	# reads as a component with a pin one rather than a bare block.
	var chip_at := Vector3(-BASE_SIZE.x * 0.28, 0.0, BASE_SIZE.y * 0.22)
	_chip_at = chip_at
	var chip_size := Vector2(0.045, 0.032)
	_chip_body = _box(_static, Vector3(chip_size.x, 0.010, chip_size.y), chip_at + Vector3(0, _top_y + 0.005, 0), CHAR, 0.1)
	_box(_static, Vector3(0.006, 0.011, 0.006), chip_at + Vector3(-chip_size.x * 0.5 + 0.006, _top_y + 0.005, -chip_size.y * 0.5 + 0.006), SILKSCREEN, 0.0)
	var pins := 6
	for side in [-1.0, 1.0]:
		for pin in pins:
			var pin_y := lerpf(-chip_size.y * 0.4, chip_size.y * 0.4, float(pin) / float(pins - 1))
			# Legs are plated, not etched. Gold, and kept so the infusion can light
			# them as the seals go in.
			_chip_pins.append(_box(_static, Vector3(0.010, 0.002, 0.003), chip_at + Vector3(side * (chip_size.x * 0.5 + 0.005), _top_y + 0.001, pin_y), GOLD, 0.85))

	# Silkscreen outline around the chip footprint. Every real board has one.
	var outline := chip_size + Vector2(0.006, 0.006)
	for corner_x in [-outline.x * 0.5, outline.x * 0.5]:
		_box(_static, Vector3(0.0006, 0.0002, outline.y), chip_at + Vector3(corner_x, _top_y + 0.0002, 0), SILKSCREEN)
	for corner_y in [-outline.y * 0.5, outline.y * 0.5]:
		_box(_static, Vector3(outline.x, 0.0002, 0.0006), chip_at + Vector3(0, _top_y + 0.0002, corner_y), SILKSCREEN)

	# The edge connector. The most recognisable gold on any board, and the
	# reason a stripped motherboard is worth scrapping at all.
	var fingers := 14
	for finger in fingers:
		var fx := lerpf(-BASE_SIZE.x * 0.34, BASE_SIZE.x * 0.34, float(finger) / float(fingers - 1))
		_box(_static, Vector3(0.0055, 0.0004, 0.016), Vector3(fx, _top_y + 0.0002, BASE_SIZE.y * 0.44), GOLD, 0.9)

	# A pair of capacitors, because a board with only one component reads as
	# a diagram rather than a thing that was actually populated.
	# Clear of SEAL_CENTER/SEAL_RADIUS. They were inside it, so every seal drew
	# straight through two capacitors — the reserved patch was honoured by the
	# routing and by nothing else on the board.
	for cap_at in [Vector3(-BASE_SIZE.x * 0.02, 0.0, BASE_SIZE.y * 0.28), Vector3(BASE_SIZE.x * 0.07, 0.0, BASE_SIZE.y * 0.28)]:
		var cap_mesh := CylinderMesh.new()
		cap_mesh.top_radius = 0.006
		cap_mesh.bottom_radius = 0.006
		cap_mesh.height = 0.012
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position = cap_at + Vector3(0, _top_y + 0.006, 0)
		var cap_material := StandardMaterial3D.new()
		cap_material.albedo_color = Color("2a2a2e")
		cap.material_override = cap_material
		_static.add_child(cap)


# --- E2.4: the seal, burnt or bound onto this board ------------------------

## `seal_strokes()` returns points on a unit circle; this is that same
## geometry, at `SEAL_RADIUS`, sitting on the board's own top surface. One
## conversion, shared by the live animation and the permanent bake, so a
## finished seal looks exactly like the last frame that drew it.
func _stroke_points_3d(stroke: PackedVector2Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for point: Vector2 in stroke:
		out.append(SEAL_CENTER + Vector3(point.x, 0.0, point.y) * SEAL_RADIUS + Vector3(0, _top_y + 0.0009, 0))
	return out


func is_animating() -> bool:
	return _mode != ""


## E2.6. Binding: additive. Grows the same stroke order `draw_seal_forming`
## reveals in construction order (ring, spokes, chords, core), ending as a
## permanent raised copper trace completing a circuit that was open ground
## before it.
func begin_bind(seed_value: int, complexity: int = 6, anim_duration: float = 3.0) -> void:
	_mode = "bind"
	_seed = seed_value
	_complexity = complexity
	_duration = maxf(0.2, anim_duration)
	_elapsed = 0.0
	_strokes = CellOutzType.seal_strokes(seed_value, complexity)
	set_process(true)


## E2.6. Burning: subtractive. The same front-consuming order
## `draw_seal_burning` already uses — strokes behind the front are gone,
## the one at the front catches ember-bright before it goes — ending as a
## permanent char scar rather than a working trace.
func begin_burn(seed_value: int, complexity: int = 6, anim_duration: float = 2.4, front_angle: float = 0.0) -> void:
	_mode = "burn"
	_seed = seed_value
	_complexity = complexity
	_front_angle = front_angle
	_duration = maxf(0.2, anim_duration)
	_elapsed = 0.0
	_strokes = CellOutzType.seal_strokes(seed_value, complexity)
	set_process(true)


# --- E2.5: the procession, and what "infused" means ------------------------

## Greg: the sigils are *infused into the microchip*, not left on the board.
##
## That is a different verb from burn and bind and it needs to be, because
## seventy-two burns would leave seventy-two overlapping scars on one patch of
## board and read as mud. An infusion burns the seal in exactly as before, then
## the same geometry collapses into the chip and is gone from the board. What is
## left behind is not a mark. It is the chip's legs sitting a little brighter
## than they did, seventy-two times over.
##
## `seeds` defaults to all seventy-two of the Ars Goetia in their traditional
## order. Each demon's number seeds its own seal, so every one of them is a
## distinct glyph and the same demon is the same glyph every run.
func begin_procession(seeds: Array = [], per_seal := 2.0) -> void:
	_queue = seeds.duplicate() if not seeds.is_empty() else _all_goetia_numbers()
	_per_seal = maxf(0.4, per_seal)
	_processing = true
	infused_seals = 0
	_advance_procession()


static func _all_goetia_numbers() -> Array:
	var out: Array = []
	for entry: Dictionary in GoeticSeals.GOETIA:
		out.append(int(entry.number))
	return out


## 7919 is prime and large enough that consecutive demons do not produce
## neighbouring seals — Bael and Agares should not look related.
static func seed_for(number: int) -> int:
	return number * 7919


func _advance_procession() -> void:
	if _queue.is_empty():
		_processing = false
		_mode = ""
		set_process(false)
		procession_finished.emit(infused_seals)
		return
	_current_number = int(_queue.pop_front())
	begin_burn(seed_for(_current_number), _complexity, _per_seal * 0.55, fposmod(float(_current_number) * 0.7, TAU))


## The burn has finished and the strokes are gone. Re-form the whole seal —
## same seed, so it is the same glyph — and send it into the chip.
func _begin_infuse() -> void:
	_mode = "infuse"
	_elapsed = 0.0
	_duration = maxf(0.2, _per_seal * 0.45)
	_strokes = CellOutzType.seal_strokes(seed_for(_current_number), _complexity)


func _draw_live_infuse(progress: float) -> void:
	# Accelerating rather than linear: a seal that drains into a chip should
	# leave slowly and arrive fast.
	var eased := progress * progress
	var target := _chip_at + Vector3(0, _top_y + 0.006, 0)
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = GOLD
	material.emission_energy_multiplier = 1.2 + progress * 2.2
	# Copper going in, gold arriving. The metal changing is the tell that it
	# crossed from the board into the part.
	var tone := EMBER.lerp(GOLD, progress)
	for stroke: PackedVector2Array in _strokes:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		mesh.surface_set_color(tone)
		for point: Vector3 in _stroke_points_3d(stroke):
			mesh.surface_add_vertex(point.lerp(target, eased))
		mesh.surface_end()
	_live_mesh.mesh = mesh
	_light_pins(1.0 - progress)


## The chip's legs carry the count. A flash as each one lands, over a floor
## that rises with how many are already in there — so a chip holding sixty
## seals looks different from a bare one before anything happens to it.
func _light_pins(flash: float) -> void:
	var settled := clampf(float(infused_seals) / 72.0, 0.0, 1.0)
	for pin in _chip_pins:
		var material := pin.material_override as StandardMaterial3D
		if material == null:
			continue
		material.emission_enabled = true
		material.emission = GOLD
		material.emission_energy_multiplier = settled * 0.9 + flash * 1.8
	if _chip_body != null:
		var body := _chip_body.material_override as StandardMaterial3D
		if body != null:
			body.emission_enabled = true
			body.emission = GOLD
			body.emission_energy_multiplier = settled * 0.35


func _finish_infuse() -> void:
	infused_seals += 1
	var record: Dictionary = GoeticSeals.seal(_current_number)
	seal_infused.emit(_current_number, str(record.get("name", "")), infused_seals)
	_live_mesh.mesh = null
	_light_pins(0.0)
	_advance_procession()


func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	if _mode == "bind":
		_draw_live_bind(progress)
	elif _mode == "burn":
		_draw_live_burn(progress)
	elif _mode == "infuse":
		_draw_live_infuse(progress)
	if progress < 1.0:
		return
	# A burn inside a procession does not scar the board. It goes into the
	# chip instead, which is the only difference between the two verbs and
	# the reason seventy-two of them do not turn one patch into mud.
	if _mode == "burn" and _processing:
		_begin_infuse()
	elif _mode == "infuse":
		_finish_infuse()
	else:
		_bake_current()


func _draw_live_bind(progress: float) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = COPPER
	material.emission_enabled = true
	material.emission = COPPER
	material.emission_energy_multiplier = 1.2 + progress * 0.6
	var drawn := clampi(roundi(progress * _strokes.size()), 0, _strokes.size())
	for index in drawn:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		_emit_stroke(mesh, _strokes[index])
		mesh.surface_end()
	_live_mesh.mesh = mesh


func _draw_live_burn(progress: float) -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = EMBER
	material.emission_energy_multiplier = 1.4
	var front := TAU * progress
	for stroke: PackedVector2Array in _strokes:
		var midpoint := Vector2.ZERO
		for point in stroke:
			midpoint += point
		midpoint /= maxf(1.0, float(stroke.size()))
		var stroke_angle := fposmod(midpoint.angle() - _front_angle, TAU)
		if stroke_angle < front:
			continue
		var at_front := stroke_angle < front + 0.55
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		_emit_stroke(mesh, stroke, EMBER if at_front else COPPER)
		mesh.surface_end()
	_live_mesh.mesh = mesh


func _emit_stroke(mesh: ImmediateMesh, stroke: PackedVector2Array, tone := COPPER) -> void:
	mesh.surface_set_color(tone)
	for point: Vector3 in _stroke_points_3d(stroke):
		mesh.surface_add_vertex(point)


## The animation ends and the mark does not go anywhere: baked as a static,
## permanent mesh rather than continuing to depend on the live overlay, the
## same distinction `_static`/`_baked` already draws between "the board as
## manufactured" and "what has happened to this one".
func _bake_current() -> void:
	var record := {"seed": _seed, "complexity": _complexity}
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	if _mode == "bind":
		bound_seals.append(record)
		material.albedo_color = COPPER
		material.metallic = 0.7
		material.emission_enabled = true
		material.emission = COPPER
		material.emission_energy_multiplier = 0.9
		for stroke: PackedVector2Array in _strokes:
			mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
			_emit_stroke(mesh, stroke)
			mesh.surface_end()
	else:
		burnt_seals.append(record)
		# E2.7. "Burn 1.0 leaves nothing but the memory of the ring" — the same
		# rule `draw_seal_burning` follows in 2D, kept true in 3D rather than
		# leaving the last live frame's partial scorch as the permanent mark.
		# A scar rather than a glow, but a real board's own soot still has a
		# warm, slightly lit edge against the green — plain black on dark
		# green vanishes entirely under this scene's lighting, which is not
		# the same as a mark that "stays".
		material.albedo_color = CHAR
		material.roughness = 0.95
		material.emission_enabled = true
		material.emission = Color("3a1f16")
		material.emission_energy_multiplier = 0.4
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		_emit_stroke(mesh, _strokes[0], CHAR)
		mesh.surface_end()
	var baked := MeshInstance3D.new()
	baked.mesh = mesh
	_baked.add_child(baked)
	_live_mesh.mesh = null
	_mode = ""
	set_process(false)
