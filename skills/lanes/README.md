# lanes (skill)

Run multiple Claude Code instances in parallel on the same repo, each in its own git worktree (a **lane**). This skill helps you start, watch, save, and integrate them locally. Nothing here pushes to GitHub.

## The one thing to remember

```
lanes help
```

That prints the full cheat sheet. Below is the same thing organized by what you're trying to do.

## Two surfaces, one rule of thumb

- **CLI (`lanes ...`)** — orchestrates *across* lanes. Run from your main worktree shell.
- **Slash commands (`/...`)** — mutate the *current* lane. Run from inside a Claude Code lane.

Anything that looks at multiple lanes (status, logs, integration) lives in the CLI. Anything that commits to the lane you're in lives in slash commands.

## Lane names: short name vs branch

Refer to a lane by its **short name** — the worktree directory name (e.g. `esc`, `feat-auth`). That's what you type into every command here.

The underlying git branch is `worktree-<name>` (Claude Code's `--worktree` flag picks that prefix; we don't control it). You'll see the branch in `git log` and in `lanes monitor` output rendered as:

```
Lane: esc    (branch: worktree-esc)
```

Tooling accepts either form, so don't worry about it.

## Workflow at a glance

### 1. Start a lane (from the main worktree, in your shell)

```
lanes start feat-auth         # launches Claude Code in worktree "feat-auth"
```

### 2. Work inside the lane (slash commands inside Claude)

| Want to... | Use |
| --- | --- |
| Save progress, you write the message | `/checkpoint added validation` |
| Save progress, Claude writes the message | `/wrap` |
| Update human-readable handoff notes | `/handoff` |

### 3. Look around (from your main worktree shell)

| Want to... | Use |
| --- | --- |
| Status + overlap across all lanes | `lanes monitor` |
| Commit history for all lanes | `lanes log` |
| List worktrees/branches | `lanes list` |
| Detail view of one lane | `lanes inspect feat-auth` |

### 4. Bring a lane home (from your main worktree shell)

| Want to... | Use |
| --- | --- |
| See lanes with commits to integrate | `lanes merge` |
| Integrate the safest lane automatically | `lanes next` (or `lanes merge next`) |
| Integrate a specific lane | `lanes merge feat-auth` |

`lanes merge` picks the integration mode automatically based on how many *unintegrated* commits the lane has (patch-id aware, so re-integrating a lane after more work counts only the new commits):

- **1-2 new commits** → cherry-pick (linear history, no merge commit even when target moved).
- **3+ new commits** → `git merge --ff` (fast-forward when possible; one merge commit only if the target moved since the lane forked).

It refuses if your working tree is dirty. It does not push, squash, or delete the lane.

## When-to-use cheat sheet

- **Just want to save state?** `/wrap` (lazy) or `/checkpoint <msg>` (you write it).
- **About to step away?** `/handoff` writes a markdown summary other lanes can read.
- **Curious what other lanes are doing?** `lanes monitor`.
- **Ready to integrate?** `lanes merge` to see options, `lanes next` to auto-merge the safest, or `lanes merge <name>` for a specific lane.
- **Forgot everything?** `lanes help`.

## Files

- `bin/lanes` — shell dispatcher (symlinked into `~/.local/bin/lanes`).
- `commands/*.md` — slash commands (symlinked into `~/.claude/commands/`). Lane-internal only: `checkpoint`, `wrap`, `handoff`.
- `skills/lanes/scripts/*.sh` — underlying scripts the CLI calls.
- `skills/lanes/SKILL.md` — instructions Claude follows when coordinating lanes.

## Safety

The skill never pushes to GitHub, never squashes, never deletes worktrees or branches without you saying so. Integration is local only.
