#!/usr/bin/env bash
# drop-lane.sh — retire a finished lane: remove its worktree and delete its
# branch in one step. Refuses if the lane still has unintegrated work or a dirty
# worktree, unless --force is given.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

FORCE=0
LANE=""
for a in "$@"; do
  case "$a" in
    -f|--force) FORCE=1 ;;
    *) [ -z "$LANE" ] && LANE="$a" ;;
  esac
done

if [ -z "$LANE" ]; then
  echo "usage: drop-lane.sh <lane> [--force]"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
CURRENT="$(git branch --show-current)"

RESOLVED="$(resolve_lane "$LANE" || true)"
if [ -z "$RESOLVED" ]; then
  echo "Branch not found for lane: $LANE"
  echo "Available worktrees:"
  git worktree list
  exit 1
fi
LANE="$RESOLVED"

if [ "$LANE" = "$CURRENT" ]; then
  echo "Refusing to drop $LANE: it's the current branch."
  exit 1
fi

# Worktree path for this branch, if any.
WT_PATH="$(git worktree list --porcelain | awk -v b="refs/heads/$LANE" '
  /^worktree / { p=$2 }
  /^branch /   { if ($2==b) print p }
' | head -n1)"

# Guard: does the lane still have real work to integrate into $CURRENT?
NEW_COUNT="$(git rev-list --cherry-pick --right-only --no-merges \
               "$CURRENT...$LANE" 2>/dev/null | grep -c . || true)"
[ -z "$NEW_COUNT" ] && NEW_COUNT=0
if [ "$FORCE" -ne 1 ] && [ "$NEW_COUNT" -ne 0 ] && ! lane_adds_nothing "$CURRENT" "$LANE"; then
  echo "Refusing to drop $LANE: it has $NEW_COUNT unintegrated commit(s) vs $CURRENT."
  echo "Integrate it first ('lanes merge $LANE'), or re-run with --force to discard."
  exit 1
fi

echo "Dropping lane $LANE"
if [ -n "$WT_PATH" ]; then
  if [ "$FORCE" -eq 1 ]; then
    git worktree remove --force "$WT_PATH"
  else
    git worktree remove "$WT_PATH"
  fi
  echo "  removed worktree: $WT_PATH"
fi
git branch -D "$LANE"
echo "  deleted branch:   $LANE"
echo
echo "Done. Nothing was pushed."
