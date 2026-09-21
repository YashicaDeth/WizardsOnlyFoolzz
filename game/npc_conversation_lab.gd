extends Node3D

## AI NPC Communication & Relationship System, "Tonight's Build Order", step 1:
## "Create one test room and one NPC with look-at behavior, interaction radius,
## subtitle label and relationship debug panel."
##
## This is that room. It exists so the conversation loop can be played and
## tuned without dragging the vat opening -- a scene with its own camera
## choreography and a form that owns the keyboard -- into every iteration.
##
## Voice input is typed here rather than spoken, and that is not a stand-in for
## the feature being absent: the spec's own step 4 is "display returned speech
## as subtitles before adding voice", precisely so the loop can be proven
## before a microphone or an API key is in the way. `VoiceInput` swaps in at
## the same seam later and nothing downstream changes.

const LOOK := preload("res://systems/world_look.gd")

## Section 6, the Doctor's character bible, as the definition the brain is
## given. Deliberately the same man who runs the vat intake -- he already has a
## voice in this game and a reason to be asking the player questions.
const DOCTOR := {
	"name": "THE EXAMINER",
	"identity": "An unnamed government examiner in a facility that grows people. Fifties to sixties. He believes what he does is rational and necessary, and he is not in a hurry.",
	"voice": "Australian male, 55-65. Low, dry, measured. Excellent diction. Controlled volume; he rarely needs to shout.",
	"rules": [
		"Never announce that you are evil, sinister, brilliant or frightening.",
		"When angry, become more precise rather than louder.",
		"Humour is dry and rare. You can sound almost paternal while saying something disturbing.",
		"You do not know anything the player has not said or done in front of you.",
	],
	"location": "the growing floor",
	"allies_nearby": 0,
}

const NPC_ID := "examiner_unknown"
const SPEED := 4.2
const EYE := 1.62

var player: CharacterBody3D
var camera: Camera3D
var doctor: NPCConversationComponent
var hud: NPCDebugHUD
var entry: LineEdit
var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = WorldLook.environment("ossuary")
	add_child(environment)
	_build_room()
	_build_player()
	_build_doctor()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_room() -> void:
	_slab(Vector3(20.0, 0.4, 20.0), Vector3(0, -0.2, 0), "dirt", Color("15120f"))
	_slab(Vector3(20.0, 0.35, 20.0), Vector3(0, 4.4, 0), "rust", Color("100d0b"))
	for side in [-1.0, 1.0]:
		_slab(Vector3(0.5, 4.6, 20.0), Vector3(side * 9.8, 2.2, 0), "rust", Color("1c1712"))
		_slab(Vector3(20.0, 4.6, 0.5), Vector3(0, 2.2, side * 9.8), "rust", Color("19140f"))
	for index in 4:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-5.0 + float(index % 2) * 10.0, 3.6, -5.0 + float(index / 2) * 10.0)
		lamp.light_color = Color("c0703a") if index % 2 == 0 else Color("7fbf95")
		lamp.light_energy = 2.4
		lamp.omni_range = 12.0
		add_child(lamp)
	# A floor ring at the interaction radius, so "attention acquired" is
	# something you can see yourself crossing rather than a number in the HUD.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.4
	torus.outer_radius = 4.55
	torus.material = WorldLook.surface(Color("4a3a22"), "bone", 3001)
	ring.mesh = torus
	ring.position = Vector3(0, 0.03, -3.0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	add_child(ring)


func _build_player() -> void:
	player = CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	player.position = Vector3(0, 0.85, 4.5)
	add_child(player)
	camera = Camera3D.new()
	camera.position = Vector3(0, EYE - 0.85, 0)
	camera.fov = 78.0
	player.add_child(camera)
	WorldHistory.register_subject("player", {"name": "THE HUNTER", "kind": "person"})


func _build_doctor() -> void:
	var rig := BaselineHuman.new()
	rig.build("examiner_rig", {"gore": false, "flesh": Color("6b5340")})
	var look := HunterAppearance.new()
	rig.add_child(look)
	look.configure(rig, {})

	doctor = NPCConversationComponent.new()
	doctor.name = "Examiner"
	doctor.position = Vector3(0, 0, -3.0)
	add_child(doctor)
	doctor.add_child(rig)
	doctor.configure(NPC_ID, DOCTOR, player)
	doctor.set_process(true)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 64
	add_child(layer)
	hud = NPCDebugHUD.new()
	layer.add_child(hud)
	hud.watch(doctor)

	entry = LineEdit.new()
	entry.placeholder_text = "hold V, type, press Enter"
	entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	entry.offset_left = 120.0
	entry.offset_right = -120.0
	entry.offset_top = -96.0
	entry.offset_bottom = -52.0
	entry.visible = false
	entry.text_submitted.connect(_on_said)
	layer.add_child(entry)

	var help := Label.new()
	help.text = "WASD MOVE   //   MOUSE LOOK   //   HOLD V TO SPEAK   //   ESC RELEASE MOUSE"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -34.0
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(help)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.4, 1.4)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and not entry.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Hold V. The same verb the spec asks for, standing in for push-to-talk:
	# press to open the channel, release to send what was captured.
	if event is InputEventKey and event.keycode == KEY_V and not event.echo:
		if event.pressed and not entry.visible:
			_open_channel()
		elif not event.pressed and entry.visible and entry.text.strip_edges().is_empty():
			_close_channel()


func _open_channel() -> void:
	entry.visible = true
	entry.text = ""
	entry.grab_focus()
	hud.listening = true
	hud.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_channel() -> void:
	entry.visible = false
	entry.release_focus()
	hud.listening = false
	hud.queue_redraw()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_said(text: String) -> void:
	var said := text.strip_edges()
	_close_channel()
	if said.is_empty():
		return
	var turn := doctor.hear(said)
	hud.note_turn({"transcript": said})
	if bool(turn.get("ok", false)):
		hud.note_turn(turn)
	else:
		# A refusal is shown rather than swallowed. "He did not think you were
		# talking to him" is a real answer and the HUD should say so.
		hud.intent = "(%s)" % str(turn.get("reason", "no reply"))
		hud.queue_redraw()


func _physics_process(delta: float) -> void:
	if entry.visible:
		return
	var input := Vector3(
		Input.get_axis("move_left", "move_right"), 0.0,
		Input.get_axis("move_forward", "move_back"),
	)
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x * SPEED, 16.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * SPEED, 16.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)


func _slab(dimensions: Vector3, at: Vector3, kind: String, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	box.material = WorldLook.surface(color, kind, int(at.x * 31.0 + at.z * 17.0))
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
