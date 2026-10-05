extends "res://tests/v01_duel_bot.gd"

## Job 9: the freed vat subject and the Lower Works sentinel, in the real
## route, fought through the real InputMap (pad events only).
## - Walking past the near tank, its living subject breaks out (the same
##   glass, spill and climb-out as a tank you smash), turns, and comes at you;
##   a careful player kills it with the HOTLINE CLEAVER.
## - The X-ray (d-pad up) on the sentinel shows its four plates and its two
##   weak points.
## - A careful player kills the sentinel with each v0.1 weapon: the cleaver
##   on its core when it vents after a ram, the PRODSTAFF's charged shock
##   through its plates, the sidearm in its eye and then its core. Cleaver
##   blows on its plates barely mark it.

const WORKS_FLOOR := -12.0
var _sentinels := 0


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	result_name = "V01_CREATURE_DUEL_TEST"
	await boot()
	check(enc != null, "the one-map route builds the v0.1 encounters")
	if enc == null:
		finish(result_name)
		return
	vat.doctor_route._take_axe()
	await _subject()
	await _xray()
	await _sentinel_plates()
	await _sentinel_cleaver()
	await _sentinel_staff()
	await _sentinel_gun()
	finish(result_name)


func _subject() -> void:
	check(enc.subject == null, "no subject is loose before you pass its tank")
	# Up the aisle past the near tanks, as the walk to the staff door goes.
	var tank: Dictionary = {}
	for each: Dictionary in vat.vat_smash.tanks:
		if int(each.seed) == 1 and (tank.is_empty() or float((each.at as Vector3).x) > float((tank.at as Vector3).x)):
			tank = each
	check(not tank.is_empty(), "the near tank with the living subject is on the floor")
	var at: Vector3 = tank.at
	stand(Vector3(at.x - 2.6, 0.0, at.z + 1.2), at + Vector3(0, 1.2, 0))
	var until := Time.get_ticks_msec() + int(5000 / Engine.time_scale)
	while enc.subject == null and Time.get_ticks_msec() < until:
		await get_tree().physics_frame
	check(enc.subject != null, "it breaks out of its tank as you pass")
	if enc.subject == null:
		return
	check(bool(tank.broken) and WorldHistory.event_count("v01_subject_broke_out") == 1, "through its own glass (VatSmash), filed once")
	check(vat.vat_smash.freed.is_empty(), "no random placeholder subject is made: this one is the v0.1 foe")
	check(enc.subject.brain != null, "it thinks with a LimboAI behaviour tree")
	var foe: V01FreedSubject = enc.subject
	var all := isolate(foe)
	var won := await duel(foe, 1.4, 3.0, 50.0)
	check(won, "HOTLINE CLEAVER beats the freed subject (blood left %.0f%%, its health %.0f)" % [blood() * 100.0, foe.health])
	check(foe.telegraphs > 0, "it telegraphed its claws and pounces (%d)" % foe.telegraphs)
	check(foe.body is BaselineHuman and (foe.body as BaselineHuman).anatomy.dead, "its body dies through its own anatomy")
	check(str(WorldHistory.subject("v01_freed_subject").get("status", "")) == "dead", "its death is filed")
	restore(all)
	heal()


func _xray() -> void:
	var sentinel: V01Sentinel = enc.sentinel
	stand(Vector3(28.0, WORKS_FLOOR, -84.0), sentinel.global_position + Vector3(0, 1.2, 0))
	await get_tree().physics_frame
	await tap(JOY_BUTTON_DPAD_UP)
	for _frame in 6:
		await get_tree().physics_frame
	var report: Dictionary = enc.xray.report
	check(enc.xray_on and enc.xray.visible and enc.xray.rig == sentinel, "d-pad up points the X-ray at the sentinel")
	check((report.get("plates", []) as Array).size() == 4, "the X-ray reads its four armour plates (%d)" % (report.get("plates", []) as Array).size())
	var tags: Array = (report.get("implants", []) as Array).map(func(entry: Dictionary) -> String: return str(entry.tag))
	check(tags.any(func(tag: String) -> bool: return tag.begins_with("CORE")) and tags.any(func(tag: String) -> bool: return tag.begins_with("EYE")), "and its weak points: core and eye (%s)" % str(tags))
	await tap(JOY_BUTTON_DPAD_UP)
	await get_tree().physics_frame
	check(not enc.xray_on, "d-pad up again puts it away")


