extends Node

## Impact damage now attributes by who drove into whom, which means AI wreckers
## ramming a stationary player finally hurt. That is correct, but it made the
## pit lethal enough that an idle player was wrecked during a visual capture, so
## the floor is worth holding: being swarmed should be survivable long enough to
## fight back.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	var derby = load("res://rift_derby.tscn").instantiate()
	add_child(derby)
	await get_tree().physics_frame
	# Never let the round hand over to Ashbloom mid-test: the scene swap would
	# free this node out from under the await.
	derby.leaving = true
	derby.round_state = "active"
	var impacts := 0
	var strongest_impact := 0.0
	derby.boat.impact.connect(func(_other, closing_speed, _share):
		impacts += 1
		strongest_impact = maxf(strongest_impact, float(closing_speed)))
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var seconds := 0.0
	var samples: Array[String] = []
	var next_sample := 0.0
	var peak_crowding := 0
	while seconds < 30.0 and derby.round_state == "active":
		await get_tree().physics_frame
		seconds += step
		if seconds >= next_sample:
			var nearest := 9999.0
			var nearest_car: Node3D
			var moving := 0
			var crowding := 0
			var hunters := 0
			for target in derby.targets:
				if not is_instance_valid(target):
					continue
				var gap: float = target.global_position.distance_to(derby.boat.global_position)
				if gap < nearest:
					nearest = gap
					nearest_car = target
				# The crowding metric: how many cars are on top of the player at
				# once. This is what "ten NPCs ramming you" actually measures.
				if gap < 9.0:
					crowding += 1
				if str(target.get_meta("wrecker_role", "")) == "hunt":
					hunters += 1
				if target.linear_velocity.length() > 1.0:
					moving += 1
			peak_crowding = maxi(peak_crowding, crowding)
			var nearest_ai = nearest_car.get_node_or_null("AIDriver") if nearest_car != null else null
			var charge := float(nearest_ai.final_approach_timer) if nearest_ai != null else 0.0
			var nearest_speed := nearest_car.linear_velocity.length() if nearest_car != null else 0.0
			samples.append("%.0fs hull%d near%.1fm/%.1fms charge%.1f crowd%d hunt%d moving%d/%d" % [seconds, derby.integrity, nearest, nearest_speed, charge, crowding, hunters, moving, derby.targets.size()])
			next_sample += 4.0
	print("  hull over time -> ", " ".join(samples))
	print("  survived %.1fs, ended hull %d, wreckers disabled %d, peak crowding %d" % [seconds, derby.integrity, derby.disabled_count, peak_crowding])
	# Crowding is now a bound in both directions. Too many cars on the player at
	# once is the complaint; zero is a pit with no teeth.
	check(peak_crowding <= 4, "the pit never piles more than four cars on the player (peak %d)" % peak_crowding)
	check(peak_crowding >= 1, "the pit still reaches the player (peak %d)" % peak_crowding)
	check(seconds >= 12.0, "a swarmed idle player survives at least 12s (lasted %.1fs)" % seconds)
	# G0.3. Hull loss is downstream and can come from another code path. Count
	# the chassis signal itself so a no-contact pit cannot look green again.
	check(impacts >= 1, "wreckers fire real impact signals (%d, strongest %.1f m/s)" % [impacts, strongest_impact])
	check(strongest_impact >= 4.0, "a hunter reaches the chassis impact threshold (%.1f m/s)" % strongest_impact)
	# The other side of the bound: if nothing can hurt a parked car, the pit has
	# no teeth and the damage attribution has regressed the other way.
	check(derby.integrity < 100, "a parked car still takes punishment (hull %d)" % derby.integrity)
	print("DERBY_BALANCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
