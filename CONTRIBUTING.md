# Contributing

Issues and pull requests in English or Simplified Chinese are welcome.

## Build and check

Use Apple Command Line Tools on macOS. No third-party packages are required.

```sh
VB_SIGN_IDENTITY=- zsh scripts/check.sh
```

This runs offline checks only. Hardware tests are opt-in and can change output devices, volume, or sample rates; read [TESTING.md](docs/TESTING.md) first and restore the values observed before your test. Run only one app instance/audio chain at a time. Automated entry-point tests are not physical-key or listening acceptance.

For local use, `scripts/setup-local-signing.sh` creates your own persistent signing identity. Keep its private key in your own Keychain; do not commit or share it. No signing certificate is needed for the ad-hoc check command above. CI is not configured; include local validation results in your PR.

The optional signing setup uses OpenSSL 3 (`-addext` and PKCS#12 `-legacy`); the macOS-provided LibreSSL is not a substitute for that script. Ordinary builds have no such dependency.

## Changes

- Keep the native AppKit interface and the dependency-free Swift / Objective-C++ implementation.
- Keep realtime audio callbacks free of allocation, locks, logging, UI, and localization work.
- Preserve native-device bypass, volume smoothing, per-device memory, slider synchronization, and media-key lifecycle safeguards.
- Maintain English and Simplified Chinese strings together, including accessibility text.
- Add focused regression coverage for behavior changes. Document any untested hardware/OS scope.
- Do not change the Bundle Identifier without a settings and permission migration plan.
- App icon changes use `design/icon/icon.py`; see [ICON.md](docs/ICON.md) before regenerating assets.
- Keep logs, builds, recordings, credentials, machine paths, and personal device IDs out of commits.

Explain the problem, final behavior, checks run, and remaining limitations in your PR. Update relevant docs and CHANGELOG for user-facing changes. Contributions are made under the project's [MIT license](LICENSE); identify the source and license of any external material.

For security issues, follow [SECURITY.md](SECURITY.md).
