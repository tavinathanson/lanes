#!/usr/bin/env bash
# integrate-next.sh: rank lanes by integration safety.
#
# Modes:
#   list  (default): print a table of mergeable lanes, ranked safest first.
#   pick           : print the top recommendation's reasoning on stderr and
#                    its lane name on stdout (empty when there is none).
#   recent <hours> : print the names of lane worktrees (under .claude/worktrees/)
#                    whose last commit is within <hours>, ranked safest first
#                    (used by 'lanes next-all'). Other worktrees, like a
#                    release branch checkout, are never merged in bulk.
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

# analyze_lane <branch>: print one row for a lane worth integrating, or an
# empty line for a skipped one so the caller can count progress. Row fields
# (tab-separated): older conflict lines short new behind merge epoch age islane
# (islane is 1 for a Claude Code worktree under .claude/worktrees/).
analyze_lane() {
  local branch="$1" new_count merge older conflict lines behind islane
  # Cheap check first: a lane with no commits past $CURRENT needs no patch-ids.
  if [ "$(git rev-list --count "$CURRENT..$branch" 2>/dev/null || echo 0)" -eq 0 ]; then
    echo; return 0
  fi
  # Patch-id-aware count: matches what merge-lane.sh will see.
  new_count="$(unintegrated_shas "$CURRENT" "$branch" | grep -c . || true)"
  merge="$(merge_outcome "$CURRENT" "$branch")"
  if [ "${new_count:-0}" -eq 0 ] || [ "$merge" = nothing ]; then
    echo; return 0
  fi
  older=1; lane_is_today "$branch" && older=0
  conflict=0; [ "$merge" = conflict ] && conflict=1
  lines="$(git diff --numstat "$CURRENT...$branch" | awk '{ s += $1 + $2 } END { print s + 0 }')"
  behind="$(git rev-list --count "$branch..$CURRENT" 2>/dev/null || echo 0)"
  islane=0; [[ "$(lane_dir "$branch")" == */.claude/worktrees/* ]] && islane=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$older" "$conflict" "$lines" "${branch#worktree-}" \
    "$new_count" "$behind" "$merge" "$(git log -1 --format=%ct "$branch")" "$(lane_age "$branch")" "$islane"
}
export -f analyze_lane unintegrated_shas merge_outcome lane_is_today lane_age lane_dir
export CURRENT

# progress <total>: pass rows through, dropping blanks, and keep a live
# "Checking lanes n/total" counter on stderr when it is a terminal.
progress() {
  local i=0 line
  while IFS= read -r line; do
    i=$((i + 1))
    [ -t 2 ] && printf '\rChecking lanes... %d/%d' "$i" "$1" >&2
    [ -n "$line" ] && printf '%s\n' "$line"
  done
  [ -t 2 ] && printf '\r\033[K' >&2
  return 0
}

branches="$(git worktree list --porcelain | awk -v cur="refs/heads/$CURRENT" '
  /^branch / && $2 != cur { b=$2; sub("refs/heads/", "", b); print b }
')"
jobs="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
rows="$(printf '%s\n' "$branches" | grep . \
  | xargs -r -P "$jobs" -n1 bash -c 'analyze_lane "$1"' _ \
  | progress "$(printf '%s\n' "$branches" | grep -c . || true)" || true)"

sorted="$(printf '%s' "$rows" | sort -t '	' -k1,1n -k2,2n -k3,3n -k4,4)"

# print_section <heading> <0|1>: print the sorted rows with that 'older' flag.
print_section() {
  local section
  section="$(printf '%s\n' "$sorted" | awk -F '\t' -v o="$2" '$1 == o')"
  [ -z "$section" ] && return 0
  echo "  $1"
  printf "    %-30s %5s %7s %7s  %-9s %s\n" "LANE" "NEW" "LINES" "BEHIND" "MERGE" "LAST COMMIT"
  printf '%s\n' "$section" | while IFS='	' read -r _ _ lines short new behind merge _ age _; do
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
    echo "Or:  lanes next-all    # auto-merge every lane from the last 24 hours"
    ;;
  pick)
    [ -z "$sorted" ] && exit 0
    IFS='	' read -r _ _ lines short new behind merge _ age _ <<<"$(printf '%s\n' "$sorted" | head -n1)"
    {
      echo "Recommended next: $short"
      echo "  $new new commit(s), $lines line(s) changed, $behind behind $CURRENT, merge: $merge, last commit $age."
      echo "  (Ranking: today's lanes first, then clean merges, then smallest change. For nuance, run 'lanes monitor'.)"
    } >&2
    echo "$short"
    ;;
  recent)
    hours="${2:-24}"
    cutoff=$(( $(date +%s) - hours * 3600 ))
    printf '%s\n' "$sorted" | awk -F '\t' -v c="$cutoff" '$10 == 1 && $8 >= c { print $4 }'
    ;;
  *)
    echo "usage: integrate-next.sh [list|pick|recent <hours>]" >&2
    exit 1
    ;;
esac
