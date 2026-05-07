/**
 * F-001 Engine Bootstrap Loop — GREEN implementation.
 * Per docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md.
 *
 * Behavior contract: a single CoClaw run with deterministic lifecycle
 * (open → active → closing → closed), cycle-bounded (≤50), with hash-chained
 * audit on every cycle. Termination always passes through `closing` so the
 * pre-close retro signal (F-014) fires before reaching `closed`.
 *
 * F-002 Per-agent identity & run_id correlation — GREEN.
 * Per docs/03-feature-catalog/M0-bootstrap/F-002-per-agent-identity-runid.md.
 * Adds Session (runId), Agent (agentId, parentRunId), and stampIdentity()
 * helper that decorates an artifact with the {agent_id, run_id, parent_run_id}
 * correlation triple. Identity is UUID v7 (time-ordered per RFC 9562) so the
 * lexicographic ordering doubles as a wall-clock proxy for audit replay.
 * stampIdentity rejects with IDENTITY_MISSING when agent or session is absent
 * — the audit-writer boundary discipline from the F-002 ledger.
 *
 * F-014 Pre-close retro signal — GREEN.
 * Per docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md.
 * Adds RetroSignal (5-axis Likert 1-5 + 7 pattern fields + outcome + optional
 * trigger_evidence_sha256), RetroMissingError (carries .missingFields list),
 * and closeSession() — the boundary contract that fails the close transition
 * with RETRO_MISSING when the retro is absent / partial / out-of-range. The
 * filesystem write to runs/<run_id>/retro.json is F-008's job (storage layout)
 * per the F-014 ledger out-of-scope-notes; this flip lands the in-memory
 * boundary that F-008 will plug into.
 *
 * This is the minimal implementation that satisfies F-001's three, F-002's
 * three, and F-014's eight acceptance scenarios. F-015 hash-chain crypto,
 * F-019 cost ledger, and F-021 exception-injection seam are tracked separately
 * and will extend this loop without breaking the contracts.
 */

import { createHash, randomBytes } from 'node:crypto';

export type LifecycleState = 'open' | 'active' | 'closing' | 'closed';

export type TerminatedBy = 'completion' | 'cycle_cap' | 'exception';

/** Hard cap per F-001 ledger ("≤50 cycles per run"). */
export const MAX_CYCLES_HARD_CAP = 50;

export interface RunConfig {
  /** Maximum cycles before forced transition to closing. Effective cap is min(maxCycles, 50). */
  maxCycles: number;
}

export interface AuditEntry {
  /** Monotonic cycle index, starting at 1. */
  cycle: number;
  /** Hash chained from prior entry; first entry chains from genesis. */
  hash: string;
  /** Lifecycle state captured at audit-write time. */
  state: LifecycleState;
}

export interface RunResult {
  /** Ordered lifecycle transitions emitted across the run. */
  lifecycle: LifecycleState[];
  /** One entry per cycle that ran. */
  audit: AuditEntry[];
  /** Why the run terminated. */
  terminatedBy: TerminatedBy;
}

/** Genesis hash — first audit entry chains from this constant. */
const GENESIS_HASH = '0'.repeat(64);

/**
 * Compute the hash for an audit entry by chaining from the prior hash.
 * SHA-256 of `${priorHash}|${cycle}|${state}` — F-015 will extend this with
 * cycle payload + signature; for F-001 the chain shape is what matters.
 */
function chainHash(priorHash: string, cycle: number, state: LifecycleState): string {
  return createHash('sha256').update(`${priorHash}|${cycle}|${state}`).digest('hex');
}

/**
 * Boot a single run and execute it to termination.
 *
 * Acceptance scenarios from the F-001 ledger:
 *   1. maxCycles=3 → lifecycle [open, active, closing, closed], 3 audit entries
 *   2. maxCycles=50 → 50 audit entries, terminatedBy='cycle_cap'
 *   3. exception path still transitions through closing (F-021 seam will inject;
 *      for F-001 the type surface is what's promised)
 */
