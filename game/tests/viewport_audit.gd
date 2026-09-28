extends Node
## X10.6: which SubViewports render every frame while nobody can see them.
## `-- --scene=res://x.tscn`. Prints one line per viewport; exit code is the
## number rendering always behind a hidden owner.

func _ready() -> void:
	var scene_path := "res://bone_yard_hunt.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_path = argument.trim_prefix("--scene=")
	var level: Node = load(scene_path).instantiate()
	add_child(level)
	for _frame in 90:
		await get_tree().process_frame
	var wasted := 0
	for node in get_tree().root.find_children("*", "SubViewport", true, false):
		var viewport := node as SubViewport
		var owner_item := _owner_item(viewport)
		var seen := owner_item == null or owner_item.is_visible_in_tree()
		var always := viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		if always and not seen:
			wasted += 1
		print("VIEWPORT %s always=%s seen=%s size=%s %s" % ["WASTE" if always and not seen else "ok", always, seen, viewport.size, viewport.get_path()])
	print("VIEWPORT_AUDIT_RESULT failures=%d" % wasted)
	get_tree().quit(wasted)


## The nearest CanvasItem above the viewport: the thing that would show it.
func _owner_item(node: Node) -> CanvasItem:
	var at := node.get_parent()
	while at != null:
		if at is CanvasItem:
			return at
		at = at.get_parent()
	return null
