"""Opt-in live hardware checks; restores audio settings in finally.

Usage: python3 integration.py AUDIOCTL STATUS_JSON COMMAND_JSON [RESULT_JSON]
The app must already be running with the corresponding test paths.
"""
import json
import pathlib
import subprocess
import sys
import time
import uuid

ctl, status_path, command_path = sys.argv[1:4]
status_path, command_path = pathlib.Path(status_path), pathlib.Path(command_path)
results = []

def inventory():
    return json.loads(subprocess.check_output([ctl, "list"], text=True))

def action(*args):
    subprocess.run([ctl, *map(str, args)], check=True, capture_output=True, text=True)

def command(name, **kwargs):
    command_path.write_text(json.dumps(dict(token=str(uuid.uuid4()), action=name, **kwargs)))

def state():
    try:
        return json.loads(status_path.read_text())
    except (OSError, ValueError):
        return {}

def wait(predicate, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        s = state()
        if predicate(s):
            return s
        time.sleep(0.15)
    raise AssertionError(f"Timed out, last status: {state()}")

def record(name, s):
    results.append(dict(name=name, state=s))
    print(f"PASS {name}: state={s.get('state')} generation={s.get('generation')} rate={s.get('rate')}", flush=True)

initial = inventory()
original = next(d for d in initial["devices"] if d["id"] == initial["default"])
speaker = next(d for d in initial["devices"] if d["uid"] == "BuiltInSpeakerDevice")
changed_volume = False
try:
    s = wait(lambda s: s.get("state") == "active", timeout=120)
    record("initial capture", s)
    command("volume", value=37)
    wait(lambda s: s.get("volume") == 37)
    generation = state()["generation"]
    # Native bypass must not route audio through the software engine.
    for channel in speaker["volumes"]:
        action("volume", speaker["id"], channel, min(0.15, speaker["volumes"][channel]))
        changed_volume = True
    action("output", speaker["id"])
    s = wait(lambda s: s.get("state") == "bypass" and s.get("deviceID") == speaker["id"])
    calls = s["callbacks"]
    time.sleep(2.3)
    assert state()["callbacks"] == calls, "Callback count advanced during native bypass"
    record("native output bypass", state())
    action("output", original["id"])
    s = wait(lambda s: s.get("state") == "active" and s.get("generation", 0) > generation)
    assert s["volume"] == 37, "Per-device volume was not restored"
    record("display output restored and remembered volume", s)
    generation = s["generation"]
    if any(low <= 44100 <= high for low, high in original["rates"]):
        action("rate", original["id"], 44100)
        s = wait(lambda s: s.get("state") == "active" and s.get("rate") == 44100 and s.get("generation", 0) > generation)
        record("physical sample rate 44100", s)
        generation = s["generation"]
        time.sleep(2)
        action("rate", original["id"], original["rate"])
        s = wait(lambda s: s.get("state") == "active" and s.get("rate") == original["rate"] and s.get("generation", 0) > generation)
        record("physical sample rate restored", s)
    generation = state()["generation"]
    command("retry")
    s = wait(lambda s: s.get("state") == "active" and s.get("generation", 0) > generation)
    record("forced rebuild with silence guard", s)
    generation = s["generation"]
    command("pause")
    s = wait(lambda s: s.get("state") == "paused")
    record("pause releases pipeline", s)
    command("resume")
    s = wait(lambda s: s.get("state") == "active" and s.get("generation", 0) > generation)
    record("resume rebuilds pipeline", s)
    generation = s["generation"]
    command("sleep")
    s = wait(lambda s: s.get("state") == "sleeping")
    record("simulated sleep entry point", s)
    command("wake")
    s = wait(lambda s: s.get("state") == "active" and s.get("generation", 0) > generation)
    record("simulated wake entry point", s)
    command("volume", value=50)
    wait(lambda s: s.get("volume") == 50)
    time.sleep(4)
    s = state()
    assert s["state"] == "active"
    assert s["mismatches"] == 0, "Unexpected audio buffer format mismatch"
    assert s["overloads"] == 0, "Core Audio reported an overload during short test"
    record("settled audio callback health", s)
finally:
    # Pause before restoring hardware settings, even when an assertion fails.
    command("pause")
    try:
        wait(lambda s: s.get("state") in ("paused", "stopped"), timeout=8)
    except AssertionError:
        pass
    for restore in [("rate", original["id"], original["rate"]),
                    ("output", initial["default"]), ("system-output", initial["systemDefault"])]:
        action(*restore)
    if changed_volume:
        for channel, value in speaker["volumes"].items():
            action("volume", speaker["id"], channel, value)
    final = inventory()
    assert final["default"] == initial["default"]
    assert final["systemDefault"] == initial["systemDefault"]
    current = next(d for d in final["devices"] if d["id"] == original["id"])
    final_speaker = next(d for d in final["devices"] if d["id"] == speaker["id"])
    assert current["rate"] == original["rate"]
    assert final_speaker["volumes"] == speaker["volumes"]
    print("RESTORED original output, sound effects output, sample rate and speaker volume", flush=True)
    if len(sys.argv) > 4:
        pathlib.Path(sys.argv[4]).write_text(json.dumps(dict(checks=results, restored=True), ensure_ascii=False, indent=2))
