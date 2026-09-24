# Art asset ledger

This is the production-facing companion to `CHECKLIST.md`. The checklist says
what the game must do; this ledger gives Greg and collaborating artists bounded
things they can actually draw, model, animate, texture, record, review and hand
back. `ART-DIRECTION-MINDMAP.md` remains the source of truth for confirmed style
and undecided visual questions. `ART-DIRECTION.md` remains the material brief.

Nothing becomes final merely because it was delivered. The workflow is:

`READY TO CLAIM -> CLAIMED -> REVIEW -> ACCEPTED -> INTEGRATED`

- **NEEDS GREG** means the visual choice is still too personal or ambiguous to
  outsource honestly.
- **READY TO CLAIM** means a friend can take the card without inventing lore or
  guessing a technical format.
- **CLAIMED** must list an artist and target date. Two people should not
  unknowingly make the same asset.
- **REVIEW** means source files, exports and previews are present but Greg has
  not accepted the direction.
- **ACCEPTED** means the art direction is approved. It may still need technical
  integration.
- **INTEGRATED** means the shipped runtime path uses it and the relevant visual
  and gameplay checks pass.

## How collaborators hand work back

Every delivery goes in `game/art/inbox/<asset-id>/` and includes:

1. the editable source (`.blend`, `.kra`, `.psd`, `.aseprite`, `.wav`, etc.);
2. an exchange/export file (`.glb` preferred for 3D; lossless PNG or WAV for
   source images/audio);
3. front, side, back and three-quarter previews where the asset is 3D;
4. a one-paragraph `README.txt` naming the artist, date, tools, scale, material
   slots, usage permission and any third-party source material;
5. a note identifying deliberate asymmetry, removable parts, damage seams,
   sockets and anything that must not be cropped or recoloured.

Do not flatten the only editable copy. Do not use ripped commercial-game assets,
unlicensed faces, private photographs without permission, or generated material
whose source/usage rights cannot be recorded. Tonal references guide decisions;
they are not a request to reproduce another game's characters or textures.

## Active queue

Owner and target are intentionally blank until somebody claims the work.

