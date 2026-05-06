# lanes

Run multiple Claude Code instances in parallel on the same repo, each in its own git worktree (a **lane**). This is the shell + slash-command layer that lets you start, watch, save, and merge them locally. Nothing here pushes to GitHub.

## Install

```
git clone git@github.com:tavinathanson/lanes.git ~/lanes
~/lanes/install.sh
```

That symlinks:

- `~/.local/bin/lanes` → `~/lanes/bin/lanes` (shell dispatcher; needs `~/.local/bin` on `PATH`)
- `~/.claude/skills/lanes` → `~/lanes/skills/lanes` (skill Claude reads)
- `~/.claude/commands/<name>.md` → `~/lanes/commands/<name>.md` (slash commands)

## Usage

```
lanes help
```

See [`skills/lanes/README.md`](skills/lanes/README.md) for the full cheat sheet.

## Layout

```
bin/lanes              shell dispatcher
skills/lanes/          Claude Code skill (SKILL.md + scripts)
commands/              slash command markdown
install.sh             symlink installer
```

## Uninstall

```
~/lanes/install.sh --uninstall
```

Removes the symlinks. The repo itself stays put.
