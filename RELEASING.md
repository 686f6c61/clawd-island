# Releasing Claude Island

Claude Island is distributed through GitHub Releases and Sparkle. It is not a
Mac App Store build because it installs Claude Code hooks in the user's home
directory, launches terminal applications, and uses an external updater.

The repository is `686f6c61/clawd-island`; the product and app bundle remain
named **Claude Island**.

## One-time setup

1. Install a valid Developer ID Application certificate.
2. Store Apple notarization credentials in a named `notarytool` Keychain
   profile.
3. Keep the Sparkle EdDSA private key in Keychain. Never commit or print it.
4. Protect `main` and release tags, enable private vulnerability reporting,
   secret scanning and immutable releases on GitHub.

## Release gate

Before packaging:

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in
   `Resources/Info.plist`.
2. Add the version and date to `CHANGELOG.md`.
3. Update the BSL `Licensed Work` version and `Change Date` in `LICENSE`.
4. Review `THIRD_PARTY_NOTICES.md` and `Package.resolved`.
5. Complete [docs/RELEASE-SECURITY.md](docs/RELEASE-SECURITY.md).
6. Run the full test and universal packaging checks from a clean checkout.

## Build the release

```zsh
CLAUDE_ISLAND_SIGN_IDENTITY="Developer ID Application: YOUR NAME (TEAMID)" \
CLAUDE_ISLAND_NOTARY_PROFILE="clawd-island-notary" \
./scripts/package-release.sh
```

The script refuses ad-hoc signing, requires notarization and writes public
assets to `dist/vVERSION/`. Notarization response data is retained privately
under `.build/release-evidence/`.

## Publish safely

Create a draft first so every asset can be attached before immutable release
protection takes effect:

```zsh
VERSION="0.1.0"
TAG="v${VERSION}"
OUTPUT_DIR="dist/${TAG}"

gh release create "$TAG" \
  "$OUTPUT_DIR/Claude-Island-${TAG}.zip" \
  "$OUTPUT_DIR/appcast.xml" \
  "$OUTPUT_DIR/SHA256SUMS" \
  "$OUTPUT_DIR/Claude-Island-${TAG}-swiftpm-dependencies.json" \
  --repo 686f6c61/clawd-island \
  --title "Claude Island ${VERSION}" \
  --notes-file "$OUTPUT_DIR/Claude-Island-${TAG}.md" \
  --draft
```

Before publishing the draft:

- verify the tag points to the intended signed commit;
- download the draft assets and compare SHA-256 values;
- retain the Apple notarization submission ID privately;
- test a fresh install on a non-development macOS account;
- for later versions, test a Sparkle upgrade from the previous release.

The app reads `appcast.xml` from the latest published GitHub Release. Sparkle
verifies its EdDSA signature and the downloaded archive before installation.

## CI policy

Pull-request CI never receives signing, notarization, Apple or Sparkle secrets.
The first releases are prepared on a trusted maintainer Mac. A future automated
release workflow may use a protected GitHub Environment with manual approval,
but it must preserve the same gate and must not run on untrusted pull-request
code.
