# Pattern: State Files as Coordination Primitive

**Canonical name:** State Files. Variants: *shared state*, *file-based message passing*, *workspace coordination*, *artifact-driven workflow*.

**One-line definition:** Use plain files (JSON, YAML, Markdown) in a predictable directory layout as the shared state between agents and sessions. Reads are free, writes use atomic rename; the filesystem is the database.

## When to use

- Multi-agent / multi-session coordination on a single machine.
- You want state to be debugged with `cat` and `ls`, not through a query language.
- No budget for a database or message queue.
- Resumability matters — crash recovery is "just read the files again."
- Cross-toolchain interop where the lowest common denominator is the filesystem.

## When NOT to use

- Cross-machine coordination — filesystem semantics don't hold over NFS/SMB.
- High-frequency, low-latency updates (10K+ writes/sec). Filesystem can't keep up.
- Multi-writer at high concurrency — filesystem locking is awkward, race windows widen.
- When you need transactional multi-file atomicity (updating N files as one unit).

## Core mechanics

```
workspace/
  state.json              ← coordination state (small, read-often)
  messages/
    <seq>-<timestamp>.json ← append-only log (write-once, read-many)
  markers/<id>.json       ← per-agent cursors (read-write)
  archive/                ← resolved state, moved here intact
```

**Invariants:**

1. **Append-only logs are never rewritten.** New events are new files.
2. **Mutable files use atomic rename** (write `.tmp` → `rename`).
3. **One writer per file per instant** (or embrace last-write-wins with reducers).
4. **Readers tolerate eventually-consistent views** — a reader may see pre- or post-update, both valid.

## Common implementations

### Marketplace (MAD.Council itself)

Channel directory at `~/claude-data/channels/<name>/`:
- `channel.json` — mutable metadata.
- `seq.json` — atomic counter.
- `digest.json` — rolling summary (<2KB, cheap read).
- `threads/<id>/messages/*.json` — append-only.
- `read-markers/<alias>.json` — per-member cursors.
- `archive/` — terminal states.

**Pros of MAD's layout:** debuggable with standard tools; no process required between sessions; resumable.

### Marketplace: ai-native-team (`plan.md` pattern)

A single Markdown file tracks a plan:
- Checkboxes mark progress.
- Sections mark phases.
- Agents update the file in-place with atomic writes.

**Pros:** human-readable; portable; easy to diff across time.
**Cons:** Markdown is lossy for structured data; harder to query than JSON.

### Marketplace: a11y-remediation (`a11y-session.yaml`)

A YAML state file tracking a multi-phase accessibility session:
- Each phase has a `status` field.
- Agents update the YAML atomically between phases.

**Pros:** YAML handles nested structure better than Markdown.
**Cons:** YAML parsers vary in strictness; easy to emit slightly-wrong YAML.

### Git itself

`.git/` directory is the canonical state-files example. Ref files, packed objects, pack indexes — all filesystem primitives. Git invented many of the patterns (atomic ref updates via rename, write-once objects).

### SQLite (the adjacent contrast)

An on-disk database is the "file-based state + transactional atomicity" answer. LangGraph's SqliteSaver uses it. MAD.Council explicitly rejects it (§2 Non-Goals) — because the debugging advantage of plain files is core to the kit.

## Pros

- **Debuggable with standard tools.** `cat`, `ls`, `grep`, `diff`, version control.
- **No runtime dependencies.** No database server, no queue broker, no message bus.
- **Resumable by construction.** Crash → restart → read files → resume.
- **Cheap to back up.** `tar`, `rsync`, git.
- **Human-inspectable.** A support engineer can read state without special tools.
- **Portable.** A workspace moves between machines by copying the directory.
- **Version-controllable** (at least the human-readable files).

## Cons

- **No transactions across files.** Updating `channel.json` AND `thread.json` atomically requires careful ordering; a crash between them is possible.
- **Concurrency is manual.** You implement atomic rename + retry-on-collision yourself. Easy to get subtly wrong.
- **Scales poorly.** Filesystem syscalls aren't free; 10K writes/sec starts to hurt.
- **No queries.** `grep` is not SQL. Finding "all messages from alias X in the last hour" is a scan.
- **Schema evolution is painful.** Adding a field means every file may have different shapes; you need migration logic or tolerant parsers.
- **Filesystem semantics vary.** Windows NTFS vs POSIX vs network mounts have different guarantees. Corners bite.
- **Binary content is awkward.** State files should be text/JSON; attachments need separate handling.

