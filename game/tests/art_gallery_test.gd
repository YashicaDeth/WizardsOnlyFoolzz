extends Node
## Greg's in-game art gallery: a poster on the vat room wall, torn, lands in
## the Brain Index gallery once. `-- --shot` saves the poster and the wall.

var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	WorldHistory.clear_history()
	var vat = load("res://vat_chamber.tscn").instantiate()
	add_child(vat)
	for _f in 3:
		await get_tree().process_frame
	var poster: WallPoster = vat.get_node_or_null("Art_cellout_wizards")
	check(poster != null, "Greg's CELLOUT poster hangs in the vat room")
	if poster == null:
		_done()
		return
	check(not ArtGallery.has("cellout_wizards"), "not in the gallery before it is torn")
	# Stand in front of it, looking at it.
	var camera := Camera3D.new()
	vat.add_child(camera)
	camera.global_position = poster.global_position + Vector3(-1.6, 0.0, 0.0)
	camera.look_at(poster.global_position, Vector3.UP)
	camera.make_current()
	await get_tree().process_frame
	check(poster.in_reach(), "in reach and in view from a step away")
	if "--shot" in OS.get_cmdline_user_args():
		for _f in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/gallery_poster.png")
	check(poster.take(), "E tears a tab off")
	check(ArtGallery.has("cellout_wizards") and ArtGallery.collected().size() == 1, "and the piece is in the gallery")
	check(not poster.take(), "a second tab adds nothing")
	camera.global_position = poster.global_position + Vector3(-6.0, 0.0, 0.0)
	await get_tree().process_frame
	check(not poster.in_reach(), "out of reach from across the aisle")
	_done()


func _done() -> void:
	print("ART_GALLERY_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
