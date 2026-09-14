"""Convert Greg's own footage into something Godot can actually play.

Godot 4 plays exactly one video format natively: **Ogg Theora** (`.ogv`). No
MP4, no MOV, no WebM. Greg's material is MJPEG .mov out of DaVinci and H.264
.mp4 out of OBS, so none of it can be dropped into the project as-is — which is
the real reason "just add my video" is a tooling job rather than a drag and drop.

This is that job. Sources stay where they are and are never written to; the
derived `.ogv` lands in `game/art/derived/video/` and rebuilds from scratch.

Two decisions worth stating, because both cost quality on purpose:

- **Downscaled.** The sources are 1280x854 and 1920x1080 at 60fps. A title
  backdrop does not need either. 960 wide at 30fps is the point where Theora
  stops looking like a compression artefact and the file stops being enormous.
- **Silent by default.** The intro plays under the cold open, which already has
  its own audio design. `--audio` keeps the original track when a clip is meant
  to bring its own.

Run:
  python tools/derive_video.py --name intro --source "C:/.../s1tartintro.mov"
  python tools/derive_video.py --name mandala --source "C:/.../Past (17).mp4" --seconds 8
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(HERE, "game", "art", "derived", "video")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--name", required=True, help="output stem, e.g. 'intro'")
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--fps", type=int, default=30)
    # 0-10 for libtheora. 6 holds a graded night shot together; below 5 the
    # blacks band badly, which is exactly where this footage lives.
    parser.add_argument("--quality", type=int, default=6)
    parser.add_argument("--seconds", type=float, default=0.0, help="trim; 0 = whole clip")
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--audio", action="store_true")
    args = parser.parse_args()

    try:
        import imageio_ffmpeg
    except ImportError:
        print("needs imageio-ffmpeg: python -m pip install imageio-ffmpeg")
        return 2

    if not os.path.exists(args.source):
        print("source not found: %s" % args.source)
        return 1

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, args.name + ".ogv")

    cmd = [ffmpeg, "-y", "-loglevel", "error"]
    if args.start > 0.0:
        cmd += ["-ss", str(args.start)]
    cmd += ["-i", args.source]
    if args.seconds > 0.0:
        cmd += ["-t", str(args.seconds)]
    cmd += [
        "-c:v", "libtheora",
        "-q:v", str(args.quality),
        "-r", str(args.fps),
        # -2 keeps the source aspect and rounds to an even height, which Theora
        # requires and which silently fails the encode if you let it be odd.
        "-vf", "scale=%d:-2" % args.width,
    ]
    cmd += ["-c:a", "libvorbis", "-q:a", "3"] if args.audio else ["-an"]
    cmd += [out_path]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not os.path.exists(out_path):
        print("encode failed:\n%s" % result.stderr.strip()[:900])
        return 1

    print("%-10s %s -> %s" % (args.name, os.path.basename(args.source), out_path))
    print("           %.1f MB at %dpx / %dfps / q%d%s" % (
        os.path.getsize(out_path) / 1048576.0, args.width, args.fps, args.quality,
        "" if args.audio else " (silent)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
