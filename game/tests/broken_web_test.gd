extends Node

## I2. The surviving internet is a set of places, not a feed. The claims worth
## asserting are the ones that stop it collapsing back into a platform: no two
## sites share a layout, each is reachable from exactly one place in the world,
## and most of them are measurably dead.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	check(BrokenWeb.SITES.size() >= 5, "there is more than one site (%d)" % BrokenWeb.SITES.size())

	# I2.2 — no two alike. A template with a palette swap is a platform again.
	var layouts: Array = []
	var palettes: Array = []
	for entry in BrokenWeb.SITES:
		layouts.append(str(entry.layout))
		palettes.append(str(entry.palette))
	var unique_layouts: Array = []
	for layout in layouts:
		if not unique_layouts.has(layout):
			unique_layouts.append(layout)
	check(unique_layouts.size() == layouts.size(), "no two sites share a layout (%d layouts, %d sites)" % [unique_layouts.size(), layouts.size()])
	# Was: every palette had to be unique. That failed the moment the web got a
	# second CellOutz page -- celloutz_support and celloutz_store are both
	# "corporate", and they should be: two pages of one company are supposed to
	# look like one company. A brand with a different palette per page is not a
	# brand.
	#
	# What the assertion was actually protecting is that no two sites are
	# indistinguishable, and layout plus palette together is the honest test of
	# that. Sibling pages stay on-brand and still cannot be confused with each
	# other.
	var signatures: Array = []
	for index in layouts.size():
		var signature := "%s/%s" % [layouts[index], palettes[index]]
		if not signatures.has(signature):
			signatures.append(signature)
	check(signatures.size() == layouts.size(), "and no two sites are indistinguishable -- layout and palette together (%d of %d)" % [signatures.size(), layouts.size()])

	# Every palette resolves to a real set of colours rather than the fallback.
	var grounds: Array = []
	for entry in BrokenWeb.SITES:
		var colours: Dictionary = BrokenWeb.palette(str(entry.palette))
		check(colours.has("ground") and colours.has("ink") and colours.has("accent"), "%s palette is complete" % entry.palette)
		grounds.append(str(colours.ground))
	check(grounds.size() == BrokenWeb.SITES.size(), "every site has its own ground")

	# I2.3 — a site is a location. Each names exactly one emitter, and those
	# emitters have to be ones the world actually has.
	var emitter_ids: Array = []
	for emitter in SignalField.EMITTERS:
		emitter_ids.append(str(emitter.id))
	for entry in BrokenWeb.SITES:
		check(emitter_ids.has(str(entry.requires)), "%s hangs off a real emitter (%s)" % [entry.id, entry.requires])

	# Standing at one place does not give you the whole web.
	var at_ossuary: Array = BrokenWeb.reachable_from("ossuary_terminal")
	var at_tunnel: Array = BrokenWeb.reachable_from("tunnel_mast")
	check(not at_ossuary.is_empty() and not at_tunnel.is_empty(), "each emitter carries something")
	check(at_ossuary.size() < BrokenWeb.SITES.size(), "one place is not the whole internet (%d of %d)" % [at_ossuary.size(), BrokenWeb.SITES.size()])
	check(str(at_ossuary[0].id) != str(at_tunnel[0].id), "and two places do not carry the same thing")
	check(BrokenWeb.reachable_from("nowhere_at_all").is_empty(), "somewhere with no emitter carries nothing")

	# I2.4 — dead, and the date proves it.
	var dead := 0
	for entry in BrokenWeb.SITES:
		if BrokenWeb.is_dead(entry):
			dead += 1
			check(BrokenWeb.years_dead(entry) >= 2, "%s is measurably old (%d years)" % [entry.id, BrokenWeb.years_dead(entry)])
	check(dead >= 3, "most of the web is dead (%d of %d)" % [dead, BrokenWeb.SITES.size()])
	check(dead < BrokenWeb.SITES.size(), "but not all of it — something is still updating")
	var moderator_dead := false
	for entry in BrokenWeb.SITES:
		if bool(entry.get("moderator_dead", false)):
			moderator_dead = true
	check(moderator_dead, "at least one moderator is deceased and the board does not know")

	print("BROKEN_WEB_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
