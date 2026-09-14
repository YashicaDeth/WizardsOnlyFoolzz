# Playtest, 14 September 2026 — Greg, full run, spoken live

Greg played the 17:50 build end to end and talked through it. This is that pass,
kept close to his words. Nothing here is softened, including where the thing he
is describing is something I built this session.

**Sorted so the bugs are separable from the art direction**, because roughly a
third of this is "that is broken" and the rest is "that is bad", and they need
different people.

---

## A. Bugs — things that do not work

| # | What | Where |
| --- | --- | --- |
| A1 | **You can fall out of the world.** "You walk to the end of this room and then there's just a skybox... I just fell out of the skybox." | end of the facility corridor, after the vat |
| A2 | **Blood hangs in the air.** "There's like eight little circles in the air of blood... blood stays in the air and then eventually it goes away." | Hunt Grounds, melee |
| A3 | **Two black circles float above attacking NPCs.** | Hunt Grounds |
| A4 | **You can walk through a massive block.** "So it doesn't even feel real." | Hunt Grounds |
| A5 | **Green and orange circular objects block the car.** "Fully block the car half the time from driving." | derby |
| A6 | **The handheld does nothing.** "When you're in your device in the G tab you can't even do anything. You can't use the ritual app." | everywhere |
| A7 | **The gore choice does not persist.** "When the gore comes up saying unrestricted, that should save once you've done it." | warning card |
| A8 | **The races are not the specified races.** | vat / character creation |
| A9 | **Velocity is unitless.** Reads "0 1 5"; should be real km/h. | derby |

A7 is already diagnosed: there are two separate settings screens and the menu's
gore cycle writes the value but never calls `apply_gore_setting()`.

## B. The cold open — mine, and he does not like it

> *"This stuff is too fast, and it shows too little, with too much being on the
> screen with too little being said and too little going on visually."*
>
> *"'A company grew you. Being half of the other thing is how you leave.' That's
> dumb as fuck. I hate that."*
>
> *"I'm so sick of the skeleton in the transitions and screens because they just
> look so bad."*

Taking that as written. The fourth card is the one he named and it is the one I
wrote as the thesis statement; it reads as the game explaining itself, which is
exactly what the surrounding comment in `decanting_prologue.gd` says it must not
do. The cards are also paced wrong — too fast to land, too sparse to look at.

The skeleton motif recurring across transitions and loading screens is a
separate complaint and a broader one.

## C. Character creation — the largest single block of notes

The vat/clipboard screen drew more criticism than anything else in the run.

**The vat itself.** The box on the right should be a **circular vat**, a full 3D
model, and the character inside it should be fully customisable and visible
there. His reference is the Matrix pod — "something gnarly". The fluid should be
"bloody and disgusting", visceral, not the current green.

**The clipboard.** "The clipboard looks dog shit" — too large, with the text on
it far too small to read. "CELLOUTZ GROWING FLOOR" is unreadable. The small
blood stain at the bottom "just looks dumb".

**The controls.** Mouse should work throughout. Presets (authored / canonical /
random) exist but barely change anything — "all the head changes kind of". He
does not know what "INTAKE" means.

**What it should be.** Explicitly: *"Make it like the Fallout character
customisation screen, but way better UI and HUD."* Plus three things that do not
exist at all — a real **psychology test**, a **birthday** entry, and a real
**points distribution** system. Traits, body and evolution all need rework.

**The handler.** The character on the left who talks at you should:
- be talked *back* to,
- fill the left side of the screen,
- wear a wizardly cape — "an elite pyramid head, whatever, creep, fucking insane",
- have evil eyes,
- physically hand you the clipboard at the start.

He reached for a specific character reference and could not name it; do not
guess at it, ask him.

## D. The vat, and the walk out

- **The tube.** There should be something in your mouth, Matrix-style, that you
  can only pull out once you are broken out. Currently "you can't even see that
  there's anything in your throat".
- **The corridor.** Walls look bad. The walk is too long.
- **The other vats** read as "a straight copy from Fallout 4". The facility
  should be genuinely disturbing and visceral.
