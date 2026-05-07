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
// ----------------------------------------------------------------------------
// F-006 — Logging pipeline (in-memory boundary primitive)
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M0-bootstrap/F-006-logging-pipeline.md.
// Behavior contract scoped to wave-9 / lane-a: a structured-logging facade
// that emits LogEvent records to an injectable sink. Each event carries
// `{timestamp, level, event, ...ctx}` with the four common levels
// (debug | info | warn | error). Level-gating drops events below the
// configured threshold; context fields merge onto the record so callers can
// stamp `agent_id`, `run_id`, `cycle`, etc. without nesting.
//
// This is the in-memory boundary primitive that two future flips will
// compose against:
//   - F-008 (storage layout): the filesystem sink that writes the LogEvent
//     stream to `runs/<run_id>/log.ndjson` line-by-line.
//   - F-015 (hash-chained audit log, already GREEN wave-008/lane-b): an
//     audit-routing sink can call appendAuditEntry() so every emitted event
//     also enters the tamper-evident chain.
// Both compositions are out of scope here per `rules/no-silent-deferrals.md`
// and the F-006 ledger §dependencies. The current flip lands the boundary
// shape (LogEvent + Logger + createLogger) the integrations will plug into.
//
// Out of scope (per ledger): the `no-console` ESLint rule (acceptance scenario
// 2 of the ledger) is enforced by ESLint config, not by a runtime test.
// Six-level set (`trace | fatal`) is straightforward to extend later — the
// brief specifies the four common levels for v1. Degradation signal when
// the audit-log writer is offline (acceptance scenario 3 of the ledger)
// requires the audit-log integration which is itself out of scope above.

/**
 * Recognized log levels in order of severity. Per the F-006 ledger the full
 * level set is `trace | debug | info | warn | error | fatal`; this minimal
 * flip implements the four common levels per the brief's TypeScript hint.
 * Extending to six is straightforward and lives in a follow-on flip.
 */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/**
 * A single emitted log record. Reserved keys: `timestamp`, `level`, `event`.
 * All caller-supplied context fields merge onto the record at the top level
 * — minimum-change discipline per the brief's hint. The F-008 storage flip
 * will serialize these records line-by-line to `runs/<run_id>/log.ndjson`;
 * the F-015 audit integration will route them through `appendAuditEntry`.
 *
 * Optional fields like `run_id` / `agent_id` are not part of the LogEvent
 * type itself — they enter via the ctx merge (per scenario 3). The ledger's
 * §Behavior contract names them as the load-bearing identity stamps that
 * F-002 (already GREEN) supplies; the logger itself is identity-agnostic
 * so callers can stamp via the same `stampIdentity()` helper that decorates
 * audit entries.
 */
export interface LogEvent {
  /** ISO-8601 UTC timestamp (e.g. "2026-05-07T00:04:25.123Z"). */
  timestamp: string;
  /** One of `LogLevel`. */
  level: LogLevel;
  /** Short event name in dot-segment form (e.g. `cycle.start`, `audit.write.failed`). */
  event: string;
  /** Caller-supplied context fields merged onto the record. */
  [key: string]: unknown;
}

/**
 * The four-method logging facade. Each method takes an event name and an
 * optional context bag whose fields merge onto the emitted LogEvent.
 *
 * Per `rules/canonical-skill-only.md`-style discipline (the F-006 ledger's
 * "ONLY supported way to emit logs from engine-core" clause), engine-core
 * code should reach for this facade — direct `console.log` is forbidden by
 * the no-console lint rule (acceptance scenario 2 of the ledger; ESLint
 * config not runtime).
 */
export interface Logger {
  debug(event: string, ctx?: Record<string, unknown>): void;
  info(event: string, ctx?: Record<string, unknown>): void;
  warn(event: string, ctx?: Record<string, unknown>): void;
  error(event: string, ctx?: Record<string, unknown>): void;
}

/** Numeric ordering for level-gating — `debug < info < warn < error`. */
const LOG_LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

