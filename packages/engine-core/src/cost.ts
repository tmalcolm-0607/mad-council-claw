/**
 * F-019 Per-agent cost ledger — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-019-cost-ledger.md.
 * Behavior contract (verbatim from ledger):
 *   Every `usage` event from a backend (per F-013) is converted to a
 *   cost-ledger row at runs/<run_id>/cost-ledger.ndjson. Each row carries
 *   {run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens,
 *    output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}. Costs
 *   are computed using a per-model price table (versioned in
 *   pricing/<backend>.json). Aggregations over the ledger (sum per agent,
 *   per run, per day) are deterministic. The ledger NEVER auto-imposes
 *   budgets — observable-only, per `rules/no-invented-constraints.md`.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

/**
 * A single cost-ledger row.
 *
 * Aliased fields (the brief's API name + the ledger's authoritative name
 * are both present so downstream consumers can use either):
 *   - `tokens_in` aliases `input_tokens`
 *   - `tokens_out` aliases `output_tokens`
 *   - `usd_estimate` aliases `cost_usd`
 *   - `timestamp` aliases `ts_utc`
 *
 * Optional fields:
 *   - `parent_run_id` — F-002 correlation; present when the recording agent
 *     was spawned from another session.
 *   - `backend` — backend identifier (e.g. `anthropic`, `copilot`); F-013
 *     event-normalization will populate this in a future flip.
 *   - `cache_read_tokens` / `cache_write_tokens` — per ledger contract,
 *     captured when the backend reports prompt-cache usage.
 *   - `failure_mode` — present on rows where the call failed
 *     (`tool_failure` | `rate_limit` | `parse_error` | etc.). Undefined on
 *     success rows; observable-only — does NOT halt.
 */
export interface CostEntry {
  /** Monotonic 0-based sequence within this ledger instance. */
  seq: number;
  /** ISO-8601 UTC timestamp captured at append time. Aliases `ts_utc`. */
  timestamp: string;
  /** Same as {@link timestamp}; ledger's authoritative name. */
  ts_utc: string;
  /** F-002 agent identity (UUID v7). */
  agent_id: string;
  /** F-002 run/session identity (UUID v7). */
  run_id: string;
  /** F-002 parent-run correlation; absent for root agents. */
  parent_run_id?: string;
  /** Backend identifier (e.g. `anthropic`, `copilot`). Populated by F-013. */
  backend?: string;
  /** Model identifier (e.g. `claude-opus-4-7`, `gpt-5`). */
  model: string;
  /** Input/prompt tokens. Aliases `input_tokens`. */
  tokens_in: number;
  /** Same as {@link tokens_in}; ledger's authoritative name. */
  input_tokens: number;
  /** Output/completion tokens. Aliases `output_tokens`. */
  tokens_out: number;
  /** Same as {@link tokens_out}; ledger's authoritative name. */
  output_tokens: number;
  /** Cache-read tokens reported by the backend. Defaults to 0 when absent. */
  cache_read_tokens: number;
  /** Cache-write tokens reported by the backend. Defaults to 0 when absent. */
  cache_write_tokens: number;
  /** USD cost estimate for this row. Aliases `cost_usd`. */
  usd_estimate: number;
  /** Same as {@link usd_estimate}; ledger's authoritative name. */
  cost_usd: number;
  /**
   * Failure classification when the call failed; absent on success rows.
   * Common values: `tool_failure`, `rate_limit`, `parse_error`, `timeout`,
   * `quota_exceeded`. The taxonomy is open — F-013 normalizer + F-021
   * degradation-fallback will refine it; the ledger preserves whatever
   * the caller supplies verbatim.
   */
  failure_mode?: string;
}

/**
 * Input shape for {@link CostLedger.append}. Same as {@link CostEntry} minus
 * the auto-stamped fields (`seq`, `timestamp`/`ts_utc`) and minus the
 * authoritative-name aliases (`input_tokens`, `output_tokens`, `cost_usd`)
 * which the writer derives from the brief's API names.
 */
export interface CostEntryInput {
  agent_id: string;
  run_id: string;
  parent_run_id?: string;
  backend?: string;
  model: string;
  tokens_in: number;
  tokens_out: number;
  cache_read_tokens?: number;
  cache_write_tokens?: number;
  usd_estimate: number;
  failure_mode?: string;
}

