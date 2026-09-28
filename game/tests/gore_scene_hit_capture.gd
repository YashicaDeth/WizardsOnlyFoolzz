extends Node

## Lane C proof: a hit, photographed, in each of the four places bodies get hit.
##
##   sandbox      res://gore_demo.tscn
##   vat room     res://vat_chamber.tscn
##   support unit res://support_unit.tscn
##   hunt         res://bone_yard_hunt.tscn
##
## The parity suite proves a hit reaches the rig and blood reaches the world.
## Numbers are not a picture, and this game's whole argument is that gore has
## to be looked at. So each scene is loaded for real, a real person in it is
## hit hard enough to open a wound, and the frame is taken once the blood has
## had time to run -- far enough that the streak is down the skin rather than a
## red dot on a clean body.
##
## The camera is put where it can see the wound, not where the scene's own
## camera happens to be, and the same overlay blackout the station look-check
## needed is applied here: `Fade`, `Submerge` and `TortureLoadIn` are
## full-screen and would otherwise black the whole frame out.

const SCENES := {
	"sandbox": "res://gore_demo.tscn",
	"vat_room": "res://vat_chamber.tscn",
	"support_unit": "res://support_unit.tscn",
	"hunt": "res://bone_yard_hunt.tscn",
}


func _ready() -> void:
	var out_dir := "P:/GameDev/Temp/gore_hits"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(out_dir)
	WorldHistory.clear_history()

	for label: String in SCENES:
		await _shoot(label, SCENES[label], out_dir)
	get_tree().quit(0)


func _shoot(label: String, path: String, out_dir: String) -> void:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	for _frame in 6:
		await get_tree().process_frame

	# Full-screen overlays first, or the frame is black and proves nothing.
	for hud_name in ["HUD"]:
		var hud := scene.get_node_or_null(hud_name)
		if hud == null:
			continue
		for child in hud.get_children():
			if child is Control:
				(child as Control).visible = false

	var rig := _find_rig(scene)
	if rig == null:
		print("GORE_HIT %s :: no rig in the scene" % label)
		scene.queue_free()
		return

	var torso := rig.parts.get("torso") as Node3D
	if torso == null:
		torso = rig
	var at: Vector3 = torso.global_position + Vector3(0.0, 0.12, 0.20)

	# Aimed before the hit so the camera is already on the body, and left
	# running while the blood comes: the point of the picture is the aftermath.
	var camera := _make_camera(scene, at)
	camera.look_at(at, Vector3.UP)

	rig.hit_at(at, 40.0, 10.0, "ballistic", Vector3(0, 0, -1))
	var zone := rig.zone_nearest(at)
	for _frame in 150:
		await get_tree().process_frame

	var streak := 0
	for child in rig.get_children():
		if child.name == "BloodStreak":
			streak += 1
	for zone_id: String in rig.wound_marks.keys():
		var part := rig.parts.get(zone_id) as Node3D
		if part == null or not is_instance_valid(part):
			continue
		if part.get_node_or_null("BloodStreak") != null:
			streak += 1
		var garment := part.get_node_or_null("Garment") as Node3D
		if garment != null and garment.get_node_or_null("BloodStreak") != null:
			streak += 1

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := "%s/gore_hit_%s.png" % [out_dir, label]
	var error := image.save_png(file)
	var total := 0.0
	var samples := 0
	for y in range(0, image.get_height(), 16):
		for x in range(0, image.get_width(), 16):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			samples += 1
	print("GORE_HIT %s :: rig=%s zone=%s wounds=%d streaks=%d falling=%d mean_luma=%.4f save=%s" % [
		label, rig.name, zone, _wound_total(rig), streak,
		(rig.get("_loose") as Array).size(), total / maxf(float(samples), 1.0),
		"ok" if error == OK else "FAILED"])
	scene.queue_free()
	for _frame in 2:
		await get_tree().process_frame


func _make_camera(scene: Node, aim: Vector3) -> Camera3D:
	# Exactly one camera may be current, or aiming one of them changes nothing.
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var current: Node = stack.pop_front()
		if current is Camera3D:
			(current as Camera3D).current = false
		for child in current.get_children():
			stack.append(child)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.position = aim + Vector3(0.85, 0.35, 1.15)
	add_child(cam)
	cam.current = true
	return cam


func _find_rig(node: Node) -> BaselineHuman:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_front()
		if current is BaselineHuman and current.has_method("hit_at"):
			return current
		for child in current.get_children():
			stack.append(child)
	return null


func _wound_total(rig: BaselineHuman) -> int:
	var total := 0
	for marks: Array in rig.wound_marks.values():
		total += (marks as Array).size()
	return total
