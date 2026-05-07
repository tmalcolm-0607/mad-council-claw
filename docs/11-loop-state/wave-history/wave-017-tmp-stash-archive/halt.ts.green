/**
 * F-018 Failure-pattern halt — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-018-failure-pattern-halt.md.
 * Behavior contract (verbatim from ledger):
 *   The engine watches a 9-value enum of trigger conditions:
 *     consecutive_failures_3, consecutive_failures_10, overplanning_5,
 *     overplanning_8, spawns_per_hour_exceeded, token_anomaly_2x,
 *     rapid_prompt_burst, circuit_breaker_open, degradation_threshold.
 *   When any trigger fires, the engine immediately transitions to `closing`
 *   with `halted_by: <trigger_name>` and `trigger_evidence_sha256: <audit_entry_sha>`.
 *   The retro signal (F-014) fires next, capturing the trigger evidence.
 *   Thresholds are sourced from `rules/anomaly-thresholds.md` and overridable
 *   per-run.
 *
 * Scope: this implementation lands the IN-MEMORY halt-detection primitive
 * (HaltDetector class) + the verdict shape (RunHaltedVerdict) that F-020
 * (kill-switch), F-021 (degradation-fallback), and F-022 (tool-quota) reuse.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 * RunHaltedVerdict + HaltTrigger live here as the FIRST owner per wave-011/lane-a
 * brief; halt.ts is the type's authoritative location and other features (F-020
 * KillSwitch, F-022 ToolCallQuota) import from here.
 */

/**
 * Trigger conditions that cause the engine to halt mid-run.
 *
 * The first 9 values are the F-018 ledger's authoritative automatic-halt
 * trigger enum. The next 3 (`manual`, `iteration_cap`, `tool_calls_quota`)
 * are sibling triggers for the verdict shape's reuse by F-020 / F-001's
 * cycle-cap / F-022. The 13th value `tool_calls` (no `_quota` suffix) is
 * F-022's per-spawn quota trigger — F-018 emits `tool_calls_quota` for the
 * global counter; F-022 emits `tool_calls` for per-agent quota exhaustion.
 *
 * `manual` carries an operator-supplied reason (kill-switch invocation)
 * and is the F-020 reuse path. The 9-value automatic enum stays intact
 * per the ledger.
 */
export type HaltTrigger =
  // Ledger 9-value automatic-halt enum:
  | 'consecutive_failures_3'
  | 'consecutive_failures_10'
  | 'overplanning_5'
  | 'overplanning_8'
  | 'spawns_per_hour_exceeded'
  | 'token_anomaly_2x'
  | 'rapid_prompt_burst'
  | 'circuit_breaker_open'
  | 'degradation_threshold'
  // Sibling triggers (verdict-shape reuse for F-020 / cycle-cap / F-022):
  | 'manual'
  | 'iteration_cap'
  | 'tool_calls_quota'
  // F-022 per-spawn (per agent_id) quota:
  | 'tool_calls'
  // F-021 escalation-ladder reaching its top (all fallbacks exhausted):
  | 'degrade_escalate';

/**
 * RUN_HALTED verdict shape — emitted when any halt trigger fires.
 *
 * Per the F-018 ledger acceptance contract: the engine transitions to
 * `closing` with `halted_by: <trigger>` and `trigger_evidence_sha256`
 * linking to the audit entry (F-015) that triggered the halt. The retro
 * signal (F-014) fires next, capturing the evidence.
 *
 * The `trigger_evidence_sha256` field is optional in this in-memory primitive
 * — it becomes load-bearing when F-015's audit-log integration plugs in.
 * `run_id` and `agent_id` are optional because the kit's identity stamp
 * (F-002) binds them at the audit-writer boundary; halt detection happens
 * in the hot path where the session/agent context may not be threaded
 * through every call site.
 */
export interface RunHaltedVerdict {
  type: 'RUN_HALTED';
  trigger: HaltTrigger;
  reason: string;
  /** ISO-8601 UTC timestamp captured at halt time. */
  timestamp: string;
  /** Optional F-002 correlation ids. */
  run_id?: string;
  agent_id?: string;
  /** Optional F-015 audit-row binding (filled by F-015 integration). */
  trigger_evidence_sha256?: string;
}

/**
 * Optional context the caller may attach to a halt verdict at fire time.
 * Mirrors F-002's correlation triple + F-015's evidence anchor; all fields
 * are optional because halt detection happens in the hot path where the
 * full identity context may not be threaded.
 */
export interface HaltContext {
  run_id?: string;
  agent_id?: string;
  trigger_evidence_sha256?: string;
}

/**
 * Per-run threshold overrides for {@link HaltDetector}. Defaults track
 * `.claude/rules/anomaly-thresholds.md` values.
 */
export interface HaltDetectorConfig {
  maxConsecutiveFailures?: number;
  maxOverplanningReadOnly?: number;
  maxIterations?: number;
  maxToolCalls?: number;
}

