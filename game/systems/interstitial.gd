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

## The plate used to be lit acid-green, which put the one screen standing
## between every two places in the game into a register nothing else in it
## uses — the hunt is rust and sodium, the dossier is paper and red stamp ink,
## and what this screen is actually about is a body in transit. Green read as
## sci-fi telemetry. It is blood now: the rain, the readout and the light
## coming through the specimen are all arterial, the ground is a warm
## near-black rather than a cold one, and BILE survives as the single
## non-red note so the mutter line still separates from what is behind it.
const VOID := Color("0a0504")
const INK := Color("e9d5c6")
## The hot readout: the title stamp, the progress bar, the percentage.
const HOT := Color("e0442a")
## What the plate transmits in — the rain, the sweep, the halation through the
## body. Darker than HOT, so a screen full of it never competes with the few
## things on the plate that are meant to be read.
const HAEM := Color("b3231b")
const ARTERIAL := Color("c81f16")
## Stamp shadows. Was ARTERIAL, which was only legible while the foreground was
## green; a red shadow under a red foreground is a blur, so the offset copy is
## the near-black the plate is already drawn on.
const SHADOW := Color("2a0806")
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
## AR. The seal belongs to the place you are going, not to the loading screen:
## seeded off the destination path, so the same door always draws the same
## sigil and two different doors never draw the same one. Re-seeded in `travel`
## and `hold_open` rather than randomised per frame, because a mark that
## reshuffles while you look at it is a noise effect, not a mark.
var _seal_seed := 0
## Blood on the glass of the transit plate. Built once at the first size the
## screen reports and then left alone — a runnel that re-randomises every frame
## is the same failure the handheld's cracks were fixed for.
var _runnels: Array = []
## The 3D scan. Built on the first cover and kept, because rebuilding a rig per
## transition is exactly the hitch a loading screen exists to hide.
var _specimen: XraySpecimen = null
var _rain: Array = []
## The seam wipe (`TransitionKit`). Null falls back to the plain alpha fade.
var wipe: TransitionKit = null

## P1.1/P2.4. `OpeningDirector.advance()` had no caller anywhere in real
## gameplay — only in tests — so `stage()` never left "none" and
## `resume_destination()` always sent a resumed run back to the Growing
## Floor, however far it had actually gotten. Every forward step of the
## opening (`vat_chamber` -> `rift_derby` -> `bone_yard_hunt`) already
## travels through this one chokepoint, so the stage is recorded on arrival
## here rather than reaching into three other lanes' scenes to call it from
## each of them. `bone_yard_hunt.tscn` is the arrival for a lost heat as well
## as a won one (`rift_derby.gd::_leave_derby` sends both there — O10.12,
## losing is not dying) — `won_derby` marks "the pit is behind you", which is
## what `resume_destination()` actually needs, not literal victory.
const STAGE_ON_ARRIVAL := {
	"res://vat_chamber.tscn": "woke",
	# The arcade sits between the vat and the pit. `vat_chamber.gd` also
	# advances this stage on its way out, and `advance()` is write-once, so the
	# two cannot disagree -- but the whole point of this table is that arriving
	# somewhere records it, rather than every departing scene remembering to.
	# Without the entry, a second route into the arcade would record nothing and
	# a resume would drop the player back in the vat they already escaped.
	"res://service_arcade.tscn": "entered_arcade",
	"res://buried_city.tscn": "entered_lower_works",
	"res://rift_derby.tscn": "entered_pit",
	"res://underground_colosseum.tscn": "entered_pit",
	"res://bone_yard_hunt.tscn": "won_derby",
}


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
	wipe = TransitionKit.new()
	wipe.name = "Wipe"
	add_child(wipe)


func _ensure_specimen() -> void:
	if _specimen != null and is_instance_valid(_specimen):
		return
	_specimen = XraySpecimen.make(randi())
	add_child(_specimen)