## Cleaver blows on a plate barely mark it.
func _sentinel_plates() -> void:
	var sentinel := _fresh_sentinel()
	var all := isolate(sentinel)
	var before := sentinel.health
	var result := sentinel.take_blow({"weapon": "cleaver", "move": "light_1", "damage": float(enc.PLAYER_DAMAGE.cleaver), "from": sentinel.global_position + sentinel.forward() * 2.0})
	check(str(result.result) == "armour" and before - sentinel.health < float(enc.PLAYER_DAMAGE.cleaver) * 0.2, "a cleaver light on the front plate: sparks, %.1f of %.0f gets through" % [before - sentinel.health, float(enc.PLAYER_DAMAGE.cleaver)])
	result = sentinel.take_blow({"weapon": "cleaver", "move": "light_1", "damage": float(enc.PLAYER_DAMAGE.cleaver), "from": sentinel.global_position - sentinel.forward() * 2.0})
	check(str(result.result) == "weak" and float(result.damage) >= float(enc.PLAYER_DAMAGE.cleaver) * 2.0 - 0.1, "the same blow on its core from behind bites double (%.0f)" % float(result.damage))
	# Careless: standing in front of it and hacking at the plate.
	stand(sentinel.global_position + sentinel.forward() * 1.8, sentinel.global_position + Vector3(0, 1.2, 0))
	sentinel.alert(vat.player.global_position)
	var before_blood := blood()
	var until := Time.get_ticks_msec() + int(10000 / Engine.time_scale)
	while Time.get_ticks_msec() < until and not enc.dead:
		face_point(sentinel.global_position + Vector3(0, 1.2, 0))
		if enc.swing.is_empty():
			await tap(JOY_BUTTON_RIGHT_SHOULDER)
		await get_tree().physics_frame
	check(sentinel.is_alive(), "and ten seconds of hacking at the front does not kill it (%.0f of %.0f left)" % [sentinel.health, sentinel.max_health])
	check(blood() < before_blood - 0.15 or enc.dead, "hacking at its front plate gets you slammed (%.0f%% -> %.0f%%; it took %.0f of %.0f, front plate %s)" % [before_blood * 100.0, blood() * 100.0, sentinel.max_health - sentinel.health, sentinel.max_health, "off" if float(sentinel.plates.front.health) <= 0.0 else "on"])
	restore(all)
	_retire(sentinel)
	heal()


func _sentinel_cleaver() -> void:
	var sentinel := _fresh_sentinel()
	var all := isolate(sentinel)
	stand(sentinel.global_position + Vector3(0, 0, 7.0), sentinel.global_position + Vector3(0, 1.2, 0))
	var won := await _fight_sentinel(sentinel, "cleaver", 90.0)
	check(won, "HOTLINE CLEAVER beats the sentinel through its core (blood left %.0f%%, its health %.0f, rams %d)" % [blood() * 100.0, sentinel.health, sentinel.rams])
	check(sentinel.rams > 0 and WorldHistory.event_count("v01_sentinel_vent") > 0, "it rammed, overshot and vented")
	restore(all)
	heal()


func _sentinel_staff() -> void:
	var g47: V01Guard = enc.guards[0]
	g47.kill("cleaver")
	var pickup: Dictionary = {}
	for each in enc.pickups:
		if str(each.guard) == g47.foe_id:
			pickup = each
	if pickup.is_empty():
		check(false, "guard 47 dropped his PRODSTAFF")
		return
	var at: Vector3 = (pickup.node as Node3D).global_position
	stand(Vector3(at.x, 0.0, at.z + 0.8), at)
	await get_tree().physics_frame
	await square()
	check(enc.held_weapon() == "staff", "the PRODSTAFF is in hand")
	var sentinel := _fresh_sentinel()
	var all := isolate(sentinel)
	stand(sentinel.global_position + Vector3(0, 0, 7.0), sentinel.global_position + Vector3(0, 1.2, 0))
	var won := await _fight_sentinel(sentinel, "staff", 90.0)
	check(won, "PRODSTAFF beats the sentinel (blood left %.0f%%, its health %.0f)" % [blood() * 100.0, sentinel.health])
	check(WorldHistory.event_count("v01_sentinel_overloaded") > 0, "its charged shock overloaded it through the plates")
	restore(all)
	heal()
	# Back to the cleaver (Y), for anything after.
	await tap(JOY_BUTTON_Y)


