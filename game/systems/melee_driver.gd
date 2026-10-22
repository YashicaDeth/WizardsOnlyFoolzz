class_name MeleeDriver
extends Node

## Job 3 (v0.1 "Escape"): a held melee weapon swung from the eye, for any
## first-person owner (the mechanics lab, the facility route). The swing's
## timing is `SwordMoveset`'s table for the held weapon; the per-hit numbers
## are `HunterArsenal`'s; this class adds what makes a blow land: an input
## buffer, a sweep from the eye that follows the look (pitch included), one
## contact per target per swing, hitstop, camera kick, stagger through
## `Knockback`, the HOTLINE CLEAVER's heat and the PRODSTAFF's shock.
##
## The owner keeps its body, its camera and its hit resolution: connect
## `struck` and land the packet on whatever the collider is (a BaselineHuman,
## WorldBreak, a station). Pad and keyboard both arrive as InputMap actions
## (R1 `attack`, R2 `heavy` held to charge, L1 `guard`, L2 `parry`).

signal struck(collider: Object, at: Vector3, direction: Vector3, packet: Dictionary)
signal kicked(amount: float)
signal staggered(rig: Node3D, report: Dictionary)
signal swing_started(attack_id: String)
## An incoming blow was answered: `result` is parried, blocked, guard_broken or hit.
signal blow_received(result: String)

## Seconds a press is kept while the weapon is busy (brief: about 150 ms).
const INPUT_BUFFER := 0.15
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 30.0
const STAMINA_DELAY := 0.55
const PARRY_WINDOW := 0.24
const BLOCK_STAMINA_PER_DAMAGE := 0.9
## Below this stagger share a hit only flinches; at or above it the target
## reels. Heavy and charged blows clear it, lights mostly do not.
const STAGGER_AT := 0.45

## The one tuning table for how a hit feels. Hitstop in seconds of real
## time (brief: 60-90 ms), camera kick in BodyCam units, damage factors per
## attack. Heat and shock numbers belong to their weapon.
const FEEL := {
	"cleaver": {
		"hitstop": 0.065, "hitstop_heavy": 0.09, "kick": 0.035, "kick_heavy": 0.065,
		"heat_per_hit": 0.26, "heat_decay": 0.09, "heat_damage_bonus": 0.35,
		"glow_cold": 0.6, "glow_hot": 9.0, "burn_from_heat": 0.15,
	},
	"staff": {
		"hitstop": 0.06, "hitstop_heavy": 0.085, "kick": 0.03, "kick_heavy": 0.06,
		"tip_idle": 1.2, "tip_charging": 4.0, "tip_shock": 14.0, "shock_flare": 0.35,
	},
	"default": {"hitstop": 0.06, "hitstop_heavy": 0.08, "kick": 0.03, "kick_heavy": 0.05},
}
const ATTACK_DAMAGE := {
	"light_1": 1.0, "light_2": 1.0, "light_3": 1.15, "heavy": 1.55,
	"charged_heavy": 2.0, "running_attack": 1.3, "roll_attack": 1.2,
}

## --- OPEN dials (Greg has not decided; defaults are the builder's) ---------
## Does the cleaver's heat cost anything? "none": heat only builds from hits
## and fades. "overheat": at full heat the element vents for
## OVERHEAT_SECONDS: no glow bonus and no burn until it has cooled.
static var heat_cost := "none"
const OVERHEAT_SECONDS := 1.6
## Hitstop slows the whole world (Engine.time_scale) or only the swing.
static var world_hitstop := true
const HITSTOP_TIME_SCALE := 0.05

var arsenal: HunterArsenal
var eye: Node3D
var exclude: Array[RID] = []
var moveset := SwordMoveset.new()
var model: Node3D
var stamina := MAX_STAMINA
var heat := 0.0
var vent_left := 0.0
var guard_held := false
var parry_left := 0.0
var heavy_held := -1.0
var swing_hint := Vector2.ZERO
var contacts := 0
var last_packet: Dictionary = {}
## imp-64: the swing's whoosh and the hit's voice (`FpCombatAudio`).
var audio: FpCombatAudio

var _pending := ""
var _pending_age := 0.0
var _swing_mirror := false
var _swept_to := 0.0
var _swing_serial := 0
var _whooshed := 0
var _hit_ids: Dictionary = {}
var _hitstop_until_us := 0
var _stamina_wait := 0.0
var _poise: Dictionary = {}
var _shock_flare := 0.0
var _model_rest := Transform3D.IDENTITY


