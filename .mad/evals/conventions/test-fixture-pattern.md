# Test convention — Fixture + Factory + CreateSUT

Every MAD unit and integration test MUST follow this three-layer construction pattern. Distilled from internal engineering-standards docs on C#/xUnit testing patterns. Adopted via `ADOPT-003`.

## Why

Tests that construct their subject-under-test (SUT) inline drift fast: every new constructor parameter forces an N-file edit, every new dependency leaks into every test as boilerplate, and test readers have to re-parse the construction spaghetti to understand what's being tested. A layered pattern keeps the per-test surface tiny and the construction contract in one place.

## The three layers

| Layer | Responsibility | Who writes one | How often edited |
|---|---|---|---|
| **1. TestObjectFactory** | Returns `Faker<T>` builders for domain objects. Each builder has sensible defaults; tests override only the fields they care about. | One per domain type (Message, Channel, Verdict, etc.). | Rarely — when the domain type gains a field. |
| **2. Fixture** | Holds shared state (substitutes, configs, in-memory filesystems). Exposes one `CreateSUT()` method — the **only** place the SUT is constructed. Fluent `With*` methods mutate fixture state (return `this`). | One per skill / script / behaviour cluster under test. | When a new dependency is added to the SUT. |
| **3. Test** | Arrange → fixture + factory calls. Act → single method call on SUT. Assert → outcome. No constructor calls here. | Per test case. | Per behaviour change. |

## Canonical example

```powershell
# evals/fixtures/council-post/MessageFactory.ps1
# Layer 1 — TestObjectFactory
function New-MessageBuilder {
    [Faker[Message]]::new().
        RuleFor({$_.id}, { "msg-$([guid]::NewGuid().ToString('N').Substring(0,8))" }).
        RuleFor({$_.type}, 'task').
        RuleFor({$_.body}, { $_.Lorem.Paragraph() }).
        RuleFor({$_.author_alias}, 'Advocate').
        RuleFor({$_.posted_utc}, { (Get-Date).ToUniversalTime().ToString('o') })
}

# evals/fixtures/council-post/CouncilPostFixture.ps1
# Layer 2 — Fixture
class CouncilPostFixture {
    [object] $ChannelHelpers    # substitute
    [object] $AtomicWriter      # substitute
    [string] $ChannelPath
    [bool]   $MadEnabled = $false

    # Fluent setters — keep tests tight
    [CouncilPostFixture] WithMadEnabled()          { $this.MadEnabled = $true; return $this }
    [CouncilPostFixture] WithChannelPath([string]$p) { $this.ChannelPath = $p; return $this }
    [CouncilPostFixture] WithAtomicWriteFailing()  {
        $this.AtomicWriter.When('Write-AtomicJson').Throw('disk full')
        return $this
    }

    # Single point of construction — the whole point of the fixture
    [CouncilPostSkill] CreateSUT() {
        return [CouncilPostSkill]::new($this.ChannelHelpers, $this.AtomicWriter, $this.MadEnabled)
    }
}

# evals/fixtures/council-post/unit/parse-args-happy.Tests.ps1
# Layer 3 — Test
Describe "council-post — MAD-gate blocks task posts when mad_enabled is on" {
    It "rejects task type with MAD_GATE_BLOCKED exit code" {
        $fixture = [CouncilPostFixture]::new().WithMadEnabled()
        $message = (New-MessageBuilder).Generate()

        $sut = $fixture.CreateSUT()
        $result = $sut.Post($message)

        $result.ExitCode | Should -Be 'MAD_GATE_BLOCKED'
    }
}
```

Notice what the test **does not** do:
- Construct the SUT directly (fixture does it).
- Configure every substitute inline (fluent `With*` methods encapsulate common scenarios).
- Assemble a full `Message` by hand (factory provides defaults; test overrides only what matters — nothing, in this case).

## Rules

