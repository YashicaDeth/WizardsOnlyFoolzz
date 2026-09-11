class_name BrokenWeb
extends RefCounted

## I2. The surviving internet as many worlds rather than one feed.
##
## The Wire is a scrolling column of posts, which is what a *platform* looks
## like. `DESIGN/IN_GAME_INTERNET.md` asks for the other thing as well: dead
## forums with the last post four years old, automated shops still taking orders
## nobody fills, broken image hosts, a business with no surviving employees. That
## is not a feed. It is a set of **places**, each built by a different person with
## different taste and different competence, and the only honest way to do it is
## to give each one its own layout.
##
## So this is two halves:
##
##   I2.1  the primitives every bad site was made of — tiled backgrounds,
##         marquees, hit counters, guestbooks, webrings, banner farms, popups
##   I2.2  a catalogue where no two sites share a layout
##   I2.3  each site reachable from one place in the world and nowhere else
##   I2.4  and most of them are dead, with the date to prove it
##
## Nothing here reaches for the real internet. Every site is authored fiction in
## this world's own voice.

const INK := Color("dce6ba")
const ACID := Color("b4da48")
const ARTERIAL := Color("c81f16")
const BILE := Color("b8a12a")
const SCAN := Color("35b7a7")
const BRUISE := Color("6a2d6e")

## The year the player is standing in, so "four years old" stays four years old
## rather than drifting as the fiction's calendar moves.
const NOW_YEAR := 2041

## I2.2 / I2.3 / I2.4. Each site names the emitter it is reachable through, and
## most of them name the year they stopped. `layout` is what makes them look
## unalike — see `layouts()` for what each one draws.
const SITES := [
	{
		"id": "marrow_board", "title": "THE MARROW BOARD",
		"url": "choir.marrow/board", "layout": "forum",
		"requires": "communion_terminal", "palette": "bone",
		"last_post": 2037, "moderator": "DOCTOR VANTA", "moderator_dead": true,
		"strap": "surgical theology · 11 boards · 2 users online",
		"lines": [
			"RE: is it still you afterward (412 replies)",
			"RE: RE: is it still you afterward (0 replies)",
			"sticky: NO TRADING LIVE PARTS ON THE BOARD",
			"moderator has not logged in for 1,488 days",
		],
	},
	{
		"id": "ashline_tolls", "title": "ASHLINE ROAD TOLLS",
		"url": "ashline.toll/rates", "layout": "shop",
		"requires": "black_mile_mast", "palette": "rust",
		"last_post": 2040, "moderator": "", "moderator_dead": false,
		"strap": "AUTOMATED · ORDERS ACCEPTED · NOTHING SHIPS",
		"lines": [
			"TEETH, ADULT, MATCHED SET ......... 40 SCRIP",
			"TEETH, ADULT, UNMATCHED ........... 12 SCRIP",
			"SAFE PASSAGE, ONE VEHICLE ......... 90 SCRIP",
			"YOUR ORDER #00412 IS BEING PREPARED",
		],
	},
	{
		"id": "weather_heart", "title": "the weather has a heart!!!",
		"url": "~vale/weatherheart", "layout": "conspiracy",
		"requires": "bone_yard_mast", "palette": "acid",
		"last_post": 2039, "moderator": "VALE NINE", "moderator_dead": false,
		"strap": "WAKE UP. THE STORM IS A BODY. I HAVE PROOF.",
		"lines": [
			"exhibit A: the pylons were built facing INWARD",
			"exhibit B: nobody has seen the ration board eat",
			"exhibit C: [image unavailable]",
			"they took my other site down. this one is mirrored.",
		],
	},
	{
		"id": "celloutz_support", "title": "CELLOUTZ CUSTOMER CARE",
		"url": "celloutz.xyz/support", "layout": "corporate",
		"requires": "ossuary_terminal", "palette": "corporate",
		"last_post": 2041, "moderator": "", "moderator_dead": false,
		"strap": "We value your continued function.",
		"lines": [
			"Your warranty covers the part, not the person.",
			"TICKET #77120 — CLOSED (no fault found)",
			"TICKET #77121 — CLOSED (no fault found)",
			"Was this article helpful?   [ YES ]   [ YES ]",
		],
	},
	{
		"id": "nix_ring", "title": "SCRAP MEDICS WEBRING",
		"url": "~nix/ring", "layout": "webring",
		"requires": "tunnel_mast", "palette": "moss",
		"last_post": 2036, "moderator": "NIX ARDEN", "moderator_dead": false,
		"strap": "14 sites · 11 dead · 1 redirects somewhere else now",
		"lines": [
			"« PREVIOUS   ·   RANDOM   ·   NEXT »",
			"joined 2031 · still standing",
			"if your site is gone email me. the address is gone.",
		],
	},
]


