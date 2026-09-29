extends Node
## Every piece of Greg's art is placed somewhere on the route, and each can
## be seen from a step in front of it. Saves one shot per piece.
const PLACES := {
	"res://vat_chamber.tscn": ["cellout_wizards", "war_time"],
	"res://support_unit.tscn": ["spitrost", "powers_that_be", "jester_seal"],
	"res://service_arcade.tscn": ["cover_me_in_moss", "mirror_hands", "the_hand"],
}
var failures := 0


func _ready() -> void:
	var placed := []
	for path: String in PLACES:
		var scene: Node = load(path).instantiate()
		add_child(scene)
		for _f in 10:
			await get_tree().process_frame
		for id: String in PLACES[path]:
			var poster: WallPoster = scene.get_node_or_null("Art_" + id)
			if poster == null:
				print("FAIL ", id, " not placed in ", path)
				failures += 1
				continue
			placed.append(id)
			var camera := Camera3D.new()
			scene.add_child(camera)
			var out := poster.global_transform.basis.z * 1.5 if poster.kind == "poster" else Vector3(0, 1.3, 0.9)
			camera.global_position = poster.global_position + out
			camera.look_at(poster.global_position, Vector3.UP)
			camera.make_current()
			for _f in 12:
				await get_tree().process_frame
			print(("PASS " if poster.in_reach() else "FAIL ") + id + " in reach from a step away")
			failures += int(not poster.in_reach())
			get_viewport().get_texture().get_image().save_png("P:/GameDev/Temp/gallery/%s.png" % id)
			camera.queue_free()
		scene.queue_free()
		await get_tree().process_frame
	print("GALLERY_PLACES placed=%d failures=%d" % [placed.size(), failures])
	get_tree().quit(failures)
