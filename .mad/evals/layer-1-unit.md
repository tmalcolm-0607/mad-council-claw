# Layer 1 — Unit Tests

Unit tests for individual functions: parsing, validation, state-derivation logic, schema check, etc. Deterministic; fast (<100ms per test); run on every commit.

## Scope

Test one function at a time, with mocks or fixtures replacing any external dependency.

**In scope**:
- Argument parsing (each skill's "Step 1").
- Validation functions (name regex, body size, enum values, GUID format).
- Derivation functions (run_id resolution, time-ago formatter, T-ID extraction, improvisation heuristic, unread calculation).
- Schema validators (Layer 0 fixtures helpers).
- Individual script functions (atomic-write, seq-increment, literal-phrase-scan, etc.).

**Out of scope**:
- Multi-step workflows (Layer 2).
- Real filesystem or network calls (Layer 3 fault-injection).
- Adversarial inputs (Layer 4).

## Source of truth

Each skill's `tests.md` has a "Layer 1 — Unit" section. Each row translates to one Pester test file here.

Example: `skills/council-post/tests.md` Layer 1 rows T1-01 through T1-16 → 16 test files under `fixtures/council-post/unit/`.

## Construction convention (required)

Every unit test file MUST follow the three-layer pattern in **`conventions/test-fixture-pattern.md`**:

1. **TestObjectFactory** returns `Faker<T>` builders — never pre-built objects.
2. **Fixture** holds substitutes + exposes one `CreateSUT()` method (the sole construction point) with fluent `With*` methods for shared scenarios.
3. **Test** arranges via fixture + factory, acts with a single SUT call, asserts outcome. No constructor calls in the test body.

This is an `ADOPT-003` requirement — tests that construct the SUT inline or fan-out mock configuration across multiple tests are rejected at review.

## Test file layout

```
evals/fixtures/council-post/unit/
  parse-args-happy.Tests.ps1
  parse-args-both-thread-flags.Tests.ps1
  parse-args-no-thread-flag.Tests.ps1
  parse-args-invalid-type.Tests.ps1
  body-size-cap-edge-32767.Tests.ps1
  body-size-cap-edge-32768.Tests.ps1
  body-size-cap-edge-32769.Tests.ps1
  slugify-collision.Tests.ps1
  literal-phrase-match.Tests.ps1
  mention-parse-dedup.Tests.ps1
  run-id-resolution-reply-to.Tests.ps1
  ...
```

## Test skeleton

```powershell
# council-post/unit/parse-args-happy.Tests.ps1
Describe "council-post parse-args happy path" {
    BeforeAll {
        . "$PSScriptRoot/../../../scripts/channel-helpers.ps1"
        # Load skill's argument parser (to be implemented; currently stub).
        # . "$PSScriptRoot/../../../skills/council-post/scripts/parse-args.ps1"
    }

    It "parses minimal invocation" {
        $result = ConvertFrom-ArgString "ch --new-thread ""t1"" --type task ""body"""
        $result.channel | Should -Be 'ch'
        $result.new_thread | Should -Be 't1'
        $result.type | Should -Be 'task'
        $result.body | Should -Be 'body'
        $result.mode | Should -Be $null
    }

    It "parses with all optional flags" {
        $result = ConvertFrom-ArgString "ch --thread t1 --type answer ""body"" --reply-to msg-001 --mentions ""Alice,Bob"" --run-id 8f3a2b1c-9d4e-4f5a-b6c7-d8e9f0a1b2c3 --transport a2a-http --force-raw"
        # assertions...
    }
}
```

## Test categories + target counts

| Category | Tests per skill (avg) | Total across 10 skills |
|---|---|---|
| Argument parsing | 4-6 | ~50 |
| Validation functions | 3-5 | ~40 |
| Derivation logic | 2-4 | ~30 |
| Schema validation | 1-2 | ~15 |
| Script-specific (scripts/*) | 5-8 per .ps1 | ~60 (7 scripts × 8) |
| ADOPT flag branches (council-open `--owner`, `--tier`, `--triage`, `--acceptance-criteria`, `--effort-estimate`; council-verdict lifecycle flags `--to-alias`, `--rejection-reason`; council-post new types `triage-question`/`triage-context`) | — | ~25 (ADOPT-021) |
| **Total Layer 1** | | **~220** |

## Coverage requirements

- Every branch in every validation function covered (100%).
- Every enum value tested at least once.
- Every error path asserted.
- Mutation testing: inject off-by-ones / boundary flips; tests must catch.

## Pipeline split (ADOPT-037)

Distilled from internal engineering standards docs (`CreatingServices/testing.md §Unit Tests vs Integration Tests`): unit tests run inside the fast CI gate (CloudBuild / QTests); integration tests run in a slower pre-release gate (Focus). Applied to MAD:

| Layer | Runs in | Gate speed | Blocks what |
|---|---|---|---|
| Layer 1 (this doc) | per-PR CI | <30 s / skill | every merge |
| Layer 2 integration | per-PR CI (fast path) + nightly (full path) | <3 min nightly | pre-release only for the full path |
| Layer 3 e2e fault-injection | pre-release pipeline | minutes | release candidates |

**Invariant:** a skill's unit tests (Layer 1) MUST NOT require external services, filesystem beyond a test temp dir, or real network calls. Anything requiring those lives in Layer 2+. A test that nominally runs at Layer 1 but actually hits a real A2A endpoint is a pipeline violation and gets moved to Layer 2 at review.

## Running Layer 1

```
./run-evals.ps1 -Layer 1
```

Output:

```
Layer 1 — Unit Tests
  Describe: council-open parse-args           ....  [OK] 8 passed
  Describe: council-join parse-args           ....  [OK] 6 passed
  Describe: council-post parse-args           ....  [OK] 16 passed
  Describe: council-post body-size-cap        ....  [OK] 3 passed
  Describe: council-check priority-sort       ....  [OK] 5 passed
  ...

Total: 195 tests, 195 passed
Branch coverage: 96.2%
Time: 4.8s
```

## Perf budget

- **Each test**: <100ms.
- **Full Layer 1 suite**: <30s.

Exceeding these is a regression signal — investigate.

## Related

- `layer-0-data-sources.md` — fixtures Layer 1 depends on.
- `layer-2-integration.md` — next layer (multi-function flows).
- Every skill's `tests.md` §Layer 1 section.
