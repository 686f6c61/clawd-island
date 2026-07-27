# Changelog

All notable user-facing changes to Claude Island are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses semantic version tags for public releases.

## [0.2.0] - 2026-07-27

### Fixed

- Crash when no display screens are available during configuration changes.
- Island expanded panel now correctly accounts for the agent strip bottom padding (7px missing).
- AppleScript terminal launch no longer blocks the main thread (moved to background task).
- Settings change no longer destroys SwiftUI state (scroll, animations) by recreating the root view.
- VoiceOver accessibility restored for expanded island content.
- Running or waiting agents are no longer silently dropped when trimming to the 20-agent limit.
- Settings window title now updates correctly when pane is changed programmatically.
- Removed redundant main-actor dispatch for screen change notifications.

### Added

- Certificate pinning (SPKI SHA-256) for the Anthropic usage API endpoint.
- Secure deletion of the bridge token file (random data overwrite before removal).
- Directory permission hardening (`0o700`) on `~/.claude/` settings directory.
- Dependabot configuration for automated SwiftPM and GitHub Actions dependency updates.
- Shared `NotchEnvironment` observable object for consistent notch geometry across views.
- Throttle (2s) on recent-session writes to UserDefaults to reduce I/O during busy sessions.
- `IslandPalette` shared color palette, eliminating the duplicate `MenuPalette`.

### Changed

- `helperExecutableURL()` consolidated into `ClaudeIslandCore.HookBridgeCredential`, removing code duplication.
- Magic numbers in `IslandPanelLayout` replaced with named constants for clarity.
- `AppSettings` no longer performs 21 unnecessary UserDefaults writes during initialization.
- `objectWillChange` handler for settings now uses `debounce(for: .milliseconds(16))` to avoid stale value reads.
- `MenuPalette` removed; all menu colours use `IslandPalette` instead.

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

[0.2.0]: https://github.com/686f6c61/clawd-island/compare/v0.1.0-beta.1...v0.2.0
[Unreleased]: https://github.com/686f6c61/clawd-island/compare/v0.2.0...HEAD
[0.1.0-beta.1]: https://github.com/686f6c61/clawd-island/releases/tag/v0.1.0-beta.1