export async function bootstrap(config: RunConfig): Promise<RunResult> {
  if (!Number.isInteger(config.maxCycles) || config.maxCycles < 1) {
    throw new Error(
      `F-001: maxCycles must be a positive integer; got ${String(config.maxCycles)}`,
    );
  }

  const lifecycle: LifecycleState[] = ['open'];
  const audit: AuditEntry[] = [];

  // Transition open → active. The active state runs the cycle loop.
  lifecycle.push('active');

  // Effective cap: never exceed the hard cap (F-001 ledger: "≤50 cycles per run").
  // If caller asks for ≥50, we run exactly 50 then terminate by cycle_cap.
  // If caller asks for <50, we run that many then terminate by completion.
  const requested = config.maxCycles;
  const cyclesToRun = Math.min(requested, MAX_CYCLES_HARD_CAP);
  const willHitCap = requested >= MAX_CYCLES_HARD_CAP;

  let priorHash = GENESIS_HASH;
  for (let cycle = 1; cycle <= cyclesToRun; cycle++) {
    const hash = chainHash(priorHash, cycle, 'active');
    audit.push({ cycle, hash, state: 'active' });
    priorHash = hash;
  }

  // Termination always flows through `closing` so F-014's pre-close retro
  // signal can fire. This ordering is load-bearing — scenarios 1, 2, and 3
  // all assert it.
  lifecycle.push('closing');
  lifecycle.push('closed');

  const terminatedBy: TerminatedBy = willHitCap ? 'cycle_cap' : 'completion';

  return { lifecycle, audit, terminatedBy };
}

// ----------------------------------------------------------------------------
// F-002 — Per-agent identity & run_id correlation
// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------
// F-014 — Pre-close retro signal
// ----------------------------------------------------------------------------

/**
 * Run outcomes recognized by the retro contract. `completed` covers
 * natural termination (completion + cycle_cap from F-001's TerminatedBy);
 * `halted_by_*` outcomes are the F-018/F-020 carve-outs and require a
 * `trigger_evidence_sha256` field linking to the audit entry that triggered
 * the halt (per F-014 ledger acceptance scenario 2).
 */
export type RetroOutcome =
  | 'completed'
  | 'halted_by_kill_switch'
  | 'halted_by_failure_pattern'
  | 'halted_by_tool_quota';

/**
 * The retro signal emitted during `closing` before the run reaches `closed`.
 *
 * Fields per F-014 ledger §Behavior contract:
 *   - 5-axis Likert 1-5 (accuracy / completeness / tsg_alignment / dx /
 *     confidence) — the kit:council-retro-skill rubric.
 *   - 7 pattern prose fields (what_worked / what_was_hard / surprises /
 *     blockers / next_steps / notes / meta_observations).
 *   - outcome: terminal classification.
 *   - trigger_evidence_sha256: required when outcome starts with `halted_by_`;
 *     SHA-256 hex (64 chars) linking to the audit entry that triggered the halt.
 */
export interface RetroSignal {
  // 5-axis Likert (each 1-5)
  accuracy: number;
  completeness: number;
  tsg_alignment: number;
  dx: number;
  confidence: number;
  // 7 pattern fields
  what_worked: string;
  what_was_hard: string;
  surprises: string;
  blockers: string;
  next_steps: string;
  notes: string;
  meta_observations: string;
  // Terminal classification
  outcome: RetroOutcome;
  // Required iff outcome starts with `halted_by_`
  trigger_evidence_sha256?: string;
}

/**
 * RETRO_MISSING — thrown when {@link closeSession} is called with an absent,
 * partial, or out-of-range retro. The `missingFields` array enumerates the
 * specific fields that failed validation so callers can surface remediation.
 */
