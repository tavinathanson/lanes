---
description: Pull the current lane branch from GitHub with rebase.
allowed-tools: Bash
---

Update the current worktree's branch from its GitHub upstream, rebasing local commits on top.

Steps:

1. Determine the current branch: `git rev-parse --abbrev-ref HEAD`. If detached (`HEAD`), stop and report.
2. If the branch has no upstream (`git rev-parse --abbrev-ref @{u}` fails), stop and say there is nothing to pull from yet.
3. Run `git pull --rebase`.
4. Report what happened: how many commits were pulled, or "already up to date".

Rules:
- Always rebase, never merge-pull, so lane history stays linear.
- If the rebase hits conflicts, stop immediately and report the conflicted files. Do not resolve them automatically or run `git rebase --abort` without asking.
- Do not push here.
