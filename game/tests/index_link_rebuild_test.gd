extends Node

## I5.2 v2. `_link_rects` used to be populated only as a side effect of
## `_draw()`, so it existed nowhere a click could reach before at least one
## paint had happened, and nothing but the renderer could ever ask what was
## on screen. `_rebuild_links()` is now called from `_process()`, so the list
## is real, queryable state independent of drawing - this proves that by
## calling `_process()` directly and reading `_link_rects` without `_draw()`
## ever having run once, and again for a page change with no draw in between.

const WORLD_INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _has_kind(links: Array, kind: String) -> bool:
	for link: Dictionary in links:
		if str(link.get("kind", "")) == kind:
			return true
	return false


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	WorldHistory.clear_history()
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})
	WorldHistory.register_subject("nix_arden", {
		"name": "Nix Arden", "kind": "person", "role": "Scrap medic",
		"wounds": ["spore-burned right lung"],
		"anatomy": {"cybernetics": ["copper lung bellows"]},
	})

	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.get_window().size = Vector2i(1280, 720)
	index.size = Vector2(1280, 720)
	index.open()
	index._jump_to_subject("nix_arden")

	_check(index._link_rects.is_empty(), "a freshly opened index has no links before anything has run")

	# _process() directly, never _draw() - the whole point of the item.
	index._process(0.016)
	_check(not index._link_rects.is_empty(), "_process() alone populates the link list, with no draw call in between")
	_check(_has_kind(index._link_rects, "wound"), "the wound on the selected subject is a real link (%d links)" % index._link_rects.size())
	_check(_has_kind(index._link_rects, "implant"), "so is the installed cybernetic")

	# Switching to a page with no link content clears it, again without a draw.
	index.page = index.PAGES.find("PYRAMID")
	index._process(0.016)
	_check(index._link_rects.is_empty(), "a page with nothing pointable on it reports an empty list, not stale links from the last page")

	print("INDEX_LINK_REBUILD_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
