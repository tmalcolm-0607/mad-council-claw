/**
 * @mad-council-claw/desktop-shell — barrel export.
 *
 * v1 ships the F-032 window descriptor + state resolution helpers, the
 * F-033 chat-history-pane descriptor, and the F-034 info-panel
 * descriptor. M5+ features extend this barrel as they land:
 *   - F-035 model-picker
 *   - F-036 personality-picker
 *   - F-037 system-message
 *   - F-038 primitives
 *   - F-039 theming
 *   - F-040 shortcuts
 *   - F-041 menu
 *   - F-042 notifications
 *   - F-043 multi-window
 *
 * Authoritative ownership (FETCH BEFORE CITE — verify file before edit):
 *   - window.ts — F-032 (window) — owns MainWindowDescriptor + WindowState +
 *     DEFAULT_WINDOW_STATE + createMainWindow + resolveWindowState
 *   - history-pane.ts — F-033 (chat-history-pane) — owns
 *     HistoryEntry + HistoryEntryLifecycle + HistoryPaneDescriptor +
 *     HistoryPaneVirtualization + HistoryPaneOptions + DEFAULT_HISTORY_PANE +
 *     HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD + buildHistoryPane +
 *     resolveHistoryEntry
 *   - info-panel.ts — F-034 (session-info-panel) — owns
 *     RunLifecycle + AuditChainStatus + CostBreakdown + InfoPanelDescriptor +
 *     InfoPanelOptions + DEFAULT_INFO_PANEL + INFO_PANEL_PLACEHOLDER +
 *     buildInfoPanel + resolveInfoPanelField
 */

export * from './window.js';
export * from './history-pane.js';
export * from './info-panel.js';
