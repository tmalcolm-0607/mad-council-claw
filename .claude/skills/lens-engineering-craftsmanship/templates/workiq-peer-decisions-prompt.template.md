# WorkIQ Peer-Centric Query Templates

Query patterns that surface **peer-side observable behavior** rather than what the user did for the peer.

## Why this matters

Self-Connect harvests ("Tony shared X with peer Y") are different from peer-feedback harvests ("what did Y author / decide / push back on / catch"). The same WorkIQ session can surface both, but the queries have to be explicitly peer-centric or the synthesis drifts back to the author's framing.

## Pattern 1: Authored decisions and artifacts

```
{Peer name} specific architectural decisions or PRs in {service / area} {year}.
```

```
List {peer name} authored design documents or specs in {year}.
```

```
What design decisions or artifacts did {peer name} author in {project} {month range}?
```

## Pattern 2: Pushed back / insisted / withdrew

```
What did {peer name} push back on or insist on in {area} during {window}? What corner cases did they surface?
```

```
{Peer name} contract review comments {year} - what did they flag, what did they accept?
```

## Pattern 3: Ownership and follow-through

```
{Peer name} incidents owned + retros authored {year}.
```

```
{Peer name} on-call hand-offs and how they structured them.
```

## Pattern 4: Adoption signals (not "Tony's tools" — peer's behavior)

```
{Peer name} agentic / AI tooling adoption in {year}: what patterns did they adopt, what tools did they build, what feedback did they give?
```

```
{Peer name} peer-review feedback on {package or repo}: list comments and outcomes.
```

## Pattern 5: Cross-team coordination they drove

```
What cross-team artifacts did {peer name} author or aggregate {year}?
```

```
{Peer name} email / Loop component / SharePoint doc authoring in {year}.
```

## Anti-pattern queries (avoid these — drift to self-Connect)

```
❌ "How did Tony help {peer}?"
❌ "What did Tony share with {peer}?"
❌ "{Peer} and Tony Teams collaboration {year}." (returns Tony-centric narrative by default)
```

## Throttle pattern

WorkIQ drops on real-content queries roughly every other call. Pattern:

```
1. test (probe to verify connection)
2. peer-centric query
3. test (revive)
4. next peer-centric query
```

If a query drops, send `test` and retry. See `docs/BACKOFF-PATTERNS.md` for the full pattern.

## What to save per peer

Save responses to `.mad/scratch/workiq-peer-evidence/{peer-slug}-{year}-decisions.md` with:
- Authored artifacts (design docs, PRs, emails, Loop components)
- Decisions made (chose X over Y, deferred Z)
- Push-back / withdrawal moments
- Cross-team aggregations / translations
- Adoption signals (what they built, what they gave feedback on)

These artifacts feed the peer 6-box authoring step.