## Cover the screen, swap, hold, uncover. Callers await this and then stop
## touching the old scene, because by then it is gone.
func travel(scene_path: String, travel_caption: String = "") -> void:
	if travelling:
		return
	_ensure_specimen()
	travelling = true
	destination = scene_path
	caption = travel_caption.to_upper()
	clock = 0.0
	_seal_seed = hash(scene_path)
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
	var reached := false
	if packed != null:
		tree.change_scene_to_packed(packed)
		reached = true
	else:
		# Threaded loading is the fast path, not the only one: a failure here
		# must still put the player in the scene rather than stranding them on
		# a loading screen forever.
		var error := tree.change_scene_to_file(scene_path)
		if error != OK:
			push_error("Interstitial could not reach %s (%d)" % [scene_path, error])
		else:
			reached = true
	if reached and STAGE_ON_ARRIVAL.has(scene_path):
		OpeningDirector.advance(str(STAGE_ON_ARRIVAL[scene_path]))
	await tree.process_frame
	BaselineHuman.restore_blood(tree.current_scene)
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
	_ensure_specimen()
	caption = plate_caption.to_upper()
	mutter = MUTTERS[randi() % MUTTERS.size()]
	clock = 0.0
	_seal_seed = hash(plate_caption)
	progress = 0.0
	screen.visible = true
	await _fade(1.0)


func release() -> void:
	await _fade(0.0)
	screen.visible = false


## A seam with nothing to load and nothing to say: the wipe covers, the scene
## swaps behind it, the wipe opens. No transit plate — for the splash into the
## menu, where a loading screen would be a pause pretending to be content.
func wipe_to(scene_path: String) -> void:
	if travelling:
		return
	travelling = true
	var tree := get_tree()
	if wipe != null:
		wipe.set_style(hash(scene_path))
		await wipe.cover()
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error("Interstitial could not reach %s (%d)" % [scene_path, error])
	await tree.process_frame
	if wipe != null:
		await wipe.reveal()
	travelling = false
	arrived.emit()


## Every seam in the game passes through here, so this is where the wipe lives:
## cover the old frame, flip the plate underneath, uncover. The style is seeded
## off the destination, so the same door always opens the same way.
func _fade(target: float) -> void:
	var tree := get_tree()
	if wipe != null:
		wipe.set_style(_seal_seed)
		await wipe.cover()
		alpha = target
		await wipe.reveal()
		return
	while not is_equal_approx(alpha, target):
		alpha = move_toward(alpha, target, tree.root.get_process_delta_time() / FADE)
		await tree.process_frame


func _process(delta: float) -> void:
	if _specimen != null and is_instance_valid(_specimen):
		if alpha > 0.01:
			_specimen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			_specimen.advance(delta)
		else:
			# Nothing is looking at it between transitions.
			_specimen.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not _rain.is_empty() and alpha > 0.01:
		CodeRain.advance(_rain, delta, screen.size.y)
	if not screen.visible:
		return
	clock += delta
	screen.queue_redraw()


