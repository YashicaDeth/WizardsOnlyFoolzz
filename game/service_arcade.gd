extends Node3D

## THE SERVICE ARCADE — the first real district after the Growing Floor.
## A short, original hub-and-spoke slice: the vat corridor opens into a tall
## service artery, the player retrieves one access card, opens one pressure
## gate, and reaches the pit.  It replaces the old immediate car handoff with
## a readable piece of facility geography.

const OPENING := preload("res://systems/opening_director.gd")
const FACILITY_TERRITORY := preload("res://systems/facility_territory.gd")
const ENTRY := Vector3(0, 1.0, 4.0)
const CARD_AT := Vector3(-3.8, 0.95, -20.0)
const WEAPON_AT := Vector3(3.8, 0.78, -11.5)
const GATE_AT := Vector3(0, 0.0, -48.0)
const EXIT_AT := Vector3(0, 0.0, -55.0)

var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.04
var card_taken := false
var gate_open := false
var gate_body: StaticBody3D
var gate_panel: Node3D
var card_visual: MeshInstance3D
var card_beacon: OmniLight3D
var card_label: Label3D
var weapon_taken := false
var weapon_visual: Node3D
var weapon_label: Label3D
var lower_works_requested := false

@onready var objective: Label = $HUD/Objective
@onready var prompt: Label = $HUD/Prompt
@onready var vitals: Label = $HUD/Vitals

func _ready() -> void:
	$WorldEnvironment.environment = WorldLook.environment("ossuary")
	_build_shell()
	_build_landmarks()
	_build_player()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = ENTRY
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	camera = Camera3D.new()
	camera.fov = 88.0
	camera.position.y = 0.77
	player.add_child(camera)
	LabSurface.attach_body_cam(camera)

func _build_shell() -> void:
	# Collision is intentionally simpler than dressing: one stable floor and
	# sidewalls under every arch means no void falls or physics caught on pipes.
	_slab(Vector3(15.0, 0.4, 66.0), Vector3(0, -0.2, -27.0), "dirt", Color("171410"))
	_slab(Vector3(15.0, 0.35, 66.0), Vector3(0, 8.0, -27.0), "rust", Color("100d0b"))
	_slab(Vector3(0.45, 8.2, 66.0), Vector3(-7.25, 4.0, -27.0), "rust", Color("211a15"))
	_slab(Vector3(0.45, 8.2, 66.0), Vector3(7.25, 4.0, -27.0), "rust", Color("211a15"))
	_slab(Vector3(15.0, 8.2, 0.45), Vector3(0, 4.0, 5.5), "rust", Color("211a15"))
	_slab(Vector3(15.0, 8.2, 0.45), Vector3(0, 4.0, -58.5), "rust", Color("211a15"))
	for bay in 13:
		var z := 2.5 - float(bay) * 4.5
		_build_arch(z, bay)
		if bay % 2 == 0:
			_build_side_lab(z - 1.2, bay)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 6.7, z)
		light.light_color = Color("b64027") if bay % 3 else Color("77924f")
		light.light_energy = 2.2
		light.omni_range = 8.5
		add_child(light)

func _build_arch(z: float, _index: int) -> void:
	# Two tall piers plus a raised beam read as a vault from the playable floor;
	# the beam is decoration so it cannot snag the player.
	for side in [-1.0, 1.0]:
		var pier := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, 5.5, 0.55)
		mesh.material = LabSurface.material("grime")
		pier.mesh = mesh
		pier.position = Vector3(side * 5.85, 2.75, z)
		add_child(pier)
	var lintel := MeshInstance3D.new()
	var top := BoxMesh.new()
	top.size = Vector3(12.2, 0.52, 0.55)
	top.material = LabSurface.material("plate")
	lintel.mesh = top
	lintel.position = Vector3(0, 5.45, z)
	add_child(lintel)

func _build_side_lab(z: float, seed: int) -> void:
	# Real vats with curled bodies in them (Greg, 2026-09-24), not red columns
	# around pill-shaped silhouettes.
	for side in [-1.0, 1.0]:
		LabVat.build(self, Vector3(side * 4.25, 0.0, z), seed * 2 + (1 if side > 0.0 else 0), 2.3, 0.72)


