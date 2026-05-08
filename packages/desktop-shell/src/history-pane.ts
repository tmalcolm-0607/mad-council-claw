/**
 * F-033 chat-history-pane — multi-session left-rail descriptor + entry resolver.
 *
 * Per docs/03-feature-catalog/M5-desktop-shell/F-033-history.md.
 *
 * Inherits the F-032-registered "descriptor-as-data, instantiation-deferred"
 * idiom (see packages/desktop-shell/src/window.ts header comment for the
 * full register). This module produces the descriptor a future renderer
 * consumer hands to its virtualization library (react-virtuoso /
 * tanstack/react-virtual / hand-rolled); it does NOT render DOM, does NOT
 * subscribe to IPC events, does NOT read filesystem.
 *
 * The substantive guarantees this primitive enforces:
 *   - sort order: entries DESC by `lastActivityUtc` (rail's first row is
 *     the most-recently-active run per ledger §Behavior contract).
 *   - virtualization predicate: `enabled === true` ONLY when
 *     `entries.length >= threshold` (default
 *     HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD = 100); below
 *     threshold the rail renders as a flat list.
 *   - lifecycle badge type-safety: `HistoryEntryLifecycle` union; unknown
 *     strings fall back to 'closed' (the safest read-only default per
 *     F-014/F-015 retro emission discipline).
 *   - selectedRunId pass-through: the renderer wires click handlers
 *     to update this via the F-007 IPC bridge; v1 stores it verbatim.
 *   - liveUpdateChannel: the IPC channel name the rail subscribes to for
 *     active-run progress (default 'history.run.progress'); types as
 *     string for forward-compat with future `IpcInvokeMap` entries.
 *
 * Authored wave-019 / lane-a (2026-05-07).
 *
 * Composition:
 *   - F-032 (window, GREEN) — sibling M5 surface.
 *   - F-007 (ipc-contract-scaffold, LOCKED) — `liveUpdateChannel` will
 *     eventually type as `keyof IpcInvokeMap` once the M5 integration
 *     wave extends the map; v1 uses `string` since the scaffold is empty.
 *   - F-008 (local-storage-layout, LOCKED) — caller reads
 *     <state-dir>/runs/ + <state-dir>/archive/runs/<YYYY>/<MM>/ via
 *     F-008's atomic-read helpers and passes the parsed entries here.
 *   - F-001 (engine-bootstrap-loop, LOCKED), F-019 (cost-ledger, LOCKED)
 *     supply the data each row displays.
 *   - F-034 (info-panel, paired in same wave) — composes against
 *     `selectedRunId` (info panel reads selection; rail writes it).
 */

/** The lifecycle states a run can be in. The badge enum the rail renders. */
export type HistoryEntryLifecycle = 'active' | 'closed' | 'halted';

/** A single row in the history rail. */
export interface HistoryEntry {
  /** Unique run id; the renderer truncates for display. */
  runId: string;
  /** Human-readable agent label (e.g. 'orchestrator', 'researcher-A'). */
  agentLabel: string;
  /** Lifecycle badge state; drives badge colour in the renderer. */
  lifecycle: HistoryEntryLifecycle;
  /** ISO-8601 UTC timestamp of the run's last activity (drives sort order). */
  lastActivityUtc: string;
  /** Cumulative USD spend for this run per F-019 cost-ledger. */
  costTotalUsd: number;
}

/** Virtualization sub-shape on the descriptor. */
export interface HistoryPaneVirtualization {
  /** Whether the renderer should enable list-virtualization. */
  enabled: boolean;
  /** Threshold above which `enabled === true`. */
  threshold: number;
}

/**
 * Default threshold for enabling virtualization. Below this entry-count
 * the rail renders as a flat list; at-or-above the threshold the
 * renderer enables its virtualization library to keep DOM-node count
 * bounded (per ledger scenario 3: 500 runs → ~30 DOM nodes for visible
 * entries).
 */
export const HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD = 100;

/** Default IPC channel for live run-progress updates. */
const DEFAULT_LIVE_UPDATE_CHANNEL = 'history.run.progress';

