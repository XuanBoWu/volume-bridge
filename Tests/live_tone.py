"""Checks real PCM after recovery, then graceful signal shutdown.

Usage: python3 live_tone.py AUDIOCTL STATUS_JSON COMMAND_JSON TONE_WAV RESULT_JSON
"""
import json
import os
import pathlib
import signal
import subprocess
import sys
import time
import uuid

ctl, status_path, command_path, tone_path, result_path = sys.argv[1:]
status_path, command_path = pathlib.Path(status_path), pathlib.Path(command_path)
records = []
player = None
pid = int(subprocess.check_output(["pgrep", "-x", "VolumeBridge"], text=True).strip())
inventory = json.loads(subprocess.check_output([ctl, "list"], text=True))
original = next(d for d in inventory["devices"] if d["id"] == inventory["default"])

def command(action, **kwargs):
    command_path.write_text(json.dumps(dict(token=str(uuid.uuid4()), action=action, **kwargs)))

def wait(predicate, timeout=20):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        try:
            s = json.loads(status_path.read_text())
            if predicate(s):
                return s
        except (OSError, ValueError):
            pass
        time.sleep(.15)
    raise AssertionError(f"Timed out: {s}")

def record(stage, s):
    records.append(dict(stage=stage, status=s))
    print(f"PASS {stage}: generation={s['generation']} rate={s['rate']} in={s['inputRMS']:.6f} out={s['outputRMS']:.6f}", flush=True)

def pcm(s):
    return s["state"] == "active" and s["inputRMS"] > .001

try:
    command("resume")
    wait(lambda s: s.get("state") == "active", timeout=100)
    command("volume", value=50)
    wait(lambda s: s["volume"] == 50)
    player = subprocess.Popen(["afplay", tone_path])
    s = wait(pcm)
    assert abs(s["outputRMS"] / s["inputRMS"] - .25) < .002
    record("tone before rebuild", s)
    generation = s["generation"]
    command("retry")
    s = wait(lambda s: pcm(s) and s["generation"] > generation)
    assert abs(s["outputRMS"] / s["inputRMS"] - .25) < .002
    record("tone after guarded rebuild", s)
    generation = s["generation"]
    subprocess.run([ctl, "rate", str(original["id"]), "44100"], check=True)
    s = wait(lambda s: pcm(s) and s["rate"] == 44100 and s["generation"] > generation)
    assert abs(s["outputRMS"] / s["inputRMS"] - .25) < .002
    record("tone after live sample rate change", s)
    generation = s["generation"]
    subprocess.run([ctl, "rate", str(original["id"]), str(original["rate"])], check=True)
    s = wait(lambda s: pcm(s) and s["rate"] == original["rate"] and s["generation"] > generation)
    assert abs(s["outputRMS"] / s["inputRMS"] - .25) < .002
    record("tone after original sample rate restored", s)
    command("mute")
    s = wait(lambda s: pcm(s) and s["muted"] and s["outputRMS"] == 0)
    record("mute while source keeps playing", s)
    command("unmute")
    s = wait(lambda s: pcm(s) and not s["muted"] and abs(s["outputRMS"] / s["inputRMS"] - .25) < .002)
    record("unmute restores gain", s)
    assert s["mismatches"] == 0 and s["overloads"] == 0
    player.terminate()
    player.wait()
    player = None
    os.kill(pid, signal.SIGTERM)
    s = wait(lambda s: s["state"] == "stopped")
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            break
        time.sleep(.1)
    else:
        raise AssertionError("App did not exit after successful audio teardown")
    record("graceful signal shutdown and process exit", s)
finally:
    if player:
        player.terminate()
        player.wait()
    subprocess.run([ctl, "rate", str(original["id"]), str(original["rate"])], check=True)
    pathlib.Path(result_path).write_text(json.dumps(records, ensure_ascii=False, indent=2))
