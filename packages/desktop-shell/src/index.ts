/**
 * @mad-council-claw/desktop-shell — barrel export.
 *
 * v1 ships the F-032 window descriptor + state resolution helpers. M5+
 * features extend this barrel as they land:
 *   - F-033 history-rail
 *   - F-034 info-panel
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
 */

export * from './window.js';