func setup(owner_arsenal: HunterArsenal, owner_eye: Node3D, skip: Array[RID] = []) -> void:
	arsenal = owner_arsenal
	eye = owner_eye
	exclude = skip
	if audio == null:
		audio = FpCombatAudio.new()
		audio.name = "CombatAudio"
		add_child(audio)
	_sync_weapon()


## The visible held weapon. Its rest transform is read once, so the swing
## pose is an offset from where the owner placed it.
func set_model(held: Node3D) -> void:
	model = held
	if model != null:
		_model_rest = model.transform
	_update_glow()


## The current swing runs the mirrored way (a hint from the left).
func swing_mirrored() -> bool:
	return _swing_mirror


func melee_held() -> bool:
	return arsenal != null and str(arsenal.current().get("kind", "")) == "melee"


## R1 / LMB.
func press_light() -> void:
	_queue("light")


## R2 / MMB down: a hold charges (SwordMoveset.CHARGED_HEAVY_SECONDS).
func press_heavy() -> void:
	if heavy_held < 0.0:
		heavy_held = 0.0


func release_heavy() -> void:
	if heavy_held < 0.0:
		return
	_queue("charged_heavy" if heavy_held >= SwordMoveset.CHARGED_HEAVY_SECONDS else "heavy")
	heavy_held = -1.0


func set_guard(held: bool) -> void:
	guard_held = held


func press_parry() -> void:
	parry_left = PARRY_WINDOW


## Stick or mouse direction at the moment of the press: a swing from the
## left runs right-to-left, one pushed up comes over the top.
func set_swing_hint(direction: Vector2) -> void:
	swing_hint = direction


## The owner's input hook; returns true when the event was a melee verb.
func handle_input(event: InputEvent) -> bool:
	if not melee_held():
		return false
	if event.is_action_pressed("attack"):
		press_light()
	elif event.is_action_pressed("heavy"):
		press_heavy()
	elif event.is_action_released("heavy"):
		release_heavy()
	elif event.is_action_pressed("guard"):
		set_guard(true)
	elif event.is_action_released("guard"):
		set_guard(false)
	elif event.is_action_pressed("parry"):
		press_parry()
	else:
		return false
	return true


## An incoming blow, for whatever attacks the holder. Parry inside the
## window costs nothing and staggers the attacker's swing; a raised guard
## soaks it for stamina; otherwise it lands.
func receive_blow(damage: float) -> Dictionary:
	var answer := _answer_blow(damage)
	blow_received.emit(str(answer.result))
	return answer


func _answer_blow(damage: float) -> Dictionary:
	if parry_left > 0.0:
		parry_left = 0.0
		return {"result": "parried", "damage": 0.0}
	if guard_held and melee_held() and stamina > 0.0:
		var cost := damage * BLOCK_STAMINA_PER_DAMAGE
		spend(cost)
		return {"result": "blocked" if stamina > 0.0 else "guard_broken", "damage": damage * (0.1 if stamina > 0.0 else 0.6)}
	return {"result": "hit", "damage": damage}


func hitstop_active() -> bool:
	return Time.get_ticks_usec() < _hitstop_until_us


func tick(delta: float) -> void:
	_sync_weapon()
	_tick_resources(delta)
	if hitstop_active():
		_update_pose()
		return
	_end_hitstop()
	if heavy_held >= 0.0:
		heavy_held += delta
	if not _pending.is_empty():
		_pending_age += delta
		if _try_start(_pending):
			_pending = ""
		elif _pending_age > INPUT_BUFFER and not moveset.is_attacking():
			_pending = ""
	var report := moveset.tick(delta)
	# A swing the moveset itself started out of its recovery buffer.
	if bool(report.get("started_buffered", false)) and moveset.is_attacking():
		spend(float(report.get("stamina_cost", 0.0)))
		_begin_swing()
	if moveset.is_attacking() and moveset.phase() == "active" and _whooshed != _swing_serial:
		_whooshed = _swing_serial
		if audio != null:
			audio.whoosh(arsenal.current_id, swing_heavy())
	_sweep()
	_update_pose()


## The swing in flight is a heavy, charged or running blow.
func swing_heavy() -> bool:
	return moveset.is_attacking() and moveset.current_attack() in ["heavy", "charged_heavy", "running_attack"]


func _queue(kind: String) -> void:
	if not melee_held():
		return
	_pending = kind
	_pending_age = 0.0
	if _try_start(kind):
		_pending = ""


