# Eval: peer-centric vs self-centric framing

Test fixture for the peer-feedback subject-test. Linter should distinguish peer-centric (PASS) from self-centric (FAIL) phrasing.

## Fixtures

### F1 — PASS (peer is the subject)

```
You authored the X Service Design Document and continuously synchronized it with shipped code.
```

Expected: PASS. Subject is "you" (peer).

### F2 — PASS (peer-side decision)

```
You proposed `DataCategoryGroup` as a property rather than introducing subcategories as first-class objects.
```

Expected: PASS. Subject is peer; verb is decision-shaped.

### F3 — FAIL (self-Connect framing)

```
I shared the design pattern with you and you absorbed it cleanly.
```

Expected: FAIL. Subject is "I"; framing centers Tony's giving.

### F4 — FAIL (Tony-centric pivot)

```
You flagged the issue and I traced and fixed it.
```

Expected: FAIL. Sentence starts peer-centric but pivots to Tony's action mid-sentence.

### F5 — PASS (peer-centric with Tony as background context only)

```
You sent the Mar 13 collated email aggregating CMS asks across CaseSummary, CaseDetails, DataCategory, and jobId APIs, with named owners next to each item.
```

Expected: PASS. Tony only appears implicitly as recipient; Meredith's authoring is the subject.

### F6 — FAIL (vague compliment, no anchor)

```
You're great at communication.
```

Expected: FAIL. No quoted artifact, no dated moment, no decision-shaped verb.

### F7 — PASS (quoted peer voice)

```
On the contracts review you wrote *"the approach is proven. Not asking for it in this PR. that'd blow up scope. But I think a follow-up to extract the lifecycle phases would go a long way"* — that's the right balance of architect-grade vision and PR-boundary discipline.
```

Expected: PASS. Quoted phrase is peer's; framing leads with peer's voice.

### F8 — FAIL (activity without outcome in self-Connect)

```
Worked on Service-X modernization this cycle and helped peers across LRMS, CMS, and SMS.
```

Expected: FAIL (self-Connect). Activity verbs ("worked on", "helped") with no Y outcome.

### F9 — PASS (Did X → Y in self-Connect)

```
Authored the Service-X cross-team contract package and shipped v1.11-alpha as a NuGet, resulting in two consumer services removing locally-maintained enum copies the same week.
```

Expected: PASS (self-Connect). Specific X, named Y outcome.

## Linter rules these fixtures exercise

| Rule | Anti-pattern | Detection |
|---|---|---|
| `peer.subject_is_peer` | First-person subject in peer feedback | Sentences in peer 6-box must start with "you" or peer's name (or possessive) |
| `peer.tony_pivot` | Sentence mid-pivots to Tony's action | Detect "and I {verb}" or "I {verb}" mid-paragraph |
| `peer.vague_compliment` | Compliment without anchor | Compliment phrases ("you're great at X", "you're skilled at Y") must be followed by quoted artifact OR named date |
| `self.activity_without_outcome` | Verb-only bullets in self-Connect | Self-Connect bullets must contain "resulting in" or equivalent outcome marker |

## Exit codes

`style-lint.ps1 -Mode peer-feedback` returns:
- 0 = all peer-centric, all anchored
- 1 = at least one self-centric pivot or vague compliment
- 2 = at least one box missing required structure (subject test failed)

`style-lint.ps1 -Mode self-connect` returns:
- 0 = all bullets have Did-X-Y structure
- 1 = at least one activity-without-outcome bullet
- 2 = character limit exceeded
