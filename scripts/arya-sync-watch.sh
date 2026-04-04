#!/usr/bin/env bash
# arya-sync-watch.sh — watch emacs config files and auto-sync on change
# Uses fswatch with a built-in debounce (latency flag).

set -euo pipefail

DEBOUNCE="${1:-8}"  # seconds
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SYNC_SCRIPT="$(dirname "$0")/arya-sync-run.sh"

echo "arya-sync-watch started for $REPO (debounce ${DEBOUNCE}s)"

fswatch \
  --latency "$DEBOUNCE" \
  --one-per-batch \
  --recursive \
  --exclude '\.git/' \
  --exclude 'init\.local\.el' \
  --exclude 'oauth2-auto\.plist' \
  --include '\.el$' \
  --include '\.md$' \
  --include '\.gitignore' \
  --include '\.gitattributes' \
  "$REPO/init.el" \
  "$REPO/README.md" \
  "$REPO/.gitignore" \
  "$REPO/.gitattributes" \
  "$REPO/init.local.example.el" \
  "$REPO/lisp" \
  "$REPO/scripts" \
  | while read -r _; do
      echo "[$(date '+%H:%M:%S')] change detected, syncing..."
      bash "$SYNC_SCRIPT" sync || echo "[$(date '+%H:%M:%S')] sync failed"
    done
