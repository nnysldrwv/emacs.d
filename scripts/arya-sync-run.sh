#!/usr/bin/env bash
# arya-sync-run.sh — pull / sync emacs config via git
# Usage: arya-sync-run.sh [pull|sync]

set -euo pipefail

MODE="${1:-sync}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE=origin
BRANCH=main
HOSTNAME="$(hostname -s)"

cd "$REPO"

# sanity checks
git rev-parse --is-inside-work-tree &>/dev/null || { echo "SKIP: not a git repo"; exit 0; }
git remote get-url "$REMOTE" &>/dev/null        || { echo "SKIP: remote not found"; exit 0; }

# repo busy?
if [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]; then
  echo "SKIP: repo busy"
  exit 0
fi

# unresolved conflicts?
if git diff --name-only --diff-filter=U | grep -q .; then
  echo "SKIP: conflicts present"
  exit 0
fi

git pull --rebase --autostash "$REMOTE" "$BRANCH"

if [[ "$MODE" == "pull" ]]; then
  echo "PULL_OK"
  exit 0
fi

# stage only tracked config files
git add -- .gitattributes .gitignore README.md init.el init.local.example.el lisp scripts

# anything to commit?
if git diff --cached --quiet; then
  echo "NO_CHANGES"
  exit 0
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "sync: emacs auto-update $HOSTNAME $TIMESTAMP"
git pull --rebase --autostash "$REMOTE" "$BRANCH"
git push "$REMOTE" "$BRANCH"
echo "SYNC_OK"
