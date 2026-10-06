"""Synthesise the liquid station's sounds into game/audio/fluid/*.ogg.

imp-61. Greg (5 Oct ~19:00): "Fix and improve the pour (a real liquid
surface, not spheres) and add sound." Made here from noise and damped
resonances (Minnaert bubble chirps for the liquid, inharmonic pings and
crackle for the glass), so there is no third-party licence to carry.

    python tools/synth_fluid_sounds.py            # writes game/audio/fluid/
    python tools/synth_fluid_sounds.py --out DIR  # somewhere else

Needs numpy and imageio-ffmpeg (for the Vorbis encode). Deterministic: every
sound has its own fixed seed.
"""
import argparse
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100


def band(signal, low, high):
    """Brick-wall band-pass in the frequency domain, with soft shoulders."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(signal.size, 1.0 / RATE)
    mask = np.ones_like(freqs)
    if low > 0:
        mask *= 1.0 / (1.0 + (low / np.maximum(freqs, 1.0)) ** 4)
    if high > 0:
        mask *= 1.0 / (1.0 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * mask, signal.size)


def env(n, attack, decay):
    t = np.arange(n) / RATE
    rise = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    return rise * np.exp(-np.maximum(t - attack, 0.0) / decay)


def place(out, sound, at):
    start = int(at * RATE)
    if start >= out.size:
        return
    end = min(out.size, start + sound.size)
    out[start:end] += sound[: end - start]


def ping(freq, decay, length):
    t = np.arange(int(length * RATE)) / RATE
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)


def bubble(rng, radius_mm=None, amp=1.0):
    """Minnaert resonance of a bubble, pitch rising as it nears the surface."""
    radius = (radius_mm or rng.uniform(1.5, 6.0)) / 1000.0
    f0 = 3.26 / radius
    decay = 0.0025 + radius * 3.0
    t = np.arange(int(decay * 6 * RATE)) / RATE
    rise = 1.0 + rng.uniform(0.6, 2.2) * t / (decay * 6)
    phase = 2 * np.pi * np.cumsum(f0 * rise) / RATE
    return amp * np.sin(phase) * np.exp(-t / decay)


def glass_crack(stage):
    rng = np.random.default_rng(100 + stage)
    length = 0.35 + stage * 0.2
    out = np.zeros(int(length * RATE))
    # The knock: a short broadband tick and a body thump.
    tick = rng.standard_normal(int(0.004 * RATE)) * env(int(0.004 * RATE), 0.0003, 0.0012)
    place(out, band(np.pad(tick, (0, 2048)), 1500, 0) * 1.4, 0.0)
    place(out, ping(rng.uniform(140, 190), 0.05, 0.25) * 0.35, 0.0)
    # The glass rings, inharmonic and high.
    for _ in range(4 + stage * 2):
        place(out, ping(rng.uniform(2200, 7800), rng.uniform(0.02, 0.09), 0.3) * rng.uniform(0.05, 0.16), rng.uniform(0.0, 0.01))
    # The crack running: sparse clicks, more and longer with each stage.
    clicks = 18 + stage * 22
    for index in range(clicks):
        when = 0.005 + (index / clicks) ** 1.4 * (0.12 + stage * 0.12) + rng.uniform(0.0, 0.01)
        click = rng.standard_normal(int(0.0015 * RATE)) * rng.uniform(0.15, 0.6)
        place(out, click * np.hanning(click.size), when)
    out = band(out, 120, 14000)
    return out


def glass_burst():
    rng = np.random.default_rng(7)
    out = np.zeros(int(1.8 * RATE))
    noise = rng.standard_normal(out.size)
    out += band(noise, 900, 12000) * env(out.size, 0.002, 0.09) * 0.9
    out += band(rng.standard_normal(out.size), 40, 260) * env(out.size, 0.004, 0.18) * 1.6
    # Shards: many short inharmonic tinkles, densest at the break, then the
    # pieces landing over the next second.
    for _ in range(260):
        when = rng.exponential(0.22)
        if when > 1.5:
            continue
        place(out, ping(rng.uniform(1800, 9500), rng.uniform(0.006, 0.05), 0.12) * rng.uniform(0.04, 0.22), when)
    for _ in range(90):
        click = rng.standard_normal(int(0.002 * RATE)) * rng.uniform(0.1, 0.5)
        place(out, click * np.hanning(click.size), rng.uniform(0.0, 0.25))
    return out


def fluid_gush():
    rng = np.random.default_rng(11)
    out = np.zeros(int(2.4 * RATE))
    body = band(rng.standard_normal(out.size), 70, 900)
    swell = env(out.size, 0.03, 0.9)
    # Glugging: the flow throbs as air fights its way back in.
    t = np.arange(out.size) / RATE
    throb = 0.7 + 0.3 * np.sin(2 * np.pi * (5.5 - t * 1.2) * t)
    out += body * swell * throb * 1.5
    out += band(rng.standard_normal(out.size), 1200, 5000) * env(out.size, 0.01, 0.35) * 0.25
    for _ in range(120):
        when = rng.exponential(0.5)
        if when < 2.2:
            place(out, bubble(rng, rng.uniform(3.0, 12.0), rng.uniform(0.1, 0.35)), when)
    return out


def fluid_pour_loop():
    rng = np.random.default_rng(13)
    seconds = 2.0
    n = int(seconds * RATE)
    out = band(rng.standard_normal(n + RATE), 90, 1400) * 0.9
    out += band(rng.standard_normal(n + RATE), 1500, 6000) * 0.12
    for _ in range(220):
        place(out, bubble(rng, rng.uniform(2.0, 9.0), rng.uniform(0.08, 0.3)), rng.uniform(0.0, seconds + 0.9))
    # Seamless: fold the extra second over the start with a crossfade.
    fade = int(0.4 * RATE)
    tail = out[n : n + fade]
    ramp = np.linspace(0.0, 1.0, fade)
    loop = out[:n].copy()
    loop[:fade] = loop[:fade] * ramp + tail * (1.0 - ramp)
    return loop


def fluid_splash():
    rng = np.random.default_rng(17)
    out = np.zeros(int(0.5 * RATE))
    out += band(rng.standard_normal(out.size), 400, 4200) * env(out.size, 0.002, 0.06)
    out += band(rng.standard_normal(out.size), 80, 400) * env(out.size, 0.001, 0.03) * 0.8
    for _ in range(9):
        place(out, bubble(rng, None, rng.uniform(0.15, 0.4)), rng.uniform(0.005, 0.12))
    return out


def fluid_splat():
    rng = np.random.default_rng(19)
    out = np.zeros(int(0.35 * RATE))
    out += band(rng.standard_normal(out.size), 150, 1800) * env(out.size, 0.001, 0.035) * 1.2
    place(out, ping(110, 0.04, 0.3) * 0.5, 0.0)
    for _ in range(3):
        place(out, bubble(rng, rng.uniform(4.0, 8.0), 0.2), rng.uniform(0.01, 0.06))
    return out


def wade(index):
    rng = np.random.default_rng(23 + index)
    out = np.zeros(int(0.6 * RATE))
    out += band(rng.standard_normal(out.size), 120, 1300 + index * 300) * env(out.size, 0.05 + index * 0.01, 0.13)
    out += band(rng.standard_normal(out.size), 1500, 4500) * env(out.size, 0.03, 0.06) * 0.15
    for _ in range(6 + index * 2):
        place(out, bubble(rng, rng.uniform(2.5, 8.0), rng.uniform(0.1, 0.3)), rng.uniform(0.02, 0.25))
    return out


def write(path, signal, peak=0.89, loop=False):
    signal = signal - np.mean(signal)
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * peak
    if not loop:
        fade = int(0.01 * RATE)
        signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    pcm = (signal * 32767).astype(np.int16)
    import imageio_ffmpeg

    with tempfile.TemporaryDirectory(dir=os.environ.get("TEMP")) as scratch:
        raw = os.path.join(scratch, "x.wav")
        with wave.open(raw, "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes(pcm.tobytes())
        subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", raw, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    print(path, f"{signal.size / RATE:.2f}s")


def main():
    parser = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    parser.add_argument("--out", default=os.path.join(here, "..", "game", "audio", "fluid"))
    out = parser.parse_args().out
    os.makedirs(out, exist_ok=True)
    for stage in (1, 2, 3):
        write(os.path.join(out, f"glass_crack_{stage}.ogg"), glass_crack(stage))
    write(os.path.join(out, "glass_burst.ogg"), glass_burst())
    write(os.path.join(out, "fluid_gush.ogg"), fluid_gush())
    write(os.path.join(out, "fluid_pour_loop.ogg"), fluid_pour_loop(), 0.7, loop=True)
    write(os.path.join(out, "fluid_splash.ogg"), fluid_splash())
    write(os.path.join(out, "fluid_splat.ogg"), fluid_splat())
    for index in (1, 2, 3):
        write(os.path.join(out, f"wade_{index}.ogg"), wade(index), 0.75)


if __name__ == "__main__":
    main()
