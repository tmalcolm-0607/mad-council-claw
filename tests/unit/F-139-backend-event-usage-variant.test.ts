import { describe, it, expect } from 'vitest';
import {
  CostLedger,
  isUsageEvent,
  isTokenEvent,
  eventTextContent,
  usageEventToCostEntry,
  type BackendEvent,
  type UsageEventContext,
  type PriceLookup,
  type CostEntryInput,
} from '@mad-council-claw/engine-core';

/**
 * F-139 RED -> GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-139-backend-event-usage-variant.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (RED-then-GREEN micro-session pattern validated by F-138).
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Usage event + price lookup + correlation -> CostEntryInput with
 *      computed usd_estimate; F-019 CostLedger.append round-trip yields a
 *      CostEntry with seq=0 and matching numeric fields.
 *   2. isUsageEvent type guard returns false for non-usage events.
 *   3. Usage event WITHOUT price lookup -> CostEntryInput with usd_estimate=0
 *      and all 4 token-count fields mapped verbatim (including cache fields).
 *   4. eventTextContent on a usage event returns deterministic
 *      [usage: input=N output=M cache_read=R cache_write=W] descriptor.
 *   5. parent_run_id in correlation context propagates to CostEntryInput.
 *   6. eventTextContent exhaustive-switch witness compiles (5/5 variants).
 *
 * Resolves wave-016 / lane-d C-2 (Opus Critical -> single-model SHOULD-FIX
 * under cross-model rule but reasoning concrete: F-019 cost ledger has no
 * event source without this variant). Closes D-36.
 *
 * Also resolves the F-138 §out-of-scope-notes gap that names this feature
 * explicitly: cycle.ts can begin computing cost-ledger rows from BackendEvent
 * once a future cycle.ts iteration composes this primitive.
 */