static func site(site_id: String) -> Dictionary:
	for entry in SITES:
		if str(entry.id) == site_id:
			return entry
	return {}


## I2.3. A site is a location. `emitter_id` is whatever the player is actually
## standing in range of — `signal_field.gd` already decides that from where they
## are — so a site you read at the Ossuary terminal is not readable in the
## Bone Yard, and no menu toggle changes that.
static func reachable_from(emitter_id: String) -> Array:
	var found: Array = []
	for entry in SITES:
		if str(entry.requires) == emitter_id:
			found.append(entry)
	return found


## I2.4. How long it has been dead, in the fiction's own calendar. Zero means it
## is still being updated by something, which is not the same as by someone.
static func years_dead(entry: Dictionary) -> int:
	return maxi(0, NOW_YEAR - int(entry.get("last_post", NOW_YEAR)))


static func is_dead(entry: Dictionary) -> bool:
	return years_dead(entry) >= 2


static func palette(name: String) -> Dictionary:
	match name:
		"bone":
			return {"ground": Color("17161a"), "ink": Color("d8d2be"), "accent": Color("b9a06a"), "link": Color("7fa0b8")}
		"rust":
			return {"ground": Color("1a120c"), "ink": Color("d8b48a"), "accent": Color("c1642c"), "link": Color("d7c25a")}
		"acid":
			return {"ground": Color("0b1206"), "ink": Color("caf07a"), "accent": ACID, "link": Color("ff5ca8")}
		"corporate":
			return {"ground": Color("101418"), "ink": Color("cfd8de"), "accent": Color("4e9ec4"), "link": Color("9fd0e6")}
		_:
			return {"ground": Color("0d1310"), "ink": Color("c3d2ae"), "accent": Color("7f9440"), "link": Color("b4da48")}


# --- I2.1: the primitives every bad site was made of -----------------------

## A tiled background. The single most reliable signal that a person made this
## page by hand and was pleased with it.
static func tiled_ground(canvas: CanvasItem, rect: Rect2, tint: Color, seed_value: int) -> void:
	var tile := 22.0
	var rows := int(rect.size.y / tile) + 1
	var columns := int(rect.size.x / tile) + 1
	for row in rows:
		for column in columns:
			var at := rect.position + Vector2(column * tile, row * tile)
			var alternate := (row + column) % 2 == 0
			var hashed := absf(sin(float(row * 71 + column * 31 + seed_value)) * 43758.5453)
			var patch := Rect2(at, Vector2(tile, tile)).intersection(rect)
			canvas.draw_rect(patch, tint * Color(1, 1, 1, 0.05 if alternate else 0.02))
			if fmod(hashed, 1.0) > 0.86:
				canvas.draw_rect(patch.grow(-6.0), tint * Color(1, 1, 1, 0.07))


## Text that will not sit still, because the person who built this learned one
## tag and used it.
static func marquee(canvas: CanvasItem, rect: Rect2, text: String, tint: Color, clock: float) -> void:
	var cap := 13.0
	var width := CellOutzType.width(text, cap, 1.4)
	var travel := fposmod(clock * 60.0, rect.size.x + width) - width
	canvas.draw_rect(rect, tint * Color(1, 1, 1, 0.06))
	# Drawn a glyph at a time and skipped outside the track. Godot's draw calls
	# do not clip to a rect, so the whole-string version printed the tail of the
	# message across the page margin and out into the browser chrome.
	var advance := CellOutzType.GRID.x * (cap / CellOutzType.GRID.y) + cap * 0.26 + 1.4
	for index in text.length():
		var x := rect.position.x + travel + float(index) * advance
		if x < rect.position.x - advance or x > rect.end.x:
			continue
		CellOutzType.draw_text(canvas, Vector2(x, rect.position.y + 4), text.substr(index, 1), cap, tint, 1.4)


