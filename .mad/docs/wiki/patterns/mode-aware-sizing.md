# Pattern: Mode-Aware Sizing

**Canonical name:** Mode-Aware Sizing. Variants: *CI vs interactive mode*, *auto vs propose*, *fast vs full*, *batch vs streaming*, *unattended vs attended*.

**One-line definition:** A skill offers multiple execution modes (e.g., `auto` / `propose`, `fast` / `full`). Behavior adapts — including which patterns apply, how many sub-agents run, what consent gates fire — based on whether a human is in the loop.

## When to use

- Skills that run in both CI/CD (no human) and interactive (human curator) contexts.
- Skills where sub-agent ensembles add cost that's justified only when the output lands without review.
- Skills with destructive actions gated on user consent — which makes no sense in automated mode.
- Workflows where the same output can be used for "decide" vs "propose for human decide."

## When NOT to use

- Single-context skills (always interactive, always automated). Don't invent a mode you don't need.
- Skills where "fast mode" is just "skip safety checks." That's not mode-awareness, that's skipping rules.

## Core mechanics

```
/skill <args> --mode <auto | propose | review | silent | ...>
                  ↓
Mode determines:
  - Which sub-agents run (ensemble vs single)
  - Which consent gates fire (all vs interactive-only)
  - Which output is emitted (final-decision vs draft-for-curation)
  - Which fallbacks apply (degrade-silently vs ask-user)
```

The key: **the mode is declared by the caller**, not inferred at runtime. Inference is a bug — a skill that "thinks it's in interactive mode" when a cron is driving it produces stuck interactive prompts.

## Canonical modes (from marketplace)

### `auto` / `propose` (`review-verdict`)

- `--mode auto` (CI/CD, no human curator present):
  - Runs 3-model ensemble for max comment quality (no human to filter false positives).
  - Publishes comments directly to PR.
  - Skips interactive Q&A loop (no one to answer).
  - Uses conservative consent defaults (block destructive in daemon mode unless trust-tier elevated).

- `--mode propose` (interactive, human curates):
  - Single Opus agent (user filters, ensemble overhead unnecessary).
  - Outputs proposed diffs; user applies selectively.
  - Enters Q&A loop for "any questions about the findings?"

### `review` / `report` / `silent` (`pr-review-critic`)

- `review` — post comments to PR.
- `report` — generate report file only; no PR interaction.
- `silent` — no output to PR; useful when running in a pipeline that aggregates elsewhere.

### `develop:` / `just fix:` (`server-migration/develop`)

- `develop:` — full flow with Gateway Expert review + draft PR.
- `just fix:` — quick flow; user controls git.

### `--fast` / default (`review-swarm`)

- `--fast` — orchestrator does all areas single-pass; no sub-agents.
- default — spawns Breaker + Exploiter + Inspector in parallel.

### `MINIMAL` / `STANDARD` / `FULL` (`mad-tasks`)

- Auto-selects by story count + escalation keywords.
- `MINIMAL` — flat task list (≤3 stories, no escalation).
- `STANDARD` — grouped by phase + dependency graph (4-10 stories).
- `FULL` — full MAD with parallel examples + per-phase verification (>10 stories, or high complexity).

## Pros

- **Right-sized cost.** Don't pay ensemble cost when a curator will filter anyway. Don't skip ensemble when no curator exists.
- **Explicit design decisions.** Each mode's behavior is a declared choice, not emergent.
- **Safer in CI.** Automated mode is conservative by default — destructive ops blocked, consent gates treated as refusals.
- **Usable interactively.** Interactive mode is responsive — no forced ensemble delay, Q&A loop available.
- **Discoverable.** Users see `--mode` in the help and know there's a choice to make.
- **Matches patterns to contexts.** `wiki/patterns/multi-role-review.md` §5.6 applies ensemble only in auto; matches the real-world contexts.

## Cons

- **Mode explosion.** If you have 5 modes, testing is 5× the work.
- **Mode drift.** As the skill evolves, some modes accumulate features the other modes don't have.
- **Wrong-mode-selected footguns.** User runs `--mode auto` locally, gets blocked consent gates, thinks the skill is broken.
- **Implicit mode inference is tempting and wrong.** Don't try to "detect" mode; require explicit declaration.

## Do / Don't

**Do**:

