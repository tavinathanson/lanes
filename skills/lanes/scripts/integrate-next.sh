#!/usr/bin/env bash
# integrate-next.sh: rank lanes by integration safety.
#
# Modes:
#   list  (default): print a table of mergeable lanes, ranked safest first.
#   pick           : print the top recommendation with one-line reasoning.
#   name           : print just the top recommendation's lane name (for scripts).
#
# "Safest" ranking, in order:
#   1. today's lanes (tip committed today, local time) before older ones
#   2. lanes that merge cleanly before lanes that would conflict
#   3. fewest lines changed (merge-base...lane)
#   4. lane name
# A lane with 0 unintegrated commits (patch-id aware) is skipped, as is a lane
# that a real 3-way merge shows would not change $CURRENT at all.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

MODE="${1:-list}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CURRENT="$(git branch --show-current)"

# Row fields (tab-separated): older conflict lines short new behind merge age
rows=""
while IFS='|' read -r path branch; do
  [ -z "$branch" ] && continue
  [ "$branch" = "$CURRENT" ] && continue
  short="${branch#worktree-}"

  # Patch-id-aware count: matches what merge-lane.sh will see.
  new_count="$(git rev-list --cherry-pick --right-only --no-merges \
                 "$CURRENT...$branch" 2>/dev/null | grep -c . || true)"
  [ -z "$new_count" ] && new_count=0
  [ "$new_count" -eq 0 ] && continue

  merge="$(merge_outcome "$CURRENT" "$branch")"
  [ "$merge" = nothing ] && continue

  older=1; lane_is_today "$branch" && older=0
  conflict=0; [ "$merge" = conflict ] && conflict=1
  lines="$(git diff --numstat "$CURRENT...$branch" | awk '{ s += $1 + $2 } END { print s + 0 }')"
  behind="$(git rev-list --count "$branch..$CURRENT" 2>/dev/null || echo 0)"
  rows="$rows$older	$conflict	$lines	$short	$new_count	$behind	$merge	$(lane_age "$branch")
"
done < <(git worktree list --porcelain | awk '
  /^worktree / { path=$2 }
  /^branch /   { b=$2; sub("refs/heads/", "", b); print path "|" b }
')

sorted="$(printf '%s' "$rows" | sort -t '	' -k1,1n -k2,2n -k3,3n -k4,4)"

# print_section <heading> <0|1>: print the sorted rows with that 'older' flag.
print_section() {
  local section
  section="$(printf '%s\n' "$sorted" | awk -F '\t' -v o="$2" '$1 == o')"
  [ -z "$section" ] && return 0
  echo "  $1"
  printf "    %-30s %5s %7s %7s  %-9s %s\n" "LANE" "NEW" "LINES" "BEHIND" "MERGE" "LAST COMMIT"
  printf '%s\n' "$section" | while IFS='	' read -r _ _ lines short new behind merge age; do
    printf "    %-30s %5s %7s %7s  %-9s %s\n" "$short" "$new" "$lines" "$behind" "$merge" "$age"
  done
  echo
}

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
    print_section "Today:" 0
    print_section "Older:" 1
    echo "Run: lanes merge <lane>"
    echo "Or:  lanes next        # auto-merge the top one"
    ;;
  pick)
    if [ -z "$sorted" ]; then
      echo "No lanes have unintegrated commits. Nothing to recommend."
      exit 0
    fi
    IFS='	' read -r _ _ lines short new behind merge age <<<"$(printf '%s\n' "$sorted" | head -n1)"
    echo "Recommended next: $short"
    echo "  $new new commit(s), $lines line(s) changed, $behind behind $CURRENT, merge: $merge, last commit $age."
    echo "  (Ranking: today's lanes first, then clean merges, then smallest change. For nuance, run 'lanes monitor'.)"
    echo
    echo "Run: lanes merge $short"
    ;;
  name)
    if [ -z "$sorted" ]; then
      exit 0
    fi
    printf '%s\n' "$sorted" | head -n1 | cut -f4
    ;;
  *)
    echo "usage: integrate-next.sh [list|pick|name]" >&2
    exit 1
    ;;
esac
