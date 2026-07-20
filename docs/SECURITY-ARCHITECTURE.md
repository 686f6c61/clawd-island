# Security architecture

Last reviewed: 20 July 2026

## Scope and deployment assumptions

Claude Island is a single-user native macOS application built with Swift,
SwiftUI, AppKit, Network.framework, WebKit, and Sparkle. It is intended for
direct distribution outside the Mac App Store. There is no project-operated
cloud backend, account system, telemetry pipeline, or multi-tenant service.

The expected environment is one interactive macOS user running Claude Code
and one or more supported terminal applications. A managed enterprise
deployment, shared macOS account, remote desktop service, or future website
backend would require a new review.

## Primary components

| Component | Responsibility | Security relevance | Evidence |
| --- | --- | --- | --- |
| `ClaudeIsland` app | Island UI, settings, sessions, decisions, usage and updates | Handles prompts, tool activity, permission decisions, paths and cached metadata | `Sources/ClaudeIsland/AppMain.swift`, `IslandStore.swift` |
| `HookServer` | Mutually authenticated loopback listener on TCP port 47835 | Main runtime trust boundary; verifies HMAC request proofs, freshness and replay before accepting events | `Sources/ClaudeIsland/HookServer.swift`, `Sources/ClaudeIslandCore/HookBridgeAuthentication.swift` |
| `ClaudeIslandHook` | Reads Claude Code hook JSON from stdin and forwards it to the app | Carries sensitive hook input and returns decisions to Claude Code | `Sources/ClaudeIslandHook/ClaudeIslandHookMain.swift` |
| Settings managers | Merge hooks and permission settings with backups | Writes integrity-sensitive files under `~/.claude` | `Sources/ClaudeIslandCore/HookSettingsInstaller.swift`, `ClaudeSettingsManager.swift` |
| Terminal activator | Starts or resumes Claude sessions | Constructs shell, AppleScript, YAML and URL inputs | `Sources/ClaudeIsland/TerminalActivator.swift`, `ClaudeTerminalCommand.swift` |
| Usage client | Reads Claude Code OAuth credentials and calls Anthropic | Handles a bearer token in memory | `Sources/ClaudeIsland/ClaudeUsageClient.swift` |
| Sparkle updater | Checks and applies releases | Executes distributed code after feed and signature validation | `Sources/ClaudeIsland/UpdateController.swift`, `Resources/Info.plist` |
| Mascot renderer | Loads bundled SVG into a non-persistent WKWebView | Embedded browser surface, currently limited to bundled resources | `Sources/ClaudeIsland/ClawdStateView.swift` |
| Release scripts | Build, sign, notarize, package and generate appcast | Software supply-chain boundary | `scripts/build-app.sh`, `scripts/package-release.sh` |

## Runtime data flows

1. **Claude Code → hook helper:** Claude Code writes hook JSON to the helper's
   standard input. It may include prompts, commands, paths, questions,
   permission suggestions, and session identifiers.
2. **Hook helper → local bridge:** the helper adds terminal context and sends an
   HTTP POST to `127.0.0.1:47835/hook`. It signs the method, path, timestamp,
   random nonce and body digest with a private per-install HMAC key. The key is
   never transmitted. The app rejects stale, replayed, malformed and
   browser-origin requests.
3. **Local bridge → island state:** the app decodes JSON and retains up to 20
   activity items per active session in memory. Permission requests and
   questions remain pending until answered or the session ends.
4. **User → Claude Code:** an approval, denial, or answer is encoded as hook
   output and returned on the original HTTP connection, then printed by the
   helper to stdout.
5. **App ↔ local files:** the app reads and atomically writes selected Claude
   settings, stores a helper executable, and creates backups before supported
   settings changes.
6. **App → terminal:** user-selected folder paths and session identifiers are
   quoted and passed to Ghostty, Terminal, iTerm2, or Warp.
7. **App → Anthropic:** if enabled, an OAuth access token obtained from Keychain
   is sent over HTTPS to Anthropic's usage endpoint. Only percentages and reset
   dates are cached.
8. **App → GitHub/Sparkle:** Sparkle reads the HTTPS appcast and verifies update
   signatures using the configured EdDSA public key before installation.

## Stored data

| Location | Data | Protection and retention |
| --- | --- | --- |
| macOS Keychain | Claude Code OAuth credential owned by Claude Code | Read on demand through Security.framework after Claude activity; background checks suppress authentication UI and the token is not intentionally persisted by Claude Island |
| `UserDefaults` | UI preferences, favorite paths, recent session ID/path/name/date, cached usage windows | Current-user storage; clear/reset controls exist; no additional encryption |
| `~/.claude` | Claude settings and timestamped backups | Current-user filesystem permissions; writes use atomic replacement where implemented |
| Application Support | Copied hook helper and Warp launch YAML | Current-user filesystem permissions; helper is executable |
| App bundle | Binaries, Sparkle, SVG assets, legal notices | Expected to be Developer ID signed and notarized for public releases |

## Existing controls

- The listener is bound explicitly to `127.0.0.1` and rejects non-loopback
  peer endpoints.
- The helper and app mutually authenticate each exchange with HMAC-SHA256. A
  256-bit nonce and 30-second freshness window bind each request; accepted
  nonces are retained briefly to reject replay. Responses are signed over the
  request nonce, HTTP status and body digest before the helper accepts them.
- Hook failure is fail-open to Claude Code's ordinary terminal interaction;
  absence of the app does not intentionally auto-approve a request.
- JSON is decoded with `JSONDecoder`/`JSONSerialization`; invalid events receive
  an empty response.
- Settings changes create backups and use atomic writes.
- Terminal directory and resume values use shell quoting; dedicated tests cover
  quoting behavior.
- The usage client uses an ephemeral URL session, HTTPS, timeouts, a response
  size limit for credentials, and no intentional token logging.
- Sparkle is pinned to version 2.9.4 and the app contains an EdDSA public key.
- Mascot WebViews use a non-persistent data store and load only bundled SVGs.

## Known gaps and security decisions

The loopback bridge no longer trusts network location alone. It uses a private
per-install secret for bidirectional request and response authentication, so a
process that pre-binds port 47835 cannot recover the secret or forge an accepted
response. A same-user process able to read the mode `0600` credential or alter
the installed helper remains outside this control's protection. A
code-identity-aware XPC service or another macOS identity-aware IPC mechanism
should be evaluated as a future hardening layer.

The HTTP parser bounds headers, bodies and total request size; validates method,
path and content type; rejects duplicate/transfer-encoded headers and browser
origins. Global connection concurrency, read deadlines and pending-request
queue limits remain possible availability hardening.

The app is not sandboxed. Its documented features require access to Claude
settings, Application Support, Keychain, terminal applications, and local
process execution. Hardened Runtime and notarization remain required for
public distribution; sandbox feasibility should be reassessed if architecture
changes.

## Security ownership

Security reports go to `686f6c61@00b.tech` with subject prefix `[SECURITY]` or
through GitHub private vulnerability reporting when available. See
[SECURITY.md](../SECURITY.md).
