extends Node

## I3. celloutz.xyz, fictionalised and built as a reachable place on the Wire
## (Greg's call: mirror or fictionalise, and the answer was fictionalise).
## Also covers I2.3/I2.4 for the new entry specifically, since nothing had
## ever exercised `broken_web.gd` being reached from a real screen before
## this - it existed as pure data with no caller anywhere in the game.

const BROKEN_WEB := preload("res://systems/broken_web.gd")
const WORLD_INDEX := preload("res://systems/world_index.gd")

var failures: Array[String] = []


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		failures.append(what)
		print("  FAIL ", what)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	print("I3 - celloutz.xyz exists as a real, reachable site")
	var store: Dictionary = BROKEN_WEB.site("celloutz_store")
	_check(not store.is_empty(), "the storefront is a real BrokenWeb entry")
	_check(str(store.get("layout", "")) == "storefront", "with its own layout, not a reused one")
	_check(not BROKEN_WEB.is_dead(store), "and it is alive, unlike almost everything else in the catalogue")
	var reachable_there: Array = BROKEN_WEB.reachable_from("ossuary_terminal")
	var ids: Array = []
	for entry: Dictionary in reachable_there:
		ids.append(str(entry.get("id", "")))
	_check(ids.has("celloutz_store"), "it is reachable from the Ossuary terminal")
	_check(ids.has("celloutz_support"), "alongside the customer-care site already there")
	var ids_elsewhere: Array = []
	for entry: Dictionary in BROKEN_WEB.reachable_from("bone_yard_mast"):
		ids_elsewhere.append(str(entry.get("id", "")))
	_check(not ids_elsewhere.has("celloutz_store"), "and it is not reachable from everywhere (I2.3)")

	print("I3 - the signal field names which emitter you are actually at")
	var field: SignalField = SignalField.new()
	# The terminal's own registered position sits inside "THE OSSUARY, BELOW"
	# dead zone's radius, so the reachable stand point is just off it rather
	# than dead centre - the same as approaching any real terminal from a
	# specific side rather than teleporting into its exact marker.
	field.stand_at(Vector2(135.0, -24.0))
	_check(str(field.reading().get("id", "")) == "ossuary_terminal", "standing at the Ossuary terminal resolves to its id")
	field.stand_at(Vector2(9000.0, 9000.0))
	_check(str(field.reading().get("id", "")) == "", "standing nowhere near an emitter resolves to no id at all")

	print("I3 - the World Index can actually reach it")
	var index: Control = WORLD_INDEX.new()
	add_child(index)
	await get_tree().process_frame
	index.size = Vector2(1280, 720)
	index.open()
	index.page = index.PAGES.find("WIRE")
	index.current_emitter_id = "ossuary_terminal"
	index._process(0.05)
	var site_links: Array = []
	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "site":
			site_links.append(link)
	_check(site_links.size() == 2, "both sites in range are real, clickable links (%d)" % site_links.size())

	var store_link := {}
	for link: Dictionary in site_links:
		if str(link.get("id", "")) == "celloutz_store":
			store_link = link
	_check(not store_link.is_empty(), "the storefront specifically is one of them")
	index._follow_link(store_link)
	_check(index.viewing_site == "celloutz_store", "clicking it opens the site")
	index._process(0.05)
	var back_links := 0
	for link: Dictionary in index._link_rects:
		if str(link.get("kind", "")) == "site" and str(link.get("id", "")) == "celloutz_store":
			back_links += 1
	_check(back_links == 1, "and while it is open, the one link left is the way back (%d)" % back_links)
	index._follow_link({"kind": "site", "id": "celloutz_store"})
	_check(index.viewing_site == "", "clicking it again closes it, the same as every other link on this screen")

	print("CELLOUTZ_SITE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
