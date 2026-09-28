class_name ThermalPrint
extends ColorRect

## A rect that re-prints whatever is drawn under it on paper (item 5, Greg
## 2026-09-24). Put one over a surface's panel, set `stock`, keep `rect_size`
## in step with its size, and the surface reads as a receipt, a flyer, a card
## or a tractor-feed printout. The shader is thermal_print.gdshader.

const SHADER := preload("res://shaders/thermal_print.gdshader")
const STOCKS := {"register": 0, "flyer": 1, "card": 2, "feed": 3}


static func make(stock_name: String) -> ThermalPrint:
	var paper := ThermalPrint.new()
	paper.name = "ThermalPrint_" + stock_name
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_value := ShaderMaterial.new()
	material_value.shader = SHADER
	material_value.set_shader_parameter("stock", int(STOCKS.get(stock_name, 0)))
	paper.material = material_value
	paper.resized.connect(paper._sync)
	return paper


## Places the paper over `rect` (in its parent's coordinates) and shows it.
func cover(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	visible = true
	_sync()


func _sync() -> void:
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