- **Pick 2–4 modes max.** More than that = you're under-decomposed.
- **Name modes by intent, not implementation.** `auto` / `propose` is better than `ensemble` / `single`.
- **Default to the safer mode.** `propose` is safer than `auto`. `review` is safer than `apply`. Default protects the careless invoker.
- **Document each mode's differences explicitly.** In one table, side-by-side. Reader should see the whole decision.
- **Require consent elevation to pick dangerous modes.** `auto` mode may need a `--trust-tier` flag to unlock.
- **Align mode with contextual patterns.** `auto` → ensemble + conservative gates. `propose` → single model + interactive gates.
- **Test all modes.** If you add a mode, add a fixture in `evals/`.
- **Make mode visible in output.** Include `"mode": "auto"` in reports, logs, PR comments. Consumers should know which mode produced the output.

**Don't**:

- **Don't infer mode at runtime.** "This looks like CI, I'll pick auto" → wrong when it isn't.
- **Don't let modes diverge semantically.** All modes do "the same thing" at different resolutions; if auto and propose produce different outputs, you have two skills, not modes.
- **Don't hide modes in undocumented flags.** If `--secret-dangerous-mode` exists, document it or remove it.
- **Don't rely on environment variables alone.** Command-line flag is authoritative; env can be a default, not an override.
- **Don't skip consent gates in any mode without declaring it.** If `auto` skips consent, that's a declared behavior, not a bug-feature.

## Common pitfalls

### Prompted for consent in daemon mode

Skill runs under cron; hits a consent gate; waits forever for a response. Mitigation: `auto` mode blocks gate-requiring ops by default or elevates via trust-tier.

### Ensemble in interactive mode

User running `--mode propose` sees 3-model ensemble fire and wait 30s. Expected 5s response. Mitigation: interactive defaults to single model.

### Mode overridden by config file

`--mode auto` on command line; config file says `mode: propose`. Which wins? Canonical answer: CLI flag overrides config.

### Mode leakage across invocations

Skill runs in auto mode, writes output. Next invocation in propose mode reads the output and processes it assuming propose mode semantics. Mitigation: include mode in output metadata; downstream consumers check.

## Interaction with other patterns

- **+ `wiki/patterns/multi-model-ensemble.md`** — ensemble is typically enabled only in auto mode.
- **+ `rules/dangerous-operations-policy.md`** — consent gates fire interactively; auto mode treats them as block-by-default.
- **+ `wiki/patterns/bounded-iteration-caps.md`** — caps may differ per mode (tighter in auto).
- **+ `wiki/patterns/multi-role-review.md`** — Council mode determines role count (full ensemble vs single per role).

## MAD.Council specifics

MAD.Council uses modes in several places (per `mad.council.a2a.md`):

- **`/council-review --mode auto | propose`** (§11.5) — ensemble enabled in auto, single-role in propose.
- **`/council-review --ensemble`** — orthogonal flag, explicitly enables multi-model even in propose.
- **`/council-review --alias-set court | construct`** — cosmetic role naming.
- **`/council-post --transport local | a2a-http | a2a-stream | a2a-push`** — transport is a per-message mode.
- **`/council-post --force-raw`** — suppress literal-phrase ban tag (use for docs of attack examples).
- **MAD tasks tier**: automatic (MINIMAL / STANDARD / FULL) by story count, per mad-tasks pattern.

Default modes:
- `/council-review` default = `propose` (safer).
- `/council-post` default transport = `local`.
- Tasks tier = auto-detected.

## References

- `plugins/review-verdict/skills/review-verdict/references/phase-3.5-comments.md` — auto vs propose pattern source.
- `plugins/review-swarm/skills/review-swarm/SKILL.md` — `--fast` flag source.
- `plugins/pr-review-critic/agents/pr-review-critic.md` — review/report/silent modes.
- `plugins/server-migration/skills/develop/SKILL.md` — `develop:` / `just fix:` dual-mode.
- `plugins/dotnet-dev-kit/skills/mad-tasks/SKILL.md` — MINIMAL/STANDARD/FULL tiering.
- `mad.council.a2a.md` §5.6, §11.5 — Council mode spec.
- CHECKLIST pattern #43 — mode-aware ensemble sizing.
- CHECKLIST pattern #47 — `--fast` flag.
- CHECKLIST pattern #52 — review modes (review/report/silent).
- CHECKLIST pattern #98 — dual-mode workflow skill.