## Do / Don't

**Do**:

- **Design the directory layout upfront** — document it in a README. Ad-hoc layouts become chaos.
- **Separate mutable and append-only files.** Mutable (`channel.json`) uses atomic write; append-only (`messages/`) uses unique filenames.
- **Use atomic rename for mutable writes.** `rename()` is atomic on POSIX and NTFS.
- **Name append-only files uniquely** (monotonic counter + timestamp + alias). Guarantees no collision.
- **Keep mutable files small.** `digest.json` is <2KB so every reader reads cheaply.
- **Version the schema.** `schema_version: N` field; tolerant parsers.
- **Document the invariants.** Append-only vs mutable vs derived. Reviewers need to know.
- **Archive whole subtrees.** `mv <thread-dir> archive/` preserves everything in one atomic op.
- **Use reducers for last-write-wins fields.** `message_count` in thread.json is recomputable; don't fight for correctness.

**Don't**:

- **Don't write mutable files non-atomically.** Readers see half-written state.
- **Don't edit append-only files after creation.** Corrections are new entries.
- **Don't rely on file timestamps for ordering.** Use an explicit sequence counter.
- **Don't assume `rename()` works across filesystems.** Same volume only.
- **Don't lock files.** Advisory locks are a different pattern; atomic rename is usually enough.
- **Don't put secrets in state files.** They're readable by anyone with filesystem access.
- **Don't ignore orphan .tmp files.** Add a startup-sweep to clean them up.

## Interaction with other patterns

- **+ `rules/concurrency-safety.md`** — this pattern is where concurrency discipline is enforced.
- **+ `wiki/patterns/run-id-correlation.md`** — run_id gives you cross-file query capability ("grep for GUID") on top of the file-based state.
- **+ `wiki/patterns/circuit-breakers.md`** — breakers write their trip state to a file; state survives session restart.
- **+ `wiki/patterns/completion-report-protocol.md`** — Completion Reports land as JSON in a predictable path.

## MAD.Council specifics

MAD.Council is a 100% file-based system (when A2A Layer is disabled). Directory:

```
~/claude-data/channels/<name>/
  channel.json
  seq.json
  digest.json
  spec.md        (if --mad)
  plan.md        (if --mad)
  tasks.md       (if --mad)
  threads/<id>/
    thread.json
    verdict.json  (if --council review ran)
    messages/<seq>-<ts>-<alias>.json
  read-markers/<alias>.json
  leave-reports/<alias>-<ts>.json
  archive/
  consent-log.jsonl
  degradation-log.jsonl
  breaker-log.jsonl
.sessions.json   (at ~/claude-data/channels/)
```

Every file classified per the invariants table:

| File | Class | Writer | Reader | Concurrency |
|---|---|---|---|---|
| `channel.json` | mutable | any member | all | atomic rename |
| `seq.json` | mutable | any poster | all | read-inc-write + retry |
| `digest.json` | mutable | poster (rebuilds on post) | all | atomic rename |
| `spec.md`, `plan.md`, `tasks.md` | mutable | MAD skills | all | atomic rename |
| `threads/<id>/thread.json` | mutable | poster (updates on post) | all | last-write-wins |
| `threads/<id>/verdict.json` | append (one-shot) | /council-review | all | exclusive-create |
| `threads/<id>/messages/*.json` | append-only | /council-post | all | unique filenames |
| `read-markers/<alias>.json` | mutable | owner only | self | atomic rename |
| `leave-reports/*.json` | append-only | /council-leave | audit | unique filenames |
| `*.jsonl` (logs) | append-only | various | audit | append syscall |
| `archive/*` | frozen | one-shot move | audit | atomic rename of dir |
| `.sessions.json` | mutable | session owner | self | atomic rename |

## References

- `rules/concurrency-safety.md` — the concurrency primitives.
- `mad.council.a2a.md` §7.1 — directory layout.
- Channels v1 §Concurrency & Write Safety — original design.
- Git internals (Pro Git book Ch. 10) — canonical state-file system.
- `wiki/implementations/langgraph.md` — contrast with SQLite-based state.
- CHECKLIST cross-cutting pattern #2 — "explicit state files as coordination primitive."
