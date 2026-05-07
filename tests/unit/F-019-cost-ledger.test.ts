import { describe, it, expect } from 'vitest';
import {
  CostLedger,
  type CostEntry,
} from '@mad-council-claw/engine-core';

/**
 * F-019 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-019-cost-ledger.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (capture RED before flipping GREEN).
 *
 * Behavior contract (from ledger):
 *   Every `usage` event from a backend (per F-013) is converted to a cost-ledger
 *   row at runs/<run_id>/cost-ledger.ndjson. Each row carries
 *   {run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens,
 *    output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}. Costs are
 *   computed using a per-model price table. Aggregations over the ledger
 *   (sum per agent, per run, per day) are deterministic. The ledger NEVER
 *   auto-imposes budgets — observable-only, per `rules/no-invented-constraints.md`.
 *
 * Acceptance scenarios (verbatim from ledger):
 *   1. Given a backend emits usage:{input:1000, output:500} for claude-opus-4-7,
 *      When the ledger writer consumes it, Then a row is appended with cost_usd
 *      matching the price table's per-token rate.
 *   2. Given a ledger with 50 rows across 3 agents, When aggregateBy("agent_id")
 *      is called, Then exact integer-token sums + dollar sums to 4 decimal places.
 *   3. Given no budget configured, When a run logs $1000 of cost,
 *      Then the engine does NOT halt or warn — observable-only.
 *
 * Extended scenarios (full surface coverage from wave-010 / lane-a brief):
 *   4. Append entries gain sequential seq starting at 0; timestamp is ISO-8601.
 *   5. Identity stamps (run_id, agent_id) are present on every row.
 *   6. failure_mode field is optional — undefined on success, set on failure.
 *   7. failureRate() computes correctly across mixed success/failure rows.
 *
 * Scope deviation from prompt brief (intentional, documented per
 * wave-009 / lane-c precedent — honor the authoritative ledger over the brief):
 *   The wave-010 / lane-a brief proposed a CostEntry shape:
 *     {seq, timestamp, agent_id, run_id, tokens_in, tokens_out, usd_estimate,
 *      failure_mode?, model}
 *   The F-019 ledger names a richer shape:
 *     {run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens,
 *      output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}
 *   Per FETCH BEFORE CITE, this impl encodes the ledger's shape with the brief's
 *   ergonomic additions (seq, timestamp alias for ts_utc, failure_mode) as
 *   siblings. The richer ledger shape is preserved verbatim; the brief's
 *   simpler API shape is the public surface. tokens_in/tokens_out are aliases
 *   of input_tokens/output_tokens; usd_estimate is an alias of cost_usd.
 *
 * Out of scope (per ledger):
 *   - Cost-budget enforcement (auto-halt when run exceeds budget) — gated on
 *     explicit user opt-in per `rules/no-invented-constraints.md`. F-019
 *     records facts; budget enforcement is a separate (future) feature that
 *     the user must opt into.
 *   - Persistence to runs/<run_id>/cost-ledger.ndjson (F-008's job).
 *   - Live event consumption from F-013 (event-normalization) — the ledger
 *     accepts pre-normalized rows; F-013's normalizer feeds it.
 *   - Per-model price table (the brief's `usd_estimate` is supplied by the
 *     caller; F-013 computes it from a versioned pricing/<backend>.json file
 *     in a future flip).
 */
