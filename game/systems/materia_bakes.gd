class_name MateriaBakes
extends RefCounted

## drug-70: where TouchDesigner's bakes land, and how the game picks them up
## (DESIGN/TOUCHDESIGNER_PIPELINE.md, "Baking into the game").
##
## Every file is optional. With none present the game uses what it generates
## itself (the palette gradients in `Materia.PALETTES`, the rig's placeholder
## noise, Greg's plate under the trip), so a missing bake is never a broken
## screen. Names, all in `bake_dir`:
##
##   lut_<palette>.png        a palette LUT, read left (dark) to right (light)
##                            along its middle row; replaces that palette
##   flow.png                 the warp/melt field (R and G are the two axes,
##                            0.5 is still); replaces the rig's noise
##   trip_flipbook.png + .json  a frame atlas for the trip's ground layer
##
## A file Godot has imported loads as a resource and ships; a file dropped in
## while the game is open loads from disk for development (it will not be in
## an export until the editor has imported it once).

static var bake_dir := "res://art/materia"


static func path(file_name: String) -> String:
	return bake_dir.path_join(file_name)


static func texture(file_name: String) -> Texture2D:
	var at := path(file_name)
	if ResourceLoader.exists(at):
		return load(at) as Texture2D
	var image := image_of(file_name)
	return ImageTexture.create_from_image(image) if image != null else null


static func image_of(file_name: String) -> Image:
	var at := path(file_name)
	if ResourceLoader.exists(at):
		var loaded := load(at) as Texture2D
		return loaded.get_image() if loaded != null else null
	if not FileAccess.file_exists(at):
		return null
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(at)) == OK else null


## The trip's ground as a flipbook: `{texture, columns, rows, frames, fps,
## loop}`, or empty when there is none. The sidecar JSON carries the layout
## TouchDesigner wrote it with; `frames` defaults to columns x rows.
static func flipbook(base_name: String) -> Dictionary:
	var atlas := texture(base_name + ".png")
	if atlas == null:
		return {}
	var spec := {"columns": 1, "rows": 1, "fps": 24.0, "loop": true}
	var sidecar := path(base_name + ".json")
	if FileAccess.file_exists(sidecar):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(sidecar))
		if parsed is Dictionary:
			spec.merge(parsed, true)
	var columns := maxi(1, int(spec.columns))
	var rows := maxi(1, int(spec.rows))
	return {
		"texture": atlas, "columns": columns, "rows": rows,
		"frames": clampi(int(spec.get("frames", columns * rows)), 1, columns * rows),
		"fps": maxf(1.0, float(spec.fps)), "loop": bool(spec.loop),
	}


## The atlas cell for frame `index`, as a pixel rect.
static func flipbook_region(book: Dictionary, index: int) -> Rect2:
	var atlas: Texture2D = book.texture
	var cell := Vector2(atlas.get_width() / float(book.columns), atlas.get_height() / float(book.rows))
	return Rect2(Vector2(index % int(book.columns), index / int(book.columns)) * cell, cell)
