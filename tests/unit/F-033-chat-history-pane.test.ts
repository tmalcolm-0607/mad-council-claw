import { describe, it, expect } from 'vitest';
import {
  buildHistoryPane,
  resolveHistoryEntry,
  DEFAULT_HISTORY_PANE,
  HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD,
  type HistoryPaneOptions,
  type HistoryPaneDescriptor,
  type HistoryEntry,
  type HistoryEntryLifecycle,
} from '@mad-council-claw/desktop-shell';

/**
 * F-033 chat-history-pane — RED → GREEN test.
 * Per docs/03-feature-catalog/M5-desktop-shell/F-033-history.md
 * acceptance scenarios.
 *
 * Authored wave-019 / lane-a per the wave-019 lane-a brief; this is the
 * SECOND M5 desktop-shell feature transition (M5 was 11R + 1G at wave-19
 * start after F-032 GREEN'd in wave-018 / lane-c).
 *
 * Inherits the F-032-registered "descriptor-as-data, instantiation-deferred"
 * idiom: the test asserts the SHAPE that `buildHistoryPane(opts)` returns,
 * not actual DOM rendering or live IPC streaming. The descriptor is plain
 * data the eventual renderer-process consumer (a future M5 integration
 * wave) will hand to whichever virtualization library it picks (e.g.
 * react-virtuoso, tanstack/react-virtual). The substantive guarantees the
 * structural test enforces:
 *
 *   - sort order: history entries returned in `lastActivityUtc` DESC
 *     (ledger scenario 1: rail shows all runs sorted by last activity).
 *   - virtualization threshold: `virtualization.enabled === true` ONLY
 *     when entries.length >= threshold (default
 *     HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD = 100); below threshold
 *     `enabled === false` so small rails render as a flat list (ledger
 *     scenario 3 — rail virtualizes for >100 runs; the threshold is the
 *     mechanical predicate driving the badge).
 *   - lifecycle badge: each entry carries a typed lifecycle
 *     ('active' | 'closed' | 'halted') derived verbatim from the input
 *     run's lifecycle field (no silent translation; if the input has an
 *     unknown lifecycle string the resolver returns 'closed' — closed-run
 *     fallback is the safest read-only default per F-014/F-015 retro
 *     emission discipline).
 *   - selectedRunId: the descriptor carries which entry is currently
 *     selected; consumers wire their click handlers to update this via
 *     the F-007 IPC bridge. v1 stores the value verbatim — no validation
 *     against entries[].runId (the consumer is the renderer; if it sets a
 *     stale id, the consumer reconciles on the next tick).
 *   - liveUpdateChannel: the IPC channel name the rail subscribes to for
 *     active-run progress (per ledger scenario 2). Default is the
 *     well-known 'history.run.progress' channel; consumers may override.
 *     This is the runtime hook for ledger scenario 2 ("rail entry's
 *     last-activity timestamp updates within 2s without full-rail
 *     rerender"); the actual IPC handler wiring is deferred to the
 *     integration wave per `no-silent-deferrals.md`.
 *
 * Scope deviation from ledger §Acceptance scenarios (intentional, per
 * `no-silent-deferrals.md` + the wave-019 / lane-a brief):
 *   The ledger's three scenarios bind to a browser-suite test that boots
 *   the desktop renderer in headless Chromium and asserts visual rail
 *   behavior. The wave-019 / lane-a brief simplifies the v1 shape to a
 *   STRUCTURAL / INTERFACE-BASED unit test that asserts what
 *   `buildHistoryPane(opts)` returns. The browser-suite scenarios bind to
 *   the M5 integration wave (a future feature wave that wires
 *   the F-008 storage layout to the renderer-process via the F-007 IPC
 *   bridge; per F-004 vitest-playwright-config's "browser project runtime
 *   wiring deferred to first DOM-rendering spec consumer wave").
 *
 *   Substantive guarantees preserved by the structural test:
 *     - sort order (DESC by lastActivityUtc)
 *     - virtualization-threshold predicate
 *     - lifecycle-badge type-safety
 *     - IPC channel registration intent (live-update channel name)
 *     - selectedRunId pass-through
 *
 *   Deferred to M5 integration wave per `no-silent-deferrals.md`:
 *     - Actual DOM render of the rail (react-virtuoso / tanstack)
 *     - On-disk read of `<state-dir>/runs/` + `<state-dir>/archive/runs/<YYYY>/<MM>/`
 *       — caller resolves entries via F-008 storage helpers
 *     - F-007 IPC handler runtime wiring for live updates
 *     - 2s update SLA from ledger scenario 2 (the channel name + threshold
 *       declaration is the v1 contract; the SLA is observed at the
 *       consumer wave's e2e harness)
 *     - Full-text search / filter (v1.5 per ledger out-of-scope-notes)
 *     - History export/import (v1.5 per ledger out-of-scope-notes)
 *     - Server-synced multi-device history (out of v1 per ledger out-of-scope-notes)
 */
