class_name FieldLens
extends ColorRect

## The permanent, very slight bow in the field view. Kept separate from the
## psychedelic rig: this is the glass/costume framing the ordinary world, not a
## drug effect, and resetting a substance must never flatten it.

const FIELD_SHADER := preload("res://shaders/field_lens.gdshader")

var curvature := 0.024
var edge_weight := 0.18
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	_material = ShaderMaterial.new()
	_material.shader = FIELD_SHADER
	material = _material
	_push()


func _push() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("curvature", curvature)
	_material.set_shader_parameter("edge_weight", edge_weight)


func treatment() -> Dictionary:
	return {"curvature": curvature, "edge_weight": edge_weight}
