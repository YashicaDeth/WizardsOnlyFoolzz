extends Node
## AX3.6: "no permanent all-controls overlay substitutes for staging". Each
## facility scene is opened and left idle; its prompt line must not fall back
## to a standing "WASD MOVE // ..." strip. Keys are taught once (KeyHints).

const SCENES := [
	"res://support_unit.tscn", "res://service_arcade.tscn", "res://old_drains.tscn",
	"res://buried_city.tscn", "res://derby_tunnels.tscn", "res://blood_waterfall_exit.tscn",
]
var failures := 0


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	failures += int(not condition)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	for path: String in SCENES:
		WorldHistory.clear_history()
		var scene: Node = load(path).instantiate()
		add_child(scene)
		for _f in 30:
			await get_tree().process_frame
		var prompt := scene.get("prompt") as Label
		var text := prompt.text if prompt != null else ""
		check(not text.contains("WASD") and not text.contains("MOUSE LOOK"), "%s: no standing controls strip (\"%s\")" % [path.get_file(), text.left(60)])
		if path == "res://support_unit.tscn":
			var hints := scene.get_node_or_null("KeyHints") as KeyHints
			var offered: Array = []
			if hints != null:
				offered.append(str(hints.current.get("id", "")))
				for waiting: Dictionary in hints.queue:
					offered.append(str(waiting.id))
			check(offered.has("creep") and offered.has("strike"), "the Support Unit teaches creeping and striking once instead (%s)" % [offered])
		scene.queue_free()
		await get_tree().process_frame
	print("NO_CONTROLS_STRIP_TEST_RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
