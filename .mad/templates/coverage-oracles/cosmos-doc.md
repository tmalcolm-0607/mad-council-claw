# Coverage Oracle — Cosmos repository documentation

What a *complete* doc-change describing a Cosmos DB repository pattern must cover. A skill (pr-review, code-reviewer, design-review, refresh-best-practices) loads this oracle when input classifies as `doc-change` AND topic-keywords match Cosmos.

> Source: post-mortem of LENS-CMS PR #5157555 (May 2026). The original doc was scored "no findings" on stylistic precision while structurally missing PATCH semantics — exactly the failure mode this oracle is designed to catch.

## Required sections

For each section: skill emits `present | missing | partial` against the input.

### 1. Partition key strategy
- WHAT field, WHY chosen, throughput implications
- Cardinality bounds (target 100–10K logical partitions)
- Hot-partition mitigation if applicable

### 2. Indexing policy
- Default vs included vs excluded paths
- Composite indexes called out with example query
- RU impact stated quantitatively (or "default" with rationale)

### 3. Query patterns
- ≥3 representative queries with their RU cost
- Cross-partition explicitly declared (or marked single-partition)
- Pagination strategy (continuation token vs offset)

### 4. PATCH / partial-update semantics
- `If-Match` ETag propagation pattern (request → response → next request)
- 412 Precondition Failed handling
- Idempotency key, if applicable
- 428 Precondition Required handling (server requires `If-Match`)
- Difference between PATCH and ReplaceItem

### 5. Read patterns
- Strong vs eventual consistency choice + why
- Session token propagation if Session-level
- Point read vs query for known-id retrieval

### 6. Error handling
- Specific Cosmos exception types caught
- 429 (rate-limited) backoff strategy
- 503 (service unavailable) retry policy
- `CosmosException.SubStatusCode` interpretation table

### 7. Bicep / infra index sync
- Bicep `included paths` array matches the indexing-policy section
- Container creation parameters (TTL, partition key path) match runtime ContainerContext

### 8. Test coverage
- Integration test against Cosmos emulator
- Concurrency test for ETag-mismatch path
- Empty-partition / cold-cache behavior

### 9. Migration / version handling
- Forward-only schema additions vs reshape
- Old-version reader compatibility
- Rollback ETag implications

### 10. Telemetry
- Per-operation RU consumption logged
- Diagnostic context propagation (operation_Id)
- Throughput metric exposed

## Severity per missing section (when content-type is `doc-change`)

| Section | Missing severity |
|---------|------------------|
| Partition key strategy | BLOCKING |
| Indexing policy | BLOCKING |
| Query patterns | MUST-FIX |
| **PATCH / partial-update semantics** | **BLOCKING** |
| Read patterns | MUST-FIX |
| Error handling | MUST-FIX |
| Bicep / infra index sync | BLOCKING |
| Test coverage | MUST-FIX |
| Migration / version handling | SHOULD-FIX |
| Telemetry | SHOULD-FIX |

The right *first* finding for a teaching doc lacking PATCH semantics is "PATCH section missing", emitted as BLOCKING with this oracle's section ID cited.

## Anti-hallucination

- "Missing" finding cites this oracle's section number + title verbatim
- "Partial" finding quotes the partial content present and lists what's absent
- Reference-repo cross-check (per Gap 2) verifies any pattern claimed in the doc actually exists in `references/LENS-CMS`, `references/LENS-DCS`, etc.

## Cross-references

- `rules/prescriptive-content-review.md` § Gap 3 — completeness oracle pattern
- `rules/patterns/_dotnet/dotnet-cosmos-core.md` — actual partition / client guidance
- `rules/patterns/_dotnet/dotnet-cosmos-queries.md` — query and pagination patterns
- `rules/patterns/_dotnet/dotnet-cosmos-advanced.md` — change feed, batching
