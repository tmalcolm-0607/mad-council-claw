/**
 * F-034 session-info-panel — read-only run-metadata panel descriptor.
 *
 * Per docs/03-feature-catalog/M5-desktop-shell/F-034-info-panel.md.
 *
 * Inherits the F-032-registered "descriptor-as-data, instantiation-deferred"
 * idiom (see packages/desktop-shell/src/window.ts header comment for the
 * full register) AND exemplifies the **explicit-placeholder discipline**
 * corollary: when source data is missing, the descriptor surfaces a
 * typed placeholder (INFO_PANEL_PLACEHOLDER = '—'), NOT a silent zero or
 * empty string. This is a direct mechanization of
 * `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT into
 * the descriptor's field types — readers can mechanically detect missing
 * data by string-equality with the placeholder.
 *
 * The substantive guarantees this primitive enforces:
 *   - Read-only field rendering (descriptor has no edit handlers).
 *   - Audit-chain badge type-safety ('green' | 'yellow' | 'red'); the
 *     descriptor's `'red'` state masks the cost breakdown + emits a
 *     Context Gap line per `kit:rules/degradation-fallback-policy.md`
 *     Rule 3 (data-integrity warning per ledger scenario 2).
 *   - Missing cost-ledger (`costBreakdownAvailable: false`) → empty
 *     `costBreakdown` array + `costBreakdownPlaceholder: '—'` + Context
 *     Gap line (per ledger scenario 3 — explicit placeholder, NOT silent
 *     zero).
 *   - Default `isOpen: true` (panel default-open per ledger §Behavior contract).
 *   - Closed-only `retroSummary` enforcement (active runs cannot carry
 *     retro per F-014's emit-on-close discipline).
 *
 * Authored wave-019 / lane-a (2026-05-07).
 *
 * Composition:
 *   - F-032 (window, GREEN), F-033 (history-pane, paired in same wave)
 *     — sibling M5 surfaces.
 *   - F-002 (per-agent identity + run-id) — supplies `agentLabel`.
 *   - F-014 (pre-close retro signal, LOCKED) — supplies `retroSummary`.
 *   - F-015 (hash-chained audit log, LOCKED) — supplies
 *     `auditChainStatus`; the red-masks-cost discipline preserves
 *     data-integrity warning semantics.
 *   - F-019 (cost-ledger, LOCKED) — supplies `CostBreakdown[]`.
 *   - F-020 (kill-switch, LOCKED) — supplies `killSwitchActive`.
 *   - F-007 (ipc-contract-scaffold, LOCKED) — IPC channels for live
 *     updates type-check against `keyof IpcInvokeMap` at the consumer
 *     call site.
 */

/** The lifecycle states a run can be in. Mirrors F-033's HistoryEntryLifecycle. */
export type RunLifecycle = 'active' | 'closed' | 'halted';

/** The audit-chain verification status per F-015. */
export type AuditChainStatus = 'green' | 'yellow' | 'red';

/** A single cost sub-total (per tool or per model). */
export interface CostBreakdown {
  /** What kind of cost this represents. */
  kind: 'tool' | 'model';
  /** Human-readable label (tool name or model id). */
  label: string;
  /** USD spend for this kind+label. */
  usd: number;
}

/**
 * The literal placeholder string surfaced for missing source data per
 * `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT. The
 * em-dash is the canonical "no data here" character; the renderer
 * matches on string-equality to render a skeleton or "—" verbatim.
 */
export const INFO_PANEL_PLACEHOLDER = '—'; // U+2014 EM DASH

/** A field that may be a runtime value (string/number) or the placeholder. */
type InfoPanelField<T> = T | typeof INFO_PANEL_PLACEHOLDER;

/** The plain-data descriptor a future renderer consumer hands to its component tree. */
export interface InfoPanelDescriptor {
  /** Whether the panel is open (default true per ledger §Behavior contract). */
  isOpen: boolean;
  /** Run id; placeholder when no run selected. */
  runId: InfoPanelField<string>;
  /** Agent label per F-002; placeholder when no run selected. */
  agentLabel: InfoPanelField<string>;
  /** Lifecycle state; placeholder when no run selected. */
  lifecycle: InfoPanelField<RunLifecycle>;
  /** Cycle counter; placeholder when no run selected. */
  cycleCount: InfoPanelField<number>;
  /** Cycle max; placeholder when no run selected. */
  cycleMax: InfoPanelField<number>;
  /** Audit-chain badge state per F-015; null when no run selected. */
  auditChainStatus: AuditChainStatus | null;
  /** Kill-switch state per F-020. */
  killSwitchActive: boolean;
  /**
   * Per-tool/model cost sub-totals per F-019. Empty when no run selected
   * OR when audit chain is 'red' (data-integrity warning) OR when
   * `costBreakdownAvailable === false`.
   */
  costBreakdown: ReadonlyArray<CostBreakdown>;
  /**
   * The placeholder string the renderer surfaces when costBreakdown is
   * empty due to missing source data (per ledger scenario 3 — NOT
   * silent zeros). null when costBreakdown is genuinely empty (no costs
   * yet) — the renderer can distinguish "no data" (placeholder) from
   * "zero costs" (no entries + no placeholder).
   */
  costBreakdownPlaceholder: string | null;
  /** Retro summary per F-014; null for active/halted runs. */
  retroSummary: string | null;
  /** Context Gap lines per `kit:rules/degradation-fallback-policy.md` Rule 3. */
  contextGaps: ReadonlyArray<string>;
}

