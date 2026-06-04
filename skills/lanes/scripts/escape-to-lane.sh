#!/usr/bin/env bash
# escape-to-lane.sh <lane> — you started in the main checkout without a lane.
# Move any uncommitted work into a new lane worktree, leaving main clean, and
# print a one-liner to continue the current Claude conversation in that lane.
# Nothing is committed, merged, or pushed. On any failure, work is restored to
# main and nothing is moved.
set -euo pipefail

LANE="${1:-}"
if [ -z "$LANE" ]; then
  echo "usage: escape-to-lane.sh <lane>"
  exit 1
fi

# Resolve the main checkout root from the shared git dir, then refuse to run
# from inside a worktree (where there's nothing to escape).
COMMON="$(git rev-parse --git-common-dir)"
case "$COMMON" in /*) ;; *) COMMON="$(pwd)/$COMMON" ;; esac
MAIN_ROOT="$(cd "$(dirname "$COMMON")" && pwd)"
TOPLEVEL="$(git rev-parse --show-toplevel)"
if [ "$TOPLEVEL" != "$MAIN_ROOT" ]; then
  echo "You're already in a worktree ($TOPLEVEL), not the main checkout."
  echo "Nothing to escape."
  exit 1
fi

BRANCH="worktree-$LANE"        # matches Claude Code's `--worktree` convention
WT_PATH="$MAIN_ROOT/.claude/worktrees/$LANE"

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "Lane '$LANE' already exists (branch $BRANCH). Pick a different name."
  exit 1
fi
if [ -e "$WT_PATH" ]; then
  echo "Path already exists: $WT_PATH. Pick a different name."
  exit 1
fi

DIRTY=0
[ -n "$(git status --porcelain)" ] && DIRTY=1

if [ "$DIRTY" -eq 1 ]; then
  git stash push -u -m "lane-escape:$LANE" >/dev/null
fi

git worktree add "$WT_PATH" -b "$BRANCH" >/dev/null

if [ "$DIRTY" -eq 1 ]; then
  if ! git -C "$WT_PATH" stash pop >/dev/null 2>&1; then
    git worktree remove --force "$WT_PATH" >/dev/null 2>&1 || true
    git branch -D "$BRANCH" >/dev/null 2>&1 || true
    git stash pop >/dev/null 2>&1 || true
    echo "Error: could not apply your changes in the new worktree."
    echo "Restored everything to main. Nothing was moved."
    exit 1
  fi
  echo "Moved your uncommitted work into lane '$LANE'. main is now clean."
else
  echo "Created empty lane '$LANE' (main had no uncommitted changes)."
fi

echo
echo "  Worktree: $WT_PATH"
echo "  Branch:   $BRANCH"
echo

SID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SID" ]; then
  echo "To continue THIS conversation in the lane, exit this session and run:"
  echo
  echo "    cd \"$WT_PATH\" && claude --resume $SID --fork-session"
  echo
  echo "(Drop --fork-session to reuse this session id instead of forking a copy.)"
else
  echo "Open the lane with:  lanes start $LANE"
fi
