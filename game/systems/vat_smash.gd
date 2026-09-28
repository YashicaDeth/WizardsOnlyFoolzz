extends RefCounted

## Smashing the other tanks on the Growing Floor (Greg, 24 September: "make
## sure you're able to smash the glass and let the liquid and the yangas out
## of the vats post creation"; `DESIGN/BINGYANG.md`: vats you can smash to
## free the subject inside, and letting one out is the player's choice).
##
## Once you are out of your own tank, look at another one up close and
## click. The restraint or the axe breaks the glass in two blows, bare
## hands in four. Each blow cracks it. When it goes, the glass flies, the
## medium drains out across the grating, and the subject inside climbs out as
## a loose bingyanger: the Support Unit's own `Bingyanger`, friendly or
## hostile by its roll. Everything is filed in WorldHistory.

const BINGYANGER := preload("res://systems/bingyanger.gd")

const REACH := 2.3
const AIM_DOT := 0.86
const BLOWS_ARMED := 2
const BLOWS_BARE := 4
const DRAIN_SECONDS := 1.8
const CLIMB_OUT_AT := 0.9
const SPILL_RADIUS := 1.4

var host: Node3D
var tanks: Array[Dictionary] = []
var freed: Array = []


func _init(owner: Node3D) -> void:
	host = owner


## One tank that can be broken. `root` is what `LabVat.build` returned;
## `cradled` is the seated body in the near tanks, if there is one.
func register(root: Node3D, at: Vector3, seed_value: int, cradled: Node3D = null) -> void:
	var medium := root.get_node_or_null("Medium") as MeshInstance3D
	tanks.append({
		"root": root, "at": at, "seed": seed_value, "hits": 0, "broken": false,
		"glass": root.get_node_or_null("Glass"), "medium": medium,
		"medium_y": medium.position.y if medium != null else 1.5,
		"curled": root.get_node_or_null("Curled"), "cradled": cradled,
		"since": -1.0, "puddle": null, "freed": null,
	})


## The tank the camera is looking at, close enough to hit, or -1.
func aimed(camera: Camera3D) -> int:
	if camera == null:
		return -1
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var best := -1
	var best_dot := AIM_DOT
	for index in tanks.size():
		var tank: Dictionary = tanks[index]
		if bool(tank.broken):
			continue
		var at: Vector3 = tank.at
		var flat := Vector2(at.x - from.x, at.z - from.z).length()
		if flat > REACH:
			continue
		var to := (at + Vector3(0, 1.5, 0) - from).normalized()
		var dot := forward.dot(to)
		if dot > best_dot:
			best_dot = dot
			best = index
	return best


func blows_needed(weapon: String) -> int:
	return BLOWS_ARMED if weapon in ["restraint", "axe"] else BLOWS_BARE


func prompt_for(camera: Camera3D, weapon: String) -> String:
	var index := aimed(camera)
	if index < 0:
		return ""
	var left := blows_needed(weapon) - int(tanks[index].hits)
	var what := "WITH THE RESTRAINT" if weapon == "restraint" else ("WITH THE AXE" if weapon == "axe" else "WITH YOUR FISTS")
	return "[CLICK] SMASH THE GLASS %s   //   %d MORE" % [what, left]


## One blow on tank `index`. Returns what happened.
func strike(index: int, weapon: String) -> Dictionary:
	if index < 0 or index >= tanks.size() or bool(tanks[index].broken):
		return {"hit": false}
	var tank: Dictionary = tanks[index]
	tank.hits = int(tank.hits) + 1
	_crack(tank)
	if host.get("breach_shake") != null:
		host.set("breach_shake", maxf(float(host.get("breach_shake")), 0.18))
	if int(tank.hits) < blows_needed(weapon):
		WorldHistory.record_event("growing_floor_vat_cracked", {"tank": int(tank.seed), "by": weapon if not weapon.is_empty() else "fists", "hits": int(tank.hits)})
		return {"hit": true, "broken": false}
	_break(tank, weapon)
	return {"hit": true, "broken": true}


func step(delta: float) -> void:
	for tank in tanks:
		if not bool(tank.broken):
			continue
		tank.since = float(tank.since) + delta
		var drained := clampf(float(tank.since) / DRAIN_SECONDS, 0.0, 1.0)
		var medium := tank.medium as MeshInstance3D
		if medium != null and is_instance_valid(medium):
			var level := maxf(0.02, 1.0 - drained)
			var full_height := (medium.mesh as CylinderMesh).height if medium.mesh is CylinderMesh else 2.2
			medium.scale.y = level
			medium.position.y = float(tank.medium_y) - full_height * 0.5 * (1.0 - level)
			medium.visible = level > 0.03
		var puddle := tank.puddle as MeshInstance3D
		if puddle != null and is_instance_valid(puddle):
			var spread := ease(drained, 0.5)
			puddle.scale = Vector3(spread, 1.0, spread) * 1.0 + Vector3(0.01, 0, 0.01)
		if tank.freed == null and float(tank.since) >= CLIMB_OUT_AT:
			_free(tank)
	for loose in freed:
		if is_instance_valid(loose):
			loose.step(delta)


func broken_count() -> int:
	return tanks.filter(func(tank: Dictionary) -> bool: return bool(tank.broken)).size()


# --- the glass ---------------------------------------------------------------

