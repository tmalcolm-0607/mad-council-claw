# Fixture: basic input for /mad-parallel (synthetic)

Synthetic input for the mad-parallel skill. The skill executes `[P]` (parallel-eligible) tasks from tasks.md as concurrent subagent dispatches.

## Synthetic input artifact

`tasks.md` excerpt:
- T1: implement entity X (no deps)
- T2 [P]: implement entity Y (no deps)
- T3 [P]: implement entity Z (no deps)
- T4: integration test (depends on T1, T2, T3)

Expected: T1 + T2 + T3 in one parallel wave, T4 sequentially after.

## Skill invocation

```
/mad-parallel
```

## Notes

This fixture exercises the smart-default flow (enumerate parallel groups → dispatch wave → join). For mode-specific fixtures (--max-concurrency <N>), add additional fixtures.
