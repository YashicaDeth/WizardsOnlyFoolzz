extends Node

## Impact damage now attributes by who drove into whom, which means AI wreckers
## ramming a stationary player finally hurt. That is correct, but it made the
## pit lethal enough that an idle player was wrecked during a visual capture, so
## the floor is worth holding: being swarmed should be survivable long enough to
## fight back.

var failures: Array[String] = []
var impacts := 0
var strongest_impact := 0.0


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
	derby.boat.impact.connect(func(_other, closing_speed, _share):
		impacts += 1
		strongest_impact = maxf(strongest_impact, float(closing_speed)))
	for wrecker in derby.targets:
		wrecker.impact.connect(func(other, closing_speed, _share):
			if other == derby.boat:
				impacts += 1
				strongest_impact = maxf(strongest_impact, float(closing_speed)))
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var seconds := 0.0
	var samples: Array[String] = []
	var next_sample := 0.0
	var peak_crowding := 0
	var approach_runs := 0
	var contact_closing := 0.0
	var vehicle_contact_closing := 0.0
	var hunter_alignment := -1.0
	var player_contact_closing := 0.0
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
					var hunter_driver = target.get_node_or_null("AIDriver")
					if hunter_driver != null:
						approach_runs = maxi(approach_runs, int(hunter_driver.final_approach_count))
						hunter_alignment = maxf(hunter_alignment, float(hunter_driver.max_target_alignment))
				var driver = target.get_node_or_null("AIDriver")
				contact_closing = maxf(contact_closing, float(target.max_contact_closing))
				vehicle_contact_closing = maxf(vehicle_contact_closing, float(target.max_vehicle_contact_closing))
				player_contact_closing = maxf(player_contact_closing, float(target.vehicle_contact_peaks.get(derby.boat.get_instance_id(), 0.0)))
				if target.linear_velocity.length() > 1.0:
					moving += 1
			peak_crowding = maxi(peak_crowding, crowding)
			var nearest_ai = nearest_car.get_node_or_null("AIDriver") if nearest_car != null else null
			var charge := float(nearest_ai.final_approach_timer) if nearest_ai != null else 0.0
			var nearest_speed: float = float(nearest_car.linear_velocity.length()) if nearest_car != null else 0.0
			samples.append("%.0fs hull%d near%.1fm/%.1fms charge%.1f crowd%d hunt%d moving%d/%d" % [seconds, derby.boat.integrity, nearest, nearest_speed, charge, crowding, hunters, moving, derby.targets.size()])
			next_sample += 4.0
	print("  hull over time -> ", " ".join(samples))
	print("  survived %.1fs, ended hull %d, wreckers disabled %d, peak crowding %d" % [seconds, derby.boat.integrity, derby.disabled_count, peak_crowding])
	# Crowding is now a bound in both directions. Too many cars on the player at
	# once is the complaint; zero is a pit with no teeth.
	check(peak_crowding <= 4, "the pit never piles more than four cars on the player (peak %d)" % peak_crowding)
	check(peak_crowding >= 1, "the pit still reaches the player (peak %d)" % peak_crowding)
	check(seconds >= 12.0, "a swarmed idle player survives at least 12s (lasted %.1fs)" % seconds)
	check(approach_runs >= 1, "hunters commit to a final approach (%d observed)" % approach_runs)
	print("  hunter peak alignment -> %.3f" % hunter_alignment)
	check(contact_closing > 0.0, "wreckers make physical chassis contact (peak normal closing %.1f m/s)" % contact_closing)
	check(vehicle_contact_closing > 0.0, "wreckers contact another vehicle (peak normal closing %.1f m/s)" % vehicle_contact_closing)
	print("  player-specific contact -> %.3f m/s" % player_contact_closing)
	# G0.3. Hull loss is downstream and can come from another code path. Count
	# the chassis signal itself so a no-contact pit cannot look green again.
	check(impacts >= 1, "wreckers fire real impact signals (%d, strongest %.1f m/s)" % [impacts, strongest_impact])
	check(strongest_impact >= 3.0, "a hunter reaches the rebuilt chassis impact threshold (%.1f m/s)" % strongest_impact)
	# The other side of the bound: if nothing can hurt a parked car, the pit has
	# no teeth and the damage attribution has regressed the other way.
	check(derby.boat.integrity < 100, "a parked car still takes punishment (hull %d)" % derby.boat.integrity)
	print("DERBY_BALANCE_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
