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

	_check(is_equal_approx(feel.scale_for("player"), 1.0), "time runs normally before anything is hit")

	feel.strike(0.8, "cut", false)
	_check(feel.scale_for("player") < 0.5, "a solid hit stops time for the one hit (%.2f)" % feel.scale_for("player"))
	_check(feel.kick.length() > 0.0, "and kicks the camera")

	# It has to come back on its own, and within a sane window.
	var waited := 0.0
	while feel.holding() and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	_check(is_equal_approx(feel.scale_for("player"), 1.0), "and time comes back by itself")
	_check(waited < 0.5, "within a fraction of a second, not a visible hitch (%.3fs)" % waited)

	# Severity actually matters.
	feel.strike(0.1, "cut", false)
	var graze_kick: float = feel.kick.length()
	await get_tree().process_frame
	while feel.holding():
		await get_tree().process_frame
	feel.kick = Vector2.ZERO
	feel.strike(1.0, "cut", true)
	_check(feel.kick.length() > graze_kick, "a severing blow hits harder than a graze")
	while feel.holding():
		await get_tree().process_frame

	# A bullet must not freeze the game on every shot.
	feel.strike(0.9, "ballistic", false)
	var ballistic_hold := 0.0
	while feel.holding() and ballistic_hold < 1.0:
		await get_tree().process_frame
		ballistic_hold += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	feel.strike(0.9, "cut", false)
	var cut_hold := 0.0
	while feel.holding() and cut_hold < 1.0:
		await get_tree().process_frame
		cut_hold += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
	_check(ballistic_hold < cut_hold, "a bullet stops time less than a blade (%.3f vs %.3f)" % [ballistic_hold, cut_hold])

	# O2.5 v2. The exchange is between two bodies; the region is not in it.
	feel.strike(0.9, "cut", false, ["player", "mara_voss"])
	_check(feel.scale_for("mara_voss") < 0.5, "the body you hit slows (%.2f)" % feel.scale_for("mara_voss"))
	_check(is_equal_approx(feel.scale_for("some_other_fight"), 1.0), "and every other fight in the region carries on at full speed")
	_check(is_equal_approx(Engine.time_scale, 1.0), "the global clock is never touched")
	while feel.holding():
		await get_tree().process_frame

	# ------------------------------------------------------------------ O2.9
	# "Loud aggressive screen shake without feeling satisfying." Each of these
	# asserts one of the four things that made it read as noise.

	print("")
	print("O2.9 - punch instead of noise")

	# 1. Random roll on every contact was the single most disorienting channel.
	# An ordinary hit must now leave the horizon alone entirely.
	feel.roll = 0.0
	feel.kick = Vector2.ZERO
	feel.strike(0.5, "ballistic", false)
	_check(is_equal_approx(feel.roll, 0.0), "a routine shot does not roll the horizon at all (%.5f)" % feel.roll)
	while feel.holding():
		await get_tree().process_frame
	feel.roll = 0.0
	feel.strike(1.0, "cut", true)
	_check(absf(feel.roll) > 0.0, "but a severing blow still wrenches the view (%.5f)" % feel.roll)
	while feel.holding():
		await get_tree().process_frame

	# 2. Directionality beats randomness: a caller that says where the hit came
	# from gets a camera pushed away from it, and the sign is not a coin flip.
	feel.kick = Vector2.ZERO
	feel.strike(0.8, "cut", false, [], Vector2.RIGHT)
	var pushed_left: float = feel.kick.x
	while feel.holding():
		await get_tree().process_frame
	feel.kick = Vector2.ZERO
	feel.strike(0.8, "cut", false, [], Vector2.LEFT)
	var pushed_right: float = feel.kick.x
	_check(pushed_left < 0.0 and pushed_right > 0.0, "the camera is thrown away from what was hit (%.4f vs %.4f)" % [pushed_left, pushed_right])
	while feel.holding():
		await get_tree().process_frame

	# 3. Headroom. The sandbox passes the same mid severity on every rifle shot;
	# if that already sits near the ceiling a sever has nowhere left to go.
	feel.kick = Vector2.ZERO
	feel.strike(0.7, "ballistic", false)
	var routine_kick: float = feel.kick.length()
	var routine_shake: float = feel.shake
	while feel.holding():
		await get_tree().process_frame
	feel.kick = Vector2.ZERO
	feel.shake = 0.0
	feel.strike(1.0, "cut", true)
	var sever_kick: float = feel.kick.length()
	var sever_shake: float = feel.shake
	_check(sever_kick > routine_kick * 1.8, "a sever kicks far past a routine shot (%.4f vs %.4f)" % [sever_kick, routine_kick])
	_check(sever_shake > routine_shake * 2.0, "and shakes far past it too (%.3f vs %.3f)" % [sever_shake, routine_shake])
	_check(routine_kick < ImpactFeel.KICK_CEILING * 0.5, "while the routine shot leaves half the range unspent (%.4f)" % routine_kick)
	while feel.holding():
		await get_tree().process_frame

	# 4. The kick is a spring, not a slide. v3's comment claimed it settled past
	# centre and its `lerp` mathematically could not. Punch is the counter-swing.
	feel.kick = Vector2.ZERO
	feel.shake = 0.0
	feel.strike(0.9, "cut", false)
	_check(feel.kick.y < 0.0, "the blow throws the view up first")
	var crossed := false
	var spring_waited := 0.0
	while spring_waited < 0.6:
		await get_tree().process_frame
		spring_waited += get_process_delta_time()
		if feel.kick.y > 0.0:
			crossed = true
			break
	_check(crossed, "and the camera snaps back through centre rather than sliding home (%.3fs)" % spring_waited)
	_check(spring_waited < 0.3, "within a snap, not a wallow (%.3fs)" % spring_waited)

	# 5. The shake is a trace, not static. Two reads of the same state used to
	# differ because `camera_offset()` called `randf` twice per frame, which is
	# a signal fault to look at, not a camera being hit.
	feel.kick = Vector2.ZERO
	feel.shake = 0.0
	feel.strike(1.0, "blunt", false)
	var first_read: Vector2 = feel.camera_offset()
	var second_read: Vector2 = feel.camera_offset()
	_check(first_read.is_equal_approx(second_read), "the shake is a continuous trace, not per-frame noise")
	_check(not first_read.is_equal_approx(feel.kick), "and it is genuinely moving the camera")

	# 6. And it is a transient. A routine shot's shake used to outlast its kick.
	feel.shake = 0.0
	feel.kick = Vector2.ZERO
	feel.strike(0.7, "ballistic", false)
	var shot_ring := 0.0
	while feel.shake > 0.0 and shot_ring < 1.0:
		await get_tree().process_frame
		shot_ring += get_process_delta_time()
	feel.strike(1.0, "cut", true)
	var sever_ring := 0.0
	while feel.shake > 0.0 and sever_ring < 1.0:
		await get_tree().process_frame
		sever_ring += get_process_delta_time()
	_check(shot_ring < 0.12, "a shot's shake is a flick, not a hum (%.3fs)" % shot_ring)
	_check(sever_ring > shot_ring * 1.5, "and a sever rings for meaningfully longer (%.3fs)" % sever_ring)
	while feel.holding():
		await get_tree().process_frame

	# 7. Sustained fire must not walk the view into the sky. v3's `kick +=` had
	# no ceiling at all.
	feel.kick = Vector2.ZERO
	for _shot in 40:
		feel.strike(0.8, "ballistic", false)
	_check(feel.kick.length() <= ImpactFeel.KICK_CEILING + 0.0001, "forty rounds cannot stack the camera past its ceiling (%.4f)" % feel.kick.length())
	while feel.holding():
		await get_tree().process_frame

	# 8. The ballistic stop cut is for routine hits. A limb leaving the body is
	# the heaviest thing the game does whatever took it off.
	feel.strike(1.0, "ballistic", true)
	var ballistic_sever_hold := 0.0
	while feel.holding() and ballistic_sever_hold < 1.0:
		await get_tree().process_frame
		ballistic_sever_hold += get_process_delta_time()
	_check(ballistic_sever_hold > 0.1, "a limb shot off still earns the full stop (%.3fs)" % ballistic_sever_hold)

	# 9. The other half of "loud": five gore voices on one frame at one point.
	var deepest: float = GoreChunks.stack_level(GoreChunks.Layer.ORGAN, GoreChunks.Layer.ORGAN)
	var entry: float = GoreChunks.stack_level(GoreChunks.Layer.SKIN, GoreChunks.Layer.ORGAN)
	_check(is_equal_approx(deepest, 1.0), "the deepest layer a hit reached is the voice that plays at full")
	_check(entry < deepest * 0.25, "and the layers it passed through on the way are only ticks (%.3f)" % entry)
	var stacked := 0.0
	for layer in range(0, GoreChunks.Layer.ORGAN + 1):
		stacked += float(GoreChunks.impact_profile(layer)["gain"]) * GoreChunks.stack_level(layer, GoreChunks.Layer.ORGAN)
	_check(stacked < 1.6, "a rifle round through to the organ layer no longer sums past clipping (%.2f linear)" % stacked)
	var single: float = float(GoreChunks.impact_profile(GoreChunks.Layer.ORGAN)["gain"])
	_check(stacked > single, "without flattening it into a single sound either")

	# O2.3. A miss moves the camera but never stops time — the absence is the
	# feedback.
	feel.kick = Vector2.ZERO
	feel.whiff()
	_check(feel.kick.length() > 0.0, "a miss still carries the weapon through")
	_check(is_equal_approx(feel.scale_for("player"), 1.0), "but a miss never stops time")

	# Something else owning time wins.
	var owner_state := {"blocked": true}
	feel.blocked_by = func() -> bool: return bool(owner_state["blocked"])
	feel.strike(1.0, "cut", true)
	_check(is_equal_approx(feel.scale_for("player"), 1.0), "an impact inside a kill cam does not fight it for time")
	owner_state["blocked"] = false

	# And the scene can leave mid-hit without stranding the game in slow motion.
	feel.strike(1.0, "cut", true)
	_check(feel.holding(), "time is held")
	remove_child(feel)
	await get_tree().process_frame
	_check(not feel.holding(), "and leaving the scene mid-hit releases it")
	_check(is_equal_approx(feel.scale_for("player"), 1.0), "so nothing is left running slow")
	feel.free()

	print("")
	if failures.is_empty():
		print("O2 PASS")
	else:
		print("FAIL: %d" % failures.size())
		for failure in failures:
			print("  - ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
