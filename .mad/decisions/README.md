# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records documenting significant technical decisions for this project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. ADRs follow [Michael Nygard's format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

## Format

Each ADR follows the naming convention: `NNN-slug-title.md`

Where:
- `NNN` = Sequential three-digit number (001, 002, 003...)
- `slug-title` = Lowercase, hyphen-separated title

### Required Sections

```markdown
# [Number]. [Title]

Date: YYYY-MM-DD
Status: [Proposed | Accepted | Rejected | Deprecated | Superseded by ADR-XXX]

## Context
[What is the issue that we're seeing that motivates this decision?]

## Decision
[What is the change that we're proposing and/or doing?]

## Consequences
[What becomes easier or harder to do because of this change?]
```

## Status Lifecycle

```
Proposed ──┬──► Accepted ──┬──► Deprecated
           │               │
           └──► Rejected   └──► Superseded by [ADR-XXX]
```

- **Proposed**: Decision under consideration
- **Accepted**: Decision approved and implemented
- **Rejected**: Decision not adopted (kept for historical context)
- **Deprecated**: Decision no longer applies (conditions changed)
- **Superseded**: Replaced by a newer decision (link to replacement)

## Managing ADRs

Use the `/mad-adr` skill to manage ADRs:

```bash
# Create a new ADR
/mad-adr "Use PostgreSQL for primary database"

# List all ADRs
/mad-adr list

# Update ADR status
/mad-adr accept 001
/mad-adr reject 002
/mad-adr deprecate 003
/mad-adr supersede 001 005  # ADR 001 superseded by ADR 005
```

## Numbering Rules

1. Numbers are **sequential** starting from 001
2. Gaps are **NOT filled** - if ADR 003 is deleted, next ADR is still the next available number
3. Numbers are **zero-padded** to 3 digits (001, 002, ... 099, 100)

## Index

| # | Title | Status | Date |
|---|-------|--------|------|
| 001 | [Fat-plugin path resolution over thin-shim relative paths](001-fat-plugin-path-resolution.md) | Accepted | 2026-04-21 |
| 002 | [Exhaustive enumeration over ruthless filtering for kit inventories](002-exhaustive-enumeration-over-ruthless-filtering.md) | Accepted | 2026-04-21 |
| 003 | [Context-before-action: three failure modes from the 2026-04-22 MAD install session](003-context-before-action-three-failure-modes.md) | Accepted | 2026-04-22 |

*This index is automatically updated by the `/mad-adr` skill.*
