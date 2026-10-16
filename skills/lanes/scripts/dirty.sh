#!/usr/bin/env bash
# dirty.sh: list every worktree with uncommitted work, so nothing gets left
# behind. Exits 1 when any worktree is dirty, 0 when all are clean.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

rows="$(dirty_lanes)"
stashes="$(git stash list | grep -c . || true)"

if [ -z "$rows" ]; then
  echo "All worktrees are clean."
else
  echo "Worktrees with uncommitted work:"
  printf '%s\n' "$rows" | while IFS='	' read -r short summary; do
    printf '  %-30s %s\n' "$short" "$summary"
  done
  echo
  echo "Commit inside each lane with /wrap, or see details with 'lanes inspect <lane>'."
fi
[ "$stashes" -gt 0 ] && echo "($stashes stash(es) too: 'git stash list'.)"
[ -z "$rows" ]
