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

### 2. The doctor arrives at the glass
- He walks up to the tank screen and **taps it**. The tap is heard through
  the glass.
  - **Exists:** the examiner's arrival walk, his door, and the station beside
    the tank.
  - **New:** the tap animation and sound; he looks at you first.
- He goes to his computer, and **appears on the left screen**: the live
  examiner feed.
  - **Exists:** `ExaminerFeed`, the left panel of the intake.

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

### 7. The GUI is Fallout: New Vegas, not a checklist
- Pip-Boy-like: images, big stat indicators, customization, and no wasted
  space. Greg replaces the textures with his art.
  - **Exists:** the intake pages (receipt tabs, gauges, gears, blood), and
    `CellOutzType`.
  - **New:** a rebuilt intake layout: portrait and body images, large dials
    or bars for each stat that visibly matter, and texture slots named for
    Greg's art.

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
