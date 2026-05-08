# PR Description Template for Split PRs

Use this template for each PR in a split series.

## Template

```markdown
## [Feature Name] - Part {N} of {TOTAL}: {Short Description}

### Series Overview

This PR is part of a series that splits [{MAIN_PR_TITLE}](#{MAIN_PR_ID}) into focused, reviewable units.

| # | PR | Description | Status |
|---|-----|-------------|--------|
| 1 | [#{PR1_ID}]({PR1_URL}) | {PR1_desc} | {Merged/This PR/Pending} |
| 2 | [#{PR2_ID}]({PR2_URL}) | {PR2_desc} | ... |
| ... | ... | ... | ... |

### What This PR Does
- {bullet 1}
- {bullet 2}
- {bullet 3}

### What This PR Does NOT Include
- {thing in later PR with PR link}
- {another thing}

### Review Focus
- {Specific question for reviewers}
- {Pattern check request}

### Merge Order
This PR should be merged {before/after} #{OTHER_PR_ID}.

### How to Test
```
{commands to verify in isolation}
```

### Dependencies
- Depends on: #{DEP_PR_ID} ({status})
- Blocks: #{BLOCKED_PR_ID}
```

## Main PR Update Template

When updating the original (main) PR before closing:

```markdown
## This PR Has Been Split

This large PR ({FILE_COUNT} files, {LINE_COUNT} lines) has been split into {N} focused PRs for better reviewability.

### Child PRs (merge in order)

| # | PR | Description | Files | Lines |
|---|-----|-------------|-------|-------|
| 1 | [#{PR1_ID}]({URL}) | {desc} | {files} | {lines} |
| 2 | [#{PR2_ID}]({URL}) | {desc} | {files} | {lines} |
| ... | ... | ... | ... | ... |

### Merge Order
1. PR1 and PR3 can merge independently (no shared deps)
2. PR2 depends on PR1
3. PR4 depends on PR3
4. ...

### Why Split?
- Research shows PRs >400 lines get 40% fewer defect detections (SmartBear/Cisco, Propel)
- Each child PR is reviewable in under 45 minutes
- Tests are co-located with their feature code
```

## Guidelines

Based on research (Google, SmartBear, Propel, Graphite):

1. **"What This PR Does NOT Include"** is critical - it prevents reviewers from looking for missing code that's in a later PR
2. **Series Overview table** lets reviewers see the full picture and their PR's place in it
3. **Review Focus** directs attention to what matters most for this specific PR
4. **Merge Order** prevents out-of-order merges that break builds
5. Keep descriptions concise - 2-3 bullets per section max
