# Loose-thread triage — 28 September 2026

This is the merge gate for work found outside the playable demo branch. It
does not treat a commit title as proof that a feature works. Every retained
runtime change still needs a current-demo comparison, a focused test, a
real-route reachability check, and visual evidence where presentation matters.

No branch, commit, worktree, or source asset was deleted during this triage.
Archived tags preserve the exact old tips before any later cleanup.

## Cut from the active merge queue

These are not candidates for cherry-pick or wholesale merge.

- `f49d7ce2` — **superseded.** Filing already saves the character preset in
  the playable demo, with newer rebirth coverage.
- `58d7e1ce` — **historical only.** ORCA outage recovery anchor; no independent
  player-facing change.
- `55920d2c` — **historical only.** ORCA baseline-export anchor.
- `b8b80214` — **historical only.** ORCA canonical-lane recovery anchor.

The local `claude/dust-to-bones-look` branch is also excluded as a merge unit:

- `0f56b401` is already represented in the current `DESIGN.md` direction.
- `f49d7ce2` is superseded as above.
- `5803a6c6` and `cb206ebd` are unverified vat-room fragments against an older
  scene. They remain preserved for comparison, but are not approved to merge.

## Keep as evidence, not implementation work

These stay available to explain decisions, licensing, or captures. They do
not belong in an implementation lane unless a current document is missing the
same information.

- `06dd6d1e` — B3/B4 decisions.
- `a838bdb3` — anatomy asset and licence research.
- `216dbf67` — Dust-page depth-camera grade ledger.
- `ab83e90f` — silent-menu direction and pause-menu question.
- `46470be4` — 25 September route, vat, and intake notes.
- `a2bfb534` — Wetwire capture evidence for `3241ed50`.

## Suspended bundles

These contain potentially useful work, but must be treated as one comparison
bundle rather than a pile of individual cherry-picks.

### Front-door silence

`f88b7a26`, `6d823216`, `3ebee406`, `823701fd`, `561389ee`

Reproduce the current bug, then port one minimal fix plus the final regression
test. Do not merge the five-step history individually.

### Persistence and menu flow

`3416d7cb`, `c6f38c2f`, `9c5acf25`, `c5316c1d`

Choose one current save-slot model and one menu entry flow first. Split the
unrelated Wire-card layout from `3416d7cb`. Rebuild or port the selected design
as one tested subsystem.

### Connected underground model

`16a596ef`, `36f28384`, `acc3fb97`, `71431054`

Review as one route architecture: topology, liened-organ routing, discovery
persistence, then occlusion. Do not merge the later commits without the model
they extend.

### Reference-art experiments

`90b44f14`, `df7b7cc3`, `c3769028`

The current rule is that generated output is reference material, not shipped
final art. Compare the current playable sequence before removing or restoring
anything. The MoGe memory projection is a separate feature proposal.

### Six look lanes

- `158490be` — combat styles, blood growth, loot preservation.
- `9ee0dd03` — receipt-paper job posters and business cards.
- `e0b83775` — kinship as a Brain Index tab.
- `01af92fc` — Hornee source-art preparation.
- `3e23de10` — lab cables as a wiring system.
- Intake and index work associated with the same old lane base.

All are far behind the playable demo and several conflict with current core
files. Extract and verify one system at a time. Hornee additionally has
authored files that are still untracked in its worktree; preserve those before
any worktree cleanup.

### Mixed-scope older work

- `08c6a8cc` — split menu-label repair, export exclusions, and route audit.
- `4ec965ab` — split materia experimentation from controls/body QA.
- `39c28661` — split control routing, anatomy inspection, and weapon grips.
- `eeb1d2d0` — port only the chosen Sidereal Concordance result, not the old
  branch wholesale.

## Active recovery candidates

These are small enough or important enough to reproduce against the current
demo first. A green check here still means “candidate,” not “verified.”

### Reliability and regressions

- [ ] `71049096` — stop `VoiceInput` listeners when the node leaves the tree.
- [ ] `9b82ab00` — drains exit/channel-softlock regression coverage.
- [ ] `778c2417` — Carry double-event bug and regression coverage.
- [ ] `22ebd8d2` — wait for Godot export completion.
- [ ] `656b5f92` — identify builds by source revision.
- [ ] `6381ced3` — benchmark the claimed Hunt frame-rate improvement before
  selecting any code.

### Opening and route usability

- [ ] `342a5ee9` — floating vat specimens and SPACE on the controls page.
- [ ] `54dd12d7` — visible intake pointer and confirm-current-tab behavior.
- [ ] `742981a3` — breach-tool sign and interaction reach.
- [ ] `c6c1c2b8` — elevator and sallyport surface placement.
- [ ] `f6fa93c6` — readable intake continuation instructions.
- [ ] `7a8e3dba` — floating player body, mouth tube, and skull leads.

### Interface and visual defects

- [ ] `7b0eada9` — keep flesh out of the rust treatment.
- [ ] `a5fd6532` — examination-station capture correction.
- [ ] `bbc36ce5` — preserve the depth-camera night grade after reopening.
- [ ] `c89b1823` — surface/falls/pit darkness tuning.
- [ ] `458820b7` — title fallback does not blow out white.
- [ ] `3af0f10e` — severed-limb pickup prompt.
- [ ] `3de65ca0` — menu splash highlight clipping.
- [ ] `3241ed50` — open the Wetwire index from the inventory head.

### Systems requiring present-code comparison

- [ ] `a8fb906c` — tolerance and comedown on the real clock.
- [ ] `2412c7eb` — capped offline debt time.

## Next allocation rule

Split work by subsystem, never by alternating commit numbers. One person owns
a bundle from comparison through tests and capture; the other person works a
different bundle. Only the coordinator merges into the playable demo.

