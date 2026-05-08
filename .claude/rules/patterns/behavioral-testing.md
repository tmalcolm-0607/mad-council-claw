> **Kit-policy supplement; canonical LENS does not prescribe.** Behavioral testing patterns archived to `.mad/docs/non-lens-extras/behavioral-testing.md` (kit-extra, not LENS-canonical).

# Behavioral Testing (archived)

The previous content of this file (947 lines covering RFC 7807 ProblemDetails assertions, state-machine matrix tooling, Playwright frontend, AI-validator mock patterns) has been moved out of the kit's prescriptive surface to `.mad/docs/non-lens-extras/behavioral-testing.md`. That content is preserved for reference but is **not** LENS-canonical:

- RFC 7807 ProblemDetails conflicts with the canonical `{ error, correlationId }` envelope.
- State-machine matrix tooling is consumer-project-specific.
- Playwright/frontend testing is outside LENS scope (LR-5 already removed the frontend pattern file).
- AI-validator mocks are application-specific.

## Canonical LENS testing guidance

| Concern | Authoritative source |
|---|---|
| Unit testing structure, naming, builders, mocking | `_dotnet/dotnet-testing.md` (MSTest + NSubstitute + FluentAssertions per LENS-CMS reference) |
| Integration testing (fixtures, API tests, WireMock) | `_dotnet/dotnet-testing-integration.md` |
| TDD workflow + test-failure protocol | `.claude/rules/test-discipline.md` |
| Quality gate hierarchy (build, test, coverage, lint) | `.claude/rules/quality-gates.md` |

If you need a pattern from the archived content, copy it from `.mad/docs/non-lens-extras/behavioral-testing.md` into your consumer project's local docs — do not re-import to the kit's prescriptive surface without canonical-source justification.
