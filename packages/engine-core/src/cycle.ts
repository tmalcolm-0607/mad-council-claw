/**
 * F-138 Engine-cycle orchestrator — GREEN.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-138-engine-cycle-orchestrator.md.
 * Behavior contract: runEngineCycle composes the 18 LOCKED M0/M1/M2 primitives
 * into a single MAD-pipeline iteration end-to-end. Resolves wave-016 / lane-d
 * Copilot CLI HARD-BLOCK F1 (no engine-cycle orchestrator wires F-001 → F-009 →
 * F-019 → F-022 → F-021 → F-018 → F-014).
 *
 * Composition order (no primitive logic re-implemented — orchestrator-identity
 * rule "compose; do not re-implement"):
 *   1. createAgent + createSession (F-002) → correlation triple
 *   2. appendAuditEntry cycle.start (F-015)
 *   3. backend.startSession (F-009)
 *   4. EITHER: forceHaltTrigger='manual' → halt.manualHalt → backend.halt → halted RunOutcome
 *      OR: for await (event of backend.sendPrompt) → audit + halt detection
 *   5. backend.stopSession (F-009)
 *   6. closeSession(retro) (F-014) — throws RetroMissingError on null/invalid
 *   7. Return RunOutcome with auditChainHead = last entry's entry_sha256
 *
 * Scope per `no-silent-deferrals.md` ledger §out-of-scope-notes:
 *   - F-017 redaction NOT piped (audit-egress wave)
 *   - F-021 ladder NOT instantiated (M3 error-path wave)
 *   - F-020 kill-switch polling NOT wired (M3 cron-heartbeat integration)
 *   - F-022 per-spawn quota NOT wired (multi-agent variant; v1 uses global)
 *   - F-002 stampIdentity boundary NOT yet at audit-writer (F-006/F-008 wave)
 *   - F-013 usage variant NOT yet on BackendEvent (D-36 / F-139)
 *   - Multi-iteration loop NOT yet (M3+)
 *
 * Created in wave-017 / lane-a.
 */

import { createAgent, createSession } from './identity.js';
import type { IBackendProvider, BackendEvent } from './backend.js';
import {
  appendAuditEntry,
  type AuditLogEntry,
  type AuditLogEntryInput,
} from './audit.js';
import { closeSession, type RetroSignal } from './retro.js';
import { HaltDetector, type HaltTrigger, type RunHaltedVerdict } from './halt.js';
import { CostLedger } from './cost.js';

/**
 * Configuration for {@link runEngineCycle}.
 *
 * Required:
 *   - `backend` — F-009 IBackendProvider implementation (StubBackend for tests,
 *     AnthropicBackend / CopilotBackend for real runs).
 *   - `prompt` — single user prompt for v1 (multi-turn deferred to M3+).
 *   - `retro` — factory invoked at close time. Returns RetroSignal | null.
 *     Returning null/invalid throws RetroMissingError (F-014 contract).
 *
 * Optional:
 *   - `maxToolCalls` — global tool-call cap (HaltDetector). Default 200.
 *   - `maxIterations` — cycle iteration cap. Default 100. (Single-iteration v1
 *     does not exercise; reserved for M3+ multi-turn extensions.)
 *   - `forceHaltTrigger` — test seam exercising the manual halt path without
 *     a contrived backend error injection. Currently 'manual' only; future
 *     test seams may add 'iteration_cap' / 'tool_calls_quota'.
 */
export interface EngineCycleConfig {
  backend: IBackendProvider;
  prompt: string;
  retro: () => RetroSignal | null;
  maxToolCalls?: number;
  maxIterations?: number;
  forceHaltTrigger?: 'manual';
}

/**
 * Structured outcome of a single MAD-pipeline iteration.
 *
 * Status enum:
 *   - `'completed'` — backend's sendPrompt yielded a finish event with
 *     reason='stop' (or 'tool' / 'length' but no halt fired).
 *   - `'halted'` — a halt trigger fired mid-stream OR forceHaltTrigger was
 *     set. haltTrigger + haltReason are populated.
 *
 * Correlation triple (F-002): runId + agentId always present.
 *
 * Audit chain (F-015): auditChainHead is the SHA-256 of the last appended
 * entry; downstream verification (verifyAuditChain) consumes the audit
 * array, which is private to the cycle (the head is the externally-visible
 * proof of the chain's terminal state).
 *
 * Events array preserves the captured BackendEvent stream from the run.
 *
 * costTotalUsd is CostLedger.totalUsd() — 0 in v1 because BackendEvent has
 * no `usage` variant per wave-016 D-36; F-139 adds the variant and rows
 * begin appending automatically.
 */
export interface RunOutcome {
  status: 'completed' | 'halted';
  runId: string;
  agentId: string;
  auditChainHead: string;
  haltTrigger?: HaltTrigger;
  haltReason?: string;
  events: BackendEvent[];
  costTotalUsd: number;
}

/**
 * Thin in-memory adapter wrapping `appendAuditEntry`. Private to cycle.ts;
 * provides ergonomic `audit.append(action, fields)` instead of threading the
 * array through every call site. The underlying storage is a regular array
 * of AuditLogEntry, so F-016 queryAuditLog continues to work unchanged.
 *
 * The adapter is NOT exported — F-015's appendAuditEntry / verifyAuditChain
 * remain the canonical surface; this adapter exists only to keep cycle.ts
 * readable. cycle counter is monotonic 1-based per F-015 contract.
 */
