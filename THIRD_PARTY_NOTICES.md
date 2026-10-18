# Source and resource notices

Project source, documentation, and the procedural app-icon assets in this repository are covered by [LICENSE](LICENSE).

The project has no third-party package dependencies or vendored fonts/audio. The icon source is `design/icon/icon.py`; checked-in SVG, PNG, and ICNS files are generated from it.

Apple frameworks, SDK interfaces, and SF Symbols are provided by the operating system/toolchain and remain subject to Apple's terms. They are not relicensed under the project's MIT license.

The volume cue is read at runtime from the host macOS installation when available. That Apple audio file is not included in this repository or copied into app packages. The fallback cue is synthesized in memory by project code.

Document the origin and license here before adding third-party source or bundled resources.
