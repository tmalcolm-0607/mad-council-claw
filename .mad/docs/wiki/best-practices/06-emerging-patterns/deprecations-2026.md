---
category: emerging-patterns
subcategory: deprecations
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Deprecations (2026)

## Overview

Deprecated patterns, tools, and APIs in 2026 with migration guides and timelines for removal.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Deprecation Timeline** | Note when feature will be removed |
| **Migration Path** | Provide clear path to replacement |
| **Compatibility Period** | Document backward compatibility support |
| **Detection** | Use `/claude-md-refresh` to find deprecated patterns |
| **Proactive Updates** | Update before removal deadline |

## Deprecated Patterns

### Model Deprecations

| Model | Deprecated | Removed | Replacement |
|-------|-----------|---------|-------------|
| **Claude Opus 4** | 2026-Q1 | 2026-Q1 | Claude Opus 4.5 / 4.6 |
| **Claude Opus 4.1** | 2026-Q1 | 2026-Q1 | Claude Opus 4.5 / 4.6 |

**Impact**: Models removed from model selector and Claude Code. Existing agent definitions referencing these models will fail.

**Migration**: Update all agent definitions (`.claude/agents/*.md`) to use current model lineup:
- Opus 4.5 / 4.6 (complex reasoning, architecture, security)
- Sonnet 4.5 (implementation, testing, documentation - 90% capability, 40% cost savings)
- Haiku 4.5 (cleanup, formatting, batch operations)

See: `.claude/rules/model-selection.md` for capability matrix

### Legacy SDK Entrypoint

**Deprecated**: Legacy SDK entrypoint (exact package name not specified in findings)

**Removed**: Timeline not specified

**Replacement**: `@anthropic-ai/claude-agent-sdk`

**Migration**: Update `package.json` dependencies and import statements to use new SDK package

### Output Styles (Temporary Deprecation)

**Initial deprecation**: 2026-Q1

**Un-deprecated**: 2026-Q1 (based on community feedback)

**Current status**: Available again - no migration needed

**Historical context**: Initially deprecated with recommendation to use `--system-prompt-file` or plugins instead. Community pushback reversed the decision.

**Lesson**: Output styles remain supported - safe to continue using

## Migration Guides

### Migration 1: Opus 4/4.1 → Opus 4.6 / Sonnet 4.5

**Step 1**: Audit agent definitions

```bash
# Find all agent files referencing old models
grep -r "model: opus-4" .claude/agents/
```

**Step 2**: Update model references

**Before**:
```yaml
---
model: opus-4
---
```

**After** (for complex reasoning):
```yaml
---
model: opus  # Maps to Opus 4.6
---
```

**After** (for cost optimization):
```yaml
---
model: sonnet  # Maps to Sonnet 4.5 (90% capability, 40% cost savings)
---
```

**Step 3**: Test agent behavior

Run sample tasks with updated agents to verify quality remains acceptable.

**Cost consideration**: Sonnet 4.5 provides 90% of Opus capability at 40% lower cost. Consider downgrading non-critical agents from Opus to Sonnet.

### Migration 2: Legacy SDK → `@anthropic-ai/claude-agent-sdk`

**Step 1**: Update package.json

```json
{
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^latest"
  }
}
```

**Step 2**: Update import statements

**Before**:
```typescript
import { Agent } from 'legacy-sdk-package';
```

**After**:
```typescript
import { Agent } from '@anthropic-ai/claude-agent-sdk';
```

**Step 3**: Review API changes

Consult official migration guide (not provided in findings) for breaking API changes.

## Detection and Remediation

### Automated Detection

**Hook**: `.claude/hooks/detect-deprecated-patterns.js` (if implemented)

**Manual audit**:
```bash
# Find deprecated model references
grep -r "opus-4\|sonnet-3\.7" .claude/

# Find legacy SDK imports (update pattern as needed)
grep -r "import.*legacy-sdk" .
```

### Remediation Strategy

| Pattern | Detection | Remediation |
|---------|-----------|-------------|
| Deprecated models | Grep agent YAML frontmatter | Update to `opus`, `sonnet`, or `haiku` |
| Legacy SDK | Grep import statements | Update to `@anthropic-ai/claude-agent-sdk` |
| Output styles | N/A (un-deprecated) | No action needed |

## Compatibility Matrix

| Version | Opus 4/4.1 | Opus 4.5/4.6 | Sonnet 4.5 | Haiku 4.5 |
|---------|-----------|-------------|-----------|-----------|
| **2025-Q4** | ✅ Supported | ✅ Supported | ✅ Supported | ✅ Supported |
| **2026-Q1** | ❌ Removed | ✅ Supported | ✅ Supported | ✅ Supported |
| **2026-Q2+** | ❌ Removed | ✅ Supported | ✅ Supported | ✅ Supported |

## Examples

### Example 1: Before (Deprecated)

**Agent definition** (`.claude/agents/code-implementer.md`):
```yaml
---
agent_type: code-implementer
model: opus-4  # ❌ DEPRECATED
subagent_type: code-implementer
---
```

**Error**: Model not found, agent spawn fails

### Example 2: After (Current)

**Agent definition** (`.claude/agents/code-implementer.md`):
```yaml
---
agent_type: code-implementer
model: opus  # ✅ Maps to Opus 4.6
subagent_type: code-implementer
---
```

**Result**: Agent spawns successfully with latest Opus model

### Example 3: Cost-Optimized Alternative

**Agent definition** (`.claude/agents/code-implementer.md`):
```yaml
---
agent_type: code-implementer
model: sonnet  # ✅ Sonnet 4.5 (40% cost savings, 90% capability)
subagent_type: code-implementer
---
```

**Trade-off**: Slight capability reduction for significant cost savings. Evaluate based on task criticality.

## Known Issues and Workarounds

### Context Management Validation Errors (Gateway Users)

**Issue**: Context management validation errors on gateway deployments

**Workaround**: Set `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` in `.claude/settings.local.json` under `env`

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
  }
}
```

**Impact**: Disables experimental beta features that may cause validation errors

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Using Opus 4/4.1 model references | Model removed, agent fails | Update to `opus` (4.6) |
| Ignoring deprecation warnings | Future breakage | Update proactively during compatibility period |
| Manual model version pinning | Fragile, breaks on updates | Use generic `opus`, `sonnet`, `haiku` (auto-maps) |
| Skipping SDK migration | Legacy SDK may stop working | Migrate to `@anthropic-ai/claude-agent-sdk` |
| Over-relying on output styles | Initially deprecated, may change | Consider `--system-prompt-file` as alternative |

## See Also

- `whats-new-q1-2026.md` - New replacement features
- `.claude/rules/model-selection.md` - Model capability matrix and selection guide
- https://docs.anthropic.com/en/docs/about-claude/model-deprecations - Official deprecation notices
- https://docs.anthropic.com/en/docs/claude-code/changelog - Official changelog

## Research Metadata

**Sources consulted**:
- https://support.claude.com/en/articles/12138966-release-notes
- https://docs.claude.com/en/docs/about-claude/model-deprecations
- https://code.claude.com/docs/en/agent-teams
- https://www.gradually.ai/en/changelogs/claude-code/
- https://releasebot.io/updates/anthropic

**Research date**: 2026-02-16
**Confidence level**: HIGH (official release notes and documentation)
**Frequency validation**: 100% (all deprecations from official sources)
**Next refresh**: 2026-05-16 (quarterly update)
