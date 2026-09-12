class_name GoreChunks
extends RefCounted

## Pieces of people, as physical objects that know what they are.
##
## Greg's brief: *"chunk physics that then get down to the layers of blood bones
## organs chunks — that's how you can rob cybernetics."* The second half is why
## this is a system rather than an effect. A chunk is not decoration that
## despawns; it is an **identified object** carrying its layer, its zone, the
## subject it came off and, where relevant, which organ or which implant. Three
## unbuilt things need exactly that and cannot be built without it:
##
## - **B5, robbing cybernetics.** You dig through the layers and the part that
##   comes out is the part that was installed, with a name and an owner.
## - **Camera rituals** (`DESIGN/RITUAL_AND_KARMA.md`). A ritual that says
##   "photograph five gored heads" has to be able to check that what is in frame
##   is actually a head and actually gored.
## - **The economy.** Organs and hardware are worth something to the Choir, and
##   the thing you sell has to be a specific thing.
##
## Depth is the other half. A hit does not produce a generic red spray — it
## reaches a *layer*, and what comes off is everything it went through. A sword
## into a healthy arm throws skin and muscle. The same sword into an arm already
## opened reaches bone. Blunt trauma barely breaks the skin and shatters what is
## underneath, which is why it gets its own rule.

enum Layer {SKIN, FAT, MUSCLE, BONE, ORGAN, CYBERNETIC}

const LAYER_NAMES := ["skin", "fat", "muscle", "bone", "organ", "cybernetic"]

## Tints per layer. Fat is the one that sells it: a wound that is only red reads
## as paint, and a wound with yellow in it reads as a body.
const LAYER_TINTS := {
	Layer.SKIN: "9a6c5c",
	Layer.FAT: "c8b26a",
	Layer.MUSCLE: "7a1a16",
	Layer.BONE: "cfc2a4",
	Layer.ORGAN: "6d100e",
	Layer.CYBERNETIC: "7d8894",
}

const ORGAN_TINTS := {
	"brain": "9c8a86", "heart": "6d100e", "left_lung": "8a4d4a", "right_lung": "8a4d4a",
	"liver": "5a2015", "gut": "8d7a52", "spine": "cfc2a4",
}

## Chunks are rigid bodies, so this cap is a frame-rate contract rather than an
## aesthetic one. The same reasoning as `BaselineHuman.MAX_LIVE_GORE`: twelve
## drivers shedding unbounded physics bodies in a pileup is a bug, not atmosphere.
const MAX_CHUNKS := 90

## A chunk that survives this long has fully rotted: discoloured, and a scent
## source other systems can query. Most chunks never see it - the cap and the
## whole-limb cleanup timer recycle them first - but one left undisturbed in a
## corner of the world is meant to read as a body forgetting nobody found it.
const ROT_SECONDS := 240.0

static var live: Array[Node3D] = []


## A severed limb is a chunk too, but it is an entire body zone rather than one
## tissue layer. Registering it here gives CARRY, rituals and the economy the
## same identity contract as every smaller piece.
static func register_whole_limb(node: RigidBody3D, zone: String, subject_id: String) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	if live.size() >= MAX_CHUNKS:
		_recycle_oldest()
	var info := {
		"layer": -1,
		"layer_name": "limb",
		"whole_limb": true,
		"zone": zone,
		"subject_id": subject_id,
		"organ_id": "",
		"implant": "",
		"condition": 1.0,
		"taken": false,
		"spawn_msec": Time.get_ticks_msec(),
	}
	node.set_meta("chunk", info)
	live.append(node)
	_watch_chunk(node)
	_schedule_rot(node)
	return info


