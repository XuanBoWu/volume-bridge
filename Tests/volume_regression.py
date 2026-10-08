"""Live PCM regression for repeated 100% -> lower and zero -> higher changes.

Run with the app's --status-file and --command-file diagnostic arguments.
Usage: python3 volume_regression.py STATUS_JSON COMMAND_JSON TONE_WAV RESULT_JSON
"""
import json
import pathlib
import subprocess
import sys
import time
import uuid

status_path, command_path, tone_path, result_path = map(pathlib.Path, sys.argv[1:])
records = []

def command(value):
    command_path.write_text(json.dumps(dict(token=str(uuid.uuid4()), action="volume", value=value)))

def wait(predicate, timeout=20):
    end = time.monotonic() + timeout
    s = {}
    while time.monotonic() < end:
        try:
            s = json.loads(status_path.read_text())
            if predicate(s):
                return s
        except (OSError, ValueError):
            pass
        time.sleep(.1)
    raise AssertionError(f"Timed out: {s}")

player = None
try:
    wait(lambda s: s.get("state") == "active", timeout=120)
    command(50)
    wait(lambda s: s["volume"] == 50)
    player = subprocess.Popen(["afplay", str(tone_path)])
    generation = wait(lambda s: s["inputRMS"] > .001)["generation"]
    for percent in [100, 60, 20, 100, 0, 50, 100, 35, 50]:
        command(percent)
        expected = (percent / 100) ** 2
        s = wait(lambda s: s["state"] == "active" and s["volume"] == percent
                 and s["inputRMS"] > .001
                 and abs(s["outputRMS"] / s["inputRMS"] - expected) < .002)
        assert s["generation"] == generation, "Volume change unexpectedly rebuilt audio"
        assert s["mismatches"] == 0 and s["overloads"] == 0
        records.append(dict(percent=percent, expectedGain=expected, status=s))
        print(f"PASS {percent}%: measured gain={s['outputRMS'] / s['inputRMS']:.6f}", flush=True)
finally:
    if player:
        player.terminate()
        player.wait()
    command(50)
    result_path.write_text(json.dumps(records, ensure_ascii=False, indent=2))
