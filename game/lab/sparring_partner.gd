extends Node3D

## Job 3 PROOF needs "a fighting enemy in the mechanics lab". This is the
## smallest honest one: the lab's own dummy body (`BodiesStation.dummy`) with
## a PRODSTAFF in hand that turns to face you, closes in, and swings with a
## readable telegraph. Its blow goes through the player's `MeleeDriver`
## (parry, block, or it lands) and misses a roll's i-frames (`SoulsMover`).
## A parry or a heavy hit makes it reel. It is not the v0.1 guard AI (that is
## job 5's); it exists so blocking, parrying and rolling have something to
## answer in the lab.

const BODIES := preload("res://lab/stations/bodies_station.gd")
const BODY_CAM := preload("res://systems/body_cam_feel.gd")

const SPEED := 1.5
const ENGAGE := 6.0
## How far from where it stands it will follow you before walking back.
const LEASH := 5.0
const REACH := 2.6
const WINDUP := 0.62
const ACTIVE := 0.14
const RECOVERY := 0.7
const REST := 1.3
const DAMAGE := 18.0
const RESPAWN_SECONDS := 12.0
## Fix-58. A body on the floor waits for you this long before the lab stands a
## fresh one up. Downed used to count as dead, so the body you were walking up
## to finish (or had a hand inside) was deleted under you at twelve seconds.
const DOWNED_SECONDS := 40.0
## Seconds it stands stunned after your parry.
const PARRIED_STUN := 1.4

var lab: Node3D
var rig: BaselineHuman
var holder: Node3D
var staff: Node3D
var flare: OmniLight3D
var state := "idle"
var clock := 0.0
var swings := 0
var outcomes: Array[String] = []
var dead_for := 0.0
var _death_seen := false


func build(owner_lab: Node3D) -> void:
	lab = owner_lab
	_spawn()


func _spawn() -> void:
	if holder != null and is_instance_valid(holder):
		holder.queue_free()
	# Lab-48: hardware for the PRODSTAFF to short and the X-ray to tag.
	rig = BODIES.dummy(self, "lab_sparring_%d" % Time.get_ticks_msec(), Vector3.ZERO, PI, 3, {"chest": "copper lung bellows", "organ_bays": "quiet-heart regulator"})
	holder = rig.get_parent() as Node3D
	staff = HeldGear.build_weapon("staff")
	staff.name = "PartnerStaff"
	var arm := rig.parts.get("right_arm") as Node3D
	(arm if arm != null else holder).add_child(staff)
	staff.position = Vector3(0.0, -0.3, -0.2)
	flare = OmniLight3D.new()
	flare.light_color = Color("ff3a1a")
	flare.omni_range = 2.2
	flare.light_energy = 0.0
	flare.position = Vector3(0, 1.6, -0.3)
	holder.add_child(flare)
	state = "idle"
	clock = 0.0
	dead_for = 0.0
	_death_seen = false


func is_dead() -> bool:
	return rig == null or not is_instance_valid(rig) or rig.anatomy.dead or rig.anatomy.downed


func _physics_process(delta: float) -> void:
	if lab == null:
		return
	if is_dead():
		flare.light_energy = 0.0
		# Never under a finisher or a hand in the chest.
		var in_use: bool = (lab.execution != null and lab.execution.active and lab.execution.victim == rig) 			or (not lab.rip.is_empty() and lab.rip.get("rig") == rig)
		var dead_now := rig == null or not is_instance_valid(rig) or rig.anatomy.dead
		if dead_now and not _death_seen:
			# The clock to clear a corpse starts at the death, not the fall.
			_death_seen = true
			dead_for = 0.0
		if in_use:
			return
		dead_for += delta
		if dead_for >= (RESPAWN_SECONDS if dead_now else DOWNED_SECONDS):
			_spawn()
		return
	var player: CharacterBody3D = lab.player
	var to := player.global_position - holder.global_position
	to.y = 0.0
	var distance := to.length()
	clock += delta
	if state in ["idle", "rest"] and distance > 0.01:
		# Face the player (the holder's -Z is the dummy's front).
		holder.rotation.y = lerp_angle(holder.rotation.y, atan2(-to.x, -to.z), clampf(delta * 6.0, 0.0, 1.0))
	match state:
		"idle":
			var home := global_position - holder.global_position
			home.y = 0.0
			var chasing := distance < ENGAGE and (player.global_position - global_position).length() < LEASH + REACH
			if chasing and distance > REACH * 0.85:
				# Lab-48: a lung gone is breathless, a heart gone barely moves.
				holder.global_position += to.normalized() * SPEED * OrganSystem.pace(rig.anatomy) * delta
			elif chasing:
				_enter("windup")
			elif home.length() > 0.2:
				holder.global_position += home.normalized() * SPEED * delta
		"windup":
			# The telegraph: it draws back and its staff head reddens.
			var draw := clampf(clock / WINDUP, 0.0, 1.0)
			flare.light_energy = draw * 3.0
			holder.rotation.x = -0.12 * draw
			if clock >= WINDUP:
				_enter("active")
		"active":
			holder.rotation.x = 0.1
			if clock >= ACTIVE * 0.5 and swings > outcomes.size():
				_land_blow(distance)
			if clock >= ACTIVE:
				_enter("recovery")
		"recovery":
			flare.light_energy = 0.0
			holder.rotation.x = lerpf(holder.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
			if clock >= RECOVERY:
				_enter("rest")
		"stunned":
			flare.light_energy = 0.0
			if clock >= PARRIED_STUN:
				_enter("rest")
		"rest":
			if clock >= REST:
				_enter("idle")


func _enter(next: String) -> void:
	state = next
	clock = 0.0
	if next == "active":
		swings += 1


## The blow, resolved against the player at the moment it would connect.
func _land_blow(distance: float) -> void:
	var outcome := "missed"
	if distance <= REACH:
		if lab.mover.invulnerable():
			outcome = "rolled"
		else:
			var answer: Dictionary = lab.melee.receive_blow(DAMAGE)
			outcome = str(answer.result)
			lab.player_health = maxf(0.0, float(lab.player_health) - float(answer.damage))
			if outcome == "hit" or outcome == "guard_broken":
				# A body caught reaching for a handle is knocked back out of the
				# entry sequence; damage never grants invulnerable transport.
				if lab.vehicles != null:
					lab.vehicles.interrupt_entry("TOOK DAMAGE")
				BODY_CAM.hit(lab.camera, 0.08)
				# Its staff is a PRODSTAFF: your own hardware shorts too.
				if lab.has_method("on_player_shocked"):
					lab.on_player_shocked()
	outcomes.append(outcome)
	if outcome == "parried":
		if lab.get("disciplines") != null:
			lab.disciplines.open_riposte(rig)
		var away: Vector3 = holder.global_position - lab.player.global_position
		away.y = 0.0
		MeleeDriver.reel(rig, {"shove": away.normalized() * 0.35, "knockdown": false, "shock": true})
		_enter("stunned")
	lab.call("_note", "SPARRING // %s" % outcome.to_upper().replace("_", " "))


## Only a hit or a heavy staggers it; the player's MeleeDriver already reels
## the body on its own `staggered` signal, so this just interrupts the swing.
func interrupt() -> void:
	if state in ["windup", "active"]:
		flare.light_energy = 0.0
		_enter("stunned")

