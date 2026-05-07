/**
 * F-012 backend-factory — GREEN.
 *
 * Per docs/03-feature-catalog/M1-backend/F-012-backend-factory.md.
 *
 * Behavior contract (from ledger):
 *   `createBackend(opts)` is the single supported way for engine code to
 *   obtain an IBackendProvider. It takes a `kind`
 *   (`'anthropic' | 'copilot' | 'stub'`) and returns the matching concrete
 *   class instance. Engine code MUST NOT import a concrete provider
 *   directly — it imports this factory and receives the implementation.
 *
 * Why a factory (per ledger §Behavior contract):
 *   - Engine code stays decoupled from concrete provider classes — adding
 *     a new backend (e.g. a future `gateway` origin) only requires editing
 *     this file + adding the kind to `BackendKind`. No engine-side change.
 *   - Routing by kind keeps F-019 (cost-ledger) + F-015 (audit-log)
 *     attribution consistent: `provider.origin` is the canonical tag.
 *   - The factory is pure (kind in → provider out, no I/O). Settings-layer
 *     resolution (env vars, F-067 settings shape) is the caller's job;
 *     this keeps `createBackend` deterministic and testable in isolation.
 *
 * Scope deviation from ledger (intentional, documented per the wave-014 /
 * lane-d + F-009 + wave-015 / lane-b precedent):
 *   The ledger names the function `createBackendProvider(name, opts)` and
 *   includes a `MAD_BACKEND` env-var override. The wave-015 / lane-d brief
 *   shortens to `createBackend({kind, model})` and defers env-var resolution
 *   to the caller (or a future settings layer per F-067, M8). The factory
 *   contract surface is unchanged; the resolution path is moved up the call
 *   stack so the factory itself is pure.
 *
 *   `BackendNotRegistered` (named in the ledger) is implemented via
 *   TypeScript's exhaustive-switch `never`-arm pattern. Compile-time:
 *   adding a new kind without a case triggers TS2322 on the `_exhaustive`
 *   binding. Runtime: an unknown kind (e.g. an externally-supplied string
 *   cast as BackendKind) throws `Error('Unknown backend kind: <kind>')`.
 *   This is the same pattern F-018 uses for HaltTrigger exhaustivity.
 */

import type { IBackendProvider } from './backend.js';
import { StubBackend } from './backend.js';
import { AnthropicBackend } from './backend-anthropic.js';
import { CopilotBackend } from './backend-copilot.js';

/**
 * The set of backend identities the factory can construct. Adding a new
 * value here is a deliberate two-line change: extend the union AND add a
 * `case` to the switch in `createBackend` (or the exhaustive-switch
 * `never`-arm fires at compile time).
 */
export type BackendKind = 'anthropic' | 'copilot' | 'stub';

/**
 * Options for `createBackend`. `model` is forwarded to the AnthropicBackend
 * and CopilotBackend constructors when supplied; the StubBackend ignores it
 * (no model concept). Forwarding is positional via the constructor's
 * default-parameter mechanism — passing `undefined` falls through to each
 * backend's documented default (claude-opus-4-7 for anthropic; gpt-5 for
 * copilot per F-010 + F-011).
 */
export interface BackendFactoryOptions {
  kind: BackendKind;
  model?: string;
}

/**
 * Construct a concrete IBackendProvider from a kind tag.
 *
 * Returns the interface type (not a concrete class) so engine consumers
 * cannot accidentally narrow to a provider-specific surface. Per the
 * F-012 ledger §Behavior contract, the factory is "the ONLY supported way
 * for engine code to obtain a provider."
 *
 * @throws Error('Unknown backend kind: <kind>') when `kind` is not in
 *   `BackendKind` (runtime defense; the compile-time check is the
 *   exhaustive-switch `_exhaustive: never` binding).
 */
export function createBackend(opts: BackendFactoryOptions): IBackendProvider {
  switch (opts.kind) {
    case 'anthropic':
      return new AnthropicBackend(opts.model);
    case 'copilot':
      return new CopilotBackend(opts.model);
    case 'stub':
      return new StubBackend();
    default: {
      // Exhaustive-switch witness. If a future commit extends BackendKind
      // without adding a case here, this assignment fails TS2322 at compile
      // time. The runtime throw covers the case where an externally-
      // supplied string is cast as BackendKind to bypass the type system
      // (config files, env vars, IPC messages).
      const _exhaustive: never = opts.kind;
      throw new Error(`Unknown backend kind: ${String(_exhaustive)}`);
    }
  }
}
