# gh-file-attach - Claude Code plugin for uploading files to GitHub PRs

A [Claude Code](https://code.claude.com/) plugin that gives Claude the ability to upload files to GitHub and get permanent, shareable URLs — perfect for embedding screenshots in PRs, attaching logs to issues, and managing file attachments from the terminal.

Powered by the [GitHub Releases API](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases). No browser cookies, no hacks — just your existing `gh` auth.

## Install

### From a marketplace

```bash
# Add the marketplace (one-time)
/plugin marketplace add vindu939/gh-file-attach-plugin

# Install the plugin
/plugin install gh-file-attach@vindu939/gh-file-attach-plugin
```

### Local development

```bash
git clone https://github.com/vindu939/gh-file-attach-plugin.git
claude --plugin-dir ./gh-file-attach-plugin
```

### Prerequisites

| Requirement | How to check |
|---|---|
| [GitHub CLI](https://cli.github.com/) v2.0+ | `gh --version` |
| Authenticated with `repo` scope | `gh auth status` |
| Write access to target repo | Push access or collaborator role |

If `repo` scope is missing: `gh auth refresh -s repo`

## What Claude gains

Once installed, Claude can:

- **Discover and upload files** — scans your project for screenshots, recordings, logs, and other media, then uploads them to GitHub with descriptive labels
- **Embed in PRs and issues** — auto-detects open PRs for the current branch and injects uploaded files directly into the PR/issue body
- **Format intelligently** — before/after side-by-side tables, collapsible sections for large batches, type-aware markdown (inline images, labeled links for videos/docs)
- **Manage storage** — list uploads, check usage against GitHub plan limits, clean up old assets with safeguards against breaking live links

## Usage

The plugin triggers automatically when Claude detects a relevant task. You can also invoke it directly:

### Attach screenshots to a PR

> "Add screenshots to the PR"

Claude scans your project for image/video files, shows you what it found, lets you pick which ones to upload, suggests labels, and embeds them in the current PR — all with confirmation at each step.

### Upload a specific file

> "Upload `/tmp/mockup.png` to PR #1244"

Skips discovery. Verifies the file, uploads it, and embeds the markdown directly into PR #1244.

### Before/after comparisons

> "Attach before and after screenshots to PR #89"

Detects the before/after pattern and formats as a side-by-side markdown table for easy visual review.

### Check storage

> "How much attachment storage am I using?"

```
Storage stats for '_attachments' in you/repo

  Images           12 files       4 MB
  Videos            3 files      28 MB
  Documents         2 files     512 KB
  Total            17 files      32 MB

GitHub repo storage limits: 5 GB (warning at 1 GB)
```

### Clean up old attachments

> "Clean up attachments older than 30 days"

Claude runs a safeguard sequence before any deletion: inventory → dry-run preview → checks for live PR/issue references → explicit count confirmation → executes → reports what was removed.

## Supported file types

| Category | Formats | Max size |
|---|---|---|
| Images | PNG, JPG, GIF, WebP, SVG, BMP, ICO, TIFF, AVIF | 50 MB |
| Videos | MP4, MOV, WebM, AVI, MKV | 200 MB |
| Audio | MP3, WAV, OGG, FLAC, AAC, M4A | 50 MB |
| Documents | PDF, DOCX, PPTX, XLSX, RTF, DOC, ODT | 25 MB |
| Code | PY, JS, TS, TSX, JSX, Java, C, C++, Go, Rust, Ruby, and 20+ more | 10 MB |
| Archives | ZIP, GZ, TGZ, TAR, BZ2, XZ, 7Z, RAR | 50 MB |
| Text/Data | TXT, MD, CSV, TSV, LOG, JSON, TOML, INI, CFG | 25 MB |

Executables (.exe, .dmg, .iso, .deb, .rpm) and symlinks are rejected by design.

## How it works

1. On first use, the tool creates a GitHub Release tagged `_attachments` in the target repo
2. Files are uploaded as release assets with unique timestamped names (e.g. `screenshot-20260411-a1b2c3d4.png`)
3. Each asset gets a permanent download URL that works in GitHub markdown
4. The `_attachments` release appears in the repo's Releases tab — this is expected

Uses your existing `gh auth` session. No separate API keys or environment variables needed.

### Markdown formatting by type

| Type | Format | Renders as |
|---|---|---|
| Images | `![label](url)` | Inline image |
| Videos | `[▶ label](url)` | Clickable link |
| Audio | `[🔊 label](url)` | Clickable link |
| Documents | `[📄 label](url)` | Clickable link |
| Code | `[📝 label](url)` | Clickable link |
| Archives | `[📦 label](url)` | Clickable link |

## Security considerations

This plugin uploads files to GitHub. Before installing, understand what it does and doesn't do:

**What the plugin accesses:**
- Reads files from your local filesystem (only files you explicitly select or confirm)
- Uses your `gh` CLI auth token to interact with the GitHub Releases API
- Scans project directories for uploadable media during discovery (never scans outside the project tree)

**What it does NOT do:**
- Never uploads without user confirmation
- Never scans home directories (~/) — discovery is limited to the project working tree
- Never stores or transmits credentials beyond your existing `gh` auth session
- Never runs on its own — all actions are initiated by user request

**Asset visibility follows repo visibility.** The `--public` flag publishes the *release* so its URLs resolve; it does not change who may read the file. On a private repo the asset stays restricted to people with repo access — the flag is safe there, and omitting it is what produces broken links. On a public repo uploaded files are world-readable, so Claude confirms before uploading anything sensitive.

**Cleanup is destructive:** Deleting assets permanently breaks markdown links in merged PRs, closed issues, and READMEs. The plugin enforces a multi-step safeguard sequence before any deletion.

**GitHub storage limits:** Release assets count toward total repo size. Free/Pro/Team: 5 GB (warning at 1 GB). Enterprise: 100 GB. Use the `--stats` command to monitor usage.

## Plugin structure

```
gh-file-attach-plugin/
├── .claude-plugin/
│   ├── plugin.json                          # Plugin manifest
│   └── marketplace.json                     # Marketplace discovery manifest
├── skills/
│   └── file-attach/
│       ├── SKILL.md                         # Main skill instructions
│       ├── references/
│       │   ├── discovery-and-formatting.md  # File discovery and formatting guide
│       │   └── cleanup-safeguards.md        # Cleanup safety procedures
│       └── scripts/
│           └── scan-media.sh                # Media file scanner
├── bin/
│   └── gh-file-attach                       # CLI tool (from vindu939/gh-file-attach)
├── CHANGELOG.md
├── README.md
└── LICENSE
```

| Component | Purpose |
|---|---|
| `skills/file-attach/SKILL.md` | Core skill — tells Claude how to upload, discover, embed, and manage files |
| `references/` | Loaded on demand for complex flows (discovery scan, cleanup safeguards) |
| `scripts/scan-media.sh` | Reusable scan script — single source of truth for supported extensions |
| `bin/gh-file-attach` | The upload CLI — added to PATH when the plugin is enabled |

## Development

```bash
# Clone the repo
git clone https://github.com/vindu939/gh-file-attach-plugin.git
cd gh-file-attach-plugin

# Load locally for testing
claude --plugin-dir .

# Test the skill
/gh-file-attach:file-attach
```

After making changes, run `/reload-plugins` inside Claude Code to pick up updates.

## Choosing the target repo

The tool uploads to the current repo by default, resolved through `gh repo view`. In a fork-based checkout that usually resolves to the **upstream** repo, so a bare run creates the `_attachments` release there — visible in its Releases tab.

**For shared-project PRs, upstream is the right target.** GitHub serves these URLs directly rather than proxying them through camo, so an image renders only for viewers who can read whichever repo hosts it. Upstream is the one location guaranteed to outlive every contributor's fork:

```bash
gh file-attach --public --repo <org>/<shared-repo> -m "Label:shot.png"
```

A fork is a workable fallback but not a durable one. Private forks inherit the parent's collaborator list, so a fork-hosted asset does render for upstream readers today — the failure mode is lifetime, not permissions. Assets die with the repo hosting them, and forks get deleted when people leave or tidy up, silently breaking every image in every merged PR that referenced them. Prefer upstream for anything that should still render next year.

If images break for reviewers, work through these in order before re-uploading:

1. **Broken for everyone, including you** — the release is a draft. Re-run with `--public` and re-copy the URL, since publishing changes it.
2. **Broken for one person** — their SSO session lapsed. GitHub answers the image request with a redirect to the login page and the browser draws a broken icon. They should load the repo once in that browser, then reload the page. Note this affects drag-and-drop `user-attachments` URLs identically, so switching upload methods does not help.
3. **Broken for everyone but you** — the asset landed in a repo they cannot read. Check the target with `--list`.

## Also available as

The upload tool is also available as a standalone GitHub CLI extension (without the Claude Code skill layer):

```bash
gh extension install vindu939/gh-file-attach
gh file-attach --public -m "Label:file.png"
```

See the [gh-file-attach repo](https://github.com/vindu939/gh-file-attach) for CLI-only usage.

## Uninstall

```bash
/plugin uninstall gh-file-attach
```

## License

MIT