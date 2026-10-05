# Wizards Only Fools: start here

This folder is everything an AI (or a person) needs to keep building Greg's game
without the old chats or paid accounts. Written 5 October 2026.

## Paste this into any AI first

> I'm Greg, solo developer of **Wizards Only Fools**, a first-person biopunk
> occult horror game in **Godot 4.7.2 (GDScript)**. The project is at
> `P:\GameDev\AllusionsTooGrandeur` (game in `game/`). Read
> `HANDOFF/START_HERE.md` fully, then only the parts of `GAME_PLAN.md`,
> `BUILD_PLAN.md`, `BUILD_BRIEFS.md` and `DECISIONS.md` that the task needs.
> My newest decision always wins over older ones. Don't invent lore, names or
> story; ask me. Before writing new code, search the repo for a system that
> already does it and wire that in. Change as little as possible, keep the
> tests passing, and tell me plainly what you could not check.
> Today's task: <describe one thing>.

Free or smaller AIs have small memories. Give them this file plus the one job
brief you're working on, not the whole folder.

## The files here

| File | What it is | When to read |
|---|---|---|
| `START_HERE.md` | This guide | Always |
| `GAME_PLAN.md` | The whole game: world, cosmology, the twelve planes, factions, body, combat, systems, roadmap | When a task touches design or lore |
| `BUILD_PLAN.md` | v0.1 "Escape": exactly what the first playable version contains | Before building anything |
| `BUILD_BRIEFS.md` | One detailed brief per job (goal, existing code, files, proof, tests), plus the rules | The brief for your task |
| `DECISIONS.md` | Greg's recorded decisions, oldest first. Newest wins | Search it for the decision you need |
| `STATUS.md` | What was built overnight 4–5 Oct, what's weak, what's waiting | To know where things stand |
| `CODE_MAP.md` | Every system file with a one-line description, and the scenes | To find code |
| `raw/greg_said_all_messages.md` | Every message Greg typed to any AI, 8 Sep – 4 Oct (2 MB) | Search only; it's the true source when docs disagree |
| `raw/chat_digests/` | 19 summaries of those messages by period | Context on a topic |
| `raw/planning_chat_2026-10-04.md` | The 4–5 Oct planning chat that made these plans | Background |

The plan pages also exist as web pages: `DESIGN/GAME_PLAN.html` and
`DESIGN/BUILD_PLAN.html`.

## The game in one paragraph

Earth is a prison planet in a perpetual post-apocalypse. You are a decanted
clone owned by debt, woken early in a CellOutz vat. The examiner runs your
intake (that is the character creation). Your soul hacks the brain chip, you
tear out the cords, smash the glass, get revenge and escape the underground
facility. Combat is brutal and anatomical: one rigged body for everyone, an
X-ray that shows organs and implants, organs you rip out through wounds, VATS
targeting, Teardown-style destruction. Six disciplines (playstyles) live on
the chip. Later: the Ashbloom surface, a nemesis pyramid, territories, the
Wire. Full detail in `GAME_PLAN.md`.

## How to run it

- **Play:** double-click `P:\GameDev\PLAY.cmd` (runs `game/` with Godot 4.7.2 at
  `P:\GameDev\Tools\Godot-4.7.2\`).
- **Mechanics lab:** `P:\GameDev\Start-MechanicsLab.cmd`. One test map where each
  system is proven before it goes into the real game. Press Start for the
  station menu.
- **Edit:** open `game/project.godot` in the Godot 4.7.2 editor.
- **Tests:** from `P:\GameDev\AllusionsTooGrandeur`, run
  `bash tools/run_tests.sh <test_name>` (headless). The core set:
  `baseline_human_test body_cut_test opening_handoff_test first_run_walk_test first_thirty_route_test`.
  After a fresh checkout run `Godot --headless --path game --import` once.
- **Screenshots:** each system has a capture scene in `game/tests/*_capture.tscn`.
  Run it windowed and look at the PNG. A test passing does not mean it looks right.
- **Physics:** the project uses Jolt (Project Settings, Physics, 3D).

## Where things stand (5 Oct, midday)

5 of the 10 v0.1 jobs are in the game: the mechanics lab, rigged bodies on
Jolt, real fluid and glass, the HOTLINE CLEAVER / PRODSTAFF / MERCY NINE
combat, waking in the vat, and organs + cybernetics + X-ray. Built but not
finished: Teardown destruction, the one facility map. Details and weak spots
in `STATUS.md`.

**Greg's top problems, newest first:**
1. **The facility map** is the main thing that needs fixing.
2. The examiner's generated model "looks way too human, that cursed Higgsfield
   model sucks". Use the stylised base body instead.
3. Aiming down the sights: the iron sights block the whole screen (weapon model
   scale/position). He wants a slowed-down kill cam of the bullet entering and
   rupturing on VATS shots.
4. The Black Mirror phone doesn't work as one device. The depth-map camera does
   nearly nothing and isn't the TouchDesigner-style node look he wants.
5. Teardown destruction and BeamNG-style vehicles aren't in yet.
6. Bodies: checker skin, helmet-like heads, hunched idle. No sound on hits or
   liquid.

Each has a written task in `P:\GameDev\AgentHub\queue\pending\` (the file name
says what it is). Those task files are good prompts for any AI.

## Rules that kept the work honest

1. **One game folder.** `P:\GameDev\AllusionsTooGrandeur`, branch
   `claude/launch-latest`. Never make copies of the project. The old 30+ copies
   were the biggest mess.
2. **Build, don't plan.** One task at a time on the next most broken thing in
   the current slice. No planning-only or "audit" sessions.
3. **Wire before you build.** About 350 system files exist, many finished but
   unused. Search first (`CODE_MAP.md`, `rg -n "<word>" game`).
4. **Look at it.** A visual change is only done when someone has seen it running
   or in a screenshot.
5. **Greg's words win.** Newest decision wins. Quote him; don't paraphrase.
6. **No invented lore or names.** "Bingyanger" and "Support Unit" are placeholder
   joke names, not lore. Acid rain is not a real concept (lab demo only).
7. **Free assets, credited.** CC0 first (Quaternius, Kenney, Poly Pizza,
   ambientCG, Poly Haven), Mixamo animations, credit everything in `CREDITS.md`.
   Never rip assets from other games.
8. **Pad first.** Every action works on a PS4/PS5 controller with the Souls
   layout (R1 light, R2 heavy, L1 block, L2 parry or aim).
9. **144 fps** on Greg's RTX 2060 SUPER in every room.
10. **Commit small and often**, with a message saying what changed and what was
    tested.

## The automation (it stops when the subscriptions end)

`P:\GameDev\AgentHub\hub.py` dispatched build tasks to several Claude and Codex
accounts every 15 minutes (Windows scheduled task `AgentHub-dispatch`), and a
Claude scheduled task ("WOF build check-in") reviewed work every 25 minutes.
Once the accounts stop working, turn them off so nothing errors in the
background:

- `schtasks /Change /TN "AgentHub-dispatch" /DISABLE` (run in a terminal)
- In the Claude app, Scheduled sidebar: pause "WOF build check-in".

The queue folder (`AgentHub\queue\pending\`) stays useful as a to-do list: each
file is a ready-made prompt.

## Using a free AI well

- One task per conversation. Paste the prompt above, this file and the one
  brief or task file. Don't paste the whole folder.
- Ask it to search before writing, and to show the diff.
- Run the game or the test yourself after each change; small models are often
  confidently wrong.
- When it needs a design decision, answer it yourself and add one line to
  `DECISIONS.md` at the bottom with the date, so the next AI knows.
