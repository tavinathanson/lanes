---
description: Push the current lane branch to GitHub, setting upstream on first push.
allowed-tools: Bash
---

Push the current worktree's branch to GitHub.

Steps:

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`.
   - If it is `HEAD` (detached), stop and report; there is nothing to push.
2. Check whether the branch has an upstream: `git rev-parse --abbrev-ref --symbolic-full-name @{u}` (non-zero exit means no upstream yet).
3. Push:
   - No upstream yet: `git push -u origin <branch>`.
   - Upstream exists: `git push`.
4. Report the result: the branch pushed, and the compare/PR URL if git prints one.

Rules:
- Push only the current branch. Never `--all`.
- Never force. If the push is rejected as non-fast-forward, stop and report; do not force or `--force-with-lease` unless the user explicitly asks.
- Do not commit, amend, merge, or rebase here. This command only pushes what is already committed.
