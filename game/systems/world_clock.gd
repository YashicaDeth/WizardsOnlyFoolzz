class_name WorldClock
extends RefCounted

## W1.1. The hour.
##
## A9.7 v2 asked for something small — *"stations have a schedule; the dial is
## the same at 3am as at noon"* — and turned out to be blocked on something the
## project has never had: **there is no time of day in this game at all.** No
## clock, no day, no night, no hour anything can ask for. W1.1 has been sitting
## unticked with five other things quietly depending on it:
##
##   - **A9.7** stations that keep hours, which is what sent me here.
##   - **W1.4** factions keeping hours, and the Wire being busier at some of them.
##   - **AB2.4** damage repairing over a month of game time.
##   - **AJ4.3** a practice you stop practising decaying.
##   - **AL1.5** interest accruing while you are away.
##
## Every one of those needs the same thing, so none of them should invent it.
##
## Deliberately not an autoload. It is a pure function of one number that lives
## in `WorldHistory` — which already persists, already migrates safely, and is
## already the thing this project treats as the record of what is true. Adding a
## sixth autoload to hold a float would be a worse answer.

## How much game time passes per real second. At 0.4, one complete day takes
## sixty real minutes. The former 1.0 rate made a day only twenty-four minutes
## long and the light visibly ran away while a player was reading or fighting.
## Sleeping and authored time skips still pass world-hours directly.
const MINUTES_PER_SECOND := 0.4

const MINUTES_PER_HOUR := 60.0
const HOURS_PER_DAY := 24.0
const MINUTES_PER_DAY := MINUTES_PER_HOUR * HOURS_PER_DAY
## Thirty days. Long enough that AB2.4's "repairs after a month" is a real wait
## and short enough that a player who keeps a save will see one turn over.
const DAYS_PER_MONTH := 30.0
const MONTHS_PER_YEAR := 12
const REGULAR_DAYS_PER_YEAR := 360
const DAYS_PER_YEAR := 365
const MONTHS_PER_SEASON := 4
const SEASON_NAMES := ["ASHFALL", "EMERGENCE", "REAPING"]
const MONTH_NAMES := [
	"ASHWAKE", "RUST RAIN", "CINDER FLOOD", "BLACK BLOOM",
	"SPOREWAKE", "BONE RISE", "MARROWTIDE", "LONG STATIC",
	"RED HARVEST", "HOLLOW SUN", "LAST ROT", "QUIET PYRE",
]
const UNCOUNTED_DAYS := ["THE FOOL", "THE WOUND", "THE MIRROR", "THE WIRE", "THE FLAME"]

## Where the day starts. Not midnight: a run opens in the afternoon, so the first
## thing a new player meets is the light going, which is the register this world
## is in.
##
## It opened at 16:30, and that put the light going *before the player had it*.
## Full daylight runs to 18:30, which from 16:30 is two world hours -- five real
## minutes at MINUTES_PER_SECOND. The opening alone spends that: the examination
## takes about half a minute of it, the derby the rest, and the player surfaces
## into the bone yard after dark, where `_update_day_night()` drops the sun to
## 0.08 because night here is authored to be genuinely black.
##
## 13:00 keeps the register -- it is still the afternoon, the light still goes
## while you watch -- and gives the opening chain somewhere to happen first.
## The rate is the deeper lever and is deliberately not touched here: at 0.4
## world-minutes a second a whole day is an hour of play, which is a pacing
## decision for the game rather than a bug in this constant.
const OPENING_MINUTE := 13.0 * MINUTES_PER_HOUR


## Advance the world by a frame. Called once, by whichever scene owns the world;
## everything else reads. Returns the new absolute minute.
static func advance(delta: float) -> float:
	var now := minutes() + delta * MINUTES_PER_SECOND
	WorldHistory.world_minute = now
	return now


## Absolute minutes since this world began. The one stored number.
static func minutes() -> float:
	return WorldHistory.world_minute


## 0.0 to 24.0. Fractional, because a sky that steps hourly is worse than no sky.
static func hour() -> float:
	return fmod(minutes(), MINUTES_PER_DAY) / MINUTES_PER_HOUR


## Which day. Starts at 1, because nobody says "day zero" out loud.
static func day() -> int:
	return int(minutes() / MINUTES_PER_DAY) + 1


## How far through the month, 0..1. For anything that repairs, accrues or decays
## on a long schedule rather than a daily one.
static func month_progress() -> float:
	return fmod(float(day() - 1), DAYS_PER_MONTH) / DAYS_PER_MONTH


## How many months have turned over. AB2's repair pass reads this.
static func month() -> int:
	return int(float(day() - 1) / DAYS_PER_MONTH) + 1


