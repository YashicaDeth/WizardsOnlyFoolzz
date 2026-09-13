class_name SatelliteView
extends SubViewport

## A10. The map, as the world seen from above.
##
## Greg: *"make the map an inbuilt satellite transferring from topview somewhat
## 3d with showing the maps color and what it looks like, then make it
## transferable into streetview"* — and the part that turns it from a renderer
## into a mechanic: *"going from grey and discoloured and foggy to when you walk
## around colored and explored"*.
##
## A6 built a survey **chart**: drawn, stencilled, and honest about being a
## drawing. This is the other thing a map can be, and the two are not in
## competition — the chart's marks, roads and contacts still draw on top. What
## changes is what they draw on top *of*: the actual region, in its own
## materials, instead of a dark plate.
##
## The whole thing is one camera in the scene the player is standing in, so
## there is no second copy of the world to keep in step. Zooming does not scale
## a picture; it flies the camera down. Past a threshold it tilts, and the map
## becomes street level — which is why there is no separate street view mode.
## It is the same camera at the bottom of its own descent.

## How high the camera sits at each end of the zoom. The top is high enough to
## hold a district, the bottom is eye height for a standing body — the same
## 1.68m the player's own camera uses, so arriving at the bottom of the zoom
## looks like standing there.
const TOP_HEIGHT := 210.0
const STREET_HEIGHT := 1.68

## Where the tilt starts. Above this the camera looks straight down; below it,
## it rolls forward until it is looking at the horizon.
const TILT_BEGINS := 0.55

var camera: Camera3D
var clock := 0.0

## 0 = all the way up, looking down. 1 = standing in the street.
var descent := 0.0
var heading := 0.0
var centre := Vector3.ZERO
var _air_settled := false
var _framed_aspect := 0.0


## 576 square rather than 768. The map draws it into a rectangle roughly a
## thousand pixels wide and then covers a good part of it with chart marks, so
## the extra 77% of pixels was buying nothing and costing a full extra render of
## the region every time it was asked for.
static func make(world: World3D, resolution := Vector2i(576, 576)) -> SatelliteView:
	var view := SatelliteView.new()
	view.size = resolution
	view.transparent_bg = false
	# A10.8. Nothing renders until somebody asks for a frame. A satellite that
	# runs while the map is shut is a second render of the whole region, every
	# frame, for nobody.
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# The player's own world, not a copy: one region, one set of bodies, one
	# truth about where everything is.
	view.world_3d = world
	view.own_world_3d = false
	view._assemble()
	return view


func _assemble() -> void:
	camera = Camera3D.new()
	camera.name = "SatelliteCamera"
	camera.fov = 62.0
	camera.far = 2200.0
	# Not `current`: this camera belongs to its own viewport and must never
	# steal the one the player is looking through.
	add_child(camera)
	_clear_the_air()


## A10.4. The Ashbloom is a foggy place at head height, which is correct and is
## most of how it looks. From two hundred metres up it means the entire region
## is inside the fog and the satellite returns a flat grey sheet — which is what
## the second playtest actually showed: *"sort of? I can tell theres somthing
## behind it"*. There was something behind it; it was fog.
##
## A camera can carry its own `Environment`, which overrides the world's for
## that camera alone. So the satellite gets the same sky, the same ambient and
## the same tone mapping as the region — and no fog, because it is above it.
## Nothing about how the player sees the world at ground level changes.
func _clear_the_air() -> void:
	var world_environment: Environment = null
	if world_3d != null and world_3d.environment != null:
		world_environment = world_3d.environment
	var air: Environment = world_environment.duplicate() if world_environment != null else Environment.new()
	air.fog_enabled = false
	air.volumetric_fog_enabled = false
	if world_environment == null:
		air.background_mode = Environment.BG_COLOR
		air.background_color = Color("1a1712")
		air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		air.ambient_light_color = Color("6d6a58")
		air.ambient_light_energy = 1.0
	else:
		# Lift the ambient a little. Overhead light on a region built to be lit
		# from the side leaves the roofs correct and the streets between them
		# unreadably dark, and a satellite picture whose streets are black is
		# not a map.
		air.ambient_light_energy = maxf(air.ambient_light_energy, 0.9)
	camera.environment = air