func _sentinel_gun() -> void:
	var g49: V01Guard = enc.guards[2]
	g49.kill("cleaver")
	HIDDEN_CACHE.give_stash()
	HIDDEN_CACHE.give_stash()
	var pickup: Dictionary = {}
	for each in enc.pickups:
		if str(each.guard) == g49.foe_id:
			pickup = each
	if pickup.is_empty():
		check(false, "guard 49 dropped his sidearm")
		return
	var at: Vector3 = (pickup.node as Node3D).global_position
	stand(Vector3(at.x, 0.0, at.z + 0.8), at)
	await get_tree().physics_frame
	await square()
	var rounds: int = enc._gun_rounds()
	check(rounds >= 8, "his sidearm, with the cupboard's loose rounds loaded (%d)" % rounds)
	var sentinel := _fresh_sentinel()
	var all := isolate(sentinel)
	stand(sentinel.global_position + Vector3(0, 0, 8.0), sentinel.global_position + Vector3(0, 1.2, 0))
	var won := await _fight_sentinel(sentinel, "gun", 90.0)
	check(won, "the sidearm beats the sentinel: eye, then core (blood left %.0f%%, its health %.0f, rounds used %d of %d)" % [blood() * 100.0, sentinel.health, rounds - enc._gun_rounds(), rounds])
	check(WorldHistory.event_count("v01_sentinel_blinded") > 0, "a round in its eye blinded it")
	restore(all)
	heal()


## Careful against the machine: dodge the red ram sideways, step back from
## the copper slam, and hit it where it is soft. Cleaver: its core when it
## vents. Staff: a charged shock from the front, then its core while it is
## overloaded. Gun: its eye, then its core while it is blind.
func _fight_sentinel(sentinel: V01Sentinel, weapon: String, limit: float) -> bool:
	var started := Time.get_ticks_msec()
	var blood_before := blood()
	var events_before := WorldHistory.events.size()
	var dodges_before := enc.dodges
	var until := started + int(limit * 1000.0 / Engine.time_scale)
	while sentinel.is_alive() and not enc.dead and Time.get_ticks_msec() < until:
		await _sentinel_frame(sentinel, weapon)
		await get_tree().physics_frame
	stick(Vector2.ZERO)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var hurts := []
	for event in WorldHistory.events.slice(events_before):
		if str(event.get("type", "")) == "v01_player_hurt":
			hurts.append("%s/%s since_dodge=%s" % [str(event.details.get("move", "")), str(event.details.get("outcome", "")), str(event.details.get("since_dodge", ""))])
	print("DUEL sentinel/%s hurt by: %s; dodges %d" % [weapon, str(hurts), enc.dodges - dodges_before])
	print("DUEL sentinel/%s: %.1f s, blood lost %.0f%%, telegraphs %d, rams %d, slams %d, plates off %d" % [weapon, (Time.get_ticks_msec() - started) * 0.001 * Engine.time_scale, (blood_before - blood()) * 100.0, sentinel.telegraphs, sentinel.rams, sentinel.slams, sentinel.plates_broken])
	return not sentinel.is_alive() and not enc.dead


