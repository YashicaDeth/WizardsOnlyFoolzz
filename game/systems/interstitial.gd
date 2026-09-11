extends CanvasLayer

## The seam cover. Every scene change in the game was a hard cut straight from
## one `.tscn` to another — the derby into the Hunt Grounds, the menu into the
## vat, the vat into the derby — which is most of why the game reads as a set of
## dev tools rather than one place. Greg asked for loading screens rather than
## seamlessness here, which is the right call: covering the swap costs nothing
## and buys a moment the world can talk during.
##
## Autoloaded, so it survives the change it is covering.
##
## The register is the one `ART-DIRECTION.md` already sets for interstitials:
## procedural anatomy drawn in code from the same primitives the dossier and the
## kill cam use. Nothing here is an imported asset.

signal arrived()

## Floor on how long the plate stays up, so a fast load does not flash. The
## upper bound is the load itself: the plate now waits on real progress from
## ResourceLoader rather than on a fixed timer that knew nothing.
const MIN_HOLD := 0.85
const FADE := 0.36

const VOID := Color("060b09")
const INK := Color("dce6ba")
const ACID := Color("b4da48")
const SPORE := Color("9bf01a")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")
const BRUISE := Color("6a2d6e")
const BONE := Color("ead4ad")

## Deadpan filler in the Postal 2 register: a machine doing paperwork about a
## body while the body waits. Picked per travel, never repeated back to back.
const MUTTERS := [
	"REGISTERING MEAT WITH THE DEPARTMENT OF ARRIVALS",
	"COUNTING YOUR RIBS AGAINST THE MANIFEST",
	"YOUR ORGANS HAVE BEEN NOTIFIED OF THE MOVE",
	"CHECKING WHETHER ANYONE MISSED YOU (NO)",
	"WARMING THE FLOOR SO IT KNOWS YOU ARE COMING",
	"ASKING THE PREVIOUS TENANT TO VACATE THE SPINE",
	"ROUNDING YOUR BLOOD DOWN TO THE NEAREST LITRE",
	"FILING A COMPLAINT ON YOUR BEHALF. IT WILL NOT BE READ",
]

var screen: Control
var travelling := false
var alpha := 0.0
var clock := 0.0
var caption := ""
var mutter := ""
var destination := ""
var progress := 0.0
var _last_mutter := -1


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	screen.name = "Plate"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.draw.connect(_draw_plate)
	add_child(screen)
	screen.visible = false


## Cover the screen, swap, hold, uncover. Callers await this and then stop
## touching the old scene, because by then it is gone.
func travel(scene_path: String, travel_caption: String = "") -> void:
	if travelling:
		return
	travelling = true
	destination = scene_path
	caption = travel_caption.to_upper()
	clock = 0.0
	var pick := randi() % MUTTERS.size()
	if pick == _last_mutter:
		pick = (pick + 1) % MUTTERS.size()
	_last_mutter = pick
	mutter = MUTTERS[pick]
	screen.visible = true

	var tree := get_tree()
	progress = 0.0
	# Start the load behind the fade, so the two overlap instead of queueing.
	var requested := ResourceLoader.load_threaded_request(scene_path) == OK
	await _fade(1.0)

	var held := 0.0
	var packed: PackedScene = null
	if requested:
		var steps: Array = []
		while true:
			var status := ResourceLoader.load_threaded_get_status(scene_path, steps)
			if not steps.is_empty():
				progress = clampf(float(steps[0]), 0.0, 1.0)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(scene_path)
				break
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Interstitial could not load %s (status %d)" % [scene_path, status])
				break
			await tree.process_frame
			held += tree.root.get_process_delta_time()
	progress = 1.0
	if packed != null:
		tree.change_scene_to_packed(packed)
	else:
		# Threaded loading is the fast path, not the only one: a failure here
		# must still put the player in the scene rather than stranding them on
		# a loading screen forever.
		var error := tree.change_scene_to_file(scene_path)
		if error != OK:
			push_error("Interstitial could not reach %s (%d)" % [scene_path, error])
	# The floor exists so a cached scene does not flash the plate for two frames.
	while held < MIN_HOLD:
		await tree.process_frame
		held += tree.root.get_process_delta_time()
	await _fade(0.0)
	screen.visible = false
	travelling = false
	arrived.emit()


## Raise the plate without changing scene. Used by the visual check, and by any
## caller that needs to cover a load happening in place rather than a swap.
func hold_open(plate_caption: String) -> void:
	caption = plate_caption.to_upper()
	mutter = MUTTERS[randi() % MUTTERS.size()]
	clock = 0.0
	progress = 0.0
	screen.visible = true
	await _fade(1.0)