## How deep a blow reached, as a `Layer`. The zone's current condition is part of
## the answer — the second cut into the same arm goes further than the first,
## which is the whole reason a fight escalates visually.
static func depth_for(damage: float, damage_type: String, health_ratio: float) -> int:
	var penetrating := damage_type in ["cut", "puncture", "ballistic", "shear"]
	var reach := damage / (10.0 if penetrating else 20.0)
	reach += (1.0 - clampf(health_ratio, 0.0, 1.0)) * 3.0
	if not penetrating:
		# Blunt does not open a body the way an edge does, but it does break what
		# is under the skin - so it reaches bone without passing through muscle
		# in the way a cut would.
		reach -= 0.6
		if damage >= 25.0:
			reach = maxf(reach, float(Layer.BONE))
	return clampi(int(reach), 0, Layer.CYBERNETIC)


## Throws the layers a blow went through. `subject_id` is what makes the pieces
## traceable back to a person, which is the point of the whole system.
static func burst(host: Node3D, origin: Vector3, heading: Vector3, info: Dictionary, detail: float = 1.0) -> Array:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return []
	var depth := int(info.get("depth", Layer.SKIN))
	var zone := str(info.get("zone", "torso"))
	var subject_id := str(info.get("subject_id", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = (hash(subject_id + zone) + int(origin.x * 1000.0) + Time.get_ticks_msec()) & 0x7fffffff
	var produced: Array = []
	var direction := heading.normalized() if heading.length() > 0.01 else Vector3.UP
	for layer in range(0, depth + 1):
		# Deeper layers shed fewer, larger pieces. Skin tears into flaps; bone
		# gives you a shard, not a shower of them.
		var count := maxi(1, roundi(float(3 - mini(layer, 2)) * detail))
		if layer == Layer.CYBERNETIC:
			count = 1
		var layer_produced := 0
		for index in count:
			if live.size() >= MAX_CHUNKS:
				_recycle_oldest()
			var chunk := _make_chunk(layer, zone, subject_id, info, rng)
			if chunk == null:
				continue
			host.get_tree().current_scene.add_child(chunk)
			chunk.global_position = origin + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06), rng.randf_range(-0.06, 0.06))
			var scatter := direction * rng.randf_range(1.4, 3.6) + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.4, 2.0), rng.randf_range(-1.2, 1.2))
			chunk.apply_impulse(scatter * chunk.mass)
			chunk.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			live.append(chunk)
			produced.append(chunk)
			_watch_chunk(chunk)
			_schedule_rot(chunk)
			layer_produced += 1
		# One impact voice per layer actually reached, not per piece - a burst
		# through three layers sounds like three distinct events, not a hail.
		if layer_produced > 0:
			play_impact(host, origin, layer)
	return produced


