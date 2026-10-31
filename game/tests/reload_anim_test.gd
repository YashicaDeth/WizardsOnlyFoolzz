extends Node

## AF1.4 follow-up. Greg: *"reloading weapons and those animations need to be
## fixed, the reload is so broken."* Captured on the lane (`reload_anim_capture`,
## 31 Oct) and reduced here to the two things the frames actually showed:
##
##   1. The shotgun refused the reload outright. `reload()` gave up whenever
##      `cooldown > 0`, and a pump shotgun's recovery is 0.92 s — so the most
##      natural input in the game, fire and then tap R, did nothing at all: no
##      timer, no animation, no prompt. The sidearm looked fine only because
##      its 0.28 s recovery usually elapses first.
##
##   2. Aiming cancelled the reload. `FirstPersonArms.pose()` applies the aim
##      pose last, so while the sights were up the reload pose was overwritten
##      on the same frame: the magazine fell out of a pistol welded to the
##      sight line, and `mount_moved` read 0.000 on every frame of the swap.
##
## The gate: a reload asked for inside the recovery is accepted and finishes a
## real swap, and it is visible with the sights up — the gun comes off them for
## the swap and goes back on them afterwards.

var failures: Array[String] = []
var lab: Node3D
var arms: FirstPersonArms


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	BloodPool.clear()
	lab = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	arms = lab.held_mount
	check(arms != null, "the lab has first-person arms")

	await _asked_inside_the_recovery()
	await _aimed_reload_is_visible()

	print("RELOAD_ANIM_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)


## 1. Fire, then immediately ask to reload. The request has to survive the
## recovery the shot just started, for every firearm the Hunt issues.
func _asked_inside_the_recovery() -> void:
	for weapon_id in ["shotgun", "sidearm"]:
		# Each weapon is its own case: the arsenal keeps one cooldown, one
		# reload timer and one jam record for whatever is in hand, so a test
		# that carried the previous case's clock into the next would be
		# measuring its own bookkeeping rather than the reload.
		lab.arsenal.cooldown = 0.0
		lab.arsenal.reload_remaining = 0.0
		lab.arsenal.jam_clear_remaining = 0.0
		lab.arsenal.jammed[weapon_id] = false
		check(lab.arsenal.select_slot(lab.arsenal.carried().find(weapon_id)), "%s is in hand" % weapon_id)
		await _frames(2)
		lab.arsenal.ammo[weapon_id]["loaded"] = 1
		var shot: Dictionary = lab.arsenal.begin_attack()
		check(bool(shot.get("accepted", false)), "%s fires" % weapon_id)
		check(lab.arsenal.cooldown > 0.0, "%s is still recovering when R is pressed (%.2fs)" % [weapon_id, lab.arsenal.cooldown])
		check(lab.arsenal.reload(), "%s accepts a reload inside its own recovery" % weapon_id)
		var duration := float(lab.arsenal.current().get("reload", 1.0))
		check(duration > 0.0 and lab.arsenal.reload_remaining > 0.0, "%s starts a real reload timer (%.2fs)" % [weapon_id, lab.arsenal.reload_remaining])
		# It has to finish, not merely start.
		var guard := 0
		while lab.arsenal.reload_remaining > 0.0 and guard < 400:
			lab.arsenal.tick(1.0 / 30.0)
			guard += 1
		check(lab.arsenal.reload_remaining <= 0.0, "%s's reload finishes" % weapon_id)
		check(int(lab.arsenal.ammo[weapon_id]["loaded"]) == int(lab.arsenal.WEAPONS[weapon_id]["magazine"]),
			"%s comes back full (%d)" % [weapon_id, int(lab.arsenal.ammo[weapon_id]["loaded"])])


## 2. The same swap with the sights up: the arms must leave the sight line for
## it, and come back onto it once the magazine is seated.
func _aimed_reload_is_visible() -> void:
	lab.arsenal.select_weapon("sidearm")
	await _frames(2)
	# Sample the shouldered pose with nothing else running.
	arms.aim_blend = 1.0
	arms.pose(0.0)
	var shouldered := arms.held.position
	var base := arms.held.position

	lab.arsenal.ammo["sidearm"]["loaded"] = 2
	check(lab.arsenal.reload(), "the sidearm reloads with the sights up")
	var duration := float(lab.arsenal.current().get("reload", 1.0))
	# Halfway through: the magazine is out and the fresh one is on its way in.
	lab.arsenal.tick(duration * 0.5)
	arms.aim_blend = 1.0
	arms.pose(0.0)
	var dipped := arms.held.position.distance_to(shouldered)
	check(arms.last_phase == "reload", "the arms are in the reload pose with the sights up (%s)" % arms.last_phase)
	check(dipped > 0.05, "and the gun actually comes off the sight line for the swap (%.3f m)" % dipped)
	check(arms.held.position.distance_to(base) > 0.05, "the held mount moves, not just the label")

	# Finish it and let the pose settle: the sights have the gun back.
	lab.arsenal.tick(duration * 0.6)
	arms.aim_blend = 1.0
	arms.pose(0.0)
	var home := arms.held.position.distance_to(shouldered)
	check(home < 0.02, "and the sights have the gun back once the magazine is seated (%.3f m)" % home)


func _frames(count: int) -> void:
	for _frame in count:
		await get_tree().physics_frame