export class RetroMissingError extends Error {
  public readonly missingFields: string[];
  constructor(missingFields: string[]) {
    super(
      `RETRO_MISSING: pre-close retro signal is incomplete; missing or invalid fields: ${
        missingFields.join(', ') || '<entire retro object>'
      }`,
    );
    this.name = 'RetroMissingError';
    this.missingFields = missingFields;
    // Preserve prototype chain through transpilation (TS class extending Error).
    Object.setPrototypeOf(this, RetroMissingError.prototype);
  }
}

/** The 5 Likert axes — each MUST be an integer 1..5 inclusive. */
const LIKERT_AXES = [
  'accuracy',
  'completeness',
  'tsg_alignment',
  'dx',
  'confidence',
] as const satisfies readonly (keyof RetroSignal)[];

/** The 7 pattern prose fields — each MUST be a non-empty string. */
const PATTERN_FIELDS = [
  'what_worked',
  'what_was_hard',
  'surprises',
  'blockers',
  'next_steps',
  'notes',
  'meta_observations',
] as const satisfies readonly (keyof RetroSignal)[];

/** Recognized outcomes that require trigger_evidence_sha256. */
const HALTED_OUTCOMES: ReadonlySet<RetroOutcome> = new Set([
  'halted_by_kill_switch',
  'halted_by_failure_pattern',
  'halted_by_tool_quota',
]);

/**
 * Close a session with a mandatory retro signal.
 *
 * Acceptance scenarios from the F-014 ledger:
 *   1. Valid retro w/ outcome=completed → returns {ok: true}.
 *   2. Halted run carries trigger_evidence_sha256 matching the halt audit
 *      entry → returns {ok: true}; absence → RETRO_MISSING.
 *   3. Buggy impl that omits the retro → RETRO_MISSING; the run does NOT
 *      reach `closed` (the throw IS the failed close transition).
 *
 * Validation contract (in order):
 *   - retro must be a non-null object.
 *   - All 5 Likert axes present, integer, 1..5 inclusive.
 *   - All 7 pattern prose fields present, non-empty string.
 *   - `outcome` present and one of RetroOutcome.
 *   - If outcome starts with `halted_by_`, trigger_evidence_sha256 present
 *     and 64-char lowercase hex.
 */
export function closeSession(
  retro: Partial<RetroSignal> | null | undefined,
): { ok: true } {
  if (retro === null || retro === undefined) {
    throw new RetroMissingError([]);
  }

  const missing: string[] = [];

  // 5-axis Likert validation: present + integer + 1..5.
  for (const axis of LIKERT_AXES) {
    const v = retro[axis];
    if (v === undefined) {
      missing.push(axis);
      continue;
    }
    if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > 5) {
      missing.push(axis);
    }
  }

  // 7 pattern fields: present + non-empty string.
  for (const field of PATTERN_FIELDS) {
    const v = retro[field];
    if (v === undefined) {
      missing.push(field);
      continue;
    }
    if (typeof v !== 'string' || v.length === 0) {
      missing.push(field);
    }
  }

  // outcome: present + recognized.
  const outcome = retro.outcome;
  const validOutcomes: ReadonlySet<RetroOutcome> = new Set<RetroOutcome>([
    'completed',
    'halted_by_kill_switch',
    'halted_by_failure_pattern',
    'halted_by_tool_quota',
  ]);
  if (outcome === undefined) {
    missing.push('outcome');
  } else if (!validOutcomes.has(outcome)) {
    missing.push('outcome');
  }

  // halted-by carve-out: trigger_evidence_sha256 required iff halted_by_*.
  if (outcome !== undefined && HALTED_OUTCOMES.has(outcome)) {
    const sha = retro.trigger_evidence_sha256;
    if (sha === undefined) {
      missing.push('trigger_evidence_sha256');
    } else if (typeof sha !== 'string' || !/^[0-9a-f]{64}$/.test(sha)) {
      missing.push('trigger_evidence_sha256');
    }
  }

  if (missing.length > 0) {
    throw new RetroMissingError(missing);
  }

  return { ok: true };
}