static func _make_chunk(layer: int, zone: String, subject_id: String, info: Dictionary, rng: RandomNumberGenerator) -> RigidBody3D:
	var organ_id := str(info.get("organ_id", ""))
	var implant := str(info.get("implant", ""))
	# The two identified layers only exist if the body actually had one there.
	# Inventing an organ or a piece of hardware that was never installed would
	# make every downstream system - loot, rituals, the economy - lie.
	if layer == Layer.ORGAN and organ_id == "":
		return null
	if layer == Layer.CYBERNETIC and implant == "":
		return null

	var body := RigidBody3D.new()
	body.name = "chunk_%s_%s" % [LAYER_NAMES[layer], zone]
	body.mass = [0.12, 0.18, 0.4, 0.6, 0.5, 0.9][layer]
	body.continuous_cd = true

	var mesh_instance := MeshInstance3D.new()
	var extent := 0.05
	var mesh_seed := rng.randi()
	match layer:
		Layer.SKIN:
			var flap_width := rng.randf_range(0.05, 0.11)
			var flap_length := rng.randf_range(0.05, 0.13)
			mesh_instance.mesh = BodyMesh.torn_flap(flap_width, flap_length, mesh_seed)
			extent = maxf(flap_width, flap_length) * 0.5
		Layer.FAT:
			var fat_radius := rng.randf_range(0.020, 0.038)
			mesh_instance.mesh = BodyMesh.lump(fat_radius, mesh_seed)
			extent = fat_radius
		Layer.MUSCLE:
			var strand_length := rng.randf_range(0.07, 0.16)
			var strand_radius := rng.randf_range(0.014, 0.026)
			mesh_instance.mesh = BodyMesh.twisted_strand(strand_length, strand_radius, mesh_seed)
			extent = strand_length * 0.5
		Layer.BONE:
			mesh_instance.mesh = BodyMesh.long_bone(rng.randf_range(0.06, 0.13), rng.randf_range(0.007, 0.013))
			extent = 0.07
		Layer.ORGAN:
			mesh_instance.mesh = BodyMesh.lump(0.055, mesh_seed, 10)
			extent = 0.055
		Layer.CYBERNETIC:
			mesh_instance.mesh = BodyMesh.hardware_shard(0.09, mesh_seed)
			extent = 0.06

	var tint := Color(str(LAYER_TINTS[layer]))
	if layer == Layer.ORGAN:
		tint = Color(str(ORGAN_TINTS.get(organ_id, "6d100e")))
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.45 if layer in [Layer.BONE, Layer.CYBERNETIC] else 0.82
	material.metallic = 0.4 if layer == Layer.CYBERNETIC else 0.0
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.02, extent)
	collider.shape = shape
	body.add_child(collider)

	# The identity. Everything downstream reads this and nothing downstream
	# should ever have to guess from the node name.
	body.set_meta("chunk", {
		"layer": layer,
		"layer_name": LAYER_NAMES[layer],
		"zone": zone,
		"subject_id": subject_id,
		"organ_id": organ_id if layer == Layer.ORGAN else "",
		"implant": implant if layer == Layer.CYBERNETIC else "",
		"taken": false,
		"spawn_msec": Time.get_ticks_msec(),
	})
	return body


