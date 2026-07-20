# Safety and operational risk

Claude Island is a local control surface for Claude Code. It can display tool
activity, answer Claude Code questions and permission requests, edit selected
Claude Code settings, install hook commands, and launch terminal sessions.
Those capabilities can affect files, commands, and developer workflows.

## User responsibilities

- Review every requested command, path, permission, and answer before approving it.
- Treat **Bypass permissions** as unsafe outside an isolated environment.
- Keep current backups of repositories and important files.
- Inspect the backups Claude Island creates before removing them.
- Keep macOS, Claude Code, Claude Island, terminals, and dependencies updated.
- Do not use Claude Island as the sole control protecting production systems,
  credentials, regulated data, or safety-critical operations.

## Changes made by the app

Claude Island may:

- install `ClaudeIslandHook` under the current user's Application Support directory;
- merge hook handlers into `~/.claude/settings.json`;
- update permission defaults in `~/.claude/settings.json` and
  `~/.claude/settings.local.json` after an explicit Apply action;
- create timestamped backups before changing existing Claude settings;
- store preferences, favorite folders, recent session identifiers and paths,
  and cached usage percentages in the current user's defaults database;
- open terminal applications and invoke the locally installed `claude` command;
- contact Anthropic for usage information and GitHub for signed updates.

## Failure behavior

The hook helper is designed to exit successfully if the app is unavailable so
Claude Code can fall back to its normal terminal interaction. This fallback is
not a guarantee against data loss, interrupted work, incompatible Claude Code
changes, terminal failures, or defects in third-party services.

## Warranty

The software is provided on an "AS IS" basis to the extent allowed by law.
The controlling software license is in [LICENSE](LICENSE). The separate
[disclaimer and limitation of liability](DISCLAIMER.md) states the project's
position without modifying the standard BSL text. No safety notice or
disclaimer excludes liability that applicable law does not allow to be
excluded.
