import { describe, it, expect } from 'vitest';
import {
  createAgent,
  createSession,
  stampIdentity,
} from '@mad-council-claw/engine-core';

/**
 * F-002 RED → GREEN test.
 * Per docs/03-feature-catalog/M0-bootstrap/F-002-per-agent-identity-runid.md
 * acceptance scenarios. Authored RED-first in wave-006 / lane-d per the
 * wave-5 retro proposal (capture RED before flipping GREEN).
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Engine boots, allocates a root run_id; value is UUID v7 (time-ordered).
 *   2. Agent A spawns agent B; B's first stamped artifact carries
 *      parent_run_id = A's run_id and a fresh agent_id distinct from A.
 *   3. Audit-write call without an agent_id rejects with IDENTITY_MISSING and
 *      no entry is appended.
 *
 * UUID v7 shape (per RFC 9562):
 *   xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
 *   where the third group starts with `7` (version) and the fourth group
 *   starts with `8`, `9`, `a`, or `b` (variant).
 */
const UUID_V7_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe('F-002 per-agent-identity-runid', () => {
  it('scenario 1: createSession returns a Session whose runId is UUID v7 (time-ordered)', () => {
    const session = createSession();
    expect(session.runId).toMatch(UUID_V7_REGEX);

    // Stable across reads (not regenerated on access).
    expect(session.runId).toBe(session.runId);

    // Time-ordered: a session created later sorts >= an earlier session
    // lexicographically (UUID v7's leading 48 bits are unix-ms timestamp).
    const later = createSession();
    expect(later.runId >= session.runId).toBe(true);
  });

  it('scenario 2: spawned agent carries parent run_id and a fresh distinct agent_id', () => {
    const sessionA = createSession();
    const agentA = createAgent();

    // Agent B is spawned from agent A's session context; the spawn API
    // accepts parentSession so B's stamped artifacts can carry parent_run_id.
    const agentB = createAgent({ parentSession: sessionA });
    const sessionB = createSession();

    expect(agentB.agentId).toMatch(UUID_V7_REGEX);
    expect(agentB.agentId).not.toBe(agentA.agentId);
    expect(agentB.parentRunId).toBe(sessionA.runId);

    // Stamping a B-emitted artifact carries the correlation triple:
    // {agent_id: B, run_id: B's session, parent_run_id: A's session run_id}
    const artifact = { kind: 'audit-entry', payload: 'first-from-B' };
    const stamped = stampIdentity(artifact, agentB, sessionB);
    expect(stamped.agent_id).toBe(agentB.agentId);
    expect(stamped.run_id).toBe(sessionB.runId);
    expect(stamped.parent_run_id).toBe(sessionA.runId);
    expect(stamped.kind).toBe('audit-entry');
    expect(stamped.payload).toBe('first-from-B');
  });

  it('scenario 3: stampIdentity without an agent rejects with IDENTITY_MISSING', () => {
    const session = createSession();
    const artifact = { kind: 'audit-entry' };

    expect(() => stampIdentity(artifact, undefined, session)).toThrow(
      /IDENTITY_MISSING/,
    );
    expect(() =>
      stampIdentity(artifact, undefined as unknown as never, session),
    ).toThrow(/IDENTITY_MISSING/);

    // Same rejection if session is missing.
    const agent = createAgent();
    expect(() => stampIdentity(artifact, agent, undefined)).toThrow(
      /IDENTITY_MISSING/,
    );
  });
});
