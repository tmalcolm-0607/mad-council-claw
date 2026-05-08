# Parallel Execution Plan

Generated from: {SOURCE_PATH}
Generated on: {DATE}
Total features: {FEATURE_COUNT}
Total waves: {WAVE_COUNT}
Worktree root: {WORKTREE_ROOT}

## Dependency Graph

```
{DEPENDENCY_GRAPH_ASCII}
```

## Wave Assignments

### Wave {N}: {WAVE_TITLE}

| Feature | Slug | Depends On | Est. Files | Worktree Path | Status |
|---------|------|------------|------------|---------------|--------|
| {TITLE} | {SLUG} | {DEPS} | {FILE_COUNT} | {WORKTREE_PATH} | Pending |

### Shared Files (Merge-Time Resolution)

| File | Features | Resolution Strategy |
|------|----------|---------------------|
| {FILE_PATH} | {FEATURE_LIST} | {STRATEGY} |

## Feature Status

### {SLUG}: {TITLE}

| Phase | Status | Artifacts | Gate Result |
|-------|--------|-----------|-------------|
| Worktree Setup | {STATUS} | {WORKTREE_PATH} | {GATE} |
| Spec | {STATUS} | specs/{NNN}-{SLUG}/spec.md | {GATE} |
| Plan | {STATUS} | specs/{NNN}-{SLUG}/plan.md | {GATE} |
| Tasks | {STATUS} | specs/{NNN}-{SLUG}/tasks.md | {GATE} |
| Analyze | {STATUS} | specs/{NNN}-{SLUG}/analysis-report.md | {GATE} |
| Implement | {STATUS} | src/ files | {GATE} |
| Validate | {STATUS} | validation report | {GATE} |
| Merge | {STATUS} | commit hash | {GATE} |
| Cleanup | {STATUS} | worktree removed | {GATE} |

## Execution Log

### Wave {N}

| Timestamp | Event | Feature | Details |
|-----------|-------|---------|---------|
| {TIMESTAMP} | {EVENT} | {SLUG} | {DETAILS} |

## Summary

| Metric | Value |
|--------|-------|
| Features completed | {COMPLETED}/{TOTAL} |
| Waves completed | {WAVES_COMPLETED}/{WAVE_COUNT} |
| Merge conflicts | {CONFLICT_COUNT} |
| Total duration | {DURATION} |
| Agent team spawns | {SPAWN_COUNT} |
