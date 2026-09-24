# Cutscene art slots

`cutscenes/art_slot_stage.tscn` is a side-on cutscene stage made of named slots.
Every slot draws a rough placeholder (labelled with its name) until you put a PNG
with the same name in this folder. Your file then replaces the placeholder with no
code change. Run the stage with:

    Godot --path game res://cutscenes/art_slot_stage.tscn

| File | What it is | Notes |
|---|---|---|
| `backdrop.png` | Deep background behind everything | Stretched to the stage |
| `bg_skulls.png` | Back row of large spiked skulls | Tiles horizontally, drifts slowly (parallax 0.25) |
| `floor_top.png` | The walkable ledge surface | Tiles horizontally, a thin strip |
| `floor_worms.png` | Band of worms / guts under the ledge | Tiles horizontally, scrolls with the camera |
| `actor_runner.png` | The character that runs and leaps | About 1:2 (width:height), transparent background |
| `actor_jar.png` | A body in a jar that rides up and down | About 3:5, transparent background |
| `prop_orb.png` | An eye or orb that rolls along the ledge | Square, transparent background; it spins |
| `frame.png` | Ornate border over everything | Full screen, transparent middle |

Tiling slots scale to the band's height, so draw them at any height and keep the
left and right edges seamless. For animated characters later, the next step is a
sprite sheet per actor; ask and the slot will read frames from it.