func _draw_plate() -> void:
	var size := screen.size
	if alpha <= 0.01 or size.x < 1.0:
		return
	screen.draw_rect(Rect2(Vector2.ZERO, size), VOID * Color(1, 1, 1, alpha))

	# Behind the body, because the body is arriving *through* it. The seal is
	# the loudest thing on the plate and the specimen still has to be readable
	# over it, which is the whole reason it is drawn first and dim rather than
	# over the top at full strength.
	_draw_seal(Vector2(size.x * 0.5, size.y * 0.47), minf(size.x, size.y) * 0.42)

	# The scan itself, composited large and centred. Drawn additively over the
	# void so the film reads as light coming through a body rather than as a
	# picture of one pasted on black.
	if _specimen != null and is_instance_valid(_specimen):
		var texture := _specimen.get_texture()
		if texture != null:
			var span := minf(size.x, size.y) * 1.02
			var frame := Rect2(Vector2(size.x * 0.5 - span * 0.5, size.y * 0.47 - span * 0.5), Vector2(span, span))
			screen.draw_texture_rect(texture, frame, false, Color(1, 1, 1, alpha))
			# A second pass, offset and dimmer: the film's own halation, which
			# is what stops a rendered mesh looking like a rendered mesh.
			screen.draw_texture_rect(texture, frame.grow(6.0), false, HAEM * Color(1, 1, 1, 0.22 * alpha))

	# I1. The rain falls behind the readout and through the specimen, so the
	# body is being *transmitted*. Holes are punched for everything printed.
	if _rain.is_empty() and size.x > 1.0:
		_rain = CodeRain.build(size.x, size.y, 34.0, 6101)
	CodeRain.draw_field(screen, Rect2(Vector2.ZERO, size), _rain, HAEM * Color(1, 1, 1, alpha), 0.0, clock, [
		Rect2(30, 24, 520, 66),
		Rect2(30, size.y - 100, size.x - 60, 76),
	])

	# Scan banding over the whole plate, so the image reads as something being
	# transmitted rather than something being displayed.
	for row in range(0, int(size.y), 3):
		screen.draw_line(Vector2(0, row), Vector2(size.x, row), Color(0, 0, 0, 0.2 * alpha), 1.0)
	var sweep := fposmod(clock * 260.0, size.y + 200.0) - 100.0
	screen.draw_rect(Rect2(0, sweep, size.x, 46), HAEM * Color(1, 1, 1, 0.05 * alpha))

	# Gore on the glass. Over the transmission and under the readout, because
	# the readout is printed on the far side of the pane from whatever ran down
	# this one.
	_draw_runnels(size)

	CellOutzType.draw_stamped(screen, Vector2(44, 36), "CELLOUTZ TRANSIT", 20.0, HOT * Color(1, 1, 1, alpha), SHADOW * Color(1, 1, 1, 0.75 * alpha), 3.2)
	CellOutzType.draw_condensed(screen, Vector2(44, 64), "SPECIMEN IN MOTION / DO NOT OPEN THE CASE", 9.0, INK * Color(1, 1, 1, 0.45 * alpha), 0.8)
	if not caption.is_empty():
		CellOutzType.draw_stamped(screen, Vector2(44, size.y - 104), caption, 18.0, INK * Color(1, 1, 1, alpha), SHADOW * Color(1, 1, 1, 0.7 * alpha), 1.6)
	CellOutzType.draw_condensed(screen, Vector2(44, size.y - 68), mutter, 10.0, BILE * Color(1, 1, 1, 0.8 * alpha), 0.8)

	# Real load progress, not a crawling barber pole. The bar used to know
	# nothing and say so; it now reports what ResourceLoader actually reports.
	var bar := Rect2(44, size.y - 42, size.x - 88, 6)
	screen.draw_rect(bar, Color(0, 0, 0, 0.5 * alpha))
	screen.draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), HOT * Color(1, 1, 1, 0.9 * alpha))
	screen.draw_rect(bar, INK * Color(1, 1, 1, 0.18 * alpha), false, 1.0)
	CellOutzType.draw_condensed(screen, Vector2(size.x - 92, size.y - 58), "%03d%%" % roundi(progress * 100.0), 10.0, HOT * Color(1, 1, 1, 0.9 * alpha), 0.9)


