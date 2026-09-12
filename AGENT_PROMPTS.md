# Prompts for the other agents — 12 Sep 2026, late

Copy one block per agent. Each is self-contained: an agent that reads only its
own block has everything it needs.

**Before anything else, every agent:** work in your own worktree, not in
`P:\GameDev\AllusionsTooGrandeur`. Three times today an agent has edited the
shared checkout directly, and once it left a half-finished merge that broke
every run. `git -C <your worktree> status` should be the first thing you type.

Read `CHECKLIST.md` for the detail on any item id below. It now runs A–Z then
AA–AN, 40+ sections. Rules that apply to all of you:

- **I0**: no screen is a list of text in a box. It does *not* mean the player
  gets no information — that misreading is what stripped every readout out of
  the derby and produced the second playtest's first complaint. An instrument is
  not a text box. A gauge is allowed.
- **Rule 3**: every hard cut is a bug.
- **The version ladder**: ticking `vN` means writing `vN+1` with a real fault it
  exposed. A version that cannot name a fault is not written.
- **Never claim a visual result you have not looked at.** Capture it, open the
  PNG, and describe what is actually in it.
- Satire aims at institutions, never at congregations or any group of people.
- No assets or implementations lifted from commercial games. Experiential
  reference only.

---

## Agent A — the body is the weapon (AN), and movement (AD)

The biggest open thing in the project, and Greg has asked for it four separate
times. He is explicit about the direction now:

> *"i wanna make the hands kinda floppy... the combat with the floppy arms as
> swords is so fun, i want to rework that system into something new but keeping
> that fun of the movement"* — and the playtester, on the same thread: *"the
> physics base fighting — like with shooting, the gun swivels with where you
> aim, and sorta moves around with the momentum"*.

**`game/systems/limb_momentum.gd` already exists — written this session.** It is
the spring-damper core: the weapon is a mass on the end of an arm, where you
point is where the *anchor* goes, and the weapon lags, overshoots and swings
through. `head_speed()` measures how fast the business end is genuinely
travelling; `commitment()` turns that into 0..1.
`tests/limb_momentum_test.gd` proves a committed sweep beats a flick, that
heavier weapons trail further, that it settles, and that it never detaches.

**It is not wired to anything.** That is your work — and please do not repeat the
M2 mistake, where a module was ticked off on a screenshot and then sat unused
for days while the thing it was built for stayed broken.

1. **AN1.2** Drive it from `bone_yard_hunt.gd`: feed it the same mouse delta the
   camera turns by, plus the player's own velocity. Walking into a blow counts.
2. **AN1.3** Draw the weapon through `pose()` rather than through the current
   animation. This is the whole visible half.
3. **AN1.4** Damage asks `commitment()` instead of reading a constant off the
   weapon. The weapon sets the ceiling; the player earns how much of it they get.
   This is the actual design change — everything else is support for it.
4. **AN1.5** `carry()` per weapon. Mass and reach are the balance conversation
   now: a bare hand about 0.4kg, a cleaver 1.4, a sledge 6.
5. **AN1.6** `fatigue` from stamina, so a tired fighter genuinely cannot hold a
   guard rather than being told they cannot.
6. **AN1.7** Firearms run through the same object: the barrel swivels toward
   where you are looking and carries momentum past it. TaKeS asked for this by
   name.
7. **AD1.1–AD1.5** Jumping, vaulting, mantling, wall running, and momentum
   carrying between them. Section AD is still at zero and Greg has called it his
   priority more than once.

Do not delete the existing swing system until the new one is better. Run them
side by side behind a flag if you need to.

---

## Agent B — the room, the cloud, and the tutorial web (AH)

Greg's largest new idea, and it answers every item in AG2 ("what the playtester
could not find") far better than a tooltip would:

> *"the black mirror is crazy... i want you to make it a room on the phone
> somewhat, when you check the pinboard then you can be in a room with a massive
> mirror on the wall and a bed, and then you can turn to the conspiracy quest
> board, and then to your right you can look into like a neuralink or some cloud
> connect thing and see the tutorial like a cloud software and its like 'remember
> the cloud' and you repair the fragments of the cloud of archival information
> which is the tutorial software parts"*

**The tutorial is a place, and getting it is a mechanic.** You do not read help;
you recover it, fragment by fragment, out of something that used to know
everything and has been decaying since before you arrived.

