class_name LabDressing
extends RefCounted

## What turns a tunnel into somewhere people worked, and then died in.
##
## Greg, on the Lower Works: *"this map is super scuffed ... overdetail a crazy
## lab ... with gore details"*. The district was eleven bays of pier-and-beam in
## a box -- about forty visible meshes over seventy metres -- and it ran under
## the `ossuary` environment, which carries the densest fog of any preset in
## `world_look.gd`. That is the same pairing the front door was already fixed
## for, and the note left there says it plainly: the fog "is why the street
## reads as untextured blocks".
##
## So the geometry is only half of the complaint and this file is that half.
## The rule it is built under is the one the brief has been asking for:
## **repeated detail goes in a `MultiMesh`.** Performance is a measured open
## item -- 39 fps, `process` at 20.16ms against a 16.67ms budget, 2141 visible
## meshes in the districts, and nothing anywhere using a `MultiMesh`. Dressing a
## corridor with a thousand loose `MeshInstance3D` nodes would be that same
## mistake at a larger size. Everything here that repeats is one instanced draw:
## panels, rivets, conduit, grates, jars, spatter, viscera. Only what a player
## walks up to and reads -- tanks, slabs, trolleys -- gets its own node.
##
## Nothing here is gameplay. It never adds a collider, so the district's
## movement and combat stay exactly as testable as they were.

const LAB_STEEL := Color("2b3230")
const LAB_ENAMEL := Color("4a4c42")
const DRIED_BLOOD := Color("2a0806")


## One instanced draw per repeated kind. The whole reason this file exists.
static func scatter(host: Node3D, mesh: Mesh, placements: Array, piece_name: String) -> MultiMeshInstance3D:
	if host == null or not is_instance_valid(host) or mesh == null or placements.is_empty():
		return null
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = placements.size()
	for index in placements.size():
		batch.set_instance_transform(index, placements[index] as Transform3D)
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.name = piece_name
	# Detail, not architecture: it must never cast the district into shadow, and
	# it never becomes another thing for a body to collide with.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(node)
	return node


static func _lit(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## Dress the corridor between `from_z` and `to_z`.
##
## Returns what it built, so a test can hold it to the instancing rule rather
## than only to "something appeared".
static func dress(host: Node3D, from_z: float, to_z: float, half_width: float, ceiling: float, seed_value: int, avoid: Array = []) -> Dictionary:
	if host == null or not is_instance_valid(host):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var near := minf(from_z, to_z)
	var far := maxf(from_z, to_z)
	var built := {"batches": 0, "instances": 0, "tanks": 0, "slabs": 0, "trolleys": 0, "pools": 0}

	_panel_the_walls(host, near, far, half_width, rng, built)
	_run_the_conduit(host, near, far, half_width, ceiling, rng, built)
	_grate_the_floor(host, near, far, rng, built)
	_shelve_the_jars(host, near, far, half_width, rng, built)
	_spatter(host, near, far, half_width, rng, built)
	_stand_the_tanks(host, near, far, half_width, rng, built, avoid)
	_lay_the_slabs(host, near, far, half_width, rng, built, avoid)
	_hang_the_viscera(host, near, far, half_width, ceiling, rng, built)
	return built


## Wall panelling and its rivets. Two batches carry the whole seventy metres of
## both walls, which is what stops a flat slab reading as a grey box.
static func _panel_the_walls(host: Node3D, near: float, far: float, half_width: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var panel := BoxMesh.new()
	panel.size = Vector3(0.09, 2.3, 2.6)
	panel.material = WorldLook.surface(LAB_ENAMEL, "metal", 4100)
	var rivet := SphereMesh.new()
	rivet.radius = 0.035
	rivet.height = 0.07
	rivet.radial_segments = 6
	rivet.rings = 3
	rivet.material = WorldLook.surface(Color("6a6256"), "metal", 4101)

	var panels: Array = []
	var rivets: Array = []
	var run := near
	while run < far:
		for side in [-1.0, 1.0]:
			# Two courses, so the wall has a waist rather than one flat face.
			for course in 2:
				var height := 1.35 + float(course) * 2.35
				var jitter := rng.randf_range(-0.03, 0.03)
				panels.append(Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 0.12), height + jitter, run + 1.3)))
				for stud in 4:
					var stud_y := height - 1.0 + float(stud) * 0.66
					rivets.append(Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 0.19), stud_y, run + 0.15)))
					rivets.append(Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 0.19), stud_y, run + 2.45)))
		run += 2.7

	_count(built, scatter(host, panel, panels, "WallPanels"), panels.size())
	_count(built, scatter(host, rivet, rivets, "PanelRivets"), rivets.size())