describe('F-139 backend-event-usage-variant', () => {
  it('scenario 1: usage event + price lookup + correlation -> CostEntryInput; CostLedger round-trip preserves numeric fields', () => {
    const usage: BackendEvent = {
      type: 'usage',
      input_tokens: 1000,
      output_tokens: 500,
      cache_read_tokens: 0,
      cache_write_tokens: 0,
      model: 'claude-opus-4-7',
      backend: 'anthropic',
    };
    const ctx: UsageEventContext = { run_id: 'r1', agent_id: 'a1' };
    // claude-opus-4-7 published rates: $15/M input, $75/M output -> per-token
    // 0.000015 input + 0.000075 output. 1000 * 0.000015 + 500 * 0.000075 =
    // 0.015 + 0.0375 = 0.0525 USD.
    const lookup: PriceLookup = (model, kind) => {
      if (model !== 'claude-opus-4-7') return 0;
      return kind === 'input' ? 0.000015 : 0.000075;
    };

    const input: CostEntryInput = usageEventToCostEntry(usage, ctx, lookup);

    expect(input.tokens_in).toBe(1000);
    expect(input.tokens_out).toBe(500);
    expect(input.cache_read_tokens).toBe(0);
    expect(input.cache_write_tokens).toBe(0);
    expect(input.model).toBe('claude-opus-4-7');
    expect(input.backend).toBe('anthropic');
    expect(input.agent_id).toBe('a1');
    expect(input.run_id).toBe('r1');
    expect(input.usd_estimate).toBeCloseTo(0.0525, 6);

    // F-019 round-trip: caller appends to a CostLedger and the resulting
    // CostEntry preserves every field.
    const ledger = new CostLedger();
    const entry = ledger.append(input);
    expect(entry.seq).toBe(0);
    expect(entry.tokens_in).toBe(1000);
    expect(entry.tokens_out).toBe(500);
    expect(entry.input_tokens).toBe(1000);
    expect(entry.output_tokens).toBe(500);
    expect(entry.usd_estimate).toBeCloseTo(0.0525, 6);
    expect(entry.cost_usd).toBeCloseTo(0.0525, 6);
    expect(entry.cache_read_tokens).toBe(0);
    expect(entry.cache_write_tokens).toBe(0);
    expect(entry.model).toBe('claude-opus-4-7');
    expect(entry.backend).toBe('anthropic');
    expect(ledger.totalUsd()).toBeCloseTo(0.0525, 6);
  });

  it('scenario 2: isUsageEvent narrows BackendEvent only for type==="usage"', () => {
    const tokenEvent: BackendEvent = { type: 'token', text: 'hello' };
    const finishEvent: BackendEvent = { type: 'finish', reason: 'stop' };
    const toolCallEvent: BackendEvent = {
      type: 'tool_call',
      name: 'foo',
      arguments: {},
    };
    const toolResultEvent: BackendEvent = {
      type: 'tool_result',
      name: 'foo',
      result: 'ok',
    };
    const usageEvent: BackendEvent = {
      type: 'usage',
      input_tokens: 10,
      output_tokens: 5,
      cache_read_tokens: 0,
      cache_write_tokens: 0,
      model: 'gpt-5',
    };

    expect(isUsageEvent(tokenEvent)).toBe(false);
    expect(isUsageEvent(finishEvent)).toBe(false);
    expect(isUsageEvent(toolCallEvent)).toBe(false);
    expect(isUsageEvent(toolResultEvent)).toBe(false);
    expect(isUsageEvent(usageEvent)).toBe(true);

    // Cross-witness: existing F-013 type guards keep their contracts intact.
    expect(isTokenEvent(tokenEvent)).toBe(true);
    expect(isTokenEvent(usageEvent)).toBe(false);
  });

  it('scenario 3: usage event without price lookup -> usd_estimate=0; all 4 token counts mapped verbatim', () => {
    const usage: BackendEvent = {
      type: 'usage',
      input_tokens: 1000,
      output_tokens: 500,
      cache_read_tokens: 200,
      cache_write_tokens: 100,
      model: 'claude-opus-4-7',
      backend: 'anthropic',
    };
    const ctx: UsageEventContext = { run_id: 'r1', agent_id: 'a1' };

    // No price lookup supplied -> caller-deferred pricing.
    const input: CostEntryInput = usageEventToCostEntry(usage, ctx);

    expect(input.tokens_in).toBe(1000);
    expect(input.tokens_out).toBe(500);
    expect(input.cache_read_tokens).toBe(200);
    expect(input.cache_write_tokens).toBe(100);
    expect(input.model).toBe('claude-opus-4-7');
    expect(input.backend).toBe('anthropic');
    expect(input.usd_estimate).toBe(0);
  });

  it('scenario 4: eventTextContent on usage event returns deterministic [usage: ...] descriptor', () => {
    const usage: BackendEvent = {
      type: 'usage',
      input_tokens: 1000,
      output_tokens: 500,
      cache_read_tokens: 200,
      cache_write_tokens: 100,
      model: 'claude-opus-4-7',
    };

    const text = eventTextContent(usage);
    expect(text).toBe('[usage: input=1000 output=500 cache_read=200 cache_write=100]');
  });

  it('scenario 5: parent_run_id in correlation context propagates to CostEntryInput', () => {
    const usage: BackendEvent = {
      type: 'usage',
      input_tokens: 100,
      output_tokens: 50,
      cache_read_tokens: 0,
      cache_write_tokens: 0,
      model: 'gpt-5',
    };
    const ctx: UsageEventContext = {
      run_id: 'child-run',
      agent_id: 'child-agent',
      parent_run_id: 'parent-run',
    };

    const input: CostEntryInput = usageEventToCostEntry(usage, ctx);
    expect(input.parent_run_id).toBe('parent-run');
    expect(input.run_id).toBe('child-run');
    expect(input.agent_id).toBe('child-agent');
  });

  it('scenario 6: eventTextContent exhaustive-switch witness compiles for the 5-variant union', () => {
    // Type-witness scenario: this test passes at compile-time IF the
    // BackendEvent union has exactly 5 variants AND eventTextContent has a
    // branch for each. The runtime assertion is just a smoke check.
    const variants: BackendEvent[] = [
      { type: 'token', text: 't' },
      { type: 'tool_call', name: 'f', arguments: {} },
      { type: 'tool_result', name: 'f', result: null },
      { type: 'finish', reason: 'stop' },
      {
        type: 'usage',
        input_tokens: 1,
        output_tokens: 1,
        cache_read_tokens: 0,
        cache_write_tokens: 0,
        model: 'm',
      },
    ];
    for (const v of variants) {
      expect(typeof eventTextContent(v)).toBe('string');
      expect(eventTextContent(v).length).toBeGreaterThan(0);
    }
  });
});
