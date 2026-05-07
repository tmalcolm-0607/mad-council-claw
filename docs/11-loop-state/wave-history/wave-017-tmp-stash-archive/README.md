# Wave-17 .tmp-stash archive

**Date archived:** 2026-05-07 (wave 18 / lane D cleanup)
**Provenance:** salvaged from `.tmp-stash/` (untracked scratch dir from wave-17 cross-lane staging-race recovery)

These four files have residual audit value for the wave-17 multi-lane index.ts merge story; the rest of `.tmp-stash/` (empty `lane-b-*.patch` files plus `red/green-output-w17b*.txt` dumps) was deleted because the LOCKED feature test results are the canonical proof, not transient run dumps.

| File | Origin | Why preserved |
|---|---|---|
| `F-010-index-patch.diff` | wave-17 lane B | 807-byte diff fragment showing the F-010 anthropic-backend addition to `packages/engine-core/src/index.ts`. Useful for cross-referencing the staging-race recovery sequence. |
| `halt.ts.green` | wave-17 lane B | Snapshot of `packages/engine-core/src/halt.ts` at the GREEN moment of F-018 / F-020 / F-027 wiring. Preserved because the active file has since evolved; this captures the LOCKED-precursor shape. |
| `index.ts.full` | wave-17 lane B | Snapshot of `packages/engine-core/src/index.ts` showing the multi-lane barrel export shape after lane-A + lane-B + lane-C reconciliation. |
| `index.ts.multilane` | wave-17 lane B | Sibling of `index.ts.full` — labels the merge state for the cross-lane diff narrative. |

Everything in this archive is FROZEN historical state — do not edit. Refer to current `packages/engine-core/src/*.ts` for the live code.

`.tmp-stash/` itself is now in `.gitignore` (per wave-18 lane D), so future cross-lane recovery debris stays out of history.
