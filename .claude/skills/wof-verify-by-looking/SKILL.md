---
name: wof-verify-by-looking
description: Prove a visual change in Wizards Only Fools by rendering it and opening the PNG before claiming anything. Use for any change to shaders, HUD, transitions, lighting, VFX, materials, UI or camera — whenever a commit message would say how something looks.
metadata:
  project: AllusionsTooGrandeur
---

# Verify by looking

This repo has shipped several "it looks X" claims that were wrong, and one
script titled as seen that did not compile. Headless runs render nothing, so a
green test proves nothing about a picture. The rule: **capture it, open it,
say what is in it.**

## Capture an existing scene

```bash
G="P:/GameDev/Tools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe"
export TEMP=P:/GameDev/Temp TMP=P:/GameDev/Temp
"$G" --path game res://tests/capture_scene.tscn -- \
  --scene=res://bone_yard_hunt.tscn --out=P:/GameDev/Temp/look.png --frames=120
```

Every capture prints the hour, phase and daylight it shot at. **Read that
line.** The world clock persists between runs; a long settle once walked the
Hunt Grounds into dusk and a black frame was misfiled as a lighting bug.
`--hour=N` pins it.

## Capture a new component: the gallery pattern

For a new visual system, add `game/prototype_lab/<thing>_gallery.tscn` that
stages it in several states at once over real art (Greg's derived plates in
`game/art/derived/`), and accepts `-- --shot=PATH` (or `--shots=DIR`) to
write PNGs and quit. Examples already in the repo:
`transition_gallery` (each wipe at 35/70/100%), `nerve_rig_gallery`
(whole / hurt / dying side by side), `strike_fx_gallery` (a sweep over a
locked target). Run it windowed (not `--headless`) with `--resolution`.

## Look

- Tile several captures into one contact sheet (PIL) and open it with your
  image-reading tool. Crop and upscale any detail you are judging.
- Describe what is actually on screen, then compare with the intent.
- Allow one fix-and-recapture pass for what the look showed. Name the fix in
  the commit ("reworked vertebrae from boxes into bone shapes after the
  first look").
- If you could not open the image, say so in the commit instead of claiming
  the result. `[NOT YET SEEN RENDERED]` in a title is honest and fine.

## Motion: record it

A still cannot show a wipe, a trail or a swing. Godot's Movie Maker renders a
scene deterministically at a fixed frame rate, however slow the machine:

```bash
"$G" --path game --resolution 1280x720 --write-movie P:/GameDev/Temp/clip.avi \
  --fixed-fps 30 --quit-after 180 res://prototype_lab/strike_fx_gallery.tscn
# transition_gallery plays every wipe with: ... transition_gallery.tscn -- --reel
python -c "import imageio_ffmpeg,subprocess;subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-i','P:/GameDev/Temp/clip.avi','-c:v','libx264','-pix_fmt','yuv420p','P:/GameDev/Temp/clip.mp4'])"
```

Check it with a contact sheet (`-vf fps=2,scale=320:-2,tile=4x3`) and send
the MP4 to Greg — it is the thing he actually judges.

## New worktree first run

A fresh worktree has no `.godot/` cache and no class registry, so new
`class_name` scripts fail to resolve. Run once:
`"$G" --headless --path game --import` (about a minute).
