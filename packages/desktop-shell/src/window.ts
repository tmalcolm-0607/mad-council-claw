/**
 * F-032 window — Electron BrowserWindow descriptor + state resolution.
 *
 * Per docs/03-feature-catalog/M5-desktop-shell/F-032-window.md.
 *
 * This module is the v1 STRUCTURAL surface for the desktop shell's primary
 * BrowserWindow. It does NOT instantiate Electron's `BrowserWindow` itself
 * — that's the job of the M5 integration consumer (a future feature wave
 * that wires `app.whenReady()` to a `new BrowserWindow(descriptor)` call
 * at the actual Electron entry point). Instead, this module produces the
 * DESCRIPTOR (a plain object Electron's BrowserWindow constructor accepts)
 * with the canonical security tripod, default state, and IPC channel
 * registration intent.
 *
 * The split is intentional per F-004's "browser project runtime wiring
 * deferred to first DOM-rendering spec consumer wave" — by keeping the
 * descriptor shape pure-data, F-032 can be unit-tested without bundling
 * Electron into the test runner. F-038..F-043 will compose against this
 * same descriptor without changing it.
 *
 * Authored wave-018 / lane-c (2026-05-07).
 *
 * Composition:
 *   - F-007 (ipc-contract-scaffold, LOCKED) — `ipcChannels` strings type
 *     against `keyof IpcInvokeMap` at the consumer call site (TS enforces
 *     subset-of-known-channels; runtime stores whatever was supplied).
 *   - F-008 (local-storage-layout, LOCKED) — caller resolves the
 *     `<state-dir>/desktop/window-state.json` path via `resolveDesktopDir`
 *     and passes the parsed value here as `windowState`.
 *   - F-001 (engine-bootstrap-loop, LOCKED) — the eventual Electron entry
 *     hosts the engine kernel in the main process; `createMainWindow` is
 *     called from that entry point.
 */

import type { IpcInvokeChannel } from '../../../common/ipc-contract.js';

/** Persisted window state — what gets read from `<state-dir>/desktop/window-state.json`. */
export interface WindowState {
  /** Top-left X coordinate in screen pixels. Negative = left of primary display. */
  x: number;
  /** Top-left Y coordinate in screen pixels. */
  y: number;
  /** Window width in screen pixels. */
  width: number;
  /** Window height in screen pixels. */
  height: number;
  /** Whether the window was maximized at last shutdown. */
  maximized: boolean;
}

/**
 * The canonical default state for a fresh install (no `window-state.json`
 * on disk). Position uses Electron's "centered on primary display" sentinel
 * (the eventual consumer reads x=0/y=0 + size, then calls `win.center()`
 * before showing — keeps the descriptor JSON-cloneable per F-032 scenario 6).
 */
export const DEFAULT_WINDOW_STATE: WindowState = {
  x: 0,
  y: 0,
  width: 1280,
  height: 800,
  maximized: false,
};

/** The default preload bundle path. Consumers override via `preloadPath`. */
const DEFAULT_PRELOAD_PATH = './preload.js';

/** Inputs accepted by `createMainWindow`. All fields optional. */
export interface MainWindowOptions {
  /** Restored state read from `window-state.json`, or null on fresh install. */
  windowState?: WindowState | null;
  /** Override the preload script path. Defaults to `./preload.js`. */
  preloadPath?: string;
  /**
   * IPC channels the renderer subscribes to via the preload bridge. Type-
   * checked against F-007's `IpcInvokeMap` at the consumer call site. The
   * scaffold's `IpcInvokeMap` is empty, so the default is `[]`; future M5
   * features extend `IpcInvokeMap` and pass channel names here.
   */
  ipcChannels?: ReadonlyArray<IpcInvokeChannel>;
}

/**
 * The descriptor Electron's `new BrowserWindow(descriptor)` consumes. Plain
 * data — no functions, no class instances, no Date objects. JSON-cloneable
 * per F-032 scenario 6 so a future feature can persist a snapshot for
 * restart-on-crash.
 *
 * Field order mirrors Electron's `BrowserWindowConstructorOptions` for
 * easy diffing during code review.
 */
