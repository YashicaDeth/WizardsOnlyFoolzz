# art/materia

TouchDesigner bakes for the materia screen. Every file is optional; with none
here the game uses what it generates itself. Read by `systems/materia_bakes.gd`.

- `lut_<palette>.png`: a palette LUT (dark left, light right). Palettes:
  prism, warm, ash, cold, sodium, smoke, lead, honey, wire. `lut_ash.png` is
  the deliriant's and must stay dark (materia_test checks it).
- `flow.png`: the warp/melt field, seamless, R and G the two directions.
- `trip_flipbook.png` + `trip_flipbook.json`: the trip's ground, made with
  `tools/touchdesigner/pack_flipbook.py`.

How to make each: DESIGN/TOUCHDESIGNER_PIPELINE.md, section 3.
