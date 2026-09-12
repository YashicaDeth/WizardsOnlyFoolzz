# The Final V

The specification for v10 — what every system in this game is *for* once the
ladders are climbed, written **before the nodes get connected to the code** so
that the connecting has something to aim at.

Sixteen features. Each one is a rule the whole build obeys rather than a thing
the build contains, which is the difference between a feature list and a design.
Every section's final pass in `CHECKLIST.md` is an instance of one of these.

---

## 1. One anatomical truth

There is one body in this game. The player, a scavenger, Mara Voss, a grey, a
reptilian, a demon that has a torso — all of them are `BaselineHuman` with
different parameters, and all of them can be opened up in the same detail.

**Why it is the first rule:** the moment a boss gets a health bar instead of
organs, every other system in the game develops a special case for it. At v10
there are no special cases. A thing with no anatomy still resolves against zones,
because `AnatomyComponent` describes *where damage went*, not *what species it
was*.

## 2. The world keeps two records

What happened, and what each faction believes happened. They are allowed to
disagree and the game never arbitrates.

At v10 this reaches the story itself: **the nuclear war is fake, and the game
never confirms it.** Crisis-actor footage is findable. The agency publishes its
version. The Board holds both. A player can finish the game believing either.

## 3. Time is real, and everything reads it

`world_clock.gd` is one number. At v10 it is the input to: station schedules,
faction hours, hauntings, repair over a month, practice decay, interest on debts,
the gods visible in the sky, and whether the streets are lit.

**Nothing keeps its own clock.** A system that needs to know what time it is asks.

## 4. Light is the resource

Not health, not ammunition — light. The world is dark, the handheld is the lamp,
the lamp has a battery, holding it up costs you a hand, and its glow is what
anything hunting you sees first.

At v10 the sentence *"I need to see"* and the sentence *"I need to not be seen"*
are the same decision.

## 5. The blow is performed, not requested

`limb_momentum.gd` is the whole of it. The weapon is a mass on the end of an arm;
where you point is where the *anchor* goes; turning throws it; and damage asks
what the business end was actually doing rather than reading a constant.

At v10 there is no attack button in the sense other games have one. There is a
weapon, and there is you moving it.

## 6. A round is an object

It travels, it drops, it slows, it is traced so it cannot pass through a wall,
and when it lands the wall is different. Brass ejects and stays on the floor, so
a room can be read afterwards by whoever walks into it.

## 7. Everything breaks, and the world keeps the damage

Measured, recorded, and repaired over a month of game time by somebody whose job
it is. A holding nobody holds does not get fixed. **Destruction is a ledger entry,
not a particle effect.**

## 8. The tutorial is a place you repair

You do not read help. You stand in a room with a bed and a wall-sized mirror,
turn right to a cloud terminal, and recover fragments of an archive that used to
know everything. Each fragment you restore is a CRT playing one mechanic as a
drawn loop, with the keys underneath.

**The archive is visibly incomplete forever.**

## 9. Two charts, one document

The **pyramid** (AI) is where power is: upright above, inverted below, you at the
waist. As above, so below. The **tree** (AR) is which way you went. They pin onto
the same Board and a theory can connect a tier to a person to a holding.

## 10. Sigilisation is a procedure

State an intent in your own words, watch the letters strip and condense into a
glyph, charge it with something real, and forget it. Five steps that already
exist as a practice, so none of them had to be invented. The same words always
make the same sigil.

At v10 **every system in the game is reachable through a sigil, badly** — which
is the playground Greg asked for, and the rule that lets the system surprise its
own author.

## 11. The gods are what is actually worshipped

Markets, metrics, engagement, brands. Each is a real entity in `WorldHistory`
with attention that can be attracted. Naming one in an intent gets its notice,
which is not always wanted.

Alongside them: a god for each planet, the moon and the sun, visible at their
hours through a broken firmament. **The satire lands on institutions and never on
congregations.**

## 12. The godhead accumulates

It is not revealed. It taunts, its visibility builds from what you have done, and
eventually it summons you rather than being travelled to. It enslaves through its
own lessons and learning, which makes it the correct final boss for a game about
institutions.

**AQ1.6: the fight is not a damage race.** Everything O built is present in it and
none of it is sufficient.

## 13. The universe restarts and you do not

Quantum immortality. Nothing carries in the save-file sense. The world is the
variable and you are the constant, which is the only ending consistent with a
spirit that cannot be banished by violence.

The question this turns T1.3 into is the good one: not *what did I keep*, but
**what is different about this world because a previous one had me in it.**

## 14. Every screen is an object in the world

No screen is a list of text in a box — and, learned the hard way in the derby,
that never meant *no information*. A gauge is an object. An instrument in a
binnacle is an object. The Board on a wall is an object. The handheld is an
object you hold, that lights your hands, that has a jester on the back.

At v10 the whole black mirror GUI is one grammar rather than six well-drawn
pages.

## 15. Sound is a property of the world

Where you are standing decides what you hear. Reception depends on distance,
terrain shadow and the hour. Underground behaves differently. A station that is
off air is not quiet — it is off.

## 16. The psychedelic layer is a real pipeline

