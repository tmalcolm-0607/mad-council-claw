# Template — Claude Code diagnostic report

Canonical shape for `/debug-claude` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Diagnostic Report — <ISO date>

**Operator**: <alias>
**Symptom (verbatim from user)**: <quoted>

## Environment

- Claude Code version: <output of `claude --version`>
- Platform: <Win/Linux/Mac>
- Shell: bash | pwsh
- Hooks registered: N
- MCP servers: <list>

## Probes

For each suspected category:

### Hooks

| Hook | Registered? | Path resolves? | Dry-run exit code | Stderr |
|------|-------------|----------------|-------------------|--------|
| pre-bash-validate | yes | yes | 0 | — |
| validate-quality-gates | yes | NO (path missing) | — | — |

### MCP

| Server | Status | Tool count | Last error |
|--------|--------|------------|------------|
| workiq | down | 0 | "session expired" |
| msft-learn | up | 3 | — |

### Skills

| Skill | Frontmatter parses? | path resolves? |
|-------|---------------------|----------------|
| mad-spec | yes | yes |
| custom-foo | NO (allowed-tools nested wrongly) | — |

## Findings

For each issue: cite file:line + severity + suggested fix.

## Verdict

ACCEPT — diagnostic complete; user reviews fixes.
REJECT — environment broken; cannot continue session safely.
```

## Anti-hallucination

- Never claim a hook works without dry-running it
- Never claim a skill loads without parsing its frontmatter
- FETCH BEFORE CITE on every probe
