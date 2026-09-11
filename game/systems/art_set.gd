class_name ArtSet
extends RefCounted

## G1.3–G1.5. The bridge between Greg's own artwork and the running game.
##
## `tools/art_pipeline.py` reads `Desktop/Art Collections` — read-only, never
## written to — and lays down three kinds of derived sheet in
## `game/art/derived/`: tiling body sheets, interface plates and Wire collages.
## Until now they existed on disk and nothing loaded them, which made G1 look
## finished in the filesystem and unchanged on screen.
##
## Everything here degrades to nothing. A fresh worktree without the derived
## folder, or a pipeline that has not been run, must render exactly as it did
## before rather than erroring — the art is a layer over the procedural look,
## never a dependency of it.

const ROOT := "res://art/derived"
const KINDS := ["body", "plate", "wire"]

static var _cache: Dictionary = {}
static var _scanned := false


## Every sheet of one kind, in a stable order so a seed picks the same sheet
## between runs. Empty when the pipeline has not been run.
static func sheets(kind: String) -> Array:
	_scan()
	return _cache.get(kind, [])


## One sheet of a kind, chosen by seed. Null when there are none, and every
## caller must handle that — see the class docstring.
static func pick(kind: String, seed_value: int) -> Texture2D:
	var available: Array = sheets(kind)
	if available.is_empty():
		return null
	return available[absi(seed_value) % available.size()]


static func has_art() -> bool:
	_scan()
	for kind in KINDS:
		if not (_cache.get(kind, []) as Array).is_empty():
			return true
	return false


## Rebuilds the index. Called automatically; exposed so a test can force a
## rescan after writing files.
static func rescan() -> void:
	_scanned = false
	_cache.clear()
	_scan()


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	for kind in KINDS:
		var found: Array = []
		var directory := DirAccess.open("%s/%s" % [ROOT, kind])
		if directory != null:
			var names := directory.get_files()
			# Exported projects serve `.png.import` stubs and the editor serves
			# raw names; normalise both to the resource path and de-duplicate.
			var seen: Dictionary = {}
			for name in names:
				var resource_name := str(name).trim_suffix(".import")
				if not resource_name.to_lower().ends_with(".png"):
					continue
				if seen.has(resource_name):
					continue
				seen[resource_name] = true
			var ordered := seen.keys()
			ordered.sort()
			for resource_name in ordered:
				var path := "%s/%s/%s" % [ROOT, kind, resource_name]
				if not ResourceLoader.exists(path):
					continue
				var texture: Texture2D = load(path)
				if texture != null:
					found.append(texture)
		_cache[kind] = found