1. **AH1.1–AH1.7** The room. Opening the Board puts you *in* it rather than on a
   screen. A bed, a wall-sized mirror, one window's worth of light. Turn to the
   wall for the Board — `game/systems/pin_board.gd` is built and works, it just
   needs to be on a wall instead of filling the screen. Turn right for the cloud
   terminal. Leaving is a movement, not a menu close (Rule 3).
2. **AH1.5** The mirror shows your body, current, with everything that has been
   done to it. `BaselineHuman` already renders exactly this for the dossier.
3. **AH2.1–AH2.6** REMEMBER THE CLOUD. Fragments are *repaired*, not unlocked —
   the verb is restoration, and it costs something the player actually has. The
   archive is visibly incomplete forever. It talks like cloud software written
   by people who are now dead.
4. **AH3.1–AH3.8** The tutorial web. A node web where the connections mean
   something, not a list. Each node is a CRT set — curved, scanlines, real tube
   falloff — playing the mechanic as a short *drawn* loop, with a paragraph in
   the game's voice underneath and, critically, **the keys**. That last part is
   what AG2 was actually asking for. Nodes unlock alongside the Board from what
   the player has actually done; a locked one shows static and the shape of what
   is missing.

`systems/celloutz_type.gd` has the display face and `code_rain.gd` the
substrate. Do not import a font.

---

## Agent C — the double pyramid (AI), and the seals on the board (E2.4)

Two things, both visual, both with references Greg supplied directly.

**AI — the pyramid.** Greg sent three charts (the occult hierarchy pyramid,
*Hierarchy of the Old World*, the gods/demigods/mortals stack) with one
instruction: *"the pyramid structure in the tab map and everything needs to be
rework with this inspiration... also the pyramids should be like upside down and
then up top"*.

Two pyramids meeting at a point. Upright above, inverted below. **As above, so
below** — and that is not decoration, it is the two-axis system the game already
has: AA hands a holding to the ascent or to corruption, and those are the two
cones. The player stands at the waist, where they touch.

1. **AI1.1–AI1.7** The Tree page becomes the double pyramid. Tiers as strata with
   real edges, not a list with indentation. Density carries meaning — the base is
   crowded, the apex is one thing. The references are legible at a glance *and*
   reward an hour of reading; match both.
2. **AI2.1–AI2.6** Every tier populated from `WorldHistory`, not authored.
   Factions sit where their power actually is, and they move. The player's own
   position is computed. The Board's theories pin onto it — the two charts are
   one document. Marginalia in the corners the way the references carry it.
3. **AI2.5** is a hard line: satire aims at institutions, never at congregations.
   Greg has also explicitly steered away from the QAnon register — *"not as much
   qanon shit but just black magick ect and chaos magick"*. Take the **density**
   from those charts, never the payload.

**E2.4 — the seals.** Greg: *"burn and bind seals should have their own animation
based on real life, where the person's computer motherboard appears in 3D and
the seals burn into the microscopic copper stuff as sigils on the board, like a
full animation for it when a seal is burnt"*.

The best single image anybody has had for this game's thesis: a printed circuit
board *is* a sigil, drawn in copper, mass-produced by the million.

4. **E2.4–E2.7** A real board — traces, pads, silkscreen, something that reads as
   a chip. Burning is subtractive and scars the copper; binding is additive and
   closes a loop that was open. A bound seal works while the board has power; a
   burnt one is gone for the run. `celloutz_type.gd` already has
   `draw_seal_burning()` and it has only ever run in 2D — this is the 3D half.

---

## What I am doing, so nobody duplicates it

Done this session: blood on the lens (`systems/blood_veil.gd`), the derby cab and
its instruments (`systems/dash_cluster.gd` plus `vehicle_interior.gd` finally
wired into `rift_derby.gd`), the gore/hitstop hole Greg spotted, the map's frame
cost (319ms a frame down to 22ms at worst), the satellite being invisible under
its own chart, and the sprint jitter the playtester found.

Next for me: the A v2 items (A1.6, A2.9, A5.6, A6.6, A7.7, A9.7), the
version/changelog page for the GitHub repo, and AK/AL.

**Do not touch:** `rift_derby.gd`, `vehicle_interior.gd`, `dash_cluster.gd`,
`blood_veil.gd`, `living_map.gd`, `satellite_view.gd`, `gore_chunks.gd`.
`limb_momentum.gd` belongs to Agent A from here.