## What this piece is. Returns empty for anything that is not a chunk, so
## callers can test a raycast hit without checking the class first.
static func identify(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node.has_meta("chunk"):
		return {}
	return node.get_meta("chunk")


## Pick it up. Removes the physical piece from the world and hands back its
## identity for whoever is carrying it — this is the seam B5 plugs into, and the
## reason it returns the dictionary rather than the node.
static func take(node: Node) -> Dictionary:
	var info := identify(node)
	if info.is_empty() or bool(info.get("taken", false)):
		return {}
	info["taken"] = true
	live.erase(node)
	if is_instance_valid(node):
		node.queue_free()
	return info


## Everything currently on the floor that came off a given person. Rituals and
## the loot pass both want to ask this.
static func from_subject(subject_id: String) -> Array:
	var out: Array = []
	for chunk in live:
		var info := identify(chunk)
		if not info.is_empty() and str(info.get("subject_id", "")) == subject_id:
			out.append(chunk)
	return out


## Landing and rolling both leave a mark: this is what makes a floor "fill up"
## from combat rather than only from the blood spray that flew there directly.
## An `await` loop rather than a self-rescheduling lambda - a lambda that calls
## `connect(mark_loop)` on itself captures `mark_loop` by value at creation, so
## it closes over the variable's pre-assignment null rather than the finished
## function, and every reconnect after the first silently does nothing.
static func _watch_chunk(node: RigidBody3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.sleeping_state_changed.connect(func():
		if is_instance_valid(node) and node.sleeping:
			_mark_ground(node)
	)
	_track_rolling(node)


static func _track_rolling(node: RigidBody3D) -> void:
	var rolls_left := 3
	while rolls_left > 0 and is_instance_valid(node) and node.is_inside_tree() and not node.sleeping:
		await node.get_tree().create_timer(0.4).timeout
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		if node.linear_velocity.length() > 0.35:
			_mark_ground(node)
			rolls_left -= 1


static func _mark_ground(node: RigidBody3D) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var scene := node.get_tree().current_scene
	if scene == null:
		return
	BaselineHuman.mark_ground_for_chunk(node.get_world_3d(), scene, node.global_position, node.linear_velocity, 0.22)


## Per-layer voice for a hit: skin thuds, bone cracks, hardware clinks. Data
## rather than a switch buried inside audio code, so the mapping is one place
## and G5's later positional-audio pass can read the same table.
## G5.4. What each layer sounds like when something goes through it.
##
## The first pass gave every layer the same shape with different numbers on it,
## so bone and organ were the same burst at different pitches. They are not the
## same event. Bone **cracks** — a hard transient and then a ring that keeps
## going after the hit. An organ **bursts** — wet, and the pitch falls as it
## empties. A cybernetic **faults** — it sputters, because there is current in
## it. `character` selects that behaviour; the numbers only colour it.
static func impact_profile(layer: int) -> Dictionary:
	match layer:
		Layer.SKIN:
			return {"freq": 90.0, "noise": 0.55, "decay": 6.0, "gain": 0.55, "character": "slap"}
		Layer.FAT:
			return {"freq": 70.0, "noise": 0.75, "decay": 5.0, "gain": 0.6, "character": "slap"}
		Layer.MUSCLE:
			return {"freq": 55.0, "noise": 0.65, "decay": 4.5, "gain": 0.65, "character": "slap"}
		Layer.BONE:
			return {"freq": 620.0, "noise": 0.2, "decay": 10.0, "gain": 0.75, "character": "crack"}
		Layer.ORGAN:
			return {"freq": 96.0, "noise": 0.85, "decay": 4.0, "gain": 0.5, "character": "burst"}
		Layer.CYBERNETIC:
			return {"freq": 980.0, "noise": 0.08, "decay": 14.0, "gain": 0.7, "character": "fault"}
		_:
			return {"freq": 90.0, "noise": 0.55, "decay": 6.0, "gain": 0.5, "character": "slap"}


## One frame of a layer's impact, as a pure function of time. Split out from the
## buffer fill so a test can ask what bone sounds like without an audio device,
## which is the only way any of this gets verified in a headless run.
static func impact_sample(profile: Dictionary, t: float, noise: float) -> float:
	var freq := float(profile.get("freq", 90.0))
	var noise_mix := float(profile.get("noise", 0.5))
	var decay := float(profile.get("decay", 6.0))
	var gain := float(profile.get("gain", 0.5))
	var envelope := exp(-decay * t)
	var sample := 0.0
	match str(profile.get("character", "slap")):
		"crack":
			# A hard transient in the first two milliseconds, then a ring that
			# outlives it. That gap between the snap and the ring is the whole
			# difference between breaking a bone and hitting meat.
			var snap: float = noise * exp(-t * 900.0)
			var ring: float = sin(TAU * freq * t) * exp(-decay * t) * 0.55
			var body: float = sin(TAU * freq * 0.5 * t) * exp(-decay * 1.7 * t) * 0.3
			sample = snap + ring + body
		"burst":
			# Wet, and falling: the pitch drops as the thing empties. Modulated
			# so it gurgles rather than hums.
			# Phase, not frequency: integrating a falling rate is what makes the
			# pitch actually drop rather than simply start lower.
			var fall: float = clampf(t * 5.0, 0.0, 1.0)
			var falling: float = freq * (1.0 - 0.55 * fall)
			var wet: float = sin(TAU * falling * t + sin(t * 180.0) * 2.4)
			sample = (wet * (1.0 - noise_mix) + noise * noise_mix) * envelope
		"fault":
			# Current in it. Gated into bursts so it sputters instead of ringing
			# like a bell, and detuned against itself so it beats.
			var gate: float = 1.0 if fmod(t * 63.0, 1.0) < 0.55 else 0.18
			var tone: float = sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 1.007 * t) * 0.4
			sample = (tone + noise * noise_mix) * envelope * gate
		_:
			sample = (sin(TAU * freq * t) * (1.0 - noise_mix) + noise * noise_mix) * envelope
	return clampf(sample * gain, -1.0, 1.0)


## A short procedural burst rather than a sample library - nothing shipped yet
## has recorded audio, and a synthesised voice per layer is honest about that
## rather than silent. G5 replaces this with authored, positional audio later.
static func play_impact(host: Node3D, at: Vector3, layer: int) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var scene := host.get_tree().current_scene
	if scene == null:
		return
	var profile := impact_profile(layer)
	var player := AudioStreamPlayer3D.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.2
	player.stream = generator
	player.unit_size = 5.0
	player.max_distance = 26.0
	# G5.1. No bus was set here, so the engine put every gore hit on Master and
	# the SFX slider could not touch it.
	AudioBus.route(player, "Gore")
	scene.add_child(player)
	player.global_position = at
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_fill_impact_buffer(playback, profile)
	player.get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free())


