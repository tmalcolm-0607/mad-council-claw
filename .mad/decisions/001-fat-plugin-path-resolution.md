# 1. Fat-plugin path resolution over thin-shim relative paths

Date: 2026-04-21
Status: Accepted

## Context

During Phase-1b packaging (iter 37–42) we had to decide how a consumer project references MAD kit assets once installed. Two options were on the table:

1. **Thin shim** — skills and hooks use relative paths (`../../../scripts/foo.ps1`) that resolve against whatever directory the skill happens to be loaded from.
2. **Fat plugin** — skills and hooks use `${CLAUDE_PLUGIN_ROOT}` (the Claude Code harness env var for the plugin's install root) so resolution is anchored, not traversal-based.

The relative-path thin shim looked simpler but broke in real installs the moment the consumer's directory layout didn't match the kit's source layout. The scope of "directory layout" also includes worktrees, submodules, symlinks, and kit-inside-consumer subfolders — all of which exist in practice.

## Decision

All skills, hooks, and scripts that need to resolve a kit-relative file MUST use `${CLAUDE_PLUGIN_ROOT}` (or the equivalent anchoring env the harness exposes). No relative-traversal paths.

The install layout itself is codified in `PORTED.md` (kit path → consumer path mapping). `${CLAUDE_PLUGIN_ROOT}` points at the root of that installed layout in the consumer.

## Consequences

**Easier**:
- Consumer repos can place the kit anywhere (`.claude/`, `.mad/`, a sibling repo, a symlinked worktree) and everything still resolves.
- Cross-plugin references are unambiguous.
- Authoring a new skill is simpler — you never think about "where am I being loaded from."

**Harder**:
- Tests have to set `${CLAUDE_PLUGIN_ROOT}` explicitly (not a real burden once noted).
- Can't drop a single skill file into a scratch folder and have it "just work" against a sibling scripts dir — you must set the env.

## References

- `plans/phase-1b-polish-package-dogfood.md:181-244` — authoritative fat-plugin discussion (CHK-065 iter-38 correction to the thin-façade plan)
- `scripts/ported/seed-self-hosting.ps1:75` — records CHK-065 as "canonical is CLAUDE_PLUGIN_ROOT, not thin facade"
- `wiki/implementations/anthropic-claude-code.md:61` — skill-path resolution via `CLAUDE_PLUGIN_ROOT`
- `PORTED.md` — install path mapping