## Conduit along both ceiling edges, and the hangers holding it up.
static func _run_the_conduit(host: Node3D, near: float, far: float, half_width: float, ceiling: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.11
	pipe.bottom_radius = 0.11
	pipe.height = 3.2
	pipe.radial_segments = 8
	pipe.material = WorldLook.surface(Color("3b2c1e"), "rust", 4200)
	var hanger := BoxMesh.new()
	hanger.size = Vector3(0.05, 0.6, 0.05)
	hanger.material = WorldLook.surface(Color("2a2420"), "metal", 4201)

	# Laid along Z, so the cylinder's own Y axis turns a quarter turn.
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	var pipes: Array = []
	var hangers: Array = []
	var run := near
	while run < far:
		for side in [-1.0, 1.0]:
			for line in 3:
				var offset := half_width - 1.1 - float(line) * 0.34
				var drop := ceiling - 0.55 - float(line % 2) * 0.28
				pipes.append(Transform3D(along, Vector3(side * offset, drop, run + 1.6)))
			hangers.append(Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 1.4), ceiling - 0.3, run + rng.randf_range(0.2, 3.0))))
		run += 3.2

	_count(built, scatter(host, pipe, pipes, "CeilingConduit"), pipes.size())
	_count(built, scatter(host, hanger, hangers, "ConduitHangers"), hangers.size())


## Drainage. A lab where bodies are opened has somewhere for it to go, and a
## grated channel down the centre line is the cheapest way to say so.
static func _grate_the_floor(host: Node3D, near: float, far: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var grate := BoxMesh.new()
	grate.size = Vector3(1.1, 0.04, 0.9)
	grate.material = WorldLook.surface(Color("191512"), "metal", 4300)
	var slat := BoxMesh.new()
	slat.size = Vector3(1.0, 0.03, 0.06)
	slat.material = WorldLook.surface(Color("0d0b09"), "metal", 4301)

	var grates: Array = []
	var slats: Array = []
	var run := near
	while run < far:
		grates.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, run)))
		for bar in 7:
			slats.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.055, run - 0.36 + float(bar) * 0.12)))
		run += rng.randf_range(2.6, 3.4)

	_count(built, scatter(host, grate, grates, "FloorGrates"), grates.size())
	_count(built, scatter(host, slat, slats, "GrateSlats"), slats.size())