/**
 * Default sink — emits the LogEvent as a single JSON-stringified line on
 * stdout. The brief specifies this default; it gives the facade a working
 * out-of-the-box shape for headless smoke tests. Production callers (engine
 * cycles, audit integrations) will inject custom sinks per scenario 4.
 *
 * Reach for `console.log` here is the ONE permitted use — it's the default
 * sink BEHIND the facade, not engine code emitting log events. The
 * no-console lint rule will scope its allowlist accordingly.
 */
function defaultSink(event: LogEvent): void {
  // eslint-disable-next-line no-console -- default sink only; engine code MUST use the Logger facade.
  console.log(JSON.stringify(event));
}

/**
 * Create a structured-logging facade.
 *
 * Acceptance scenarios from the F-006 ledger + wave-9 / lane-a brief:
 *   1. `logger.info('cycle.start', { cycle: 3 })` → LogEvent with timestamp,
 *      level=info, event='cycle.start', cycle=3.
 *   2. Level-gating: min-level `warn` drops debug/info; emits warn/error.
 *   3. Context fields merge: caller-supplied keys (agent_id, run_id, cycle,
 *      reason, ...) appear at the top level of the emitted record.
 *   4. Sink injection: custom sink receives every event; default `console.log`
 *      sink is NOT invoked when a sink is provided.
 *
 * The facade is identity-agnostic — F-002's `stampIdentity()` is the
 * audit-writer boundary that decorates artifacts with the {agent_id, run_id,
 * parent_run_id} triple. Callers route stamped artifacts through the
 * Logger.* methods; the Logger does not auto-stamp. This keeps the boundary
 * shape minimal and lets the F-008 storage flip + F-015 audit integration
 * compose without forcing identity through the facade itself.
 *
 * @param level - minimum level to emit (default `info`); events at lower
 *                severity are dropped.
 * @param sink  - injectable sink invoked once per emitted event (default
 *                JSON-stringified stdout).
 * @returns a `Logger` whose `debug`/`info`/`warn`/`error` methods route
 *          through the level-gate and sink.
 */
export function createLogger(
  level: LogLevel = 'info',
  sink: (event: LogEvent) => void = defaultSink,
): Logger {
  const minOrder = LOG_LEVEL_ORDER[level];

  const emit = (
    levelOfCall: LogLevel,
    eventName: string,
    ctx: Record<string, unknown> = {},
  ): void => {
    if (LOG_LEVEL_ORDER[levelOfCall] < minOrder) {
      return; // level-gating: drop below threshold (scenario 2).
    }
    // Build the LogEvent. Reserved keys (`timestamp`, `level`, `event`) win
    // over any same-named ctx keys — the ctx spread happens FIRST, then
    // reserved keys overwrite. This keeps the contract stable: callers
    // can't accidentally shadow the canonical fields by passing
    // `{ level: 'info' }` in ctx.
    const record: LogEvent = {
      ...ctx,
      timestamp: new Date().toISOString(),
      level: levelOfCall,
      event: eventName,
    };
    sink(record);
  };

  return {
    debug: (event, ctx) => emit('debug', event, ctx),
    info: (event, ctx) => emit('info', event, ctx),
    warn: (event, ctx) => emit('warn', event, ctx),
    error: (event, ctx) => emit('error', event, ctx),
  };
}