## The seal of the place you are arriving at.
##
## A goetic seal is a ring, a set of points bound to that ring, and a single
## unbroken figure walking between them — so that is what this builds, rather
## than a texture of one. `_seal_seed` picks how many points and the stride the
## figure walks them in, which is the whole of why two destinations look
## nothing alike: a 13-point ring walked 5 at a time and an 11-point ring
## walked 4 at a time are different marks, not the same mark recoloured.
##
## Drawn as three passes of the same path — a wide dim bleed, the line itself,
## and a node at every vertex — because one flat polyline reads as a diagram
## and this is meant to read as something burnt onto the plate.
func _draw_seal(centre: Vector2, radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seal_seed
	# Odd point counts only. An even ring walked at any stride closes early and
	# leaves a figure that is two overlapping shapes instead of one continuous
	# one, which is exactly the thing a seal is not allowed to be.
	var sizes: Array[int] = [9, 11, 13, 15, 17]
	var points: int = sizes[rng.randi() % sizes.size()]
	# Coprime with `points` by construction, so the walk visits every vertex
	# before it returns to the one it started on.
	var stride: int = 2 + rng.randi() % int((points - 1) / 2.0 - 1.0)
	while points % stride == 0:
		stride += 1
	var spin := clock * 0.16
	var breath := 1.0 + sin(clock * 0.9) * 0.015

	var vertex := func(index: int) -> Vector2:
		var angle := spin - PI * 0.5 + TAU * float(index % points) / float(points)
		return centre + Vector2(cos(angle), sin(angle)) * radius * breath

	# The ring, and a second one inside it that the vertices actually sit on.
	for band in [[1.0, 1.6, 0.5], [0.965, 1.0, 0.3], [0.62, 1.0, 0.22]]:
		screen.draw_arc(centre, radius * breath * float(band[0]), 0.0, TAU, 96,
			HAEM * Color(1, 1, 1, float(band[2]) * alpha), float(band[1]))

	# Teeth around the outside, so the ring has a direction and a count.
	for index: int in points * 3:
		var angle := spin - PI * 0.5 + TAU * float(index) / float(points * 3)
		var out := Vector2(cos(angle), sin(angle))
		var long: bool = index % 3 == 0
		screen.draw_line(centre + out * radius * breath,
			centre + out * radius * breath * (1.055 if long else 1.025),
			HAEM * Color(1, 1, 1, (0.55 if long else 0.28) * alpha), 1.8 if long else 1.0)

	# The figure. One unbroken walk, closed back onto its first point.
	var path := PackedVector2Array()
	for step: int in points + 1:
		path.append(vertex.call(step * stride))
	screen.draw_polyline(path, ARTERIAL * Color(1, 1, 1, 0.20 * alpha), 11.0)
	screen.draw_polyline(path, HOT * Color(1, 1, 1, 0.62 * alpha), 2.0)

	# A node on every vertex, and a stroke out to the ring from each — the part
	# that makes it look bound to the circle rather than drawn inside it.
	for index: int in points:
		var at: Vector2 = vertex.call(index)
		screen.draw_circle(at, 3.4, HOT * Color(1, 1, 1, 0.7 * alpha))
		screen.draw_circle(at, 1.5, INK * Color(1, 1, 1, 0.55 * alpha))
		var out := (at - centre).normalized()
		screen.draw_line(at, centre + out * radius * breath * 0.965,
			HAEM * Color(1, 1, 1, 0.35 * alpha), 1.0)


## Blood running down the inside of the transit plate.
##
## Seeded once per screen size rather than per frame: a runnel is a thing that
## happened, and one that redraws itself somewhere else every frame is weather.
## Each is a head, a tail that thins behind it, and a bead at the bottom, and
## they crawl rather than fall — the plate is vertical glass, not open air.
func _draw_runnels(size: Vector2) -> void:
	if _runnels.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4477
		for index in 14:
			_runnels.append({
				"x": rng.randf(),
				"from": rng.randf_range(-0.25, 0.35),
				"length": rng.randf_range(0.10, 0.46),
				"width": rng.randf_range(1.4, 5.2),
				"speed": rng.randf_range(0.006, 0.028),
				"alpha": rng.randf_range(0.25, 0.8),
			})
	for runnel: Dictionary in _runnels:
		var x: float = float(runnel["x"]) * size.x
		# Creeps and then stops, so the plate is not an endless drip loop.
		var reach: float = float(runnel["length"]) * (1.0 - exp(-clock * float(runnel["speed"]) * 40.0))
		var top: float = float(runnel["from"]) * size.y
		var bottom: float = top + reach * size.y
		if bottom <= 0.0:
			continue
		var width: float = float(runnel["width"])
		var tint: float = float(runnel["alpha"]) * alpha
		# The tail: thinner and dimmer the further it is from the head, drawn as
		# a few segments rather than one line so it actually tapers.
		for segment in 5:
			var t0 := float(segment) / 5.0
			var t1 := float(segment + 1) / 5.0
			screen.draw_line(
				Vector2(x, lerpf(maxf(top, 0.0), bottom, t0)),
				Vector2(x, lerpf(maxf(top, 0.0), bottom, t1)),
				ARTERIAL * Color(1, 1, 1, tint * lerpf(0.25, 1.0, t1)),
				width * lerpf(0.35, 1.0, t1))
		# The bead at the head of the run, which is where the mass ends up.
		screen.draw_circle(Vector2(x, bottom), width * 0.85, ARTERIAL * Color(1, 1, 1, tint))
		screen.draw_circle(Vector2(x - width * 0.25, bottom - width * 0.2), width * 0.3,
			HOT * Color(1, 1, 1, tint * 0.5))


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
			# A1.3. Organ callouts are stamps on a transit plate, so they are set
			# in the display face rather than in the engine default.
			CellOutzType.draw_text(screen, label_at - Vector2(0, 6.0 * scale * 0.5), str(entry[0]), 12.0 * scale * 0.5 + 4.0, tint * Color(1, 1, 1, alpha), 1.0)
		else:
			screen.draw_arc(at, radius, 0.0, TAU, 14, tint * Color(1, 1, 1, 0.28 * alpha), 1.2)