func _try_start(kind: String) -> bool:
	if moveset.is_attacking() and moveset.time_remaining() > SwordMoveset.INPUT_BUFFER_WINDOW:
		return false
	var result: Dictionary
	match kind:
		"light": result = moveset.request_light(stamina)
		"heavy": result = moveset.request_heavy(stamina)
		_: result = moveset.request_heavy_release(SwordMoveset.CHARGED_HEAVY_SECONDS, stamina)
	if bool(result.get("accepted", false)):
		spend(float(result.stamina_cost))
		_begin_swing()
		return true
	# Handed to the moveset's own recovery buffer: it starts when this ends.
	return bool(result.get("buffered", false))


func _begin_swing() -> void:
	_swing_serial += 1
	_swept_to = 0.0
	_hit_ids.clear()
	# Directional: a hint to the left mirrors the arc. Up turns any swing
	# into one over the top.
	_swing_mirror = swing_hint.x < -0.35
	swing_started.emit(moveset.current_attack())


func _sweep() -> void:
	if not moveset.is_attacking() or eye == null or _swept_to >= 1.0:
		return
	var phase := moveset.phase()
	if phase == "windup":
		return
	var to := 1.0 if phase == "recovery" else moveset.phase_progress()
	var definition := moveset.current_definition()
	var from := _swept_to
	_swept_to = to
	var samples := maxi(2, ceili(8.0 * (to - from)) + 1)
	var space := eye.get_world_3d().direct_space_state
	for index in samples:
		var amount := lerpf(from, to, float(index) / float(samples - 1))
		var along := _swing_ray(definition, amount)
		var query := PhysicsRayQueryParameters3D.create(eye.global_position, eye.global_position + along * float(definition.reach))
		query.collide_with_areas = true
		query.exclude = exclude
		var met := space.intersect_ray(query)
		if met.is_empty():
			continue
		var key := _target_key(met.collider)
		if _hit_ids.has(key):
			continue
		_hit_ids[key] = true
		_contact(met.collider, met.position, along, definition)


## The blade's direction from the eye at `amount` through the arc. Sides
## sweep round the eye's up axis, `high` comes down round its right axis,
## and a thrust stays on the look line with a small drift.
func _swing_ray(definition: Dictionary, amount: float) -> Vector3:
	var basis := eye.global_basis
	var forward := -basis.z
	var angle := lerpf(float(definition.arc_start), float(definition.arc_end), amount) * (-1.0 if _swing_mirror else 1.0)
	var overhead := str(definition.side) == "high" or swing_hint.y > 0.5
	if overhead:
		# Top to bottom across the look line, whatever the table's sign.
		var drop := lerpf(0.75, -0.45, amount)
		return forward.rotated(basis.x.normalized(), drop).normalized()
	return forward.rotated(basis.y.normalized(), -angle * 0.55).normalized()


func _contact(collider: Object, at: Vector3, along: Vector3, definition: Dictionary) -> void:
	var weapon: Dictionary = arsenal.current()
	var feel := _feel()
	var attack_id := str(definition.get("attack", moveset.current_attack()))
	var heavy := attack_id in ["heavy", "charged_heavy", "running_attack"]
	var damage := float(weapon.damage) * float(ATTACK_DAMAGE.get(attack_id, 1.0))
	if arsenal.current_id == "cleaver" and vent_left <= 0.0:
		damage *= 1.0 + heat * float(feel.heat_damage_bonus)
	var packet := {
		"weapon": arsenal.current_id,
		"attack": attack_id,
		"kind": "melee",
		"damage": damage,
		"impulse": float(weapon.impulse) * sqrt(maxf(0.1, float(definition.get("knockback_multiplier", 1.0)))),
		"damage_type": str(definition.get("damage_type", weapon.damage_type)),
		"heavy": heavy,
		"shock": bool(definition.get("shock", false)),
		"heat": heat,
		"swing": along,
		"mirror": _swing_mirror,
		"attack_data": definition,
	}
	contacts += 1
	last_packet = packet
	struck.emit(collider, at, along, packet)
	var rig := rig_of(collider)
	if rig != null:
		_stagger(rig, packet, definition, along)
		if arsenal.current_id == "cleaver" and vent_left <= 0.0 and heat >= float(feel.burn_from_heat):
			burn_mark(collider as Node, at, along, heat)
	# One stop, one kick and one step of heat per swing, however many things
	# the arc passes through.
	if _hit_ids.size() == 1:
		_after_contact(heavy, packet)
		if audio != null:
			audio.impact(FpCombatAudio.surface_of(collider, packet), heavy)


