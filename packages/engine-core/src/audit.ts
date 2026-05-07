/**
 * F-015 Hash-chained audit log + F-016 Query audit log — GREEN.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-015-hash-chained-audit-log.md.
 * Behavior contract: every audit entry includes `prev_sha256` and `entry_sha256`
 * fields. `prev_sha256` is the `entry_sha256` of the immediately preceding
 * entry in the same run (or `"GENESIS"` for the first entry).
 * `entry_sha256 = sha256(canonical_json(entry_without_entry_sha256))`. The
 * audit log is append-only. `verifyAuditChain` walks the log and reports the
 * first index where a mismatch is detected, pointing precisely at the
 * tampered entry.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-016-query-audit-log.md
 * + wave-009 lane-b brief: read-only query helpers over an F-015 audit chain.
 * `queryAuditLog` filters/paginates a chain into a defensive copy
 * (chronological order preserved). `findChainBreak` reports the first
 * tampered index using F-015's verifyAuditChain primitive (or null when
 * the chain is intact).
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

import { createHash } from 'node:crypto';

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
