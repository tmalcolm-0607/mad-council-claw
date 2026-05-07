# Implementation TODO

F-NNN features waiting for implementation (RED state). Filled from `docs/03-feature-catalog/` once feature ledgers are authored (Wave 2+ is when the catalog drop happens).

## Schema

```
| F-NNN | Title | Milestone | Source citations | Confidence | Blocking decisions (D-N) | Status |
```

## Entries

| F-NNN | Title | Milestone | Source | Confidence | Blocking | Status |
|---|---|---|---|---|---|---|

_no entries yet — populated as feature ledgers are authored in Wave 2+_

## Pickup convention

Per the multi-instance pickup protocol in `docs/11-loop-state/README.md`: any instance can claim an F-NNN here by appending to the claim table in `current-wave.md`, then commit the implementation per micro-session discipline (≤1 feature per PR; behavior contract + acceptance scenarios + RED test before; GREEN after; status table evidence).
