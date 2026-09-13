class_name PitRadio
extends Control

## The cab speaker. Every driver in the heat is on the same open channel and
## none of them should be. Chatter is provoked by what actually happens — who
## rammed whom, who just died, who is bleeding — so the radio is a readout of
## the fight rather than a loop playing underneath it.
##
## Register per ART-DIRECTION.md: crude, loud, funny and genuinely unhinged, and
## the joke and the horror arrive together. Barks are authored strings for now;
## the same call sites take voice lines later without touching this logic.

signal transmitted(speaker: String, line: String)

const HANDLES := [
	"GUTTER-9", "SAINT PIG", "MOTHERWOUND", "TEN-BELL", "COUSIN RENDER",
	"HALF A FACE", "THE APPETITE", "WET WORK", "LITTLE MERCY", "SCRAP DADDY",
	"BONE APPETIT", "MRS TEETH",
]

const BARKS := {
	"idle": [
		"is anyone else's steering wheel WARM",
		"i have been awake for nine days and i feel FANTASTIC",
		"my mum's in the stands. she doesn't know it's me.",
		"they said no biting. no BITING. it's a CAR EVENT.",
		"whoever's got my thumb, no questions asked, just post it back",
		"i'm not angry i'm just LOUD. there's a difference. LEARN IT.",
		"sponsored tonight by nothing. nobody sponsors us. we're disgusting.",
	],
	"hit_player": [
		"KISSED HIM. I KISSED HIM WITH THE CAR.",
		"that's for looking at me. that's for EXISTING at me.",
		"did you see that? SOMEBODY WRITE THAT DOWN.",
		"i'm going to do it again and you can't stop me, nobody can, it's ALLOWED",
	],
	"took_hit": [
		"OW. OW. THAT'S MY SPINE. THAT'S MY WHOLE ENTIRE SPINE.",
		"okay. okay. okay. that was RUDE and i'm TELLING.",
		"you've made it personal. it was ALREADY personal. now it's WORSE.",
		"i'll be honest with you that one hurt my feelings more than my body",
	],
	"death": [
		"...he's gone. does anyone want his arm? going once.",
		"one down! statistically that's good news for ELEVEN of us!",
		"POUR ONE OUT. actually don't, i'll drink it, pass it here.",
		"that could have been any of us. mostly him though.",
	],
	"critical": [
		"i can see my own engine. from the inside. this is a design flaw.",
		"i'm fine. everything's fine. i'm mostly fine. i'm 40% fine.",
		"bleeding is just the body being dramatic about it",
	],
	"player_winning": [
		"who IS this. who let the fresh meat drive.",
		"tank baby's got a lead. EVERYONE. ON THE TANK BABY.",
		"i don't like him. i've decided. as a group. we've decided.",
	],
}

const CASE := Color("191410")
const CASE_EDGE := Color("55442f")
const HOT := Color("e2603a")
const PHOSPHOR := Color("d8c39a")

var messages: Array[Dictionary] = []
var cooldown := 0.0
var idle_timer := 0.0
var speaker_bloom := 0.0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var audio: Node
## The open channel remains audible and continues to drive world history, but
## it is not a subtitle slab bolted over the collision view.
var show_transcript := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.randomize()
	set_process(true)


func attach_audio(player: Node) -> void:
	audio = player


## `kind` keys into BARKS. Calls that arrive during cooldown are dropped rather
## than queued: a pile-up should not produce a backlog of stale chatter.
func transmit(kind: String, speaker: String = "") -> void:
	if cooldown > 0.0 or not BARKS.has(kind):
		return
	var pool: Array = BARKS[kind]
	var handle: String = speaker if not speaker.is_empty() else str(HANDLES[rng.randi() % HANDLES.size()])
	var line := str(pool[rng.randi() % pool.size()])
	cooldown = rng.randf_range(1.5, 3.2)
	speaker_bloom = 1.0
	messages.append({"speaker": handle, "line": line, "life": 7.5})
	if messages.size() > 4:
		messages.pop_front()
	if audio != null and audio.has_method("play_impact"):
		# Squelch: the channel opening is its own sound.
		audio.call("play_impact", 0.18, Vector3.ZERO, "panel")
	emit_signal("transmitted", handle, line)
	WorldHistory.record_event("pit_radio_bark", {"speaker": handle, "kind": kind})


func _process(delta: float) -> void:
	elapsed += delta
	cooldown = maxf(0.0, cooldown - delta)
	speaker_bloom = maxf(0.0, speaker_bloom - delta * 1.6)
	idle_timer -= delta
	if idle_timer <= 0.0:
		idle_timer = rng.randf_range(7.0, 14.0)
		transmit("idle")
	for message in messages.duplicate():
		message.life = float(message.life) - delta
		if float(message.life) <= 0.0:
			messages.erase(message)
	queue_redraw()


func _draw() -> void:
	if not show_transcript:
		return
	var panel := Rect2(Vector2(size.x * 0.5 - 250.0, size.y - 214.0), Vector2(500.0, 92.0))
	if messages.is_empty():
		return
	# Speaker grille bolted to the dash, lighting up when the channel opens.
	var grille := Rect2(panel.position - Vector2(58, 0), Vector2(50, 50))
	draw_rect(grille, CASE)
	draw_rect(grille, CASE_EDGE, false, 1)
	for row in 5:
		for column in 5:
			var hole := grille.position + Vector2(7 + column * 9, 7 + row * 9)
			draw_circle(hole, 2.2, HOT * Color(1, 1, 1, 0.2 + speaker_bloom * 0.7))

	var y := panel.position.y
	for index in messages.size():
		var message: Dictionary = messages[index]
		var age := clampf(float(message.life) / 7.5, 0.0, 1.0)
		var alpha := clampf(age * 2.4, 0.0, 1.0)
		# Radio chatter, in the voice the rest of the cab speaks in. `draw_string`
		# takes a baseline and `CellOutzType` a top-left, so both lines lift by
		# their cap to sit where they already sat.
		CellOutzType.draw_condensed(self, Vector2(panel.position.x, y - 9.0), "%s:" % str(message.speaker),
			9.0, HOT * Color(1, 1, 1, alpha), 1.1)
		CellOutzType.draw_condensed(self, Vector2(panel.position.x + 108, y - 9.0), str(message.line),
			9.0, PHOSPHOR * Color(1, 1, 1, alpha * 0.92), 1.1)
		y += 21.0
