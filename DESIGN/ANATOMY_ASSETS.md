# Anatomy assets: what to download, and what is already ruled out

For item 3 of the Dust to Bones pass — the anatomy loading screen with a real
X-ray body and painted plates, and the Sniper Elite-grade X-ray behind it.

**Nothing here has been downloaded.** The rule is that unapproved assets are
listed, not fetched, and this is the list. Drop files into
`P:\GameDev\Incoming\anatomy`.

## The rules these have to satisfy

- **Human-made only.** No generated images or generated meshes, in the game or
  in the tools used to make them. TouchDesigner, After Effects and Photoshop are
  authoring tools: whatever comes out gets baked into shipped textures and
  loops, and the source art does not go in the build.
- **CC0 or CC-BY, credited.** A credit line is part of shipping, not an
  afterthought, so each entry below carries the line to paste.
- **Reference is not theft.** A model may be studied and then replaced with
  original art. It is not traced, and it does not become the shipped look by
  default.

## What the game actually needs

| Need | Where it is used | Notes |
|---|---|---|
| Full skeleton | Loading screen X-ray; the X-ray in every kill cam and cutscene | Proportion has to be right or the whole illusion dies. A 1:1 scale skeleton is worth more than a detailed one at the wrong scale. |
| Organs, detachable | Kill cam and cutscene wound paths; the live X-ray on bodies | Heart, lungs, liver, kidneys, gut. Enough that a round through the chest has somewhere to go. |
| A body to wrap the skeleton in | Loading screen; the vat; the slideable X-ray | Skin and muscle can be painted onto the skeleton rather than modelled. |
| A brain | The Nerve Rig, the brain-chip readouts | Already exists in the game as geometry; a real model is a replacement, not a gap. |

## Verified, and cleared to download

Each of these was opened and the licence read on the model's own page, not
taken from a search result.

| Asset | Author | Licence | Use it for |
|---|---|---|---|
| [Male Skeleton](https://sketchfab.com/3d-models/male-skeleton-11b57ebfcf6c4e3b88d0cbe618ee70a7) | projectkaizen | **CC Attribution** (stated on the page) | The skeleton. 67.5k triangles, every major skeletal structure, labelled bones, rigged per-bone. 3,858 downloads, so it is a model people have actually used rather than one nobody has opened. |

Credit line, verbatim, for wherever this ends up credited:

> Male Skeleton by projectkaizen, licensed CC BY 4.0, via Sketchfab.

## The recommended source for the organs

**NIH 3D — <https://3d.nih.gov/>** — the open repository run by the US National
Institutes of Health. It has an Anatomy category, the models are made by
medical imaging researchers rather than by a generator, and each model carries
its own Creative Commons licence or is released to the public domain.

Two things to know before starting:

- **The licence is per model, not per site.** Check the licence on each model
  page and paste its credit line. Do not assume one licence covers the site.
- **These are print-derived.** They are excellent as bone and organ *shapes* and
  will want work before they read as a body under a shader. That is the point:
  the shapes are real, and the look is ours.

## Ruled out, and why — so nobody re-adds them

| Asset | Why not |
|---|---|
| [Animated Full Human Body Anatomy](https://sketchfab.com/3d-models/animated-full-human-body-anatomy-9b0b079953b840bc9a13f524b60041e4) by AVRcontent | **A paid Sketchfab Store product**, not CC-BY. It is also, by a distance, the best-suited free-ly available asset for this: skeleton, brain, digestive, lungs, heart, diaphragm, urinary, liver, gallbladder, eyes, circulatory, skin and muscular, all detachable. See the decision below. |
| [Skeleton with Organs](https://sketchfab.com/3d-models/skeleton-with-organs-ad5a405ab2c34a1aa9d03e311feff8f0) by Mali_Mrtva | No licence line and no download button on the model page. Sixteen organs on a skeleton is exactly the right idea, and there is nothing to attribute, so it cannot be cleared. |
| [Ecorche — Skeleton and Muscles](https://sketchfab.com/3d-models/ecorche-skeleton-and-muscles-3555abac11c744d29bc4e5e52d8b47f4) by VeryCrunchyTaco | No licence line and no download button either. The description invites you to download it for reference; the page does not offer a licence to do it under. |

The common thread in the last two: they look like free community models in a
search result, and they are not clearable. A missing licence is not a permissive
one.

## The decision, for Greg

The anatomy loading screen and the X-ray want one asset that is fully
articulated and detachable. There are two ways to get there:

1. **Buy the AVRcontent model.** One purchase, everything in one file, the
   fastest route to the Sniper Elite look by a wide margin. It breaks the
   CC-BY-only rule, deliberately and visibly.
2. **Assemble from NIH 3D and projectkaizen.** Stays inside the rule, costs
   nothing, and is more work: bones from projectkaizen, organs from NIH 3D, and
   someone has to make them read as one body rather than a kit of parts.

Recommendation is **2**, because the rule exists to keep the shipped art ours
and a bought model's look is not, and because the organs only have to be right
where a round can reach them. But 1 is a legitimate buy if the X-ray is the
thing the remaster is judged on, and that is Greg's call, not mine.

## Naming, so the drop is unambiguous

```
P:\GameDev\Incoming\anatomy\
  bones\      projectkaizen_male_skeleton.fbx
  organs\     nih3d_<organ>_<licence>.glb
  body\       (nothing yet — see the decision above)
  LICENCE.md  one line per file: source URL, author, licence, credit line
```

`LICENCE.md` is the file that makes this auditable later. One line per asset,
written at download time, because reconstructing where a model came from six
months later is how a credit line gets invented.