## A hit counter with an implausible number on it, in the odometer style.
static func hit_counter(canvas: CanvasItem, at: Vector2, hits: int, tint: Color) -> void:
	var digits := "%07d" % hits
	var cell := Vector2(15, 21)
	for index in digits.length():
		var box := Rect2(at + Vector2(index * (cell.x + 2), 0), cell)
		canvas.draw_rect(box, Color(0.02, 0.02, 0.02, 0.9))
		canvas.draw_rect(box, tint * Color(1, 1, 1, 0.4), false, 1.0)
		CellOutzType.draw_text(canvas, box.position + Vector2(3, 4), digits.substr(index, 1), 13.0, tint, 0.0)


## The guestbook. Nobody has signed it since the moderator died.
static func guestbook(canvas: CanvasItem, rect: Rect2, entries: Array, ink: Color, accent: Color) -> void:
	canvas.draw_rect(rect, ink * Color(1, 1, 1, 0.04))
	canvas.draw_rect(rect, accent * Color(1, 1, 1, 0.45), false, 1.0)
	CellOutzType.draw_text(canvas, rect.position + Vector2(8, 6), "SIGN MY GUESTBOOK", 11.0, accent, 1.2)
	var font := ThemeDB.fallback_font
	var y := rect.position.y + 30.0
	for entry in entries:
		if y > rect.end.y - 12.0:
			break
		canvas.draw_string(font, Vector2(rect.position.x + 10, y), str(entry), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 11, ink * Color(1, 1, 1, 0.7))
		y += 16.0


## A ring of sites that mostly do not answer any more.
static func webring(canvas: CanvasItem, rect: Rect2, tint: Color, alive: int, total: int) -> void:
	canvas.draw_rect(rect, tint * Color(1, 1, 1, 0.05))
	canvas.draw_rect(rect, tint * Color(1, 1, 1, 0.5), false, 1.0)
	CellOutzType.draw_text(canvas, rect.position + Vector2(8, 6), "« PREV    RANDOM    NEXT »", 11.0, tint, 1.4)
	# A pip per member: lit if it still answers, hollow if it does not.
	for index in total:
		var at := rect.position + Vector2(10 + index * 13, 30)
		if index < alive:
			canvas.draw_circle(at, 4.0, tint)
		else:
			canvas.draw_arc(at, 4.0, 0.0, TAU, 10, tint * Color(1, 1, 1, 0.3), 1.0)


## Adverts for things that no longer exist, stacked because the page owner was
## paid per banner and there was no upper limit.
static func banner_farm(canvas: CanvasItem, rect: Rect2, count: int, seed_value: int, clock: float) -> void:
	var height := 26.0
	for index in count:
		var strip := Rect2(rect.position + Vector2(0, index * (height + 4)), Vector2(rect.size.x, height))
		if strip.end.y > rect.end.y:
			return
		var hue := fmod(absf(sin(float(index * 13 + seed_value)) * 43758.5453), 1.0)
		var tint := Color.from_hsv(hue, 0.55, 0.7)
		var blink := 0.65 + 0.35 * sin(clock * (3.0 + float(index)) + float(index))
		canvas.draw_rect(strip, tint * Color(1, 1, 1, 0.14 * blink))
		canvas.draw_rect(strip, tint * Color(1, 1, 1, 0.5), false, 1.0)
		CellOutzType.draw_text(canvas, strip.position + Vector2(8, 6), ["CLICK HERE", "FREE ORGANS", "SHE IS NEARBY", "WIN A LIVER", "NOT A SCAM"][index % 5], 12.0, tint * Color(1, 1, 1, blink), 1.6)