func _after_contact(heavy: bool, packet: Dictionary) -> void:
	var feel := _feel()
	var stop := float(feel.hitstop_heavy if heavy else feel.hitstop)
	_hitstop_until_us = Time.get_ticks_usec() + int(stop * 1000000.0)
	if world_hitstop:
		Engine.time_scale = HITSTOP_TIME_SCALE
	kicked.emit(float(feel.kick_heavy if heavy else feel.kick))
	if arsenal.current_id == "cleaver" and vent_left <= 0.0:
		heat = minf(1.0, heat + float(feel.heat_per_hit))
		if heat >= 1.0 and heat_cost == "overheat":
			vent_left = OVERHEAT_SECONDS
	if bool(packet.shock):
		_shock_flare = float(feel.get("shock_flare", 0.3))
	_update_glow()


func _stagger(rig: Node3D, packet: Dictionary, definition: Dictionary, along: Vector3) -> void:
	var key := rig.get_instance_id()
	if not _poise.has(key):
		_poise[key] = Knockback.new()
	var knock: Knockback = _poise[key]
	var report := knock.apply(float(packet.impulse), along, definition)
	report["shock"] = bool(packet.shock)
	if float(report.stagger) >= STAGGER_AT or bool(report.knockdown) or bool(packet.shock):
		report["staggered"] = true
		staggered.emit(rig, report)
		reel(rig, report)


## The target reels: its holder is shoved along the blow and rocks back,
## then settles. Visual only; a live fighter's AI reads `staggered`.
static func reel(rig: Node3D, report: Dictionary) -> void:
	var holder := rig.get_parent() as Node3D
	if holder == null or not rig.is_inside_tree():
		return
	var anatomy = rig.get("anatomy")
	if anatomy != null and bool(anatomy.get("dead")):
		return
	var shove: Vector3 = report.get("shove", Vector3.ZERO)
	var rest := holder.rotation
	var tween := holder.create_tween()
	tween.set_ignore_time_scale(true)
	var lean := Vector3(-0.28 if bool(report.get("knockdown", false)) else -0.16, 0, 0)
	tween.tween_property(holder, "position", holder.position + shove.limit_length(0.6), 0.12)
	# AN6.8. This shove is the player's verb landing on somebody, and a landed
	# blow is how a body is moved without anybody having hold of it: a bleeding
	# target pushed across a floor has to mark the floor it crossed. Sampled from
	# the shove's own tween because `reel()` is static and has no frame of its
	# own; the smear system measures the delta.
	var scene_root := rig.get_tree().current_scene
	if scene_root != null:
		var sampler := holder.create_tween()
		sampler.set_ignore_time_scale(true)
		var sample := func(_progress: float) -> void: BloodSmear.follow_now(scene_root, rig, rig)
		sampler.tween_method(sample, 0.0, 1.0, 0.12)
	tween.parallel().tween_property(holder, "rotation", rest + lean, 0.12)
	tween.tween_property(holder, "rotation", rest, 0.45 if bool(report.get("shock", false)) else 0.3)


