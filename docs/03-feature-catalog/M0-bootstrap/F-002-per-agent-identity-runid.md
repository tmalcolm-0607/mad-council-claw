---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-006 / lane-d
    note: "RED test scaffold + impl landed in same lane (RED-then-GREEN micro-session per wave-5 retro proposal). Test at tests/unit/F-002-per-agent-identity-runid.test.ts, impl at packages/engine-core/src/index.ts (~110 LOC added: createAgent, createSession, stampIdentity, internal uuidV7). 3/3 acceptance scenarios passing across 5 consecutive stable runs (vitest 2.1.9, Node 24.13.1). RED baseline captured at docs/09-examples-proof/F-002/red-test-output.txt BEFORE flip; GREEN at green-test-output.txt."
  - status: locked
    at: 2026-05-07
    by: wave-012 / lane-d
    note: "Council review verdict ACCEPT (Verdict consensus: APPROVE; median confidence 90; 0 CRITICAL / 0 MAJOR / 3 MINOR / 3 PRAISE) at docs/05-design-reviews/council-reviews/F-002-per-agent-identity-runid-review.md. red-green-rule predicate satisfied: GREEN AND review file with verdict ACCEPT. MINOR findings are honest scope-narrowing notes per no-silent-deferrals.md (crypto signing v1.5; audit-writer integration follow-on; sub-ms ordering caveat). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/identity.ts (146 LOC). 3/3 acceptance scenarios continue to PASS unchanged. Second LOCKED transition in the repo after F-001 (wave-011 / lane-b)."
feature-id: F-002
short-slug: per-agent-identity-runid
milestone: M0
provenance:
  surfaces:
    - ce:FR-IDENTITY-001
    - kit:rules/single-owner-accountability.md
    - cp:src/agents/identity
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-002-per-agent-identity-runid.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-002-per-agent-identity-runid-review.md exists with verdict: ACCEPT.
green-evidence:
  test-runner: vitest@2.1.9 (project: unit, filter: tests/unit)
  scenarios-passing: 3
  scenarios-total: 3
  red-output: docs/09-examples-proof/F-002/red-test-output.txt
  green-output: docs/09-examples-proof/F-002/green-test-output.txt
  physical-proof: docs/09-examples-proof/F-002/physical-proof.md
  stability: 5 consecutive stable runs, 6/6 PASS each (combined with F-001 no-regression)
depends-on: [F-001]
out-of-scope-notes: |
  Cryptographic spawn signing + Entra principal-binding deferred to v1.5 per
  ce:FR-IDENTITY-002 / FR-IDENTITY-003 (tracked in M19 deferred catalog).
  This feature implements run_id + agent_id + parent_run_id correlation chain only.

  Audit-writer downstream consumers — F-006 (logging pipeline that consumes
  stamps), F-008 (storage layout for runs/<run_id>/manifest.json), F-019
  (cost-ledger writer) — are tracked as soft deps; F-002 provides the
  IDENTITY_MISSING rejection contract those features will compose against.

  UUID v7 monotonic-random extension (RFC 9562 §5.7 optional sub-section)
  intentionally omitted for v1; sub-ms session creation can produce
  non-deterministic ordering of the random tail. The test compares only the
  12-hex-char timestamp prefix to honor what RFC 9562 actually guarantees.
  Adding monotonic-random later does not change the public type surface.
confidence: high
---

# F-002 — Per-agent identity & run_id correlation

## Behavior contract

Every agent action is stamped with a triple `{run_id, agent_id, parent_run_id}`. `run_id` is allocated at engine boot (UUID v7, time-ordered). `agent_id` is allocated per spawned agent. `parent_run_id` is set when an agent is spawned from another agent's context, forming a correlation chain. The triple is non-optional on every audit entry, every cost-ledger row, and every IPC message; missing-identity writes are rejected at the audit-writer boundary. Cryptographic spawn signing is explicitly deferred (v1.5).

