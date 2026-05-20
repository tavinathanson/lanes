#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

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

# Even with unintegrated commits by patch-id, the lane may add nothing once a
# real 3-way merge is considered (e.g. a commit whose patch-id changed during a
# past conflict resolution, so its content already landed under a different
# SHA). If merging would not change $CURRENT at all, there is nothing to do.
if lane_adds_nothing "$CURRENT" "$LANE"; then
  echo "Nothing to integrate: merging $LANE would not change $CURRENT."
  echo "(Its commits are flagged by patch-id, but their content is already present."
  echo " Retire the lane with 'lanes drop $LANE' when you're done with it.)"
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
# Serialize concurrent `lanes merge` invocations against the same repo so they
# don't race for `.git/index.lock`. Linked worktrees have their own index, but
# multiple operations on the main checkout (e.g. two Claude sessions) share it.
GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
LOCK_FILE="$GIT_COMMON_DIR/lanes-merge.lock"

run_merge() {
  if [ "$NEW_COUNT" -le 2 ]; then
    echo "Mode: cherry-pick ($NEW_COUNT commit(s))"
    # shellcheck disable=SC2086
    printf '%s\n' "$NEW_SHAS" | xargs git cherry-pick
  else
    echo "Mode: merge --ff ($NEW_COUNT commit(s))"
    git merge --ff "$LANE"
  fi
}

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    echo "Another lanes merge is in progress (waiting for lock: $LOCK_FILE)..."
    flock 9
  fi
  run_merge
else
  run_merge
fi

echo
echo "Integration complete on $CURRENT."
echo "Latest:"
git --no-pager log --oneline -5
echo
echo "Next: run your tests. Nothing has been pushed. The lane worktree/branch is untouched."
