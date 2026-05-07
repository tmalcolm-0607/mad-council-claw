/**
 * F-007 IPC contract scaffold — single source of truth for all RPC types
 * between Electron main and renderer processes (when M5 desktop shell lands).
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md.
 *
 * Behavior contract: every IPC channel between Electron main and renderer is
 * declared in this single TypeScript module. Each channel has a typed request
 * shape, a typed response shape, and a unique string name. Renderer accesses
 * IPC ONLY through the `contextBridge`-exposed API; `nodeIntegration` stays
 * disabled and `contextIsolation` enabled. Adding a channel without updating
 * this contract module fails type-check at the consumer call site. Both main
 * and renderer import the same types from here.
 *
 * Currently empty scaffold; channel entries are added by M5+ features as
 * they need IPC routes (F-032..F-043 desktop chat shell, then later
 * milestones). The scaffold is the contract; future features extend
 * `IpcInvokeMap` with new entries — they MUST NOT bypass this module.
 *
 * TODO (refresh after PR merge): once M5 features land their first channels,
 * verify the inheritance pattern (declaration merging via `interface
 * IpcInvokeMap` vs type extension) matches what clawpilot's `cp:src/main/ipc`
 * surface uses. Source surfaces named in the F-007 ledger:
 *   - cp:src/main/ipc           (clawpilot main-process IPC handler pattern)
 *   - cp:src/preload            (clawpilot contextBridge API surface)
 *   - kit:rules/orchestrator-identity.md (renderer is orchestrator-shape)
 *
 * Created: wave-011 / lane-a (2026-05-07).
 * Vendored from: brief-only (no external scaffold to copy verbatim).
 */

/**
 * The IPC contract — every Electron `ipcMain.handle` <-> `ipcRenderer.invoke`
 * channel name maps to its `{request, response}` typed shapes.
 *
 * Empty in the scaffold; populated as M5+ desktop-shell features land their
 * channels. Pattern for adding a channel:
 *
 * ```ts
 * export type IpcInvokeMap = {
 *   'chat.send': { request: { message: string }; response: { reply: string } };
 *   'settings.read': { request: void; response: { theme: 'light' | 'dark' } };
 * };
 * ```
 *
 * The scaffold uses an empty object type (the `Record<string, never>`-ish
 * shape) so `keyof IpcInvokeMap = never` until channels are added. This is
 * intentional: any consumer that tries to invoke a channel before one is
 * declared gets a clear "Argument of type 'X' is not assignable to parameter
 * of type 'never'" type error pointing to the missing contract entry.
 */
export type IpcInvokeMap = {
  // Empty for now. Filled as M5+ features need IPC routes.
  // Pattern: 'route-name': { request: ReqType; response: ResType };
};

/** Union of all declared IPC channel names. `never` while the map is empty. */
export type IpcInvokeChannel = keyof IpcInvokeMap;

/**
 * Request shape for a given IPC channel `C`. Use at the call site:
 *
 * ```ts
 * function handle<C extends IpcInvokeChannel>(
 *   channel: C,
 *   payload: IpcInvokeRequest<C>,
 * ): Promise<IpcInvokeResponse<C>> { ... }
 * ```
 */
export type IpcInvokeRequest<C extends IpcInvokeChannel> = IpcInvokeMap[C] extends {
  request: infer R;
}
  ? R
  : never;

/** Response shape for a given IPC channel `C`. See {@link IpcInvokeRequest}. */
export type IpcInvokeResponse<C extends IpcInvokeChannel> = IpcInvokeMap[C] extends {
  response: infer R;
}
  ? R
  : never;
