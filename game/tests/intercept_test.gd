extends Node

## AD3.3. A projectile is a physical thing that can be met, not a damage
## event. AF1.1 made a round an object that travels and can arrive
## (`round_hit`) or run out of world (`round_expired`). This is the third
## way its flight can end: something reaches into the path and takes it out
## of the air. Without that, "meeting" a rocket with a blade is not a thing
## the simulation can express at all — a round could only ever be dodged,
## never answered.

const BALLISTICS := preload("res://systems/ballistics.gd")

var failures: Array[String] = []
var intercepted: Array[Dictionary] = []
var landed := 0
var expired := 0


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var ballistics: Ballistics = BALLISTICS.new()
	add_child(ballistics)
	ballistics.round_intercepted.connect(func(report: Dictionary): intercepted.append(report))
	ballistics.round_hit.connect(func(_hit: Dictionary): landed += 1)
	ballistics.round_expired.connect(func(_payload: Dictionary): expired += 1)

	# --- a round in the air can be taken out of it --------------------------
	var origin := Vector3(0, 2, 0)
	ballistics.fire(origin, Vector3.FORWARD, "pistol", 0.0, 1, "shooter", {"damage": 12.0})
	check(ballistics.rounds.size() == 1, "a round is actually in flight to begin with")
	var took := ballistics.intercept_near(origin, 0.5, "blade")
	check(took == 1, "swinging where the round actually is takes exactly one out of the air")
	check(ballistics.rounds.is_empty(), "and it is genuinely gone from flight, not just flagged")
	check(intercepted.size() == 1, "the interception is a real signal, not a silent removal")
	check(str(intercepted[0].get("by", "")) == "blade", "carrying whoever did it")
	check(str(intercepted[0].get("shooter", "")) == "shooter", "and whose round it was")
	check(float(intercepted[0].get("energy", 0.0)) > 0.0, "and what it still had left when it was met (%.3f)" % intercepted[0].get("energy", 0.0))
	check(float((intercepted[0].get("payload", {}) as Dictionary).get("damage", 0.0)) == 12.0, "and the damage it was carrying, which now never arrives")

	# --- the third outcome is its own, not one of the other two -------------
	check(landed == 0, "an intercepted round never reports as having arrived somewhere")
	check(expired == 0, "and never reports as having run out of world either")

	# --- swinging at nothing is swinging at nothing -------------------------
	ballistics.fire(Vector3(0, 2, -40), Vector3.FORWARD, "pistol", 0.0, 1, "shooter", {})
	var missed := ballistics.intercept_near(Vector3(0, 2, 40), 1.0, "blade")
	check(missed == 0, "a swing nowhere near a round takes nothing")
	check(ballistics.rounds.size() == 1, "and leaves the round it missed still flying")
	check(intercepted.size() == 1, "no phantom interception is reported for a miss")

	# --- radius is a real reach, not a free hit anywhere --------------------
	var far_round: Dictionary = ballistics.rounds[0]
	var where: Vector3 = far_round["at"]
	check(ballistics.intercept_near(where + Vector3(0, 3.0, 0), 0.5, "blade") == 0, "three metres above a round is still a miss at half a metre of reach")
	check(ballistics.intercept_near(where + Vector3(0, 0.4, 0), 0.5, "blade") == 1, "and inside that reach it connects")

	# --- a zero or negative reach cannot connect ---------------------------
	ballistics.fire(origin, Vector3.FORWARD, "pistol", 0.0, 1, "shooter", {})
	check(ballistics.intercept_near(origin, 0.0, "blade") == 0, "a reach of nothing meets nothing")
	check(ballistics.rounds.size() == 1, "and the round survives it")

	# --- a shotgun's pellets are each their own real object ----------------
	ballistics.clear()
	intercepted.clear()
	ballistics.fire(origin, Vector3.FORWARD, "buck", 0.12, 9, "shooter", {})
	check(ballistics.rounds.size() == 9, "nine pellets are nine real rounds in the air")
	var caught := ballistics.intercept_near(origin, 0.5, "blade")
	check(caught == 9, "and a swing through all of them at the muzzle meets every one (%d)" % caught)
	check(intercepted.size() == 9, "each reported separately rather than as one event")

	# --- what is in the air is answerable without reaching into internals --
	ballistics.clear()
	ballistics.fire(origin, Vector3.FORWARD, "pistol", 0.0, 1, "shooter", {})
	var in_flight := ballistics.rounds_in_flight()
	check(in_flight.size() == 1 and in_flight[0].distance_to(origin) < 0.01, "rounds_in_flight() reports where the round actually is")

	ballistics.queue_free()

	# --- and it is a real player move, not just an API nothing calls -------
	# Driven through `_resolve_strike()` itself — the same function a real
	# swing lands in — rather than by calling `intercept_near()` again here,
	# because the thing worth proving is the wiring, not the arithmetic
	# already proven above.
	var hunt: Node = load("res://bone_yard_hunt.tscn").instantiate()
	add_child(hunt)
	for _settle in 60:
		await get_tree().process_frame
	var hunt_ballistics: Ballistics = hunt.get("ballistics")
	check(hunt_ballistics != null, "the hunt grounds stood up with a real Ballistics of their own")

	WorldHistory.clear_history()
	var player_at: Vector3 = hunt.get("player")
	var yaw: float = float(hunt.get("yaw"))
	var facing := Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	# Put a round squarely in the arc the swing is about to cover.
	hunt_ballistics.fire(player_at + facing * 2.4, facing, "pistol", 0.0, 1, "somebody_else", {"damage": 30.0})
	check(hunt_ballistics.rounds.size() == 1, "a round is in the air in front of the player")

	hunt.set("pending_attack", {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"})
	hunt.call("_resolve_strike")
	check(hunt_ballistics.rounds.is_empty(), "a real swing through it actually takes it out of the air")
	check(WorldHistory.event_count("melee_met_round") == 1, "and the world records that it happened, once")

	# A swing with nothing in the arc must not report meeting anything.
	hunt.set("pending_attack", {"damage": 24.0, "impulse": 18.0, "damage_type": "cut", "range": 4.1, "weapon": "sword"})
	hunt.call("_resolve_strike")
	check(WorldHistory.event_count("melee_met_round") == 1, "swinging at empty air records no second meeting")

	print("INTERCEPT_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
