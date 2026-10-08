"""Exercise the app's media-key handler, HUD and real PCM without posting OS keys.

Usage: python3 media_integration.py AUDIOCTL STATUS COMMAND TONE RESULT
Real physical keys and permission UI are verified separately by the user.
"""
import json
import pathlib
import subprocess
import sys
import time
import uuid

ctl, status_path, command_path, tone_path, result_path = sys.argv[1:]
status_path, command_path = pathlib.Path(status_path), pathlib.Path(command_path)
records = []
player = None

def command(action, **kwargs):
    command_path.write_text(json.dumps(dict(token=str(uuid.uuid4()), action=action, **kwargs)))

def status():
    return json.loads(status_path.read_text())

def wait(predicate, timeout=20):
    end = time.monotonic() + timeout
    s = {}
    while time.monotonic() < end:
        try:
            s = status()
            if predicate(s):
                return s
        except (OSError, ValueError):
            pass
        time.sleep(.1)
    raise AssertionError(f"Timed out: {s}")

def record(stage, s):
    records.append(dict(stage=stage, status=s))
    print(f"PASS {stage}: volume={s['volume']} muted={s['muted']} HUD={s['hudPresentations']}", flush=True)

def expected(percent, muted=False):
    gain = 0 if muted else (percent / 100) ** 2
    return lambda s: s["state"] == "active" and s["volume"] == percent and s["muted"] == muted \
        and s["inputRMS"] > .001 and abs(s["outputRMS"] / s["inputRMS"] - gain) < .002

original = wait(lambda s: s.get("state") == "active", timeout=120)
inventory = json.loads(subprocess.check_output([ctl, "list"], text=True))
native = next(d for d in inventory["devices"] if d["uid"] == "BuiltInSpeakerDevice")
native_volume = native["volumes"].get("0")
try:
    command("volume", value=50)
    wait(lambda s: s["volume"] == 50)
    player = subprocess.Popen(["afplay", tone_path])
    wait(expected(50))
    for key, count, fine, percent, muted, stage in [
        (0, 4, False, 75, False, "four rapid up actions accumulate"),
        (1, 8, False, 25, False, "eight rapid down actions accumulate"),
        (0, 1, True, 26.5625, False, "fine adjustment"),
        (7, 1, False, 26.5625, True, "mute preserves volume"),
        (7, 1, False, 26.5625, False, "second mute restores sound"),
        (0, 32, False, 100, False, "upper limit"),
        (1, 1, False, 93.75, False, "leave 100 with down key"),
        (1, 32, False, 0, False, "lower limit"),
        (0, 1, False, 6.25, False, "leave zero with up key"),
    ]:
        presentations = status()["hudPresentations"]
        command("media-key", key=key, count=count, fine=fine)
        s = wait(lambda s: expected(percent, muted)(s) and s["hudPresentations"] == presentations + count)
        assert s["generation"] == original["generation"]
        assert s["mismatches"] == 0 and s["overloads"] == 0
        record(stage, s)
    s = wait(lambda s: not s["hudVisible"])
    record("HUD automatically hides", s)
    command("pause")
    s = wait(lambda s: s["state"] == "paused")
    count, volume = s["hudPresentations"], s["volume"]
    command("media-key", key=0, count=4)
    time.sleep(1.5)
    s = status()
    assert s["state"] == "paused" and s["volume"] == volume and s["hudPresentations"] == count and not s["hudVisible"]
    record("paused handler leaves volume and HUD untouched", s)
    command("resume")
    wait(lambda s: s["state"] == "active")
    player.terminate()
    player.wait()
    player = None
    # No test tone on the native speaker; preserve its hardware setting.
    subprocess.run([ctl, "output", str(native["id"])], check=True)
    s = wait(lambda s: s["state"] == "bypass")
    count, volume = s["hudPresentations"], s["volume"]
    command("media-key", key=1, count=4)
    time.sleep(1.5)
    s = status()
    assert s["state"] == "bypass" and s["volume"] == volume and s["hudPresentations"] == count and not s["hudVisible"]
    now = json.loads(subprocess.check_output([ctl, "list"], text=True))
    assert next(d for d in now["devices"] if d["id"] == native["id"])["volumes"].get("0") == native_volume
    record("native bypass ignores handler and preserves native volume", s)
finally:
    if player:
        player.terminate()
        player.wait()
    subprocess.run([ctl, "output", str(inventory["default"])], check=True)
    command("resume")
    wait(lambda s: s["state"] == "active")
    command("volume", value=original["volume"])
    wait(lambda s: s["volume"] == original["volume"])
    if original["muted"]:
        command("mute")
        wait(lambda s: s["muted"])
    pathlib.Path(result_path).write_text(json.dumps(records, ensure_ascii=False, indent=2))
