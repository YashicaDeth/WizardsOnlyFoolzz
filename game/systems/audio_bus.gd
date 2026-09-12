class_name AudioBus
extends RefCounted

## G5.1. The bus graph, in one place, because it was not in any place.
##
## Greg asked to fix the entire game's sound, and the first thing measurement
## turned up was not a missing effect — it was that **the mixer did nothing**.
## `pause_gate.gd` builds Master / Music / SFX / Ambience and drives them from
## the settings screen, and every sound in the game was going straight to Master
## around the side of all three:
##
##   - `DerbyQuarry` (engines, impacts, crowd) sent to Master
##   - `FieldRadio` sent to Master
##   - `gore_chunks.gd` and `hunter_body_motion.gd` set no bus at all
##
## So a player could drag SFX to zero and the derby would carry on at full
## volume. Only `opening_audio.gd` was routed correctly, which is why this was
## easy to miss: the first thirty seconds of the game mixed properly and nothing
## after it did.
##
## Every sound now enters through `route()` and every processing bus sends into
## one of the three the player can actually see. Nothing is allowed to address
## Master directly except the three themselves.

## What the player sees on the settings screen.
const MASTER := "Master"
const MUSIC := "Music"
const SFX := "SFX"
const AMBIENCE := "Ambience"
const PLAYER_BUSES := [MUSIC, SFX, AMBIENCE]

## Processing buses, and which visible bus each one feeds. A new effect chain
## belongs in here rather than sending itself to Master, which is the mistake
## this file exists to make impossible.
const CHAINS := {
	"DerbyQuarry": SFX,
	"FieldRadio": SFX,
	"Gore": SFX,
	"Bodies": SFX,
	"Weather": AMBIENCE,
}


## Builds the graph if it is not already there, and — importantly — repairs it
## if it is. Buses can be created by whichever system happens to start first,
## and the one that created `DerbyQuarry` pointed it at Master. Re-pointing is
## cheap and idempotent, so this is safe to call from anywhere, any number of
## times.
static func ensure() -> void:
	for bus_name: String in PLAYER_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index == -1:
			index = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, MASTER)
	for chain_name: String in CHAINS:
		var index := AudioServer.get_bus_index(chain_name)
		if index == -1:
			continue
		# The repair. Whatever created it, it feeds the player's mixer now.
		AudioServer.set_bus_send(index, str(CHAINS[chain_name]))


## Creates a processing bus that feeds the right place, and hands back its
## index so the caller can hang effects on it. Call sites used to do this by
## hand and get the send wrong.
static func chain(chain_name: String) -> int:
	var index := AudioServer.get_bus_index(chain_name)
	if index == -1:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, chain_name)
	AudioServer.set_bus_send(index, str(CHAINS.get(chain_name, SFX)))
	return index


## Puts a player on a bus, falling back to a visible bus when the chain it asked
## for does not exist. A sound on a missing bus is silently reassigned to Master
## by the engine, which is exactly the failure that hid this bug.
static func route(player: Node, bus_name: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not ("bus" in player):
		return
	var wanted := bus_name
	if AudioServer.get_bus_index(wanted) == -1:
		wanted = str(CHAINS.get(bus_name, SFX))
	if AudioServer.get_bus_index(wanted) == -1:
		wanted = MASTER
	player.set("bus", wanted)


## Every bus that is not Master, and where it currently sends. Used by the test
## to assert that nothing sneaks around the mixer, and worth having as a
## diagnostic the next time somebody swears the volume slider is broken.
static func graph() -> Dictionary:
	var out: Dictionary = {}
	for index in AudioServer.bus_count:
		var bus_name := AudioServer.get_bus_name(index)
		if bus_name == MASTER:
			continue
		out[bus_name] = AudioServer.get_bus_send(index)
	return out


## True when every bus ultimately reaches Master through one of the three the
## player can turn down. A capture bus (a microphone input) is allowed to be
## outside this, since turning down SFX should not deafen the game's own ears.
static func fully_routed(exempt: Array = ["NPCVoiceCapture"]) -> bool:
	for bus_name: String in graph():
		if exempt.has(bus_name):
			continue
		if PLAYER_BUSES.has(bus_name):
			continue
		if not PLAYER_BUSES.has(str(graph()[bus_name])):
			return false
	return true
