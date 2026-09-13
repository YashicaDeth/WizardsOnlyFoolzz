extends Control

const PART_VIEWER := preload("res://systems/part_viewer.gd")

var viewer: SubViewport


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color("080605")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	viewer = PART_VIEWER.new()
	viewer.spin_speed = 0.0
	add_child(viewer)
	await get_tree().process_frame
	viewer.size = Vector2i(640, 640)
	viewer.show_part({"kind": "organ", "id": "brain", "zone": "head"}, 1.0)
	viewer.view_rotation = Vector2(0.42, -0.04)
	viewer.zoom_by(1.08)

	var plate := TextureRect.new()
	plate.name = "CortexSpecimen"
	plate.texture = viewer.get_texture()
	plate.position = Vector2(330, 42)
	plate.size = Vector2(620, 620)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(plate)

	var title := Label.new()
	title.text = "HEAD / BRAIN / LIVE INDEX"
	title.position = Vector2(42, 44)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("b8d98c"))
	add_child(title)
	var note := Label.new()
	note.text = "CURVED PHOSPHOR\nINSET IN CORTEX\n\nROTATE SPECIMEN\nTO READ THE BEND"
	note.position = Vector2(44, 92)
	note.add_theme_font_size_override("font_size", 17)
	note.add_theme_color_override("font_color", Color("8e6b4f"))
	add_child(note)
