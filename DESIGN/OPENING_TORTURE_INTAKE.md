# The opening, rebuilt: the torture load-in and the doctor's psychology test

Greg, 25 September 2026, in his own words (lightly trimmed):

> when you are loading into the game make it you're getting tortured there are
> like muffled screaming you have like a thing being put in your mouth then you
> remember and you hear a voice say hundreds of years of the ... perpetual
> post-apocalypse ... and it just like glitches out and then like you kind of
> come to and you're being talked to a doctor walks up to the screen taps it
> then he appears on the left screen because he goes on the computer he says
> hello hey you were going to do a psychology test for me you were going to
> tell me your birthday and I am going to find out everything I need to know
> and we need to know and then he says hurry up now I'm being watched too and
> then the cameras that are all around zoom in closer and you see them on your
> depth map and your x-ray and you can use your v for voice ... as an actual
> mic ... so your thoughts you can like speak your thoughts and then because
> they have a brain chip ... he says "hey i can read your thoughts don't forget
> ... we own you with a brain chip" ... and so then you do a psychology test
> tell them their birthday so he tells you information about ... your birth
> then he asks what style of fighting you want to do. The GUI instead of being
> this big checklist is like way more like Fallout New Vegas, way more
> customization, images UI ... I'll replace textures with the actual art ...
> the stats actually matter and they're like big indicators and there's no
> space wastage.

And the look: lighting like Alien Isolation, Outlast 1 and 2, Resident Evil,
Silent Hill 1 and 2, and Cruelty Squad. Old low-poly horror, old-internet
gore, surveillance-state cameras, and blatant esoteric symbolism (sigils,
demons, Baal) in the assets. Assets are **human-made, not generated**.

## The beats, in order

Each beat names what the game already has (**exists**) and what has to be
made (**new**). Lines marked (rec) are the assistant's proposal and stay
open until Greg says yes.

### 1. Loading in is being tortured
- Black screen, and the sound comes first: muffled screaming through fluid.
  Something is forced into your mouth: a wet rubber sound, a gag, your
  breathing going to the tube.
  - **Exists:** `OpeningAudio`, generated room sound, pulse and cues. The
    X-ray loading screen on failing film.
  - **New:** a torture sound bed; a mouth-tube insertion cue; muffled screams
    (human-recorded or authored, not generated).
- Flashes of memory between the black: (rec) the X-ray film, single frames.
- A voice: *"Hundreds of years of the perpetual post-apocalypse..."* The line
  repeats and degrades, then glitches out.
  - **Exists:** the datamosh transition, the CRT glass, `NPCSpeechOutput`
    (a generated voice, placeholder only).
  - **New:** the line, recorded by Greg or a voice actor; a glitch-out.
- You come to, submerged in the vat.
- **Built (25 September):** `systems/torture_load_in.gd`, before the intake on every new game (not on rebirth). Three screams through fluid, the gag, breathing to the tube, four X-ray film flashes (skull with the chip, ribs, the rune), the broadcast line three times and worse each time, a glitch, then the room. F, Enter, Space or a click cuts to the glitch. Sounds are generated placeholders behind `cue()`, waiting for the Higgsfield voice set. Test: `torture_load_in_test`.

### 2. The doctor arrives at the glass
- He walks up to the tank screen and **taps it**. The tap is heard through
  the glass.
  - **Exists:** the examiner's arrival walk, his door, and the station beside
    the tank.
  - **New:** the tap animation and sound; he looks at you first.
- He goes to his computer, and **appears on the left screen**: the live
  examiner feed.
  - **Exists:** `ExaminerFeed`, the left panel of the intake.
- **Built (25 September):** he comes round the tank, stops in front of your glass, turns to you and taps three times (a dull knock through the fluid, the subtitle "TAP. TAP. TAP."), then goes to his terminal. He now wears the bloodied lab coat the feed shows; the 3D body was walking up naked under the censor. (He was also facing backwards on every walk; fixed.)

### 3. "Hurry up now, I'm being watched too"
- He says: *"Hello. Hey. You're going to do a psychology test for me. You're
  going to tell me your birthday, and I'm going to find out everything I need
  to know. Everything we need to know."* Then: *"Hurry up now. I'm being
  watched too."*