class AuditChain {
  private readonly rows: AuditLogEntry[] = [];
  private cycle = 0;

  append(action: string, fields: Record<string, unknown>): AuditLogEntry {
    this.cycle++;
    const input: AuditLogEntryInput = { cycle: this.cycle, action, fields };
    return appendAuditEntry(this.rows, input);
  }

  getRows(): readonly AuditLogEntry[] {
    return this.rows;
  }

  headHash(): string {
    if (this.rows.length === 0) return '0'.repeat(64);
    return this.rows[this.rows.length - 1].entry_sha256;
  }
}

/**
 * Run a single MAD-pipeline iteration end-to-end.
 *
 * See {@link EngineCycleConfig} + {@link RunOutcome} for the contract. The
 * function never re-implements primitive logic — every step delegates to a
 * LOCKED primitive (F-001/F-002/F-009/F-014/F-015/F-018/F-019).
 *
 * Failure modes:
 *   - retro() returns null/invalid → RetroMissingError (F-014 boundary).
 *   - backend.startSession rejects → propagates (provider misconfiguration).
 *   - backend.sendPrompt yields finish/error → halt.recordFailure; verdict
 *     fires when consecutive_failures threshold reached.
 *   - forceHaltTrigger='manual' → halt.manualHalt fires immediately, no
 *     prompt is sent.
 */
export async function runEngineCycle(config: EngineCycleConfig): Promise<RunOutcome> {
  // 1. Allocate F-002 correlation triple.
  const agent = createAgent();
  const session = createSession();

  // 2. Initialize F-018 halt detector + F-019 cost ledger + F-015 audit chain.
  const halt = new HaltDetector({
    maxConsecutiveFailures: 3,
    maxOverplanningReadOnly: 5,
    maxIterations: config.maxIterations ?? 100,
    maxToolCalls: config.maxToolCalls ?? 200,
  });
  const cost = new CostLedger();
  const audit = new AuditChain();

  audit.append('cycle.start', {
    agent_id: agent.agentId,
    run_id: session.runId,
  });

  // 3. Open F-009 backend session.
  const { sessionId } = await config.backend.startSession({ agent, session });
  audit.append('backend.session.start', {
    sessionId,
    origin: config.backend.origin,
  });

  // 4a. Manual halt path (test seam exercising HaltDetector.manualHalt +
  //     IBackendProvider.halt without backend-error injection).
  if (config.forceHaltTrigger === 'manual') {
    const verdict: RunHaltedVerdict = halt.manualHalt(
      'test-driven manual halt via forceHaltTrigger',
      { run_id: session.runId, agent_id: agent.agentId },
    );
    await config.backend.halt(sessionId, verdict);
    audit.append('cycle.halted', {
      trigger: verdict.trigger,
      reason: verdict.reason,
    });
    await config.backend.stopSession(sessionId);
    audit.append('backend.session.stop', { sessionId });

    // F-014 close-transition still fires for halted runs; the outcome enum
    // varies (halted_by_*) but the boundary contract is unconditional.
    closeSession(config.retro());

    audit.append('cycle.end', { status: 'halted' });

    return {
      status: 'halted',
      runId: session.runId,
      agentId: agent.agentId,
      auditChainHead: audit.headHash(),
      haltTrigger: verdict.trigger,
      haltReason: verdict.reason,
      events: [],
      costTotalUsd: cost.totalUsd(),
    };
  }

  // 4b. Normal path: stream the backend's response, audit each event,
  //     run halt detection, exit on halt or finish.
  const events: BackendEvent[] = [];
  let haltVerdict: RunHaltedVerdict | null = null;

  for await (const event of config.backend.sendPrompt(sessionId, config.prompt)) {
    events.push(event);
    audit.append('backend.event', { event });

    if (event.type === 'tool_call') {
      const v = halt.recordToolCall({
        run_id: session.runId,
        agent_id: agent.agentId,
      });
      if (v) {
        haltVerdict = v;
        break;
      }
    } else if (event.type === 'finish') {
      if (event.reason === 'stop' || event.reason === 'tool' || event.reason === 'length') {
        halt.recordSuccess();
      } else if (event.reason === 'error') {
        const v = halt.recordFailure({
          run_id: session.runId,
          agent_id: agent.agentId,
        });
        if (v) {
          haltVerdict = v;
        }
      }
      // finish ends the stream regardless of halt status.
      break;
    }
  }

  // 5. Halt path: notify backend before stop.
  if (haltVerdict) {
    await config.backend.halt(sessionId, haltVerdict);
    audit.append('cycle.halted', {
      trigger: haltVerdict.trigger,
      reason: haltVerdict.reason,
    });
  }

  // 6. F-009 graceful stop.
  await config.backend.stopSession(sessionId);
  audit.append('backend.session.stop', { sessionId });

  // 7. F-014 mandatory close-transition. Throws RetroMissingError on
  //    null/invalid retro — the run does NOT reach 'closed' in that case.
  closeSession(config.retro());

  audit.append('cycle.end', {
    status: haltVerdict ? 'halted' : 'completed',
  });

  const outcome: RunOutcome = {
    status: haltVerdict ? 'halted' : 'completed',
    runId: session.runId,
    agentId: agent.agentId,
    auditChainHead: audit.headHash(),
    events,
    costTotalUsd: cost.totalUsd(),
  };
  if (haltVerdict) {
    outcome.haltTrigger = haltVerdict.trigger;
    outcome.haltReason = haltVerdict.reason;
  }
  return outcome;
}
