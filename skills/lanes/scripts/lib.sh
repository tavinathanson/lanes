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
                   if (!found && (nb==n || b==n)) { print b; found=1 }
                 }
  ')"
  if [ -n "$match" ]; then
    echo "$match"; return 0
  fi
  return 1
}

# lane_dir <branch>: echo the worktree path checked out on <branch>, if any.
# Reads git's whole output on purpose: quitting early (awk exit, head) can kill
# git with SIGPIPE, which pipefail turns into a silent exit under set -e.
lane_dir() {
  git worktree list --porcelain | awk -v b="refs/heads/$1" '
    /^worktree / { p=substr($0, 10) }
    $0 == "branch " b { print p }
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

# merge_in_progress: return 0 when a merge or cherry-pick stopped partway in
# this checkout (what 'lanes resolve' picks up).
merge_in_progress() {
  local d
  d="$(git rev-parse --git-dir)"
  [ -f "$d/CHERRY_PICK_HEAD" ] || [ -f "$d/MERGE_HEAD" ]
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

# dirty_summary <worktree path>: echo a short note on uncommitted work there
# ("2 modified, 1 untracked"), or nothing when the tree is clean.
dirty_summary() {
  git -C "$1" status --porcelain 2>/dev/null | awk '
    /^\?\?/ { u++; next } { m++ }
    END { s = ""
          if (m) s = m " modified"
          if (u) s = s (s ? ", " : "") u " untracked"
          if (s) print s }'
}

# dirty_lanes [skip branch]: echo "short<TAB>summary" for every worktree with
# uncommitted work, except the one on <skip branch>.
dirty_lanes() {
  local path branch summary
  git worktree list --porcelain | awk '
    /^worktree / { p=substr($0, 10) }
    /^branch /   { b=$2; sub("refs/heads/", "", b); print p "\t" b }
  ' | while IFS='	' read -r path branch; do
    [ "$branch" = "${1:-}" ] && continue
    summary="$(dirty_summary "$path")"
    [ -n "$summary" ] && printf '%s\t%s\n' "${branch#worktree-}" "$summary"
  done
  return 0
}

# warn_if_dirty <branch>: print a heads-up when that lane's worktree has
# uncommitted work, which merging or archiving the lane would leave behind.
warn_if_dirty() {
  local dir summary
  dir="$(lane_dir "$1")"
  [ -n "$dir" ] || return 0
  summary="$(dirty_summary "$dir")"
  [ -n "$summary" ] || return 0
  echo "Heads up: ${1#worktree-} has uncommitted work ($summary). Only commits"
  echo "  count here; run /wrap in that lane so it isn't left behind."
  echo
}
