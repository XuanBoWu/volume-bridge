[简体中文](README.zh-CN.md)

# VolumeBridge

A native macOS menu bar app for controlling the volume of HDMI / DisplayPort displays that do not provide writable system volume controls.

- Adjust volume with a slider, mute button, or keyboard volume keys.
- See a volume HUD and hear volume feedback when adjusting the level.
- Follow the system output or select a fixed target device.
- Process audio locally, without drivers, recording, or uploads.

VolumeBridge uses a Core Audio Process Tap and software attenuation. It does not use DDC or modify the Control Center volume slider. Devices with native volume controls are left to macOS.

## Requirements

- Apple silicon Mac; default build architecture is arm64.
- Deployment target: macOS 14.2. Hardware testing so far covers M1 Pro / macOS 27 only; older systems and Intel are unverified.
- For software volume control: HDMI / DisplayPort output, no input streams, one output stream, stereo interleaved Float32 PCM, and no writable native volume.
- Apple Command Line Tools with Swift and a recent macOS SDK to build from source.

## Build and run

```sh
zsh build.sh
```

Quit any running copy before opening `build/VolumeBridge.app`. Grant audio capture and keyboard-control permissions when prompted.

Builds use a local signing identity if available, otherwise ad-hoc signing. For a stable identity across local rebuilds, optionally run this once before building:

```sh
zsh scripts/setup-local-signing.sh
```

Local signing is not Developer ID signing or notarization. This repository currently provides source and local test packaging, not a notarized public release.

The optional signing setup requires OpenSSL 3. Ordinary builds and ad-hoc checks do not.

## Use

Open the menu bar panel to choose a device, adjust volume, mute, or pause. A fixed target is controlled only while it is the system output; selecting a target does not automatically switch the Mac's output. Use the panel's explicit system-output action to switch it.

Keyboard volume keys work while software control is active. Other outputs and paused states use macOS volume handling. The interface supports English and Simplified Chinese.

**Pausing, quitting, or a crash removes software attenuation and restores the display's original playback level.**

## Privacy and diagnostics

Audio stays in memory and is neither saved nor uploaded. Local logs contain device information, states, errors, counters, and volume statistics. They rotate at 1 MiB, are capped at 12 MiB, and retain rotated files for up to 14 days. Review device names and identifiers before sharing logs. See [logging](docs/LOGGING.md).

## Development

```sh
zsh scripts/check.sh
```

The checks build and test without starting audio capture, playing sounds, switching devices, or requesting permissions. To explicitly build without a local signing identity, use `VB_SIGN_IDENTITY=- zsh scripts/check.sh`.

See [contributing](CONTRIBUTING.md), [testing](docs/TESTING.md), [architecture](docs/ARCHITECTURE.md), and [known work](docs/ROADMAP.md). Real sleep/wake and long-duration compatibility testing remain open. GitHub Actions CI is intentionally not configured; validation runs locally.

## License

[MIT](LICENSE). Asset and platform-resource details are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
