import { describe, it, expect } from 'vitest';
import {
  buildInfoPanel,
  resolveInfoPanelField,
  DEFAULT_INFO_PANEL,
  INFO_PANEL_PLACEHOLDER,
  type InfoPanelOptions,
  type InfoPanelDescriptor,
  type AuditChainStatus,
  type CostBreakdown,
} from '@mad-council-claw/desktop-shell';

/**
 * F-034 session-info-panel — RED → GREEN test.
 * Per docs/03-feature-catalog/M5-desktop-shell/F-034-info-panel.md
 * acceptance scenarios.
 *
 * Authored wave-019 / lane-a (paired with F-033 history-pane); third M5
 * desktop-shell feature transition.
 *
 * Inherits the F-032-registered "descriptor-as-data, instantiation-deferred"
 * idiom: the test asserts the SHAPE that `buildInfoPanel(opts)` returns,
 * not actual DOM rendering. The descriptor is plain data the eventual
 * renderer-process consumer will hand to its component tree.
 *
 * Behavior contract (from ledger §Behavior contract):
 *   The right-side info panel (toggleable; default open) displays the
 *   selected run's metadata: agent identity (per F-002), lifecycle state,
 *   cycle count + max, audit-chain verification status (per F-015 —
 *   green/yellow/red badge), cost-ledger sub-totals broken down by
 *   tool/model (per F-019), kill-switch status (per F-020), retro
 *   summary (per F-014, only for closed runs). All fields are read-only,
 *   sourced via IPC from main process; no field is editable from the UI.
 *   Loading state is explicit: no field shown without source data;
 *   placeholders are explicit "—" or skeleton, NEVER silent zeros (per
 *   `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT).
 *
 * Scope deviation from ledger §Acceptance scenarios (intentional, per
 * `no-silent-deferrals.md` + the wave-019 / lane-a brief):
 *   The ledger's three scenarios bind to a browser-suite test that boots
 *   the desktop renderer in headless Chromium and asserts visual panel
 *   behavior + button interactions (re-verify chain on demand). The
 *   wave-019 / lane-a brief simplifies the v1 shape to a STRUCTURAL /
 *   INTERFACE-BASED unit test that asserts what `buildInfoPanel(opts)`
 *   returns. The browser-suite scenarios bind to the M5 integration wave.
 *
 *   Substantive guarantees preserved by the structural test:
 *     - Read-only field rendering (descriptor has no edit handlers)
 *     - Audit-chain badge type-safety ('green' | 'yellow' | 'red')
 *     - Explicit-placeholder discipline (per Rule 4 ACTUAL BEFORE PRESENT;
 *       missing fields surface INFO_PANEL_PLACEHOLDER, NOT zero or empty)
 *     - Kill-switch + cycle counts pass-through
 *     - Cost-breakdown structural preservation (sub-totals by tool/model)
 *     - Default `isOpen: true` (panel default-open per ledger §Behavior contract)
 *
 *   Deferred to M5 integration wave per `no-silent-deferrals.md`:
 *     - Actual DOM render of the panel
 *     - F-007 IPC subscription wiring for live updates per cycle
 *     - "Re-verify on button" runtime trigger (wires
 *       F-015 audit-chain re-verification via the F-007 IPC bridge)
 *     - Live trace timeline + step-by-step replay scrubber (M11 scope per
 *       ledger out-of-scope-notes — F-088..F-092)
 *     - Cross-run aggregate stats (v1.5 per ledger out-of-scope-notes)
 *     - Editable run metadata fields (out of scope per ledger
 *       out-of-scope-notes — info panel is read-only by design)
 */
