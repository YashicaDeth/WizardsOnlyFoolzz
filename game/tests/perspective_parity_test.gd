extends Node

## AX5.1. "First- and third-person combat share anatomy, wound depth,
## ballistics and the same resolution."
##
## Today they do, and they do it the simplest possible way: there is one
## `apply_hit`, one `_resolve_strike`, one `_resolve_firearm`, and none of them
## knows which camera is active. Nothing to build.
##
## What this suite is for is the drift. Perspective-conditioned damage never
## arrives as a decision -- it arrives as one reasonable-looking line, usually
## "third person needs a little more reach to feel right", and then the two
## views are different games and nobody can say when that happened. This reads
## the source and fails on that line the day it is written.
##
## A static check rather than a behavioural one on purpose: you cannot catch
## this by running combat, because both paths pass their own tests happily
## while disagreeing with each other.

const COMBAT_SOURCES := [
	"res://bone_yard_hunt.gd",
	"res://systems/ballistics.gd",
	"res://systems/penetration.gd",
	"res://systems/anatomy_component.gd",
]

## The functions that decide what a hit does. If perspective reaches any of
## these, the two views have started to diverge.
const RESOLVERS := ["_resolve_strike", "_attack", "_resolve_firearm", "apply_hit", "resolve"]

const PERSPECTIVE_WORDS := ["third_person", "first_person", "is_first_person"]

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


## Everything from `func <name>` up to the next top-level func.
func _body_of(source: String, function_name: String) -> String:
	var marker := "\nfunc %s" % function_name
	var start := source.find(marker)
	if start == -1:
		return ""
	var rest := source.substr(start + 1)
	var next := rest.find("\nfunc ")
	return rest if next == -1 else rest.substr(0, next)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return

	var checked := 0
	for path in COMBAT_SOURCES:
		var source := _read(path)
		check(source != "", "%s is readable" % path.get_file())
		if source == "":
			continue
		for resolver in RESOLVERS:
			var body := _body_of(source, resolver)
			if body == "":
				continue
			checked += 1
			var guilty: Array = []
			for word in PERSPECTIVE_WORDS:
				if body.contains(word):
					guilty.append(word)
			check(guilty.is_empty(), "%s/%s does not branch on the camera (%s)" % [path.get_file(), resolver, str(guilty)])

	check(checked >= 3, "found the resolvers to check (%d)" % checked)

	# One anatomy, not two. A second apply_hit is the other way this diverges.
	var anatomy := _read("res://systems/anatomy_component.gd")
	check(anatomy.count("func apply_hit") == 1, "there is exactly one apply_hit in the game")

	# And the perspective switch itself must stay what it is: a camera.
	var motion := _read("res://systems/hunter_body_motion.gd")
	var switch := _body_of(motion, "set_perspective")
	check(switch != "", "the perspective switch exists")
	var leaks: Array = []
	for word in ["damage", "apply_hit", "wound", "penetrat"]:
		if switch.to_lower().contains(word):
			leaks.append(word)
	check(leaks.is_empty(), "switching view changes the camera and nothing about damage (%s)" % str(leaks))

	print("failures: %d" % failures.size())
	get_tree().quit(1 if failures.size() > 0 else 0)