describe('F-033 chat-history-pane', () => {
  it('scenario 1: buildHistoryPane with no opts returns descriptor with default state (empty entries; default virtualization threshold; default live-update channel)', () => {
    const descriptor = buildHistoryPane();

    // Default-state contract (fresh install, no runs)
    expect(descriptor.entries).toEqual([]);
    expect(descriptor.selectedRunId).toBeNull();
    expect(descriptor.virtualization.threshold).toBe(
      HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD,
    );
    expect(descriptor.virtualization.enabled).toBe(false);
    // Live-update channel default: well-known 'history.run.progress'
    expect(typeof descriptor.liveUpdateChannel).toBe('string');
    expect(descriptor.liveUpdateChannel.length).toBeGreaterThan(0);

    // The whole descriptor MUST equal the canonical default — proves the
    // default object shape is stable across releases.
    expect(descriptor).toEqual(DEFAULT_HISTORY_PANE);
  });

  it('scenario 2: buildHistoryPane sorts entries by lastActivityUtc DESC (ledger scenario 1: most-recent run first)', () => {
    // Entries supplied in mixed order; the descriptor MUST present them
    // sorted by lastActivityUtc descending so the rail's first row is
    // the most-recently-active run (ledger §Behavior contract).
    const entries: HistoryEntry[] = [
      {
        runId: 'run-A',
        agentLabel: 'agent-A',
        lifecycle: 'closed',
        lastActivityUtc: '2026-05-05T10:00:00Z',
        costTotalUsd: 0.1,
      },
      {
        runId: 'run-C',
        agentLabel: 'agent-C',
        lifecycle: 'active',
        lastActivityUtc: '2026-05-07T10:00:00Z',
        costTotalUsd: 0.3,
      },
      {
        runId: 'run-B',
        agentLabel: 'agent-B',
        lifecycle: 'halted',
        lastActivityUtc: '2026-05-06T10:00:00Z',
        costTotalUsd: 0.2,
      },
    ];

    const descriptor = buildHistoryPane({ entries });

    expect(descriptor.entries.map((e) => e.runId)).toEqual(['run-C', 'run-B', 'run-A']);
    // Verify lifecycle badges round-trip verbatim (no silent translation)
    expect(descriptor.entries[0]!.lifecycle).toBe('active');
    expect(descriptor.entries[1]!.lifecycle).toBe('halted');
    expect(descriptor.entries[2]!.lifecycle).toBe('closed');
  });

  it('scenario 3: virtualization toggles based on entry count vs threshold (ledger scenario 3: virtualize >100 runs)', () => {
    // Below threshold: virtualization disabled (small rail = flat list)
    const small = buildHistoryPane({
      entries: Array.from({ length: 50 }, (_, i) => ({
        runId: `run-${i}`,
        agentLabel: 'agent',
        lifecycle: 'closed' as HistoryEntryLifecycle,
        lastActivityUtc: `2026-05-07T10:${String(i).padStart(2, '0')}:00Z`,
        costTotalUsd: 0,
      })),
    });
    expect(small.virtualization.enabled).toBe(false);
    expect(small.virtualization.threshold).toBe(
      HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD,
    );

    // At threshold: virtualization enabled (rail virtualizes per ledger scenario 3)
    const atThreshold = buildHistoryPane({
      entries: Array.from(
        { length: HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD },
        (_, i) => ({
          runId: `run-${i}`,
          agentLabel: 'agent',
          lifecycle: 'closed' as HistoryEntryLifecycle,
          lastActivityUtc: `2026-05-07T${String(Math.floor(i / 60)).padStart(2, '0')}:${String(i % 60).padStart(2, '0')}:00Z`,
          costTotalUsd: 0,
        }),
      ),
    });
    expect(atThreshold.virtualization.enabled).toBe(true);

    // Above threshold (500 runs per ledger scenario 3 phrasing): virtualization enabled
    const large = buildHistoryPane({
      entries: Array.from({ length: 500 }, (_, i) => ({
        runId: `run-${i}`,
        agentLabel: 'agent',
        lifecycle: 'closed' as HistoryEntryLifecycle,
        lastActivityUtc: `2026-05-07T10:00:00Z`,
        costTotalUsd: 0,
      })),
    });
    expect(large.virtualization.enabled).toBe(true);

    // Caller-supplied threshold overrides the default
    const customThreshold = buildHistoryPane({
      entries: Array.from({ length: 10 }, (_, i) => ({
        runId: `run-${i}`,
        agentLabel: 'agent',
        lifecycle: 'closed' as HistoryEntryLifecycle,
        lastActivityUtc: '2026-05-07T10:00:00Z',
        costTotalUsd: 0,
      })),
      virtualizationThreshold: 5,
    });
    expect(customThreshold.virtualization.threshold).toBe(5);
    expect(customThreshold.virtualization.enabled).toBe(true);
  });

  it('scenario 4: selectedRunId + liveUpdateChannel pass-through (ledger scenario 2: live updates via IPC; selection state)', () => {
    const entries: HistoryEntry[] = [
      {
        runId: 'run-A',
        agentLabel: 'agent-A',
        lifecycle: 'active',
        lastActivityUtc: '2026-05-07T10:00:00Z',
        costTotalUsd: 0.1,
      },
    ];

    // selectedRunId pass-through (consumer wires click handlers to update this)
    const selected = buildHistoryPane({ entries, selectedRunId: 'run-A' });
    expect(selected.selectedRunId).toBe('run-A');

    // selectedRunId is verbatim — no validation against entries[].runId
    // (consumer reconciles on next tick if stale)
    const stale = buildHistoryPane({ entries, selectedRunId: 'run-Z-not-in-entries' });
    expect(stale.selectedRunId).toBe('run-Z-not-in-entries');

    // Custom liveUpdateChannel passes through verbatim (typed against
    // F-007's IpcInvokeMap at the consumer call site)
    const custom = buildHistoryPane({
      entries,
      liveUpdateChannel: 'custom.history.channel',
    });
    expect(custom.liveUpdateChannel).toBe('custom.history.channel');
  });

  it('scenario 5: resolveHistoryEntry hydrates partial input with safe defaults; never throws on null/undefined/{}', () => {
    // Partial-state hydration (mirrors F-032's resolveWindowState contract).
    // The renderer may receive partial run records when the F-008 storage
    // layout returns a write that's still mid-flight (atomic-write
    // discipline prevents half-written files but a parse failure at the
    // caller's read site flowing through here as null/{} must produce a
    // usable entry with safe defaults).

    // null + undefined yield a placeholder shape with stable defaults
    const placeholderFromNull = resolveHistoryEntry(null);
    expect(placeholderFromNull.lifecycle).toBe('closed'); // safest default
    expect(placeholderFromNull.runId).toBe('');
    expect(placeholderFromNull.agentLabel).toBe('');
    expect(placeholderFromNull.costTotalUsd).toBe(0);
    expect(typeof placeholderFromNull.lastActivityUtc).toBe('string');

    expect(resolveHistoryEntry(undefined)).toEqual(placeholderFromNull);
    expect(resolveHistoryEntry({})).toEqual(placeholderFromNull);

    // Partial: caller-supplied fields win; missing fields take defaults
    const partial = resolveHistoryEntry({ runId: 'run-X', agentLabel: 'agent-X' });
    expect(partial.runId).toBe('run-X');
    expect(partial.agentLabel).toBe('agent-X');
    expect(partial.lifecycle).toBe('closed');
    expect(partial.costTotalUsd).toBe(0);

    // Unknown lifecycle string → 'closed' fallback (read-only safest default)
    const unknownLifecycle = resolveHistoryEntry({
      runId: 'run-Y',
      agentLabel: 'agent-Y',
      // @ts-expect-error — intentionally invalid lifecycle to verify fallback
      lifecycle: 'wibble-not-a-real-lifecycle',
      lastActivityUtc: '2026-05-07T10:00:00Z',
      costTotalUsd: 0.5,
    });
    expect(unknownLifecycle.lifecycle).toBe('closed');

    // Full input round-trips verbatim
    const full: HistoryEntry = {
      runId: 'run-full',
      agentLabel: 'agent-full',
      lifecycle: 'active',
      lastActivityUtc: '2026-05-07T11:00:00Z',
      costTotalUsd: 1.25,
    };
    expect(resolveHistoryEntry(full)).toEqual(full);
  });

  it('scenario 6: descriptor is a plain object — JSON-cloneable + type witness (mirrors F-032 idiom)', () => {
    // Inherits F-032's "descriptor-as-data, instantiation-deferred" idiom.
    // The descriptor is what the eventual renderer consumer hands to its
    // virtualization library; it MUST be JSON-serializable so a future
    // feature could persist a snapshot for restart-on-crash. No
    // functions, no class instances, no Date objects.
    const descriptor = buildHistoryPane({
      entries: [
        {
          runId: 'run-A',
          agentLabel: 'agent-A',
          lifecycle: 'active',
          lastActivityUtc: '2026-05-07T10:00:00Z',
          costTotalUsd: 0.1,
        },
      ],
      selectedRunId: 'run-A',
    });

    expect(() => JSON.stringify(descriptor)).not.toThrow();
    const round = JSON.parse(JSON.stringify(descriptor)) as HistoryPaneDescriptor;
    expect(round).toEqual(descriptor);

    // HistoryPaneOptions is the inputs shape — ALL fields optional;
    // callers may pass `{}` and get the canonical defaults.
    const opts: HistoryPaneOptions = {};
    void opts;
  });
});
