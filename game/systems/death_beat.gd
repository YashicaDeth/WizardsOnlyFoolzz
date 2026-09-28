class_name DeathBeat
extends CanvasLayer

## Greg's playtest: dying cut straight to a loading plate, so you did not know
## you had died, what did it, or what happens now. Every facility death now
## plays this first: you go down (the view drops and rolls), red to black, a
## sound, then three lines -- YOU DIED, what killed you, what happens next --
## and only then the trip back to the vat.

const SECONDS := 3.2
const FALL_SECONDS := 0.9
const BLOOD := Color(0.55, 0.02, 0.02)

var cause := ""
var next_line := ""
var scene := ""
var clock := 0.0
var _camera: Camera3D
var _camera_start := Transform3D.IDENTITY
var _canvas: Control
var _travelled := false


## Plays the beat over `host`'s scene, then sends the player to `request.scene`.
static func play(host: Node, request: Dictionary, cause_text: String) -> CanvasLayer:
	var beat = load("res://systems/death_beat.gd").new()
	beat.cause = cause_text.to_upper()
	var vat_label := str(request.get("vat", {}).get("label", "a vat")).to_upper()
	beat.next_line = "%s GROWS YOU BACK" % vat_label
	beat.scene = str(request.get("scene", ""))
	host.add_child(beat)
	return beat


func _ready() -> void:
	name = "DeathBeat"
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = get_viewport().get_camera_3d()
	if _camera != null:
		_camera_start = _camera.transform
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_beat)
	add_child(_canvas)
	var sound := AudioStreamPlayer.new()
	var maker = TortureLoadIn.new()
	sound.stream = maker._wave("gag", 1.1, false)
	maker.free()
	sound.volume_db = -4.0
	add_child(sound)
	sound.play()


func _process(delta: float) -> void:
	clock += delta
	# Going down: the view drops toward the floor and rolls onto its side.
	if _camera != null and is_instance_valid(_camera):
		var fall := ease(clampf(clock / FALL_SECONDS, 0.0, 1.0), 2.2)
		_camera.transform = _camera_start
		_camera.position.y -= 1.1 * fall
		_camera.rotate_object_local(Vector3.FORWARD, 1.2 * fall)
		_camera.rotate_object_local(Vector3.RIGHT, -0.35 * fall)
	_canvas.queue_redraw()
	if clock >= SECONDS and not _travelled:
		_travelled = true
		if OS.get_environment("ATG_TEST_MODE") != "1" and not scene.is_empty():
			Interstitial.travel(scene, "you died // back to the vat")


func _draw_beat() -> void:
	var area := Rect2(Vector2.ZERO, _canvas.size)
	# A red hit, then the black comes in over it.
	var red := clampf(1.0 - clock / 0.6, 0.0, 1.0)
	var black := clampf((clock - 0.3) / 1.0, 0.0, 0.92)
	_canvas.draw_rect(area, Color(BLOOD, 0.55 * red))
	_canvas.draw_rect(area, Color(0, 0, 0, black))
	var centre_y := _canvas.size.y * 0.42
	for line in [[1.0, "YOU DIED", 54.0, Color("d8c7a8")], [1.6, cause, 22.0, Color("c0392b")], [2.2, next_line, 18.0, Color("9c9480")], [2.4, "WHAT YOU CARRIED STAYS ON THIS BODY", 16.0, Color("9c9480")]]:
		var alpha := clampf((clock - float(line[0])) / 0.4, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var text: String = line[1]
		var height: float = line[2]
		var width := CellOutzType.width(text, height, 2.0)
		if width > _canvas.size.x * 0.9:
			height *= _canvas.size.x * 0.9 / width
			width = CellOutzType.width(text, height, 2.0)
		CellOutzType.draw_text(_canvas, Vector2((_canvas.size.x - width) * 0.5, centre_y), text, height, Color(line[3], alpha), 2.0)
		centre_y += height * 2.2