| ID | Priority | Status | Package | Deliverable | Dependency / replacement seam | Owner | Target |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `CHAR-001` | P0 | READY TO CLAIM | Modular human base | One adult gameplay body with separate head, torso, arms and legs; clean deformation and damage separation | Replaces the procedural silhouette behind `BaselineHuman`; must retain the six anatomy zones | — | — |
| `FACE-001` | P0 | READY TO CLAIM | Ashbloom face library | Six original heads/faces across age, ancestry, damage and asymmetry; neutral plus core expression shapes | Built for `CHAR-001`; may be sculpted independently if neck scale and views follow its card | — | — |
| `COST-001` | P0 | NEEDS GREG | Forced jester restraint outfit | Punitive poofed sleeves/cuffs, damaged collar, trousers and footwear; readable first-person wrists and full-body silhouette | Greg must choose the silhouette sheet before modelling; replaces procedural humiliation cuffs | — | — |
| `ANIM-001` | P0 | READY TO CLAIM | Ground locomotion | Idle/breathe, walk, run, sprint, strafe, crouch-walk, stop, turn and injured variants | Author against `CHAR-001`; current procedural motion is the replaceable reference, not final timing | — | — |
| `ANIM-002` | P0 | READY TO CLAIM | Combat actions | Melee anticipation/cut/recovery, block, parry reaction, firearm low-ready/aim/fire/recoil/reload, stagger, downed and recovery | Same animation state names already exist in `HunterBodyMotion`; must preserve readable wind-ups | — | — |
| `ANIM-003` | P0 | READY TO CLAIM | First-person hands and smoking | Cigarette/joint grip, hand-to-mouth, persistent mouth hold, ash flick, Zippo flip/light, bong cradle/light/pull/cough | Uses live props and two continuous forearms; current choreography supplies timing reference | — | — |
| `PROP-001` | P0 | READY TO CLAIM | Smoking prop kit | Cigarette, joint, spliff, bong and battered flip lighter with ember/ash/bowl/lid components | Replaces procedural meshes behind `Smokeables`; preserve grip, mouth, flame and bowl anchors | — | — |
| `WEAP-001` | P0 | READY TO CLAIM | Mercy 9 sidearm | Authored sidearm with grip, support-hand, muzzle, slide, magazine and casing-port anchors | Replaces the procedural sidearm without changing ballistics or inspection logic | — | — |
| `WEAP-002` | P0 | READY TO CLAIM | Bone Yard long gun | Authored long gun/shotgun with stock, receiver, forend, muzzle, loading and grip anchors | Replaces the procedural long gun; inspection already expects a movable support hand | — | — |
| `ENV-001` | P0 | NEEDS GREG | Facility constitution sheet | One sheet establishing concrete/tile/metal/organic balance, lighting, signage and scale for the prison-lab | Greg selects the dominant facility material before modular environment production | — | — |
| `ENV-002` | P0 | BLOCKED | Underground facility kit | Modular corridor, vat room, service tunnel, cell/lab, lift, locked door and breakable wall set | Begins only after `ENV-001` approval; replaces primitive facility geometry by module | — | — |
| `ENV-003` | P0 | READY TO CLAIM | Underground colosseum kit | Arena wall, roof ribs, stands, service ring, gates, floodlight rig and wreck dressing | Stable derby gameplay stays intact; art replaces the current structural primitives | — | — |
| `FX-001` | P1 | READY TO CLAIM | Smoke and ember atlas | Thin neutral smoke wisps, subtly green herb variation, exhale layers, ember pulse, ash and smoke-ring breakup | Replaces code-generated visual textures while retaining the existing particle/trick simulation | — | — |
| `UI-001` | P1 | NEEDS GREG | Interface substrate pack | Original paper, toner, stains, tape, borders, stamps, handwriting and registration marks | Greg should provide/approve the five visual-constitution works before final UI surfacing | — | — |
| `UI-002` | P1 | READY TO CLAIM | Black Mirror physical shell | Scuffed phone body, cracked screen/bezel, pocket silhouette and lighter-ring detail | Replaces the procedural phone shell; live MAP/INDEX/Board screens remain code-driven | — | — |
| `VEH-001` | P1 | READY TO CLAIM | Scrap skiff replacement | Full-scale brutal derby vehicle with chassis, wheels, weapon mount, driver point and damage parts | Replaces `game/art/scrap_skiff.glb` while preserving wheel/contact and named-part contracts | — | — |
| `GORE-001` | P1 | READY TO CLAIM | Damage-zone body variants | Authored wounds and exposed interiors for head, torso, arms and legs; severed caps included | Plugs into the six existing anatomy zones; does not invent a second damage model | — | — |
| `AUDIO-001` | P1 | READY TO CLAIM | Body movement library | Footwear/ground footsteps, cloth, cuffs, breath, jump, landing, dodge, stumble and fall | Replaces procedural/placeholder clips behind existing movement events and `Bodies` bus | — | — |
| `AUDIO-002` | P1 | READY TO CLAIM | Held-action library | Weapon handling/fire/reload, Zippo flip/spark/flame, inhale/exhale/cough, bong water and ash flick | Files stay independent of action duration; code owns timing, audio supplies layers | — | — |
| `CHAR-002` | P2 | NEEDS GREG | Faction silhouette sheet | Government/military, raider, CellOutz/demon and angel silhouettes without final lore proliferation | Requires a Greg-approved sheet before individual outfits or ranks are claimed | — | — |

## Starter briefs

These are the cards most suitable to send to friends now.

### `CHAR-001` — modular human base

**Goal:** replace the block-built human without losing the body simulation that
already works. The model should feel battered, capable of surviving this world,
and anatomically believable rather than superhero-perfect.

Required delivery:

- real-world scale, approximately 1.7–1.9 m at neutral stance;
- neutral A-pose, unapplied destructive modifiers preserved in the source;
- separate head, torso, left/right arms and left/right legs, with hidden overlap
  at seams so losing a limb does not open an empty paper shell;