func release() -> void:
	await _fade(0.0)
	screen.visible = false


func _fade(target: float) -> void:
	var tree := get_tree()
	while not is_equal_approx(alpha, target):
		alpha = move_toward(alpha, target, tree.root.get_process_delta_time() / FADE)
		await tree.process_frame


func _process(delta: float) -> void:
	if not screen.visible:
		return
	clock += delta
	screen.queue_redraw()


func _draw_plate() -> void:
	var size := screen.size
	if alpha <= 0.01 or size.x < 1.0:
		return
	var font := ThemeDB.fallback_font
	screen.draw_rect(Rect2(Vector2.ZERO, size), VOID * Color(1, 1, 1, alpha))

	var centre := Vector2(size.x * 0.5, size.y * 0.52)
	var scale := clampf(minf(size.x / 1280.0, size.y / 720.0), 0.5, 1.6) * 2.1
	_draw_specimen(centre, scale)

	# Scan banding over the whole plate, so the image reads as something being
	# transmitted rather than something being displayed.
	for row in range(0, int(size.y), 3):
		screen.draw_line(Vector2(0, row), Vector2(size.x, row), Color(0, 0, 0, 0.2 * alpha), 1.0)
	var sweep := fposmod(clock * 260.0, size.y + 200.0) - 100.0
	screen.draw_rect(Rect2(0, sweep, size.x, 46), SPORE * Color(1, 1, 1, 0.035 * alpha))

	screen.draw_string(font, Vector2(44, 54), "CELLOUTZ TRANSIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, ACID * Color(1, 1, 1, alpha))
	screen.draw_string(font, Vector2(44, 74), "SPECIMEN IN MOTION / DO NOT OPEN THE CASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK * Color(1, 1, 1, 0.45 * alpha))
	if not caption.is_empty():
		screen.draw_string(font, Vector2(44, size.y - 86), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 88, 22, INK * Color(1, 1, 1, alpha))
	screen.draw_string(font, Vector2(44, size.y - 58), mutter, HORIZONTAL_ALIGNMENT_LEFT, size.x - 88, 13, BILE * Color(1, 1, 1, 0.8 * alpha))

	# Real load progress, not a crawling barber pole. The bar used to know
	# nothing and say so; it now reports what ResourceLoader actually reports.
	var bar := Rect2(44, size.y - 42, size.x - 88, 6)
	screen.draw_rect(bar, Color(0, 0, 0, 0.5 * alpha))
	screen.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), ACID * Color(1, 1, 1, 0.8 * alpha))
	screen.draw_rect(bar, INK * Color(1, 1, 1, 0.18 * alpha), false, 1.0)
	screen.draw_string(font, Vector2(size.x - 92, size.y - 48), "%03d%%" % roundi(progress * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ACID * Color(1, 1, 1, 0.8 * alpha))


## The specimen: a skeleton turning on the spot with its organs lit in sequence.
## Drawn from the same body plan the dossier, the resolution form and the kill
## cam all use, so the anatomy the player sees here is the anatomy of the world.
func _draw_specimen(centre: Vector2, scale: float) -> void:
	var spin := sin(clock * 0.8)
	# Foreshortening from a fake Y-rotation: the whole plate squashes toward its
	# own axis, which is enough to read as turning without a 3D viewport.
	var squash := absf(spin) * 0.75 + 0.25
	var bone := BONE * Color(1, 1, 1, 0.8 * alpha)

	var point := func(x: float, y: float) -> Vector2:
		return centre + Vector2(x * squash * scale, y * scale)

	screen.draw_line(point.call(0, -58), point.call(0, 40), bone, 3.4 * scale)

	# Ribs as shallow paired sweeps off the spine, not as arcs centred on it.
	# A centred arc closes into a hoop once the body turns face-on, which is how
	# the first pass photographed as a scarecrow wearing barrels.
	for rib in 6:
		var y := -44.0 + rib * 12.5
		var span := 26.0 - absf(float(rib) - 1.5) * 2.6
		var drop := 7.0 + rib * 0.8
		for side in [-1.0, 1.0]:
			var curve := PackedVector2Array([
				point.call(0, y),
				point.call(side * span * 0.55, y + drop * 0.35),
				point.call(side * span, y + drop),
				point.call(side * span * 0.82, y + drop * 1.8),
			])
			screen.draw_polyline(curve, bone * Color(1, 1, 1, 1.0 if side < 0.0 else 0.82), 1.7 * scale)
	# Sternum, so the ribcage has a front to be seen from.
	screen.draw_line(point.call(0, -40), point.call(0, -4), bone * Color(1, 1, 1, 0.55), 2.4 * scale)

	# Skull with a jaw and an eye socket rather than two plain circles.
	screen.draw_arc(point.call(0, -88), 21.0 * scale * maxf(squash, 0.2), PI, TAU, 20, bone, 2.2 * scale)
	screen.draw_arc(point.call(0, -88), 21.0 * scale * maxf(squash, 0.2), 0.0, PI, 20, bone * Color(1, 1, 1, 0.75), 1.8 * scale)
	screen.draw_line(point.call(-12, -76), point.call(12, -76), bone * Color(1, 1, 1, 0.6), 1.8 * scale)
	for socket in [-8.0, 8.0]:
		screen.draw_arc(point.call(socket, -90), 5.0 * scale * maxf(squash, 0.25), 0.0, TAU, 12, VOID * Color(1, 1, 1, alpha), 3.0 * scale)
	screen.draw_line(point.call(0, -66), point.call(0, -58), bone, 2.6 * scale)

	# Clavicles and a pelvis, so the limbs hang off the skeleton instead of
	# floating beside it.
	for side in [-1.0, 1.0]:
		screen.draw_line(point.call(0, -54), point.call(side * 25, -48), bone * Color(1, 1, 1, 0.8), 2.0 * scale)
		screen.draw_line(point.call(0, 40), point.call(side * 17, 47), bone * Color(1, 1, 1, 0.85), 2.8 * scale)
		screen.draw_line(point.call(side * 17, 47), point.call(side * 13, 54), bone * Color(1, 1, 1, 0.85), 2.6 * scale)
		# Upper and lower arm, with an elbow, and the same for the leg.
		screen.draw_line(point.call(side * 25, -48), point.call(side * 38, -10), bone * Color(1, 1, 1, 0.72), 2.6 * scale)
		screen.draw_line(point.call(side * 38, -10), point.call(side * 45, 32), bone * Color(1, 1, 1, 0.72), 2.2 * scale)
		screen.draw_line(point.call(side * 13, 54), point.call(side * 17, 78), bone * Color(1, 1, 1, 0.72), 3.0 * scale)
		screen.draw_line(point.call(side * 17, 78), point.call(side * 20, 104), bone * Color(1, 1, 1, 0.72), 2.4 * scale)

	# Organs light one at a time and are named, which is the "trippy anatomy
	# screensaver" the roadmap asks for and doubles as a legend for the body the
	# rest of the game keeps talking about.
	var organs := [
		["BRAIN", Vector2(0, -86), 9.0, BRUISE],
		["LEFT LUNG", Vector2(-16, -29), 10.0, BRUISE],
		["RIGHT LUNG", Vector2(16, -29), 10.0, BRUISE],
		["HEART", Vector2(-3, -26), 8.0, ARTERIAL],
		["LIVER", Vector2(3, 13), 11.0, BILE],
		["GUT", Vector2(0, 35), 12.0, BILE],
	]
	var lit := int(clock * 1.6) % organs.size()
	for index in organs.size():
		var entry: Array = organs[index]
		var at: Vector2 = point.call((entry[1] as Vector2).x, (entry[1] as Vector2).y)
		var radius: float = float(entry[2]) * scale * maxf(squash, 0.25)
		var tint: Color = entry[3]
		if index == lit:
			var throb := 0.5 + 0.5 * sin(clock * 7.0)
			screen.draw_circle(at, radius * (1.0 + throb * 0.22), tint * Color(1, 1, 1, 0.85 * alpha))
			screen.draw_arc(at, radius * 2.1 + throb * 5.0, 0.0, TAU, 20, tint * Color(1, 1, 1, 0.4 * alpha), 1.4)
			var label_at := centre + Vector2(120.0 * scale, (entry[1] as Vector2).y * scale)
			screen.draw_line(at, label_at - Vector2(6, 4), tint * Color(1, 1, 1, 0.4 * alpha), 1.0)
			screen.draw_string(ThemeDB.fallback_font, label_at, str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * scale * 0.5) + 8, tint * Color(1, 1, 1, alpha))
		else:
			screen.draw_arc(at, radius, 0.0, TAU, 14, tint * Color(1, 1, 1, 0.28 * alpha), 1.2)