## Racking, and what is kept on it. The jars are one batch of a few hundred.
static func _shelve_the_jars(host: Node3D, near: float, far: float, half_width: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var shelf := BoxMesh.new()
	shelf.size = Vector3(0.62, 0.06, 3.0)
	shelf.material = WorldLook.surface(LAB_STEEL, "metal", 4400)
	var jar := CylinderMesh.new()
	jar.top_radius = 0.088
	jar.bottom_radius = 0.088
	jar.height = 0.25
	jar.radial_segments = 8
	jar.material = _lit(Color(0.20, 0.34, 0.22, 1.0), 0.55)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.094
	lid.bottom_radius = 0.094
	lid.height = 0.035
	lid.radial_segments = 8
	lid.material = WorldLook.surface(Color("5a4a2e"), "metal", 4401)

	var shelves: Array = []
	var jars: Array = []
	var lids: Array = []
	var run := near + 3.0
	while run < far - 3.0:
		for side in [-1.0, 1.0]:
			# Skip a bank now and then, so the wall is not a wallpaper repeat.
			if rng.randf() < 0.32:
				continue
			for tier in 3:
				var tier_y := 0.95 + float(tier) * 0.78
				shelves.append(Transform3D(Basis.IDENTITY, Vector3(side * (half_width - 0.45), tier_y, run)))
				for slot in 9:
					if rng.randf() < 0.22:
						continue
					var jar_z := run - 1.3 + float(slot) * 0.32
					var jar_at := Vector3(side * (half_width - 0.45) + rng.randf_range(-0.07, 0.07), tier_y + 0.16, jar_z)
					jars.append(Transform3D(Basis.IDENTITY, jar_at))
					lids.append(Transform3D(Basis.IDENTITY, jar_at + Vector3(0, 0.14, 0)))
		run += rng.randf_range(4.2, 6.0)

	_count(built, scatter(host, shelf, shelves, "JarShelves"), shelves.size())
	_count(built, scatter(host, jar, jars, "SpecimenJars"), jars.size())
	_count(built, scatter(host, lid, lids, "JarLids"), lids.size())


## Dried spatter on the walls and the floor, as flat quads rather than decals:
## one batch of a few hundred marks costs one draw, and a `Decal` each would be
## a few hundred of the most expensive node in the renderer.
static func _spatter(host: Node3D, near: float, far: float, half_width: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var mark := QuadMesh.new()
	mark.size = Vector2(0.9, 0.9)
	var mark_material := StandardMaterial3D.new()
	mark_material.albedo_color = DRIED_BLOOD
	mark_material.roughness = 0.95
	# Flat against a surface, so it must not fight the wall behind it.
	mark_material.render_priority = 1
	mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material = mark_material

	var marks: Array = []
	var count := int((far - near) * 1.6)
	for index in count:
		var run := rng.randf_range(near, far)
		var spread := rng.randf_range(0.35, 1.5)
		var spin := Basis(Vector3.FORWARD, rng.randf_range(0.0, TAU)).scaled(Vector3(spread, spread, spread))
		if rng.randf() < 0.55:
			# On the floor, facing up.
			var flat := Basis(Vector3.RIGHT, -PI * 0.5) * spin
			marks.append(Transform3D(flat, Vector3(rng.randf_range(-half_width + 0.6, half_width - 0.6), 0.02, run)))
		else:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var facing := Basis(Vector3.UP, PI * 0.5 * side) * spin
			marks.append(Transform3D(facing, Vector3(side * (half_width - 0.25), rng.randf_range(0.3, 3.4), run)))
	_count(built, scatter(host, mark, marks, "DriedSpatter"), marks.size())


## The tanks. These are things a player walks up to, so they are real nodes with
## their own light and something recognisable suspended inside.
static func _stand_the_tanks(host: Node3D, near: float, far: float, half_width: float, rng: RandomNumberGenerator, built: Dictionary, avoid: Array) -> void:
	var run := near + 6.0
	while run < far - 5.0:
		if _reserved(run, avoid):
			run += 3.0
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var at := Vector3(side * (half_width - 2.1), 0.0, run)

		# LabVat is the hardware; this tank holds a part rather than a body.
		LabVat.build(host, at, int(run * 10.0), 2.5, 0.62, false, false, false)

		# Something in it. `BodyMesh` is already this project's vocabulary for
		# parts of people, so a tank holds an actual one rather than a blob.
		var specimen := MeshInstance3D.new()
		var pick := rng.randi() % 3
		if pick == 0:
			specimen.mesh = BodyMesh.skull(0.30)
		elif pick == 1:
			specimen.mesh = BodyMesh.arm(0.62)
		else:
			specimen.mesh = BodyMesh.lump(0.26, int(rng.randi()), 10)
		specimen.material_override = WorldLook.surface(Color("6d5b50"), "flesh", int(rng.randi()))
		specimen.position = at + Vector3(0, 1.75, 0)
		specimen.rotation.y = rng.randf_range(0.0, TAU)
		host.add_child(specimen)

		var glow := OmniLight3D.new()
		glow.position = at + Vector3(0, 1.8, 0)
		glow.light_color = Color("3fae86")
		glow.light_energy = 1.35
		glow.omni_range = 4.2
		glow.shadow_enabled = false
		host.add_child(glow)

		built["tanks"] = int(built.get("tanks", 0)) + 1
		run += rng.randf_range(7.5, 11.0)


## Slabs, the trolleys beside them, and what is left on both.
static func _lay_the_slabs(host: Node3D, near: float, far: float, half_width: float, rng: RandomNumberGenerator, built: Dictionary, avoid: Array) -> void:
	var run := near + 9.0
	while run < far - 6.0:
		if _reserved(run, avoid):
			run += 3.0
			continue
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var at := Vector3(side * (half_width - 5.0), 0.0, run)

		var top := MeshInstance3D.new()
		var top_mesh := BoxMesh.new()
		top_mesh.size = Vector3(0.96, 0.09, 2.1)
		top_mesh.material = WorldLook.surface(Color("4d5450"), "metal", 4600)
		top.mesh = top_mesh
		top.position = at + Vector3(0, 0.92, 0)
		host.add_child(top)
		for leg_index in 4:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.045
			leg_mesh.bottom_radius = 0.045
			leg_mesh.height = 0.88
			leg_mesh.radial_segments = 6
			leg_mesh.material = WorldLook.surface(LAB_STEEL, "metal", 4601)
			leg.mesh = leg_mesh
			leg.position = at + Vector3(0.38 * (1.0 if leg_index % 2 else -1.0), 0.44, 0.86 * (1.0 if leg_index < 2 else -1.0))
			host.add_child(leg)

		# What was being worked on, left where it was being worked on.
		for piece_index in 3:
			var piece := MeshInstance3D.new()
			piece.mesh = BodyMesh.lump(rng.randf_range(0.07, 0.15), int(rng.randi()), 9)
			piece.material_override = WorldLook.surface(Color("5c1512"), "flesh", int(rng.randi()))
			piece.position = at + Vector3(rng.randf_range(-0.3, 0.3), 1.02, rng.randf_range(-0.8, 0.8))
			host.add_child(piece)

		var trolley := MeshInstance3D.new()
		var trolley_mesh := BoxMesh.new()
		trolley_mesh.size = Vector3(0.52, 0.06, 0.82)
		trolley_mesh.material = WorldLook.surface(Color("58524a"), "metal", 4602)
		trolley.mesh = trolley_mesh
		trolley.position = at + Vector3(side * -0.95, 0.86, 0.5)
		host.add_child(trolley)
		for tool_index in 4:
			var instrument := MeshInstance3D.new()
			var instrument_mesh := BoxMesh.new()
			instrument_mesh.size = Vector3(0.022, 0.016, rng.randf_range(0.16, 0.30))
			instrument_mesh.material = _lit(Color("8d9aa0"), 0.22)
			instrument.mesh = instrument_mesh
			instrument.position = trolley.position + Vector3(-0.16 + float(tool_index) * 0.1, 0.05, rng.randf_range(-0.2, 0.2))
			instrument.rotation.y = rng.randf_range(-0.3, 0.3)
			host.add_child(instrument)

		# The floor under a slab, through the system that already models how
		# blood spreads and dries rather than a red disc laid on the ground.
		BloodPool.keep(host, at + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.9, 0.9)), rng.randf_range(0.9, 2.2))
		built["pools"] = int(built.get("pools", 0)) + 1
		built["slabs"] = int(built.get("slabs", 0)) + 1
		built["trolleys"] = int(built.get("trolleys", 0)) + 1
		run += rng.randf_range(11.0, 15.0)


