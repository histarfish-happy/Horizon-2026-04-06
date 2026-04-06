#!/usr/bin/env bash
# Deploy docs/ to gh-pages branch
# Usage: ./scripts/deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

cd "$PROJECT_DIR"

echo "$LOG_PREFIX Deploying to gh-pages..."

TMPDIR=$(mktemp -d)
trap "git worktree remove --force '$TMPDIR' 2>/dev/null; rm -rf '$TMPDIR'" EXIT

git fetch origin gh-pages:gh-pages 2>/dev/null || true

git worktree add "$TMPDIR" gh-pages
cp -r docs/* "$TMPDIR/"

cd "$TMPDIR"
git add -A
git diff --staged --quiet || git commit -m "Daily Summary: $(date '+%Y-%m-%d')"
git push --force origin gh-pages

echo "$LOG_PREFIX Done."
