# MAD.Council schemas

Machine-readable JSON Schemas for the artifacts described in prose in `mad.council.a2a.md §7`. These files let Layer-0 data-source certification (`evals/layer-0-data-sources.md`) validate fixtures mechanically instead of by eye.

## Inventory

| File | What it validates | Source of truth |
|---|---|---|
| `channel.schema.json` | `~/claude-data/channels/<channel>/channel.json` | spec §7.1 + §6.1 (Agent Card) |
| `message.schema.json` | `threads/<thread-id>/messages/<seq>-<timestamp>-<alias>.json` | spec §7.3 |
| `digest.schema.json` | `~/claude-data/channels/<channel>/digest.json` | spec §7.5 |
| `verdict.schema.json` | `threads/<thread-id>/verdict.json` | `skills/council-review/SKILL.md §Step 9` |
| `read-marker.schema.json` | `read-markers/<alias>.json` | spec §7.6 |
| `seq.schema.json` | `seq.json` | spec §7.1 (implicit) |
| `completion-report.schema.json` | `/council-leave` output JSON | `skills/council-leave/SKILL.md §Output format` |
| `thread.schema.json` | `threads/<thread-id>/thread.json` | spec §7.4 |
| `sessions.schema.json` | `.sessions.json` per-session registry | spec §7.2 |
| `retro.schema.json` | `<channel>/retros/<ts>-<alias>.json` | `skills/council-retro/SKILL.md §Output format` |
| `consent-log.schema.json` | `<channel>/consent-log.jsonl` (one line per entry) | `rules/dangerous-operations-policy.md §Audit trail` |

## Conventions

- JSON Schema draft **2020-12**.
- `$id` starts with `https://github.com/agency-microsoft/playground-main/MAD/schemas/` so schemas can be resolved by URL if we later publish.
- `additionalProperties: false` by default — every field declared, no silent extras. Exception: the top-level `metadata` object on each artifact (for future-proofing).
- `description` on every property — the schemas double as documentation.
- Field types match the spec exactly; when the spec says "GUID" we use `"format": "uuid"`; when "ISO-8601 UTC" we use `"format": "date-time"`.

### Typed-parameter convention (ADOPT-031)

Distilled from internal engineering standards docs on Bicep parameter conventions — every Bicep parameter requires `@description` + `type` + `@allowed` (constrained set, not an enumeration of every possible value). Applied to JSON Schema:

1. **`description` required on every property.** No exceptions. A field without a description is a field that will be mis-populated by a skill author. `scripts/check-mad-links.ps1` (Phase-1) will enforce this.
2. **`enum` when the value space is discrete and bounded.** `status: triage|ready|active|resolved|closed` is an enum. Free-form strings (`purpose`, `acceptance_criteria`) are not — use `minLength` + `maxLength` + `pattern` instead.
3. **`pattern` on string fields with constrained shape.** Aliases, channel names, slugs, IDs — all have regex constraints. Prose like "lowercase alphanumeric" is not enough; the pattern is the contract.
4. **Constrained enums, not kitchen-sink enums.** Include values the skills actually emit. Don't pre-declare Phase-5 enum values "just in case" — add them when skills consume them, in the same PR.
5. **Version the schema on breaking changes.** Adding an optional field is non-breaking and doesn't bump the version. Changing a field from optional to required, tightening a pattern, or removing an enum value is breaking: bump via `$id` suffix `/v2`.

### Schema-version increment invariant (ADOPT-036)

Derived from internal engineering standards docs (`CreatingServices/Ev2ManualDeploy.md`) — "Artifact version MUST increment per registration; overriding versions only for rapid iteration, never in prod."

Applied to MAD at the artifact (not schema-file) level: **every JSON document MUST carry a `schema_version` field**, and that field MUST increment when the writing skill's expectations change materially.

Examples:
- `channel.json:schema_version` started at `1`. Iters 1-8 added 7 new fields (`owner_alias`, `environment_tier`, `status`, `acceptance_criteria`, `effort_estimate_hours`, `triaged_at_utc`, `triaged_by_alias`, `channel_slug`, `membership_expires_at`, `role`). **→ bump to `2`.**
- `verdict.json:schema_version` similar — add if not present; iters 3-4 added `ownership_transfer` + `triage_decision` sub-objects. **→ version 2.**
- `digest.json`, `thread.json`, `message.json` — audit at the next QSR.

**Reader compatibility rule:** a skill reading a lower schema_version than it was written against MUST up-convert on read (fill in new optional fields with sensible defaults). A skill reading a *higher* schema_version than it knows about MUST fail with `SCHEMA_VERSION_AHEAD` rather than silently dropping unknown fields. This is the mirror of the the ecosystem "override in rapid iteration, never in prod" posture.

## Validation harness

Planned `scripts/validate-schemas.ps1` (Phase-1 deliverable): walks `evals/fixtures/**/*.json`, matches each file to its schema by location (e.g. any file named `channel.json` → `channel.schema.json`), runs validation via `Test-Json -Schema`, exits non-zero on any failure. Also runnable ad-hoc against a single file.

## When to edit a schema

- A new field gets added to the spec → add it here first, then update the prose, then the code.
- A field's semantics change → version the schema by adding `$id` suffix `/v2` and cutover fixtures.
- Do NOT loosen validation to accommodate a malformed fixture — fix the fixture.

## Related

- `mad.council.a2a.md §7` — prose source of truth.
- `evals/layer-0-data-sources.md §Fixture integrity` — where these schemas get invoked.
- `scripts/validate-schemas.ps1` (Phase 1) — the runner.