## The popup. It has a close button that is drawn but need not work.
static func popup(canvas: CanvasItem, rect: Rect2, title: String, body: String, tint: Color) -> void:
	canvas.draw_rect(rect.grow(3), Color(0, 0, 0, 0.5))
	canvas.draw_rect(rect, Color("1a1a1f"))
	canvas.draw_rect(rect, tint * Color(1, 1, 1, 0.8), false, 1.0)
	var bar := Rect2(rect.position, Vector2(rect.size.x, 18))
	canvas.draw_rect(bar, tint * Color(1, 1, 1, 0.3))
	CellOutzType.draw_text(canvas, bar.position + Vector2(6, 4), title, 10.0, Color(0.95, 0.95, 0.95), 1.0)
	var close := Rect2(Vector2(bar.end.x - 16, bar.position.y + 3), Vector2(12, 12))
	canvas.draw_rect(close, Color(0.7, 0.2, 0.2, 0.8))
	CellOutzType.draw_text(canvas, close.position + Vector2(3, 2), "X", 8.0, Color(1, 1, 1), 0.0)
	# Wrapped rather than clipped mid-word: a popup that cuts itself off reads
	# as a rendering bug rather than as a nuisance, and the nuisance is the joke.
	var label := Label.new()
	canvas.draw_multiline_string(ThemeDB.fallback_font, rect.position + Vector2(10, 40), body, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 11, 3, Color(0.85, 0.85, 0.85))
	label.free()


