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
 *   - redaction.ts   — F-017 (audit-pii-redaction)
 *   - halt.ts        — F-018 (failure-pattern-halt) — owns RunHaltedVerdict + HaltTrigger
 *   - cost.ts        — F-019 (cost-ledger)
 *   - killswitch.ts  — F-020 (kill-switch) — imports RunHaltedVerdict from halt.ts
 *   - quota.ts       — F-022 (tool-call-quota) — imports RunHaltedVerdict from halt.ts
 *   - degradation.ts — F-021 (degradation-fallback) — imports RunHaltedVerdict from halt.ts
 *   - backend.ts     — F-009 (ibackend-provider) — imports Agent/Session from identity.ts + RunHaltedVerdict from halt.ts
 *   - backend-anthropic.ts — F-010 (anthropic-sdk-provider) — implements IBackendProvider; origin='anthropic'
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
export * from './redaction.js';
export * from './halt.js';
export * from './cost.js';
export * from './killswitch.js';
export * from './quota.js';
export * from './degradation.js';
export * from './backend.js';
export * from './backend-anthropic.js';