## A scorch where the hot edge went in, projected onto the struck part.
static func burn_mark(part: Node, at: Vector3, along: Vector3, strength: float) -> Decal:
	var holder := part as Node3D
	if holder == null or not holder.is_inside_tree():
		return null
	var decal := Decal.new()
	decal.name = "BurnMark"
	var size := lerpf(0.07, 0.13, clampf(strength, 0.0, 1.0))
	decal.size = Vector3(size, 0.16, size)
	decal.texture_albedo = _burn_texture()
	decal.texture_emission = _burn_texture()
	decal.emission_energy = lerpf(0.4, 2.2, strength)
	decal.modulate = Color(1, 1, 1, 1)
	holder.add_child(decal)
	# Project along the cut: the decal's -Y looks into the wound.
	var up := -along.normalized()
	var side := up.cross(Vector3.UP if absf(up.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	decal.global_basis = Basis(side, up, side.cross(up)).orthonormalized()
	decal.global_position = at
	return decal


static var _burn_cache: GradientTexture2D


static func _burn_texture() -> GradientTexture2D:
	if _burn_cache != null:
		return _burn_cache
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.10, 0.03, 0.01, 0.95))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	gradient.add_point(0.45, Color(0.35, 0.08, 0.02, 0.85))
	gradient.add_point(0.62, Color(0.85, 0.30, 0.05, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	_burn_cache = texture
	return texture


func _tick_resources(delta: float) -> void:
	parry_left = maxf(0.0, parry_left - delta)
	_shock_flare = maxf(0.0, _shock_flare - delta)
	if vent_left > 0.0:
		vent_left = maxf(0.0, vent_left - delta)
		heat = maxf(0.0, heat - delta / OVERHEAT_SECONDS)
	else:
		heat = maxf(0.0, heat - float(FEEL.cleaver.heat_decay) * delta)
	for key in _poise:
		(_poise[key] as Knockback).tick(delta)
	if _stamina_wait > 0.0:
		_stamina_wait = maxf(0.0, _stamina_wait - delta)
	elif not guard_held:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN * delta)
	_update_glow()


func spend(cost: float) -> void:
	stamina = maxf(0.0, stamina - cost)
	_stamina_wait = STAMINA_DELAY


func _end_hitstop() -> void:
	if _hitstop_until_us > 0 and world_hitstop and is_equal_approx(Engine.time_scale, HITSTOP_TIME_SCALE):
		Engine.time_scale = 1.0
	_hitstop_until_us = 0


func _exit_tree() -> void:
	_end_hitstop()


func _sync_weapon() -> void:
	if arsenal == null:
		return
	var held := str(arsenal.current_id)
	var table := held if SwordMoveset.WEAPON_TABLES.has(held) else "sword"
	if moveset.weapon_id != table and not moveset.is_attacking():
		moveset.configure(table, "two_hand" if table == "staff" else "one_hand")


func _feel() -> Dictionary:
	return FEEL.get(arsenal.current_id if arsenal != null else "", FEEL.default)


func _target_key(collider: Object) -> int:
	var rig := rig_of(collider)
	return rig.get_instance_id() if rig != null else (collider.get_instance_id() if collider != null else 0)


## The body a collider belongs to. A knocked-down or dead body's parts are
## reparented under its `RagdollBody`, which remembers its `source`.
static func rig_of(collider: Object) -> BaselineHuman:
	var node := collider as Node
	while node != null:
		if node is BaselineHuman:
			return node
		if node is RagdollBody and (node as RagdollBody).source != null and is_instance_valid((node as RagdollBody).source):
			return (node as RagdollBody).source
		node = node.get_parent()
	return null


## The held model: pulled back in the windup, carried through the arc while
## active, eased home in recovery. Charging a heavy draws it further back.
func _update_pose() -> void:
	if model == null or not is_instance_valid(model):
		return
	# imp-64: real arms pose themselves from this driver's state.
	if model is FirstPersonArms:
		return
	var turn := Vector3.ZERO
	var push := Vector3.ZERO
	if moveset.is_attacking():
		var definition := moveset.current_definition()
		var progress := moveset.phase_progress()
		var overhead := str(definition.side) == "high"
		var thrust := str(definition.get("motion", "")).contains("thrust")
		var mirror_sign := -1.0 if _swing_mirror else 1.0
		var start := 1.0
		var finish := -1.0
		var amount := 0.0
		match moveset.phase():
			"windup": amount = lerpf(0.0, start, ease(progress, 0.5))
			"active": amount = lerpf(start, finish, progress)
			_: amount = lerpf(finish, 0.0, ease(progress, 2.0))
		if thrust:
			push = Vector3(0, 0, -0.35 * clampf(-amount, 0.0, 1.0) + 0.12 * clampf(amount, 0.0, 1.0))
		elif overhead:
			turn = Vector3(amount * 0.9, 0, 0)
		else:
			turn = Vector3(0, amount * 0.85 * mirror_sign, amount * 0.25 * mirror_sign)
	elif heavy_held >= 0.0:
		var charge := clampf(heavy_held / SwordMoveset.CHARGED_HEAVY_SECONDS, 0.0, 1.0)
		turn = Vector3(charge * 0.7, 0, 0)
		push = Vector3(0, 0, 0.08 * charge)
	elif guard_held:
		turn = Vector3(0, 0, 0.9)
		push = Vector3(-0.12, 0.08, 0.05)
	model.transform = Transform3D(_model_rest.basis * Basis.from_euler(turn), _model_rest.origin + push)


func _update_glow() -> void:
	if model == null or not is_instance_valid(model):
		return
	var edge := model.find_child("heat_edge", true, false) as MeshInstance3D
	if edge != null and edge.material_override is StandardMaterial3D:
		var feel: Dictionary = FEEL.cleaver
		var lit := 0.0 if vent_left > 0.0 else heat
		(edge.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(float(feel.glow_cold), float(feel.glow_hot), lit)
	var tip := model.find_child("shock_tip", true, false) as MeshInstance3D
	if tip != null and tip.material_override is StandardMaterial3D:
		var feel_staff: Dictionary = FEEL.staff
		var energy := float(feel_staff.tip_idle)
		if heavy_held >= SwordMoveset.CHARGED_HEAVY_SECONDS:
			energy = float(feel_staff.tip_charging)
		if _shock_flare > 0.0:
			energy = float(feel_staff.tip_shock)
		(tip.material_override as StandardMaterial3D).emission_energy_multiplier = energy
