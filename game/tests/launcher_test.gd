extends Node

## AD3.1. "A melee build can close on a launcher and live — the distance is
## the puzzle." The last five words are the item's own answer, and the answer
## is not a launcher that does less damage — that would be a number. It is a
## weapon whose whole strength is range and which stops working when range
## stops existing, so closing the ground is *the* counterplay rather than one
## of several.

const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()

	# --- the arming ring is the whole mechanic ------------------------------
	check(not LauncherActor.armed_at(0.0), "point blank, the warhead has not armed")
	check(not LauncherActor.armed_at(LauncherActor.MIN_ARMING_METRES - 0.1), "nor a hair inside the ring")
	check(LauncherActor.armed_at(LauncherActor.MIN_ARMING_METRES), "it arms exactly at the authored distance")
	check(LauncherActor.in_envelope(20.0), "and works at range")
	check(not LauncherActor.in_envelope(LauncherActor.MAX_ENGAGE_METRES + 1.0), "past its own envelope it stops bothering")

	# --- a launcher at range winds up and fires, on a readable clock --------
	var actor := {"subject_id": "tube", "launcher": true}
	var fired := false
	var saw_windup := false
	var elapsed := 0.0
	while elapsed < LauncherActor.CYCLE_SECONDS + 0.2:
		var shot := LauncherActor.advance(actor, 20.0, 0.1)
		elapsed += 0.1
		if str(shot.state) == "winding":
			saw_windup = true
		if str(shot.state) == "fire":
			fired = true
			break
	check(saw_windup, "the tube goes up before it goes off — the move is readable")
	check(fired, "and it does actually fire on its own cycle")

	# --- closing inside the ring loses the shot, it does not pause it ------
	var closer := {"subject_id": "tube2", "launcher": true}
	for _tick in 30:
		LauncherActor.advance(closer, 20.0, 0.1)
	check(float(closer.get("launcher_clock", 0.0)) > 0.0, "sanity: it had a shot building")
	var inside := LauncherActor.advance(closer, 3.0, 0.1)
	check(str(inside.state) == "idle", "stepping inside the ring, it cannot fire")
	check(is_equal_approx(float(closer.get("launcher_clock", 0.0)), 0.0), "and the shot it was building is lost, not paused — the distance is the puzzle, not a delay")

	# --- a non-launcher is untouched by any of it --------------------------
	var ordinary := {"subject_id": "somebody"}
	check(not LauncherActor.is_launcher(ordinary), "an ordinary actor is not one")
	check(str(LauncherActor.advance(ordinary, 20.0, 5.0).state) == "idle", "and never fires one")

	# --- the round is slow enough to actually answer ------------------------
	var ballistics: Ballistics = BALLISTICS.new()
	add_child(ballistics)
	var rocket: Dictionary = BALLISTICS.CALIBRES["rocket"]
	var pistol: Dictionary = BALLISTICS.CALIBRES["pistol"]
	check(float(rocket.muzzle) < float(pistol.muzzle) * 0.2, "a warhead leaves the tube far slower than a bullet (%.0f vs %.0f)" % [rocket.muzzle, pistol.muzzle])

	ballistics.fire(Vector3(0, 2, 0), Vector3.FORWARD, "rocket", 0.0, 1, "tube", {"damage": 46.0})
	check(ballistics.rounds.size() == 1, "a launched warhead is a real round in flight")
	check(ballistics.casings.is_empty(), "and a launcher throws no brass")

	# AD3.3 closing the loop: the thing this game just learned to do to a
	# bullet works on the thing the section is actually about.
	var met := ballistics.intercept_near(Vector3(0, 2, 0), 0.6, "blade")
	check(met == 1, "and it can be met in the air with a blade, which is what AD3.3 was for")
	check(ballistics.rounds.is_empty(), "the warhead is genuinely gone rather than merely flagged")

	print("LAUNCHER_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
