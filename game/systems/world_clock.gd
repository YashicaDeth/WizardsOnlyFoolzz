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

## How much game time passes per real second. At 60, one real minute is one game
## hour and a day takes twenty-four real minutes, which is roughly where
## survival games land and is short enough that a player sees a night in a
## session without a day feeling like a stopwatch.
const MINUTES_PER_SECOND := 1.0

const MINUTES_PER_HOUR := 60.0
const HOURS_PER_DAY := 24.0
const MINUTES_PER_DAY := MINUTES_PER_HOUR * HOURS_PER_DAY
## Thirty days. Long enough that AB2.4's "repairs after a month" is a real wait
## and short enough that a player who keeps a save will see one turn over.
const DAYS_PER_MONTH := 30.0

## Where the day starts. Not midnight: a run opens in the late afternoon, so the
## first thing a new player meets is the light going, which is the register this
## world is in.
const OPENING_MINUTE := 16.5 * MINUTES_PER_HOUR


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


## The full line, for anything that prints one. "DAY 3 // 03:42 // DEEP NIGHT".
static func long_stamp() -> String:
	return "DAY %d  //  %s  //  %s" % [day(), stamp(), phase().to_upper()]


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