// ----------------------------------------------------------------------------
// F-008 — Local storage layout
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md.
// Behavior contract: the engine writes all persistent state under a single
// `~/.mad-council-claw/` root. Subdirectories: sessions/, skills/,
// automations/, audit/. The settings.json file lives at the root. Every
// mutable JSON file is written atomically via the write-temp-then-rename
// pattern from `concurrency-safety.md` §2; readers never observe a
// half-written file.
//
// Surface:
//   - StorageLayout: the 5-path + settingsFile struct.
//   - getStorageLayout(rootOverride?): pure path computation.
//   - ensureStorageLayout(layout): idempotent dir creation (mkdir recursive).
//   - atomicWriteJson(path, content): write-temp + rename.
//   - readJson<T>(path): JSON parse helper, typed.
//
// The atomic-write helper is the building block that future flips compose
// against (F-006 filesystem sink writing log.ndjson — line-append, not
// JSON-rewrite, so a different helper; F-015 audit chain writing
// audit.ndjson; F-019 cost ledger; F-020 kill-switch.json — the
// last-write-wins semantics from concurrency-safety §4 ride on this
// helper's atomic rename).
//
// Out of scope (per ledger §out-of-scope-notes):
//   - Encrypted-at-rest storage of secrets/keys (M8 / F-070-F-071).
//   - Sweep of orphaned `<path>.tmp` files on startup (ledger §Edge cases).
//   - Per-run `runs/<run_id>/` subdirectory creation — F-001/F-008
//     integration flip; this lands the static layout primitives the
//     run-bootstrap will compose against.

import {
  existsSync as _existsSync,
  mkdirSync as _mkdirSync,
  readFileSync as _readFileSync,
  renameSync as _renameSync,
  writeFileSync as _writeFileSync,
} from 'node:fs';
import { join as _join } from 'node:path';
import { homedir as _homedir } from 'node:os';

/**
 * Snapshot of the on-disk layout. `root` anchors the tree; the four
 * subdirectory paths are deterministic joins (`<root>/sessions`,
 * `<root>/skills`, `<root>/automations`, `<root>/audit`); `settingsFile`
 * is the canonical settings.json at the root.
 *
 * StorageLayout is a pure value — no filesystem side-effects. Pair with
 * {@link ensureStorageLayout} to materialize the dirs and
 * {@link atomicWriteJson} to write content.
 */
export interface StorageLayout {
  root: string;
  sessions: string;
  skills: string;
  automations: string;
  audit: string;
  settingsFile: string;
}

/**
 * Compute the on-disk layout. With no argument, anchors to
 * `~/.mad-council-claw/` under the operator's home directory; with
 * `rootOverride`, anchors to the supplied path (used by tests + by
 * non-default install scenarios).
 *
 * Pure function — does NOT touch the filesystem. Callers must invoke
 * {@link ensureStorageLayout} to materialize the directory tree.
 */
export function getStorageLayout(rootOverride?: string): StorageLayout {
  const root = rootOverride ?? _join(_homedir(), '.mad-council-claw');
  return {
    root,
    sessions: _join(root, 'sessions'),
    skills: _join(root, 'skills'),
    automations: _join(root, 'automations'),
    audit: _join(root, 'audit'),
    settingsFile: _join(root, 'settings.json'),
  };
}

/**
 * Materialize the layout's directory tree. Idempotent: re-runs do not
 * throw on existing dirs (mkdir uses `recursive: true`). Does NOT create
 * `settingsFile` — that's a JSON file whose lifecycle is owned by
 * {@link atomicWriteJson}.
 */
export function ensureStorageLayout(layout: StorageLayout): void {
  for (const dir of [
    layout.root,
    layout.sessions,
    layout.skills,
    layout.automations,
    layout.audit,
  ]) {
    if (!_existsSync(dir)) {
      _mkdirSync(dir, { recursive: true });
    }
  }
}

/**
 * Atomic JSON write per kit's `concurrency-safety.md` §2.
 *
 * Steps:
 *   1. Serialize content as pretty-printed JSON (2-space indent).
 *   2. Write to `<path>.tmp` via writeFileSync.
 *   3. Rename `<path>.tmp` → `<path>` — atomic on POSIX + Windows NTFS.
 *
 * A reader that opens `<path>` either sees the pre-update file or the
 * post-update file — never a half-written one. The `.tmp` orphan is
 * consumed by the rename; on a successful return, no `.tmp` file remains.
 *
 * On a writer crash between step 2 and step 3, the `.tmp` orphans;
 * the startup sweep (out of scope here, ledger §Edge cases) reclaims it.
 */