## Strung from the ceiling. One batch, because there are a lot of them and not
## one of them is a thing you walk up to and read.
static func _hang_the_viscera(host: Node3D, near: float, far: float, half_width: float, ceiling: float, rng: RandomNumberGenerator, built: Dictionary) -> void:
	var strand := BodyMesh.twisted_strand(0.9, 0.035, 77)
	var hook := CylinderMesh.new()
	hook.top_radius = 0.02
	hook.bottom_radius = 0.02
	hook.height = 1.6
	hook.radial_segments = 5
	hook.material = WorldLook.surface(Color("2b2622"), "metal", 4701)

	var strands: Array = []
	var chains: Array = []
	var count := int((far - near) * 0.22)
	for index in count:
		var run := rng.randf_range(near + 2.0, far - 2.0)
		var lateral := rng.randf_range(-half_width + 2.5, half_width - 2.5)
		var drop := ceiling - rng.randf_range(2.2, 4.4)
		var sway := Basis(Vector3.FORWARD, rng.randf_range(-0.22, 0.22))
		strands.append(Transform3D(sway, Vector3(lateral, drop, run)))
		chains.append(Transform3D(Basis.IDENTITY, Vector3(lateral, drop + 1.25, run)))

	var strand_batch := scatter(host, strand, strands, "HangingViscera")
	if strand_batch != null:
		# `twisted_strand` carries no material of its own, unlike the primitives.
		strand_batch.material_override = WorldLook.surface(Color("4a1210"), "flesh", 4700)
	_count(built, strand_batch, strands.size())
	_count(built, scatter(host, hook, chains, "MeatHooks"), chains.size())


## Stretches the caller has already built something floor-standing into.
##
## Only the tanks and the slabs ask: they are the two things tall enough to
## grow up through a gallery walkway, and a specimen tank standing through the
## floor somebody walks on is the one detail that would read as broken rather
## than as dressing. Each entry is an x-range along the corridor as a `Vector2`.
static func _reserved(at_z: float, avoid: Array) -> bool:
	for span in avoid:
		var range_z := span as Vector2
		if at_z >= range_z.x and at_z <= range_z.y:
			return true
	return false


static func _count(built: Dictionary, batch: MultiMeshInstance3D, instances: int) -> void:
	if batch == null:
		return
	built["batches"] = int(built.get("batches", 0)) + 1
	built["instances"] = int(built.get("instances", 0)) + instances