/** Inputs accepted by `buildInfoPanel`. All fields optional. */
export interface InfoPanelOptions {
  /** Whether the panel should render open. Defaults to true. */
  isOpen?: boolean;
  /** Run id of the selected run. */
  runId?: string;
  /** Agent label per F-002. */
  agentLabel?: string;
  /** Lifecycle state. */
  lifecycle?: RunLifecycle;
  /** Cycle counter. */
  cycleCount?: number;
  /** Cycle max. */
  cycleMax?: number;
  /** Audit-chain status per F-015. */
  auditChainStatus?: AuditChainStatus;
  /** Kill-switch state per F-020. */
  killSwitchActive?: boolean;
  /** Per-tool/model cost sub-totals per F-019. */
  costBreakdown?: ReadonlyArray<CostBreakdown>;
  /**
   * Whether the cost-ledger file is available on disk. Pass `false`
   * when the F-008 read returned null (missing cost-ledger.json) so
   * the descriptor surfaces a placeholder + Context Gap rather than
   * silently zeroing the totals (per ledger scenario 3).
   */
  costBreakdownAvailable?: boolean;
  /**
   * Retro summary per F-014; only surfaced for closed runs (active
   * runs silently drop this — caller's bug, not the descriptor's).
   */
  retroSummary?: string;
}

/** Canonical default for fresh installs (no run selected). */
export const DEFAULT_INFO_PANEL: InfoPanelDescriptor = {
  isOpen: true,
  runId: INFO_PANEL_PLACEHOLDER,
  agentLabel: INFO_PANEL_PLACEHOLDER,
  lifecycle: INFO_PANEL_PLACEHOLDER,
  cycleCount: INFO_PANEL_PLACEHOLDER,
  cycleMax: INFO_PANEL_PLACEHOLDER,
  auditChainStatus: null,
  killSwitchActive: false,
  costBreakdown: [],
  costBreakdownPlaceholder: null,
  retroSummary: null,
  contextGaps: [],
};

/**
 * Hydrate a single field value into a renderable shape: `null`,
 * `undefined`, or empty-string `''` produce {@link INFO_PANEL_PLACEHOLDER};
 * numbers (including `0`) and non-empty strings round-trip unchanged.
 *
 * Per `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT —
 * surfacing a placeholder is honest about missing data; surfacing zero
 * pretends the data was actually zero. The renderer matches on
 * string-equality against the placeholder constant to decide between
 * skeleton / "—" / actual-value rendering.
 */
export function resolveInfoPanelField<T extends string | number>(
  value: T | null | undefined,
): T | typeof INFO_PANEL_PLACEHOLDER {
  if (value === null || value === undefined) return INFO_PANEL_PLACEHOLDER;
  if (typeof value === 'string' && value.length === 0) return INFO_PANEL_PLACEHOLDER;
  return value;
}

/**
 * Build the canonical descriptor for the desktop shell's right-side
 * info panel. The descriptor is read-only; consumers cannot mutate.
 *
 * Behavior:
 *   - No `runId` supplied → DEFAULT_INFO_PANEL placeholder shape.
 *   - `auditChainStatus === 'red'` → costBreakdown masked + Context Gap.
 *   - `costBreakdownAvailable === false` → costBreakdown empty +
 *     placeholder + Context Gap.
 *   - `lifecycle !== 'closed'` → retroSummary forced null (retro is
 *     emitted on close per F-014).
 *
 * @param opts - optional inputs. Defaults are appropriate for "no run selected".
 * @returns plain-object descriptor; JSON-cloneable; safe to persist.
 */
export function buildInfoPanel(opts: InfoPanelOptions = {}): InfoPanelDescriptor {
  // Default-state shortcut: no runId means no run selected → canonical default
  if (opts.runId === undefined) {
    // Honor explicit isOpen override but otherwise return canonical default
    if (opts.isOpen !== undefined) {
      return { ...DEFAULT_INFO_PANEL, isOpen: opts.isOpen };
    }
    return { ...DEFAULT_INFO_PANEL };
  }

  const contextGaps: string[] = [];
  const auditChainStatus = opts.auditChainStatus ?? null;
  const chainBroken = auditChainStatus === 'red';
  const costAvailable = opts.costBreakdownAvailable !== false; // default true unless explicitly false

  let costBreakdown: ReadonlyArray<CostBreakdown> = opts.costBreakdown ?? [];
  let costBreakdownPlaceholder: string | null = null;

  if (chainBroken) {
    // Mask costs per ledger scenario 2: "cost-ledger area masked with
    // 'data-integrity warning'"
    costBreakdown = [];
    costBreakdownPlaceholder = INFO_PANEL_PLACEHOLDER;
    contextGaps.push(
      'Audit chain verification failed (status: red); cost breakdown masked pending re-verify.',
    );
  } else if (!costAvailable) {
    // Missing cost-ledger file: explicit placeholder + Context Gap per
    // ledger scenario 3
    costBreakdown = [];
    costBreakdownPlaceholder = INFO_PANEL_PLACEHOLDER;
    contextGaps.push(
      'Cost ledger file not available; cost breakdown unknown for this run.',
    );
  }

  // Closed-only retroSummary enforcement
  const lifecycle = opts.lifecycle ?? 'closed';
  const retroSummary =
    lifecycle === 'closed' && opts.retroSummary !== undefined
      ? opts.retroSummary
      : null;

  return {
    isOpen: opts.isOpen ?? true,
    runId: opts.runId,
    agentLabel: resolveInfoPanelField(opts.agentLabel ?? null),
    lifecycle,
    cycleCount: resolveInfoPanelField(opts.cycleCount ?? null),
    cycleMax: resolveInfoPanelField(opts.cycleMax ?? null),
    auditChainStatus,
    killSwitchActive: opts.killSwitchActive ?? false,
    costBreakdown,
    costBreakdownPlaceholder,
    retroSummary,
    contextGaps,
  };
}
