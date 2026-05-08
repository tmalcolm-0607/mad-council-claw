---
name: lens-engineering-craftsmanship
description: Generic voice-aware authoring toolkit for LENS engineering communication. Learns the user's voice from WorkIQ (Teams chats, emails, prior writeups), generates a personal style-reference, and validates new content against the learned profile. Use when drafting Connect content, peer Perspective feedback, PR comments, Teams responses, or design docs - and when bootstrapping a new engineer onto the toolkit.
version: 1.0.0
user_invocable: true
author: tonym
tags: [voice, learning, connect, peer-feedback, validation, throttle-backoff, lens]
category: communication
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - mcp__workiq__ask_work_iq
tier-exempt: [multi-pass, best-practices, standards]
---

# LENS Engineering Craftsmanship

A **process-driven** authoring toolkit. The skill itself does not encode any one engineer's voice. It encodes the workflow for *learning* a voice from real communication artifacts, persisting that learned profile, and applying it to new content.

## When to use this skill

- A LENS engineer is preparing a Connect, peer Perspective feedback, or any other narrative artifact and wants the authoring assistant to match their actual voice (not generic LLM prose).
- A new engineer joins the team and needs to bootstrap their own authoring profile.
- An existing profile needs refresh after a role change, team change, or significant project shift.
- Background validation is needed during drafting (lint while writing).

## Core idea

**The user's voice is data, not prose.** It lives in their Teams replies, emails, PR comments, and prior writeups. The skill's job is to:

1. **Learn**: query WorkIQ and local artifacts to extract the user's actual sentence patterns, vocabulary, tone, and anti-patterns.
2. **Persist**: write a `style-reference.md` per user as the durable profile.
3. **Apply**: lint and validate new content against that learned profile.
4. **Refresh**: re-run the learning step periodically as the user's voice evolves.

The skill ships **no user-specific content** in its body. Tony's rules, anyone else's rules, and any team's house style are all *outputs* of running this skill, not inputs.

## Workflow

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Phase 1: LEARN                                                          │
│                                                                          │
│  scripts/learn-voice-from-workiq.ps1 -User <alias>                       │
│    → queries WorkIQ for last 60-90 days of Teams chats, emails, replies  │
│    → analyzes sentence length, vocabulary, sentence patterns, anti-      │
│       patterns, formatting habits                                        │
│    → writes .mad/voice-profiles/<alias>/style-reference.md               │
│    → uses scripts/loop-with-backoff.ps1 to handle WorkIQ throttling      │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Phase 2: SEED with prior artifacts (optional)                           │
│                                                                          │
│  scripts/seed-from-prior-artifacts.ps1 -ArtifactDir <path>               │
│    → augments the WorkIQ-derived profile with prior Connects, PR         │
│       comments, design docs the user has authored                        │
│    → reconciles with the learned profile (latest wins on conflict)       │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Phase 3: APPLY                                                          │
│                                                                          │
│  scripts/style-lint.ps1 -Path <draft.md> -Profile <profile-path>         │
│    → reads the learned style-reference.md as rules                       │
│    → flags violations (em-dashes, AI-slop, banned phrases, etc.)         │
│    → reports per-line violations with fix hints                          │
│                                                                          │
│  scripts/connect-validate.ps1 -Path <connect-draft.md> -Profile <p>      │
│    → measures section character limits                                   │
│    → runs style-lint                                                     │
│    → reports pass/fail per section                                       │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  Phase 4: REFRESH                                                        │
│                                                                          │
│  Re-run Phase 1 quarterly or after significant role/team changes.        │
│  Diff the new profile against the prior version; the user reviews any    │
│  meaningful drift and accepts or rejects per-rule.                       │
└──────────────────────────────────────────────────────────────────────────┘
```

## What's in a style-reference (the learning output)

A learned profile is plain markdown with structured sections that the linter can parse:

```yaml
---
user: <alias>
generated_utc: <iso-timestamp>
sources:
  - workiq:teams:30d
  - workiq:email:30d
  - local:.mad/work-items/<wi>/inputs/prior-*
sample_count: <N>  # number of artifacts analyzed
---

# Voice profile: <alias>

## Tone
- (one or more bullets describing the observed tone)

## Sentence patterns
- (sentence templates the user actually uses)

## Vocabulary
- (specific word choices, including misspellings the user prefers as-is)

## Formatting habits
- (em-dashes used? bullets vs prose? structured headers?)

## Banned phrases (anti-patterns)
- (corp-speak the user does not use)

## Hard rules
- (e.g. no Co-Authored-By trailer)

## Character limits (per artifact type)
- connect.results: <N>
- connect.setbacks: <N>
- connect.how: <N>
- ... (any others the user works against)

## Example artifacts referenced
- (paths to canonical examples, not embedded)
```

The linter reads this file at runtime. **The skill body has no rules of its own** - all rules come from the learned profile.

## Throttle and backoff (for the LEARN phase)

WorkIQ rate-limits to roughly N queries per hour. The learning phase uses `scripts/loop-with-backoff.ps1` to:

- Process artifacts in batches with a base delay between batches.
- On a 429 / "transport dropped" / "session expired" / "is not connected" signal, increase the delay (10 min → 30 min → 60 min cap).
- Persist a manifest at `.mad/voice-profiles/<alias>/manifest.json` so a partial run resumes from where it left off.
- Always write the per-batch artifact to disk before requesting the next batch, so progress survives session restarts.

See [`docs/BACKOFF-PATTERNS.md`](docs/BACKOFF-PATTERNS.md) for the full pattern and applicability to other batched-WorkIQ workflows.

## Background reviews while drafting

The author can spawn a background style-lint that watches the draft file and re-runs on save. Use Claude Code's Bash tool with `run_in_background: true`:

```powershell
# In the foreground session, kick off the watcher:
powershell.exe -NoProfile -File .claude/skills/lens-engineering-craftsmanship/scripts/style-lint.ps1 `
    -Path my-draft.md -Profile .mad/voice-profiles/myalias/style-reference.md -Watch
```

