#!/usr/bin/env bash
# scan-media.sh — Discover uploadable media files in a project.
# Extension list matches gh-file-attach's supported formats exactly.
#
# Usage:
#   scan-media.sh [directory]          Scan a specific directory
#   scan-media.sh                      Run the full 5-layer priority scan
#
# Output: one file per line as TAB-separated fields:
#   path \t type \t size \t metadata \t mtime_relative

set -euo pipefail

# ── Canonical extension list ───────────────────────────────────────────────
# Matches gh-file-attach supported formats. Edit ONLY here.
IMG_EXT="png|jpg|jpeg|gif|webp|svg|bmp|ico|tiff|avif"
VID_EXT="mp4|mov|webm|avi|mkv"
AUD_EXT="mp3|wav|ogg|flac|aac|m4a"
DOC_EXT="pdf|docx|pptx|xlsx|xls|rtf|doc|odt|ods|odp"
CODE_EXT="py|js|ts|tsx|jsx|java|c|cpp|cs|go|rs|rb|sh|sql|html|css|xml|yaml|swift|kt|scala|vue|svelte"
ARC_EXT="zip|gz|tgz|tar|bz2|xz|7z|rar"
TXT_EXT="txt|md|csv|tsv|log|json|toml|ini|cfg|conf"
OTHER_EXT="debug|msg|eml|dmp|pdb|cpuprofile"
ALL_EXT="${IMG_EXT}|${VID_EXT}|${AUD_EXT}|${DOC_EXT}|${CODE_EXT}|${ARC_EXT}|${TXT_EXT}|${OTHER_EXT}"

# ── Common exclusions ──────────────────────────────────────────────────────
PRUNE_DIRS="node_modules|.git|vendor|dist|build|__pycache__|.venv|.next|.nuxt"

# ── Helpers ────────────────────────────────────────────────────────────────

file_type() {
  local ext="${1##*.}"
  ext="${ext,,}"
  if [[ "$ext" =~ ^(${IMG_EXT})$ ]]; then echo "image"
  elif [[ "$ext" =~ ^(${VID_EXT})$ ]]; then echo "video"
  elif [[ "$ext" =~ ^(${AUD_EXT})$ ]]; then echo "audio"
  elif [[ "$ext" =~ ^(${DOC_EXT})$ ]]; then echo "document"
  elif [[ "$ext" =~ ^(${CODE_EXT})$ ]]; then echo "code"
  elif [[ "$ext" =~ ^(${ARC_EXT})$ ]]; then echo "archive"
  elif [[ "$ext" =~ ^(${TXT_EXT})$ ]]; then echo "text"
  else echo "other"; fi
}

get_size() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f %z "$1" 2>/dev/null | awk '{
      if ($1 >= 1048576) printf "%.1f MB", $1/1048576
      else if ($1 >= 1024) printf "%.0f KB", $1/1024
      else printf "%d B", $1
    }'
  else
    stat -c %s "$1" 2>/dev/null | awk '{
      if ($1 >= 1048576) printf "%.1f MB", $1/1048576
      else if ($1 >= 1024) printf "%.0f KB", $1/1024
      else printf "%d B", $1
    }'
  fi
}

get_metadata() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext,,}"

  # Image dimensions
  if [[ "$ext" =~ ^(png|jpg|jpeg|gif|webp|bmp|tiff|avif|ico)$ ]]; then
    if command -v identify &>/dev/null; then
      identify -format '%wx%h' "$file" 2>/dev/null | head -1 && return
    fi
    file "$file" 2>/dev/null | grep -oP '\d+\s*x\s*\d+' | head -1 && return
  fi

  # Video resolution + duration
  if [[ "$ext" =~ ^(mp4|mov|webm|avi|mkv)$ ]]; then
    if command -v ffprobe &>/dev/null; then
      local dur res
      dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | head -1)
      res=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$file" 2>/dev/null | head -1 | tr ',' 'x')
      if [ -n "$res" ] && [ -n "$dur" ]; then
        local secs=$(printf '%.0f' "$dur")
        printf '%s %d:%02d' "$res" $((secs/60)) $((secs%60))
        return
      fi
    fi
  fi

  # PDF page count
  if [[ "$ext" == "pdf" ]]; then
    if command -v pdfinfo &>/dev/null; then
      pdfinfo "$file" 2>/dev/null | awk '/^Pages:/{print $2 " pages"}' && return
    fi
  fi

  # Audio duration
  if [[ "$ext" =~ ^(mp3|wav|ogg|flac|aac|m4a)$ ]]; then
    if command -v ffprobe &>/dev/null; then
      local dur
      dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null | head -1)
      if [ -n "$dur" ]; then
        local secs=$(printf '%.0f' "$dur")
        printf '%d:%02d' $((secs/60)) $((secs%60))
        return
      fi
    fi
  fi

  echo "-"
}