describe('F-034 session-info-panel', () => {
  it('scenario 1: buildInfoPanel with no opts returns descriptor with default state (panel open; placeholder fields; chain status null)', () => {
    const descriptor = buildInfoPanel();

    // Default-state contract (no run selected → all source-dependent fields
    // surface explicit placeholders, NOT zero per Rule 4 ACTUAL BEFORE PRESENT)
    expect(descriptor.isOpen).toBe(true); // ledger §Behavior contract: default open
    expect(descriptor.runId).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.agentLabel).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.lifecycle).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.cycleCount).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.cycleMax).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.auditChainStatus).toBeNull();
    expect(descriptor.killSwitchActive).toBe(false);
    expect(descriptor.costBreakdown).toEqual([]);
    expect(descriptor.retroSummary).toBeNull();
    expect(descriptor.contextGaps).toEqual([]);

    // Whole descriptor MUST equal the canonical default
    expect(descriptor).toEqual(DEFAULT_INFO_PANEL);
  });

  it('scenario 2: active run with audit chain green + live cost breakdown (ledger scenario 1: all metadata fields present + live sub-totals)', () => {
    const cost: CostBreakdown[] = [
      { kind: 'model', label: 'claude-opus-4-7', usd: 1.25 },
      { kind: 'tool', label: 'web_search', usd: 0.05 },
    ];
    const descriptor = buildInfoPanel({
      runId: 'run-A',
      agentLabel: 'orchestrator',
      lifecycle: 'active',
      cycleCount: 7,
      cycleMax: 100,
      auditChainStatus: 'green',
      killSwitchActive: false,
      costBreakdown: cost,
    });

    expect(descriptor.runId).toBe('run-A');
    expect(descriptor.agentLabel).toBe('orchestrator');
    expect(descriptor.lifecycle).toBe('active');
    expect(descriptor.cycleCount).toBe(7);
    expect(descriptor.cycleMax).toBe(100);
    expect(descriptor.auditChainStatus).toBe('green');
    expect(descriptor.killSwitchActive).toBe(false);
    expect(descriptor.costBreakdown).toEqual(cost);
    expect(descriptor.isOpen).toBe(true);
  });

  it('scenario 3: tampered audit chain → status red + costBreakdown masked + contextGap line (ledger scenario 2: chain broken → red badge + integrity warning + cost masked)', () => {
    // When audit-chain status is 'red' (chain broken), the descriptor MUST
    // mask the cost breakdown (per ledger scenario 2 "cost-ledger area
    // masked with 'data-integrity warning'") and surface a Context Gap
    // line per `kit:rules/degradation-fallback-policy.md` Rule 3.
    const descriptor = buildInfoPanel({
      runId: 'run-tampered',
      agentLabel: 'orchestrator',
      lifecycle: 'closed',
      cycleCount: 12,
      cycleMax: 100,
      auditChainStatus: 'red',
      killSwitchActive: false,
      costBreakdown: [
        // Caller may have supplied a cost breakdown but the masked
        // discipline applies regardless
        { kind: 'model', label: 'claude-opus-4-7', usd: 5.0 },
      ],
    });

    expect(descriptor.auditChainStatus).toBe('red');
    // Cost breakdown MASKED — supplied breakdown not surfaced (data-integrity warning)
    expect(descriptor.costBreakdown).toEqual([]);
    // Context Gap line surfaced (degradation-fallback-policy.md Rule 3)
    expect(descriptor.contextGaps.length).toBeGreaterThan(0);
    expect(
      descriptor.contextGaps.some((line) =>
        line.toLowerCase().includes('audit chain'),
      ),
    ).toBe(true);
  });

  it('scenario 4: missing cost-ledger file → cost section shows placeholders + Context Gap line (ledger scenario 3: NOT silent zeros)', () => {
    // Per ledger §Behavior contract: "Loading state is explicit: no field
    // shown without source data; placeholders are explicit '—' or
    // skeleton, never silent zeros." The caller signals "cost ledger file
    // missing entirely" by passing `costBreakdownAvailable: false`. The
    // descriptor MUST emit:
    //   1. costBreakdown: [] (no fake-zero entries)
    //   2. costBreakdownPlaceholder: INFO_PANEL_PLACEHOLDER (the string the
    //      consumer renders in place of sub-totals)
    //   3. A Context Gap line documenting the absence
    const descriptor = buildInfoPanel({
      runId: 'run-no-cost',
      agentLabel: 'orchestrator',
      lifecycle: 'active',
      cycleCount: 3,
      cycleMax: 100,
      auditChainStatus: 'green',
      killSwitchActive: false,
      costBreakdownAvailable: false,
    });

    expect(descriptor.costBreakdown).toEqual([]);
    expect(descriptor.costBreakdownPlaceholder).toBe(INFO_PANEL_PLACEHOLDER);
    expect(descriptor.contextGaps.length).toBeGreaterThan(0);
    expect(
      descriptor.contextGaps.some((line) =>
        line.toLowerCase().includes('cost'),
      ),
    ).toBe(true);
  });

  it('scenario 5: closed run renders retroSummary; killSwitchActive surfaces verbatim', () => {
    const descriptor = buildInfoPanel({
      runId: 'run-retro',
      agentLabel: 'orchestrator',
      lifecycle: 'closed',
      cycleCount: 25,
      cycleMax: 100,
      auditChainStatus: 'green',
      killSwitchActive: true, // operator pulled kill-switch on this run
      retroSummary: 'Closed cleanly after 25 cycles; 2 minor warnings.',
    });

    expect(descriptor.retroSummary).toBe(
      'Closed cleanly after 25 cycles; 2 minor warnings.',
    );
    expect(descriptor.killSwitchActive).toBe(true);
    expect(descriptor.lifecycle).toBe('closed');

    // Active run should NOT carry retro (retro emitted on close per F-014).
    // The descriptor enforces this — supplying retroSummary on an active
    // run is silently dropped (caller's bug, not the descriptor's).
    const active = buildInfoPanel({
      runId: 'run-active',
      agentLabel: 'orchestrator',
      lifecycle: 'active',
      cycleCount: 5,
      cycleMax: 100,
      auditChainStatus: 'green',
      retroSummary: 'should be dropped — run is active',
    });
    expect(active.retroSummary).toBeNull();
  });

  it('scenario 6: descriptor is a plain object — JSON-cloneable + isOpen toggle + resolveInfoPanelField hydrator', () => {
    // Inherits F-032's "descriptor-as-data, instantiation-deferred" idiom.
    // The descriptor is what the eventual renderer consumer hands to its
    // component tree; it MUST be JSON-serializable so a future feature
    // could persist a snapshot. No functions, no class instances.
    const descriptor = buildInfoPanel({
      runId: 'run-A',
      agentLabel: 'orchestrator',
      lifecycle: 'active',
      cycleCount: 3,
      cycleMax: 100,
      auditChainStatus: 'yellow',
      isOpen: false, // panel collapsed; descriptor honors the setting
      costBreakdown: [{ kind: 'model', label: 'm', usd: 0.1 }],
    });

    expect(descriptor.isOpen).toBe(false);

    expect(() => JSON.stringify(descriptor)).not.toThrow();
    const round = JSON.parse(JSON.stringify(descriptor)) as InfoPanelDescriptor;
    expect(round).toEqual(descriptor);

    // resolveInfoPanelField — explicit placeholder for null/undefined/''
    // (per Rule 4 ACTUAL BEFORE PRESENT). Numbers pass through unchanged
    // (zero IS valid for a count, but caller decides whether to pass it).
    expect(resolveInfoPanelField(null)).toBe(INFO_PANEL_PLACEHOLDER);
    expect(resolveInfoPanelField(undefined)).toBe(INFO_PANEL_PLACEHOLDER);
    expect(resolveInfoPanelField('')).toBe(INFO_PANEL_PLACEHOLDER);
    expect(resolveInfoPanelField('value')).toBe('value');
    expect(resolveInfoPanelField(0)).toBe(0);
    expect(resolveInfoPanelField(42)).toBe(42);

    // Type witnesses
    const _opts: InfoPanelOptions = {};
    const _status: AuditChainStatus = 'green';
    void _opts;
    void _status;
  });
});
