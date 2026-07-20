# Privacy notice

Effective: 19 July 2026

The app bundle includes Apple's `PrivacyInfo.xcprivacy` manifest. It declares
that Claude Island does not track users and does not collect data for the
developer or a third party.

Claude Island is designed as a local macOS application. The project does not
operate a Claude Island backend, analytics service, advertising service, or
telemetry collector. The pseudonymous maintainer can be contacted at
`686f6c61@00b.tech`.

## Data processed on the Mac

Claude Code hook events may contain session identifiers, working directories,
terminal identifiers, prompts, tool names and inputs, permission suggestions,
questions, notifications, and limited assistant activity. Claude Island uses
that data in memory to display activity and return decisions to the same hook
request.

The app stores the following in the current user's macOS defaults database:

- display and behavior preferences;
- selected terminal and favorite folder paths;
- up to 12 recent Claude session identifiers, project names, working
  directories, and update dates, retained for no more than 30 days;
- cached usage percentages, reset dates, and the last refresh date.

Current prompt text, tool inputs, permission requests, and answer text are not
intentionally persisted as session history by Claude Island. Claude Code and
terminal applications may keep their own records under their own policies.

The app also reads and may update `~/.claude/settings.json` and
`~/.claude/settings.local.json`, creates local backups before supported
changes, and installs its helper under the current user's Application Support
directory.

## Claude usage request

If usage display is enabled, Claude Island asks macOS Keychain for the existing
`Claude Code-credentials` item, extracts the OAuth access token in memory, and
sends it over HTTPS directly to `https://api.anthropic.com/api/oauth/usage`.
The app uses an ephemeral URL session, does not intentionally log the token,
and does not store the token in its preferences or project files.

Anthropic receives the request as the provider of that endpoint and processes
it under Anthropic's own terms and privacy notices. Claude Island is not an
Anthropic service.

## Updates

Sparkle may contact the GitHub Releases appcast configured in the app to check
for updates and download a selected release. GitHub and its infrastructure may
receive normal network metadata such as IP address, time, requested URL, and
user-agent information under their own policies. Update packages are expected
to be verified using Sparkle's configured EdDSA public key.

## What the project maintainer receives

The maintainer receives no app usage data automatically. If you email, submit
an issue, contribute code, or send a security report, the maintainer and the
relevant hosting or email providers receive the information you choose to
send. That material may be retained as needed to respond, maintain project
history, comply with law, and protect the project. Do not send secrets or
private Claude transcripts unless explicitly requested through a secure
channel.

## Controls and deletion

- Disable **Claude usage** to stop usage requests from Claude Island.
- Disable automatic update checks in Settings to stop scheduled appcast checks.
- Clear recent sessions from Settings.
- Remove favorite folders or reset app defaults from Settings.
- Uninstall hooks from Advanced Settings before deleting the application.
- macOS settings data can be removed after uninstalling the app, but doing so
  also removes user preferences.

This notice covers the native application and repository. A future website,
payment flow, hosted service, or commercial support operation must publish any
additional privacy terms before collecting data.