static func _fill_impact_buffer(playback: AudioStreamGeneratorPlayback, profile: Dictionary) -> void:
	var rate := 22050.0
	var frames := mini(playback.get_frames_available(), int(rate * 0.2))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in frames:
		var sample := impact_sample(profile, float(index) / rate, rng.randf_range(-1.0, 1.0))
		playback.push_frame(Vector2(sample, sample))


## How rotten a chunk is: 0 the moment it hits the ground, 1 once `ROT_SECONDS`
## have passed undisturbed. A pure function of its own metadata, so a test, an
## AI or a future survival meter can all ask without this class pushing
## the answer anywhere.
static func rot_ratio(node: Node) -> float:
	var info := identify(node)
	if info.is_empty():
		return 0.0
	var age := float(Time.get_ticks_msec() - int(info.get("spawn_msec", Time.get_ticks_msec()))) / 1000.0
	return clampf(age / ROT_SECONDS, 0.0, 1.0)


## The gameplay half of B4.9: anything on the floor rotten enough to smell, as
## a position and a strength, for whichever system wants to react to it - an
## AI that avoids it, one that is drawn to it, a future survival meter.
static func scent_sources() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for chunk in live:
		var ratio := rot_ratio(chunk)
		if ratio > 0.5 and is_instance_valid(chunk) and (chunk as Node3D).is_inside_tree():
			out.append({"position": (chunk as Node3D).global_position, "strength": ratio})
	return out


## Visual half of rot: the piece darkens on a schedule and, once fully turned,
## grows a couple of fly specks. Scheduled rather than polled every frame
## because a chunk that survives this long is the rare case, not the common one.
static func _schedule_rot(node: RigidBody3D) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	while is_instance_valid(node) and node.is_inside_tree():
		await node.get_tree().create_timer(ROT_SECONDS * 0.5).timeout
		if not is_instance_valid(node) or not node.is_inside_tree():
			return
		var ratio := rot_ratio(node)
		var mesh: MeshInstance3D = null
		for child in node.get_children():
			if child is MeshInstance3D:
				mesh = child
				break
		if mesh != null and mesh.material_override is StandardMaterial3D:
			var material := mesh.material_override as StandardMaterial3D
			material.albedo_color = material.albedo_color.darkened(0.25)
		if ratio >= 1.0:
			_spawn_flies(node)
			return


static func _spawn_flies(node: RigidBody3D) -> void:
	if node.has_node("Flies"):
		return
	var swarm := Node3D.new()
	swarm.name = "Flies"
	node.add_child(swarm)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(node.get_instance_id()) & 0x7fffffff
	for index in 4:
		var fly := MeshInstance3D.new()
		var speck := SphereMesh.new()
		speck.radius = 0.006
		speck.height = 0.012
		fly.mesh = speck
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("15130f")
		fly.material_override = material
		fly.position = Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.03, 0.1), rng.randf_range(-0.08, 0.08))
		swarm.add_child(fly)


static func _recycle_oldest() -> void:
	while not live.is_empty():
		var oldest: Node3D = live.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
			return


static func clear() -> void:
	for chunk in live:
		if is_instance_valid(chunk):
			chunk.queue_free()
	live.clear()
