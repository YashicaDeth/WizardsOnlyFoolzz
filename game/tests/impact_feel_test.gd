extends Node

## O2.2 verification. Hitstop's failure mode is not "it feels wrong" — it is
## leaving Engine.time_scale somewhere other than 1.0 and putting the entire
## game into slow motion. That has to be asserted, not eyeballed.

const FEEL := preload("res://systems/impact_feel.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	print("O2 - the moment of contact")
	var feel: Node = FEEL.new()
	add_child(feel)
	await get_tree().process_frame

	_check(is_equal_approx(Engine.time_scale, 1.0), "time runs normally before anything is hit")

	feel.strike(0.8, "cut", false)
	_check(Engine.time_scale < 0.5, "a solid hit stops time (%.2f)" % Engine.time_scale)
	_check(feel.kick.length() > 0.0, "and kicks the camera")

	# It has to come back on its own, and within a sane window.
	var waited := 0.0
	while Engine.time_scale < 1.0 and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	_check(is_equal_approx(Engine.time_scale, 1.0), "and time comes back by itself")
	_check(waited < 0.5, "within a fraction of a second, not a visible hitch (%.3fs)" % waited)

	# Severity actually matters.
	feel.strike(0.1, "cut", false)
	var graze_kick: float = feel.kick.length()
	await get_tree().process_frame
	while Engine.time_scale < 1.0:
		await get_tree().process_frame
	feel.kick = Vector2.ZERO
	feel.strike(1.0, "cut", true)
	_check(feel.kick.length() > graze_kick, "a severing blow hits harder than a graze")
	while Engine.time_scale < 1.0:
		await get_tree().process_frame

	# A bullet must not freeze the game on every shot.
	feel.strike(0.9, "ballistic", false)
	var ballistic_hold := 0.0
	while Engine.time_scale < 1.0 and ballistic_hold < 1.0:
		await get_tree().process_frame
		ballistic_hold += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	feel.strike(0.9, "cut", false)
	var cut_hold := 0.0
	while Engine.time_scale < 1.0 and cut_hold < 1.0:
		await get_tree().process_frame
		cut_hold += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	_check(ballistic_hold < cut_hold, "a bullet stops time less than a blade (%.3f vs %.3f)" % [ballistic_hold, cut_hold])

	# O2.3. A miss moves the camera but never stops time — the absence is the
	# feedback.
	feel.kick = Vector2.ZERO
	feel.whiff()
	_check(feel.kick.length() > 0.0, "a miss still carries the weapon through")
	_check(is_equal_approx(Engine.time_scale, 1.0), "but a miss never stops time")

	# Something else owning time wins.
	var owner_state := {"blocked": true}
	feel.blocked_by = func() -> bool: return bool(owner_state["blocked"])
	feel.strike(1.0, "cut", true)
	_check(is_equal_approx(Engine.time_scale, 1.0), "an impact inside a kill cam does not fight it for time")
	owner_state["blocked"] = false

	# And the scene can leave mid-hit without stranding the game in slow motion.
	feel.strike(1.0, "cut", true)
	_check(Engine.time_scale < 1.0, "time is held")
	feel.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "and leaving the scene mid-hit restores it")

	print("")
	if failures.is_empty():
		print("O2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