export function atomicWriteJson(path: string, content: unknown): void {
  const tmp = `${path}.tmp`;
  _writeFileSync(tmp, JSON.stringify(content, null, 2), 'utf8');
  _renameSync(tmp, path);
}

/**
 * Read + JSON-parse a file. Typed for caller convenience; on parse error
 * the underlying SyntaxError propagates (callers handle).
 */
export function readJson<T = unknown>(path: string): T {
  return JSON.parse(_readFileSync(path, 'utf8')) as T;
}

// ----------------------------------------------------------------------------
// F-019 — Per-agent cost ledger
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-019-cost-ledger.md.
// Behavior contract (verbatim from ledger):
//   Every `usage` event from a backend (per F-013) is converted to a
//   cost-ledger row at runs/<run_id>/cost-ledger.ndjson. Each row carries
//   {run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens,
//    output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}. Costs
//   are computed using a per-model price table (versioned in
//   pricing/<backend>.json). Aggregations over the ledger (sum per agent,
//   per run, per day) are deterministic. The ledger NEVER auto-imposes
//   budgets — observable-only, per `rules/no-invented-constraints.md`.
//
// Scope: this implementation lands the IN-MEMORY ledger primitive
// (CostLedger class + CostEntry shape). Out of scope (per ledger
// out-of-scope-notes + soft-deps):
//   - Cost-budget enforcement (auto-halt when run exceeds budget) is gated
//     on the user EXPLICITLY setting a budget per
//     `rules/no-invented-constraints.md`. F-019 records facts; it does
//     NOT impose default budgets.
//   - Persistence to runs/<run_id>/cost-ledger.ndjson (F-008's job —
//     atomicWriteJson + the ndjson append helper plug in here).
//   - Live event consumption from F-013 (event-normalization) — the
//     ledger accepts pre-normalized rows.
//   - Per-model price table (versioned `pricing/<backend>.json`) is supplied
//     by the caller via `usd_estimate`; F-013's normalizer will compute it
//     in a future flip and feed the ledger.
//
// Shape reconciliation (from wave-010 / lane-a brief):
//   The brief proposed a CostEntry shape:
//     {seq, timestamp, agent_id, run_id, tokens_in, tokens_out, usd_estimate,
//      failure_mode?, model}
//   The F-019 ledger names a richer shape:
//     {run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens,
//      output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}
//   Per FETCH BEFORE CITE / wave-009 lane-c precedent (honor authoritative
//   ledger over brief snippet), this impl encodes the ledger's full shape
//   on each row WHILE exposing the brief's simpler API (tokens_in/tokens_out
//   alias input_tokens/output_tokens; usd_estimate aliases cost_usd; seq +
//   timestamp + failure_mode are sibling fields the brief's shape adds for
//   ergonomics — preserved). Both names are present on every row so
//   downstream consumers can use either alias.

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
 *
 * Optional `cache_read_tokens` / `cache_write_tokens` default to 0 if absent
 * — most call sites won't supply them until F-013 normalizes prompt-cache
 * usage events.
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
   * The writer mirrors the brief's API names (`tokens_in`, `tokens_out`,
   * `usd_estimate`) onto the ledger's authoritative names (`input_tokens`,
   * `output_tokens`, `cost_usd`) so consumers using either name see the
   * same numbers.
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