func _build_landmarks() -> void:
	# Card station — a clearly lit side objective with a physical, original card.
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := BoxMesh.new()
	pedestal_mesh.size = Vector3(0.8, 1.1, 0.7)
	pedestal_mesh.material = WorldLook.surface(Color("241b15"), "metal", 401)
	pedestal.mesh = pedestal_mesh
	pedestal.position = CARD_AT + Vector3(0, -0.45, 0)
	add_child(pedestal)
	card_visual = MeshInstance3D.new()
	var card_mesh := BoxMesh.new()
	card_mesh.size = Vector3(0.36, 0.08, 0.54)
	var card_mat := StandardMaterial3D.new()
	card_mat.albedo_color = Color("d36d30")
	card_mat.emission_enabled = true
	card_mat.emission = Color("7a230f")
	card_mesh.material = card_mat
	card_visual.mesh = card_mesh
	card_visual.position = CARD_AT
	add_child(card_visual)
	var card_light := OmniLight3D.new()
	card_light.position = CARD_AT + Vector3(0, 1.0, 0)
	card_light.light_color = Color("ff7131")
	card_light.light_energy = 3.6
	card_light.omni_range = 4.0
	add_child(card_light)
	card_beacon = card_light
	card_label = Label3D.new()
	card_label.text = "STAFF ACCESS CARD\n[ E ] TAKE"
	card_label.font_size = 42
	card_label.outline_size = 8
	card_label.modulate = Color("f0a45c")
	card_label.outline_modulate = Color("1b0805")
	card_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	card_label.position = CARD_AT + Vector3(0, 0.85, 0)
	add_child(card_label)
	# The real tool, lying where it was dropped (Greg, 2026-09-24).
	weapon_visual = LabSurface.breach_tool()
	weapon_visual.position = WEAPON_AT + Vector3(0, 0.08, 0)
	weapon_visual.rotation_degrees = Vector3(0, 34.0, 90.0)
	add_child(weapon_visual)
	weapon_label = Label3D.new()
	weapon_label.text = "BREACH TOOL\n[ E ] ARM"
	weapon_label.font_size = 36
	weapon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	weapon_label.modulate = Color("e58b42")
	weapon_label.position = WEAPON_AT + Vector3(0, 0.7, 0)
	add_child(weapon_label)
	# Pressure gate is a real collision barrier until the card is used.
	gate_body = _slab(Vector3(5.0, 5.5, 0.45), GATE_AT + Vector3(0, 2.75, 0), "metal", Color("3b2119"))
	gate_panel = Node3D.new()
	gate_panel.position = GATE_AT
	add_child(gate_panel)
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(2.35, 5.3, 0.25)
		fin_mesh.material = WorldLook.surface(Color("43241a"), "metal", 520 + int(side))
		fin.mesh = fin_mesh
		fin.position = Vector3(side * 1.25, 2.65, -0.26)
		gate_panel.add_child(fin)
	var gate_light := OmniLight3D.new()
	gate_light.position = GATE_AT + Vector3(0, 3.8, 1.0)
	gate_light.light_color = Color("d84a27")
	gate_light.light_energy = 5.0
	gate_light.omni_range = 8.0
	add_child(gate_light)

func _slab(dimensions: Vector3, at: Vector3, _kind: String, _color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	# Real lab surfaces (Greg, 2026-09-24), chosen by the slab's shape.
	mesh.material = LabSurface.for_slab(dimensions, at)
	visual.mesh = mesh
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	return body

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0026
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.15, 0.95)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		_interact()
	# Greg (2026-09-24): the breach tool should be inspectable and should open
	# doors, not only interrupt the sentinel further down.
	if event is InputEventKey and not event.echo and event.keycode == KEY_I:
		inspect_held = event.pressed
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and weapon_taken:
		_discharge_at_gate()


var inspect_held := false


## The ram opens the pressure gate as well as the card does, louder. Recorded
## as its own act, so the world can tell a forced gate from a keyed one.
func _discharge_at_gate() -> bool:
	if gate_open or _flat_distance(GATE_AT) > 3.6:
		return false
	WorldHistory.record_event("service_arcade_gate_breached", {"location": "service_arcade"})
	_open_gate()
	if weapon_visual != null and is_instance_valid(weapon_visual):
		var kick := create_tween()
		kick.tween_property(weapon_visual, "position:z", weapon_visual.position.z - 0.22, 0.05)
		kick.tween_property(weapon_visual, "position:z", weapon_visual.position.z, 0.25)
	return true

