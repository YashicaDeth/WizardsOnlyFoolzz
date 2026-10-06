extends "res://tests/v01_duel_bot.gd"

## Job 9: the Service Arcade's numbered CellOutz guards, in the real route,
## fought through the real InputMap (pad events only).
## - Three guards stand at their posts with LimboAI brains; numbers 47-49.
## - Seen, one radios and the others answer; only one melee wind-up at a time.
## - Hard: a player who stands and mashes R1 is blocked, parried and hurt.
## - Fair: a careful player (parry copper, dodge red, strike openings) kills
##   a PRODSTAFF guard and the pistol guard with the HOTLINE CLEAVER, takes
##   the dropped PRODSTAFF (Square) and kills a guard with it, takes the
##   dropped sidearm and kills a guard with it.


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	result_name = "V01_GUARD_DUEL_TEST"
	await boot()
	check(enc != null, "the one-map route builds the v0.1 encounters")
	if enc == null:
		finish("V01_GUARD_DUEL_TEST")
		return
	check(enc.guards.size() == 3, "three guards in the Service Arcade (%d)" % enc.guards.size())
	check(enc.guards.map(func(g: V01Guard) -> String: return g.number) == ["47", "48", "49"], "numbered 47, 48, 49")
	check(enc.guards.map(func(g: V01Guard) -> String: return g.weapon) == ["staff", "staff", "pistol"], "two PRODSTAFFs and a pistol")
	check(enc.guards.all(func(g: V01Guard) -> bool: return g.brain != null), "each guard thinks with a LimboAI behaviour tree")
	check(enc.guards.all(func(g: V01Guard) -> bool: return g.global_position.x > 20.75 and g.global_position.x < 35.25 and g.global_position.z < 5.5 and g.global_position.z > -58.5), "all three stand inside the arcade's walls")
	vat.doctor_route._take_axe()
	await _squad()
	await _careless()
	await _cleaver_staff_guard()
	await _cleaver_pistol_guard()
	await _prodstaff_duel()
	await _gun_duel()
	finish("V01_GUARD_DUEL_TEST")


## Seen by 47 across the arcade: he radios (copper shoulder lamp), the others
## come; never two melee wind-ups at once.
func _squad() -> void:
	var g47: V01Guard = enc.guards[0]
	stand(Vector3(27.0, 0.0, -6.0), g47.global_position + Vector3(0, 1.4, 0))
	var two_at_once := false
	var until := Time.get_ticks_msec() + int(9000 / Engine.time_scale)
	while Time.get_ticks_msec() < until:
		var winding: int = enc.guards.filter(func(g: V01Guard) -> bool: return g.is_alive() and g.winding != "" and g.winding != "aim").size()
		if winding > 1:
			two_at_once = true
		# Keep out of reach and keep looking.
		stand(Vector3(27.0, 0.0, -6.0) if vat.player.global_position.distance_to(Vector3(27.0, 1.0, -6.0)) > 1.0 else vat.player.global_position - Vector3(0, vat.BODY_HALF_HEIGHT + 0.02, 0), g47.global_position + Vector3(0, 1.4, 0))
		if WorldHistory.event_count("v01_guard_called") > 0 and enc.guards.all(func(g: V01Guard) -> bool: return g.state != "idle"):
			break
		await get_tree().physics_frame
	check(WorldHistory.event_count("v01_guard_calling") > 0, "a guard who sees you radios first")
	check(WorldHistory.event_count("v01_guard_called") > 0 and enc.guards.all(func(g: V01Guard) -> bool: return g.state != "idle"), "the call goes out and the whole squad comes")
	check(not two_at_once, "never two melee wind-ups at once (the attack token)")
	# Back to their posts for the one-on-one duels below.
	for guard in enc.guards:
		guard.cancel_windup()
		enc.release_token(guard)
	heal()


## Standing still and mashing R1 at a PRODSTAFF guard: blocked, parried, hurt.
func _careless() -> void:
	var g48: V01Guard = enc.guards[1]
	var all := isolate(g48)
	var start := g48.global_position
	stand(g48.global_position + Vector3(0, 0, 2.0), g48.global_position + Vector3(0, 1.4, 0))
	var before := blood()
	var until := Time.get_ticks_msec() + int(9000 / Engine.time_scale)
	while Time.get_ticks_msec() < until and not enc.dead:
		face_point(g48.global_position + Vector3(0, 1.3, 0))
		if enc.swing.is_empty():
			await tap(JOY_BUTTON_RIGHT_SHOULDER)
		await get_tree().physics_frame
	check(WorldHistory.event_count("v01_guard_blocked") > 0, "mashing: he blocks your lights")
	check(WorldHistory.event_count("v01_player_deflected") > 0, "mashing: a third light in a row is parried and you are thrown off")
	check(blood() < before - 0.12 or enc.dead, "mashing costs real blood (%.0f%% -> %.0f%%)" % [before * 100.0, blood() * 100.0])
	# Reset him for later, unhurt.
	g48.health = g48.max_health
	g48.cancel_windup()
	g48.stagger_left = 0.0
	g48.parried_left = 0.0
	g48.global_position = start
	enc.release_token(g48)
	restore(all)
	heal()