/**
 * In-memory failure-pattern halt detector.
 *
 * Acceptance scenarios from the F-018 ledger:
 *   1. Engine records 3 consecutive failed cycles → 3rd `recordFailure`
 *      returns a verdict with trigger=`consecutive_failures_3`.
 *   2. Engine observes 5 consecutive read-only Tool calls → 5th
 *      `recordReadOnlyTool` returns a verdict with trigger=`overplanning_5`
 *      (BEFORE the 6th call could fire).
 *   3. Threshold override `maxConsecutiveFailures: 10` → 9 consecutive
 *      failures produce no halt; 10th halts. Trigger name stays
 *      `consecutive_failures_3` (canonical taxonomy).
 *
 * Sibling triggers (out of ledger scope but in HaltDetector surface):
 *   - {@link recordIteration} → `iteration_cap` at maxIterations.
 *   - {@link recordToolCall} → `tool_calls_quota` at maxToolCalls.
 *   - {@link manualHalt} → `manual` with caller-supplied reason.
 *
 * Reset semantics:
 *   - `recordSuccess()` resets the consecutive-failures counter.
 *   - `recordWriteTool()` resets the read-only overplanning counter.
 *
 * No reset method exists for iteration / tool-call counts — those are
 * monotonic per-run quotas; the run is the reset boundary.
 */
export class HaltDetector {
  private consecutiveFailures = 0;
  private readOnlyToolStreak = 0;
  private iterations = 0;
  private toolCalls = 0;

  private readonly maxConsecutiveFailures: number;
  private readonly maxOverplanningReadOnly: number;
  private readonly maxIterations: number;
  private readonly maxToolCalls: number;

  constructor(config: HaltDetectorConfig = {}) {
    this.maxConsecutiveFailures = config.maxConsecutiveFailures ?? 3;
    this.maxOverplanningReadOnly = config.maxOverplanningReadOnly ?? 5;
    this.maxIterations = config.maxIterations ?? 100;
    this.maxToolCalls = config.maxToolCalls ?? 200;
  }

  /**
   * Record a failed cycle. Returns a halt verdict if the consecutive-failures
   * threshold is reached on this call; null otherwise. Trigger name remains
   * `consecutive_failures_3` even when the threshold is overridden — per the
   * ledger's stable-taxonomy contract.
   */
  recordFailure(context?: HaltContext): RunHaltedVerdict | null {
    this.consecutiveFailures++;
    if (this.consecutiveFailures >= this.maxConsecutiveFailures) {
      return this.halt(
        'consecutive_failures_3',
        `${this.consecutiveFailures} consecutive failures reached threshold ${this.maxConsecutiveFailures}`,
        context,
      );
    }
    return null;
  }

  /** Record a successful cycle. Resets the consecutive-failures streak. */
  recordSuccess(): void {
    this.consecutiveFailures = 0;
  }

  /**
   * Record a read-only tool call (Read / Grep / Glob analogues). Returns
   * a halt verdict if the overplanning threshold is reached on this call;
   * null otherwise. Per the F-018 ledger acceptance scenario 2, the halt
   * fires at the 5th read-only call (BEFORE a 6th could fire), so the
   * counter tests `>=` against the threshold.
   */
  recordReadOnlyTool(context?: HaltContext): RunHaltedVerdict | null {
    this.readOnlyToolStreak++;
    if (this.readOnlyToolStreak >= this.maxOverplanningReadOnly) {
      return this.halt(
        'overplanning_5',
        `${this.readOnlyToolStreak} consecutive read-only tool calls reached overplanning threshold ${this.maxOverplanningReadOnly}`,
        context,
      );
    }
    return null;
  }

  /** Record a write/edit tool call. Resets the overplanning streak. */
  recordWriteTool(): void {
    this.readOnlyToolStreak = 0;
  }

  /**
   * Record a cycle iteration. Returns a halt verdict if the iteration cap
   * is reached on this call; null otherwise. Sibling trigger to F-001's
   * MAX_CYCLES_HARD_CAP — the two coexist: F-001 enforces the hard cap of
   * 50; F-018 surfaces a per-run override-able cap for callers that want
   * to halt earlier.
   */
  recordIteration(context?: HaltContext): RunHaltedVerdict | null {
    this.iterations++;
    if (this.iterations >= this.maxIterations) {
      return this.halt(
        'iteration_cap',
        `${this.iterations} iterations reached cap ${this.maxIterations}`,
        context,
      );
    }
    return null;
  }

  /**
   * Record a tool invocation (any tool — read OR write). Returns a halt
   * verdict if the tool-call quota is reached on this call; null otherwise.
   * F-022 sources the per-tool quota separately; this is the global
   * count for the verdict shape's reuse.
   */
  recordToolCall(context?: HaltContext): RunHaltedVerdict | null {
    this.toolCalls++;
    if (this.toolCalls >= this.maxToolCalls) {
      return this.halt(
        'tool_calls_quota',
        `${this.toolCalls} tool calls reached quota ${this.maxToolCalls}`,
        context,
      );
    }
    return null;
  }

  /**
   * Operator-initiated halt (kill-switch). Always returns a verdict —
   * unconditional. F-020 calls this from its kill-switch JSON watcher.
   * The caller-supplied reason is preserved verbatim in the verdict.
   */
  manualHalt(reason: string, context?: HaltContext): RunHaltedVerdict {
    return this.halt('manual', reason, context);
  }

  private halt(
    trigger: HaltTrigger,
    reason: string,
    context?: HaltContext,
  ): RunHaltedVerdict {
    const verdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger,
      reason,
      timestamp: new Date().toISOString(),
    };
    if (context?.run_id !== undefined) {
      verdict.run_id = context.run_id;
    }
    if (context?.agent_id !== undefined) {
      verdict.agent_id = context.agent_id;
    }
    if (context?.trigger_evidence_sha256 !== undefined) {
      verdict.trigger_evidence_sha256 = context.trigger_evidence_sha256;
    }
    return verdict;
  }
}