func _crack(tank: Dictionary) -> void:
	var glass := tank.glass as MeshInstance3D
	if glass == null:
		return
	var material := (glass.mesh as PrimitiveMesh).material as StandardMaterial3D if glass.mesh is PrimitiveMesh else null
	if material != null:
		# Each tank owns its own glass, so one crack doesn't cloud the room.
		if not bool(tank.get("own_glass", false)):
			material = material.duplicate()
			(glass.mesh as PrimitiveMesh).material = material
			tank["own_glass"] = true
		material.albedo_color.a = minf(0.55, material.albedo_color.a + 0.12)
		material.albedo_color = material.albedo_color.lerp(Color(0.75, 0.8, 0.78, material.albedo_color.a), 0.25)
	# A star of cracks where the blow landed, on the face toward the player.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tank.seed) * 131 + int(tank.hits)
	var face := rng.randf() * TAU
	var radius := 0.74
	var centre := Vector3(cos(face) * radius, 1.2 + rng.randf() * 1.2, sin(face) * radius)
	var crack_material := StandardMaterial3D.new()
	crack_material.albedo_color = Color(0.9, 0.92, 0.88, 0.8)
	crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cracks := (tank.root as Node3D).get_node_or_null("Cracks") as Node3D
	if cracks == null:
		cracks = Node3D.new()
		cracks.name = "Cracks"
		(tank.root as Node3D).add_child(cracks)
	for line in 7:
		var crack := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.008, rng.randf_range(0.15, 0.45), 0.008)
		box.material = crack_material
		crack.mesh = box
		crack.name = "Crack"
		crack.position = centre
		crack.rotation = Vector3(0, -face + PI * 0.5, rng.randf() * TAU)
		cracks.add_child(crack)


func _break(tank: Dictionary, weapon: String) -> void:
	tank.broken = true
	tank.since = 0.0
	var root := tank.root as Node3D
	var glass := tank.glass as Node3D
	if glass != null:
		glass.visible = false
	var cracks := root.get_node_or_null("Cracks")
	if cracks != null:
		cracks.queue_free()
	if host.get("opening_audio") != null and host.opening_audio != null:
		host.opening_audio.cue("glass")
	if host.get("breach_shake") != null:
		host.set("breach_shake", 0.45)
	_shards(tank)
	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SPILL_RADIUS
	disc.bottom_radius = SPILL_RADIUS
	disc.height = 0.02
	var spill := StandardMaterial3D.new()
	# The same dark wet fluid as your own tank's spill, not a pale disc.
	spill.albedo_color = Color("140807")
	spill.roughness = 0.07
	spill.metallic = 0.25
	spill.metallic_specular = 0.7
	disc.material = spill
	puddle.name = "Spill"
	puddle.mesh = disc
	puddle.position = Vector3(0, 0.02, 0)
	puddle.scale = Vector3(0.01, 1.0, 0.01)
	root.add_child(puddle)
	tank.puddle = puddle
	WorldHistory.record_event("growing_floor_vat_smashed", {"tank": int(tank.seed), "by": weapon if not weapon.is_empty() else "fists"})


func _shards(tank: Dictionary) -> void:
	var shards = host.get("glass_shards")
	if shards == null:
		return
	var at: Vector3 = tank.at
	var shard_material := StandardMaterial3D.new()
	shard_material.albedo_color = Color(0.46, 0.2, 0.15, 0.4)
	shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shard_material.metallic = 0.35
	shard_material.roughness = 0.14
	for index in 22:
		var shard := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.04, 0.2), randf_range(0.06, 0.28), 0.008)
		mesh.material = shard_material
		shard.mesh = mesh
		var around := TAU * randf()
		shard.position = at + Vector3(cos(around) * 0.74, 0.6 + randf() * 2.1, sin(around) * 0.74)
		host.add_child(shard)
		var out := Vector3(cos(around), randf_range(0.05, 0.5), sin(around)).normalized()
		shards.append({"node": shard, "velocity": out * randf_range(2.4, 6.0), "life": 3.0})


# --- the yanga inside ---------------------------------------------------------

## The subject climbs out over the rim: whatever floated in there is gone from
## the tank, and a loose bingyanger stands in the spill, facing the aisle.
func _free(tank: Dictionary) -> void:
	var at: Vector3 = tank.at
	for key in ["curled", "cradled"]:
		var body = tank.get(key)
		if body != null and is_instance_valid(body):
			(body as Node3D).visible = false
	var loose = BINGYANGER.new()
	var toward_aisle := -signf(at.x) if absf(at.x) > 0.01 else 1.0
	loose.position = at + Vector3(toward_aisle * 1.25, 0, 0)
	loose.name = "Freed_%d" % int(tank.seed)
	host.add_child(loose)
	var id := "growing_floor_subject_%d" % int(tank.seed)
	loose.build(id, 9100 + int(tank.seed) * 17, true)
	var player = host.get("player")
	loose.bind(player, null, [])
	loose.release("vat_smashed")
	WorldHistory.update_subject(id, {
		"place": "growing_floor", "role": "Broken out of a Growing Floor vat",
		"memory": "A vat subject that came out wrong. The Hunter smashed its tank and let it out.",
	}, "growing_floor_subject_freed")
	if host.has_method("_on_freed_subject_struck"):
		loose.struck_player.connect(host._on_freed_subject_struck)
	tank.freed = loose
	freed.append(loose)