/** The plain-data descriptor a future renderer consumer hands to its component tree. */
export interface HistoryPaneDescriptor {
  /** Entries sorted DESC by lastActivityUtc (most-recent first). */
  entries: ReadonlyArray<HistoryEntry>;
  /** Currently-selected run; null when nothing selected. */
  selectedRunId: string | null;
  /** Virtualization config; `enabled` is derived from entries.length vs threshold. */
  virtualization: HistoryPaneVirtualization;
  /** IPC channel name the rail subscribes to for live updates. */
  liveUpdateChannel: string;
}

/** Inputs accepted by `buildHistoryPane`. All fields optional. */
export interface HistoryPaneOptions {
  /** Run rows; will be sorted DESC by lastActivityUtc. */
  entries?: ReadonlyArray<HistoryEntry>;
  /** Currently-selected run id; null/undefined → null. */
  selectedRunId?: string | null;
  /** Override the virtualization threshold; default 100. */
  virtualizationThreshold?: number;
  /** Override the IPC channel; default 'history.run.progress'. */
  liveUpdateChannel?: string;
}

/** Canonical default for fresh installs (no runs on disk). */
export const DEFAULT_HISTORY_PANE: HistoryPaneDescriptor = {
  entries: [],
  selectedRunId: null,
  virtualization: {
    enabled: false,
    threshold: HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD,
  },
  liveUpdateChannel: DEFAULT_LIVE_UPDATE_CHANNEL,
};

const VALID_LIFECYCLES: ReadonlySet<HistoryEntryLifecycle> = new Set([
  'active',
  'closed',
  'halted',
]);

/**
 * Hydrate a partial / null / undefined entry-shape into a complete
 * {@link HistoryEntry}. Caller-supplied fields win; missing fields fall
 * back to safe defaults; an unknown `lifecycle` string falls back to
 * 'closed' (the safest read-only default per F-014/F-015 discipline).
 *
 * Never throws — corrupt or partial run records (e.g. mid-write reads
 * via F-008's atomic discipline returning null at the caller's parse
 * site) flow cleanly through here as a placeholder row.
 */
export function resolveHistoryEntry(
  entry: HistoryEntry | Partial<HistoryEntry> | null | undefined,
): HistoryEntry {
  if (entry === null || entry === undefined) {
    return {
      runId: '',
      agentLabel: '',
      lifecycle: 'closed',
      lastActivityUtc: new Date(0).toISOString(),
      costTotalUsd: 0,
    };
  }
  const lifecycle: HistoryEntryLifecycle =
    entry.lifecycle && VALID_LIFECYCLES.has(entry.lifecycle as HistoryEntryLifecycle)
      ? (entry.lifecycle as HistoryEntryLifecycle)
      : 'closed';
  return {
    runId: entry.runId ?? '',
    agentLabel: entry.agentLabel ?? '',
    lifecycle,
    lastActivityUtc: entry.lastActivityUtc ?? new Date(0).toISOString(),
    costTotalUsd: entry.costTotalUsd ?? 0,
  };
}

/**
 * Build the canonical descriptor for the desktop shell's left-rail
 * history pane. The descriptor is what the eventual renderer consumer
 * hands to its virtualization library; entries are sorted DESC by
 * lastActivityUtc (rail's first row is the most-recently-active run).
 *
 * @param opts - optional inputs (entries, selection, threshold,
 *   live-update channel). Defaults are appropriate for a fresh install.
 * @returns plain-object descriptor; JSON-cloneable; safe to persist.
 */
export function buildHistoryPane(opts: HistoryPaneOptions = {}): HistoryPaneDescriptor {
  const threshold =
    opts.virtualizationThreshold ?? HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD;
  const inputEntries = opts.entries ?? [];
  // Sort DESC by lastActivityUtc; ISO-8601 strings sort lexicographically
  // in chronological order, so a string compare gives correct ordering.
  const sorted = [...inputEntries].sort((a, b) =>
    a.lastActivityUtc < b.lastActivityUtc
      ? 1
      : a.lastActivityUtc > b.lastActivityUtc
        ? -1
        : 0,
  );
  return {
    entries: sorted,
    selectedRunId: opts.selectedRunId ?? null,
    virtualization: {
      enabled: sorted.length >= threshold,
      threshold,
    },
    liveUpdateChannel: opts.liveUpdateChannel ?? DEFAULT_LIVE_UPDATE_CHANNEL,
  };
}
