# The Long Run

Greg's build order for the game, dictated 2026-09-13 while the first
shareable demo was going out. Written down verbatim in substance so none of
it is lost, then sorted into the order it can actually be built in.

Nothing in here is done unless it says so. `FINAL_V.md` is still the authority
on the shader and the six dials; this is the sequence of work that hangs off it.

---

## What already landed on the demo build

- The interface no longer sits inside the psychedelic shader's screen grab, so
  the index, map, board and their page tabs stopped warping the moment you left
  the derby. (`bone_yard_hunt.gd`, `_order_hud_layers`)
- The retired orange HUD stopped resurrecting itself every time a panel closed.
- The transit plate went from acid green to blood, and now carries a goetic
  seal seeded off the destination, with runnels down the glass.
  (`interstitial.gd`)

---

## 1. The vat, first, because it is the first room anybody sees

The decanting floor is an early block-in and it is what a new player judges the
whole game by. In rough dependency order:

1. **The body model, then the hands.** Everything else in the room is looking
   at the body, so the body has to be worth looking at first.
2. **Link the chosen size and character size to the body model.** Character
   creation already asks; the mesh has to answer. Right now the two do not
   talk.
3. **The guy with the clipboard has to be visible.** He exists in the writing
   and not on screen.
4. **Fluid physics in the vat**, and the tube in your mouth that pumps sigils
   and information through the fluid — the tube is how exposition enters the
   character, not a cutscene.
5. **The other vats are gored**, each with a different person and a different
   body in it. One room, many outcomes of the same process.
6. **The interface in this room gets enlarged** — big, readable, clinical. It
   is a medical form, not a HUD.
7. **The birthday and the psychology tests have to actually occur** and
   actually feed the character, not be flavour text.
8. **Rebalance the races and the paths** down to a smaller, better set. Fewer
   options that each mean something.
9. **Walking out**: pull the tube out of your mouth, vomit graphically, and
   that is the transition into the Bone Yard. No loading plate for this one —
   it is the same continuous shot.

## 2. The Bone Yard, on foot

- People you can **ram, crush, break the bones of**, viscerally and
  specifically — not a damage number.
- **TouchDesigner rigging** driving how the bones and the body actually break.
- Loose things in the world with weight: **gore, body parts, items, energy
  drinks, drugs, currency**, and the things that orbit a person — **floating
  heads, demons, sigils**.

## 3. The car, which is currently a tank

- The car **HUD comes from the assets**, not from placeholder labels.
- **Cars break.** Damage is structural and visible.
- Cars stop being massive tanks and become **fightable NPCs** — shootable,
  moveable, something you can put a hand through the window of.
- Once you have killed who you needed to, **you get out of the car properly**
  and transfer out into the colosseum — the massive derby.
- The **head of the colosseum** is a person you talk to, and he quests you.

## 4. The brain, which is the real interface

The mainline file in your head, opened as a tutorial and expanding as you
explore — the Psychonauts brain-compartment idea, with the visuals coming
through TouchDesigner and After Effects.

Files in the head, at the start:

- A **CellOutz advertisement and website**.
- **Audio logs in Greg's own voice, distorted**, and the blogs from
  **celloutz.xyz**.
- A **Wizards Only Foolz fake promo site** — advertising you carry around
  inside your own head.
- The **main file from the start**, which further down the line you may be
  able to change.

More files open as you explore. The **quest log lives here**: not a list of
tasks, a list of what you have not figured out yet.

## 5. The tower, and the first nemesis

After you get out, a **massive 8G/9G tower** is visible — so insane on sight
that it gives you a vision.

- The vision is the **Photoshop PSD of Death, animated live**.
- The **After Effects animation is linked into the game's UI**.
- **The haunting edit is the boss** — the first target the nemesis system
  produces.

## 6. Across all of it

- **All the TouchDesigner effects**, wired through the one shader rather than
  built as separate systems (`FINAL_V.md` §16).
- **Better fonting throughout the game and the HUDs.** `celloutz_type.gd`
  already draws condensed and stamped faces; the rest of the game has to stop
  falling back to the engine default.
- **The main intro and settings screen** gets the same treatment as the
  transit plate — red, gore, sigil work, not a column of buttons.

---

## Order of work