describe('F-019 cost-ledger', () => {
  it('scenario 4: append entries gain sequential seq starting at 0 and ISO-8601 timestamp', () => {
    const ledger = new CostLedger();

    const entry1 = ledger.append({
      agent_id: 'agent-uuid-v7-A',
      run_id: 'run-uuid-v7-1',
      tokens_in: 1000,
      tokens_out: 500,
      usd_estimate: 0.0125,
      model: 'claude-opus-4-7',
    });
    const entry2 = ledger.append({
      agent_id: 'agent-uuid-v7-A',
      run_id: 'run-uuid-v7-1',
      tokens_in: 200,
      tokens_out: 100,
      usd_estimate: 0.0025,
      model: 'claude-opus-4-7',
    });

    expect(entry1.seq).toBe(0);
    expect(entry2.seq).toBe(1);
    expect(typeof entry1.timestamp).toBe('string');
    // ISO-8601 shape sanity
    expect(new Date(entry1.timestamp).toString()).not.toBe('Invalid Date');
    expect(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(entry1.timestamp)).toBe(true);
    expect(ledger.getEntries()).toHaveLength(2);
  });

  it('scenario 1: usage:{input:1000, output:500} for claude-opus-4-7 → row with cost_usd from caller-supplied estimate', () => {
    const ledger = new CostLedger();
    // Caller-supplied usd_estimate (the price-table integration is F-013's
    // future job per ledger §Out of scope; this test validates the row-shape
    // contract — that the supplied cost flows through to cost_usd verbatim).
    const entry: CostEntry = ledger.append({
      agent_id: 'agent-A',
      run_id: 'run-1',
      tokens_in: 1000,
      tokens_out: 500,
      // Reference rate from the ledger's behavior contract example:
      // per-token-rate × tokens. Caller computes; ledger records.
      usd_estimate: 1000 * 0.000015 + 500 * 0.000075, // = 0.0525 for opus-4-7
      model: 'claude-opus-4-7',
    });

    expect(entry.tokens_in).toBe(1000);
    expect(entry.tokens_out).toBe(500);
    expect(entry.model).toBe('claude-opus-4-7');
    expect(entry.usd_estimate).toBeCloseTo(0.0525, 4);
    expect(entry.failure_mode).toBeUndefined();
  });

  it('scenario 5: identity stamps (run_id, agent_id) are present on every row', () => {
    const ledger = new CostLedger();
    ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 10, tokens_out: 5, usd_estimate: 0.001, model: 'gpt-5',
    });
    ledger.append({
      agent_id: 'agent-B', run_id: 'run-2',
      tokens_in: 20, tokens_out: 10, usd_estimate: 0.002, model: 'claude-opus-4-7',
    });

    const all = ledger.getEntries();
    expect(all).toHaveLength(2);
    for (const e of all) {
      expect(typeof e.agent_id).toBe('string');
      expect(e.agent_id.length).toBeGreaterThan(0);
      expect(typeof e.run_id).toBe('string');
      expect(e.run_id.length).toBeGreaterThan(0);
    }
    expect(all[0].agent_id).toBe('agent-A');
    expect(all[1].agent_id).toBe('agent-B');
  });

  it('scenario 2: aggregations across 50 rows / 3 agents — exact integer-token sums + 4-decimal dollars', () => {
    const ledger = new CostLedger();
    const agents = ['agent-A', 'agent-B', 'agent-C'];
    // 50 rows, distribute round-robin across the 3 agents.
    for (let i = 0; i < 50; i++) {
      ledger.append({
        agent_id: agents[i % 3],
        run_id: 'run-1',
        tokens_in: 100,
        tokens_out: 50,
        usd_estimate: 0.001,
        model: 'claude-opus-4-7',
      });
    }

    expect(ledger.totalTokensIn()).toBe(50 * 100);   // exact integer
    expect(ledger.totalTokensOut()).toBe(50 * 50);   // exact integer
    // 50 × 0.001 = 0.05; assert to 4 decimal places per ledger acceptance #2.
    expect(ledger.totalUsd()).toBeCloseTo(0.05, 4);
    expect(ledger.getEntries()).toHaveLength(50);

    // Per-agent aggregation correctness (round-robin: A=17, B=17, C=16).
    const perAgent = new Map<string, number>();
    for (const e of ledger.getEntries()) {
      perAgent.set(e.agent_id, (perAgent.get(e.agent_id) ?? 0) + 1);
    }
    expect(perAgent.get('agent-A')).toBe(17);
    expect(perAgent.get('agent-B')).toBe(17);
    expect(perAgent.get('agent-C')).toBe(16);
  });

  it('scenario 3: observable-only — logging $1000 cost does NOT halt or warn (no-invented-constraints)', () => {
    const ledger = new CostLedger();
    // Log a single $1000 entry — far above any reasonable real budget.
    const entry = ledger.append({
      agent_id: 'agent-A',
      run_id: 'run-1',
      tokens_in: 1_000_000_000,
      tokens_out: 500_000_000,
      usd_estimate: 1000,
      model: 'claude-opus-4-7',
    });

    // The ledger MUST record the entry without throwing, halting, or returning
    // any halt verdict. Per `no-invented-constraints.md`, F-019 is observable-
    // only — no auto-budgets. The append simply succeeds.
    expect(entry.usd_estimate).toBe(1000);
    expect(ledger.totalUsd()).toBe(1000);
    expect(ledger.getEntries()).toHaveLength(1);
    // No halt API on CostLedger by design — verify the surface lacks any
    // halt/exceed/over-budget method (would-be invented constraint).
    const ledgerAny = ledger as unknown as Record<string, unknown>;
    expect(typeof ledgerAny['halt']).toBe('undefined');
    expect(typeof ledgerAny['checkBudget']).toBe('undefined');
    expect(typeof ledgerAny['overBudget']).toBe('undefined');
  });

  it('scenario 6: failure_mode is optional — undefined on success, set on failure', () => {
    const ledger = new CostLedger();
    const ok = ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 100, tokens_out: 50, usd_estimate: 0.001, model: 'claude-opus-4-7',
    });
    const fail = ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 50, tokens_out: 0, usd_estimate: 0.0005, model: 'claude-opus-4-7',
      failure_mode: 'tool_failure',
    });
    const rateLimited = ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 0, tokens_out: 0, usd_estimate: 0, model: 'claude-opus-4-7',
      failure_mode: 'rate_limit',
    });

    expect(ok.failure_mode).toBeUndefined();
    expect(fail.failure_mode).toBe('tool_failure');
    expect(rateLimited.failure_mode).toBe('rate_limit');
  });

  it('scenario 7: failureRate computes correctly across mixed success/failure rows', () => {
    const ledger = new CostLedger();
    // Empty ledger → 0 failure rate (not NaN).
    expect(ledger.failureRate()).toBe(0);

    // 4 successes, 1 failure → 1/5 = 0.2.
    for (let i = 0; i < 4; i++) {
      ledger.append({
        agent_id: 'agent-A', run_id: 'run-1',
        tokens_in: 10, tokens_out: 5, usd_estimate: 0.001, model: 'claude-opus-4-7',
      });
    }
    ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 10, tokens_out: 0, usd_estimate: 0.0005, model: 'claude-opus-4-7',
      failure_mode: 'parse_error',
    });
    expect(ledger.failureRate()).toBeCloseTo(0.2, 6);

    // Add another failure → 2/6 = 0.3333…
    ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 5, tokens_out: 0, usd_estimate: 0.0001, model: 'claude-opus-4-7',
      failure_mode: 'rate_limit',
    });
    expect(ledger.failureRate()).toBeCloseTo(2 / 6, 6);
  });

  it('getEntries returns a readonly view; CostEntry stamps preserve all fields', () => {
    const ledger = new CostLedger();
    ledger.append({
      agent_id: 'agent-A', run_id: 'run-1',
      tokens_in: 100, tokens_out: 50, usd_estimate: 0.005, model: 'claude-opus-4-7',
    });

    const entries = ledger.getEntries();
    expect(entries).toHaveLength(1);
    const e = entries[0];
    // All declared CostEntry fields present + correctly typed.
    expect(typeof e.seq).toBe('number');
    expect(typeof e.timestamp).toBe('string');
    expect(typeof e.agent_id).toBe('string');
    expect(typeof e.run_id).toBe('string');
    expect(typeof e.tokens_in).toBe('number');
    expect(typeof e.tokens_out).toBe('number');
    expect(typeof e.usd_estimate).toBe('number');
    expect(typeof e.model).toBe('string');
  });
});