- **The cameras around the room zoom in closer**, and you see them on your
  depth map and X-ray.
  - **Exists:** `WorldXray`, the alarm X-ray flash, the lab's wall cameras
    (placement only).
  - **New:** cameras that visibly turn and zoom (lens barrels extending), a
    depth-map/X-ray pulse over the room showing them.
- **Built (25 September):** his three lines play in Greg's words as soon as his terminal is up (`DoctorExamination.OPENING`). "I'm being watched too" turns the Growing Floor's four wall cameras (now real `SecurityCamera`s, `systems/intake_watchers.gd`) onto your tank, runs every lens barrel out, and a depth-scan pulse over the form boxes each one: "CAM 0C-n // ON YOU". Test: `opening_greeting_test`.

### 4. V is your voice, and they can read it
- Hold **V** and speak into your real microphone (a HyperX SoloCast or any
  other). What you say is transcribed and shown as your thought.
  - **Exists:** `VoiceInput` (Vosk speech-to-text through
    `tools/voice_listener.py`), `SpokenContact`, `MicLevel`, and the
    intake's typed "think out loud" (V).
  - **New:** wire the real mic into the intake's V; a mic picker in settings;
    a fallback to typing when no mic or model is present.
- He answers what you thought: *"Hey. I can read your thoughts. Don't forget,
  we own you. Brain chip."*
- **Built (25 September):** the first thought you type or speak with V, he answers with that line, and it goes on the record (`examiner_read_thought`). The real-mic hookup is still to do.

### 5. The psychology test is your birthday
- He asks for your birthday (and time of birth, if you know it).
  - **Exists:** `CharacterSheet.birth`, sun sign, ascendant, modality,
    `NatalSigil`.
  - **New:** a birthday entry you can speak or type; his reading of your chart
    back to you, in his voice, feeding the stats.

### 6. "What style of fighting do you want?"
- He asks your fighting style: Blade/Blunt, Iron, Meat, or Hush.
  - **Exists:** the four blood-tree styles and their nodes.
  - **New:** the choice opens that style's first node and sets your starting
    weapon.
- **Built (25 September):** a STYLE tab after SCHEDULE. Reaching it, he asks "What style of fighting do you want?". Each row shows the node it opens and what you would be holding. Filing opens that style's first node free (`BloodTrees.grant_start`, recorded as `fighting_style_chosen`), and IRON starts the Hunt on the sidearm. (rec, open to Greg) MEAT and HUSH keep the sword until the arsenal has slots for hands and the unseen kill. Test: `fighting_style_test`.

### 7. The GUI is Fallout: New Vegas, not a checklist
- Pip-Boy-like: images, big stat indicators, customization, and no wasted
  space. Greg replaces the textures with his art.
  - **Exists:** the intake pages (receipt tabs, gauges, gears, blood), and
    `CellOutzType`.
  - **New:** a rebuilt intake layout: portrait and body images, large dials
    or bars for each stat that visibly matter, and texture slots named for
    Greg's art.

### 8. The vat on the right is a real vat, and you're in it
Greg, 25 September (second message):

> your VAT model on the right is like a big three D model of a VAT, and then
> you're actually in it ... there's no like circles that are going in each
> other. It's just a big VAT ... there's heaps of blood and like water in it,
> and the sexual liquid, and it's a real liquid system. And make sure it
> doesn't lag ... the performance is all perfect.

- The intake's right panel shows a **big 3D vat with you inside it**, not
  rings stacked on each other.
- It holds **a real liquid:** blood, water and other fluids that move, lit
  and refracting. It runs smoothly at full frame rate.
- **You're being tortured in it:** wires in your head, the brain implant, a
  tube in your mouth, and electrocution. Each zap flashes your body and
  organs through, X-ray style.
  - **Exists:** `VatBodyPreview`, `BaselineHuman` with organs, `WorldXray`,
    the wetwire implant, and the umbilicals from the wires beat.
  - **New:** the vat panel rebuilt as one large vat; a fluid surface and
    volume shader; zaps that flash the X-ray over the body.

### 9. Character customization as deep as Bloodborne
> as good as Bloodborne customization. Each different like eyebrow, concave
> and everything is like a complex face model shape, and it's still using my
> textures, but using skin and clothing models after that. You can make
> extremely detailed characters.