## Called by the map each frame it is open. `at` is where the player is standing,
## `look` is the direction they are facing, and `zoom` is 0..1 from the map's own
## control — so the map keeps owning the input and this owns the geometry.
func observe(at: Vector3, look: float, zoom: float, delta: float, span := Vector2.ZERO) -> void:
	clock += delta
	centre = at
	heading = look
	descent = clampf(zoom, 0.0, 1.0)
	if camera == null or not is_instance_valid(camera):
		return
	# The scene builds its own WorldEnvironment during `_ready`, which is often
	# after this view was made, so the air is settled on first look rather than
	# at construction.
	if camera.environment == null or not _air_settled:
		_clear_the_air()
		_air_settled = world_3d != null and world_3d.environment != null

	var height := lerpf(TOP_HEIGHT, STREET_HEIGHT, ease(descent, 2.2))
	# A map is only a map if the photograph is at the chart's scale. When the
	# chart says how much ground it is claiming, the camera frames exactly that
	# instead of an unrelated 252m square: `fov` is the vertical angle under
	# Godot's default KEEP_HEIGHT, so the vertical span fixes the height and the
	# viewport's own aspect carries the horizontal.
	if span.x > 1.0 and span.y > 1.0:
		_frame_chart(span)
		var fitted := (span.y * 0.5) / tan(deg_to_rad(camera.fov) * 0.5)
		if descent <= TILT_BEGINS:
			height = fitted
		else:
			# Past the tilt this stops being a chart and becomes a place, so the
			# descent to eye height takes back over from the fit.
			height = lerpf(fitted, STREET_HEIGHT, ease(inverse_lerp(TILT_BEGINS, 1.0, descent), 2.2))
	# A10.3. The tilt is the transition. Straight down until the camera is low
	# enough for a roof to have a side, then it rolls forward to the horizon —
	# which is what makes "somewhat 3D" arrive on its own rather than being a
	# separate view the player has to ask for.
	var tilt := 0.0
	if descent > TILT_BEGINS:
		tilt = inverse_lerp(TILT_BEGINS, 1.0, descent)
	var pitch := lerpf(-90.0, -4.0, ease(tilt, 1.6))

	# Backed off along the facing as it tilts, so the player's own position stays
	# in frame rather than sliding under the camera.
	var facing := Vector3(sin(heading), 0.0, cos(heading))
	var back := facing * lerpf(0.0, 6.0, tilt)
	camera.global_position = Vector3(at.x, 0.0, at.z) - back + Vector3.UP * height
	camera.rotation = Vector3(deg_to_rad(pitch), heading, 0.0)


## The photograph is drawn into the chart's rectangle, so a square render was
## being stretched to fit it and every distance in the picture came out wrong
## along one axis. Matched to the chart's aspect instead, at about the pixel
## count the square one cost, and only when the aspect has actually moved —
## resizing a render target is not a per-frame thing to do.
const RENDER_PIXELS := 576.0 * 576.0


func _frame_chart(span: Vector2) -> void:
	var aspect := clampf(span.x / span.y, 0.25, 4.0)
	if absf(aspect - _framed_aspect) < 0.01:
		return
	_framed_aspect = aspect
	var render_height := sqrt(RENDER_PIXELS / aspect)
	size = Vector2i(int(roundf(render_height * aspect)), int(roundf(render_height)))


## A10.8. One frame, on request. The map calls this while it is open and stops
## calling it when it closes, and the viewport costs nothing in between.
func request_frame() -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE


func sleep() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED


## A10.5. How much colour a piece of ground has earned. Unwalked ground is grey,
## discoloured and fogged; walking it brings the colour in. Returned rather than
## applied, so the map can decide how to paint it — this class knows about
## geometry, not about the survey.
static func reveal_tint(surveyed: bool, neighbours: int) -> Color:
	if surveyed:
		return Color(1, 1, 1, 1)
	# Ground next to somewhere you have walked is half-known: you have seen it
	# from where you stood, without having stood in it.
	var edge := clampf(float(neighbours) / 4.0, 0.0, 1.0)
	var grey := lerpf(0.16, 0.52, edge)
	return Color(grey, grey * 1.04, grey * 0.92, 1.0)
