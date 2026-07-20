# Release security

This document defines the minimum security gate for a public Claude Island
binary. It supplements [RELEASING.md](../RELEASING.md).

## Release identities and secrets

- Use a valid Apple Developer ID Application identity for the main app and all
  executable nested code.
- Keep the Apple notarization profile and Sparkle EdDSA private key outside the
  repository, preferably in Keychain or protected CI secrets.
- Never print private keys, OAuth tokens, certificate exports, or notary
  credentials in build logs.
- Restrict release creation and secret access to the maintainer.
- Rotate and revoke compromised identities immediately and publish a security
  notice through an independent channel.

## Build gate

1. Confirm the release version, build number, BSL Licensed Work version, and
   Change Date are consistent.
2. Resolve dependencies only from `Package.resolved`; review any changed pin.
3. Run `swift test` from a clean source checkout.
4. Scan the source and release inputs for committed secrets.
5. Produce the SwiftPM dependency inventory and, when available, export a
   standards-compliant SPDX SBOM from GitHub's dependency graph.
6. Build the helper, nested framework code, and app deterministically where
   practical.
7. Sign nested code from the inside out with Hardened Runtime and a secure
   timestamp. Do not rely on `codesign --deep` to apply signatures.
8. Verify every nested signature and the top-level designated requirement.
9. Submit the archive to Apple notarization, review the returned log, staple
   the ticket, and validate the ticket.
10. Run Gatekeeper assessment on the final packaged artifact.
11. Generate the Sparkle appcast with the protected EdDSA key and verify its
    signature before upload.
12. Generate SHA-256 checksums for the final ZIP and appcast.
13. Confirm the final bundle includes `LICENSE`, privacy/safety notices, and
    complete third-party notices.

## Publication gate

- Use an immutable release tag matching the app version.
- Upload only artifacts produced by the approved release run.
- Protect the GitHub repository with strong authentication and branch/tag
  controls before the first public release.
- Publish release notes describing security-relevant changes and supported
  macOS/Claude Code versions.
- Test a fresh install and an update from the previous release on a non-
  development Mac profile.
- Retain the source revision, dependency lock, notary submission ID, checksums,
  and verification output for the release record.

## Current operational gap

The scripted gate is implemented, including explicit Sparkle nested signing,
mandatory Hardened Runtime and notarization, stapler and Gatekeeper validation,
signed-feed verification, a SwiftPM dependency inventory, and SHA-256 sums.

No Developer ID Application identity is currently configured for the first
public release. Binary publication therefore remains blocked until the
certificate is installed and the complete script succeeds against Apple's
notary service. Do not bypass this gate with an ad-hoc build. Source publication
and unsigned local development builds do not waive this binary release
requirement.
