# Open questions

Append-only. Items surfaced by waves accumulate here until the next periodic interview gate (L3). Per `no-silent-deferrals.md`: removing requires user acknowledgement.

## Schema

```
| ID | Question | Source (wave/lane) | Date | Confidence | Unblock condition |
```

## Entries

| ID | Question | Source | Date | Confidence | Unblock condition |
|---|---|---|---|---|---|
| Q-1 | gh auth identity is `tonym_microsoft` (EMU); remote push to `tmalcolm/mad-council-claw` blocked. User must run `gh auth switch -u tmalcolm` (if `tmalcolm` already in keyring) OR `gh auth login --hostname github.com --git-protocol https --web` then select `tmalcolm`. After switch, orchestrator runs `gh repo create tmalcolm/mad-council-claw --private --source=. --remote=origin && git push -u origin main`. | wave-001 / lane-zero | 2026-05-06 | HIGH | User runs the gh switch command in their terminal |
