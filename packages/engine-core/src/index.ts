/**
 * @mad-council-claw/engine-core — barrel export.
 *
 * Per-feature files split out in wave-011 / lane-a to eliminate the
 * cross-lane staging race that recurred 5+ times across waves 5-10. Each
 * feature owns its own .ts file; this barrel re-exports everything that
 * was previously a single 1841-LOC index.ts.
 *
 * Authoritative ownership (FETCH BEFORE CITE — verify file before edit):
 *   - bootstrap.ts   — F-001 (engine-bootstrap-loop)
 *   - identity.ts    — F-002 (per-agent-identity-runid)
 *   - logger.ts      — F-006 (logging-pipeline)
 *   - storage.ts     — F-008 (local-storage-layout)
 *   - retro.ts       — F-014 (pre-close-retro-signal)
 *   - audit.ts       — F-015 (hash-chained-audit-log) + F-016 (query-audit-log)
 *   - halt.ts        — F-018 (failure-pattern-halt) — owns RunHaltedVerdict + HaltTrigger
 *   - cost.ts        — F-019 (cost-ledger)
 *   - killswitch.ts  — F-020 (kill-switch) — imports RunHaltedVerdict from halt.ts
 *   - quota.ts       — F-022 (tool-call-quota) — imports RunHaltedVerdict from halt.ts
 *
 * Cross-feature type sharing rule: shared types live with their FIRST owner;
 * later features import via `./<owner>.js` (ESM extension required even for
 * .ts source per Node ESM convention + tsconfig moduleResolution=Bundler).
 */

export * from './bootstrap.js';
export * from './identity.js';
export * from './logger.js';
export * from './storage.js';
export * from './retro.js';
export * from './audit.js';
export * from './halt.js';
export * from './cost.js';
export * from './killswitch.js';
export * from './quota.js';
