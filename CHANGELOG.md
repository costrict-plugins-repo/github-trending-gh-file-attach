# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-08-11

### Added
- **"Choosing the target repo"** section in `README.md`, surfacing guidance that previously existed only in `SKILL.md`. Recommends the shared upstream repo for shared-project PRs, on the grounds of asset *lifetime* rather than access: fork-hosted assets do render for upstream readers, because private forks inherit the parent's collaborator list, but they die whenever the fork is deleted and silently break every image in every merged PR that referenced them.
- Ordered triage for broken images in `README.md` — draft release, then lapsed SSO session, then an unreadable target repo — so the common instinct to re-upload isn't applied to the two causes re-uploading cannot fix.

## [1.3.0] - 2026-08-10

### Fixed
- **Corrected the private-repo security model, which was documented backwards.** `SKILL.md` and `README.md` both claimed `--public` "may make uploaded files accessible via direct URL even to non-collaborators" on private repos. It does not: `--public` publishes the release, never the file, and asset visibility always equals repository visibility. The old warning discouraged the one flag that must always be passed.
- **Removed the `curl -sI` URL-verification step** from `references/discovery-and-formatting.md`. On a private repo it cannot distinguish a working URL from a nonexistent one — every URL under the repo answers `302` (a redirect to SSO), and the web download path ignores `Authorization: Bearer` tokens, so the check silently certified broken links as good.
- Corrected the "When NOT to use" guidance that asserted uploaded assets are unconditionally public.

### Added
- **"Who can see an uploaded file"** section covering the access model: visibility follows the repo, SSO session lapses render as broken images on any `github.com`-hosted asset (Releases and `user-attachments` alike), and private forks inherit the parent's collaborator list, which makes a fork a safe host.
- **"Choosing the target repo"** guidance — `gh repo view` resolves to *upstream* in a fork-based checkout, so a bare run publishes a release in the shared repo. Documents the fork alternative and the asset-lifetime tradeoff.
- Concrete mechanism behind the `--public` rule: a draft's assets receive an `untagged-<hash>` URL that dies when the release is published, and are invisible to read-only collaborators.
- Three diagnostic rows in the error table for the distinct broken-image causes (draft release, lapsed SSO, unreadable target repo).

## [1.2.1] - 2026-04-11

### Fixed
- Removed non-standard `prerequisites` field from `plugin.json` (not part of official schema, silently ignored)
- Fixed `${CLAUDE_PLUGIN_ROOT}` paths for `scan-media.sh` — was `scripts/scan-media.sh`, corrected to `skills/file-attach/scripts/scan-media.sh`
- Removed nested duplicate `gh-file-attach-plugin/` subdirectory that could confuse the plugin loader

### Added
- CHANGELOG.md for marketplace compliance

## [1.2.0] - 2026-04-11

### Added
- Full Claude Code plugin structure (`.claude-plugin/plugin.json`, `skills/`, `bin/`, `references/`)
- SKILL.md with YAML frontmatter, semantic trigger descriptions, and allowed-tools declarations
- Discovery mode with 5-layer scan (`scan-media.sh`) for finding uploadable files without explicit paths
- Smart labeling derived from branch name and filename hints
- Before/after comparison formatting (side-by-side markdown tables)
- Collapsible sections for bulk uploads (5+ files)
- Reference docs: `discovery-and-formatting.md` and `cleanup-safeguards.md`
- PR/issue auto-embedding via safe temp-file approach (avoids shell injection)
- Type-aware markdown output: inline images, labeled links for videos/docs/archives
- Storage management commands: `--list`, `--stats`, `--cleanup`
- Multi-step cleanup safeguards: inventory, dry-run preview, live-reference check, explicit confirmation
- Per-type file size limits with pre-upload validation
- Rejection of executables (.exe, .dmg, .iso, .deb, .rpm) and symlinks
- Security documentation covering private repo data exposure and cleanup destructiveness

### Changed
- Upgraded `gh-file-attach` CLI to v1.2.0 with expanded format support and management commands

## [1.0.0] - 2026-04-10

### Added
- Initial release of `gh-file-attach-plugin` for Claude Code
- Core upload functionality via GitHub Releases API
- Markdown output formatting (`-m` flag)
- Clipboard support (`-c` flag)
- Custom release tag support (`-t` flag)
- Cross-repo uploads (`-r` flag)

[1.3.1]: https://github.com/vindu939/gh-file-attach-plugin/releases/tag/v1.3.1
[1.3.0]: https://github.com/vindu939/gh-file-attach-plugin/releases/tag/v1.3.0
[1.2.1]: https://github.com/vindu939/gh-file-attach-plugin/releases/tag/v1.2.1
[1.2.0]: https://github.com/vindu939/gh-file-attach-plugin/releases/tag/v1.2.0
[1.0.0]: https://github.com/vindu939/gh-file-attach-plugin/releases/tag/v1.0.0
