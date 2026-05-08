# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-27

### Added
- Security pitfalls checklist (S1–S15 taxonomy) injected into every review prompt as mandatory context. Captures recurring themes seen across enterprise web services: AllowAnonymous endpoints, authorization fail-open (audit-only modes, empty allow-lists), IDOR, client-spoofable identity and rate-limit keys, dev/sandbox shortcuts in production, frontend SPA hazards, secret/PII leakage in logs and metrics, debug/diagnostics in production, IaC deployment-output secret leakage and over-privileged identities, network/WAF misconfiguration, cryptographic misuse, cert/TLS validation disabled, path/command/SSRF injection, and supply-chain/dev-tooling pitfalls.
- Two-pass review procedure: explicit security pass (S1–S15) before the convention pass.
- Security findings tagged `[S#]` and labeled ACTIVE vs LATENT.
- Block-on-CRITICAL merge gate: any unmitigated CRITICAL S-finding forces "Request Changes / Block".

## [1.0.0] - 2026-04-08

### Added
- Multi-model code review using Copilot CLI (GPT 5.5 + Claude Opus 4.7)
- LENS context injection from CLAUDE.md + .claude/rules/*.md
- Two input modes: ADO PR number/URL or local git diff
- Runtime Copilot CLI detection (copilot vs agency copilot)
- LENS conventions cheat sheet with 15 org-wide rules + repo-specific overrides
- Cross-model agreement scoring and finding deduplication
- False positive avoidance rules for LENS-specific patterns
- Priority matrix separating LENS violations from style preferences
- Optional fix application with build/test verification
- Always-loaded review-conventions rule for .cs/.tsx/.ts/.bicep files