export interface MainWindowDescriptor {
  /** Top-left X. From restored state, or 0 from default. */
  x: number;
  /** Top-left Y. From restored state, or 0 from default. */
  y: number;
  /** Width. From restored state, or 1280 from default. */
  width: number;
  /** Height. From restored state, or 800 from default. */
  height: number;
  /**
   * Whether the consumer should call `win.maximize()` after creation. The
   * BrowserWindow constructor itself doesn't take a `maximized` flag —
   * Electron expects a post-construct `win.maximize()` call. The consumer
   * checks this field and dispatches accordingly.
   */
  maximized: boolean;
  /**
   * On Windows, prevent the spawn flash when the window is created hidden.
   * Maps to Electron's BrowserWindow `show: !windowsHide` + an explicit
   * `windowsHide: true` for child-process-style hidden launches.
   */
  windowsHide: boolean;
  /** Renderer security configuration. The security tripod lives here. */
  webPreferences: {
    /**
     * Process sandbox. MUST be `true` per F-032 §Behavior contract.
     * Disables Node integration, restricts FS + child_process + native
     * modules. The renderer cannot break out without a Chromium 0-day.
     */
    sandbox: boolean;
    /**
     * Context isolation. MUST be `true`. Renderer-process world is
     * isolated from preload-script world; preload exposes the IPC bridge
     * via `contextBridge.exposeInMainWorld` per F-007 contract.
     */
    contextIsolation: boolean;
    /**
     * Node integration in renderer. MUST be `false`. With this off + the
     * sandbox + contextIsolation, the renderer cannot `require('fs')` or
     * any other Node module — F-032 scenario 3's security guarantee.
     */
    nodeIntegration: boolean;
    /**
     * Preload script path. The bridge between main and renderer; declares
     * the `contextBridge.exposeInMainWorld` API surface that the renderer
     * accesses. Per F-007's IPC contract scaffold, the preload bundle
     * imports `IpcInvokeMap` and exposes typed `invoke<C>(channel, req)`
     * helpers.
     */
    preload: string;
  };
  /**
   * IPC channels this window subscribes to via the preload bridge. The
   * eventual BrowserWindow consumer iterates this list and calls
   * `ipcMain.handle(channel, handler)` for each. Empty by default
   * (F-007's IpcInvokeMap is empty in the scaffold).
   */
  ipcChannels: ReadonlyArray<IpcInvokeChannel>;
}

/**
 * Hydrate a partial / null / undefined state object into a complete
 * {@link WindowState}. Caller-supplied fields win; missing fields fall back
 * to {@link DEFAULT_WINDOW_STATE}.
 *
 * Never throws — a corrupt or partial `window-state.json` parse always
 * yields a usable state. F-008's atomic-write discipline prevents
 * half-written files, so a parse failure at the caller's read site
 * (returning `null`) flows cleanly through here.
 */
export function resolveWindowState(
  state: WindowState | Partial<WindowState> | null | undefined,
): WindowState {
  if (state === null || state === undefined) {
    return { ...DEFAULT_WINDOW_STATE };
  }
  return {
    x: state.x ?? DEFAULT_WINDOW_STATE.x,
    y: state.y ?? DEFAULT_WINDOW_STATE.y,
    width: state.width ?? DEFAULT_WINDOW_STATE.width,
    height: state.height ?? DEFAULT_WINDOW_STATE.height,
    maximized: state.maximized ?? DEFAULT_WINDOW_STATE.maximized,
  };
}

/**
 * Build the canonical descriptor for the desktop shell's primary
 * BrowserWindow. The descriptor is what Electron's
 * `new BrowserWindow(descriptor)` consumes; the security tripod is
 * non-overridable (sandbox / contextIsolation / nodeIntegration are
 * compile-time constants from this function's body).
 *
 * @param opts - optional inputs (restored state, preload override, IPC
 *   channel subscription set). Defaults are appropriate for a fresh
 *   install.
 * @returns a plain-object descriptor; JSON-cloneable; safe to persist.
 */
export function createMainWindow(opts: MainWindowOptions = {}): MainWindowDescriptor {
  const state = resolveWindowState(opts.windowState ?? null);
  return {
    x: state.x,
    y: state.y,
    width: state.width,
    height: state.height,
    maximized: state.maximized,
    windowsHide: true,
    webPreferences: {
      sandbox: true,
      contextIsolation: true,
      nodeIntegration: false,
      preload: opts.preloadPath ?? DEFAULT_PRELOAD_PATH,
    },
    ipcChannels: opts.ipcChannels ?? [],
  };
}
