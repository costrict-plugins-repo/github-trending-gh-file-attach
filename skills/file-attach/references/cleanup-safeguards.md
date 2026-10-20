# Cleanup safeguards

Read this reference before running `--cleanup`. Cleanup permanently breaks every markdown link referencing deleted assets — in merged PRs, closed issues, READMEs, and wikis.

The tool itself asks `Proceed? (y/N)` before deleting, but that confirmation only shows the count — it doesn't preview which assets will be deleted or check for live references. These safeguard steps add that missing context.

## Step 1 — Inventory

Start with a full list so the user can see what exists:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --list
```

Also check current storage usage:

```bash
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --stats
```

## Step 2 — Preview what would be deleted

Before running cleanup, filter the `--list` output to show what matches the cleanup criteria. Present both sides:

```
Cleanup preview (assets older than 30 days):

  Will DELETE (12 assets):
    - login-screenshot-20260301-a1b2c3d4.png    13 KB   2026-03-01
    - dashboard-20260305-b2c3d4e5.png           204 KB  2026-03-05
    - demo-20260310-c3d4e5f6.mp4                48 MB   2026-03-10
    ... (9 more)

  Will KEEP (31 assets):
    - header-redesign-20260408-d4e5f6a7.png     88 KB   2026-04-08
    ... (30 more)
```

## Step 3 — Impact analysis

Check whether any to-be-deleted URLs are still referenced in PRs or issues:

```bash
gh search issues "<asset_url>" --repo <owner/repo> --limit 5
gh search prs "<asset_url>" --repo <owner/repo> --state open --limit 5
```

If references are found, warn:

```
⚠️  3 assets are still referenced:
  - demo-20260310-c3d4e5f6.mp4 → PR #412 (merged), Issue #89 (open)
  - login-screenshot-20260301-a1b2c3d4.png → PR #398 (merged)

Deleting them will break those links permanently.
```

If `gh search` is unavailable or too slow, warn: "I can't verify whether these URLs are referenced in existing PRs/issues. Deleting may break links."

## Step 4 — Confirm with scope

Make the user acknowledge the specific count:

```
This will permanently delete 12 assets. This cannot be undone.
The tool will ask for confirmation — type "y" to proceed or "N" to cancel.
```

Then execute:

```bash
# The tool prompts "Proceed? (y/N)" before deleting
${CLAUDE_PLUGIN_ROOT}/bin/gh-file-attach --cleanup 30d
```

## Step 5 — Report

After cleanup, confirm what happened. The tool prints per-asset deletion messages and a final count.

## Never auto-cleanup

Even if storage is running low (check via `--stats`), surface it as a suggestion — "You're using 1.8 GB of 5 GB — want to review old assets for cleanup?" — rather than running cleanup automatically.
