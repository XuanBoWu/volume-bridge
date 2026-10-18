# Security

VolumeBridge is an early-stage local macOS tool. Fixes are made on the current development branch; there is no commitment to backport fixes to older snapshots or provide a response-time SLA.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature under **Security → Report a vulnerability** if it is enabled for the repository. If it is unavailable, open an issue requesting a private reporting channel without describing the vulnerability or attaching sensitive material. Do not publish credentials, audio, personal device identifiers, or exploit details in public issues.

Include the affected version/commit, macOS version, reproduction steps, impact, and a minimal example after a private channel is established. The maintainer must enable private reporting when configuring the GitHub repository; this file does not enable it automatically.

## Data and permissions

Audio is processed in memory and is not recorded or uploaded. Audio capture and accessibility/media-key permissions are requested for the app's core function. Local logs contain device metadata and diagnostic statistics; review and redact them before sharing.

Local self-signing is for development, not Developer ID signing or notarization. Never share signing private keys. Pausing, quitting, or a crash removes software attenuation, restoring the display's original playback level.
