#!/usr/bin/env bash
# lib.sh — shared helpers for lanes scripts. Source this; don't execute it.

# resolve_lane <name> — echo the branch name for a lane referred to by short
# name ("esc"), branch name ("worktree-esc"), or worktree dir. Returns 1 if no
# match. Resolution order: exact branch, worktree-<name> branch, then a scan of
# `git worktree list` matching either the dir basename or the branch.
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

# lane_dir <branch>: echo the worktree path checked out on <branch>, if any.
lane_dir() {
  git worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree / { p=substr($0, 10) }
    $0 == "branch " b { print p; exit }
  '
}

# unintegrated_shas <current> <lane>: echo, oldest first, the lane commits not
# yet on <current>. Patch-id aware (--cherry-pick), and also drops a commit
# that was cherry-picked with a conflict resolution: that changes its patch-id
# but keeps its author timestamp and subject, which must already be on <current>.
unintegrated_shas() {
  git log --cherry-pick --right-only --no-merges --reverse --format='%H%x09%at %s' "$1...$2" 2>/dev/null \
    | awk -F '\t' 'FILENAME != "-" { landed[$0] = 1; next } !($2 in landed) { print $1 }' \
        <(git log --no-merges --format='%at %s' "$2..$1" 2>/dev/null) -
}

# merge_outcome <current> <lane>: echo what a real 3-way merge of <lane> into
# <current> would do, without touching the working tree:
#   nothing   clean, and the result is byte-identical to <current> (a fully
#             superseded lane, even when a conflict resolution changed a
#             commit's patch-id so `git rev-list --cherry-pick` still flags it)
#   clean     clean, with real changes
#   conflict  the merge would conflict
#   unknown   git < 2.38 (no `merge-tree --write-tree`) or another error
merge_outcome() {
  local current="$1" lane="$2" merged rc=0
  merged="$(git merge-tree --write-tree "$current" "$lane" 2>/dev/null)" || rc=$?
  case "$rc" in
    0) if [ "$merged" = "$(git rev-parse --verify --quiet "$current^{tree}")" ]; then
         echo nothing
       else
         echo clean
       fi ;;
    1) echo conflict ;;
    *) echo unknown ;;
  esac
}

# lane_adds_nothing <current> <lane>: return 0 (true) when integrating <lane>
# would not change <current> at all. Conservative: a conflict, any net change,
# or an unknown outcome returns 1, so the lane stays shown.
lane_adds_nothing() {
  [ "$(merge_outcome "$1" "$2")" = nothing ]
}

# lane_is_today <branch>: return 0 when the branch tip was committed today
# (local time). Used to tell current work apart from stale lanes.
lane_is_today() {
  [ "$(git log -1 --format=%cd --date=format-local:%Y-%m-%d "$1")" = "$(date +%Y-%m-%d)" ]
}

# lane_age <branch>: echo how long ago the branch tip was committed ("3 days ago").
lane_age() {
  git log -1 --format=%cr "$1"
}

# archived_branches: echo every branch marked with 'lanes archive', one per line.
# The flag lives in local git config (branch.<name>.lanesArchived), so the
# worktree and branch stay untouched.
archived_branches() {
  { git config --get-regexp '^branch\..*\.lanesarchived$' 2>/dev/null || true; } \
    | awk '$2 == "true" { k=$1; sub(/^branch\./, "", k); sub(/\.lanesarchived$/, "", k); print k }'
}