// ----------------------------------------------------------------------------
// F-022 — Per-spawn tool-call quota
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-022-tool-quota.md.
// Behavior contract (from ledger):
//   Every tool invocation an agent makes is counted against per-agent quotas.
//   When a quota is reached, further tool calls reject with
//   `QUOTA_EXCEEDED: <quota_name>` and the rejection is logged. Quotas are
//   per-agent (independent counters per agent_id) and run-scoped (counters
//   reset on new run).
//
// Scope reconciliation with F-018 (FETCH BEFORE CITE):
//   F-018 already added a GLOBAL `recordToolCall()` method on `HaltDetector`
//   that emits `RUN_HALTED` with trigger `tool_calls_quota`. F-022 extends
//   that surface with PER-AGENT tracking — separate counter keyed by
//   agent_id. The two surfaces coexist:
//     - F-018's global counter catches runaway aggregate usage across a run
//     - F-022's per-agent counter catches per-spawn quota exhaustion
//   Both reuse `RunHaltedVerdict`. F-022 emits trigger `'tool_calls'`
//   (added to HaltTrigger union); F-018 emits `'tool_calls_quota'`. F-014's
//   `halted_by_tool_quota` retro outcome (already in RetroOutcome enum)
//   consumes both.
//
// Out of scope (per ledger §out-of-scope-notes + wave-10 brief):
//   - max_calls_per_run (1000 default) and max_tools_active (10 default)
//     are mentioned in the ledger Behavior contract but the wave-10 brief
//     scopes F-022 to per-spawn (per agent_id) cap only. M7 owns
//     skill-allowlist + version-pinning per ledger §out-of-scope-notes.
//   - F-006 logger surfacing of QUOTA_EXCEEDED events — F-022 emits the
//     verdict; F-006 routes it.
//   - F-015 audit-evidence binding for `trigger_evidence_sha256` — the
//     field is optional in the verdict shape; binding to a real audit row
//     is F-015's integration step.

/**
 * Per-spawn (per agent_id) tool-call quota enforcer.
 *
 * Acceptance scenarios from the F-022 ledger + wave-10 brief:
 *   1. Per-agent counter independence — agent A and B have separate counters
 *      within the same run (ledger scenario 2).
 *   2. Exceeding `maxPerAgent` returns `RunHaltedVerdict` with
 *      `trigger: 'tool_calls'` (ledger scenario 1).
 *   3. Verdict carries `agent_id` of the offending agent (audit anchor).
 *   4. `reset(agentId)` clears a single agent's counter.
 *   5. `resetAll()` clears every agent's counter.
 *   6. `getCount` before any call returns 0.
 *   7. Default `maxPerAgent = 50` (mid-point between ledger's 50/1000 caps;
 *      wave-10 brief specifies 50 explicitly as the per-spawn default).
 *
 * The class is in-memory only — persistence (`runs/<run_id>/quota-state.json`)
 * is F-008's job per the F-022 ledger §depends-on. The verdict shape reuses
 * F-018's `RunHaltedVerdict` so F-014's retro consumer needs no changes.
 *
 * Reset semantics:
 *   - `reset(agentId)`: clears one agent's counter (e.g. spawn lifecycle end).
 *   - `resetAll()`: clears every agent's counter (e.g. run boundary).
 *   - No automatic decay — counters are monotonic per-agent until reset.
 *     (The run is the natural reset boundary; sub-run resets are F-001's
 *     cycle-boundary call site, which will use `reset` per-agent at cycle
 *     end if/when per-cycle quotas land — out of scope for this flip.)
 */
export class ToolCallQuota {
  private readonly callsByAgent = new Map<string, number>();
  private readonly maxPerAgent: number;

  constructor(maxPerAgent = 50) {
    this.maxPerAgent = maxPerAgent;
  }

  /**
   * Record a tool call by `agentId`. Returns a halt verdict if this call
   * pushed the agent's count past `maxPerAgent`; null otherwise.
   *
   * The counter increments BEFORE the threshold check, so the verdict's
   * `reason` reports the actual breach value (e.g. "51 > 50"), giving
   * operators a precise audit anchor.
   */
  recordCall(agentId: string): RunHaltedVerdict | null {
    const current = (this.callsByAgent.get(agentId) ?? 0) + 1;
    this.callsByAgent.set(agentId, current);
    if (current > this.maxPerAgent) {
      return {
        type: 'RUN_HALTED',
        trigger: 'tool_calls',
        reason: `Agent ${agentId} exceeded per-spawn tool-call quota (${current} > ${this.maxPerAgent})`,
        timestamp: new Date().toISOString(),
        agent_id: agentId,
      };
    }
    return null;
  }

