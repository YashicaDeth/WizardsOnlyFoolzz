# Cutscene art slots

`cutscenes/art_slot_stage.tscn` is a neutral cutscene stage made of named layers.
Each slot draws a plain labelled grey block until you put a PNG with the same name
in this folder; your file then replaces it with no code change. The placeholders
suggest nothing about content: what each layer shows is yours.

    Godot --path game res://cutscenes/art_slot_stage.tscn

| File | Layer | Notes |
|---|---|---|
| `bg_far.png` | Furthest background | Tiles horizontally, drifts slowest |
| `bg_mid.png` | Middle background | Tiles, drifts a little faster |
| `bg_near.png` | Nearest background | Tiles, drifts faster again |
| `ground.png` | The surface actors stand on | Tiles, a thin strip |
| `ground_under.png` | What is below the surface | Tiles |
| `actor_a.png` | First character | Transparent background |
| `actor_b.png` | Second character | Transparent background |
| `prop.png` | A prop | Transparent background |
| `frame.png` | Border over everything | Full screen, transparent middle |

Tiling layers scale to their band's height; keep their left and right edges
seamless. Positions, sizes and any movement are set per scene once you decide
what the scenes are; sprite sheets for animated actors can be added the same way.
