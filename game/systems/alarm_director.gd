class_name AlarmDirector
extends Node

## Facility alertness for one place (Greg, 24 September): "a alarm and
## alertness for the characters system which then has an animated brainchip
## flash on their character model as well as blocktracking that you see and ...
## the depth map like white xray looking thing on the camera flashing on it for
## a second, and then more guards begin piling out ... and they try to kill
## you".
##
## One number, three states:
##
##   calm        0 .. SUSPICIOUS_AT     guards walk their rounds
##   suspicious  .. 1                   guards go and look at the last noise
##   alarm       1, latched             everyone is told, and more come
##
## Noise and glimpses raise it and it settles back down on its own, until the
## alarm, which does not. A camera that films you, a guard who sees you clearly,
## a bingyanger screaming: any of them is the alarm straight away.
##
## When the alarm goes, in order:
##   1. every registered character is alerted and its brain chip flashes
##      (`BrainChipFlash`, on the model);
##   2. the block tracker boxes each of them (`watch_entries()`, fed by the
##      host into `BlockTracker.watch`);
##   3. the player's camera flashes white depth / X-ray for a second
##      (`AlarmXrayFlash`);
##   4. after `REINFORCE_DELAY`, reinforcements come out of the doors, through
##      the host's `spawner`, in waves up to `MAX_REINFORCEMENTS`.
##
## Everything it decides goes into `WorldHistory`.

signal level_changed(level: String)
signal alarm_raised(source: String, at: Vector3)
signal reinforcements_arrived(count: int)

const SUSPICIOUS_AT := 0.3
const SETTLE_PER_SECOND := 0.04
const REINFORCE_DELAY := 2.4
const WAVE_GAP := 7.0
const WAVE_SIZE := 2
const MAX_REINFORCEMENTS := 6

@export var place := "support_unit"

var alertness := 0.0
var level := "calm"
var alarm_source := ""
var alarm_at := Vector3.ZERO
## Who hears it: anything with a `rig` (BaselineHuman) and an `alert(at)`.
var characters: Array = []
## Where reinforcements come out, and the host's function that makes one:
## `spawner.call(door_index: int) -> Node`.
var doors: Array = []
var spawner: Callable
var reinforcements := 0
var xray_flash: AlarmXrayFlash
var _until_wave := -1.0
var _chips: Dictionary = {}


func register(character: Object) -> void:
	if character == null or characters.has(character):
		return
	characters.append(character)
	if level == "alarm":
		_alert(character)


## A sound or a glimpse. `amount` is how much it moved the facility.
func raise(amount: float, source: String, at := Vector3.ZERO) -> void:
	if level == "alarm":
		return
	alertness = clampf(alertness + amount, 0.0, 1.0)
	alarm_at = at
	if alertness >= 1.0:
		_sound_alarm(source, at)
	elif alertness >= SUSPICIOUS_AT and level == "calm":
		_set_level("suspicious")
		WorldHistory.record_event("support_unit_suspicious", {"place": place, "source": source})


## Straight to the alarm: a camera filming, a clear sighting, a scream.
func trip(source: String, at := Vector3.ZERO) -> void:
	raise(1.0, source, at)


func is_alarm() -> bool:
	return level == "alarm"


func _sound_alarm(source: String, at: Vector3) -> void:
	alertness = 1.0
	alarm_source = source
	alarm_at = at
	_set_level("alarm")
	WorldHistory.record_event("support_unit_alarm_raised", {"place": place, "source": source, "alerted": characters.size()})
	var rigs: Array = []
	for character in characters:
		_alert(character)
		var rig := _rig_of(character)
		if rig != null:
			rigs.append(rig)
	if xray_flash != null and is_instance_valid(xray_flash):
		xray_flash.flash(rigs)
	_until_wave = REINFORCE_DELAY
	alarm_raised.emit(source, at)


func _alert(character: Object) -> void:
	if character == null or not is_instance_valid(character):
		return
	if character.has_method("alert"):
		character.call("alert", alarm_at)
	var rig := _rig_of(character)
	if rig == null or not is_instance_valid(rig):
		return
	var chip := _chips.get(rig.get_instance_id()) as BrainChipFlash
	if chip == null or not is_instance_valid(chip):
		chip = BrainChipFlash.install(rig)
		_chips[rig.get_instance_id()] = chip
	chip.flash()


func chip_for(character: Object) -> BrainChipFlash:
	var rig := _rig_of(character)
	if rig == null:
		return null
	return _chips.get(rig.get_instance_id()) as BrainChipFlash


func _rig_of(character: Object) -> Node3D:
	if character == null or not is_instance_valid(character):
		return null
	if character is BaselineHuman:
		return character as Node3D
	return character.get("rig") as Node3D


func _set_level(value: String) -> void:
	if value == level:
		return
	level = value
	level_changed.emit(level)


func _process(delta: float) -> void:
	if level != "alarm":
		alertness = maxf(0.0, alertness - SETTLE_PER_SECOND * delta)
		if level == "suspicious" and alertness < SUSPICIOUS_AT * 0.5:
			_set_level("calm")
		return
	if _until_wave < 0.0 or reinforcements >= MAX_REINFORCEMENTS or doors.is_empty() or not spawner.is_valid():
		return
	_until_wave -= delta
	if _until_wave <= 0.0:
		send_wave()


## One wave out of the doors now. Returns how many came.
func send_wave() -> int:
	_until_wave = WAVE_GAP
	var came := 0
	for index in WAVE_SIZE:
		if reinforcements >= MAX_REINFORCEMENTS:
			break
		var door_index := (reinforcements + index) % doors.size()
		var guard: Object = spawner.call(door_index)
		if guard == null:
			continue
		reinforcements += 1
		came += 1
		register(guard)
	if came > 0:
		WorldHistory.record_event("support_unit_reinforcements", {"place": place, "count": came, "total": reinforcements})
		reinforcements_arrived.emit(came)
	return came


## Block-tracking boxes for everyone who knows about the player: the alerted
## characters that are still standing. Fed to `BlockTracker.watch`.
func watch_entries() -> Array:
	var entries: Array = []
	for character in characters:
		if character == null or not is_instance_valid(character):
			continue
		if not bool(character.get("alerted")):
			continue
		if character.has_method("is_down") and bool(character.call("is_down")):
			continue
		var rig := _rig_of(character)
		if rig == null or not is_instance_valid(rig):
			continue
		var torso := (rig.get("parts") as Dictionary).get("torso") as Node3D
		var at := torso.global_position if torso != null and is_instance_valid(torso) else rig.global_position + Vector3(0, 1.1, 0)
		entries.append({"at": at, "certainty": clampf(float(character.get("certainty")) if character.get("certainty") != null else 1.0, 0.0, 1.0)})
	return entries
