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
	# `tools/art_pipeline.py` derives these three from Greg's collections, so
	# their folders being empty means the pipeline did not run.
	for kind in ["body", "plate", "wire"]:
		check(not ArtSet.sheets(kind).is_empty(), "%s sheets load (%d)" % [kind, ArtSet.sheets(kind).size()])

	# `slab` is hand-made architecture art rather than pipeline output, so it is
	# legitimately empty until Greg draws some. That is the class's stated
	# contract -- "everything here degrades to nothing" -- and it is the half of
	# it nothing was checking: asserting every kind is populated would make a
	# kind awaiting art indistinguishable from a kind that is broken.
	for kind in ArtSet.KINDS:
		check(ArtSet.sheets(kind) is Array, "%s answers with a list whether or not it has art" % kind)
	var empty_pick: Texture2D = ArtSet.pick("slab", 7) if ArtSet.sheets("slab").is_empty() else null
	check(empty_pick == null, "a kind with no art picks null instead of erroring")

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
	# Architecture takes its own sheets from `slab`, not the body's. Asserting
	# "structural surfaces are left alone" was right while flesh was the only
	# kind that could carry art, and becomes a tripwire the moment a single PNG
	# lands in `art/derived/slab` -- so it checks the rule that actually holds:
	# a wall never wears a body sheet, and only takes a detail layer when slab
	# art exists to give it.
	var rust := WorldLook.surface(Color("6b5842"), "rust", 4)
	var slab_art_exists := not ArtSet.sheets("slab").is_empty()
	check(rust.detail_enabled == slab_art_exists, "walls take a detail layer exactly when slab art exists (%s)" % ("present" if slab_art_exists else "none yet"))
	if slab_art_exists:
		check(not ArtSet.sheets("body").has(rust.detail_albedo), "a wall never wears one of the body sheets")
	# Polished and transparent surfaces stay clean either way: a grime sheet
	# over chrome or pressure glass reads as dirt on the lens, not a surface.
	var chrome := WorldLook.surface(Color("6b5842"), "chrome", 4)
	check(not chrome.detail_enabled, "chrome is never given a grime sheet")
	# The procedural contamination is still underneath it, not replaced.
	check(flesh.albedo_texture != null, "the generated contamination still sits under the art")

	# An unknown kind returns nothing rather than erroring, which is the same
	# path a worktree without the pipeline output takes.
	check(ArtSet.pick("nonexistent", 1) == null, "a missing kind degrades to nothing")

	print("ART_SET_TEST_RESULT failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