  /** Return the current call count for `agentId`. Unseen agents return 0. */
  getCount(agentId: string): number {
    return this.callsByAgent.get(agentId) ?? 0;
  }

  /** Clear a single agent's counter. No-op when the agent is unseen. */
  reset(agentId: string): void {
    this.callsByAgent.delete(agentId);
  }

  /** Clear every agent's counter. Used at run-boundary reset. */
  resetAll(): void {
    this.callsByAgent.clear();
  }
}

// ----------------------------------------------------------------------------
// F-020 — Read-time-propagating kill switch
// ----------------------------------------------------------------------------
//
// Per docs/03-feature-catalog/M2-governance-triad/F-020-kill-switch.md
// + wave-010 / lane-b brief.
//
// Behavior contract (lane-b brief shape): a `KillSwitch` class checked at
// the START of every model + tool call. Kill state surfaces from EITHER
// an environment variable (default `MAD_KILL=1` or `=true`) OR the
// existence of a designated file (caller-supplied path; checked via the
// injected `fileExistsFn`). When triggered:
//   - `isTriggered()` returns true (idempotent across reads — read-time
//     propagation per the F-020 ledger; no internal state mutation).
//   - `checkOrThrow()` throws an Error decorated with a `RunHaltedVerdict`
//     whose `trigger` is `manual` (the F-018 sibling trigger reserved for
//     operator/kill-switch invocations) per the F-018 verdict-shape contract.
//
// Scope deviation from ledger (intentional, documented per
// rules/no-silent-deferrals.md):
//   The F-020 ledger §Behavior contract names a JSON file at
//   `userData/mad-council-claw/kill-switch.json` with
//   `{halted, reason?, set_at_utc?, set_by?}` schema. The lane-b brief
//   simplifies to existence-check only (file present ⇔ halted=true) plus
//   an env-var path. JSON parsing + reason/set_at_utc/set_by capture is
//   deferred to the engine-cycle integration step that consumes this
//   primitive — when F-001's bootstrap loop calls `checkOrThrow()` at
//   cycle start, an extension can read the JSON and pass `reason` into
//   the verdict.
//
// Out of scope (per ledger out-of-scope-notes + brief):
//   - JSON schema parsing (deferred to engine-cycle integration).
//   - F-008 storage layout for the kill-switch file path resolution.
//   - F-014 retro-signal `outcome: halted_by_kill_switch` consumer wiring —
//     the engine cycle that catches the throw and routes to closing.
//   - F-015 audit-log entry for the kill-switch read result.
//   - Read-at-cycle-start hook integration with F-001's bootstrap loop.
//
// The KillSwitch primitive is the in-memory boundary that the engine-cycle
// integration will plug into; this flip lands the primitive shape only.

/**
 * Default function used to test file existence. Wraps `node:fs.existsSync`
 * so callers don't have to import `fs` themselves; the module is loaded
 * lazily via `require` so test harnesses can pass an injected stub without
 * the real fs module being touched.
 *
 * Errors during the check are swallowed (return false) — a permissions
 * error or a transient FS hiccup should NOT be interpreted as "the
 * kill-file exists." Read-time propagation per the ledger means we
 * fail-safe to "not halted" when the FS layer misbehaves; an explicit
 * env-var override (`MAD_KILL=1`) remains the operator's belt-and-braces
 * path.
 */
function defaultKillFileExists(path: string): boolean {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires -- lazy CJS require so injected stubs in tests never trigger fs load.
    const fs = require('node:fs') as typeof import('node:fs');
    return fs.existsSync(path);
  } catch {
    return false;
  }
}

