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

# lane_adds_nothing <current> <lane> — return 0 (true) when integrating <lane>
# into <current> would not change <current> at all: a clean 3-way merge whose
# result tree is byte-identical to <current>'s tree. This is merge-base aware,
# so it catches lanes that are fully superseded even when the patch-id check
# (git rev-list --cherry-pick) still flags a commit because a conflict
# resolution changed its patch.
#
# Deliberately conservative: any merge conflict, or any net change, returns 1
# (false). Needs git >= 2.38 for `merge-tree --write-tree`; on older git or any
# error it returns 1, falling back to the existing behavior (lane stays shown).
lane_adds_nothing() {
  local current="$1" lane="$2" merged base_tree
  merged="$(git merge-tree --write-tree "$current" "$lane" 2>/dev/null)" || return 1
  base_tree="$(git rev-parse --verify --quiet "$current^{tree}")" || return 1
  [ "$merged" = "$base_tree" ]
}
