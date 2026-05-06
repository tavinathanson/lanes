#!/usr/bin/env bash
# integrate-next.sh — rank lanes by integration safety.
#
# Modes:
#   list  (default) — print a table of mergeable lanes, ranked safest first.
#   pick            — print the top recommendation with one-line reasoning.
#   name            — print just the top recommendation's lane name (for scripts).
#
# "Safest" heuristic: fewest *unintegrated* commits (patch-id aware), tiebreak
# by lane name. A lane with 0 unintegrated commits is skipped.
set -euo pipefail

MODE="${1:-list}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT="$(git branch --show-current)"

rows=""
while IFS='|' read -r path branch; do
  [ -z "$branch" ] && continue
  [ "$branch" = "$CURRENT" ] && continue
  short="${path##*/}"

  # Patch-id-aware count: matches what merge-lane.sh will see.
  new_count="$(git rev-list --cherry-pick --right-only --no-merges \
                 "$CURRENT...$branch" 2>/dev/null | grep -c . || true)"
  [ -z "$new_count" ] && new_count=0
  [ "$new_count" -eq 0 ] && continue

  behind="$(git rev-list --count "$branch..$CURRENT" 2>/dev/null || echo 0)"
  rows="$rows$new_count	$behind	$short	$branch
"
done < <(git worktree list --porcelain | awk '
  /^worktree / { path=$2 }
  /^branch /   { b=$2; sub("refs/heads/", "", b); print path "|" b }
')

# Sort ascending by new_count, tiebreak by lane name.
sorted="$(printf '%s' "$rows" | sort -t '	' -k1,1n -k3,3)"

case "$MODE" in
  list)
    echo "Lanes with commits to integrate into $CURRENT (safest first):"
    echo
    if [ -z "$sorted" ]; then
      echo "  (none)"
      echo
      echo "Run a lane to completion, then 'lanes merge <lane>'."
      exit 0
    fi
    printf "  %-30s %6s %7s\n" "LANE" "NEW" "BEHIND"
    printf '%s\n' "$sorted" | while IFS='	' read -r new behind short branch; do
      [ -z "$short" ] && continue
      printf "  %-30s %6s %7s\n" "$short" "$new" "$behind"
    done
    echo
    echo "Run: lanes merge <lane>"
    echo "Or:  lanes next        # auto-merge the safest one"
    ;;
  pick)
    if [ -z "$sorted" ]; then
      echo "No lanes have unintegrated commits. Nothing to recommend."
      exit 0
    fi
    top="$(printf '%s\n' "$sorted" | head -n1)"
    new="$(printf '%s' "$top" | cut -f1)"
    behind="$(printf '%s' "$top" | cut -f2)"
    short="$(printf '%s' "$top" | cut -f3)"
    echo "Recommended next: $short"
    echo "  $new new commit(s) to integrate, $behind behind $CURRENT."
    echo "  (Heuristic: smallest unintegrated changeset wins. For nuance, run 'lanes monitor'.)"
    echo
    echo "Run: lanes merge $short"
    ;;
  name)
    if [ -z "$sorted" ]; then
      exit 0
    fi
    printf '%s\n' "$sorted" | head -n1 | cut -f3
    ;;
  *)
    echo "usage: integrate-next.sh [list|pick|name]" >&2
    exit 1
    ;;
esac
