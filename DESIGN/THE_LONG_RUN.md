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
