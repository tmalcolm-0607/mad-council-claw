# Expected output: spec from feature idea

## Generated artifact

`specs/<N>-lookup-by-tag/spec.md` carrying:

### Required sections

1. **Problem statement** — restates the consumer demand from 3 teams
2. **Functional Requirements (FR)** — each with a Logical Proof:
   - FR-1: GET /api/v1/documents/by-tag returns documents matching tag query (Logical Proof: file:line of new controller route + handler method)
   - FR-2: Pagination with ≤50 items per page, cursor-based (Logical Proof: ref to existing PaginationCursor type used in DocumentRepository)
   - FR-3: 5-minute cache TTL on (tenant, tag-query, cursor) (Logical Proof: ref to existing CachePolicy type or new policy declaration)
   - FR-4: Tenant isolation enforced (Logical Proof: ref to DocumentRepository.GetByTagAsync's existing tenantId scope)
   - FR-5: Auth via ServiceAuthorizationPolicies.DocumentRead (Logical Proof: controller method attribute)
3. **User stories** — each with ≥3 nouns (concrete artifacts):
   - "As an LRMS service, I can call /api/v1/documents/by-tag with `?tag=invoice` and receive page 1 of matching docs."
4. **Open questions explicitly marked** (per the "What WAS NOT decided" input):
   - Q1: Endpoint shape (query param vs new route)
   - Q2: AND/OR query support in v1
   - Q3: Emit TagLookupRequested event?
   These need [NEEDS CLARIFICATION: ...] markers per `.claude/rules/non-negotiable-rules.md` "guess when uncertain"
5. **Test plan reference** — auto-spawn `/mad-testplan --source spec` per the spec→testplan auto-trigger

### Implementability gates (BLOCKING per /mad-spec step 7.1)

- ✓ Vision/Contract flag: this is a Contract (FRs cite file/endpoint paths)
- ✓ Newspaper Test: each FR has a concrete answer to "what file confirms this FR?"
- ✓ 3 Nouns Test: user story has ≥3 concrete artifacts (LRMS, /api/v1/documents/by-tag, tag query string)
- ✓ Implementation Squeeze: FR-1's first verification command = `curl /api/v1/documents/by-tag?tag=invoice`
- ✓ Concept Density: 0 new coined terms (uses existing terminology)
- ✓ Test Plan Generation: blocking; spec triggers /mad-testplan auto

## Output Contract on findings (if any open questions remain)

```
[NEEDS CLARIFICATION] specs/<N>-lookup-by-tag/spec.md:<line> — Q1: endpoint shape
[NEEDS CLARIFICATION] ...
```

These are NOT findings to fix; they're explicit unknowns that block implementation until answered.

## Skill features exercised

- 6 implementability gates run (BLOCKING per step 7.1) ✓
- Vision-vs-Contract detection ✓
- Newspaper Test on every FR ✓
- Open-questions surfaced as [NEEDS CLARIFICATION] markers, not silent guesses ✓
- Auto-spawn of /mad-testplan after spec ✓