1. **One `CreateSUT()` per fixture, one call per test.** Tests that construct the SUT twice are testing two things — split the test.
2. **Fluent `With*` methods only for scenarios used by ≥2 tests.** A one-off setup belongs inline in the single test that needs it. Don't grow the fixture surface prophylactically.
3. **Base fixtures only for truly ubiquitous dependencies** (logger, configuration, clock). Deep inheritance trees are a smell — prefer composition.
4. **Factories return builders, not objects.** `New-MessageBuilder` → caller chains `.With(...)` → `.Generate()`. This lets every test override whichever fields matter for that test without the factory having to anticipate every permutation.
5. **Partial classes to split large generator files.** `MessageGenerators.cs` → when it grows past ~200 lines, split by area: `MessageGenerators.Verdict.cs`, `MessageGenerators.Retro.cs`. PowerShell analogue: one `.ps1` per area dot-sourced into the fixture.
6. **No test reaches through the fixture to tweak substitutes directly** after `CreateSUT()` returns. If a mid-test mutation is needed, add a `With*` method or expose a setter with a deliberate name.

## MAD-specific adaptations

MAD runs PowerShell (Pester 5) + JSON fixtures on disk. The C# / xUnit patterns in the source engineering-standards doc map as:

| Source (C# / xUnit)              | MAD (PowerShell / Pester 5)                                           |
|----------------------------------|-----------------------------------------------------------------------|
| `Faker<T>` (Bogus lib)           | `[Faker[T]]::new()` via `Bogus.PSM` or hand-rolled `New-*Builder`.    |
| `Moq` / `NSubstitute`            | Pester `Mock` or `InModuleScope` with `Should -Invoke`.                |
| xUnit class fixture              | Pester `BeforeAll { $script:fixture = ... }` in the `Describe`.        |
| `FluentAssertions` (v7)          | Pester `Should -Be` / `Should -Match` / `Should -BeOfType`.            |
| WireMock for downstream stubs    | `evals/fixtures/a2a-mock/` — filesystem-backed JSON-RPC stub server.   |

## Pinned tool choices (ADOPT-028)

The source engineering standard pins specific tool names. MAD adopts the same pins where a MAD analogue exists, and treats deviations as needing explicit justification in `_review-checklist.md`:

| Purpose | Source pin | MAD pin | Deviation rule |
|---|---|---|---|
| Mocking | **NSubstitute** (chosen over Moq for cleaner API) | Pester `Mock` + `Should -Invoke` (no Moq/NSubstitute in pwsh) | — |
| Assertions | **FluentAssertions** v7 (or MSFT_InternalOnly fork; v8+ not OSS) | Pester `Should` operators | When MAD grows C# test components, pin to FluentAssertions v7/MSFT_InternalOnly — DO NOT take the v8+ OSS-incompatible jump without a CHK entry |
| Test data generation | **Bogus** (via `Faker<T>`) | `[Faker[T]]::new()` via Bogus.PSM OR hand-rolled `New-*Builder` | Hand-rolled allowed only when Bogus.PSM is unavailable |
| Downstream service stubs | **WireMock** | `evals/fixtures/a2a-mock/` JSON-RPC stub; use WireMock directly only for HTTP-shaped A2A tests | — |
| Unit test framework (C#) | **MSTest OR xUnit** (team evaluating — no pin yet) | **Pester 5** (pwsh-native; no choice debate) | If MAD grows C# tests, defer framework choice to first such test's PR review |

**Framework-choice ambivalence is intentional.** The source engineering standard itself hasn't pinned MSTest vs xUnit; MAD inherits that un-pinning and doesn't artificially over-specify. But within each chosen framework, the library selections (NSubstitute, FluentAssertions, Bogus, WireMock) ARE pinned — these are downstream compatibility contracts, not style choices.

## Related

- `evals/layer-1-unit.md` — required reference to this doc for every unit test author.
- `evals/layer-2-integration.md` — integration tests use the same fixture pattern; extra layer for filesystem state (temp-dir fixture pattern).

## Source

Internal engineering-standards doc on C# testing conventions — specifically the sections "Test project layout", "TestObjectFactory pattern", and "Fixture pattern".
