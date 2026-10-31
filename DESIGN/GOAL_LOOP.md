# The self-guided goal loop

24 September 2026. A checklist, plus the way Claude works through it on its
own: build, prove, ship, then stop and ask Greg questions at set points in
play. It builds on `DESIGN/FIRST_30_REBUILD.md` and the `/goal` queue.
Assistant recommendations are marked **(rec)** and stay proposals until
Greg says yes.

## Paste this to start it

> /goal Work `DESIGN/GOAL_LOOP.md` top-down on your own.
>
> For every item: build the smallest version a player can do in the real
> route, record it in the world, render it and look, test it, merge it, and
> send me a Windows build with the commit in the file names.
>
> Push further each round. After every item, write down one thing a skill,
> test or tool could do better next time, and make that change before
> starting the next item.
>
> Stop and ask me question boxes, with the recommended option first, at
> every **ASK** point below. Record my answers in `DESIGN.md` the same turn.
> Don't wait on me otherwise: if a question blocks one item, move to the next
> item and come back.

## How each round goes

1. **Pick** the next unticked item.
   - `grep` for what it touches.
   - Check `wof-wire-before-polish` first: wire what is already built before
     writing anything new.
2. **Build** the smallest version a player can do.
3. **Prove it:**
   - render it and open the PNG; motion gets a clip
   - one small test
   - `tools/run_tests.sh --core` passes
4. **Ship it:**
   - merge
   - make a versioned Windows build (`WOF-<commit>.zip.part*` and
     `JOIN-<commit>.bat`)
   - add a clip to the site's footage
5. **ASK:** the questions for that item (listed under it).
6. **Push the limit:** one improvement to a skill, test or tool, committed.
7. Tick the item with its commit and move on.

Rules that hold every round:
- Stage by explicit path.
- Never commit `.import` or `.uid` churn.
- Never run `git clean` without paths.
- Use subagents only when they save real time, and brief them with
  `wof-agent-brief`.

---

## A. Finish what is in flight

- [ ] **Skins, cases, the Wire exchange, and the jester set as parts.**
      Built on `skins-work`: 4 tests pass and 3 renders were checked by eye.
      The core suite passes; then merge it and send a build.
  - **ASK, while Greg opens his first case in game:**
    - Is the 4-second reel the right length?
    - Should gold get its own moment (sound, light, a slow-down)?
    - Are the prices right? Gold is about 780,000 scrip; a common is about 20.
    - Should cases need keys, like CS?
  - **ASK, when he breaks the collar:**
    - Should breaking the lock take a hold and a sound?
    - Should the jester set stay a punishment, or become a style people
      notice?
- [ ] **Merge what Greg has approved:** the body-cam OSD HUD (`4acfb0b`), the
      cybernetic spine (`c4853df`) and the websites (`8abba5a`).
  - **ASK before merging:** "Merge the HUD, the spine and the sites into the
    main branch?"
- [ ] **Nudity and censors** (Greg: "then from there we can make nudity and
      censors").
  - Wire `AnatomyPresentation` (the explicit / mosaic option).
  - The body under the clothes, and a censor mode that pixelates or mosaics
    it.
  - A setting in the options.
  - **ASK before building:**
    - What shows with everything off?
    - What does the censor look like: mosaic, bars, or the body-cam
      glitching?
    - Is it on by default?
    - Do NPCs follow the same setting?
  - **ASK after he sees it:** "Does the censor read as part of the world, or
    as a filter over it?"

## B. The first 30 minutes (from `FIRST_30_REBUILD.md`, in order)

- [ ] **Stopwatch every route out** (rec).
  - **ASK:** "Which route felt longest, and was that good or bad?"
- [ ] **Every killer in minutes 0-30 sends you to the rebirth vat:** the
      sentinel, the bingyanger, the derby and the Support Unit.
  - **ASK, after his first death that isn't Hollis:** "Did waking in the vat
    feel like a cost or a relief? Should the claimant's vat look different
    each time?"
- [ ] **Rooms for the other claimants' vats** (a rival, a cult).
  - **ASK first:** "Who are the rival and the cult, and what does their vat
    room look like?"
- [ ] **The wires moment reads as your soul seizing the chip:** the wetwire
      feedback and the chaos-magick interface waking.
  - **ASK first:** "The exact beat, and does third person unlock here?"
- [ ] **A better examiner model, and the animated intake pages** (ink,
      blood, metal, gears).
  - **ASK after the first page animates:** "More of this, or calmer?"
- [ ] **Carry icons:** a real icon per item kind, including skins, cases and
      garments.
- [ ] **The derby's slow-motion kill cam**, on the real body.
  - **ASK after the first one plays:** "How slow, how long, and how often?"
- [ ] **The first minute on the surface:** a person, a job poster or a
      threat.
  - **ASK:** "What should the first thing you meet up top be?"
- [ ] **The lab's Lain / Evangelion cables, more cameras, and doors that
      answer.**
  - **ASK with side-by-side renders:** "Is this the wiring you meant?"
- [ ] **The Brain Index hub,** with tabs for Carry, Combat, Brain Index,
      Tasks and Map. The exchange's Skins and Wardrobe tabs move into it.
  - **ASK after it opens:** "Is anything missing from the hub, or in the
    wrong tab?"
- [ ] **The combat overhaul:**
  - omnidirectional swings
  - a readable skill curve
  - AI difficulty tiers
  - the blood trees wired to the four styles
  - **ASK after each difficulty tier:** "Too hard, too easy, or right? What
    did you learn from losing?"
- [ ] **Hollis's real model.** Waiting on Greg's pick.

## C. Limit-pushing work (rec)

Take one of these per round, alongside the item being built:
- [ ] **A sound pass per beat** (law 15).
- [ ] **A frame-time budget per scene**, measured in Forward+ and written
      down.
- [ ] **One controls sheet**, and a decision on the `ControlBindings` branch.
- [ ] **A `wof-build` skill:** one command that exports, versions, zips,
      writes release notes and drafts the GitHub Release.
- [ ] **A `wof-playtest` skill:** logs narrated playtests into
      `playtests/<date>.md` and turns them into checklist lines.
- [ ] **A `wof-footage` skill:** the movie-writer reels, the 9:16 Reel and
      the 4:5 carousel, as one repeatable command.
- [ ] **A route replay test:** a scripted run of each route that records
      its time, so pacing changes show up as numbers.
- [ ] **Stale briefs:** `START_HERE.md` brought up to date.

## D. Question checkpoints during play

Besides the ASK lines above, Claude asks at these moments in every playtest
Greg narrates or plays:

| When | What to ask |
|---|---|
| Before he plays | What he wants to try first, and whether anything from last time is still bugging him |
| After the intake | Did the examiner and the pages hold his attention? |
| After the breakout | Did tearing the wires feel like his choice? |
| At Hollis | Coerce or kill, and why? Was the door clear? |
| At the first death | Did rebirth read? What did he lose, and did he care? |
| At the route choice | Why that route? Did he know the other one existed? |
| On the surface | What did he want to do next? |
| At the exchange | Did the case feel worth opening? Would he sell or keep what he got? |
| After the session | His top 3 fixes, in order. They go to the top of this list |

Each answer goes into `DESIGN.md` (his decisions) or
`playtests/<date>.md` (what he saw), the same turn.

## E. Waiting on Greg

- Hollis's model.
- The anatomy downloads.
- The doctor's name, history and vehicle.
- The breakthrough beat.
- Where the Board lives.
- The blade for Hollis's hand.
- The sky agency.