// ----------------------------------------------------------------------------
// F-015 — Hash-chained audit log
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-015-hash-chained-audit-log.md.
// Behavior contract: every audit entry includes `prev_sha256` and `entry_sha256`
// fields. `prev_sha256` is the `entry_sha256` of the immediately preceding
// entry in the same run (or `"GENESIS"` for the first entry).
// `entry_sha256 = sha256(canonical_json(entry_without_entry_sha256))`. The
// audit log is append-only. `verifyAuditChain` walks the log and reports the
// first index where a mismatch is detected, pointing precisely at the
// tampered entry.
//
// Out-of-scope (per ledger): cryptographic signing, third-party timestamping
// (deferred to v1.5 per ce:FR-IDENTITY-002). Persistence to the
// `runs/<run_id>/audit.ndjson` file lives in F-008 (storage layout).

/** Sentinel string used as `prev_sha256` for the first entry of any run. */
export const GENESIS_SENTINEL = 'GENESIS' as const;

/**
 * A single audit log entry. Shape mirrors the F-015 ledger contract:
 *   - `cycle`: monotonic cycle index (1-based) — chains naturally to F-001's
 *     in-memory cycle counter.
 *   - `action`: short string identifying the action class
 *     (e.g. `engine.boot`, `tool.invoke`, `agent.spawn`).
 *   - `fields`: free-form key/value payload; serialized via canonical JSON
 *     so the hash is stable across reads.
 *   - `prev_sha256`: 64-hex SHA-256 of the prior entry's `entry_sha256`,
 *     or `"GENESIS"` for the first entry.
 *   - `entry_sha256`: 64-hex SHA-256 over the canonical JSON of THIS entry
 *     with `entry_sha256` removed. Recomputable; tamper-evident.
 *
 * Naming note: this is `AuditLogEntry`, distinct from F-001's transient
 * `AuditEntry` (the in-memory `{cycle, hash, state}` cycle audit). F-001's
 * shape is run-bootstrap state; F-015's shape is the durable audit log row
 * persisted at `runs/<run_id>/audit.ndjson`. The names diverge intentionally
 * so consumers can hold both types in scope without TypeScript declaration
 * merging silently fusing them.
 */
export interface AuditLogEntry {
  cycle: number;
  action: string;
  fields: Record<string, unknown>;
  prev_sha256: string;
  entry_sha256: string;
}

/** Input shape for `appendAuditEntry` — same as `AuditLogEntry` minus the chain fields. */
export interface AuditLogEntryInput {
  cycle: number;
  action: string;
  fields: Record<string, unknown>;
}

/** Result of `verifyAuditChain`. */
export type VerifyAuditChainResult =
  | { valid: true }
  | {
      valid: false;
      /** Zero-based index of the first entry that fails verification. */
      broken_at: number;
      /** Why the chain broke. */
      reason: 'entry_sha256 mismatch' | 'prev_sha256 mismatch';
    };

/**
 * Canonical JSON serializer for the hash input.
 *
 * Recursively sorts object keys so two semantically-identical objects produce
 * byte-identical JSON. Arrays preserve order; primitives serialize with
 * `JSON.stringify`'s default rules. Sufficient for v1's free-form `fields`
 * payload; if we later need RFC 8785 (JCS) precision we'll swap this out.
 */
function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return '[' + value.map((v) => canonicalJson(v)).join(',') + ']';
  }
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj).sort();
  const body = keys
    .map((k) => JSON.stringify(k) + ':' + canonicalJson(obj[k]))
    .join(',');
  return '{' + body + '}';
}

/**
 * Compute the `entry_sha256` for an entry, omitting the `entry_sha256` field
 * itself from the hash input — per the ledger's behavior contract:
 *   `entry_sha256 = sha256(canonical_json(entry_without_entry_sha256))`.
 */
