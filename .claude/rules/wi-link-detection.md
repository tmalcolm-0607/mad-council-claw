---
status: preview
since: 2026-05-07
last_reviewed: 2026-05-07
title: WI-link detection
---

# Rule — WI-link detection

> **Status: preview.** Authored 2026-05-07 in cross-lens-em-reporting loop iter 6 (per iter3-N4). Promotion to `stable` requires 2+ clean iters with consumer skills (`pr-without-workitem-scan`, `breaking-change-paper-trail`) inheriting this rule and producing reconciled WI-link verdicts that match ADO's canonical PR-Workitem relations.

## Rule statement

Every skill that classifies commits or PRs as "linked to a work item" or "WI-less" MUST use the canonical regex set defined here AND reconcile the commit-body signal against ADO's PR-Workitem RELATIONS list. Drift between consumers (one skill widening the regex, another narrowing it; one counting bare `#NNN` as a WI link, another excluding it) defeats cross-LENS roll-up comparability and produces silently inconsistent EM reports. The regex set is THE single source of truth — fork only via explicit user/council discussion documented in this file's changelog.

## Canonical regex set

```
AB#\d{4,}                                         # Azure Boards reference
\b(?:User Story|Bug|Task|Feature|Epic)\s+#?\d+\b  # typed reference
^\s*#\d+\b                                        # bare GitHub-style
Work\s*Item\s*[#:]?\s*\d+                         # verbose form
users/[^/]+/(?:wi|task|bug|us|feature)-\d+        # branch refs
Related\s+work\s+items?:\s*#?\d+                  # verbose Related
```

Scanned in BOTH commit subject AND body. Multi-line; case-insensitive on the prose forms (typed reference, verbose, Related).

## Exclusions

The pattern `\bPR\s*#?\s*\d+\b` is **NOT** a WI link. Match and EXCLUDE this pattern BEFORE applying the WI regex set — otherwise PR cross-references (e.g., "supersedes PR #5158460") get miscounted as WI links and inflate the linked-rate.

## Reconciled WI verdict

```
WiLess = (CommitBodyWi == NO) AND (PrLinkedWi == NO)
```

The PR-linked WI list (`az repos pr work-item list --id <pr-id>`) is the canonical signal — it returns ONLY formal PR-Workitem RELATIONS, which is what ADO and the EM rollup tooling treat as the audit trail. Commit-body regex catches direct mentions; PR-relation API catches links created via portal/UI without commit-message discipline. A commit/PR is only "WI-less" when BOTH signals are negative.

PR descriptions that mention `AB#NNNNN` without creating a relation will record `PrLinkedWi = NO` — this is correct per `verification-protocol.md` (relations are the authoritative state, not prose claims).

## When to update

Update this rule (regex additions, exclusion changes, reconciliation logic) ONLY with explicit user/council discussion documented in the changelog at the bottom of this file. Per `no-silent-deferrals.md`, narrowing or removing a regex without discussion is forbidden. Adding a new pattern that surfaces previously-missed WI-link forms is a discussion-required change too — broader scope changes the WI-less rate trend line and breaks comparability across iters.

## How to apply

Every consumer skill MUST:

1. Add `.claude/rules/wi-link-detection.md` to its `inherits-rules` frontmatter list.
2. Cite the regex set verbatim in its own Standards section (preserves the rule even if a future audit tool reads only the SKILL.md).
3. Implement the exclusion BEFORE the match (PR-number filter first).
4. Implement the reconciliation as `WiLess = both-negative`, not `WiLess = commit-body-only-negative`.

A skill that emits a "WI-less" verdict without inheriting this rule is producing uncomparable output and fails `skill-standards.md` Dimension 3.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Narrow regex to "AB#NNNN only" without discussion | Misses 5 of 6 link forms; inflates WI-less rate; breaks roll-up comparability | Open a council thread; document rationale in this file's changelog |
| Count `PR \d+` references as WI links | PR IDs and WI IDs share namespace prefix `#NNN` but are different entities | Apply PR-number exclusion BEFORE the WI regex |
| Rely on commit-body signal only (skip the PR-relation API) | Iter2-M5 vs iter3-A: 21pp gap on LEAPI sample (92.9% commit-body WI-less vs 71.4% reconciled) | Reconcile both signals; report both rates separately for transparency |
| One consumer adds a regex, another doesn't | Cross-skill drift; EM report shows different WI-less rates depending on which skill ran | Inherit this rule; cite the canonical set verbatim |

## Evidence

- **Iter2-M5** (`.mad/reports/cross-lens-iter2/M5-lens-leapi-wi-link-analysis.md`): LENS-LEAPI 7-day window, commit-body regex only — 13 of 14 commits (92.9%) WI-less. Source signal that motivated the skill set.
- **Iter3-A** (reconciled with `az repos pr work-item list`): same window — 10 of 14 commits (71.4%) reconciled-WI-less. **21 percentage-point gap** between commit-body-only and reconciled. PR-relation API surfaces formal links the commit body doesn't mention. Reconciliation is mandatory; commit-body alone systematically over-flags.

## Consumers

- `pr-without-workitem-scan@0.2.x` — daily fleet-wide scan; uses the regex + reconciliation for the per-repo and roll-up reports.
- `breaking-change-paper-trail@0.1.x` — daily catchup + (iter 5+) PR webhook hook; uses the WI-link absence as a precondition for retroactive WI auto-creation.

Future consumers (fleet-WI-discipline-trend, BC-discipline-roll-up, weekly-em-report) MUST inherit this rule when they ship.

## Related

- `.claude/rules/verification-protocol.md` — FETCH BEFORE CITE; ACTUAL BEFORE PRESENT (PR-relation API is the actual signal; commit body is one of two)
- `.claude/rules/no-silent-deferrals.md` — narrowing the regex without discussion = silent deferral of detection coverage
- `.claude/rules/skill-standards.md` — Dimension 3 (Standards section) requires citing inherited rules verbatim

## Changelog

- **2026-05-07 (iter 6)** — Initial author. Extracted from `pr-without-workitem-scan@0.2.0` Standards section + iter3-N4 finding (canonical regex needs single source of truth across consumers).