- **Face:** many fine shape controls (brows, cheek hollows, jaw, nose,
  eyes, and so on) on a proper face model. Each slider moves only its own
  feature.
  - **Exists:** the FACE tab's sliders (each moves only its own feature),
    `face_model`, and `BaselineHuman`.
- **Skin and clothing** on top, using Greg's textures.
- **Genitalia:** none, asexual, or chosen, with size; the censor blur stays
  an option. Greg: "there will be sexual stuff in the game".
  - **Exists:** `BodyForms` (chest, groin, buttocks, by anatomy and frame),
    `AnatomyPresentation` (explicit or mosaic), and the body-cam censor
    glitch.
- **Blood:** you choose your blood.
- **Cybernetics:** you choose them in the vat.
- **You see every choice on your body in the vat:** blood, ink, build,
  fighting style, and cybernetics all change the body you see.

### 10. The breakout: your soul takes the chip
Greg, 25 September (third message), in order:
1. He leaves the room. **Muffled screaming** starts.
2. **A sigil takes your brain:** the game's rune (the seal's Algiz, the icon
   used everywhere), crazy and demonic.
3. The rune **shrinks into a microscopic motherboard / CPU sigil**, then
   **gets hacked**: CRT blob tracking, in the same glitched style as the END
   ALL SUFFERING card.
4. The card reads **BRAIN HACKED** / **SOUL OVERTAKEN**. You overtake the
   brain chip.
   - **Exists:** `motherboard.gd` and `motherboard_sequence` (seal
     animations), `mission_card.gd` (END ALL SUFFERING, GET REVENGE),
     `block_tracker`, `SoulBreakthrough`.
5. **Your hands:** you look at them, they tear free, come straight to your
   face, both cover it, and **rip the cord out of your mouth**.
6. You **smash the glass three times** until it cracks completely.
7. **All the liquid pours out,** you fall to your knees, and you get up.
   - **Exists:** the wires beat (tugs), the glass break, the puddle, and the
     stand-up.
8. Then you play: the paths out we've built. Keep building from there.

### 11. The rooms, the cameras and the X-ray
- **Fix every placeholder model:** a room still has a "bean" (a capsule
  body). Replace the capsules, skins and props with real human-made models.
- **Cameras like Hitman:** smart and strategic. They sweep, track, have
  blind spots and lines of sight, and report to the alarm, not just a blue
  light.
  - **Exists:** `alarm_director.gd`, `camera_hack`, and the Growing Floor's
    wall cameras.
- **X-ray like Sniper Elite 4 and 5:** full-body organs in every cutscene
  and kill, realistic anatomy.
  - **Exists:** `kill_cam.gd`, `world_xray.gd`, and `BaselineHuman`'s organs.
- **Loading screens:** not "newbie". Insane sigil art, sacred geometry, and
  a realistic anatomical X-ray body.
  - **Exists:** `interstitial.gd` and the X-ray loading screen.

## The look (applies to everything above)
- **Lighting:** Alien Isolation and Outlast darkness. Pools of light,
  practical lamps, a flashlight or camera light doing the work. (rec) Measure
  it: most of the frame near black, lit areas small and hot.
- **Old low-poly horror:** PS1/PS2 texture wobble, Silent Hill fog, Cruelty
  Squad's sick colour.
- **Surveillance:** cameras everywhere, the body-cam frame, Palantir-like
  watching.
- **Symbolism:** sigils, demons, Baal, blatant in the assets and signage.
- **Gore:** old-internet grime; blood, splatter, physics.

## Assets: human-made, free, credited
- Only human-made assets: CC0 or CC-BY, credited in the game.
- (rec) Sources: Kenney, Quaternius, Poly Haven, OpenGameArt, ambientCG,
  Freesound (CC0 or CC-BY sounds), and itch.io free packs. Sketchfab CC-BY
  models are allowed with credit.
- Every asset gets a line in a credits file with its author, licence and
  link.

## Questions for Greg
- Higgsfield generates art and games with AI. How should it be used, given
  "non-gen-AI, peak human creation"?
- What are "Ponytail" and "Mento"? Please send links.
- Who records the voice lines: Greg, a voice actor, or generated
  placeholders until then?
