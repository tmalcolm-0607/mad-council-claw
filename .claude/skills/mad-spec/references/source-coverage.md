# Source Coverage Validation

This step ensures ALL workflows from source documents are captured in the spec.

## When to Use

**CRITICAL**: This step is MANDATORY when source documents are referenced. Skipping this step led to missing 5 critical workflows in past specifications.

## Validation Process

### a. Identify source documents

Check for referenced documents in the feature description:
- Look for file paths (e.g., `specs/ideas/*.md`, `docs/*.md`)
- Look for phrases like "based on", "from the idea document", "per the requirements"
- If source documents exist, they MUST be analyzed for completeness

### b. Extract all workflows from source

**If source documents exist**:

```
For each source document:
  1. Read the document
  2. Extract ALL workflows, mechanics, and processes mentioned:
     - State transitions (e.g., "when X happens, do Y")
     - User journeys (e.g., "player can...", "DM initiates...")
     - Game mechanics (e.g., "death moves", "rest system", "leveling")
     - Entity lifecycles (e.g., "created → active → completed")
  3. Create a SOURCE_WORKFLOWS list with:
     - Workflow name
     - Key triggers/conditions
     - Expected outcomes
```

### c. Cross-reference with generated spec

```
For each item in SOURCE_WORKFLOWS:
  - Search spec for matching user story or functional requirements
  - Mark as: COVERED (user story exists) or GAP (not found)
```

### d. Handle gaps

**BLOCKING** - do not proceed with gaps:

If gaps exist, present them to the user:

```markdown
## Source Coverage Gaps Detected

The following workflows from [source document] are NOT covered in the spec:

| # | Workflow | Source Location | Impact |
|---|----------|-----------------|--------|
| 1 | [name] | [section/line] | [why it matters] |
| 2 | [name] | [section/line] | [why it matters] |

**Action Required**: Choose one:
- A) Add these as new user stories (recommended)
- B) Explicitly exclude with documented rationale
- C) Mark as out-of-scope for this phase

**Your choice**: _[Wait for user response]_
```

After user response:
1. Update spec accordingly
2. Re-run source coverage validation until all gaps are addressed

### e. Document coverage in spec

Add to spec's Assumptions section:

```markdown
## Source Document Coverage
- Source: [document path]
- Workflows identified: [count]
- Workflows covered: [count]
- Explicitly excluded: [list with rationale, if any]
```

## Output Reporting

When source documents exist, include this in completion report:

```
Source Documents Analyzed: [list]
Workflows Identified: [count]
Workflows Covered: [count]
Gaps Found: [count] - [resolved/pending]
```