The vat first, because it is the first room and it is the weakest. The brain
second, because the quest log and the tutorial both live in it and everything
downstream needs somewhere to be explained. The car third, because it is
playable now and merely wrong rather than missing. The tower and the nemesis
boss last, because they need the After Effects and Photoshop work to exist as
files before they can be wired into anything.

Fonting and the intro screen are not a phase — they are a pass that happens
alongside whichever of the above is being touched.

---

# Second dictation, 13 September 2026

Sent while the demo build was going out and being played. Recorded the same
way: substance kept, sorted afterwards. Anything already built is ticked in
`CHECKLIST.md` under AG4 rather than repeated here.

Greg also shared `C:/Users/Greg/Downloads/huiii_260912_212921.pdf` (5 MB),
which has not been read yet and should be before any of the art direction below
is acted on.

## The inventory, which does not exist yet

The biggest single gap Greg names, and he names it three times:
*"i still dont see any inventory i see the carry but the brain inventory body
on the personal character"*.

- Slots, loosely like Unturned — a grid you arrange, not a list.
- **Body, organs and cybernetic limb upgrades** done from inside it.
- **Brainchip memory, drug storage, and mainline quest storage** living in it.
- **Clicking through from the inventory into the brain mainline quest.**
- Weapon attachments, and melee attachments, deliberately stupid — TABG rather
  than tactical. High-quality gun customisation alongside it.

## Skins, crates and the first currency

- CS:GO-style lootbox crates, rarities, the lot — knowingly ridiculous.
- **Skins generated from Greg's own Photoshop and Affinity textures and
  photos**, through TouchDesigner, rather than authored one at a time.
- This is what finally justifies a temporary currency system.
- Reached by holding shift with the wheel key to lock it open, then into
  customisation.

## Talking to people

Hacker-man X / Fallout / Oblivion: walk up to an NPC, the camera settles onto
their face, and you begin speaking. Three ways in, all live at once:

- Proximity voice chat (the system already exists).
- Write your own dialogue.
- Pick from prewritten lines.

## The world, and how many people are in it

- **Far more people**, across the different races, with authorities among them,
  carrying weapons.
- **Shops with insides. Houses with tops.**
- The map rebuilt on Greg's own art textures, with smart generation behind it.
- The map integrating the underground conspiracy-network text file.
- Marketplaces and an economy; the remaining phone/index apps built out.

## Physics, and gore that means something

- **Destruction physics, water/liquid physics, bullet physics, chunk physics.**
- Those synergised with the gore rather than sitting beside it: gruesome,
  specific deaths.
- **Slow-motion executions**, Fallout VATS or Hitman in register.
- Bones that break through TouchDesigner rigging when you ram or crush someone.

## Look and sound

- *"i hate the look of this ui it looks ugly"* — the bottom-right cluster
  especially. Boxes: dimensional, 3D-and-a-bit HUD panels rather than flat
  strips. The phone as a black mirror object with real depth, clickable, and
  observable *in* the mirror rather than only as a phone.
- Fonts and style throughout: grungier, gorier, biopunk.
- A full sigil rework in metals, blood and copper — binding sigils.
- The radio: fix the volume and give it a real use in play.

## Airships

Old-style blimps and airships. Nausicaa-era Ghibli steampunk, but apocalyptic.
This is section AV's register, now that it has one.

## Quests that come from what you do

Once there are enough NPCs: the game asking you to **photograph ritualistic
murder**, with stat boosts hanging off it. The photograph verb already exists
(N); what is missing is anything asking for one.

## Saves

Deletable save files, continue-game, several of them — so somebody handed the
build can keep a world and generate new stories in it. Named as a thing friends
need, which makes it demo-blocking rather than long-run.

## A trailer before the demo

An After Effects / Photoshop piece with real typography that tells the story and
shows a visualised game demo — shipped *before* the playable one.

---

## What this changes about the order

`Saves` moves to the front: it is the only item here that people already
holding the build are blocked by. `Inventory` follows, because three separate
messages are about things with nowhere to live without it, and the brain
mainline quest is reached through it. Physics and the map rebuild are the big
middle. Skins, crates and currency sit on top of the inventory and cannot start
before it. The trailer is parallel work in other tools and waits on none of it.
