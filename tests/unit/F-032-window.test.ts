import { describe, it, expect } from 'vitest';
import {
  createMainWindow,
  resolveWindowState,
  DEFAULT_WINDOW_STATE,
  type MainWindowOptions,
  type WindowState,
  type MainWindowDescriptor,
} from '@mad-council-claw/desktop-shell';

/**
 * F-032 window — RED → GREEN test.
 * Per docs/03-feature-catalog/M5-desktop-shell/F-032-window.md
 * acceptance scenarios.
 *
 * Authored wave-018 / lane-c per the wave-018 lane plan; this is the FIRST
 * M5 desktop-shell feature transition (M5 was 12R + 0G at wave-18 start).
 *
 * Behavior contract (from ledger §Behavior contract):
 *   The desktop shell is an Electron application that opens a primary
 *   BrowserWindow on launch. The window MUST: persist position + size across
 *   launches (`<state-dir>/desktop/window-state.json`); restore minimized/
 *   maximized state; block renderer-process Node integration (sandbox: true,
 *   contextIsolation: true, nodeIntegration: false); communicate with main
 *   exclusively through preload-script-mediated IPC (per F-007 contract
 *   scaffold). No window-flash on Windows: `windowsHide: true` for any spawn.
 *
 * Scope deviation from ledger §Acceptance scenarios (intentional, per
 * `no-silent-deferrals.md` + the wave-018 lane-c brief):
 *   The ledger's three scenarios bind to the integration suite — they
 *   require an actual Electron `BrowserWindow` to launch and create
 *   `window-state.json` on disk. The wave-018 / lane-c brief simplifies the
 *   v1 shape to a STRUCTURAL / INTERFACE-BASED test that asserts
 *   `createMainWindow(opts)` returns a canonical descriptor — i.e. the
 *   shape that downstream code (the eventual Electron BrowserWindow consumer
 *   in M5+ integration waves) will instantiate. The descriptor carries:
 *     - the canonical webPreferences (sandbox / contextIsolation /
 *       nodeIntegration) that Electron will read when the consumer wraps
 *       this descriptor in `new BrowserWindow(descriptor)`
 *     - the `windowsHide` flag honored by Electron's BrowserWindow
 *       constructor on Windows to prevent the spawn flash
 *     - the merged window state (position + size + maximized) that
 *       Electron's BrowserWindow constructor reads from `x`/`y`/`width`/
 *       `height` + the post-construct `maximize()` step
 *     - the IPC channel registration intent (which channels from the
 *       F-007 IpcInvokeMap this window will subscribe to via the preload
 *       bridge)
 *   The ledger's launch-an-actual-Electron-process scenarios are deferred
 *   to the M5 integration wave when an Electron + Playwright harness is
 *   wired (per F-004 vitest-playwright-config's "browser project runtime
 *   wiring deferred to first DOM-rendering spec consumer wave").
 *
 *   Substantive guarantees preserved by the structural test:
 *     - sandbox: true + contextIsolation: true + nodeIntegration: false
 *       (the security tripod that ledger scenario 3 exercises)
 *     - windowsHide: true (the Windows-no-flash discipline)
 *     - default-state when no `windowState` is supplied (ledger scenario 1)
 *     - last-state restoration when `windowState` IS supplied (scenario 2)
 *     - IPC channel registration shape (the F-007 contract is the contract;
 *       this descriptor declares which channels the renderer will invoke)
 *
 *   Deferred to M5 integration wave per `no-silent-deferrals.md`:
 *     - Actual Electron BrowserWindow instantiation
 *     - On-disk `window-state.json` round-trip with the F-008 storage layout
 *     - Renderer-process require('fs') runtime block (only the static
 *       webPreferences guarantee, not the runtime check)
 *     - Multi-window orchestration (F-043's scope)
 */
