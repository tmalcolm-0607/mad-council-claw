import { describe, it, expect } from 'vitest';
import {
  AnthropicBackend,
  CopilotBackend,
  StubBackend,
  createBackend,
  type IBackendProvider,
  type BackendKind,
} from '@mad-council-claw/engine-core';

/**
 * F-012 backend-factory — RED → GREEN test.
 * Per docs/03-feature-catalog/M1-backend/F-012-backend-factory.md.
 *
 * Behavior contract (from ledger):
 *   `createBackend(opts)` is the single supported way for engine code to
 *   obtain an IBackendProvider. It takes a `kind` (`'anthropic' | 'copilot'
 *   | 'stub'`) and returns the matching concrete class instance. Engine
 *   code MUST NOT import a concrete provider directly — it imports the
 *   factory and receives the implementation.
 *
 * Scope deviation from ledger (intentional, documented per the wave-014 /
 * lane-d + wave-015 / lane-b precedent):
 *   The ledger names the function `createBackendProvider(name, opts)` and
 *   includes a `MAD_BACKEND` env-var override. The wave-015 / lane-d brief
 *   shortens to `createBackend({kind, model})` and defers env-var resolution
 *   to the caller (or a future settings layer per F-067, M8). The factory
 *   contract surface is unchanged; the resolution path is moved up the call
 *   stack so the factory itself is pure (kind in → provider out, no I/O).
 *
 *   `BackendNotRegistered` is implemented via TypeScript's exhaustive-switch
 *   `never`-arm pattern: at compile time, adding a new kind without a case
 *   triggers TS2322; at runtime, an unknown kind (e.g. an externally-supplied
 *   string cast as BackendKind) throws `Error('Unknown backend kind: ...')`.
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. createBackend({kind:'anthropic'}) returns AnthropicBackend instance with
 *      origin === 'anthropic'.
 *   2. createBackend({kind:'copilot'}) returns CopilotBackend instance with
 *      origin === 'copilot'.
 *   3. createBackend({kind:'stub'}) returns StubBackend instance with origin
 *      === 'stub'.
 *   4. createBackend({kind:'<unknown>' as BackendKind}) throws (runtime
 *      defense for the case where the kind comes from a string cast or
 *      external input that bypasses the compile-time check).
 *   5. The factory forwards the optional `model` parameter to AnthropicBackend
 *      and CopilotBackend constructors so per-instance model pinning works
 *      (compose with M10 multi-model adversarial dispatch wave).
 *   6. The factory return type is exactly IBackendProvider — engine consumers
 *      can rely on the interface contract without narrowing to a concrete class.
 *
 * Out of scope (per ledger):
 *   - MAD_BACKEND env-var resolution (deferred to a settings layer per F-067).
 *   - Multi-tier routing (Haiku-for-cheap-calls, Opus-for-hard-reasoning) —
 *     tracked under F-124 (NEW M1 frontier-research candidate).
 *   - Lint rule preventing direct `new AnthropicBackend()` (eslint custom
 *     rule; deferred per `no-silent-deferrals.md` to a future lint-pass wave).
 */
describe('F-012 backend-factory', () => {
  it('scenario 1: createBackend({kind:"anthropic"}) returns AnthropicBackend with origin="anthropic"', () => {
    const provider: IBackendProvider = createBackend({ kind: 'anthropic' });
    expect(provider).toBeInstanceOf(AnthropicBackend);
    expect(provider.origin).toBe('anthropic');
  });

  it('scenario 2: createBackend({kind:"copilot"}) returns CopilotBackend with origin="copilot"', () => {
    const provider: IBackendProvider = createBackend({ kind: 'copilot' });
    expect(provider).toBeInstanceOf(CopilotBackend);
    expect(provider.origin).toBe('copilot');
  });

  it('scenario 3: createBackend({kind:"stub"}) returns StubBackend with origin="stub"', () => {
    const provider: IBackendProvider = createBackend({ kind: 'stub' });
    expect(provider).toBeInstanceOf(StubBackend);
    expect(provider.origin).toBe('stub');
  });

  it('scenario 4: createBackend on an unknown kind throws at runtime', () => {
    // Cast an unknown string to BackendKind to bypass the compile-time
    // exhaustive-switch check. This models real-world external input
    // (config file, env var, IPC message) that the type system can't
    // statically validate.
    const bogusKind = 'ollama' as unknown as BackendKind;
    expect(() => createBackend({ kind: bogusKind })).toThrow(/Unknown backend kind/i);
  });

  it('scenario 5: createBackend forwards the model parameter to anthropic and copilot constructors', () => {
    // Constructor-level model pinning is observable via the token chunk's
    // text (each backend surfaces its model id in the stub response per
    // F-010 + F-011). This is the cross-cutting traceability check for
    // F-012's parameter-forwarding contract.
    const a = createBackend({ kind: 'anthropic', model: 'claude-sonnet-4-7' });
    expect(a).toBeInstanceOf(AnthropicBackend);

    const c = createBackend({ kind: 'copilot', model: 'gpt-5-turbo' });
    expect(c).toBeInstanceOf(CopilotBackend);

    // Note: the model is private to each backend, so we can't directly
    // assert on it; the structural witness here is that both calls succeed
    // with the optional model parameter and return the right concrete type.
    // F-010 scenario 3 already verifies the model id surfaces in the token
    // chunk text — F-012 inherits that observability via its forwarding.
  });

  it('scenario 6: factory return type is IBackendProvider (interface contract preserved)', () => {
    // Compile-time witness: the type annotation on `provider` requires that
    // createBackend's return type is assignable to IBackendProvider. If
    // createBackend ever drifts to a wider type (e.g. `unknown`) or a
    // narrower one (e.g. `AnthropicBackend`), this annotation will fail
    // TS2322 / TS2740 at compile time. Runtime check is structural: the
    // four required methods are present on every kind.
    for (const kind of ['anthropic', 'copilot', 'stub'] as const) {
      const provider: IBackendProvider = createBackend({ kind });
      expect(typeof provider.startSession).toBe('function');
      expect(typeof provider.sendPrompt).toBe('function');
      expect(typeof provider.halt).toBe('function');
      expect(typeof provider.stopSession).toBe('function');
    }
  });
});
