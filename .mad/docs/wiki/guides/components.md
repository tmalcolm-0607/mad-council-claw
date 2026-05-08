# Component Reference: Unified AI Development Kit

Detailed reference for each unified kit component.

## C4 Diagram Generation (`/mad-c4`)

### Purpose
Generate C4 architecture diagrams from plan.md infrastructure sections.

### Usage

```bash
/mad-c4                    # Generate all levels
/mad-c4 --level context    # Context diagram only
/mad-c4 --level container  # Container diagram only
/mad-c4 --level component  # Component diagram only
/mad-c4 --format plantuml  # Use PlantUML format
```

### Output Files

| File | Contents |
|------|----------|
| `diagrams/c4-context.md` | System boundary, external actors |
| `diagrams/c4-container.md` | Deployable units (frontend, backend, DB) |
| `diagrams/c4-component.md` | Internal structure of containers |

### Input Sources

The skill reads from plan.md sections:

| Section | Maps To |
|---------|---------|
| Summary | System description |
| Technical Context | Technology decisions |
| Project Structure | Container breakdown |
| Infrastructure | Component structure |

### Integration

During `/mad-plan`, C4 diagrams auto-generate after the Infrastructure section is complete.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Diagrams not generating | Check plan.md has Infrastructure section |
| Empty Container diagram | Add Project Structure section to plan |
| Mermaid syntax errors | Validate in https://mermaid.live |

---

## Architecture Decision Records (`/mad-adr`)

### Purpose
Document significant technical decisions with context, rationale, and consequences.

### Usage

```bash
/mad-adr "Decision title"    # Create new ADR (default)
/mad-adr create "Title"      # Create new ADR (explicit)
/mad-adr list               # List all ADRs
/mad-adr show 001           # Display ADR contents
/mad-adr accept 001         # Change status to Accepted
/mad-adr reject 001         # Change status to Rejected
/mad-adr deprecate 001      # Change status to Deprecated
/mad-adr supersede 001 002  # Mark 001 superseded by 002
```

### Storage Location

ADRs are stored in `.claude/decisions/` with format `NNN-slug.md`:

```
.claude/decisions/
├── README.md
├── 001-use-postgresql.md
├── 002-use-mermaid-diagrams.md
└── 005-adopt-typescript.md
```

### ADR Structure

```markdown
---
id: 1
title: Use PostgreSQL for primary database
status: Proposed
date: 2026-01-21
supersedes: null
superseded_by: null
---

# 1. Use PostgreSQL for primary database

Date: 2026-01-21
Status: Proposed

## Context
[Why this decision is needed]

## Decision
[What was decided]

## Consequences
[Positive/negative impacts]
```

### Status Lifecycle

```
Proposed ──┬── accept ──> Accepted ──┬── deprecate ──> Deprecated
           │                         │
           └── reject ──> Rejected   └── supersede ──> Superseded
```

### Numbering Rules

1. Sequential from 001
2. Gaps are preserved (deleted ADRs leave gaps)
3. Next number = max(existing) + 1

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Wrong number assigned | Check `.claude/decisions/` for existing files |
| Status won't change | Check current status allows transition |
| Supersede fails | Verify both ADR numbers exist |

---

## Staleness Detection (`--check-staleness`)

### Purpose
Detect when source files have changed since a baseline was captured, preventing false confidence from testing stale code.

### Workflow

1. **Capture baseline** after tests pass
2. **Modify code** during development
3. **Check staleness** before verification
4. **Warning/Error** if files changed

### Usage

```bash
# Capture baseline
.claude/scripts/powershell/capture-baseline.ps1 -WorkItem WI-001

# Check staleness (warn on stale)
/mad-validate --check-staleness

# Check staleness (fail on stale)
/mad-validate --check-staleness --strict

# Check specific work item
/mad-validate --check-staleness --work-item WI-001
```

### Hash Manifest

Baseline is stored in `.claude/work-items/<id>/hash-manifest.json`:

```json
{
  "work_item_id": "WI-001",
  "captured_at": "2026-01-21T14:30:00Z",
  "git_commit": "abc123...",
  "include_patterns": ["src/**/*", ".claude/**/*.md"],
  "exclude_patterns": ["**/*.test.*"],
  "files": [
    {"path": "src/index.ts", "hash": "e3b0c44...", "size": 1234}
  ]
}
```

### Detection States

| State | Meaning | Non-Strict | Strict |
|-------|---------|-----------|--------|
| FRESH | No changes | Continue | Continue |
| STALE | Files modified | Warn | Error |
| INCOMPLETE | Files missing | Warn | Error |
| SKIP | No baseline | Continue | Continue |

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Always shows SKIP | Capture baseline first |
| Wrong files tracked | Adjust -IncludePatterns |
| Hash mismatch (no change) | Verify file encoding/line endings |

---

## Integration Verification

### Purpose
Verify MAD skills work correctly with orchestration patterns.

### Structural Signals (6 checks)

| # | Signal | Location |
|---|--------|----------|
| 1 | ORCHESTRATOR rule | `.claude/rules/orchestration.md` |
| 2 | Work items directory | `.claude/work-items/` |
| 3 | Core agents | `.claude/agents/` (7+ files) |
| 4 | Verification spec schema | `.claude/schemas/verification-spec.md` |
| 5 | Trust-but-verify rule | `.claude/rules/trust-but-verify.md` |
| 6 | Plan management rule | `.claude/rules/plan-management.md` |

### MAD Gates (8 checks)

1. mad-spec creates spec.md
2. mad-plan creates plan.md
3. mad-tasks creates tasks.md
4. mad-implement executes phases
5. mad-validate runs suite
6. mad-c4 generates diagrams
7. mad-adr manages decisions
8. Staleness detection works

### Running Integration Check

```bash
# Run full validation (includes integration)
/mad-validate

# Check integration status section in output
# Expected: 6/6 signals pass
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Missing rules | Copy from unified-kit `.claude/rules/` |
| Missing agents | Copy from unified-kit `.claude/agents/` |
| Work items not routing | Create ACTIVE file |

---

## Quick Reference

### All Skills

| Skill | Purpose |
|-------|---------|
| `/mad-spec` | Create specifications |
| `/mad-plan` | Generate plans + C4 |
| `/mad-tasks` | Break into tasks |
| `/mad-implement` | Execute phases |
| `/mad-validate` | Run validation |
| `/mad-c4` | Generate C4 diagrams |
| `/mad-adr` | Manage ADRs |
| `/mad-full` | Full pipeline |

### Key Files

| File | Purpose |
|------|---------|
| `.claude/decisions/*.md` | Architecture decisions |
| `.claude/work-items/sessions/<session-id>` | Current work item (per-session) |
| `specs/*/diagrams/c4-*.md` | C4 diagrams |
| `.claude/work-items/*/hash-manifest.json` | Staleness baseline |

### Common Commands

```bash
# Feature development
/mad-spec "Add authentication"
/mad-plan
/mad-tasks
/mad-implement --phase 1

# Architecture decisions
/mad-adr "Use PostgreSQL"
/mad-adr accept 001

# Verification
.claude/scripts/powershell/capture-baseline.ps1 -WorkItem WI-001
/mad-validate --check-staleness
```
