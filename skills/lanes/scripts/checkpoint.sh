#!/usr/bin/env bash
set -euo pipefail

ONLY_STAGED=0
if [ "${1:-}" = "--only-staged" ]; then
  ONLY_STAGED=1
  shift
fi

MSG="${1:-}"

if [ -z "$MSG" ]; then
  echo "usage: checkpoint.sh [--only-staged] \"commit message\""
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current)"

cd "$ROOT"

if [ "$ONLY_STAGED" = "1" ]; then
  if ! git diff --cached --check; then
    echo "Diff check failed on staged content. Fix whitespace/conflict markers before committing."
    exit 1
  fi
else
  if ! git diff --check; then
    echo "Diff check failed. Fix whitespace/conflict markers before committing."
    exit 1
  fi
fi

if git diff --name-only --diff-filter=U | grep -q .; then
  echo "Unresolved merge conflicts present. Not committing."
  git diff --name-only --diff-filter=U
  exit 1
fi

if [ "$ONLY_STAGED" = "1" ]; then
  if git diff --cached --quiet; then
    echo "Nothing staged. Use 'git add' first, or omit --only-staged to checkpoint everything."
    exit 0
  fi
else
  if [ -z "$(git status --short)" ]; then
    echo "No changes to checkpoint on $BRANCH."
    exit 0
  fi

  # Stage tracked changes, then add untracked files while skipping character/block
  # devices. Bubblewrap-style sandboxes (e.g. Claude Code's) bind /dev/null over
  # protected paths inside their mount namespace, which surfaces as untracked
  # device-node entries that git refuses to add.
  git add -u
  while IFS= read -r f; do
    if [ -c "$f" ] || [ -b "$f" ]; then
      continue
    fi
    git add -- "$f"
  done < <(git ls-files --others --exclude-standard)
fi

git commit -m "$MSG"

echo
echo "Checkpoint created on $BRANCH"
echo
git --no-pager log --oneline -5