describe('F-032 window', () => {
  it('scenario 1: createMainWindow with no opts returns descriptor with default state + canonical security webPreferences', () => {
    const descriptor = createMainWindow();

    // Default-state contract (ledger scenario 1: fresh install, no state file)
    expect(descriptor.x).toBe(DEFAULT_WINDOW_STATE.x);
    expect(descriptor.y).toBe(DEFAULT_WINDOW_STATE.y);
    expect(descriptor.width).toBe(DEFAULT_WINDOW_STATE.width);
    expect(descriptor.height).toBe(DEFAULT_WINDOW_STATE.height);
    expect(descriptor.maximized).toBe(false);

    // Security tripod (ledger scenario 3 — renderer cannot require Node modules)
    expect(descriptor.webPreferences.sandbox).toBe(true);
    expect(descriptor.webPreferences.contextIsolation).toBe(true);
    expect(descriptor.webPreferences.nodeIntegration).toBe(false);

    // Windows-no-flash discipline (per F-032 §Behavior contract, second-to-last sentence)
    expect(descriptor.windowsHide).toBe(true);

    // The preload entry point is required (it's what surfaces the F-007 IPC bridge to renderer)
    expect(typeof descriptor.webPreferences.preload).toBe('string');
    expect(descriptor.webPreferences.preload.length).toBeGreaterThan(0);
  });

  it('scenario 2: createMainWindow with windowState restores last position + maximized state (ledger scenario 2)', () => {
    const restored: WindowState = {
      x: 1200,
      y: 800,
      width: 1400,
      height: 900,
      maximized: true,
    };
    const descriptor = createMainWindow({ windowState: restored });

    expect(descriptor.x).toBe(1200);
    expect(descriptor.y).toBe(800);
    expect(descriptor.width).toBe(1400);
    expect(descriptor.height).toBe(900);
    expect(descriptor.maximized).toBe(true);

    // Security tripod still enforced regardless of restored state
    expect(descriptor.webPreferences.sandbox).toBe(true);
    expect(descriptor.webPreferences.contextIsolation).toBe(true);
    expect(descriptor.webPreferences.nodeIntegration).toBe(false);
    expect(descriptor.windowsHide).toBe(true);
  });

  it('scenario 3: createMainWindow with custom preload path uses caller-supplied preload (preload-mediated IPC per F-007)', () => {
    const customPreload = '/custom/preload-bundle.js';
    const descriptor = createMainWindow({ preloadPath: customPreload });

    expect(descriptor.webPreferences.preload).toBe(customPreload);
    // Other security defaults preserved
    expect(descriptor.webPreferences.sandbox).toBe(true);
    expect(descriptor.webPreferences.contextIsolation).toBe(true);
    expect(descriptor.webPreferences.nodeIntegration).toBe(false);
  });

  it('scenario 4: createMainWindow declares IPC channel registrations the window will subscribe to via the F-007 bridge', () => {
    // The descriptor declares which IPC channels the renderer invokes through
    // the preload-mediated bridge (per F-032 §Behavior contract, last sentence).
    // F-007's IpcInvokeMap is empty in the scaffold (per common/ipc-contract.ts);
    // therefore the window's default subscription set is empty. Future M5
    // features (F-033 history rail, F-034 info panel, etc.) extend this set
    // by passing `ipcChannels` and adding their own entries to IpcInvokeMap.
    const descriptor = createMainWindow();
    expect(Array.isArray(descriptor.ipcChannels)).toBe(true);
    expect(descriptor.ipcChannels).toEqual([]);

    // Caller-supplied channels are passed through verbatim. The TYPE-level
    // contract (subset of `keyof IpcInvokeMap`) is enforced by TypeScript at
    // the consumer call site; at runtime the descriptor stores whatever
    // strings were supplied so the eventual BrowserWindow consumer can
    // register the matching `ipcRenderer.invoke` handlers.
    const withChannels = createMainWindow({
      ipcChannels: ['chat.send', 'settings.read'],
    });
    expect(withChannels.ipcChannels).toEqual(['chat.send', 'settings.read']);
  });

  it('scenario 5: resolveWindowState merges restored state with defaults (partial state hydration)', () => {
    // The window-state.json file may carry a partial shape (e.g. only x/y
    // were restored at a prior shutdown; width/height/maximized never
    // changed from defaults). resolveWindowState fills in defaults for any
    // missing field, never throws on null/undefined input.
    expect(resolveWindowState(null)).toEqual(DEFAULT_WINDOW_STATE);
    expect(resolveWindowState(undefined)).toEqual(DEFAULT_WINDOW_STATE);
    expect(resolveWindowState({})).toEqual(DEFAULT_WINDOW_STATE);

    const partial = { x: 50, y: 75 };
    expect(resolveWindowState(partial)).toEqual({
      ...DEFAULT_WINDOW_STATE,
      x: 50,
      y: 75,
    });

    const full: WindowState = {
      x: 100,
      y: 200,
      width: 1024,
      height: 768,
      maximized: false,
    };
    expect(resolveWindowState(full)).toEqual(full);
  });

  it('scenario 6: descriptor is a plain object — type witness + structural cloneability', () => {
    // The descriptor is what Electron's BrowserWindow constructor consumes.
    // It must be JSON-serializable so the F-008 storage layout can persist
    // a snapshot if a future feature wants restart-on-crash. No functions,
    // no class instances, no Date objects in the descriptor itself.
    const descriptor = createMainWindow();
    expect(() => JSON.stringify(descriptor)).not.toThrow();
    const round = JSON.parse(JSON.stringify(descriptor)) as MainWindowDescriptor;
    expect(round).toEqual(descriptor);

    // MainWindowOptions is the inputs shape — ALL fields optional, callers
    // may pass `{}` and get the canonical defaults.
    const opts: MainWindowOptions = {};
    void opts;
  });
});