get_mtime() {
  local file="$1" now fmod diff
  now=$(date +%s)
  if [[ "$(uname -s)" == "Darwin" ]]; then
    fmod=$(stat -f %m "$file" 2>/dev/null)
  else
    fmod=$(stat -c %Y "$file" 2>/dev/null)
  fi
  [ -z "$fmod" ] && echo "unknown" && return
  diff=$((now - fmod))
  if [ $diff -lt 60 ]; then echo "just now"
  elif [ $diff -lt 3600 ]; then echo "$((diff/60)) min ago"
  elif [ $diff -lt 86400 ]; then echo "$((diff/3600)) hr ago"
  else echo "$((diff/86400)) days ago"; fi
}

# Build a find-compatible regex for matching extensions
FIND_REGEX=".*\\.($ALL_EXT)$"

do_find() {
  local dir="$1" depth="${2:-10}"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS BSD find uses -E flag for extended regex
    find -E "$dir" -maxdepth "$depth" \
      -not -regex ".*/($PRUNE_DIRS)/.*" \
      -type f -iregex "$FIND_REGEX" 2>/dev/null
  else
    # GNU find uses -regextype
    find "$dir" -maxdepth "$depth" \
      -regextype posix-extended \
      -not -regex ".*/($PRUNE_DIRS)/.*" \
      -type f -iregex "$FIND_REGEX" 2>/dev/null
  fi
}

output_results() {
  sort -u | while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$f" "$(file_type "$f")" "$(get_size "$f")" "$(get_metadata "$f")" "$(get_mtime "$f")"
  done
}

# ── Specific directory scan ────────────────────────────────────────────────
if [ -n "${1:-}" ] && [ -d "${1:-}" ]; then
  # S4: Validate directory is not outside the project tree (security)
  abs_dir=$(cd "$1" && pwd)
  abs_cwd=$(pwd)
  if [[ "$abs_dir" != "$abs_cwd"* ]] && [[ "$abs_dir" != /tmp* ]]; then
    echo "WARNING: $1 is outside the project directory. Scanning anyway." >&2
  fi
  do_find "$1" | head -50 | output_results
  exit 0
fi

# ── Full 5-layer priority scan ─────────────────────────────────────────────
FOUND=$(mktemp)
trap 'rm -f "$FOUND"' EXIT

# Layer 1: Test framework output directories
for dir in test-results playwright-report cypress/screenshots cypress/videos \
           __image_snapshots__ storybook-static coverage .loki e2e/screenshots e2e/videos; do
  [ -d "$dir" ] && do_find "$dir" >> "$FOUND"
done

# Layer 2: Common project asset directories
for dir in screenshots docs/images assets/images static/images public/images \
           images media videos recordings demos docs/assets reports; do
  [ -d "$dir" ] && do_find "$dir" >> "$FOUND"
done

# Layer 3: Recently modified files anywhere in the tree
if [ -f .git/HEAD ] && git rev-parse HEAD &>/dev/null; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    find -E . -maxdepth 3 -not -regex ".*/($PRUNE_DIRS)/.*" \
      -type f -iregex "$FIND_REGEX" -newer .git/HEAD 2>/dev/null >> "$FOUND"
  else
    find . -maxdepth 3 -regextype posix-extended -not -regex ".*/($PRUNE_DIRS)/.*" \
      -type f -iregex "$FIND_REGEX" -newer .git/HEAD 2>/dev/null >> "$FOUND"
  fi
else
  do_find . 3 >> "$FOUND"
fi

# Layer 4: Git-tracked new/modified
git status --porcelain 2>/dev/null | awk '{print $NF}' | grep -iE "\.(${ALL_EXT})$" >> "$FOUND" 2>/dev/null || true

# Layer 5: Signal that nothing was found in the project
# SECURITY: Do NOT silently scan ~/Desktop, ~/Downloads, ~/Pictures, ~/Movies.
# Personal files (medical docs, legal files, photos) could be surfaced.
# Instead, signal the caller to ask the user for a path.
if [ ! -s "$FOUND" ]; then
  echo "__NO_FILES_FOUND__"
  exit 0
fi

# A3: Limit results to avoid hanging on large repos (metadata is expensive)
TOTAL=$(wc -l < "$FOUND")
cat "$FOUND" | head -50 | output_results
if [ "$TOTAL" -gt 50 ]; then
  echo "__TRUNCATED__${TOTAL}" >&2
fi
