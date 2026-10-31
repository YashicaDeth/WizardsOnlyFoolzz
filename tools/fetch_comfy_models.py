#!/usr/bin/env python3
"""Download the three models for ComfyUI, then make a first image through it.

Greg, 26 September: "auto download and run all 3 of these models so I can get
closer to using ComfyUI generation". Runs on Greg's PC (Windows, RTX):

  1. Juggernaut XL v9      -> <ComfyUI>/models/checkpoints   (SDXL images)
  2. xinsir openpose SDXL  -> <ComfyUI>/models/controlnet    (pose-locked characters)
  3. TRELLIS.2-4B + DINOv3 -> <ComfyUI>/models/trellis2, models/facebook  (image to 3D)

Then it sends one text-to-image job to the running ComfyUI (port 8188, or
8000 for ComfyUI Desktop) and says where the picture landed.

    python tools/fetch_comfy_models.py --comfy "C:/Users/<you>/Documents/ComfyUI"

Downloads are pinned to exact revisions where one is known, and resume if
interrupted. The Hugging Face cache stays on P:/GameDev/hf, not C:.
"""
import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

os.environ.setdefault("HF_HOME", r"P:\GameDev\hf")

# (repo, revision or None, files or None for the whole repo, models subfolder, rename)
MODELS = [
    ("RunDiffusion/Juggernaut-XL-v9", None, ["Juggernaut*.safetensors"], "checkpoints", None),
    ("xinsir/controlnet-openpose-sdxl-1.0", "25bcee1b31701ba33ae71483be955fb8a6284718",
     ["diffusion_pytorch_model.safetensors"], "controlnet", "controlnet-openpose-sdxl-1.0.safetensors"),
    ("microsoft/TRELLIS.2-4B", None, None, "trellis2/TRELLIS.2-4B", None),
    ("facebook/dinov3-vitl16-pretrain-lvd1689m", None, None, "facebook/dinov3-vitl16-pretrain-lvd1689m", None),
]

PROMPT = ("first-person body-cam view down a dark cloning-facility aisle, cracked glass vats with curled pale "
          "bodies, one red vat glow, rusted pipes and cables, PS1-era low-poly look, heavy film grain, muted "
          "bone and rust colours, no text")
NEGATIVE = "bright, clean, glossy, cartoon, text, watermark, logo"


def ensure_hub():
    try:
        import huggingface_hub  # noqa: F401
    except ImportError:
        print("installing huggingface_hub ...")
        import subprocess
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-U", "huggingface_hub"])


def fetch(models_dir: pathlib.Path) -> list:
    from huggingface_hub import snapshot_download
    from huggingface_hub.utils import GatedRepoError, RepositoryNotFoundError
    problems = []
    for repo, revision, patterns, sub, rename in MODELS:
        target = models_dir / sub
        target.mkdir(parents=True, exist_ok=True)
        print(f"\n== {repo} -> {target}")
        try:
            snapshot_download(repo_id=repo, revision=revision, allow_patterns=patterns, local_dir=str(target))
        except GatedRepoError:
            problems.append(f"{repo} is gated: open https://huggingface.co/{repo}, accept its licence, "
                            f"run 'hf auth login' (or 'huggingface-cli login'), then run this again")
            continue
        except RepositoryNotFoundError:
            problems.append(f"{repo} not found (or needs a login)")
            continue
        if rename:
            original = target / "diffusion_pytorch_model.safetensors"
            if original.exists():
                original.replace(target / rename)
                print(f"   renamed to {rename} (the asset tool looks for 'openpose' in the name)")
    return problems


def find_comfy() -> str:
    for port in (8188, 8000):
        try:
            urllib.request.urlopen(f"http://127.0.0.1:{port}/system_stats", timeout=3)
            return f"http://127.0.0.1:{port}"
        except (urllib.error.URLError, OSError):
            continue
    return ""


def first_image(base: str, checkpoint: str) -> None:
    graph = {
        "1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": checkpoint}},
        "2": {"class_type": "CLIPTextEncode", "inputs": {"text": PROMPT, "clip": ["1", 1]}},
        "3": {"class_type": "CLIPTextEncode", "inputs": {"text": NEGATIVE, "clip": ["1", 1]}},
        "4": {"class_type": "EmptyLatentImage", "inputs": {"width": 1344, "height": 768, "batch_size": 1}},
        "5": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "positive": ["2", 0], "negative": ["3", 0],
                                                   "latent_image": ["4", 0], "seed": 1026, "steps": 30, "cfg": 5.0,
                                                   "sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1.0}},
        "6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
        "7": {"class_type": "SaveImage", "inputs": {"images": ["6", 0], "filename_prefix": "wof_vat_aisle"}},
    }
    body = json.dumps({"prompt": graph}).encode()
    request = urllib.request.Request(f"{base}/prompt", data=body, headers={"Content-Type": "application/json"})
    try:
        reply = json.load(urllib.request.urlopen(request, timeout=30))
    except urllib.error.HTTPError as error:
        print("ComfyUI refused the job:", error.read().decode(errors="replace")[:600])
        return
    prompt_id = reply.get("prompt_id", "")
    print(f"\nqueued in ComfyUI ({prompt_id}); waiting for the image ...")
    for _ in range(300):
        time.sleep(2)
        history = json.load(urllib.request.urlopen(f"{base}/history/{prompt_id}", timeout=10))
        if prompt_id in history:
            for node in history[prompt_id].get("outputs", {}).values():
                for image in node.get("images", []):
                    print(f"done: ComfyUI/output/{image.get('subfolder', '')}/{image['filename']}".replace("//", "/"))
            return
    print("still running after 10 minutes; check the ComfyUI window")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--comfy", default=str(pathlib.Path.home() / "Documents" / "ComfyUI"),
                        help="the ComfyUI folder (the one holding 'models'); ComfyUI Desktop asks for it at install")
    parser.add_argument("--skip-download", action="store_true")
    args = parser.parse_args()
    models_dir = pathlib.Path(args.comfy) / "models"
    if not models_dir.is_dir():
        print(f"no models folder at {models_dir}. In ComfyUI Desktop: menu > Help > Open Models Folder, "
              f"then pass its parent with --comfy", file=sys.stderr)
        return 2
    problems = []
    if not args.skip_download:
        ensure_hub()
        problems = fetch(models_dir)
    checkpoints = sorted(p.name for p in (models_dir / "checkpoints").glob("Juggernaut*.safetensors"))
    base = find_comfy()
    if not base:
        print("\nComfyUI isn't running (tried ports 8188 and 8000). Open ComfyUI Desktop, then run this again "
              "with --skip-download to make the first image.")
    elif not checkpoints:
        print("\nno Juggernaut checkpoint found, so no test image")
    else:
        print(f"\nComfyUI found at {base}; press R in ComfyUI (refresh) if it doesn't list the new models")
        first_image(base, checkpoints[0])
    print("\nTRELLIS.2 (image to 3D) runs from ComfyUI itself: menu > Browse Templates > 3D > TRELLIS.2, "
          "or the ComfyUI-Trellis2 node. The models for it are now in place.")
    for problem in problems:
        print("NOTE:", problem)
    return 0


if __name__ == "__main__":
    sys.exit(main())
