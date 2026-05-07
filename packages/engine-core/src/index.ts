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
 *   - backend-copilot.ts   — F-011 (copilot-sdk-provider) — implements IBackendProvider; origin='copilot'
 *   - backend-factory.ts   — F-012 (backend-factory) — `createBackend({kind, model})` → IBackendProvider
 *   - backend-events.ts    — F-013 (event-normalization) — type guards + `eventTextContent` for BackendEvent
 *   - heartbeat.ts         — F-023 (cron-heartbeat) — HeartbeatScheduler + cadence-zone validation per loop-cadence-discipline.md
 *   - cycle.ts             — F-138 (engine-cycle-orchestrator) — runEngineCycle composes F-001/F-002/F-009/F-014/F-015/F-018/F-019; resolves wave-016 HARD-BLOCK F1
 *   - backend-event-variant.ts — F-139 (backend-event-usage-variant) — usageEventToCostEntry mapper; resolves wave-016 D-36 (BackendEvent gains 'usage' variant in backend.ts)
 *   - retro-degradation.ts — F-140 (retro-outcome-degradation) — buildDegradationRetro helper for halted_by_degradation RetroOutcome (added in retro.ts)
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
export * from './backend-copilot.js';
export * from './backend-factory.js';
export * from './backend-events.js';
export * from './heartbeat.js';
export * from './checkpoint.js';
export * from './manual-halt.js';
export * from './cycle.js';
export * from './backend-event-variant.js';
export * from './retro-degradation.js';