/**
 * In-memory append-only cost ledger.
 *
 * Acceptance scenarios from the F-019 ledger:
 *   1. Backend emits usage:{input:1000, output:500} for claude-opus-4-7 →
 *      a row is appended with cost_usd matching the per-token rate.
 *   2. 50 rows / 3 agents → deterministic integer-token sums + 4-decimal
 *      dollar sums (no floating-point drift from JSON parsing).
 *   3. $1000 of cost logged with no budget → engine does NOT halt or warn;
 *      observable-only, per `rules/no-invented-constraints.md`.
 *
 * The ledger has NO halt API by design — that is a load-bearing absence.
 * Per the ledger's behavior contract, F-019 is observable-only: budget
 * enforcement is a separate (future) feature that requires explicit user
 * opt-in. The class deliberately exposes no `halt()`, `checkBudget()`, or
 * `overBudget()` method.
 *
 * Persistence to runs/<run_id>/cost-ledger.ndjson is F-008's job; this
 * primitive is the in-memory boundary the storage layer plugs into.
 */
export class CostLedger {
  private readonly entries: CostEntry[] = [];

  /**
   * Append a cost entry. Auto-stamps `seq` (monotonic 0-based) and
   * `timestamp` / `ts_utc` (ISO-8601 UTC, captured at call time). Returns
   * the appended row (same identity as the entry stored in the ledger;
   * future stored-entry mutations would corrupt aggregations — callers
   * MUST treat the returned row as read-only).
   *
   * Per `rules/no-invented-constraints.md`, this method NEVER throws on
   * "high cost" or "over budget" — there is no built-in budget. The user
   * opts into budget enforcement via a separate (future) feature.
   */
  append(input: CostEntryInput): CostEntry {
    const seq = this.entries.length;
    const timestamp = new Date().toISOString();
    const entry: CostEntry = {
      seq,
      timestamp,
      ts_utc: timestamp,
      agent_id: input.agent_id,
      run_id: input.run_id,
      model: input.model,
      tokens_in: input.tokens_in,
      input_tokens: input.tokens_in,
      tokens_out: input.tokens_out,
      output_tokens: input.tokens_out,
      cache_read_tokens: input.cache_read_tokens ?? 0,
      cache_write_tokens: input.cache_write_tokens ?? 0,
      usd_estimate: input.usd_estimate,
      cost_usd: input.usd_estimate,
    };
    if (input.parent_run_id !== undefined) {
      entry.parent_run_id = input.parent_run_id;
    }
    if (input.backend !== undefined) {
      entry.backend = input.backend;
    }
    if (input.failure_mode !== undefined) {
      entry.failure_mode = input.failure_mode;
    }
    this.entries.push(entry);
    return entry;
  }

  /**
   * Read-only view of all entries. Returns the internal array typed as
   * `readonly CostEntry[]`; the array reference is stable across calls
   * but mutating it (or any entry) corrupts aggregations. Defensive-copy
   * if the caller intends to filter/transform.
   */
  getEntries(): readonly CostEntry[] {
    return this.entries;
  }

  /** Sum of `tokens_in` across all entries. Exact integer arithmetic. */
  totalTokensIn(): number {
    let sum = 0;
    for (const e of this.entries) sum += e.tokens_in;
    return sum;
  }

  /** Sum of `tokens_out` across all entries. Exact integer arithmetic. */
  totalTokensOut(): number {
    let sum = 0;
    for (const e of this.entries) sum += e.tokens_out;
    return sum;
  }

  /**
   * Sum of `usd_estimate` across all entries. Floating-point arithmetic;
   * callers comparing for equality should use `toBeCloseTo` / 4 decimal
   * places per the F-019 ledger acceptance scenario 2.
   */
  totalUsd(): number {
    let sum = 0;
    for (const e of this.entries) sum += e.usd_estimate;
    return sum;
  }

  /**
   * Fraction of entries that recorded a `failure_mode`. Returns 0 for an
   * empty ledger (NOT NaN — empty ledger has no failures by definition).
   * Range: [0, 1].
   */
  failureRate(): number {
    if (this.entries.length === 0) return 0;
    let failures = 0;
    for (const e of this.entries) {
      if (e.failure_mode !== undefined) failures++;
    }
    return failures / this.entries.length;
  }
}
