extends Node

## G1.3–G1.5. The sheets built from Greg's own artwork existed on disk for a
## session without anything loading them, which made G1 look finished in the
## filesystem and unchanged on screen. This asserts they reach the game — and,
## just as importantly, that their absence is survivable, because the art is a
## layer over the procedural look rather than a dependency of it.

var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)


func _ready() -> void:
	if OS.get_environment("ATG_TEST_MODE") != "1":
		get_tree().quit(2)
		return
	ArtSet.rescan()

	check(ArtSet.has_art(), "the derived art set is present")
	for kind in ArtSet.KINDS:
		check(not ArtSet.sheets(kind).is_empty(), "%s sheets load (%d)" % [kind, ArtSet.sheets(kind).size()])

	# A seed picks the same sheet every time, or a body's skin would change
	# between frames.
	var first: Texture2D = ArtSet.pick("body", 5)
	var again: Texture2D = ArtSet.pick("body", 5)
	check(first != null and first == again, "a seed picks a stable sheet")
	var other: Texture2D = ArtSet.pick("body", 6)
	check(other != null, "a different seed still returns a sheet")

	# G1.3: it reaches a real material.
	var flesh := WorldLook.surface(Color("6b5842"), "flesh", 4)
	check(flesh.detail_enabled and flesh.detail_albedo != null, "flesh materials carry an art detail layer")
	# And only flesh — the same sheets on every wall would be wallpaper.
	var rust := WorldLook.surface(Color("6b5842"), "rust", 4)
	check(not rust.detail_enabled, "structural surfaces are left alone")
	# The procedural contamination is still underneath it, not replaced.
	check(flesh.albedo_texture != null, "the generated contamination still sits under the art")

	# An unknown kind returns nothing rather than erroring, which is the same
	# path a worktree without the pipeline output takes.
	check(ArtSet.pick("nonexistent", 1) == null, "a missing kind degrades to nothing")

	print("ART_SET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
