# Asset tools (26 September)

Greg: "use all these in game creation." Six repos, each pinned to one commit.
The generators need an NVIDIA GPU, so they run on Greg's RTX, not in the
cloud. Everything they make is **placeholder** until Greg's own art replaces
it ("without making things feel really AI gen"). Pick with a grain of salt,
and bring in only what fits.

## The flow

1. Run a tool on the PC. Its output goes in `P:\GameDev\gen\<tool>\`, never
   in the repo.
2. Curate. Keep only pieces that fit the look (PS1 crunch, low-poly, bone,
   rust, grain). Delete the rest.
3. Import with the logger, which copies the file into
   `game/art/generated/<category>/` and adds its line to
   `game/art/GENERATED.md`:
   ```
   python tools/import_generated_asset.py <file> --tool <tool> --category <props|enemies|rooms|sprites|plates> --prompt "<prompt>" --lane <A-E> --for "<where it goes>"
   ```
4. Wire it into its scene, render that scene, and open the PNG (the
   `wof-verify-by-looking` skill).
5. Commit with Git LFS installed. Media only goes through LFS.

## The tools and what each is for here

| Tool | Pinned | Use it for | Needs |
|---|---|---|---|
| [joe-lloyd/game-asset-generation](https://github.com/joe-lloyd/game-asset-generation) | `49175414180e` | **The main one.** Built for classic survival horror: pre-rendered room backdrops (loading screens, the Wire), low-poly GLB props, character sheets for the examiner and guards | ComfyUI + SDXL, optional TRELLIS.2 node; 12 GB VRAM (24 better) |
| [OpenX-Inc/clay](https://github.com/OpenX-Inc/clay) | `eb41696224cc` | Game-ready 3D with colliders and LODs: stash crates, vat hardware, Hunt scrap, enemy bodies. LODs and colliders keep the 160 fps | CUDA backend (local or RunPod); Blender for rigging. **Use TRELLIS-2 / Hi3DGen, not Hunyuan** |
| [Bingeljell/image-to-3dlab](https://github.com/Bingeljell/image-to-3dlab) | `1e6972d351f6` | Turning one of Greg's drawings or a curated Higgsfield still into a 3D model. Writes a `.provenance.json`; pass it to the importer with `--provenance` | 24 GB NVIDIA (Linux) or Apple Silicon; **Pixal3D / TRELLIS.2 backends** |
| [FishWoWater/hunyuan_trellis_fast](https://github.com/FishWoWater/hunyuan_trellis_fast) | `a893cd54a721` | Fast rough blockouts (about 8 s, 8 GB) to test a shape before making it properly | Hunyuan3D-2 licence: **non-commercial when self-hosted, not licensed in the EU/UK/South Korea.** Blockouts only; the importer refuses it without `--accept-hunyuan-license` |
| [mohabash/ai-game-asset-generator](https://github.com/mohabash/ai-game-asset-generator) | `3738f2b52c68` | Top-down vehicle sprites for the satellite map and the derby's overhead views | RunComfy account + FLUX.1-dev (a non-commercial model licence) |
| [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | `44888f28ff91` | **Installed** as `.claude/skills/godot-*` (15 skills, Apache-2.0; licence in `.claude/skills/_vendor/`). Every agent in the repo reads them | Nothing |

## Rules

- Greg's own art is never overwritten; the importer refuses existing files.
- Nothing generated goes in without its `GENERATED.md` line.
- Before placing a 3D model: the MeshBudget caps apply to primitive meshes
  only, so check the triangle count yourself. Keep props under about 5,000
  triangles and use the LODs Clay makes.
- Don't upgrade a pinned tool without asking Greg.
