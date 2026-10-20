# Discovery, scanning, and formatting

Read this reference when the user asks to upload files **without specifying exact paths** — e.g. "add screenshots to the PR", "attach files", "upload everything in screenshots/".

## Discovery flow

The full sequence: **scan → present → select → label → confirm → upload → embed**.

## Step 1 — Scan for candidates

Run the bundled scan script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/file-attach/scripts/scan-media.sh
```

To scan a specific directory:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/file-attach/scripts/scan-media.sh screenshots/
```

Output is tab-separated: `path \t type \t size \t metadata \t mtime_relative`.

### What the 5 layers search

1. **Test framework outputs** — `test-results/`, `playwright-report/`, `cypress/screenshots/`, `cypress/videos/`, `__image_snapshots__/`, `storybook-static/`, `.loki/`, `e2e/`. Most common source of screenshots in dev — almost always gitignored.
2. **Project asset directories** — `screenshots/`, `docs/images/`, `media/`, `videos/`, `recordings/`, `demos/`, `reports/`.
3. **Recently modified files** — `find -newer .git/HEAD` anywhere in the tree, excluding `node_modules/`, `.git/`, `vendor/`, `dist/`, `build/`, `.next/`, `.nuxt/`. Falls back to a full scan on repos with zero commits.
4. **Git-tracked changes** — `git status --porcelain` for staged or modified media.

If all layers find nothing, the script outputs `__NO_FILES_FOUND__` — prompt the user for a path instead. Results are capped at 50 files to avoid hanging on large repos; if truncated, the script signals `__TRUNCATED__<total>` on stderr.

**Note:** The scan intentionally does NOT search `~/Desktop/`, `~/Downloads/`, or other home directories — surfacing personal file names is a privacy risk. If the user wants files from outside the project tree, ask them for the path explicitly.

## Step 2 — Present the list

Show numbered results with format-appropriate metadata:

```
Found 6 files:
  1. screenshots/login-before.png      image      1920x1080   142 KB   (2 min ago)
  2. screenshots/login-after.png       image      1920x1080   138 KB   (2 min ago)
  3. recordings/demo-flow.mp4          video      1280x720    12.4 MB  (10 min ago)
  4. test-results/visual-diff.png      image      800x600     47 KB    (1 hr ago)
  5. reports/coverage-report.pdf       document   14 pages    820 KB   (30 min ago)
  6. logs/server-crash.log             text       -           24 KB    (5 min ago)

Which ones should I upload? (e.g. "1, 2, 3" or "all" or "skip")
```

The script handles metadata gracefully — missing tools (`ffprobe`, `identify`, `pdfinfo`) fall back to file size only.

### If the scan finds nothing

Say: "I checked test output directories, project asset folders, and recently modified files but didn't find any uploadable files. Where are yours? Give me a file path or directory and I'll upload from there."

### Check size limits before uploading

The tool enforces per-type limits: images 50 MB, videos 200 MB, audio 50 MB, documents 25 MB, code 10 MB, archives 50 MB, text 25 MB. If a selected file exceeds its limit, warn the user and suggest compressing before uploading.

## Step 3 — Smart labeling

Infer labels from the **branch name** + **filename hints**:

```bash
git branch --show-current | sed 's|.*/||; s/-/ /g; s/_/ /g'
```

Branch `fix/login-button-hover-state` + file `before.png` → "Login button hover state – before".

Filename keywords appended to the branch-derived label: "before", "after", "old", "new", "mobile", "desktop", "dark", "light", "tablet", "error", "success".

Always confirm labels before uploading:

```
I'll upload with these labels:
  1. "Login button hover state – before" ← screenshots/login-before.png
  2. "Login button hover state – after"  ← screenshots/login-after.png
Sound good?
```

## Step 4 — Embed into PR or issue

Target priority:

1. **User specified a number** ("add to PR #1244") → use directly.
2. **User said "the PR"** without a number → auto-detect: `gh pr view --json number,url,body 2>/dev/null`. Confirm: "You have PR #42 open — add these there?"
3. **No PR context** → print markdown for manual placement.

### Safe embedding

```bash
tmpfile=$(mktemp /tmp/pr-body-XXXXXX.md)
gh pr view <number> --json body -q .body > "$tmpfile"
if [ $? -ne 0 ]; then rm "$tmpfile"; echo "ERROR: could not fetch PR body"; exit 1; fi
printf '\n\n## Attachments\n\n<uploaded markdown here>\n' >> "$tmpfile"
gh pr edit <number> --body-file "$tmpfile"
rm "$tmpfile"
```

Never use `gh pr edit --body "$(gh pr view ...)"` — existing backticks and `$` signs will be interpreted by the shell.

### Contextual headings

- Images only → `## Screenshots`
- Videos only → `## Recordings`
- Mixed types → `## Attachments`

## Formatting helpers

### Before/After comparison

Auto-detect when two files have "before"/"after" or "old"/"new" in their names.

**Images** — side-by-side table:
```markdown
| Before | After |
|--------|-------|
| ![Before](url1) | ![After](url2) |
```

**Videos** — labeled links:
```markdown
| Before | After |
|--------|-------|
| [▶ Before recording](url1) | [▶ After recording](url2) |
```

**Documents:**
```markdown
**Before:** [📄 Report v1](url1)
**After:** [📄 Report v2](url2)
```

**Viewport grid** (images only):
```markdown
| | Mobile | Desktop |
|---|--------|---------|
| **Before** | ![](url1) | ![](url2) |
| **After** | ![](url3) | ![](url4) |
```

### Collapsible sections for 5+ files

```markdown
<details>
<summary>Attachments (7 files)</summary>

![Homepage](url1)
![Dashboard](url2)
[▶ Demo recording](url3)
[📄 Coverage report](url4)
...

</details>
```

### URL verification

Resist the urge to verify a private-repo URL with `curl` — it cannot work, and it's worse than skipping the check because it reports success either way:

- The web download path ignores `Authorization: Bearer` tokens entirely; only browser session cookies count. An authenticated `curl` is still an anonymous request.
- On an SSO-enforced org every URL under the repo answers `302` (a redirect to the login page) whether the asset exists or not, so a real asset and a typo'd filename look identical.

A `302` therefore certifies nothing. Rely on the upload command's exit status instead — it fails loudly when an asset doesn't land — and use `--list` to confirm what's actually stored. Visual confirmation means opening the PR in a browser.

Public repos are the exception: there a `200` after following redirects is meaningful, since no session is involved.