- clean shoulder, elbow, wrist, hip, knee, ankle, neck and jaw deformation;
- UVs and named material slots for skin, eye, mouth/teeth and replaceable body
  surfaces; 2K working textures are enough for the first review;
- a simple deformation test: deep crouch, raised two-hand firearm pose, overhead
  melee wind-up, hands at mouth, and prone/downed pose;
- no permanent clothing or faction identity baked into the body.

Review gates: silhouette at 2 m and 15 m, deformation in all five test poses,
clean zone separation, and successful GLB import at correct scale.

### `FACE-001` — original face library

**Goal:** people should stop looking like one procedural mannequin with different
labels. Make six faces that plainly belong to the same harsh world without
turning ancestry, damage or age into caricature.

Each face needs front/profile/three-quarter turnarounds, a neutral sculpt, eye
and mouth interiors, and shapes or posed references for blink, jaw open, lip
seal/puff, pain, anger, fear and exhausted amusement. At least two faces should
carry deliberate asymmetry; at least two should work without scars, implants or
costume so damage remains gameplay state rather than mandatory decoration.
Provide clean and injured concept overlays separately. Do not use a real person's
likeness without written permission.

Review gates: recognisable in flat neutral light, compatible neck scale, mouth
closure around a cigarette without impossible anatomy, and no expression relying
on a texture-only painted shadow.

### `ANIM-001` and `ANIM-002` — locomotion and combat

**Goal:** remove foot skating and make intent readable before damage. The current
procedural controller already distinguishes idle, walk, sprint, crouch, injury,
melee wind-up, firearm aim/fire/recoil, reload, stagger and downed state. Authored
clips replace the visible motion, not those gameplay decisions.

Deliver clips in-place and with root-motion notes. Walk/run cycles must include
clear planted-foot frames. Combat clips need named anticipation, contact and
recovery timestamps. Firearm clips require one- and two-hand variants. Show a
single character walking, sprinting, shouldering/firing/recovering and performing
a complete melee attack in one preview video before exporting the full pack.

Review gates: no sliding at game speeds, readable wind-up at 8–15 m, no frozen
lower body during aiming, no wrist inversion, and clean transitions back to
locomotion.

### `PROP-001` — smoking kit

**Goal:** small props must survive close first-person inspection and still read
in the mouth without covering the aiming lane.

Every prop needs named local anchors or clearly documented empties for its main
grip and mouth point. The lighter also needs lid hinge, flame and thumb positions;
the bong needs base/support grip, mouthpiece, bowl and flame target. Rolled items
need an ember end and an ash/burn-length section that can shorten. Supply clean
neutral renders and one hand-scale render. Geometry should be economical, but
silhouette and close texture detail matter more than invisible underside detail.

### `ENV-003` — underground colosseum

**Goal:** preserve the derby's playable bowl while making it unmistakably an
underground prison spectacle rather than an outdoor prototype arena.

The kit should communicate colossal excavated weight, service access behind the
stands, violent vehicle scale and institutional spectatorship. Deliver modular
wall/roof/stand/ring/gate/floodlight/wreck pieces on a common grid with collision
proxy meshes. Avoid final faction logos until Greg supplies them. A blockout pass
at game scale is reviewed before high-detail texturing.

## Needs from Greg before the blocked cards open

1. Mark five existing artworks as the game's visual constitution.
2. Draw or approve one front/back silhouette for the forced jester outfit.
3. Choose the facility's dominant clean material before contamination: poured
   concrete, institutional tile, buried corporate laboratory, repurposed civic
   infrastructure, or an original hybrid sheet.
4. Approve which face concepts become playable-character options versus NPC
   population faces.
5. Name one person as the keeper of this ledger when multiple friends are
   contributing; claimed cards and review notes otherwise drift immediately.

## Review log

| Date | Asset ID | Artist | Decision | Requested changes / integration result |
| --- | --- | --- | --- | --- |
| — | — | — | — | — |
