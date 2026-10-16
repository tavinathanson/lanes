#!/usr/bin/env bash
# open-lane.sh [lane]: echo the worktree dir of an existing lane for 'lanes open'.
# With no name, list lanes (most recent first) and ask which one. Never creates
# a lane: an unknown name fails with the lanes it might have meant.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# lane_rows: "short<TAB>branch<TAB>dir" for every lane worktree, newest tip first.
# Skips the main checkout (always listed first by git).
lane_rows() {
  git worktree list --porcelain | awk '
    /^worktree / { p=substr($0, 10); n++ }
    /^branch /   { b=$2; sub("refs/heads/", "", b); if (n > 1) print p "\t" b }
  ' | while IFS='	' read -r dir branch; do
    printf '%s\t%s\t%s\t%s\n' "$(git log -1 --format=%ct "$branch")" "${branch#worktree-}" "$branch" "$dir"
  done | sort -rn | cut -f2-
}

# show_rows: print rows numbered, with age and any uncommitted work, to stderr.
show_rows() {
  local i=0 short branch dir dirty
  while IFS='	' read -r short branch dir; do
    i=$((i + 1))
    dirty="$(dirty_summary "$dir")"
    printf '  %2d) %-28s %s%s\n' "$i" "$short" "$(lane_age "$branch")" "${dirty:+  ($dirty)}" >&2
  done
}

rows="$(lane_rows)"
[ -n "$rows" ] || { echo "No lanes yet. Start one with 'lanes start <lane>'." >&2; exit 1; }

name="${1:-}"
if [ -n "$name" ]; then
  dir="$(lane_dir "$(resolve_lane "$name" || true)")"
  if [[ "$dir" == */.claude/worktrees/* ]]; then echo "$dir"; exit 0; fi
  # Close = the name appears in a lane's name or branch, ignoring case and punctuation.
  close="$(printf '%s\n' "$rows" | awk -F '\t' -v n="$name" '
    function norm(s) { s = tolower(s); gsub(/[^a-z0-9]/, "", s); return s }
    index(norm($1), norm(n)) || index(norm($2), norm(n))')"
  echo "No lane named '$name'. ('lanes start $name' creates one.)" >&2
  if [ -n "$close" ]; then echo "Did you mean:" >&2; rows="$close"; else echo "Lanes:" >&2; fi
  printf '%s\n' "$rows" | show_rows
  exit 1
fi

echo "Lanes, most recent first:" >&2
printf '%s\n' "$rows" | show_rows
[ -t 0 ] || { echo "Run 'lanes open <lane>'." >&2; exit 1; }
read -r -p "Open which? " pick
[[ "$pick" =~ ^[0-9]+$ ]] || { echo "Nothing opened." >&2; exit 1; }
dir="$(printf '%s\n' "$rows" | sed -n "${pick}p" | cut -f3)"
[ -n "$dir" ] || { echo "No lane $pick." >&2; exit 1; }
echo "$dir"
