import { describe, it, expect, expectTypeOf } from 'vitest';
import * as IpcContract from '../../common/ipc-contract.js';
import type {
  IpcInvokeMap,
  IpcInvokeChannel,
  IpcInvokeRequest,
  IpcInvokeResponse,
} from '../../common/ipc-contract.js';

/**
 * F-007 RED → GREEN test — IPC contract scaffold.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md.
 * This test asserts the scaffold's shape contract: a single TypeScript
 * source-of-truth module at `common/ipc-contract.ts` exporting the
 * `IpcInvokeMap` type + the three derived helper types
 * (`IpcInvokeChannel`, `IpcInvokeRequest<C>`, `IpcInvokeResponse<C>`).
 *
 * Scope (wave-011 / lane-a brief):
 *   The scaffold STARTS empty. M5 desktop-shell features (F-032..F-043) and
 *   later milestones add channels by extending the `IpcInvokeMap` type.
 *   Adding a channel without updating the contract module fails the type
 *   check the consumer code performs — this test only asserts the SHAPE
 *   contract (the scaffold is exported and usable).
 *
 * Acceptance scenarios (from F-007 ledger §Acceptance scenarios, scoped to
 * the wave-011 scaffold flip; full scenarios — context-bridge runtime,
 * build-time type failure on missing handler — covered under M5
 * integration when an actual handler can be wired):
 *   1. `IpcInvokeMap` is exported as a TypeScript object type. (scaffold
 *      starts as `{}` — empty contract.)
 *   2. `IpcInvokeChannel = keyof IpcInvokeMap` — derives from the map so a
 *      future channel addition automatically updates the channel union.
 *   3. `IpcInvokeRequest<C>` / `IpcInvokeResponse<C>` accessors exist for
 *      pulling the request / response shape of a given channel.
 */
describe('F-007 ipc-contract-scaffold', () => {
  it('IpcInvokeMap is exported as an object type', () => {
    expectTypeOf<IpcInvokeMap>().toBeObject();
  });

  it('IpcInvokeChannel is the keyof IpcInvokeMap', () => {
    expectTypeOf<IpcInvokeChannel>().toEqualTypeOf<keyof IpcInvokeMap>();
  });

  it('module is importable at runtime (scaffold module exists)', () => {
    // RED → GREEN gate: the module must exist on disk for this import to
    // resolve. Type-only imports (line 1-7) get stripped by esbuild, so
    // an unused type import would silently pass even with no module.
    // The wildcard `import * as IpcContract` forces a runtime module
    // resolution: vitest fails-fast with `Cannot find module` when the
    // file doesn't exist. This is the runtime witness for the scaffold's
    // existence; the type-test assertions on lines 36-43 are the witness
    // for its SHAPE.
    expect(IpcContract).toBeDefined();
    expect(typeof IpcContract).toBe('object');

    // Compile-time witness: helper types must exist + be parameterizable.
    type _Witness1 = IpcInvokeRequest<never>;
    type _Witness2 = IpcInvokeResponse<never>;
    void undefined as unknown as _Witness1;
    void undefined as unknown as _Witness2;
  });
});
