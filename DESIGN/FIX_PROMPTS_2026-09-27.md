# Fix prompts from Greg's playtest, 27 September 2026

One prompt per lane. Paste each whole. They are written to be self-contained:
an agent that has none of this conversation should still be able to work.

This extends `DESIGN/MASTER_PROMPT_2026-09-26.md` rather than replacing it.
That file owns the lane split; this one owns the specific defects below.

---

## Rules that apply to every lane

1. **One lane, one writer.** Only edit the files your lane owns. If a fix
   genuinely needs another lane's file, write the exact hunk in your report
   instead — file, line, function signature — and let that lane apply it.
2. **Stage by explicit path.** Never `git add -A`. Never commit `.import` or
   `.uid` churn unless the `.uid` belongs to a script you just created.
3. **Merge into `claude/dust-to-bones-look` and push** when the lane is green.
   No zips, no build uploads.
4. **No generated art ships.** Higgsfield and ComfyUI output is *reference and
   iteration material only*. Nothing a generator produced goes into the build
   as a texture, a mesh or a backdrop. See Lane D.
5. **Proof is a render you opened, plus a test.** A green suite is not a
   picture, and a picture nobody looked at is not a proof. If you cannot get
   either, say so plainly rather than implying you did.
6. **Do not skip a failing test to get green.** Fix it or report it.
7. **Report what you could not verify.** Greg is the only one who can confirm
   how a thing feels in play, and he has said he is logging out of the game, so
   anything you claim about "feels right" is unverified unless a render shows it.

---

## Lane A — the opening spine (Claude Code, cloud)

**You own:** the opening scenes. `vat_chamber.gd`, `vat_intake.gd`,
`doctor_examination.gd`, `decanting_prologue.gd`, the intake UI.

### A1. V / Think Out Loud does nothing. This is the worst one.

Greg: *"V shows 'Think Out Loud', but nothing happens. It needs to actually
capture your thought, show a waveform and text, and the doctor should answer
out loud with subtitles, with a quick cancel and no traps."*

What exists today, so you are not starting blind:

- `vat_intake.gd:185` and `:483` already create a `thought_edit` whose
  placeholder is `"think out loud, then Enter"`. So the field is built.
- `vat_chamber.gd:1017` advertises `[V] THINK OUT LOUD` on the keys card.
- `doctor_examination.gd:109` documents a first-thought-out-loud beat
  ("because they have a brain chip"), and `doctor_examination.gd:55` holds a
  `schedule` array.
- `opening_greeting_test.gd:6` already tests that the doctor responds to a
  thought.

So the label, the field, the doctor's scripted answer and a test all exist, and
pressing V still does nothing visible. **Find out which link in that chain is
missing** — that is the whole job. Most likely candidates, in order: V is
swallowed by another handler before it reaches the intake; the field is
created but never focused or shown; the mic never starts so there is no
waveform and no transcript; the answer fires but has no subtitle and no voice.

Done means all six of these, and a test for each:

- V opens the thought field from the real key event, in the real scene, with
  the keys card up.
- **Live waveform while recording**, driven by actual input amplitude, not a
  looping animation. If no mic permission, say so on screen and still allow a
  typed thought — the game must not dead-end on a machine with no mic.
- **Your speech becomes text** in the field, and it is what gets filed.
- **The doctor answers out loud** with a **subtitle** for the line.
- **Cancel is instant** — Esc or a second press V, at any point, including
  mid-recording. No confirm dialog, no dead frame, nothing that can trap a
  player who changes their mind.
- **No traps**: no path where V dead-ends the intake, no focus the player
  cannot escape, no state where the only way forward is to finish speaking.

Prove it with a capture of the field open, the waveform live, and the doctor's
subtitle on screen — three frames, all opened.

### A2. "Schedule" is a hard-lock.

Greg: *"Schedule is a hard-lock bug."*

The word appears as `SCHEDULE 1 / THE DEBT` and `SCHEDULE 2 / THE OTHER HALF`
in `decanting_prologue.gd:56,64`, and as the `schedule` array in
`doctor_examination.gd:55`. Find the beat, reproduce the lock, and say in your
report **which** Schedule he hit, because "Schedule" is a label and not a
system name and I could not tell which one from here.

Done means: the beat can be entered and left every time, including if the
player skips or interrupts it, and a test drives it through without a human.

### A3. Oversized overlays, and lighting and readability before anything else.

Greg: *"those oversized overlays need scaling down, with lighting and
readability fixed first."*

Order matters and he was explicit: **lighting and readability first, then
scale.** A smaller overlay that is unreadable is not a fix.

- Find full-screen Controls that cover the fight or the room and size them to
  their content.
- In the vat room specifically, check text against the new darker grade
  (commit 30c3f260, "vat room darker, red only in the glow"). Anything drawn
  for the old brightness is now either invisible or muddy.
- Report the worst three legibility failures with a capture each, before and
  after.

---

## Lane B — the Hunt (Codex, on Greg's PC)

**You own:** `bone_yard_hunt.gd` and the Hunt HUD. You are already fixing the
Hunt's broken tests; A/B are additions to that, not a replacement.

### B1. The Hunt screen fights the player.

Greg, on the post-fight screen: *"the three slots and the 'BROKE' label are
confusing, and the combat summary text is debug-sized and blocks the fight. It's
also reporting almost everything as zero, so that tracking may be broken, and
some UI is clipped off-screen."*

Four separate defects. Take them in this order, because the third may be
caused by the second:

