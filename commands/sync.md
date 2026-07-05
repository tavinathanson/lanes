---
description: Sync the current lane branch with GitHub: pull with rebase, then push.
allowed-tools: Bash
---

Bring the current worktree's branch fully in sync with GitHub in one step.

Steps:

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`. If detached (`HEAD`), stop and report.
2. If the branch has an upstream, run `git pull --rebase` first.
   - If the rebase hits conflicts, stop immediately, report the conflicted files, and do NOT push. Do not resolve or abort without asking.
3. Push:
   - No upstream yet: `git push -u origin <branch>`.
   - Upstream exists: `git push`.
4. Report the net result: commits pulled, commits pushed, and the compare/PR URL if git prints one.

Rules:
- Operate only on the current branch.
- Never force-push. If the push is rejected, stop and report.
- Do not commit, amend, or merge lanes here. This only reconciles the current branch with its own remote.