func _cleaver_staff_guard() -> void:
	var g47: V01Guard = enc.guards[0]
	var all := isolate(g47)
	stand(g47.global_position + Vector3(0.5, 0, 3.5), g47.global_position + Vector3(0, 1.4, 0))
	var won := await duel(g47, 1.7, 2.4, 60.0)
	check(won, "HOTLINE CLEAVER beats PRODSTAFF guard 47 (blood left %.0f%%, his health %.0f)" % [blood() * 100.0, g47.health])
	check(g47.telegraphs > 0 and enc.parries > 0, "he telegraphed (%d) and the careful player parried (%d)" % [g47.telegraphs, enc.parries])
	check(g47.tree_choices > 0, "his choices came from the LimboAI tree (%d)" % g47.tree_choices)
	check(blood() > enc.LOSE_AT, "a careful player is standing at the end")
	check(g47.body is BaselineHuman and (g47.body as BaselineHuman).anatomy.dead, "his body is dead through its own anatomy (gore-capable corpse)")
	var corpse := g47.body as BaselineHuman
	check(corpse != null and ((corpse.rigged != null and corpse.rigged.ragdolled) or corpse.ragdoll_body != null), "and he goes limp on his ragdoll (dec-89)")
	check(str(WorldHistory.subject(g47.foe_id).get("status", "")) == "dead", "his death is filed in WorldHistory")
	restore(all)
	heal()


func _cleaver_pistol_guard() -> void:
	var g49: V01Guard = enc.guards[2]
	var all := isolate(g49)
	stand(g49.global_position + Vector3(0, 0, 7.0), g49.global_position + Vector3(0, 1.4, 0))
	var won := await duel(g49, 1.7, 1.6, 70.0)
	check(won, "HOTLINE CLEAVER beats pistol guard 49 (blood left %.0f%%, his health %.0f)" % [blood() * 100.0, g49.health])
	check(g49.shots_fired > 0 or WorldHistory.event_count("v01_guard_reload") > 0 or g49.attacks_made > 0, "he fought back (shots %d, whips %d)" % [g49.shots_fired, g49.attacks_made])
	restore(all)
	heal()


## The dropped PRODSTAFF, taken with Square, kills guard 48.
func _prodstaff_duel() -> void:
	var g47: V01Guard = enc.guards[0]
	var pickup := _pickup_of(g47.foe_id)
	check(not pickup.is_empty(), "guard 47 dropped his PRODSTAFF")
	if pickup.is_empty():
		return
	var at: Vector3 = (pickup.node as Node3D).global_position
	stand(Vector3(at.x, 0, at.z + 0.8), at)
	await get_tree().physics_frame
	await square()
	await get_tree().physics_frame
	check(enc.staff_in_hand and enc.held_weapon() == "staff", "Square takes the PRODSTAFF into your hands")
	var g48: V01Guard = enc.guards[1]
	var all := isolate(g48)
	stand(g48.global_position + Vector3(0.5, 0, 4.0), g48.global_position + Vector3(0, 1.4, 0))
	var blows_before := enc.blows
	var started := Time.get_ticks_msec()
	var won := await duel(g48, 2.6, 2.4, 70.0)
	check(won, "PRODSTAFF beats guard 48 (blood left %.0f%%, his health %.0f, %d blows, %.1f s, state %s, dead %s)" % [blood() * 100.0, g48.health, enc.blows - blows_before, (Time.get_ticks_msec() - started) * 0.001 * Engine.time_scale, g48.state, str(enc.dead)])
	if not won:
		print("DBG g48 action=%s winding=%s calling=%.2f blocking=%.2f stagger=%.2f parried=%.2f clock=%.2f token=%s dist=%.2f facts=%s" % [g48.last_action, g48.winding, g48.calling, g48.blocking, g48.stagger_left, g48.parried_left, g48.attack_clock, str(enc.tokens), g48.global_position.distance_to(vat.player.global_position), str(g48.facts(2.0))])
	restore(all)
	heal()


## The dropped sidearm, taken with Square, kills a fresh guard at range.
func _gun_duel() -> void:
	var g49: V01Guard = enc.guards[2]
	var pickup := _pickup_of(g49.foe_id)
	check(not pickup.is_empty(), "guard 49 dropped his sidearm")
	if pickup.is_empty():
		return
	HIDDEN_CACHE.give_stash()
	var at: Vector3 = (pickup.node as Node3D).global_position
	stand(Vector3(at.x, 0, at.z + 0.8), at)
	await get_tree().physics_frame
	await square()
	await get_tree().physics_frame
	var rounds: int = enc._gun_rounds()
	check(rounds > 0, "Square takes his sidearm, loose rounds loaded (%d)" % rounds)
	# A fresh guard (the arcade's are down): same class, same post rules.
	var fresh := V01Guard.new()
	fresh.configure("staff", "50", PI)
	enc.add_child(fresh)
	fresh.setup(enc, "v01_guard_test_50", Vector3(28.0, 0.0, -20.0), enc.ARCADE_AREA, 0.0)
	enc.guards.append(fresh)
	var all := isolate(fresh)
	stand(Vector3(28.0, 0.0, -11.0), fresh.global_position + Vector3(0, 1.4, 0))
	var won := await duel(fresh, 1.7, 7.0, 60.0, "gun", "head")
	check(won, "the sidearm beats a PRODSTAFF guard (rounds left %d, his health %.0f)" % [enc._gun_rounds(), fresh.health])
	restore(all)
	enc.foes.append(fresh)


func _pickup_of(guard_id: String) -> Dictionary:
	for pickup in enc.pickups:
		if str(pickup.guard) == guard_id:
			return pickup
	return {}
