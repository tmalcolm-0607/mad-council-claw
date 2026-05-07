# 11 — Loop state

Where the loop lives. Any fresh Claude Code session, Copilot CLI invocation, or subagent picks up here per the multi-instance pickup protocol.

## Files

- `current-wave.md` — what wave is running NOW; pickup point for new instances; multi-instance claim table
- `recent-improvements.md` — methodology improvements per wave (per quality gate QG5)
- `confidence-ledger.md` — every finding's confidence over time; HIGH ↔ MEDIUM transitions captured
- `wave-history/` — one file per wave with full lane-by-lane reasoning + commit list + loop-improvement proposal

## Multi-instance pickup protocol (per Goal G18)

1. Read `current-wave.md` — tells you what wave is running and where the pickup points are
2. Read `docs/01-requirements/session-requests.md` + `goals.md` — foundational context
3. Read `docs/10-backlog/README.md` — pick an item from `research-gaps.md`, `implementation-todo.md`, or `design-decisions-pending.md`
4. Claim by appending a row to `current-wave.md`: instance type / claimed item / ETA
5. Execute per `docs/12-resource-roster/<your-instance-type>.md`
6. Output to `docs/06-agent-team-outputs/wave-NNN/lane-<your-handle>-<topic>.md`
7. Commit + PR per micro-session discipline (one feature/topic per PR)
8. Mark claimed backlog item resolved (or partial; back to backlog with progress note)

File-based claims are atomic per kit's `concurrency-safety.md` write-temp-rename pattern — no central locking needed.
