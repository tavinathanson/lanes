#!/usr/bin/env bash
# resolve.sh [claude args]: when a 'lanes merge' stopped on a conflict, open
# Claude in this checkout with what it needs to finish the job: which lane,
# which commit, the conflicted files, what each side did to them, and the
# lane's handoff notes.
set -euo pipefail

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
GIT_DIR="$(git rev-parse --git-dir)"
CURRENT="$(git branch --show-current)"

if [ -f "$GIT_DIR/CHERRY_PICK_HEAD" ]; then
  OP=cherry-pick; HEAD_REF=CHERRY_PICK_HEAD
  FINISH="git add the resolved files, then run 'GIT_EDITOR=true git cherry-pick --continue'. If the next commit in the sequence conflicts too, resolve it the same way, until the cherry-pick is done."
elif [ -f "$GIT_DIR/MERGE_HEAD" ]; then
  OP=merge; HEAD_REF=MERGE_HEAD
  FINISH="git add the resolved files, then run 'git commit --no-edit' to finish the merge commit."
else
  echo "No merge or cherry-pick in progress on $CURRENT. Nothing to resolve."
  exit 0
fi

SHA="$(git rev-parse "$HEAD_REF")"
LANE="$(git branch --contains "$SHA" --format='%(refname:short)' | grep -m1 '^worktree-' || true)"
CONFLICTS="$(git diff --name-only --diff-filter=U)"
BASE="$(git merge-base HEAD "$SHA")"

section() { printf '\n## %s\n\n%s\n' "$1" "${2:-(none)}"; }

context="$(
  echo "# Finish a lanes integration that stopped on a conflict"
  echo
  echo "A 'lanes merge' of ${LANE:-an unknown lane} into $CURRENT stopped mid-$OP in $ROOT."
  section "Commit being applied" "$(git --no-pager log -1 --format='%h %s%n%n%b' "$SHA")"
  if [ -n "$LANE" ]; then
    section "Lane commits not yet on $CURRENT" \
      "$(unintegrated_shas "$CURRENT" "$LANE" | xargs -r -n1 git --no-pager log --oneline -1)"
    notes="$(lane_dir "$LANE")/.claude-lane-status.md"
    [ -f "$notes" ] && section "Lane handoff notes ($notes)" "$(cat "$notes")"
  fi
  [ -f "$GIT_DIR/sequencer/todo" ] && section "Commits still queued after this one" "$(cat "$GIT_DIR/sequencer/todo")"
  section "Conflicted files" "$CONFLICTS"
  if [ -n "$CONFLICTS" ]; then
    # shellcheck disable=SC2086
    section "$CURRENT commits touching them since the lane forked" \
      "$(git --no-pager log --oneline "$BASE..HEAD" -- $CONFLICTS)"
  fi
  cat <<EOF

## What to do

1. For each conflicted file, read both sides and the commits above to understand what each side meant to do. Keep both intents; never silently drop a change from either side.
2. If the two sides truly contradict and the right answer is a judgment call, stop and ask me instead of guessing.
3. Check the result builds or passes its quickest relevant test when that is obvious and fast.
4. Finish: $FINISH
5. Don't push, don't touch the lane's worktree, don't use /checkpoint or /wrap, and don't abort the $OP without asking.
6. When done, summarize how you resolved each file. If I was running 'lanes next-all', remind me to rerun it for the remaining lanes.
EOF
)"

exec claude "$@" "$context"