## The civil calendar of the Ashbloom Expanse. It deliberately uses twelve
## thirty-day months arranged as three seasons, then five dangerous days that
## belong to no month. Those five are not a thirteenth month: institutions can
## date them, but cannot pretend they are ordinary working days.
static func calendar_date() -> Dictionary:
	var absolute_day := day() - 1
	var year_index := absolute_day / DAYS_PER_YEAR
	var day_of_year := absolute_day % DAYS_PER_YEAR
	if day_of_year >= REGULAR_DAYS_PER_YEAR:
		var outside_index := day_of_year - REGULAR_DAYS_PER_YEAR
		return {
			"year": year_index + 1,
			"day_of_year": day_of_year + 1,
			"uncounted": true,
			"uncounted_day": outside_index + 1,
			"name": UNCOUNTED_DAYS[outside_index],
			"season": "OUTSIDE THE YEAR",
			"month": 0,
			"month_name": "",
			"day": 0,
			"decan": 0,
			"day_in_decan": 0,
		}
	var month_index := day_of_year / int(DAYS_PER_MONTH)
	var day_in_month := day_of_year % int(DAYS_PER_MONTH)
	return {
		"year": year_index + 1,
		"day_of_year": day_of_year + 1,
		"uncounted": false,
		"uncounted_day": 0,
		"name": MONTH_NAMES[month_index],
		"season": SEASON_NAMES[month_index / MONTHS_PER_SEASON],
		"month": month_index + 1,
		"month_name": MONTH_NAMES[month_index],
		"day": day_in_month + 1,
		"decan": day_in_month / 10 + 1,
		"day_in_decan": day_in_month % 10 + 1,
	}


## Compact enough for the shared header of the handheld, and strange enough
## that the player immediately knows this is not the Roman calendar in costume.
static func calendar_stamp() -> String:
	var date := calendar_date()
	if bool(date["uncounted"]):
		return "%s // YEAR %d" % [date["name"], date["year"]]
	return "%s %02d // DECAN %s // YEAR %d" % [
		date["month_name"], date["day"], _roman_decan(int(date["decan"])), date["year"]]


static func _roman_decan(value: int) -> String:
	return ["I", "II", "III"][clampi(value - 1, 0, 2)]


## What the hour is called. Five names rather than four: the hour before dawn is
## its own thing in every culture that has ever had to be awake for it, and this
## game has a use for it.
static func phase() -> String:
	var at := hour()
	if at < 4.0:
		return "deep night"
	if at < 6.5:
		return "before dawn"
	if at < 8.5:
		return "dawn"
	if at < 17.5:
		return "day"
	if at < 20.0:
		return "dusk"
	return "night"


## How light it is, 0 (dark) to 1 (full). A curve rather than a lookup, so
## anything reading it for a sky, a shadow or a stealth check gets something
## continuous. Peak is deliberately short of noon — this place does not get a
## bright day.
static func daylight() -> float:
	var at := hour()
	# Sunrise near 7, sunset near 19, with real twilight either side.
	if at <= 5.0 or at >= 21.0:
		return 0.0
	if at < 7.5:
		return ease(inverse_lerp(5.0, 7.5, at), 2.0)
	if at > 18.5:
		return ease(1.0 - inverse_lerp(18.5, 21.0, at), 2.0)
	return 1.0


## True when somebody would call it night. For the many callers that want a yes
## or no and should not each pick their own threshold.
static func is_night() -> bool:
	return daylight() < 0.12


## A clock face. 24 hour, because every institution in this world would.
static func stamp() -> String:
	var at := hour()
	return "%02d:%02d" % [int(at), int(fmod(at * MINUTES_PER_HOUR, MINUTES_PER_HOUR))]


## The full line, for anything that prints one: date, clock face and light phase.
static func long_stamp() -> String:
	return "%s  //  %s  //  %s" % [calendar_stamp(), stamp(), phase().to_upper()]


## Set the hour directly. For harnesses that need a specific time, and for
## anything in the fiction that skips time — sleeping in the room (AH1.2) is the
## obvious one. Never goes backwards: the world's clock is a ledger like
## everything else here, and a run that can rewind its own history is a run
## where nothing that depends on elapsed time can be trusted.
static func set_hour(target: float) -> void:
	var wanted := clampf(target, 0.0, HOURS_PER_DAY)
	var today := float(day() - 1) * MINUTES_PER_DAY
	var at := today + wanted * MINUTES_PER_HOUR
	if at <= minutes():
		# Already past it today, so they mean tomorrow.
		at += MINUTES_PER_DAY
	WorldHistory.world_minute = at


## Sleep, in hours. Returns how long actually passed, which is not always what
## was asked for — something can wake you.
static func pass_time(hours: float, interrupted_at := -1.0) -> float:
	var asked := maxf(hours, 0.0)
	var actual := asked if interrupted_at < 0.0 else minf(asked, interrupted_at)
	WorldHistory.world_minute = minutes() + actual * MINUTES_PER_HOUR
	return actual