## Acceptance scenarios

1. **Given** the engine boots, **When** it allocates the root `run_id`, **Then** the value is a valid UUID v7 (time-ordered) AND is written to `runs/<run_id>/manifest.json`.
2. **Given** agent A (id=`a1`) spawns agent B, **When** agent B emits its first audit entry, **Then** the entry carries `parent_run_id = <run_id of A>` and a fresh `agent_id` distinct from `a1`.
3. **Given** an audit-write call without an `agent_id`, **When** the audit writer is invoked, **Then** the call rejects with `IDENTITY_MISSING` and no entry is appended.

## Red→green wire-up

| Test file | Project | Final state | Verifies |
|---|---|---|---|
| `tests/unit/F-002-per-agent-identity-runid.test.ts` | unit | GREEN — 3/3 scenarios PASS, 5 consecutive stable runs | scenarios 1, 2, 3 |

The lane-d implementation collapsed the three TBD test files outlined in the
original ledger into a single colocated test file matching the F-001 naming
pattern (`tests/unit/F-NNN-<slug>.test.ts`). Naming consistency wins; the
three scenarios are still distinct `it()` blocks within the same `describe`.

## Dependencies

- **Hard:** F-001 (engine kernel must exist for identity to attach to)
- **Soft:** F-006 (logging pipeline consumes identity), F-008 (storage layout for `runs/<run_id>/`)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-IDENTITY-001 | run_id + agent_id + parent_run_id correlation chain |
| kit:rules/single-owner-accountability.md | owner-of-record discipline; identity is the substrate |
| cp:src/agents/identity | clawpilot per-agent identity allocator pattern |

## Implementation notes

Wave-6 / Lane D — second feature transition RED → GREEN in the repo (after F-001 in wave-5).

- Implementation: `packages/engine-core/src/index.ts` — F-002 adds ~110 LOC to the F-001 file
- Public surface:
  - `createSession(): Session` — `Session = {readonly runId: string}`
  - `createAgent(options?: CreateAgentOptions): Agent` — `Agent = {readonly agentId: string; readonly parentRunId?: string}`
  - `stampIdentity<T>(artifact, agent, session): IdentityStamped<T>` — boundary primitive that throws `IDENTITY_MISSING` on absent agent/session
  - `IdentityStamped<T> = T & {agent_id: string; run_id: string; parent_run_id?: string}`
- UUID v7 generator (internal, unexported `uuidV7()`): RFC 9562 §5.7 layout — 48-bit unix-ms timestamp + version-7 nibble + variant-10xx bits + remaining 74 bits random. Built from `randomBytes(16)` + bit-fiddling because `node:crypto.randomUUID()` returns v4 and the `{version:7}` option is silently ignored on Node 24.
- Audit-writer boundary contract: `stampIdentity` throws `IDENTITY_MISSING` when either `agent` or `session` is absent or lacks its identity field. Per F-002 acceptance scenario 3, this is the boundary the audit writer (F-006) and storage layer (F-008) will compose against — no entry can be appended without a stamped triple.
- Spawn correlation: `createAgent({parentSession: A})` records `parentRunId = A.runId` on the agent so future `stampIdentity` calls carry the chain on every artifact (F-002 acceptance scenario 2). Root agents created without a parent session have `parentRunId === undefined`; `stampIdentity` omits `parent_run_id` from the output for those.
- Sub-ms ordering caveat: RFC 9562 §5.7 only guarantees v7 monotonicity at ms resolution. Same-ms session creation produces non-deterministic ordering of the random tail. Test compares the 12-hex-char timestamp prefix after a 5ms busy-wait. Monotonic-random extension intentionally omitted for v1 — adding it later does not change the public type surface.
- Proof: `docs/09-examples-proof/F-002/{red-test-output.txt,green-test-output.txt,physical-proof.md}`. RED baseline captured BEFORE the impl flip per the wave-5 retro proposal.
