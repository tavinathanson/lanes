#!/usr/bin/env bash
set -euo pipefail

LANE="${1:-}"

if [ -z "$LANE" ]; then
  echo "usage: merge-lane.sh <lane-name>"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT="$(git branch --show-current)"

if [ "$CURRENT" = "$LANE" ]; then
  echo "Refusing to merge $LANE into itself. Switch to the target branch first."
  exit 1
fi

if [ -n "$(git status --short --untracked-files=no)" ]; then
  echo "Working tree has tracked modifications on $CURRENT. Commit or stash before merging."
  git status --short --untracked-files=no
  exit 1
fi

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

RAW_AHEAD="$(git rev-list --count "$CURRENT..$LANE" 2>/dev/null || echo 0)"
BEHIND="$(git rev-list --count "$LANE..$CURRENT" 2>/dev/null || echo 0)"

# Patch-id-aware list of commits on $LANE not yet present on $CURRENT.
# Survives prior cherry-picks: a commit whose patch is already applied
# (with a different SHA) is filtered out.
NEW_SHAS="$(git rev-list --cherry-pick --right-only --no-merges --reverse "$CURRENT...$LANE" 2>/dev/null || true)"
if [ -z "$NEW_SHAS" ]; then
  NEW_COUNT=0
else
  NEW_COUNT="$(printf '%s\n' "$NEW_SHAS" | grep -c .)"
fi

echo "Integrating $LANE into $CURRENT"
echo "  raw: $RAW_AHEAD ahead / $BEHIND behind"
echo "  unintegrated commits (patch-id aware): $NEW_COUNT"
echo

if [ "$NEW_COUNT" = "0" ]; then
  echo "Nothing to integrate: every commit on $LANE is already present on $CURRENT (by SHA or by patch)."
  exit 0
fi

echo "Commits to land:"
printf '%s\n' "$NEW_SHAS" | xargs -r -n1 git --no-pager log --oneline -1
echo

# Threshold:
#   <=2 new commits -> cherry-pick (linear history, no merge commit, even when
#                      $CURRENT has moved since the lane forked)
#   >=3 new commits -> merge --ff (fast-forwards when possible; falls back to
#                      a single merge commit if $CURRENT has moved)
if [ "$NEW_COUNT" -le 2 ]; then
  echo "Mode: cherry-pick ($NEW_COUNT commit(s))"
  # shellcheck disable=SC2086
  printf '%s\n' "$NEW_SHAS" | xargs git cherry-pick
else
  echo "Mode: merge --ff ($NEW_COUNT commit(s))"
  git merge --ff "$LANE"
fi

echo
echo "Integration complete on $CURRENT."
echo "Latest:"
git --no-pager log --oneline -5
echo
echo "Next: run your tests. Nothing has been pushed. The lane worktree/branch is untouched."