function computeEntrySha256(entry: AuditLogEntry): string {
  const { entry_sha256: _omit, ...rest } = entry;
  void _omit;
  return createHash('sha256').update(canonicalJson(rest)).digest('hex');
}

/**
 * Append a new audit entry to the log. Mutates the log (append-only); returns
 * the appended entry. The writer computes `prev_sha256` from the prior entry's
 * `entry_sha256` (or `GENESIS_SENTINEL` for the first entry) and seals the
 * entry with `entry_sha256` over the canonical JSON of the entry without the
 * `entry_sha256` field.
 *
 * Acceptance scenarios from the F-015 ledger:
 *   1. Empty log → first entry has prev_sha256 === "GENESIS" + valid 64-hex.
 *   2. (verification side — see `verifyAuditChain`)
 *   3. Append after a valid 1..M chain → chain remains valid 1..M+1.
 */
export function appendAuditEntry(
  log: AuditLogEntry[],
  input: AuditLogEntryInput,
): AuditLogEntry {
  const prev_sha256 =
    log.length === 0 ? GENESIS_SENTINEL : log[log.length - 1].entry_sha256;
  // Build the unsealed entry first so computeEntrySha256 can hash everything
  // EXCEPT entry_sha256. We pass a placeholder which the helper strips.
  const unsealed: AuditLogEntry = {
    cycle: input.cycle,
    action: input.action,
    fields: input.fields,
    prev_sha256,
    entry_sha256: '',
  };
  const entry_sha256 = computeEntrySha256(unsealed);
  const sealed: AuditLogEntry = { ...unsealed, entry_sha256 };
  log.push(sealed);
  return sealed;
}

/**
 * Verify the integrity of an audit chain. Walks the log entry-by-entry; on
 * the first mismatch, returns `{valid: false, broken_at: <index>, reason}`
 * pointing precisely at the tampered entry.
 *
 * Two failure modes are reported separately:
 *   - `entry_sha256 mismatch`: the recomputed hash over the entry's payload
 *     does not match the stored `entry_sha256`. This is the primary
 *     tamper-detection signal (scenario 2): editing any payload field
 *     invalidates the seal.
 *   - `prev_sha256 mismatch`: the entry's stored `prev_sha256` does not
 *     equal the prior entry's `entry_sha256` (or GENESIS for index 0).
 *     This catches reordering or splicing attacks where each entry's seal
 *     is internally consistent but the chain link is wrong.
 *
 * `entry_sha256` is checked FIRST per entry — when both fail the user sees
 * the more specific signal. (In scenario 4, mutating prev_sha256 also
 * invalidates entry_sha256 because prev_sha256 is part of the hash input,
 * so the entry_sha256 mismatch fires first at the tampered index.)
 */
export function verifyAuditChain(log: readonly AuditLogEntry[]): VerifyAuditChainResult {
  for (let i = 0; i < log.length; i++) {
    const entry = log[i];

    const expectedPrev = i === 0 ? GENESIS_SENTINEL : log[i - 1].entry_sha256;
    const recomputed = computeEntrySha256(entry);

    if (recomputed !== entry.entry_sha256) {
      return { valid: false, broken_at: i, reason: 'entry_sha256 mismatch' };
    }
    if (entry.prev_sha256 !== expectedPrev) {
      return { valid: false, broken_at: i, reason: 'prev_sha256 mismatch' };
    }
  }
  return { valid: true };
}