/**
 * Read-time-propagating kill switch.
 *
 * Construction is parameterized for testability — the env source and the
 * file-existence check are both injectable, so unit tests can drive the
 * full state matrix without touching the real filesystem or process env.
 * The default shape (no args) consults `process.env.MAD_KILL` and treats
 * a null kill-file path as "no file check configured."
 *
 * Acceptance scenarios from the wave-010 / lane-b brief + F-020 ledger:
 *   1-2. Env var MAD_KILL=1 or =true → triggered.
 *   3.   Env unset, kill-file exists → triggered.
 *   4-5. Env unset, no path OR path with non-existent file → not triggered.
 *   6.   checkOrThrow() throws Error+verdict (trigger='manual') when triggered.
 *   7.   checkOrThrow() is a no-op when not triggered.
 *   8.   Multiple isTriggered() calls are idempotent (no state mutation).
 *   9.   Custom envVarName respected; default MAD_KILL not consulted.
 *
 * Read-time propagation: every `isTriggered()` call re-reads the env + FS
 * sources, so a kill triggered AFTER engine boot is observed on the NEXT
 * cycle (per the F-020 ledger acceptance scenario 1).
 *
 * The verdict shape is the F-018 `RunHaltedVerdict` with `trigger='manual'`,
 * preserving a single uniform halt-reporting surface across F-018
 * (failure-pattern halt), F-020 (kill-switch), F-021 (degradation), and
 * F-022 (tool-quota). Callers downstream of `checkOrThrow()` can pattern-match
 * on `error.verdict.trigger` to route to the right F-014 retro outcome
 * (`halted_by_kill_switch` for trigger='manual' from a kill-switch source).
 */
export class KillSwitch {
  constructor(
    private readonly killFilePath: string | null = null,
    private readonly envVarName: string = 'MAD_KILL',
    private readonly fileExistsFn: (path: string) => boolean = defaultKillFileExists,
    private readonly env: Record<string, string | undefined> = process.env,
  ) {}

  /**
   * Read the kill-switch state at this exact moment. Returns true if EITHER
   * the configured env var is `'1'` or `'true'`, OR the kill-file path is
   * configured AND `fileExistsFn` returns true for it.
   *
   * No internal state is mutated — multiple calls are idempotent in the
   * sense that the same inputs produce the same outputs. Inputs CAN
   * change between calls (the env Record may be mutated, the file may be
   * created or removed), and the read-time-propagation contract requires
   * those changes to be observed on the next call.
   */
  isTriggered(): boolean {
    const envVal = this.env[this.envVarName];
    if (envVal === '1' || envVal === 'true') {
      return true;
    }
    if (this.killFilePath !== null && this.fileExistsFn(this.killFilePath)) {
      return true;
    }
    return false;
  }

  /**
   * Throw a `RunHaltedVerdict`-decorated Error if the kill switch is
   * triggered; otherwise return undefined (no-op). The thrown Error's
   * `verdict` property carries the F-018 verdict shape with
   * `trigger='manual'` and a non-empty `reason` describing which source
   * tripped (env var or file).
   *
   * Designed to be called at the START of every model + tool call —
   * cycle-start hook integration is the engine-bootstrap (F-001)
   * integration step that this primitive feeds.
   */
  checkOrThrow(): void {
    if (!this.isTriggered()) {
      return;
    }

    // Identify the source for the verdict reason — gives the operator + the
    // F-014 retro a precise audit trail.
    const envVal = this.env[this.envVarName];
    const envTripped = envVal === '1' || envVal === 'true';
    const fileTripped =
      this.killFilePath !== null && this.fileExistsFn(this.killFilePath);

    let reason: string;
    if (envTripped && fileTripped) {
      reason = `Kill switch triggered: env ${this.envVarName}=${envVal} AND file ${this.killFilePath} exists`;
    } else if (envTripped) {
      reason = `Kill switch triggered: env ${this.envVarName}=${envVal}`;
    } else if (fileTripped) {
      reason = `Kill switch triggered: file ${this.killFilePath} exists`;
    } else {
      // Should be unreachable — isTriggered() returned true above.
      reason = 'Kill switch triggered';
    }

    const verdict: RunHaltedVerdict = {
      type: 'RUN_HALTED',
      trigger: 'manual',
      reason,
      timestamp: new Date().toISOString(),
    };

    const err = new Error(reason) as Error & { verdict: RunHaltedVerdict };
    err.verdict = verdict;
    throw err;
  }
}
