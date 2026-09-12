extends Node

## AF1.4/AF1.5. Reloading was "top the mag up from one abstract reserve
## number" — there was no such thing as a magazine, only a pool it drew
## from. A real magazine is a discrete object: reloading ejects whatever is
## still in the gun rather than merging it away, and a magazine dropped
## half-full is still half-full the next time it comes back out.

const ARSENAL := preload("res://systems/hunter_arsenal.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var rig := BaselineHuman.new()
	rig.gore = false
	add_child(rig)
	rig.build("magazine_test")
	var arsenal: Node = ARSENAL.new()
	add_child(arsenal)
	arsenal.configure(rig)
	arsenal.select_slot(1) # shotgun: magazine 5, reserve 25

	var state: Dictionary = arsenal.state()
	var spares: Array = state.spare_magazines
	check(spares.size() == 5, "a fresh reserve of 25 seeds as five real magazines of five (%d)" % spares.size())
	var starts_full := true
	for magazine in spares:
		starts_full = starts_full and int(magazine) == 5
	check(starts_full, "each seeded magazine is genuinely full, not one big remainder")

	# Fire down to three rounds left, then reload — the two-round-spent
	# magazine has to actually reappear as a spare, not vanish into a pool.
	for _shot in 2:
		arsenal.begin_attack()
		arsenal.tick(2.0)
	check(int(arsenal.ammo.shotgun.loaded) == 3, "two shots fired, three left in the gun")
	arsenal.tick(2.0)
	check(arsenal.reload(), "reloading is available with spares on hand")
	arsenal.tick(3.0)
	check(int(arsenal.ammo.shotgun.loaded) == 5, "a full spare is what comes back in, not a top-up")
	var after_first_reload: Array = arsenal.state().spare_magazines
	check(after_first_reload.has(3), "the magazine that was still carrying three rounds is now a real spare of three (%s)" % [after_first_reload])
	check(after_first_reload.size() == 5, "four full spares plus the one just ejected (%d)" % after_first_reload.size())

	# Empty the now-full gun down to one round, reload again, and the
	# three-round magazine from before must survive untouched in the bag.
	for _shot in 4:
		arsenal.begin_attack()
		arsenal.tick(2.0)
	check(int(arsenal.ammo.shotgun.loaded) == 1, "four more shots, one left")
	arsenal.tick(2.0)
	arsenal.reload()
	arsenal.tick(3.0)
	var after_second_reload: Array = arsenal.state().spare_magazines
	check(after_second_reload.has(3), "the three-round magazine from the first reload is still exactly three rounds, untouched by the second (%s)" % [after_second_reload])
	check(after_second_reload.has(1), "and the one-round magazine just ejected is now its own spare too")

	# Reserve stays a live, accurate total throughout — old direct readers of
	# ammo[weapon_id].reserve (this project's own arsenal_test.gd included)
	# must never see it drift out of sync with the real magazines.
	var total := 0
	for magazine in after_second_reload:
		total += int(magazine)
	check(int(arsenal.ammo.shotgun.reserve) == total, "reserve always equals the sum of the real magazines (%d == %d)" % [int(arsenal.ammo.shotgun.reserve), total])

	if failures.is_empty():
		print("magazines: physical, and a half-full one stays half-full")
		get_tree().quit(0)
	else:
		print("magazine FAILURES: ", failures)
		get_tree().quit(1)