The watcher writes lint reports to `.mad/scratch/lint-watch-<timestamp>.json` and the foreground draft session stays unblocked.

## Companion scripts

| Script | Purpose |
|---|---|
| `scripts/learn-voice-from-workiq.ps1` | Phase 1: extract a voice profile from WorkIQ. |
| `scripts/seed-from-prior-artifacts.ps1` | Phase 2: augment with local prior writeups. |
| `scripts/style-lint.ps1` | Phase 3: lint against a profile. |
| `scripts/connect-validate.ps1` | Phase 3: validate Connect drafts (limits + lint). |
| `scripts/loop-with-backoff.ps1` | Generic throttle-aware batch loop. Used by Phase 1. |

## Companion docs

- [`docs/BACKOFF-PATTERNS.md`](docs/BACKOFF-PATTERNS.md): the throttle / backoff / artifact-loop pattern that any WorkIQ-heavy skill should reuse.
- [`docs/INSTALLATION.md`](docs/INSTALLATION.md): how to install in a LENS repo and bootstrap a profile for the current user.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): the four-phase workflow in detail, including the file-system layout for voice profiles.

## Templates

Template files in [`templates/`](templates/) are *generic shapes*. They contain placeholders that the user's profile fills in. They contain no Tony-specific content, no team-specific assumptions, and no example word choices.

| Template | Shape provided |
|---|---|
| `connect-section.md` | Workstream block: name + Current Impact bullets + Contributors + Challenges + Projected Impact + Details |
| `setback.md` | Setback / Learning / Growth template |
| `peer-feedback.md` | Keep doing / Suggestion / Re-think / Example / Most value / Other thoughts |
| `skill-skeleton.md` | New skill scaffold matching this skill's frontmatter and body conventions |

## MS Connect Perspective form structure

Each peer Perspective response has **three sections**, each with **two prompts** (six fillable boxes total):

```
Keep doing...
  Here's something I think you do really well and hope you keep doing: <paragraph>
  Here's a suggestion for how you could leverage this strength further: <paragraph or "No response">

Re-think...
  Here's something you may want to re-think: <paragraph or "No response">
  Here's an example to consider for doing it another way: <paragraph or "No response">

Additional thoughts...
  The thing I most value about working with you is: <paragraph>
  Here are some other thoughts I have that you may want to consider: <paragraph or "No response">
```

The `Keep doing` and `The thing I most value about` boxes should always be substantive. The other four can be `"No response"` if no specific evidence supports content. Drafts that fill all six boxes only because the form has them are weaker than drafts that fill the substantive boxes deeply and leave the rest blank.

## Per-peer harvest workflow (multi-week WorkIQ coverage)

When preparing peer feedback at Connect-prep depth, follow this ordering:

1. **ADO query first** - free of throttling, gives epics/features/user-stories the peer authored or owns. Establishes the structural narrative.
2. **PR-thread mining second** - gives quotable peer-voice moments where you reviewed each other.
3. **WorkIQ week-by-week harvest third** - one-peer-one-week probes covering the full review period (typically 17 weeks for a half-cycle). Save each week's response as an artifact. See `docs/BACKOFF-PATTERNS.md` for the throttle pattern.
4. **Synthesis last** - only after all three sources are captured for a peer. Synthesize into the 6-box Perspective format. Lead each box with a concrete shared moment, not a generic claim.

Skipping the harvest and synthesizing early produces shallow feedback that misses dimensions outside PR data (PM partnerships, tooling adoption, livesite presence, cross-org work).

## Evals

[`evals/`](evals/) contains test fixtures and expected outputs for the linter and validator. Fixtures use *synthetic* content - no real engineer's voice is hard-coded. Each fixture pairs a "good" and "bad" example and asserts that the linter classifies them correctly against a reference profile.

## What this skill is NOT for

- **Code generation.** Use language-specific patterns and the implementer agents.
- **Hard-coded house style.** That belongs in a per-team or per-engineer style-reference profile, not in this skill's body.
- **One-off draft polishing.** This skill assumes a profile exists or can be learned. For one-off drafts without a profile, use a basic LLM with whatever style guidance the user provides inline.
- **Code-review semantics.** Use `code-reviewer` for that. Apply this skill's `style-lint` to the review *prose*, not the code.

## Where prior Tony-specific content went

The Tony-specific style-reference.md authored during the FY26 H2 Connect prep is a **profile output** of running this skill once for Tony. It lives at `.mad/work-items/connect-h2-2026/inputs/style-reference.md`, not in this skill's body. It serves as the canonical example of what a finished profile looks like.

When the LENS plugin marketplace ships, this skill will reference profile output paths via `~/.lens/voice-profiles/<alias>/style-reference.md` so each engineer's profile is portable across repos.
