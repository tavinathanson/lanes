---
description: Run /yolo then push to GitHub in one shot. Manual use only, for low-stakes repos where an unreviewed commit and push is acceptable.
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

Use the lanes skill.

Goal: commit the current lane's changes with an auto-written message (exactly like `/yolo`), then immediately push the branch to GitHub (exactly like `/push`). This is the only lanes command allowed to push without a separate user request, because the user invoking `/yolo-push` IS the push request.

This command is MANUAL-ONLY. It runs only when the user themselves typed `/yolo-push`. Never invoke it on your own initiative, never suggest running it for the user, and never treat its existence as permission to push in any other context. The user runs it deliberately, in repos they consider low-stakes.

Steps:

1. Do everything `/yolo` does: inspect the diff, draft a short plain commit message (one sentence by default, no `lane(...)` prefix, no `Co-Authored-By`), and commit immediately via `~/.claude/skills/lanes/scripts/checkpoint.sh "<message>"` without asking for confirmation. Follow `/yolo`'s split rules if the diff contains clearly unrelated concerns.
2. If there were no changes to commit, still continue to the push step if the branch is ahead of its upstream; otherwise say there is nothing to commit or push and stop.
3. Do everything `/push` does: determine the current branch (stop if detached), check for an upstream, then `git push -u origin <branch>` on first push or plain `git push` otherwise.
4. Report the commit message(s), `git log --oneline -5`, and the push result including the compare/PR URL if git prints one.

Rules:
- Push only the current branch. Never `--all`.
- Never force push. If the push is rejected as non-fast-forward, stop and report; do not force or `--force-with-lease`.
- Do not amend, merge, rebase, or squash.
- If checkpoint.sh refuses (conflicts, whitespace errors), report what it said and do not push.
