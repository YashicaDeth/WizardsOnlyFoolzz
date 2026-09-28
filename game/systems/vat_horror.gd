class_name VatHorror
extends Node

## Greg, 28 September (question boxes): the vat opening doesn't hit hard
## enough. Other subjects dying in the next tanks (twitching, a tank draining
## so its body flops, blood clouding the medium, one awake and hammering on
## its glass like you), and a colder examiner who injects you, cuts a sample,
## reads your parts and price aloud like meat, and drains the failed tank
## beside you.
##
## One node on the Growing Floor, fed the seated subjects of the nearest
## tanks. It only moves bodies, grows clouds and hands the intake his lines;
## everything else stays the chamber's. Headless route suites skip it unless a
## test opts in, like the brain hack.

## The examiner's acts during the intake, in intake seconds.
const ACTS := [
	{"at": 14.0, "id": "inject", "line": "Hold still. It goes in through the port. You won't feel the rest of the dose."},
	{"at": 28.0, "id": "sample", "line": "A sample. Skin, then marrow. You can't move anyway."},
	{"at": 42.0, "id": "price", "line": "Two kidneys, one liver, the eyes if they settle. You're worth more in pieces than awake."},
	{"at": 56.0, "id": "drain", "line": "That one's done. Drain it."},
]
const CLOUD := Color(0.55, 0.04, 0.03, 0.38)

static var force_in_tests := false

var vat: Node3D
## [{"rig", "at", "seed"}] from the chamber's nearest tanks.
var subjects: Array = []
var clock := 0.0
var intake_clock := 0.0
var acts_done: Array[String] = []
var drained := false
var hammer_clock := 0.0
var _rest: Dictionary = {}
var _clouds: Dictionary = {}


static func wanted() -> bool:
	return force_in_tests or OS.get_environment("ATG_TEST_MODE") != "1"


func setup(chamber: Node3D, seated: Array) -> void:
	name = "VatHorror"
	vat = chamber
	subjects = seated
	for entry: Dictionary in subjects:
		var rig := entry.rig as Node3D
		if rig == null:
			continue
		for part_id in ["left_arm", "right_arm", "left_leg", "right_leg", "head"]:
			var part := (rig as BaselineHuman).parts.get(part_id) as Node3D
			if part != null:
				_rest[part.get_instance_id()] = part.rotation
		_rest[rig.get_instance_id()] = rig.rotation


func _process(delta: float) -> void:
	if vat == null or subjects.is_empty():
		return
	clock += delta
	var phase := str(vat.get("phase"))
	# The chamber's seeds: 1 is the one still alive, 2 the one that failed.
	var alive := _subject(1)
	var failed := _subject(2)
	if phase == "intake":
		intake_clock += delta
		_examiner_acts()
	# The one still alive convulses in the medium until the hack; after it,
	# awake like you, they hammer on the glass and their blood clouds it.
	if alive != null:
		if phase in ["hacked", "submerged", "voiding", "wired", "cord", "smash"]:
			_hammer(alive, delta)
		elif phase != "aisle":
			_convulse(alive, 1.0)
	if failed != null and not drained:
		_convulse(failed, 0.35)


func _subject(seed_value: int) -> BaselineHuman:
	for entry: Dictionary in subjects:
		if int(entry.seed) == seed_value and entry.rig != null and is_instance_valid(entry.rig):
			return entry.rig as BaselineHuman
	return null


func _entry(seed_value: int) -> Dictionary:
	for entry: Dictionary in subjects:
		if int(entry.seed) == seed_value:
			return entry
	return {}


## Twitches that come in fits: mostly still, then a seizure through the limbs.
func _convulse(rig: BaselineHuman, strength: float) -> void:
	var fit := pow(maxf(0.0, sin(clock * 0.9 + float(rig.get_instance_id() % 7))), 8.0)
	for part_id in ["left_arm", "right_arm", "left_leg", "right_leg", "head"]:
		var part := rig.parts.get(part_id) as Node3D
		if part == null or not _rest.has(part.get_instance_id()):
			continue
		var rest: Vector3 = _rest[part.get_instance_id()]
		var jitter := sin(clock * 31.0 + float(part_id.length()) * 2.3) * 0.35 * fit * strength
		part.rotation = rest + Vector3(jitter, jitter * 0.5, -jitter * 0.6)


## Awake and drowning: a fist against the glass every second or so, and the
## tank clouds red as they tear at themselves.
func _hammer(rig: BaselineHuman, delta: float) -> void:
	hammer_clock += delta
	var beat := fmod(hammer_clock, 1.1) / 1.1
	var arm := rig.parts.get("right_arm") as Node3D
	if arm != null and _rest.has(arm.get_instance_id()):
		var rest: Vector3 = _rest[arm.get_instance_id()]
		var swing := sin(beat * PI) if beat < 0.5 else 0.0
		arm.rotation = rest + Vector3(-1.6 * swing, 0.0, 0.0)
	if beat < delta / 1.1 and vat.get("opening_audio") != null:
		vat.opening_audio.cue("tug")
	_grow_cloud(1, delta * 0.06)


func _examiner_acts() -> void:
	for act: Dictionary in ACTS:
		if intake_clock < float(act.at) or acts_done.has(str(act.id)):
			continue
		acts_done.append(str(act.id))
		_say(str(act.line))
		var anatomy: Node = vat.get("anatomy")
		match str(act.id):
			"inject":
				if anatomy != null:
					anatomy.call("apply_hit", "torso", 3.0, 0.0, "puncture")
				vat.set("breach_shake", 0.25)
			"sample":
				if anatomy != null:
					anatomy.call("apply_hit", "left_arm", 4.0, 0.0, "cut")
				vat.set("breach_shake", 0.35)
			"drain":
				drain_failed()
		WorldHistory.record_event("examiner_act", {"act": str(act.id), "location": "growing_floor"})


## The failed tank beside you empties: the body slumps against the glass and
## what is left of the medium runs red.
func drain_failed() -> void:
	if drained:
		return
	drained = true
	var failed := _subject(2)
	if failed != null:
		failed.rotation.x += 0.55
		failed.position.y -= 0.25
		var head := failed.parts.get("head") as Node3D
		if head != null:
			head.rotation.x += 0.7
	_grow_cloud(2, 0.45)
	WorldHistory.record_event("vat_subject_drained", {"location": "growing_floor"})


func _grow_cloud(seed_value: int, amount: float) -> void:
	var entry := _entry(seed_value)
	if entry.is_empty():
		return
	var cloud := _clouds.get(seed_value) as MeshInstance3D
	if cloud == null:
		cloud = MeshInstance3D.new()
		cloud.name = "BloodCloud_%d" % seed_value
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		var material := StandardMaterial3D.new()
		material.albedo_color = CLOUD
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ball.material = material
		cloud.mesh = ball
		cloud.position = (entry.at as Vector3) + Vector3(0, 1.1, 0)
		cloud.scale = Vector3.ONE * 0.05
		vat.add_child(cloud)
		_clouds[seed_value] = cloud
	cloud.scale = Vector3.ONE * minf(1.5, cloud.scale.x + amount)


## His line, into the intake's HE SAYS panel when it is up.
func _say(line: String) -> void:
	var intake: Node = vat.get("intake")
	if intake != null and is_instance_valid(intake) and "doctor_says" in intake:
		intake.set("doctor_says", line)
		intake.set("doctor_life", 5.0)
		intake.call("queue_redraw")
