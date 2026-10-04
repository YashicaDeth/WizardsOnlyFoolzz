extends Node

## Lab-48: organs, cybernetics and the X-ray as one system.
## No rip without an opening; each organ's failure; a shorted implant stops
## working; the scan reports what is installed; swap and sell; and the whole
## thing in the mechanics lab's bodies station on the rigged dummies.

const BODIES := preload("res://lab/stations/bodies_station.gd")

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		print("FAIL ", label)


func _ready() -> void:
	_failures_of_each_organ()
	_shorting()
	await _rip_needs_an_opening()
	_scan_and_swap()
	await _in_the_lab()
	print("ORGAN_SYSTEM_TEST_RESULT failures=%d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _anatomy(id: String) -> AnatomyComponent:
	var anatomy := AnatomyComponent.new()
	add_child(anatomy)
	anatomy.set_process(false)
	anatomy.configure(id, 4300.0)
	return anatomy


func _ticks(anatomy: AnatomyComponent, seconds: float) -> void:
	var step := 0.1
	var spent := 0.0
	while spent < seconds:
		OrganSystem.tick(anatomy, step)
		anatomy._process(step)
		spent += step


# --- each organ fails in its own way ------------------------------------------

func _failures_of_each_organ() -> void:
	check(AnatomyComponent.ORGANS.has("stomach") and AnatomyComponent.ORGANS.has("left_kidney") and AnatomyComponent.ORGANS.has("right_kidney"), "the body has a stomach and two kidneys as well")
	var whole := _anatomy("whole")
	var calm := OrganSystem.failure(whole)
	check(not calm.breathless and not calm.heart_failing and not calm.slow_bleed and not calm.dropped, "an intact body fails in no way")
	check(is_equal_approx(OrganSystem.pace(whole), 1.0), "and moves at full pace")

	var lungs := _anatomy("lungs")
	lungs.damage_organ("left_lung", 999.0)
	var winded := OrganSystem.failure(lungs)
	check(winded.breathless and winded.no_sprint, "a burst lung: breathless, no sprint")
	check(not lungs.dead and OrganSystem.pace(lungs) < 1.0, "it slows them without killing them")

	var heart := _anatomy("heart")
	heart.damage_organ("heart", 999.0)
	check(OrganSystem.failure(heart).heart_failing, "a burst heart is failing")
	_ticks(heart, OrganSystem.HEART_DEATH_SECONDS * 0.5)
	check(not heart.dead, "not dead at once")
	_ticks(heart, OrganSystem.HEART_DEATH_SECONDS * 0.6)
	check(heart.dead, "dead within %.0f seconds: a fast death" % OrganSystem.HEART_DEATH_SECONDS)

	var liver := _anatomy("liver")
	liver.damage_organ("liver", 999.0)
	check(OrganSystem.failure(liver).slow_bleed, "a burst liver bleeds inside")
	var blood_before := liver.blood_remaining
	_ticks(liver, 20.0)
	check(liver.internal_bleed_rate >= OrganSystem.SLOW_BLEED_FLOOR - 0.01, "and keeps bleeding (%.1f ml/s)" % liver.internal_bleed_rate)
	check(liver.blood_remaining < blood_before and not liver.dead, "slowly: blood falls (%d -> %d) but twenty seconds does not kill" % [roundi(blood_before), roundi(liver.blood_remaining)])
	var gut := _anatomy("gut")
	gut.damage_organ("gut", 999.0)
	check(OrganSystem.failure(gut).slow_bleed, "so does a burst gut")

	var brain := _anatomy("brain")
	brain.damage_organ("brain", 999.0)
	check(brain.dead and OrganSystem.failure(brain).dropped, "a burst brain drops them")

	var player := _anatomy("player")
	player.undying = true
	player.damage_organ("heart", 999.0)
	_ticks(player, OrganSystem.HEART_DEATH_SECONDS + 0.5)
	check(player.failed and not player.dead and OrganSystem.failure(player).dropped, "the same heart drops the player (body failed, spirit not)")


# --- a shorted implant stops working ------------------------------------------

func _shorting() -> void:
	var body := _anatomy("shorted")
	body.install_part("chest", {"id": "copper lung bellows"})
	body.install_part("organ_bays", {"id": "quiet-heart regulator"})
	body.install_part("right_leg", {"id": "heel anchors"})
	body.install_part("spine", {"id": "ceramic sternum"})
	body.damage_organ("right_lung", 999.0)
	body.damage_organ("heart", 999.0)
	check(not OrganSystem.failure(body).no_sprint, "a working lung bellows breathes for a burst lung")
	check(not OrganSystem.failure(body).heart_failing, "a working regulator keeps a burst heart going")
	check(body.limb_can("right_leg", "kick_off"), "heel anchors kick off")

	var shorted := OrganSystem.shock(body, 1.0)
	var sites: Array = []
	for entry in shorted:
		sites.append(str(entry.site))
	check(sites.has("chest") and sites.has("organ_bays") and sites.has("right_leg"), "a shock shorts every powered implant (%s)" % ", ".join(sites))
	check(not sites.has("spine"), "a plate conducts but does not short")
	check(not OrganSystem.implant_active(body.installed_parts.chest), "the shorted bellows is not working")
	check(OrganSystem.failure(body).no_sprint, "so the lung failure is back: no sprint")
	check(OrganSystem.failure(body).heart_failing, "and the heart is stopping")
	check(not body.limb_can("right_leg", "kick_off"), "shorted heel anchors do not kick off")
	check(OrganSystem.implant_active(body.installed_parts.spine), "the plate is still a plate")
	var again := OrganSystem.shock(body, 1.0)
	check(not again.is_empty() and bool(again[0].overloaded), "a second shock while shorted overloads")
	check(body.implant_condition("chest") <= 0.0, "an overloaded implant is burnt out for good")


# --- no hole, no rip ----------------------------------------------------------

func _rip_needs_an_opening() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var rig := BODIES.dummy(holder, "rip_subject", Vector3.ZERO, 0.0, 0, {"chest": "ceramic sternum"})
	await get_tree().process_frame
	check(OrganSystem.rip_refusal(rig, "heart") == "STILL STANDING", "a standing body cannot be ripped into")
	rig.anatomy.go_down()
	check(OrganSystem.rip_refusal(rig, "heart") == "NO OPENING", "a downed body with no wound: no opening")
	rig.reveal_organs(true)
	check(OrganSystem.rip_refusal(rig, "heart") == "NO OPENING", "seeing the heart in X-ray is not an opening")
	check(OrganSystem.begin_rip(rig, "heart").is_empty(), "so no rip starts")
	rig.reveal_organs(false)
	# A blow that does not reach the chest does not open it either.
	var front := -rig.global_transform.basis.z
	var chest: Vector3 = (rig.parts.torso as Node3D).global_position + front * 0.12
	var light := rig.hit_at(chest, 6.0, 1.0, "cut", -front)
	check(OrganSystem.after_hit(rig, light, -front, "cut").is_empty(), "a graze does not open the chest")
	var opened := {}
	for blow in 6:
		var result := rig.hit_at(chest, 34.0, 4.0, "cut", -front)
		opened = OrganSystem.after_hit(rig, result, -front, "cut")
		if not opened.is_empty():
			break
	check(not opened.is_empty(), "deep cuts to the chest open it (layer %d)" % rig.exposed_layer("torso"))
	check(OrganSystem.is_opened(rig, "torso") and (opened.get("organs", []) as Array).has("heart"), "and the heart shows through the hole")
	# Cuts at the sternum can burst the heart, which then spills on its own;
	# a burst organ is refused, so take the first one still whole.
	var target := ""
	for organ_id in ["heart", "stomach", "liver", "left_lung", "right_lung"]:
		if rig.anatomy.organ_ok(organ_id):
			target = organ_id
			break
	if target != "heart":
		check(OrganSystem.rip_refusal(rig, "heart") == "BURST", "a burst heart has already come out on its own")
	check(target != "", "an organ is still in there to take (%s)" % target)
	var downed_alive := not rig.anatomy.dead
	var session := OrganSystem.begin_rip(rig, target)
	check(not session.is_empty(), "through the wound, the rip starts")
	OrganSystem.tug(session, 0.4, true)
	var partway := float(session.progress)
	OrganSystem.tug(session, 0.5, false)
	check(float(session.progress) < partway, "let go and it slips back in")
	var seconds := 0.0
	while not bool(session.complete) and seconds < 5.0:
		OrganSystem.tug(session, 0.05, true)
		seconds += 0.05
	check(bool(session.complete) and seconds <= OrganSystem.RIP_SECONDS * 1.6, "held, it comes out in a short tug (%.2f s)" % seconds)
	var info := OrganSystem.finish_rip(session)
	check(str(info.get("organ_id", "")) == target and str(info.get("layer_name", "")) == "organ", "what comes out is the %s" % target)
	check(float(info.get("condition", 0.0)) > 0.0 and float(info.get("condition", 1.0)) < 1.0, "with a condition, bruised by bare hands (%.2f)" % float(info.get("condition", 0.0)))
	check(not (rig.organ_parts[target] as Node3D).visible and bool(rig.anatomy.organs[target].get("removed", false)), "and it is gone from the body")
	if target == "heart":
		check(not downed_alive or rig.anatomy.dead, "a heart ripped from a downed living body is a finisher")
	else:
		check(rig.anatomy.internal_bleed_rate > 0.0, "ripped from a living body, it bleeds inside")
	check(OrganSystem.rip_refusal(rig, target) == "ALREADY TAKEN", "it cannot be taken twice")
	if downed_alive and not rig.anatomy.dead:
		rig.anatomy.finish("test")
	var carry := Carry.new()
	var item := OrganSystem.carry_item(carry, info)
	check(str(item.get("kind", "")) == "organ" and int(item.get("value", 0)) > 0, "in the bag as an organ with a sell value (%d)" % int(item.get("value", 0)))
	# A corpse: open, harvest a kidney, no finisher needed.
	var session2 := OrganSystem.begin_rip(rig, "left_kidney" if rig.anatomy.organ_ok("left_kidney") else "right_kidney")
	check(not session2.is_empty(), "the corpse can be harvested through the same hole")
	holder.queue_free()


# --- the scan, swap and sell --------------------------------------------------

func _scan_and_swap() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var rig := BODIES.dummy(holder, "scan_subject", Vector3.ZERO, 0.0, 0, BODIES.LOADOUTS[0])
	rig.anatomy.install_part("right_leg", {"id": "heel anchors"})
	var report := OrganSystem.scan(rig)
	var tags: Array = []
	for entry in report.implants:
		tags.append(str(entry.tag))
	check(tags.has("PLATED RIBS") and tags.has("HEART REGULATOR") and tags.has("HEEL ANCHORS"), "the scan names every implant by its tag (%s)" % ", ".join(tags))
	check(report.implants.size() == rig.anatomy.installed_parts.size(), "and only what is installed")
	var plated: Array = []
	for entry in report.plates:
		plated.append(str(entry.tag))
	check(plated.has("PLATED RIBS"), "plates are reported as plates (%s)" % ", ".join(plated))
	check(report.organs.size() == AnatomyComponent.ORGANS.size(), "every organ has a health line")
	check(int(report.value) > 0, "and there is a loot estimate (%d)" % int(report.value))
	rig.anatomy.damage_organ("liver", 999.0)
	var shocked := OrganSystem.shock(rig.anatomy, 1.0)
	var after := OrganSystem.scan(rig)
	check((after.damaged as Array).has("liver"), "already-damaged organs are reported")
	var shorted_tags: Array = []
	for entry in after.implants:
		if bool(entry.shorted):
			shorted_tags.append(str(entry.tag))
	check(shorted_tags.has("HEART REGULATOR") and not shorted_tags.has("PLATED RIBS") and shocked.size() == shorted_tags.size(), "shorted hardware reads shorted (%s)" % ", ".join(shorted_tags))
	check(int(after.value) < int(report.value), "and the body is worth less (%d -> %d)" % [int(report.value), int(after.value)])

	# Swap: a harvested heart into a body whose heart has burst.
	var carry := Carry.new()
	var heart_item := OrganSystem.carry_item(carry, {"layer": GoreChunks.Layer.ORGAN, "layer_name": "organ", "organ_id": "heart", "zone": "torso", "subject_id": "donor", "lien": "donor", "condition": 0.7})
	var lung_item := OrganSystem.carry_item(carry, {"layer": GoreChunks.Layer.CYBERNETIC, "layer_name": "cybernetic", "implant": "copper lung bellows", "zone": "chest", "subject_id": "donor", "lien": "donor", "condition": 0.8})
	check(int(heart_item.value) > 0 and int(lung_item.value) > int(heart_item.value), "organs and hardware carry a sell value (%d, %d)" % [int(heart_item.value), int(lung_item.value)])
	var me := BODIES.dummy(holder, "swap_subject", Vector3(3, 0, 0), 0.0, 1)
	me.anatomy.undying = true
	me.anatomy.damage_organ("heart", 999.0)
	var done := OrganSystem.install_into_self(carry, carry.items.find(heart_item), me)
	check(str(done.get("organ", "")) == "heart" and me.anatomy.organ_ok("heart"), "a harvested heart goes into you")
	check(absf(float(me.anatomy.organs.heart.health) - float(AnatomyComponent.ORGANS.heart.health) * 0.7) < 0.01, "and works as well as it was kept")
	check(not OrganSystem.failure(me.anatomy).heart_failing, "the heart failure is over")
	var fitted := OrganSystem.install_into_self(carry, carry.items.find(lung_item), me)
	check(not fitted.is_empty() and str(fitted.get("implant", "")) == "copper lung bellows", "a harvested implant goes in through the existing install path")
	check(carry.items.find(heart_item) < 0 and carry.items.find(lung_item) < 0, "both leave the bag")
	holder.queue_free()


# --- the bodies station -------------------------------------------------------

func _in_the_lab() -> void:
	BloodPool.clear()
	var lab: Node3D = load("res://lab/mechanics_lab.tscn").instantiate()
	add_child(lab)
	for frame in 4:
		await get_tree().physics_frame
	lab.go_to(1)
	var rig: BaselineHuman = lab.bodies.rigs()[0]
	check(rig.get_node_or_null("OrganLife") != null, "the station's rigged dummies run the organ rules")
	check(rig.rigged != null, "on the rigged body")
	check(not rig.anatomy.installed_parts.is_empty(), "and carry hardware")

	# X-ray: the scan points at the body in front of you.
	lab.bodies.press()
	_aim(lab, (rig.parts.torso as Node3D).global_position)
	for frame in 3:
		await get_tree().physics_frame
	check(lab.organ_scan.visible and lab.organ_scan.rig != null, "X-ray on: a body in view is scanned")
	var piece := (rig.parts.torso as Node3D).get_node_or_null("Implant_chest") as MeshInstance3D
	check(piece != null and piece.visible, "its chest hardware shows under the X-ray")
	var skin := rig.parts.torso as MeshInstance3D
	check(skin.material_override == OrganSystem.xray_shell(), "the skin is the X-ray film")
	check((rig.organ_parts.heart.mesh.surface_get_material(0) as StandardMaterial3D).emission_enabled, "the organs glow in it")
	lab.bodies.press()
	await get_tree().physics_frame
	check(piece == null or not piece.visible, "and is inside the body again with the X-ray off")
	check(skin.material_override != OrganSystem.xray_shell() and skin.material_override != null, "the skin gets its own flesh back")
	check(not (rig.organ_parts.heart.mesh.surface_get_material(0) as StandardMaterial3D).emission_enabled, "and the organs stop glowing")

	# The PRODSTAFF shorts it, with sparks.
	var at: Vector3 = (rig.parts.torso as Node3D).global_position
	lab._land(rig.parts.torso, at, Vector3(0, 0, -1), {"damage": 8.0, "impulse": 1.0, "damage_type": "blunt", "shock": true, "weapon": "staff"}, "melee", null)
	var shorted: Array = lab.last_hit.get("shorted", [])
	check(not shorted.is_empty(), "the PRODSTAFF shorts the dummy's implant (%s)" % lab.last_note)
	check(OrganSystem.is_shorted(rig.anatomy.installed_parts.organ_bays), "its heart regulator is shorted")
	var sparks := 0
	for child in get_tree().current_scene.get_children() if get_tree().current_scene != null else get_tree().root.get_children():
		if str(child.name).begins_with("ImplantSparks"):
			sparks += 1
	for child in get_tree().root.get_children():
		if str(child.name).begins_with("ImplantSparks"):
			sparks += 1
	check(sparks > 0, "with sparks (%d)" % sparks)

	# Stand in front of it, in reach.
	var front := -rig.global_transform.basis.z
	front.y = 0.0
	front = front.normalized()
	lab.player.global_position = Vector3(at.x, lab.player.global_position.y, at.z) + front * 1.25
	# Cleaver into the belly until the chest opens and the body goes down.
	var toward := front
	var blows := 0
	while blows < 14 and (not OrganSystem.is_opened(rig, "torso") or not (rig.anatomy.downed or rig.anatomy.dead)):
		var chest: Vector3 = (rig.parts.torso as Node3D).global_position + toward * 0.1 + Vector3.DOWN * 0.17
		lab._land(rig.parts.torso, chest, -toward, {"damage": 30.0, "impulse": 3.0, "damage_type": "cut", "weapon": "cleaver"}, "melee", null)
		blows += 1
		await get_tree().physics_frame
	check(OrganSystem.is_opened(rig, "torso"), "the cleaver opens the chest (%d blows)" % blows)
	check(rig.anatomy.downed or rig.anatomy.dead, "and puts the dummy down")

	# Aim at the heart (or, if a blow burst it, the next whole organ) through
	# the hole and hold.
	var target := ""
	for organ_id in ["heart", "left_lung", "right_lung", "liver", "stomach"]:
		if rig.anatomy.organ_ok(organ_id):
			target = organ_id
			break
	var started := false
	for attempt in 40:
		_aim(lab, (rig.organ_parts[target] as Node3D).global_position)
		await get_tree().physics_frame
		if lab.begin_rip_aimed() and not lab.rip.is_empty():
			started = true
			break
	check(started, "aimed at the heart through the wound, the hand goes in (%s)" % lab.last_note)
	lab.rip_held = true
	var waited := 0
	while lab.hand_item.is_empty() and waited < 240:
		await get_tree().physics_frame
		waited += 1
	lab.rip_held = false
	check(str(lab.hand_item.get("organ_id", "")) == target, "the %s comes out in your hand (%s)" % [target, lab.last_note])
	check(lab.hand != null and is_instance_valid(lab.hand), "and is held in view")
	check(lab.carry.items.has(lab.hand_item) and int(lab.hand_item.get("value", 0)) > 0, "as a bag item with a value")
	lab.player_body.anatomy.damage_organ(target, 999.0)
	var installed: Dictionary = lab.install_hand_item()
	check(str(installed.get("organ", "")) == target and lab.player_body.anatomy.organ_ok(target), "and into your own chest")
	lab.player_body.anatomy.damage_organ("left_lung", 999.0)
	await get_tree().physics_frame
	check(lab.mover.winded, "a burst lung in you: no sprint")
	lab.queue_free()
	await get_tree().process_frame


func _aim(lab: Node3D, target: Vector3) -> void:
	var eye: Camera3D = lab.camera
	var to := target - eye.global_position
	lab.yaw = atan2(-to.x, -to.z)
	lab.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))
	lab.player.rotation.y = lab.yaw
	eye.rotation.x = lab.pitch
	eye.force_update_transform()