func _physics_process(delta: float) -> void:
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var direction := (Basis(Vector3.UP, yaw) * input).normalized()
	player.velocity.x = move_toward(player.velocity.x, direction.x * 3.4, 16.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * 3.4, 16.0 * delta)
	player.velocity.y = -2.0 if player.is_on_floor() else player.velocity.y - 18.0 * delta
	player.move_and_slide()
	player.rotation.y = yaw
	camera.rotation = Vector3(pitch, 0, 0)
	# The arcade is a route, not a lockout puzzle. If the card was collected,
	# entering the obvious pressure-gate threshold opens it even if an input
	# event was swallowed by the transition frame.
	if card_taken and not gate_open and _flat_distance(GATE_AT) <= 4.4:
		_open_gate()
	_update_hud()

func _flat_distance(at: Vector3) -> float:
	var delta := at - player.global_position
	delta.y = 0.0
	return delta.length()

func _interact() -> void:
	if not card_taken and _flat_distance(CARD_AT) <= 2.3:
		card_taken = true
		card_visual.visible = false
		card_beacon.visible = false
		card_label.visible = false
		WorldHistory.record_event("service_arcade_keycard_taken", {"location": "service_arcade"})
		return
	if not weapon_taken and _flat_distance(WEAPON_AT) <= 2.3:
		weapon_taken = true
		# Taking it puts it in your hands, where you can see it.
		LabSurface.hold_in_view(camera, weapon_visual)
		weapon_label.visible = false
		WorldHistory.record_event("service_arcade_breach_tool_taken", {"location": "service_arcade"})
		return
	if not gate_open and _flat_distance(GATE_AT) <= 3.2 and card_taken:
		_open_gate()
		return
	# Do not make the player hunt for an invisible, second trigger after the
	# pressure gate has visibly opened.  The control panel and the threshold both
	# lead onward; this is especially important when the original E press was
	# consumed by the gate-opening frame.
	if gate_open and (_flat_distance(GATE_AT) <= 4.4 or _flat_distance(EXIT_AT) <= 3.0):
		_enter_lower_works()

func _open_gate() -> void:
	if gate_open:
		return
	gate_open = true
	if gate_body != null:
		gate_body.queue_free()
	gate_panel.position.y = 5.8
	WorldHistory.record_event("service_arcade_pressure_gate_opened", {"location": "service_arcade"})

func _enter_lower_works() -> void:
	if lower_works_requested:
		return
	lower_works_requested = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Tests assert the handoff without replacing their own scene tree.
	if OS.get_environment("ATG_TEST_MODE") != "1":
		Interstitial.travel("res://buried_city.tscn", "pressure gate open // lower works transit unlocked")

func _record_pit_entry() -> void:
	if OPENING.reached("entered_pit"):
		return
	WorldHistory.begin_ledger_batch()
	OPENING.advance("entered_pit")
	FACILITY_TERRITORY.apply_event("opening_entered_pit")
	WorldHistory.amend_subject("player", {"status": "racked for a heat"})
	WorldHistory.record_event("service_arcade_entered_pit", {"location": "service_arcade"})
	WorldHistory.commit_ledger_batch()

func _update_hud() -> void:
	vitals.text = "BLOOD 100%   PAIN 86   DECANTED"
	objective.text = "OBJECTIVE\n" + ("FOLLOW THE HEAT" if gate_open else ("REACH THE PRESSURE GATE" if card_taken and weapon_taken else ("FIND THE BREACH TOOL" if not weapon_taken else "FIND THE ORANGE STAFF CARD")))
	if weapon_taken:
		vitals.text += "   BREACH TOOL // READY"
	if inspect_held:
		prompt.text = "BREACH TOOL // PNEUMATIC RAM, ONE CHARGE CANISTER // CLICK AT A LOCKED DOOR" if weapon_taken else "NOTHING IN HAND TO INSPECT"
	elif not card_taken and _flat_distance(CARD_AT) <= 2.3:
		prompt.text = "[E] TAKE STAFF ACCESS CARD"
	elif not gate_open and _flat_distance(GATE_AT) <= 3.2:
		if card_taken:
			prompt.text = "[E] OPEN PRESSURE GATE"
		elif weapon_taken:
			prompt.text = "[LMB] BREACH THE PRESSURE GATE   //   OR FIND THE STAFF CARD"
		else:
			prompt.text = "PRESSURE GATE // STAFF CARD REQUIRED"
	elif gate_open and (_flat_distance(GATE_AT) <= 4.4 or _flat_distance(EXIT_AT) <= 3.0):
		prompt.text = "[E] ENTER LOWER WORKS"
	elif gate_open:
		prompt.text = "PRESSURE GATE UNSEALED // MOVE THROUGH"
	else:
		prompt.text = "WASD MOVE   //   MOUSE LOOK   //   E INTERACT" + ("   //   HOLD I INSPECT" if weapon_taken else "")
