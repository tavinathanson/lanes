#!/usr/bin/env bash
# rename-lane.sh <slug>: give a timestamp-named lane (from a bare `lanes start`)
# a readable branch name, worktree-<slug>. Only the branch is renamed; the
# worktree dir keeps its timestamp because the live session runs inside it.
# A no-op unless the branch still has its timestamp name and was never pushed.
set -euo pipefail

SLUG="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-40)"
BRANCH="$(git branch --show-current)"

[ -n "$SLUG" ] || exit 0
[[ "$BRANCH" =~ ^worktree-lane-[0-9]{8}-[0-9]{6}$ ]] || exit 0
git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 && exit 0

NEW="worktree-$SLUG"
for n in 2 3 4 5 6 7 8 9; do
  git rev-parse --verify --quiet "refs/heads/$NEW" >/dev/null || break
  NEW="worktree-$SLUG-$n"
done
if git rev-parse --verify --quiet "refs/heads/$NEW" >/dev/null; then
  echo "Lane not renamed: worktree-$SLUG is taken."
  exit 0
fi

# A sandbox may block the follow-up .git/config write after the ref is renamed;
# that's harmless for an unpushed lane, so judge success by the branch itself.
git branch -m "$NEW" 2>/dev/null || [ "$(git branch --show-current)" = "$NEW" ] || {
  echo "Lane not renamed: git branch -m failed."
  exit 0
}
echo "Lane renamed: $BRANCH -> $NEW (lanes start ${NEW#worktree-} reopens it)"
