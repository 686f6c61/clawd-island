# Contributing

Thank you for considering a contribution to Claude Island.

## Before opening a pull request

1. Discuss substantial changes in an issue first.
2. Do not include secrets, private Claude transcripts, credentials, customer
   data, or files copied from software whose license is incompatible.
3. Keep changes focused and preserve unrelated user configuration.
4. Run `swift test` and describe any manual macOS checks performed.
5. For security vulnerabilities, do not open a public issue or pull request;
   follow [SECURITY.md](SECURITY.md).

## Contributor License Agreement

Claude Island uses delayed Open Source and may offer alternative licenses.
Every contribution requires acceptance of [CLA.md](CLA.md) before merge so the
project can distribute the same contribution under the project license,
future Open Source terms, and alternative licenses.

Until an automated CLA check is configured, include this statement in the pull
request description:

> I have read and accept CLA.md for this contribution. My GitHub identity and
> the email attached to my commits identify my acceptance.

Maintainers must record that acceptance in the pull request. Contributions
without recorded acceptance will not be merged.

## Code quality

- Prefer Swift concurrency and Foundation APIs over shelling out.
- Validate data at trust boundaries and use bounded inputs.
- Preserve the safe fallback when the island is unavailable.
- Add tests for parsing, quoting, settings merges, and destructive operations.
- Document new network requests, persisted data, privileges, or third-party
  code in the relevant security and privacy documents.
- Keep `Package.resolved` committed and explain every dependency change.
- Do not add signing certificates, notarization responses, release keys or
  generated app bundles to a pull request.

CI runs on Apple Silicon and Intel macOS runners. A pull request is ready only
when tests, release builds, plist validation, dependency review and CodeQL pass.

By submitting a contribution you also agree that it is provided without an
obligation to compensate you or provide support, subject to the CLA.
