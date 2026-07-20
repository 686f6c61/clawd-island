# Security policy

Security reports are welcome and should be handled privately.

## Supported versions

| Version | Security support |
| --- | --- |
| Latest published release | Supported on a best-effort basis |
| Older releases | Not normally supported |
| Development builds | No support guarantee |

An advisory may identify a different affected or fixed version range.

## Reporting a vulnerability

When the public repository is available, prefer GitHub's private vulnerability
reporting feature. Until then, or if that feature is unavailable, email
`686f6c61@00b.tech` with the subject prefix `[SECURITY]`.

Include, where possible:

- affected version and macOS version;
- impact and realistic attack scenario;
- exact reproduction steps or a minimal proof of concept;
- whether credentials, prompts, files, permissions, or update integrity are affected;
- suggested remediation and any intended disclosure date;
- a safe way to contact you for follow-up.

Do not include live credentials, private transcripts, personal data, or a
destructive payload. Use synthetic data and redact secrets.

## Coordinated disclosure

The maintainer will try to acknowledge a complete report within seven days,
triage it within fourteen days, and provide status updates when practical.
These are targets, not contractual response times or an SLA.

Please allow a reasonable remediation period before public disclosure. The
maintainer may create a private advisory, develop and test a fix, request a CVE,
publish a signed release, and then credit the reporter if requested. Public
disclosure may occur earlier when exploitation is active or users need an
immediate mitigation.

## Scope priorities

Reports are especially valuable when they concern:

- unauthorized approval or modification of Claude Code hook decisions;
- disclosure of OAuth credentials, prompts, commands, paths, or transcripts;
- local bridge impersonation, request forgery, or denial of service;
- command, AppleScript, URL, YAML, or path injection;
- unsafe writes to Claude settings or hook executables;
- update signature, appcast, code-signing, or notarization bypasses;
- privilege escalation or persistence beyond documented app behavior.

Ordinary bugs, expected behavior of Claude Code or macOS, social engineering
without a product defect, and vulnerabilities requiring a previously fully
compromised user account may be out of scope or lower priority.

## Safe-harbor intent

Good-faith research that avoids privacy violations, service disruption,
destructive testing, persistence, and access beyond what is necessary to
demonstrate the issue will not be treated as malicious by the Project. This is
an expression of project policy, not authorization to violate third-party
terms or applicable law. No bug bounty is currently offered.

## Current security documentation

- [Security architecture](docs/SECURITY-ARCHITECTURE.md)
- [Threat model](docs/THREAT-MODEL.md)
- [Release security](docs/RELEASE-SECURITY.md)

Detailed vulnerability reports and reproductions are not committed before
coordinated disclosure. Published advisories are available from the
repository's Security tab.