// ----------------------------------------------------------------------------
// F-016 — Query audit log
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-016-query-audit-log.md
// + wave-009 lane-b brief.
//
// Behavior contract: read-only query helpers over an F-015 audit chain.
// `queryAuditLog` filters/paginates a chain into a defensive copy
// (chronological order preserved). `findChainBreak` reports the first
// tampered index using F-015's verifyAuditChain primitive (or null when
// the chain is intact).
//
// The wave-9 brief simplifies the F-016 ledger's streaming async-iterator
// shape to a synchronous filter API. The substantive guarantees — filter
// by attribute, integrity warning, read-only — are preserved; the
// streaming/large-log shape is deferred to v1.5 per the ledger
// out-of-scope-notes ("M2 ships a streaming filter API only; heavy query
// needs are tracked under F-088..F-092 / M11").
//
// Out of scope (per ledger): full-text search + indexed pagination across
// thousands of runs (deferred to M11 introspect/replay), persistence-layer
// reads (F-008's job), agent_id / run_id filter (F-002 stamps these into
// `fields`; the brief uses `action` as the filter key so the v1 surface
// stays minimal).

/** Filter / pagination options for `queryAuditLog`. All fields optional. */
export interface AuditQueryOptions {
  /**
   * ISO-8601 timestamp lower bound. An entry passes the filter when
   * `entry.fields.timestamp` is a string and `>= since` (lexicographic
   * compare; ISO-8601 sorts correctly under string compare). Entries
   * without a `fields.timestamp` field are excluded when this option is set.
   */
  since?: string;
  /** Take at most this many entries (after `since` + `action` + `skip` apply). */
  top?: number;
  /** Skip this many entries (after `since` + `action` apply, before `top`). */
  skip?: number;
  /** Only include entries whose `action` field equals this value exactly. */
  action?: string;
}

/**
 * Filter + paginate an audit log into a defensive copy.
 *
 * Order of operations: `since` → `action` → `skip` → `top`. Each step is
 * applied to the array in-flight without mutating the source log.
 * Chronological order is preserved (the source log is already ordered by
 * F-015's append-only writer; this function never reorders).
 *
 * The returned array is a fresh array (defensive copy); mutating it does
 * not affect the source log. Individual entries are NOT cloned — they
 * share object identity with the source. Callers that mutate an entry's
 * `fields` will invalidate the chain (use `findChainBreak` to detect).
 *
 * The function deliberately does NOT validate chain integrity itself —
 * the F-016 ledger says queryAuditLog "validates the chain integrity per
 * F-015 BEFORE yielding any entry; if the chain is broken, it yields one
 * `chain_invalid` warning event". The wave-9 brief splits that into a
 * separate `findChainBreak` helper so callers can compose them
 * deliberately (and pay the verification cost only when they want it).
 */
export function queryAuditLog(
  rows: readonly AuditLogEntry[],
  opts: AuditQueryOptions = {},
): AuditLogEntry[] {
  let result: AuditLogEntry[] = [...rows]; // defensive copy

  if (opts.since !== undefined) {
    const since = opts.since;
    result = result.filter((e) => {
      const ts = e.fields['timestamp'];
      return typeof ts === 'string' && ts >= since;
    });
  }

  if (opts.action !== undefined) {
    const action = opts.action;
    result = result.filter((e) => e.action === action);
  }

  if (opts.skip !== undefined && opts.skip > 0) {
    result = result.slice(opts.skip);
  }

  if (opts.top !== undefined && opts.top >= 0) {
    result = result.slice(0, opts.top);
  }

  return result;
}

/**
 * Walk the chain via F-015's `verifyAuditChain` primitive. Returns the
 * zero-based index of the first tampered entry, or `null` when the chain
 * is fully intact.
 *
 * This is the F-016 brief's chain-integrity helper — a simple wrapper that
 * normalizes `verifyAuditChain`'s discriminated union into the
 * `number | null` shape the brief specifies. Callers that need the
 * tampering reason (`entry_sha256 mismatch` vs `prev_sha256 mismatch`)
 * should call `verifyAuditChain` directly.
 */
export function findChainBreak(rows: readonly AuditLogEntry[]): number | null {
  const result = verifyAuditChain(rows);
  return result.valid ? null : result.broken_at;
}