- **Canon break:** "You don't have your shift, you don't have your tab, you
  don't have your anything, because nothing's even happened canonically. Then
  suddenly you get all that shit when you get out of the car." The kit arrives
  without the fiction ever granting it.
- **The route to the derby makes no sense.** There is a light at the end of a
  corridor and no logic connecting it. *"The derby should be underground."*

## E. The derby

- HUD top-right reads `SCR`, `WRK12`, `MEM` — "none of that means anything".
- A player model appears top-left labelled DRIVER INTACT with no setup.
- Cars do not read as cars. Other racers "look like tanks" and you only see
  heads sticking out the top.
- **No third-person view of your own car.**
- Damage is not communicated — "the way it breaks doesn't tell you".
- The bottom-left cluster (hull, path, load) should be **bigger**.
- The ground is "not properly dry".

## F. The Hunt Grounds

- The green/blue cast is "just gross".
- An unexplained "mirror box thing with a red outline" spawns where you arrive.
- Melee works and escalates well — *"once you use the sword a lot you get really
  gory and it starts giving really weird effects"* — but **guns do not**.
- Loot does not make sense.
- **The map is the strongest thing in the build**: "the map is really nice". It
  still needs work — the circles read as "a bunch of Paimon" rather than as
  survey data.

## G. Things he liked

Worth recording, because almost nothing in the run was praised and these are the
parts to protect:

- **The map.** Named explicitly as good.
- **The world itself.** "I like the world."
- **Melee escalation.** The gore ramp as you keep using the sword.
- **The F1 key help in the derby.** *"I love the F1 keys. That should be in every
  menu, including the gore sandbox."* — this is a concrete, cheap, high-value ask
  and it should be done everywhere.
- **The CellOutz in-transit loading screen**, from the previous pass.

## H. His summary

> *"The main game just needs so much work gameplay-wise. Like, it doesn't even
> work properly."*

That is the honest state and it should not be argued with. The systems inventory
is deep — anatomy, substances, the map, the ledger, the tree — and the
connective tissue that makes them a *game* is mostly missing. Section `P` (the
demo) is 39 items and 0 done, which is the same observation in checklist form.


---

## I. The derby, as it is actually meant to be

Spoken straight after the run, unprompted — this is a design target, not a bug
list.

**It is an underground coliseum.** A demolition derby in a facility big enough
not to feel squished, with **stands full of spectators** — different races,
robots, elites, reptilians, aliens — watching. There are people and models on
the floor you can **run over, kill and gore**.

**You fight from the car.**
- **Right mouse shoots while driving.** You kill the other drivers.
- You shoot **through their windscreen**.
- There is no proper gun model today.
- *"You're trying to fight for your freedom."*

**The cars are cars.**
- Every racer drives a car that looks like **yours**, at **your level** — not a
  character model sitting above the chassis like a tank turret, which is what it
  reads as now and why you cannot shoot or destroy them.
- **Doors.**
- **Switchable third and first person.**

## J. The combat rework, in his words

> *"Really make sure that the combat is really fun, new, fresh, realistic, but
> like not."*

- **One-shot headshot kills** — if you are serious about it, and if you hit the
  right part of the brain.
- **X-ray kill cameras in the Sniper Elite 4 register**: the round tracked into
  the body, eyeballs popping, a groin shot that destroys.

This is worth cross-reading against what already exists rather than starting
over. `AnatomyComponent` already models zones, organs, bones and whether a hit
penetrates; `BaselineHuman` already has `reveal_organs()` and `see_through()`
for the X-ray; the gore sandbox already has a working X-ray key. The Sniper
Elite pass is much closer to "aim the existing X-ray at a kill and hold it"
than it is to a new system.

Likewise the one-shot headshot: `AnatomyComponent` already drops a body when a
critical zone reaches zero and already ruptures a fatal organ on a penetrating
head hit. What is missing is the *lethality curve*, not the anatomy.
