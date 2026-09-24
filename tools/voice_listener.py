"""Offline push-to-talk speech recognition for the NPC conversation system.

The AI NPC spec's input pipeline is "microphone -> voice activity / push-to-talk
-> streaming speech-to-text -> utterance buffer". Godot has the microphone
(`AudioEffectCapture`) but no speech recogniser, and the two offline options
that do not need an API key are Windows SAPI and Vosk.

SAPI was tried first and measured rather than assumed: on open dictation it
returned "Added to a gold funds and this was his vision commission" at
confidence 0.04. Unusable for free-form game dialogue.

So this: Vosk, offline, no key, no network once the model is on disk.

Talking to Godot
----------------
Godot cannot read a child process's stdout asynchronously, so the two sides
share two small files instead, which is boring and completely reliable:

    <bridge>/state.txt       written by Godot: "listen" or "idle"
    <bridge>/transcript.txt  written here: one final utterance per line

Godot writes "listen" while V is held, and consumes lines from transcript.txt
as they appear. Audio captured while the state is "idle" is discarded, so the
microphone is only ever listened to on purpose -- which is a privacy property,
not just a performance one.

Usage:
    python voice_listener.py --model <dir> --bridge <dir> [--device N]
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import sys
import time

SAMPLE_RATE = 16000
BLOCK = 8000


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="Vosk model directory")
    parser.add_argument("--bridge", required=True, help="Directory shared with Godot")
    parser.add_argument("--device", type=int, default=None, help="Input device index")
    parser.add_argument("--list-devices", action="store_true")
    args = parser.parse_args()

    import sounddevice as sd

    if args.list_devices:
        for index, device in enumerate(sd.query_devices()):
            if device["max_input_channels"] > 0:
                print(f"DEVICE {index} :: {device['name']}")
        return 0

    from vosk import Model, KaldiRecognizer, SetLogLevel

    SetLogLevel(-1)

    os.makedirs(args.bridge, exist_ok=True)
    state_path = os.path.join(args.bridge, "state.txt")
    transcript_path = os.path.join(args.bridge, "transcript.txt")
    status_path = os.path.join(args.bridge, "status.txt")

    def status(text: str) -> None:
        with open(status_path, "w", encoding="utf-8") as handle:
            handle.write(text)

    status("loading")
    model = Model(args.model)
    recognizer = KaldiRecognizer(model, SAMPLE_RATE)
    recognizer.SetWords(False)

    audio: "queue.Queue[bytes]" = queue.Queue()

    def on_audio(indata, _frames, _time, state) -> None:
        if state:
            print(state, file=sys.stderr)
        audio.put(bytes(indata))

    def read_state() -> str:
        try:
            with open(state_path, "r", encoding="utf-8") as handle:
                return handle.read().strip().lower()
        except OSError:
            return "idle"

    def emit(text: str) -> None:
        cleaned = " ".join(text.split()).strip()
        if not cleaned:
            return
        # Appended rather than overwritten: two utterances arriving inside one
        # Godot frame must not silently replace each other.
        with open(transcript_path, "a", encoding="utf-8") as handle:
            handle.write(cleaned + "\n")

    status("ready")
    listening = False
    with sd.RawInputStream(
        samplerate=SAMPLE_RATE,
        blocksize=BLOCK,
        device=args.device,
        dtype="int16",
        channels=1,
        callback=on_audio,
    ):
        while True:
            want = read_state()
            if want == "quit":
                break

            if want == "listen" and not listening:
                # Drain whatever accumulated while idle, so the first thing the
                # examiner hears is not thirty seconds of the room.
                with audio.mutex:
                    audio.queue.clear()
                recognizer.Reset()
                listening = True
                status("listening")
            elif want != "listen" and listening:
                # Release of V ends the utterance: flush whatever partial the
                # recogniser is holding rather than waiting for silence.
                listening = False
                final = json.loads(recognizer.FinalResult()).get("text", "")
                emit(final)
                status("ready")

            try:
                data = audio.get(timeout=0.1)
            except queue.Empty:
                continue

            if not listening:
                continue

            if recognizer.AcceptWaveform(data):
                emit(json.loads(recognizer.Result()).get("text", ""))

    status("stopped")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as error:  # noqa: BLE001
        # The game must survive this process dying. Godot falls back to typed
        # input when `status.txt` stops saying "ready" or "listening".
        try:
            with open(os.path.join(sys.argv[sys.argv.index("--bridge") + 1], "status.txt"), "w", encoding="utf-8") as handle:
                handle.write(f"error: {error}")
        except Exception:  # noqa: BLE001
            pass
        print(f"voice_listener failed: {error}", file=sys.stderr)
        sys.exit(1)
