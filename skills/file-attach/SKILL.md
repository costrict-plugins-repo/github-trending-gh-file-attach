---
name: file-attach
description: Upload files to GitHub and get permanent, shareable URLs via the Releases API. Use this skill whenever a file needs a URL for embedding in a PR, issue, commit message, README, or docs. Triggers on "attach", "embed", "share", "host", or "upload" a file to GitHub — with or without a specific file path. When no path is given, scans the project for uploadable media and lets the user choose. Supports explicit PR/issue targeting by number, auto-embeds via gh pr edit, bulk uploads, and storage housekeeping. If a file needs a GitHub-hosted link, use this skill — even if the user doesn't say "attach" explicitly.
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/file-attach/scripts/scan-media.sh *)
---

# Upload files to GitHub

Get permanent, browser-accessible URLs for files using the GitHub Releases API. This plugin bundles the [`gh-file-attach`](https://github.com/vindu939/gh-file-attach) CLI tool at `${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach`.

**How it works:** On first use in a repo, the tool creates a GitHub Release tagged `_attachments` to host uploaded files. This release appears in the repo's Releases tab — that's expected. All subsequent uploads go into the same release as timestamped assets (e.g. `screenshot-20260410-a1b2c3d4.png`). It's a storage container, not a code version. You can view and manage all uploads at `https://github.com/<owner>/<repo>/releases/tag/_attachments`.

## Prerequisites

1. **GitHub CLI (`gh`) v2.0+** must be installed and authenticated with `repo` scope.
2. If auth fails, prompt: `gh auth login` then `gh auth refresh -s repo` if scope is missing.
3. **Write access** to the target repository.

If `gh-file-attach` is not present, the user can install it as a gh extension: `gh extension install vindu939/gh-file-attach`.

## Core command

```bash
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public -m "Label:path/to/file"
```

Three things to always include:

1. **`--public`** — without it the release is created as a draft, and a draft's assets are handed a placeholder URL like `…/releases/download/untagged-9310dbad22aa/shot.png`. Publishing the release later re-tags it, so that placeholder URL dies. Draft assets are also invisible to collaborators with read-only access. This is the most common reason an image renders for whoever uploaded it and for nobody else — pass `--public` for anything meant to be shared.
2. **`-m`** (or `--markdown`) — produces ready-to-paste markdown with type-aware formatting (see table below).
3. **A descriptive label** via `"Label:path"` syntax — "Before fix", "Error log from staging", not the raw filename. If no label is given, the filename is used.

If a file path itself contains a colon and exists on disk, the tool treats it as a plain path (not label:path).

### Markdown output by file type

The `-m` flag formats output based on what's being uploaded:

| Type | Format | Example |
|------|--------|---------|
| Images | `![label](url)` | Renders inline |
| Videos | `[▶ label](url)` | Clickable link |
| Audio | `[🔊 label](url)` | Clickable link |
| Documents | `[📄 label](url)` | Clickable link |
| Code | `[📝 label](url)` | Clickable link |
| Archives | `[📦 label](url)` | Clickable link |
| Other | `[📎 label](url)` | Clickable link |

## Who can see an uploaded file

Asset visibility always equals **repository visibility**. `--public` controls draft-vs-published state and nothing else — it does not make a private repo's assets public. Files uploaded to a private repo stay private; files uploaded to a public repo are world-readable the moment they land.

On a private repo a viewer needs read access *and* a live browser session, which produces two failure modes worth designing around:

- **On an SSO-enforced org, a lapsed session is indistinguishable from a broken image.** GitHub answers the image request with a `302` to the SSO login page, the browser receives HTML where it expected a PNG, and draws a broken-image icon. This applies to every `github.com`-hosted asset equally — Release downloads and drag-and-drop `user-attachments` URLs alike — so switching URL styles does not dodge it. The fix is for that viewer to load the repo once in the same browser to refresh SSO; re-uploading changes nothing.
- **Private forks inherit the parent's collaborator list**, which makes a personal fork of a private repo a safe host — everyone who can read upstream can read the fork. A personal scratch repo *outside* that network is not safe: nobody but you will ever see those images.

### Choosing the target repo

The tool defaults to the current repo, resolved through `gh repo view`. In a fork-based checkout that usually resolves to the **upstream** repo, so a bare run creates the `_attachments` release in the shared repo where it shows up in the Releases tab. When that's unwelcome, name a fork explicitly — the images still render for every upstream reader:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public --repo <you>/<fork> -m "Label:shot.png"
```

The tradeoff is lifetime: assets die with the repo hosting them. Upstream-hosted images outlive your fork, fork-hosted ones don't. For a PR that should still render years from now, prefer upstream and accept the Releases-tab entry.

## Workflows

### Direct upload (user provides a file path)

When the user gives an explicit path — "upload `/tmp/mockup.png` to PR #1244" — skip discovery:

1. **Verify the file exists** with `ls -lh <path>`. If not, say so and stop.
2. **Suggest a label** from the filename + branch name (see smart labeling in `references/discovery-and-formatting.md`).
3. **Confirm and upload.**
4. **Embed into the target** — if the user named a PR or issue number, use it directly via the safe temp-file approach:

```bash
# Upload
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public -m "UI mockup – settings page:/tmp/mockup.png"

# Safe embed — mktemp avoids predictable filenames (symlink attacks on shared systems)
tmpfile=$(mktemp /tmp/pr-body-XXXXXX.md)
gh pr view 1244 --json body -q .body > "$tmpfile"
if [ $? -ne 0 ]; then rm "$tmpfile"; echo "ERROR: could not fetch PR body"; exit 1; fi
printf '\n\n## Screenshots\n\n![UI mockup – settings page](uploaded_url)\n' >> "$tmpfile"
gh pr edit 1244 --body-file "$tmpfile"
rm "$tmpfile"
```

Choose the section heading based on content: "## Screenshots" for images, "## Recordings" for videos, "## Attachments" for mixed types. For issues: `gh issue edit <number> --body-file` works the same way.

For other targets (READMEs, wikis, docs), print the markdown output and let the user place it — or offer to insert it into the file directly if the file is in the repo.

Never use `gh pr edit --body "$(gh pr view ...)"` — backticks and `$` in the existing body will be interpreted by the shell and corrupt it.

### Discovery mode (no path given)

When the user says "add screenshots" or "attach files" without specifying paths, run the full discovery flow.

**Read `references/discovery-and-formatting.md`** for the complete flow, including the 5-layer scan, format-aware metadata display, smart labeling, before/after comparison formatting, collapsible sections, and URL verification.

Quick start:
```bash
# Full 5-layer scan
bash ${CLAUDE_PLUGIN_ROOT}/skills/file-attach/scripts/scan-media.sh

# Scan a specific directory
bash ${CLAUDE_PLUGIN_ROOT}/skills/file-attach/scripts/scan-media.sh screenshots/
```

### Common examples

```bash
# Before/after screenshots
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public -m "Before fix:before.png" "After fix:after.png"

# Demo recording
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public -m "Demo – dark mode:demo.mp4"

# Logs and data for an issue
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public -m "Crash log:logs/crash.log" "Heap dump:heap.json"

# To a different repo
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public --repo owner/repo -m "Coverage:coverage.html"

# Custom release tag (instead of default _attachments)
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --public --tag design-assets -m "Mockup:design.png"
```

## Housekeeping

For listing or storage queries ("what have I uploaded?", "how much space?"), just run the relevant command and present results — don't trigger discovery or upload.

```bash
# List all uploads (name, size, date)
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --list

# Storage breakdown by file type (with GitHub plan limits)
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --stats
```

### Cleanup

Cleanup permanently breaks markdown links referencing deleted assets. **Before running cleanup, read `references/cleanup-safeguards.md`** and follow the safeguard sequence.

The tool has a built-in confirmation prompt (`Proceed? (y/N)`) but the safeguard guide adds a dry-run preview and impact analysis on top of that.

```bash
# Delete assets older than 30 days
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --cleanup 30d

# Keep only the 50 most recent
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --cleanup 50
```

## Flags reference

| Flag | Description |
|------|-------------|
| `--public` | Publish the release so URLs work in browsers and PRs |
| `-m` / `--markdown` | Output as type-aware markdown (see format table above) |
| `-c` / `--clipboard` | Copy output to clipboard |
| `-r` / `--repo OWNER/REPO` | Target a specific repository |
| `-t` / `--tag TAG` | Custom release tag (default: `_attachments`) |
| `--list` | List all uploaded attachments |
| `--stats` | Show storage usage breakdown by type |
| `--cleanup <Nd\|N>` | Delete old assets by age (`30d`) or keep-count (`100`) |
| `--version` | Print version |
| `--help` | Print full usage |

## Supported file types and size limits

| Category | Formats | Max size |
|----------|---------|----------|
| Images | PNG, JPG, GIF, WebP, SVG, BMP, ICO, TIFF, AVIF | 50 MB |
| Videos | MP4, MOV, WebM, AVI, MKV | 200 MB |
| Audio | MP3, WAV, OGG, FLAC, AAC, M4A | 50 MB |
| Documents | PDF, DOCX, PPTX, XLSX, XLS, RTF, DOC, ODT, ODS, ODP | 25 MB |
| Code | PY, JS, TS, TSX, JSX, Java, C, CPP, Go, RS, RB, SH, SQL, HTML, CSS, XML, YAML, and more | 10 MB |
| Archives | ZIP, GZ, TGZ, TAR, BZ2, XZ, 7Z, RAR | 50 MB |
| Text/Data | TXT, MD, CSV, TSV, LOG, JSON, TOML, INI, CFG, CONF | 25 MB |

**Rejected:** executables (.exe, .dmg, .iso, .deb, .rpm) and symlinks.

**GitHub repo storage limits:** Free/Pro/Team: 5 GB (warning at 1 GB). Enterprise: 100 GB. Release assets count toward total repo size — use `--stats` to monitor.

## Error handling

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `not authenticated` / `401` | gh CLI not logged in | `gh auth login` |
| `repo scope missing` | Token lacks repo scope | `gh auth refresh -s repo` |
| `release not found` / `404` | First use or insufficient permissions | Check repo write access |
| `file not found` | Wrong path | Verify with `ls` |
| File rejected | Exceeds type-specific size limit or is an unsupported type (.exe, etc.) | Check limits table; compress if needed |
| `403 forbidden` | No write access | User needs write permission to the repo |
| `rate limit` | Too many uploads | Wait a few minutes |
| Renders for you, broken for every reviewer | Release is still a draft (`--public` omitted), so the URL contains `untagged-…` | Re-run with `--public` and re-copy the URL — publishing changes it |
| Broken for one reviewer only | Their enterprise SSO session lapsed | Have them open the repo in that browser to refresh SSO; re-uploading won't help |
| Broken for everyone, URL looks correct | Uploaded to a repo the reviewers can't read | Re-upload to the upstream repo or a fork of it |

If the tool exits non-zero and the error isn't listed, surface the full stderr.

## Behavioral rules

1. **Confirm before uploading.** Files leave the working tree and become URLs readable by anyone who can read the target repo. Never upload silently. When no paths are given, use the discovery flow from `references/discovery-and-formatting.md`.
2. **Always use `--public`** for URLs meant to be shared in PRs, issues, or docs — see the Core command section for why a draft's URL breaks. Note that `--public` publishes the *release*, not the *file*: on a private repo the asset remains restricted to people with repo access, so the flag is safe there and omitting it is what causes trouble. On a genuinely public repo, uploaded files are world-readable — that's the case that deserves a confirmation before uploading anything sensitive.
3. **Use descriptive labels.** "Login page – mobile viewport" beats "screenshot-1744349876.png".
4. **Avoid re-uploading identical files.** Check `--list` first and reuse existing URLs.
5. **Follow cleanup safeguards.** Read `references/cleanup-safeguards.md` before any cleanup.
6. **Batch related uploads** in a single command for organized output.
7. **Suggest `.gitignore`** for screenshot/recording directories that are now hosted via Releases.
8. **Prevent accidental binary commits.** If large media files are staged in `git add`, offer to upload as Release assets instead.
9. **Check size limits before uploading.** If a file exceeds the per-type limit (e.g. a 60 MB image), warn the user and suggest compressing.

## When NOT to use

- **Inline code snippets** — paste directly in markdown.
- **Files already in the repo tree** — link via relative paths or blob URLs.
- **Sensitive/secret files** — an asset is exactly as reachable as the repo hosting it, so on a public repo this is a permanent disclosure. Never upload credentials, keys, tokens, or PII without explicit consent, and confirm the target repo's visibility first rather than assuming.
- **Executables** — the tool rejects .exe, .dmg, .iso, .deb, .rpm by design.
- **Temporary files** — use a Gist or paste service if the URL doesn't need to persist.
