extends Node

## O2.8 v4. "Gore and chunk physics still run at full speed through a hit,
## so a limb can leave a body that has not moved yet." O2.7 v3 fixed the
## player's own cooldowns and rig animation clock but explicitly left gore
## out of scope — chunks are real RigidBody3D nodes the physics server
## integrates directly, which a delta multiply cannot reach.
##
## GoreChunks.hold()/release() closes it with a freeze/resume scheme instead:
## hold() freezes every live chunk (removing it from physics simulation
## entirely, which is the actual local-time-stop a delta scale can only
## approximate) after saving its velocity, and release() un-freezes and
## hands the velocity back so the arc continues rather than the limb
## stopping dead and dropping straight down.

const GORE_CHUNKS := preload("res://systems/gore_chunks.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var chunk := RigidBody3D.new()
	add_child(chunk)
	var thrown_velocity := Vector3(1.4, 3.2, -0.6)
	var spin := Vector3(0.0, 4.0, 0.0)
	chunk.linear_velocity = thrown_velocity
	chunk.angular_velocity = spin
	GORE_CHUNKS.live.append(chunk)

	print("O2.8 v4 - a hit freezes the chunk mid-flight rather than a delta scale")
	GORE_CHUNKS.hold()
	_check(chunk.freeze, "the chunk is actually removed from physics simulation, not slowed by a multiply")

	print("O2.8 v4 - the hold ends and the arc continues")
	GORE_CHUNKS.release()
	_check(not chunk.freeze, "the chunk is unfrozen afterward")
	_check(chunk.linear_velocity == thrown_velocity, "and its velocity is handed straight back rather than a limb stopping dead and dropping (%s)" % chunk.linear_velocity)
	_check(chunk.angular_velocity == spin, "the spin comes back too")

	print("O2.8 v4 - a second hold/release does not double-freeze or lose the entry")
	GORE_CHUNKS.hold()
	GORE_CHUNKS.hold()  # already held - must not clobber the saved velocity with (0,0,0)
	GORE_CHUNKS.release()
	_check(not chunk.freeze, "releasing after a repeated hold call still leaves the chunk unfrozen")
	_check(chunk.linear_velocity == thrown_velocity, "and a hold that was already active does not overwrite the saved velocity")

	chunk.queue_free()
	GORE_CHUNKS.live.clear()

	print("GORE_HITSTOP_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
