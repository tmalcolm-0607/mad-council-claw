# 08 — Behavioral reasoning

The "why" library. Every recurring discipline gets a file here that captures the WHY (not the WHAT — that's elsewhere).

## Planned files (populated as patterns emerge from waves)

- `multi-agent-fan-out.md` — why MR1: never single agent; ≥3 disjoint lanes per iter
- `short-iter-warm-cache.md` — why MR2: <5 min per iter preserves prompt cache (warm-cache zone <300s per `loop-cadence-discipline.md`)
- `canonical-skill-only.md` — why MAD artifacts only go through canonical skills (`/mad-spec`, `/mad-plan`, `/mad-tasks`, `/mad-analyze`, `/testplan`); inline authoring bypasses gates
- `deterministic-before-probabilistic.md` — why scripts collect facts and AI semantizes them, not the reverse
- `hooks-over-docs.md` — why recurring corrections become PreToolUse hooks (per memory entry "documented rules without hooks recur")
- `visibility-before-action.md` — why every act is preceded by evidence
- `skill-build-when-pitfalls-accumulate.md` — why ≥3 pitfalls = SKILL.md same session (per memory entry)
- `frontmatter-signature-contract.md` — why `generated-by:` + `generated-by-version:` + `skill-state-file-id:` distinguishes canonical from emulated artifacts
- `micro-session-discipline.md` — why small PRs + behavior tests + physical proof beats large multi-feature PRs (per Goals G21, G22, G23)

## Source

These map to `[K:rules/<rule>.md]` files in the MAD kit at `C:\Users\tonym\Repos\MAD - Clean\.claude\rules\`. Each file here MUST cite the kit rule it derives from + the failure mode it prevents.
