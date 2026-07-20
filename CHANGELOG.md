# Changelog

All notable user-facing changes to Claude Island are documented here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project uses semantic version tags for public releases.

## [Unreleased]

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
  signed responses for the local hook bridge before the first public release.
- Added bounded request parsing, private support-directory permissions and
  helper integrity verification.
- Added mandatory Developer ID signing, Hardened Runtime, notarization,
  stapling, Gatekeeper assessment and signed-feed verification to the public
  release gate.

[Unreleased]: https://github.com/686f6c61/clawd-island/commits/main