Everhood-grade sequences are not decoration bolted on at the end; they are a
production path that has to exist before anything is authored into it. **That
pipeline is the next section.**

---

# Connecting TouchDesigner and Blender

Greg: *"how can i work out how to connect touchdesigner into making the game map
effects insane through the blender 3d rigs for the psycadellic and cutscene
scenes making it like everhood 1 and 2 level psycadellic trip"*.

## The thing to get right first

**TouchDesigner cannot run inside a shipped Godot game.** There is no runtime
where a `.toe` file executes next to your `.pck`. So the question is not "how do
I connect them" but "which of the three jobs does each tool do", and the answer
that ships is:

| Tool | Job | Ships? |
| --- | --- | --- |
| **Blender** | Geometry and rigs. Characters, sets, anything with a skeleton | Yes, as glTF |
| **TouchDesigner** | The **design environment** for the effect, and the baker for anything that cannot be computed live | No — it is authoring |
| **Godot shaders** | Where the effect actually runs, every frame, reacting to the player | Yes |

Treat TD as your **lab**, not your engine. You build the look there because its
operator graph gives you an answer in half a second where a shader edit gives you
one in ten, and then you port what you found.

## Why that is not a compromise

Everhood's look is almost entirely **real-time screen-space work**, and every
technique in it has a direct Godot equivalent:

| Everhood effect | TD operator you'd design it with | Godot equivalent |
| --- | --- | --- |
| Palette cycling / duotone flashes | `Lookup TOP` | A LUT texture sampled in a `screen_texture` shader |
| Kaleidoscope and mirror tiling | `Kaleidoscope TOP` | UV fold in a fragment shader — about six lines |
| Feedback trails and infinite zoom | `Feedback TOP` | A `SubViewport` that samples its own previous frame |
| Chromatic separation | `Displace TOP` | Sample R, G and B at three offset UVs |
| Warp, ripple, melt | `Noise TOP` → `Displace TOP` | A flow map or noise texture displacing UVs |
| Beat-locked cuts | `Audio Analysis CHOP` | An audio bus spectrum feeding a shader uniform |

**None of that is baked video.** All of it reacts to what the player is doing,
which is the entire reason Everhood's sequences land — they are happening *to*
you, not playing *at* you.

## The pipeline, concretely

### Path A — the effect is live (default, use this for the map and for combat)

1. **Design in TD.** Build the operator graph until it looks right. Screenshot
   every parameter you settled on.
2. **Port to a Godot shader.** Most TD TOPs map to a handful of lines of GLSL.
   The graph is the spec.
3. **Bake only the lookups.** LUTs, gradient ramps, noise volumes and flow maps
   are textures — export them from TD as PNG or EXR and load them in Godot. This
   is the honest use of TD as a *generator*: it makes the data, Godot samples it.
4. **Drive it from the game.** Uniforms come from real state: chaos-magick level,
   what drug is active, how close the godhead is, the storm severity from AS4.2.

### Path B — the sequence is authored (use for cutscenes and the shadow realms)

1. **Rig and animate in Blender.** Export glTF for anything Godot will light and
   move itself.
2. **For deforming geometry that Godot cannot rig** — melting, splitting,
   fracturing, anything from Blender's geometry nodes — bake a **Vertex Animation
   Texture**. The mesh's per-frame vertex positions are written into a texture and
   a vertex shader reads it back. This is how you get Blender-grade deformation at
   runtime without a skeleton.
3. **For the full-screen psychedelic passages** — the DMT realms, AQ1.4 — render
   frames out of TD as an image sequence, pack them as a **flipbook atlas**, and
   play them on a quad or as an emissive layer. Flipbooks decode free where video
   does not, and Godot's built-in Theora is not good enough for this.
4. **Composite live over baked.** The baked layer is the ground; the live shader
   layer from Path A goes over it and reacts. That combination is what makes a
   pre-rendered sequence still feel interactive.

### Path C — live link, development only

TD and Godot can talk while you work, and it is worth setting up because it
collapses the iteration loop:

- **OSC** for parameters. TD sends values, Godot receives them over UDP and
  writes them straight into shader uniforms. You dial a slider in TD and watch
  the game change. About thirty lines of GDScript.
- **Spout** (Windows) to share an actual GPU texture between the two apps. Needs
  a GDExtension, does not survive export, and is purely a preview tool.

**Nothing from Path C ships.** It exists so that Path A's porting step is a
five-minute job instead of an afternoon.

## What to build first

1. A `psychedelic.gdshader` with the six effects in the table above, each behind
   a uniform, all at zero by default. **One shader, many dials.**
2. A `SubViewport` feedback rig, because feedback is the single effect that
   cannot be faked and is half of what makes Everhood look like Everhood.
3. One TD patch that generates the LUT and noise textures that shader samples.
4. An OSC bridge for development.

Then the drugs, the meditation, the shadow realms and the godhead's approach are
all the same shader with different dials, and none of them needs its own system.

---

## One thing I could not place

Greg mentioned **"louka vision"** alongside Everhood as a reference. I do not know
what that is and I would rather ask than guess at a visual direction — if it is a
creator, a game or a specific sequence, say which and it goes in section 16.
