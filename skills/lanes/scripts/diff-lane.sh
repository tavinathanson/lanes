#!/usr/bin/env bash
# diff-lane.sh — show what a lane would land if merged into the current branch.
#
# Uses CURRENT...LANE (three-dot) so the diff is from the merge base to LANE:
# exactly the changes the lane introduced, ignoring anything CURRENT has gained
# since the lane forked.
set -euo pipefail

STAT=0
LANE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --stat) STAT=1 ;;
    -h|--help)
      echo "usage: diff-lane.sh [--stat] <lane>"
      exit 0
      ;;
    -*) echo "unknown flag: $1" >&2; exit 1 ;;
    *)  LANE="$1" ;;
  esac
  shift
done

if [ -z "$LANE" ]; then
  echo "usage: diff-lane.sh [--stat] <lane>" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT="$(git branch --show-current)"

resolve_lane() {
  local name="$1"
  if git rev-parse --verify --quiet "refs/heads/$name" >/dev/null; then
    echo "$name"; return 0
  fi
  if git rev-parse --verify --quiet "refs/heads/worktree-$name" >/dev/null; then
    echo "worktree-$name"; return 0
  fi
  local match
  match="$(git worktree list --porcelain | awk -v n="$name" '
    /^worktree / { p=$2; b="" }
    /^branch /   { b=$2; sub("refs/heads/", "", b)
                   nb=p; sub(".*/","",nb)
                   if (nb==n || b==n) print b
                 }
  ' | head -n1)"
  if [ -n "$match" ]; then
    echo "$match"; return 0
  fi
  return 1
}

RESOLVED="$(resolve_lane "$LANE" || true)"
if [ -z "$RESOLVED" ]; then
  echo "Branch not found for lane: $LANE"
  echo "Available worktrees:"
  git worktree list
  exit 1
fi
LANE="$RESOLVED"

NEW_COUNT="$(git rev-list --cherry-pick --right-only --no-merges \
               "$CURRENT...$LANE" 2>/dev/null | grep -c . || true)"
[ -z "$NEW_COUNT" ] && NEW_COUNT=0

echo "Diff for $LANE vs $CURRENT (merge-base...$LANE)"
echo "  unintegrated commits (patch-id aware): $NEW_COUNT"
echo

if [ "$STAT" = "1" ]; then
  git --no-pager diff --stat "$CURRENT...$LANE"
else
  git --no-pager diff "$CURRENT...$LANE"
fi