// ----------------------------------------------------------------------------
// F-018 — Failure-pattern halt
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-018-failure-pattern-halt.md.
// Behavior contract (verbatim from ledger):
//   The engine watches a 9-value enum of trigger conditions:
//     consecutive_failures_3, consecutive_failures_10, overplanning_5,
//     overplanning_8, spawns_per_hour_exceeded, token_anomaly_2x,
//     rapid_prompt_burst, circuit_breaker_open, degradation_threshold.
//   When any trigger fires, the engine immediately transitions to `closing`
//   with `halted_by: <trigger_name>` and `trigger_evidence_sha256: <audit_entry_sha>`.
//   The retro signal (F-014) fires next, capturing the trigger evidence.
//   Thresholds are sourced from `rules/anomaly-thresholds.md` and overridable
//   per-run.
//
// Scope: this implementation lands the IN-MEMORY halt-detection primitive
// (HaltDetector class) + the verdict shape (RunHaltedVerdict) that F-020
// (kill-switch), F-021 (degradation-fallback), and F-022 (tool-quota) will
// reuse. Out-of-scope (per ledger out-of-scope-notes + soft-deps):
//   - F-006 logger surfacing of halt events (logging-pipeline owns routing)
//   - F-015 audit-evidence binding for trigger_evidence_sha256 (the field
//     is in the verdict shape but binding to a real audit row is F-015's job)
//   - F-020 kill-switch JSON file watcher (F-020 will call manualHalt())
//   - F-021 degradation source signal (F-021 will call recordDegradation())
//   - F-022 per-tool quota source (F-022 will call recordToolCall())
//
// Trigger surface naming reconciliation:
//   The brief proposed a 7-trigger enum (consecutive_failures, no_progress,
//   iteration_cap, tool_calls, manual, kill_switch, governance,
//   soul_boundary, degrade_escalate). The ledger's authoritative 9-value
//   enum is different (it carries threshold counts in the name, e.g.
//   `consecutive_failures_3`). Per FETCH BEFORE CITE / wave-008 lane-a
//   precedent, this impl encodes the ledger's enum + adds `manual`,
//   `iteration_cap`, `tool_calls_quota` as 3 sibling triggers for full
//   HaltDetector surface coverage (F-020 / cycle-cap / F-022 reuse).

/**
 * Trigger conditions that cause the engine to halt mid-run.
 *
 * The first 9 values are the F-018 ledger's authoritative automatic-halt
 * trigger enum. The last 3 (`manual`, `iteration_cap`, `tool_calls_quota`)
 * are sibling triggers for the verdict shape's reuse by F-020 / F-001's
 * cycle-cap / F-022 — these are NOT new automatic anomaly classes; they
 * are halt-source labels for the verdict's `trigger` field.
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
  | 'tool_calls_quota';

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
 * `.claude/rules/anomaly-thresholds.md` values:
 *   - consecutive_failures: 3 (kit threshold key `consecutive_failures`)
 *   - planning_turns_without_write: 5 (overplanning trigger; kit key
 *     `planning_turns_without_write` defaults to 8 — F-018 ledger names 5
 *     for the FIRST trigger in the family, escalating to 8 for the second)
 *   - maxIterations: 100 (sibling trigger for F-001's cycle-cap reuse;
 *     F-001 enforces a hard cap of 50 separately — see MAX_CYCLES_HARD_CAP)
 *   - maxToolCalls: 200 (sibling trigger; F-022 will source the per-tool
 *     quota separately)
 *
 * The ledger override semantics (acceptance scenario 3): when the threshold
 * is overridden, the trigger NAME stays the canonical
 * `consecutive_failures_3` — the trigger identifies the FAMILY, not the
 * specific count. (Override `consecutive_failures_3 = 10` means "halt at 10
 * consecutive failures, but call it `consecutive_failures_3` in the verdict
 * for stable trigger taxonomy.")
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
   * F-022 will source the per-tool quota separately; this is the global
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
   * unconditional. F-020 will call this from its kill-switch JSON watcher.
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

// ----------------------------------------------------------------------------
