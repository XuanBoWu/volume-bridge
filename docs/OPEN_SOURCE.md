# Open-source preparation

Prepared on 2026-10-19. The project uses MIT, with English as the default README and a Simplified Chinese translation. The initial preparation did not create a remote, release, tag, or Actions workflow. On 2026-10-19, the maintainer authorized publishing to [XuanBoWu/volume-bridge](https://github.com/XuanBoWu/volume-bridge) and distributing a locally built v0.2.3 (build 10) test DMG. No Actions workflow is configured.

## Public-content review

The current source/documents and the ancestry of the local `main` branch were reviewed. Pattern checks covered private-key headers, common GitHub/OpenAI/AWS credentials, credential-bearing URLs, personal home paths, shared-chat URLs, device UUIDs, and local certificate fingerprints. Source imports, resources, and tracked filenames were also inspected. No credentials matching those checks were found; pattern scans are not a guarantee that all possible secrets have been detected.

Machine paths, hardware UUIDs, and local signing fingerprints in validation records and handoff documents were replaced with placeholders. Identical device UUIDs use identical example values across records. Versions, results, counts, and the distinction between automated and physical acceptance were retained. These redacted records must never be used as runtime device configuration.

The maintainer explicitly chose to retain existing Git author names and email addresses. Local history was rewritten to sanitize file contents while preserving author/committer identity, timestamps, and messages. Commit IDs therefore changed. Historical document snapshots may refer to pre-redaction IDs; use the current `git log` for navigation.

Original history bundles, unredacted working files, redaction maps, and detailed audit output remain only under the ignored `work/open-source-prep-20261019/` directory. Application-managed local `refs/codex/` checkpoints and reflogs are not publication branches and were left untouched. They may retain original contents. Publish the reviewed `main` branch, not a mirror or an archive of the entire `.git` directory.

## Source and assets

No third-party packages or bundled system audio/fonts were found. The app-icon generator and generated assets are included under MIT. Apple SDK/framework interfaces and runtime system resources are covered by their own platform terms; see [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

Builds, local logs, signing material, test audio, and backups are excluded from publication. Public issue templates request redacted metadata and no audio recordings or private keys.

## Validation and remaining setup

Use `VB_SIGN_IDENTITY=- zsh scripts/check.sh` for offline validation without a signing certificate. The preparation also verifies a fresh independent local clone, with no pre-existing build/work files and an unavailable signing-keychain path. It does not launch capture, change the installed app, play sound, switch output devices, or create certificates. All checks passed with system-only PATH and Python 3.9.6. Final source/build/test/resource inputs match the validated clone; subsequent changes only record documentation and validation results. See [STATUS.md](STATUS.md) and the [verification summary](verification/开源准备检查.json).

No GitHub macOS runner is configured, as requested. Builds and checks run locally. The installed build 10 retains its previous local identity; the ad-hoc validation apps are not installed or launched.

The authorized publication uses only the reviewed `main` branch and its `v0.2.3` release tag. Private vulnerability reporting is enabled. The DMG is locally self-signed and is not notarized or Developer ID signed; release notes disclose this and the hardware/OS testing limits. Additional hardware/OS testing and real sleep/wake acceptance remain separate work.
