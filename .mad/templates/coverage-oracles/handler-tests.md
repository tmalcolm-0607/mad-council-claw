# Coverage Oracle — Handler tests

What a *complete* test set for an HTTP handler / message handler / event handler must cover. Skills load this oracle when input classifies as `code-change` and the changed code includes a public handler entry point.

## Required scenarios

| # | Scenario | Why required |
|---|----------|--------------|
| 1 | Happy-path: valid input → expected output | the success contract |
| 2 | Validation rejection: bad input → 400/422 with structured error | input contract enforcement |
| 3 | Unauthorized: missing/invalid auth → 401 (or 403 if RBAC) | auth contract |
| 4 | Forbidden: authenticated but unauthorized → 403 | authorization contract |
| 5 | Not found: addressing a non-existent resource → 404 | resource contract |
| 6 | Conflict: stale ETag / duplicate idempotency-key → 409 (or 412) | concurrency contract |
| 7 | Rate-limited: 429 response handling (if upstream call possible) | resilience contract |
| 8 | Server error: downstream failure → 500 with no PII leak | error-shape contract |
| 9 | Cancellation: CancellationToken propagation | shutdown / timeout contract |
| 10 | Idempotency: same input twice → same observable outcome | retry-safety contract |
| 11 | Telemetry: ActivitySource span emitted with correct tags | observability contract |
| 12 | Validator wired: `IValidator<T>.ValidateAsync` called before business logic | validator-wiring pattern |

## Per-content-type severity

For `code-change` inputs:

| Missing scenario | Severity |
|------------------|----------|
| #1 happy-path | BLOCKING (no test coverage at all) |
| #2 validation rejection | MUST-FIX |
| #3, #4 auth | MUST-FIX (BLOCKING if security-critical) |
| #5 not-found | SHOULD-FIX |
| #6 conflict / ETag | MUST-FIX (BLOCKING if mutating handler with persistence) |
| #7 rate-limited | SHOULD-FIX |
| #8 server-error shape | MUST-FIX (SHOULD-FIX if no PII risk) |
| #9 cancellation | SHOULD-FIX |
| #10 idempotency | MUST-FIX (BLOCKING if mutating + retried by callers) |
| #11 telemetry | SHOULD-FIX |
| #12 validator wired | MUST-FIX |

## Anti-hallucination

- "Missing" finding cites the test class/file inspected + asserts which scenarios were checked
- Don't claim "no test for X" without reading the test file
- "Partial" finding lists which scenarios are tested and which are missing

## Cross-references

- `rules/patterns/_dotnet/dotnet-testing.md` — test structure conventions
- `rules/patterns/_dotnet/dotnet-testing-integration.md` — integration test fixtures
- `rules/test-failure-protocol.md` — how to handle pre-existing failures
