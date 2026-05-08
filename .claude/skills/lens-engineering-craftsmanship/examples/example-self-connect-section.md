# Example: Self-Connect Workstream Section (with Did X → Y framing)

Sanitized example showing the "Did X, resulting in Y" pattern. All names and metrics are illustrative.

## Good example

### Service-X Modernization

Owned the Service-X modernization workstream end-to-end this cycle (architecture, integration contracts, ops handoff).

Authored the Service-X cross-team contract package and shipped v1.11-alpha as a NuGet, resulting in two consumer services removing locally-maintained enum copies (Service-Y, Service-Z) and aligning to the canonical model the same week.

Drove the audit-semantics decision (case-level changes auto-logged with actor + before/after value) and propagated it across the LRMS-CMS conversation, resulting in LRMS consuming the existing audit surface instead of CMS shipping new fields. saved the next two PRs of would-be schema work.

Caught and root-caused a Cosmos rollout failure (forbidden unique-index modification traced to a previously manual container delete), and committed to codify the cleanup in IaC, resulting in zero recurrence over the next 8 weeks of rollouts.

Established the CMS-LRMS integration cadence (Mar 13 collated requirements, Apr 14 LENS-Common NuGet adoption, Apr 24 region-handling alignment), resulting in PPE E2E validation completing on schedule with no breaking-change incidents.

Collaboration: Peer 1, Peer 2, Peer 3, Peer 4.

## Bad example (what to avoid)

### Service-X Modernization

Worked on Service-X modernization. Drove a lot of contract work. Helped peers across LRMS, CMS, and SMS.

Pushed the audit-semantics conversation forward. Made progress on the Cosmos rollout reliability. Helped unblock the team on a few release-time issues.

Contributors: A, B, C, D.

## What's wrong with the bad example

| Issue | Fix |
|---|---|
| "Worked on" / "drove" / "helped" without outcome | Replace each with "Did X, resulting in Y" |
| Vague scope | Name specific artifacts (NuGet version, doc, PR family) |
| "Pushed forward" / "made progress" | Replace with the decision made and what it changed |
| "Contributors" label | Use "Collaboration" — implies two-way value |
| No measurable or qualitative outcome | Every bullet must end in a result (metric, schedule, scope reduction, incident count) |

## How to write a Y outcome when there's no easy metric

Even non-metric outcomes count if they're concrete:
- "...resulting in {peer team} unblocked the same week"
- "...resulting in the next two PRs of would-be schema work being avoided"
- "...resulting in PPE E2E completing on schedule with no breaking-change incidents"
- "...resulting in {service} adopting the {pattern} as its baseline"
- "...resulting in zero recurrence over {window}"

If you genuinely can't name a Y, the X probably wasn't impactful enough to mention. Either find the Y or drop the bullet.
