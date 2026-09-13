"""Drive the psy lab's dials over OSC without TouchDesigner.

FINAL_V section 16 says TD is the lab and cannot ship inside the game, so the
dials are OSC and anything that speaks OSC can turn them. This is the smallest
possible such thing: standard library only, no TD install, no patch to load.

    python tools/psy_dials.py                 # cycle the presets, 6s apart
    python tools/psy_dials.py sober           # snap to one preset
    python tools/psy_dials.py kaleidoscope_segments=8 lut_strength=0.6

Start-PsyLab.ps1 first, or there is nothing listening.
"""
import socket
import struct
import sys
import time

HOST, PORT = "127.0.0.1", 9000

# Every dial psychedelic_rig.gd exposes, with the value that means "off".
DIALS = {
    "kaleidoscope_segments": 0.0,
    "kaleidoscope_spin": 0.0,
    "feedback_strength": 0.0,
    "feedback_zoom": 1.0,
    "feedback_spin": 0.0,
    "chromatic_offset": 0.0,
    "displacement_strength": 0.0,
    "displacement_scroll": 0.3,
    "lut_strength": 0.0,
    "cut_intensity": 0.0,
    "cut_seed": 0.0,
    "cut_rate": 0.0,
}

# Named states rather than named drugs: AU decides which substance reaches for
# which of these, and the rig should not have opinions about that.
PRESETS = {
    "sober": {},
    "come_up": {
        "chromatic_offset": 0.006,
        "displacement_strength": 0.02,
        "lut_strength": 0.2,
    },
    "peak": {
        "kaleidoscope_segments": 6.0,
        "kaleidoscope_spin": 0.35,
        "chromatic_offset": 0.018,
        "displacement_strength": 0.05,
        "lut_strength": 0.5,
    },
    "trails": {
        "feedback_strength": 0.55,
        "feedback_zoom": 1.02,
        "feedback_spin": 0.06,
        "chromatic_offset": 0.01,
    },
    "bad_trip": {
        "kaleidoscope_segments": 3.0,
        "kaleidoscope_spin": -0.8,
        "displacement_strength": 0.12,
        "chromatic_offset": 0.03,
        "cut_intensity": 0.45,
        "cut_rate": 6.0,
        "lut_strength": 0.7,
    },
}


def osc(address, value):
    """One OSC message: padded address, ',f' typetag, big-endian float."""
    def pad(raw):
        raw += b"\x00"
        return raw + b"\x00" * ((4 - len(raw) % 4) % 4)
    return pad(address.encode()) + pad(b",f") + struct.pack(">f", float(value))


def send(sock, values):
    """Always send every dial, so a preset turns the previous one off.

    Sending only what changed is how the capture harness ended up with
    feedback still at 0.72 underneath the 'everything' shot and a frame that
    had washed itself flat grey.
    """
    state = dict(DIALS)
    state.update(values)
    for name, value in state.items():
        sock.sendto(osc("/psy/" + name, value), (HOST, PORT))
    return state


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    args = sys.argv[1:]

    pairs = dict(a.split("=", 1) for a in args if "=" in a)
    names = [a for a in args if "=" not in a]

    if pairs:
        send(sock, {k: float(v) for k, v in pairs.items()})
        print("set " + ", ".join("%s=%s" % kv for kv in sorted(pairs.items())))
        return

    order = names if names else list(PRESETS)
    for name in order:
        if name not in PRESETS:
            print("no preset %r - have: %s" % (name, ", ".join(PRESETS)))
            continue
        send(sock, PRESETS[name])
        print(name.upper().replace("_", " "))
        if len(order) > 1:
            time.sleep(6.0)


if __name__ == "__main__":
    main()