1. **The summary is drawn over live combat.** It belongs after the fight, not
   during it. Find what draws it and gate it on the fight actually being over.
2. **Almost everything reads zero.** Do not assume the tracking is broken —
   *find out which*. Either the counters never increment, or they increment
   into a variable nobody reads, or the display is reading the wrong subject
   out of `WorldHistory`. A test that asserts a real hit produces a non-zero
   number will tell you which, and that test is the deliverable.
3. **The three slots and the "BROKE" label.** He could not read them. Either
   the three are indistinguishable, or "BROKE" is ambiguous about what broke.
   Say in your report which, and make the state legible without a legend.
4. **Clipped off-screen UI.** Find the Controls whose rects exceed the
   viewport, at his window size and at 1280x720, and report the ones that clip
   at either.

Prove B1 with a capture of the screen after a real fight, with non-zero
numbers in it.

---

## Lane C — gore (OpenCode)

**You own:** the gore and blood systems, `gore_demo.gd`, and one hook line per
scene. Nothing else.

### C1. The gore sandbox.

Greg: *"the schizophrenic sound-sandbox is just absolutely busted."* Another
agent read this as the Gore Sandbox, and that is my reading too — but **confirm
which sandbox he means before you start**, and if it is a different one, say so
and stop rather than fixing the wrong scene.

The useful thing to know before you look: the sandbox is **functionally
green**. `gore_demo_test` prints "gore demo: playable" and the whole
`gore_sandbox_*` family passes, so "busted" is a complaint about how it looks
and how it plays, not about a build that is down. Treat it as an art and
feel problem, and do not go looking for a crash that is not there.

What to actually do:

- Play it and list, in order, what is wrong with it. He called it
  "schizophrenic" and "slop"; find the specific things behind that word rather
  than restating it.
- Anything that is placeholder geometry, name the node and the scene it is in,
  and hand it to Lane D as a replacement request rather than restyling it here.
- The `OpeningBaseModelKit` and the base meshes are recent and intended to be
  the clean foundation. Check whether the sandbox is actually using them or
  still on its older geometry. If it is not using them, wiring it up is Lane C
  work and is probably most of what he is seeing.
- Keep `gore_*`, `blood_*`, `wound_*`, `chunk_test`, `organ_*` green.
  `gore_load_test` is a benchmark: run it windowed on the PC, never headless.

---

## Lane D1 — art (Qoder)

**You own:** `game/art`, the art tools, and placeholder replacement.

### D1a. Generated art must not ship.

Greg, flatly: *"this is just slop art... it shouldn't even be like allowed."*

Something generated has ended up where art was going to be. Find it, list every
file, and **remove it from the build path** — it is reference material, not
production. Do not delete the references; move them somewhere clearly labelled
as non-shipping. If a generated file is currently the only version of
something the game needs, say so plainly, because that is a hole, not a
cleanup.

This is the rule from `AGENTS.md` and the lane brief, and it was already broken.
Worth understanding *how*, so it does not happen again on the next pass.

### D1b. The bodies read as wrong.

Greg: *"all these body models — they look like racist or something, they're
just like black characters... but they're not black, they just look weird, like
in a gimp outfit or something. Also that front body with just those random
pieces of squares. Just fix our body model so it's just a nice clean slim
body."*

Three complaints, and I would treat the middle one as a real problem rather
than a taste note:

1. **Skin reads as black or as an odd colour** on some bodies. He is
   describing the result, not the intent. Check the flesh tints actually in use
   and report the values; there may be a tone curve crushing midtones to
   near-black.
2. **Wardrobe reads as "a gimp outfit."** Find which garment pieces are
   responsible and say which ones. He is not asking for less clothing — he is
   saying the shapes read as a costume.
3. **"That front body with just those random pieces of squares."** This one is
   specific and fixable: it sounds like the front-most body in a gallery or
   character-select view is assembled from visible box parts rather than a
   continuous surface. Find that view, find the body, and find why its parts
   are showing as squares. He asked for "a nice clean slim body" — that is a
   proportion and silhouette job, and it is yours.

### D1c. ComfyUI is set up and working.

It is installed and healthy on the RTX 2060 SUPER, the queue is clear, SDXL
works, ControlNet and Hunyuan nodes are present, **IP-Adapter is the notable
missing piece** for matching a reference consistently. Two Hunyuan 3D model
packs were still downloading — check whether they finished before assuming
3D is available.

Treat ComfyUI as an iteration tool for *authored* art with a human in the
loop, per D1a: nothing it emits ships as-is. Keep the saved workflow and prompt
so the next person reopens it instead of rebuilding the graph. Greg has real
art in a folder and wants it used — ask him for the **folder path**, not for
individual images, and build the pipeline around the folder.

---

## Lane D2 — plugins (Freebuff)

Unchanged from `DESIGN/MASTER_PROMPT_2026-09-26.md` Lane D. Every plugin
loads cleanly and pinned; `gore_load_test` and the capture harnesses depend on
this working, so a broken plugin line will look like a broken game.

---

## Lane E — the playtest

Greg is logging out of the game, so this lane cannot start until he is back.
Do not start it now. When he returns, the order is:

1. The 0–30 minute timed run with a hidden timer and an end card.
2. The V / Think Out Loud path, on a machine with a real mic, end to end.
3. The Schedule beat, entered and left, twice.
4. One fight, checking the post-fight screen for non-zero numbers and nothing
   clipped.

Every one of those is a defect above. The playtest is how we find out whether
the fixes are actually fixes.
