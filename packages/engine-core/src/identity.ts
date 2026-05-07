/**
 * F-002 Per-agent identity & run_id correlation — GREEN.
 * Per docs/03-feature-catalog/M0-bootstrap/F-002-per-agent-identity-runid.md.
 *
 * Adds Session (runId), Agent (agentId, parentRunId), and stampIdentity()
 * helper that decorates an artifact with the {agent_id, run_id, parent_run_id}
 * correlation triple. Identity is UUID v7 (time-ordered per RFC 9562) so the
 * lexicographic ordering doubles as a wall-clock proxy for audit replay.
 * stampIdentity rejects with IDENTITY_MISSING when agent or session is absent
 * — the audit-writer boundary discipline from the F-002 ledger.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

import { randomBytes } from 'node:crypto';

/** A spawned agent. Holds a stable UUID v7 agentId for its lifetime. */
export interface Agent {
  /** UUID v7 (time-ordered per RFC 9562). Stable across reads. */
  readonly agentId: string;
  /**
   * If this agent was spawned from another agent's session context, holds the
   * parent's run_id. `undefined` for root agents (no parent). The value is
   * later carried on every artifact stamped via {@link stampIdentity}.
   */
  readonly parentRunId?: string;
}

/** A run/session. Holds a stable UUID v7 runId for its lifetime. */
export interface Session {
  /** UUID v7 (time-ordered per RFC 9562). Stable across reads. */
  readonly runId: string;
}

/** Options accepted by {@link createAgent}. */
export interface CreateAgentOptions {
  /**
   * If provided, the spawning session whose runId becomes the new agent's
   * parentRunId. Used to build the F-002 correlation chain (acceptance
   * scenario 2: B's first audit entry carries parent_run_id = run_id of A).
   */
  parentSession?: Session;
}

/** Identity-stamped artifact: original fields + correlation triple. */
export type IdentityStamped<T extends object> = T & {
  agent_id: string;
  run_id: string;
  parent_run_id?: string;
};

/**
 * Generate a UUID v7 (time-ordered) per RFC 9562 §5.7.
 *
 * Layout (128 bits):
 *   - 48 bits: unix timestamp in milliseconds (big-endian)
 *   - 4 bits:  version = 0b0111 (i.e. `7`)
 *   - 12 bits: random
 *   - 2 bits:  variant = 0b10
 *   - 62 bits: random
 *
 * `node:crypto.randomUUID()` returns v4 (random); Node 24's runtime ignores
 * a `{version: 7}` option silently, so we build v7 ourselves from
 * `randomBytes` + `Date.now()`. Output is the canonical 8-4-4-4-12 hex form.
 */
function uuidV7(): string {
  const bytes = randomBytes(16);
  const ms = BigInt(Date.now());

  // 48-bit unix-ms timestamp into bytes 0-5 (big-endian).
  bytes[0] = Number((ms >> 40n) & 0xffn);
  bytes[1] = Number((ms >> 32n) & 0xffn);
  bytes[2] = Number((ms >> 24n) & 0xffn);
  bytes[3] = Number((ms >> 16n) & 0xffn);
  bytes[4] = Number((ms >> 8n) & 0xffn);
  bytes[5] = Number(ms & 0xffn);

  // Version 7 in the high nibble of byte 6.
  bytes[6] = (bytes[6] & 0x0f) | 0x70;

  // Variant 10xx in the high two bits of byte 8.
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex = bytes.toString('hex');
  return (
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20, 32)}`
  );
}

/**
 * Allocate a fresh agent with a stable UUID v7 agentId.
 *
 * If `options.parentSession` is provided, the agent is recorded as having been
 * spawned from that session — its `parentRunId` is set so future stamps carry
 * the correlation chain (F-002 acceptance scenario 2).
 */
export function createAgent(options: CreateAgentOptions = {}): Agent {
  return {
    agentId: uuidV7(),
    parentRunId: options.parentSession?.runId,
  };
}

/** Allocate a fresh session with a stable UUID v7 runId. */
export function createSession(): Session {
  return { runId: uuidV7() };
}

/**
 * Stamp an artifact with the {agent_id, run_id, parent_run_id} correlation
 * triple. The audit-writer boundary: any artifact entering the audit pipeline
 * MUST be stamped, and any call missing the agent or session rejects with
 * `IDENTITY_MISSING` (F-002 acceptance scenario 3).
 *
 * Original artifact fields are preserved; identity fields are added without
 * mutation (returns a new object — pure function).
 */
export function stampIdentity<T extends object>(
  artifact: T,
  agent: Agent | undefined,
  session: Session | undefined,
): IdentityStamped<T> {
  if (!agent || !agent.agentId) {
    throw new Error(
      'IDENTITY_MISSING: stampIdentity requires an Agent with an agentId; ' +
        'audit-writer boundary rejects unstamped writes per F-002 ledger.',
    );
  }
  if (!session || !session.runId) {
    throw new Error(
      'IDENTITY_MISSING: stampIdentity requires a Session with a runId; ' +
        'audit-writer boundary rejects unstamped writes per F-002 ledger.',
    );
  }

  const stamped: IdentityStamped<T> = {
    ...artifact,
    agent_id: agent.agentId,
    run_id: session.runId,
  };
  if (agent.parentRunId !== undefined) {
    stamped.parent_run_id = agent.parentRunId;
  }
  return stamped;
}
