extends Node

## P. Can a stranger get from the front door to the game?
##
## CHECKLIST.md's own critical-path table says seven items make the loop
## playable end to end, and all seven are now struck through - which makes
## "playable" a claim the document is asserting rather than one anything checks.
## This checks it, at the only level that can be checked without a person: every
## door the game offers leads to a scene that exists, loads, and can be stood
## up.
##
## **It derives the graph instead of restating it.** The critical-path table
## went stale precisely because it was a hand-maintained view of something that
## kept moving underneath it, and a hardcoded list of scene transitions here
## would rot the same way - passing happily while the game it describes changed.
## So the edges are read out of the source, from the one call every transition
## goes through.
##
## What this cannot do is tell you the game is any good, or that the handover
## between two scenes reads. It tells you nothing is a dead end, which is the
## floor rather than the ceiling.

## Every scene the loop passes through, plus the two files that are entered from
## outside it.
const ROOTS := [
	"res://country_town_menu.gd",
	"res://vat_chamber.gd",
	"res://rift_derby.gd",
	"res://bone_yard_hunt.gd",
	"res://gore_demo.gd",
	"res://systems/pause_gate.gd",
]

const ENTRY := "res://country_town_menu.tscn"
const MUST_REACH := "res://bone_yard_hunt.tscn"

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


## Both ways out of a scene: the interstitial, and the raw change that
## `gore_demo.gd` still uses as a fallback. Grepping for only the first would
## miss a real edge, which is the kind of gap that makes a green test worthless.
##
## A third form: `country_town_menu.gd` wraps the literal call in
## `_travel_from_menu()` so the Settings panel can go inert before the fade
## starts, which means the literal string never sits next to
## `Interstitial.travel` in that file at all. That silently zeroed the menu's
## outbound edges and made the front door look like a dead end to this test,
## which then failed the very reachability checks it exists to run — a false
## alarm on the loop, not a broken one. Any function with "travel" in its name
## is trusted to be a wrapper around the same chokepoint.
func _edges_from(script_path: String) -> Array[String]:
	var out: Array[String] = []
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return out
	var source := file.get_as_text()
	var finder := RegEx.new()
	finder.compile('(?:Interstitial\\.travel|change_scene_to_file|\\w*travel\\w*)\\(\\s*"(res://[^"]+\\.tscn)"')
	for found in finder.search_all(source):
		var target := found.get_string(1)
		if not out.has(target):
			out.append(target)
	return out


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	# --- every door leads somewhere that exists -----------------------------
	var graph := {}
	var total_edges := 0
	for script_path: String in ROOTS:
		check(ResourceLoader.exists(script_path), "%s is where the loop says it is" % script_path)
		var edges := _edges_from(script_path)
		graph[script_path] = edges
		total_edges += edges.size()
		for target: String in edges:
			check(ResourceLoader.exists(target),
				"%s -> %s is not a dead link" % [script_path.get_file(), target.get_file()])
	# Not a threshold. `total_edges >= 8` was the first version of this line and
	# it failed at 7, which told me nothing about the game and everything about
	# the number I had guessed. What matters structurally is that reading the
	# source produced a graph at all - an empty result here means the regex
	# stopped matching, and every check below it would then pass vacuously.
	print("  graph: %d edges across %d scripts" % [total_edges, ROOTS.size()])
	check(total_edges > 0, "reading the source produced a graph, so nothing below passes vacuously")

	# --- the hunt has an authored ending -------------------------------------
	# The demo wall is the first real end of a run. It must leave through the
	# same visible seam as every other production transition rather than making
	# the last action of the run a raw scene cut. Keep both claims executable:
	# there is a way out, and that way goes through the interstitial.
	var hunt_exits := _edges_from("res://bone_yard_hunt.gd")
	check(hunt_exits.has(ENTRY), "the hunt has an authored ending back at the front door")
	var hunt_source := FileAccess.get_file_as_string("res://bone_yard_hunt.gd")
	check(hunt_source.contains('Interstitial.travel("res://country_town_menu.tscn"'),
		"the hunt ending uses the interstitial rather than a hard scene cut")

	# --- and every one of them actually loads -------------------------------
	var scenes: Array[String] = [ENTRY]
	for script_path: String in graph:
		for target: String in graph[script_path]:
			if not scenes.has(target):
				scenes.append(target)
	for scene_path: String in scenes:
		var packed := load(scene_path)
		check(packed is PackedScene, "%s loads as a scene" % scene_path.get_file())
		if packed is PackedScene:
			check((packed as PackedScene).can_instantiate(),
				"and %s can actually be stood up" % scene_path.get_file())

	# --- the entry point reaches the game -----------------------------------
	# Breadth-first from the front door. A stranger who only ever presses the
	# button the menu offers has to end up somewhere that is the game; if the
	# hunt is unreachable from the entry scene then whatever else is true, the
	# loop is not closed.
	var seen: Array[String] = []
	var queue: Array[String] = [ENTRY]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if seen.has(here):
			continue
		seen.append(here)
		var as_script := here.replace(".tscn", ".gd")
		if not ResourceLoader.exists(as_script):
			as_script = "res://systems/%s" % as_script.get_file()
		for target: String in _edges_from(as_script):
			if not seen.has(target):
				queue.append(target)
	check(seen.has(MUST_REACH),
		"a stranger can reach the hunt from the front door (visited %d scenes)" % seen.size())
	check(seen.has("res://rift_derby.tscn"), "by way of the derby")
	check(seen.has("res://vat_chamber.tscn"), "and the vat, on a fresh run")

	# --- the way back out ----------------------------------------------------
	# Rule 3's sibling: a player who can get in and not out is stuck, and
	# `pause_gate.gd` is the only thing standing between them and the task
	# manager.
	check(_edges_from("res://systems/pause_gate.gd").has("res://country_town_menu.tscn"),
		"and can always get back out again, from anywhere, through the pause gate")

	print("LOOP_SMOKE_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
