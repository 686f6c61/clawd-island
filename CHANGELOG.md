# Changelog

All notable user-facing changes to Claude Island are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses semantic version tags for public releases.

## [Unreleased]

### Fixed

- Display reconfiguration no longer creates an invalid fallback screen; the
  Island hides safely and returns when a display becomes available.
- Concurrent Claude sessions are retained in memory while recent-session disk
  writes are coalesced, so one busy terminal no longer hides another.
- Agent history is capped at exactly 20 entries while prioritising agents that
  are waiting or still running.
- Opening Terminal or iTerm2 no longer blocks the app's main thread.
- Settings and display changes preserve SwiftUI view state instead of
  rebuilding the Island root view.
- Expanded layouts include the missing spacing below the agent strip.
- Settings window titles stay in sync with programmatic pane changes.
- Expanded controls and the hidden Island expose usable default VoiceOver
  actions.

### Changed

- Display geometry now flows through one stable observable state shared by the
  live Island and appearance preview.
- Island and menu status colours use one shared palette.
- Hook helper discovery is centralised and rejects non-executable helpers.
- Panel layout measurements use named constants and settings updates are
  coalesced before recalculating the frame.
- Added focused app-level tests for display layout, agent retention, concurrent
  session history and asynchronous terminal activation.

## [0.1.0-beta.1] - 2026-07-22

### Added

- Native notch and top-edge Island for Claude Code activity.
- Multi-session and nested-subagent monitoring.
- Permission and question responses from the Island.
- Ghostty, Terminal, iTerm2 and Warp session launching and resuming.
- Claude usage display, configurable idle hiding and Clawd/Clawdia mascot sets.
- Native Settings, diagnostics, hook repair and Sparkle update controls.

### Changed

- Public release automation now builds and validates universal app and hook
  binaries from a clean per-version staging directory.
- GitHub publication metadata, contribution templates and CI were added.

### Security

- Added mutual HMAC authentication, freshness checks, replay rejection and
  signed responses for the local hook bridge before the public beta.
- Added bounded request parsing, private support-directory permissions and
  helper integrity verification.
- Added mandatory Developer ID signing, Hardened Runtime, notarization,
  stapling, Gatekeeper assessment and signed-feed verification to the public
  release gate.

[Unreleased]: https://github.com/686f6c61/clawd-island/compare/v0.1.0-beta.1...HEAD
[0.1.0-beta.1]: https://github.com/686f6c61/clawd-island/releases/tag/v0.1.0-beta.1