func _sentinel_frame(sentinel: V01Sentinel, weapon: String) -> void:
	var here: Vector3 = vat.player.global_position
	var to := sentinel.global_position - here
	to.y = 0.0
	var distance := to.length()
	# Its blows first.
	if sentinel.winding != "":
		var left := sentinel.windup_needed - sentinel.windup
		if sentinel.winding == "ram" and left <= 0.12 and not _dodged_for.has("%d:%d" % [sentinel.get_instance_id(), sentinel.telegraphs]):
			_dodged_for["%d:%d" % [sentinel.get_instance_id(), sentinel.telegraphs]] = true
			face_point(sentinel.global_position + Vector3(0, 1.2, 0))
			stick(Vector2(1.0 if sentinel.telegraphs % 2 == 0 else -1.0, 0.0))
			await get_tree().physics_frame
			await tap(JOY_BUTTON_B)
			await get_tree().physics_frame
			stick(Vector2.ZERO)
			return
		if sentinel.winding == "slam":
			face_point(sentinel.global_position + Vector3(0, 1.2, 0))
			stick(Vector2(0, 1))
			return
	var open := sentinel.venting > 0.0 or sentinel.overloaded > 0.0 or sentinel.blinded > 0.0
	var behind := sentinel.global_position - sentinel.forward() * 1.5
	match weapon:
		"gun":
			if sentinel.blinded <= 0.0:
				# Its eye, from where you stand; keep some distance.
				face_point(sentinel.eye.global_position)
				stick(Vector2(0, 1) if distance < 5.0 else Vector2.ZERO)
				if enc.gun_cooldown <= 0.0 and sentinel.winding != "ram":
					await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.05)
				return
			# Blind: round behind it and put rounds in the core.
			if sentinel.side_facing(here) != "core":
				_walk_to(behind + (behind - sentinel.global_position).normalized() * 1.5, sentinel.core.global_position)
				return
			stick(Vector2.ZERO)
			face_point(sentinel.core.global_position)
			if enc.gun_cooldown <= 0.0:
				await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.05)
			return
		"staff":
			if sentinel.overloaded <= 0.0:
				# Charge a shock and let it go from inside the staff's reach.
				face_point(sentinel.global_position + Vector3(0, 1.2, 0))
				if distance > 2.9:
					stick(Vector2(0, -1))
					return
				stick(Vector2.ZERO)
				if enc.swing.is_empty() and sentinel.winding == "":
					await trigger(JOY_AXIS_TRIGGER_RIGHT, 0.8)
				return
	# Melee into the core while it is open; otherwise wait at a ram's range.
	if open:
		if sentinel.side_facing(here) != "core" or distance > 1.6:
			_walk_to(behind, sentinel.core.global_position)
			return
		stick(Vector2.ZERO)
		face_point(sentinel.core.global_position)
		if enc.swing.is_empty():
			await tap(JOY_BUTTON_RIGHT_SHOULDER)
		return
	face_point(sentinel.global_position + Vector3(0, 1.2, 0))
	stick(Vector2(0, -1) if distance > 7.0 else (Vector2(0, 1) if distance < 4.5 else Vector2.ZERO))


## Walks toward a point on the stick while looking at `look`.
func _walk_to(point: Vector3, look: Vector3) -> void:
	face_point(look)
	var here: Vector3 = vat.player.global_position
	var to := point - here
	to.y = 0.0
	if to.length() < 0.3:
		stick(Vector2.ZERO)
		return
	var local := Basis(Vector3.UP, vat.yaw).inverse() * to.normalized()
	stick(Vector2(local.x, local.z).normalized())


func _fresh_sentinel() -> V01Sentinel:
	_sentinels += 1
	var sentinel := V01Sentinel.new()
	var patrol: Array[Vector3] = [Vector3(28.0, WORKS_FLOOR, -84.0), Vector3(28.0, WORKS_FLOOR, -106.0)]
	sentinel.configure(patrol)
	enc.add_child(sentinel)
	sentinel.setup(enc, "v01_sentinel_test_%d" % _sentinels, Vector3(28.0, WORKS_FLOOR, -95.0), enc.WORKS_AREA, WORKS_FLOOR)
	sentinel.avoid = enc.sentinel.avoid
	enc.foes.append(sentinel)
	# The route's own sentinel stands down for the duel.
	enc.sentinel.visible = false
	return sentinel


func _retire(sentinel: V01Sentinel) -> void:
	enc.foes.erase(sentinel)
	sentinel.queue_free()
