#!/usr/bin/env bash
# archive-lane.sh: hide lanes from 'lanes merge', 'next' and 'next-all' without
# removing anything. The flag is local git config, so the worktree, branch and
# commits stay exactly as they are.
#
#   archive-lane.sh                   list archived lanes
#   archive-lane.sh <lane>...         archive those lanes
#   archive-lane.sh --older <days>    archive every lane whose last commit is
#                                     older than <days>
#   archive-lane.sh --undo <lane>...  unarchive those lanes
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

cd "$(git rev-parse --show-toplevel)"
CURRENT="$(git branch --show-current)"

# set_flag <branch>: archive it, or unarchive it under --undo.
set_flag() {
  if [ "$UNDO" = 1 ]; then
    git config --unset "branch.$1.lanesArchived" || true
    echo "unarchived: ${1#worktree-}"
  else
    git config "branch.$1.lanesArchived" true
    echo "archived: ${1#worktree-} (last commit $(lane_age "$1"))"
    warn_if_dirty "$1"
  fi
}

UNDO=0
case "${1:-}" in
  "")
    archived="$(archived_branches)"
    [ -z "$archived" ] && { echo "No archived lanes."; exit 0; }
    echo "Archived lanes (hidden from 'lanes merge'; 'lanes unarchive <lane>' to restore):"
    printf '%s\n' "$archived" | while read -r b; do echo "  ${b#worktree-}"; done
    exit 0
    ;;
  --older)
    days="${2:-}"
    [[ "$days" =~ ^[0-9]+$ ]] || { echo "usage: lanes archive --older <days>"; exit 1; }
    cutoff=$(( $(date +%s) - days * 86400 ))
    git worktree list --porcelain | awk -v cur="refs/heads/$CURRENT" '
      /^branch / && $2 != cur { b=$2; sub("refs/heads/", "", b); print b }
    ' | while read -r b; do
      [ "$(git config --bool "branch.$b.lanesArchived")" = true ] && continue
      if [ "$(git log -1 --format=%ct "$b")" -lt "$cutoff" ]; then set_flag "$b"; fi
    done
    exit 0
    ;;
  --undo) UNDO=1; shift ;;
esac

for lane in "$@"; do
  b="$(resolve_lane "$lane" || true)"
  [ -z "$b" ] && { echo "no such lane: $lane"; continue; }
  set_flag "$b"
done
