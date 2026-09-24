# Arriving in the overworld, and what happens out there

Greg's direction, 24 September 2026. Decisions are his; **Assistant proposals**
are not.

## Greg's words

> "each exit scenario starts your exit and reimagination of the overworld
> cutscene form the viewpoint where you exit from which opens up the map and
> different settlements nearby which you can begin exploring the map and it
> sends you down different quest and exploration spirals through using
> psycology techniques to keep players playing make an ai that isinterested in
> playing the game and then trick it into interacting with the game for as
> long enough as possible that it turns it into a good gameplay simulkation to
> learn what to make the funnest normal gameply exploration is, imagine gta and
> rdr2 random events that can happen generate insane hunderdfs of scenarios
> that play out mijni cutscenes which then can seugeway to quests or sudden
> boss or mini boss fights, for example someone trying to run you over in
> there car and going crazy, or a tribe of old man wizards who envoke and cast
> visions of the spirits ingame which are animated as somewhat holograms ingame
> but not as they are rendered models in the game lke the characters, and the
> old wizards could be traders ect make them look like the eastern orthodox
> monks in the blakc and white fgarbs with the hoodies that have ther sigils
> and insane but then instead of just white and black make it blood stained and
> creased destoryed sigikls"

## Decided

- **Every exit gets its own arrival reveal.** The camera rises from the exact
  spot the player came out of and sweeps over the real overworld, marking the
  nearby settlements on the map as it passes them. Each exit's reveal is
  different because each exit is somewhere different.
- **Then exploration spirals.** The reveal opens the map and the nearby
  settlements, and exploring sends the player down quest and exploration
  spirals built with psychology techniques that keep players playing.
- **An AI player to learn what's fun.** A curiosity-driven bot inside Godot
  that plays unattended for hours, is drawn to whatever is new, and logs what
  held its attention and what it abandoned. The game is built to keep it
  interacting as long as possible, and those logs are how we learn what
  normal exploration is most fun.
- **Hundreds of GTA / RDR2-style random events,** made by a generator from
  written parts: who, what they want, where, what they do, how it escalates.
  Each one plays as a mini cutscene and can turn into a quest, a trade or a
  sudden boss or mini-boss fight. Greg approves the parts.
- **Example events:** a driver who tries to run you over and goes crazy; a
  tribe of old-man wizards who invoke spirits and cast visions of them.
- **The wizard monks are a splinter of the wizardsonlyfoolz**, the mage
  collective in `DESIGN/COSMOLOGY.md`. They broke from the guild, and the
  guild wants them gone. They can also be traders.
- **How the monks look:** Eastern Orthodox monks in black-and-white habits
  with hoods covered in their sigils, but blood-stained and creased, with
  the sigils destroyed. Not clean black and white.
- **How their spirits look:** animated as something like holograms, **not**
  rendered as models the way the characters are.

## Assistant proposals, not confirmed

- **The reveal uses the exit data that already exists.** Every route in
  `systems/facility_routes.gd` already hands the surface a `surface_position`.
  The reveal starts there, so a new exit gets its reveal for free.
- **Spirals as open loops, not timers.** Techniques that fit the game's
  existing rules (no countdown UI, a world that keeps records): a landmark
  you can see but haven't reached; an event that ends on a question
  answered two settlements away; rewards that come at unpredictable
  intervals; a person you spared who turns up again; and every quest
  finishing by pointing at the next unexplored thing.
- **The bot's "interest" is novelty with boredom.** Things it hasn't seen
  pull it in; repetition wears it out. It logs time spent, what it walked
  away from and where it got stuck, so a night of runs produces a ranked list
  of events by how long they held it, plus the ones it abandoned.
- **Event parts, first cut:** roughly a dozen actors × a dozen wants × a
  handful of places × a handful of escalations gives several thousand
  combinations before any are hand-tuned. The driver and the monks are the
  first two actors, written in full.
- **Spirits as projected, flat, flickering figures.** Billboarded animated
  layers with the hologram treatment (scanlines, colour split, dropouts),
  never lit like the bodies. TouchDesigner loops can replace the placeholder
  animation, as for the doctor's call.

## Still open

- What the monks trade, and what they want in return.
- What the spirits are, the dead or the planes, and whether they are real.
- Why the splinter left the guild.
- How far out the first spiral reaches before it loops back.