## I2.2. No two sites share a layout. Each one is drawn by its own arm of this
## match — different furniture, different order, different competence — because
## a template with a palette swap is a platform again, and a platform is the
## thing this is supposed to be the opposite of.
static func draw_site(canvas: CanvasItem, rect: Rect2, entry: Dictionary, clock: float) -> void:
	var colours := palette(str(entry.get("palette", "moss")))
	var ground: Color = colours.ground
	var ink: Color = colours.ink
	var accent: Color = colours.accent
	var link: Color = colours.link
	canvas.draw_rect(rect, ground)
	tiled_ground(canvas, rect, ink, str(entry.id).hash())

	var font := ThemeDB.fallback_font
	var lines: Array = entry.get("lines", [])
	var dead := is_dead(entry)

	match str(entry.get("layout", "forum")):
		"forum":
			# Centred masthead, a rule, then threads. Somebody's pride and joy.
			CellOutzType.draw_stamped(canvas, rect.position + Vector2(16, 12), str(entry.title), 20.0, accent, ARTERIAL * Color(1, 1, 1, 0.25), 2.0)
			canvas.draw_line(rect.position + Vector2(14, 42), Vector2(rect.end.x - 14, rect.position.y + 42), accent * Color(1, 1, 1, 0.5), 1.0)
			canvas.draw_string(font, rect.position + Vector2(16, 60), str(entry.strap), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 11, ink * Color(1, 1, 1, 0.55))
			var fy := rect.position.y + 84.0
			for line in lines:
				canvas.draw_rect(Rect2(rect.position.x + 14, fy - 12, rect.size.x - 28, 20), ink * Color(1, 1, 1, 0.04))
				canvas.draw_string(font, Vector2(rect.position.x + 20, fy), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40, 12, link)
				fy += 24.0
			guestbook(canvas, Rect2(rect.position.x + 14, rect.end.y - 92, rect.size.x - 28, 78), ["nobody has signed this since the moderator died."], ink, accent)
		"shop":
			# Left rail of categories, monospaced price list, an order that will
			# never ship. Automated and still taking your money.
			canvas.draw_rect(Rect2(rect.position, Vector2(96, rect.size.y)), ink * Color(1, 1, 1, 0.05))
			for index in 6:
				CellOutzType.draw_condensed(canvas, rect.position + Vector2(8, 16 + index * 22), ["TOLLS", "TEETH", "PASSAGE", "SCRAP", "BONDS", "HELP"][index], 11.0, link * Color(1, 1, 1, 0.8), 0.8)
			CellOutzType.draw_text(canvas, rect.position + Vector2(112, 14), str(entry.title), 17.0, accent, 2.0)
			marquee(canvas, Rect2(rect.position.x + 110, rect.position.y + 40, rect.size.x - 124, 22), str(entry.strap), accent, clock)
			var sy := rect.position.y + 78.0
			for line in lines:
				canvas.draw_string(font, Vector2(rect.position.x + 112, sy), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 128, 12, ink)
				sy += 20.0
			hit_counter(canvas, Vector2(rect.end.x - 130, rect.end.y - 34), 4120031, accent)
		"conspiracy":
			# No grid at all. Everything shouted, banners stacked, a popup.
			banner_farm(canvas, Rect2(rect.position + Vector2(rect.size.x - 190, 10), Vector2(178, rect.size.y - 20)), 6, str(entry.id).hash(), clock)
			CellOutzType.draw_stamped(canvas, rect.position + Vector2(14, 14), str(entry.title).to_upper(), 22.0, accent, ARTERIAL, 1.0)
			marquee(canvas, Rect2(rect.position.x + 12, rect.position.y + 48, rect.size.x - 210, 22), str(entry.strap), ARTERIAL, clock)
			var cy := rect.position.y + 90.0
			for line in lines:
				canvas.draw_string(font, Vector2(rect.position.x + 16, cy), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 220, 13, ink)
				cy += 26.0
			popup(canvas, Rect2(rect.position + Vector2(40, rect.size.y - 120), Vector2(230, 92)), "A MESSAGE", "you have been selected. do not close this window.", ARTERIAL)
		"corporate":
			# Flat, tidy, and saying nothing. The only site here built by people
			# who were paid, which is why it is the emptiest.
			canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 46)), accent * Color(1, 1, 1, 0.16))
			CellOutzType.draw_text(canvas, rect.position + Vector2(16, 14), "CELLOUTZ", 18.0, accent, 3.0)
			CellOutzType.draw_condensed(canvas, rect.position + Vector2(150, 20), "SUPPORT CENTRE", 11.0, ink * Color(1, 1, 1, 0.6), 0.9)
			canvas.draw_string(font, rect.position + Vector2(16, 74), str(entry.strap), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 13, ink * Color(1, 1, 1, 0.8))
			var oy := rect.position.y + 104.0
			for line in lines:
				canvas.draw_rect(Rect2(rect.position.x + 14, oy - 13, rect.size.x - 28, 1), ink * Color(1, 1, 1, 0.12))
				canvas.draw_string(font, Vector2(rect.position.x + 18, oy), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40, 12, ink * Color(1, 1, 1, 0.75))
				oy += 28.0
		_:
			# A ring. Mostly navigation, almost no content, which was the point.
			CellOutzType.draw_text(canvas, rect.position + Vector2(16, 16), str(entry.title), 18.0, accent, 2.0)
			canvas.draw_string(font, rect.position + Vector2(16, 48), str(entry.strap), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32, 11, ink * Color(1, 1, 1, 0.6))
			webring(canvas, Rect2(rect.position.x + 14, rect.position.y + 70, rect.size.x - 28, 48), link, 3, 14)
			var wy := rect.position.y + 140.0
			for line in lines:
				canvas.draw_string(font, Vector2(rect.position.x + 18, wy), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40, 12, ink * Color(1, 1, 1, 0.7))
				wy += 22.0
			hit_counter(canvas, Vector2(rect.position.x + 18, rect.end.y - 40), 219, link)

	# I2.4. The date is the whole point of a dead site. Stamped over the top,
	# because the page does not know it is dead and the player should.
	if dead:
		var note := "LAST POST %d — %d YEARS AGO" % [int(entry.last_post), years_dead(entry)]
		if bool(entry.get("moderator_dead", false)):
			note += "   ·   MODERATOR DECEASED"
		CellOutzType.draw_condensed(canvas, Vector2(rect.position.x + 14, rect.end.y - 16), note, 10.0, ARTERIAL * Color(1, 1, 1, 0.8), 0.9)
