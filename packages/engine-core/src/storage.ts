/**
 * F-008 Local storage layout — GREEN.
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md.
 * Behavior contract: the engine writes all persistent state under a single
 * `~/.mad-council-claw/` root. Subdirectories: sessions/, skills/,
 * automations/, audit/. The settings.json file lives at the root. Every
 * mutable JSON file is written atomically via the write-temp-then-rename
 * pattern from `concurrency-safety.md` §2; readers never observe a
 * half-written file.
 *
 * Surface:
 *   - StorageLayout: the 5-path + settingsFile struct.
 *   - getStorageLayout(rootOverride?): pure path computation.
 *   - ensureStorageLayout(layout): idempotent dir creation (mkdir recursive).
 *   - atomicWriteJson(path, content): write-temp + rename.
 *   - readJson<T>(path): JSON parse helper, typed.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

import {
  existsSync as _existsSync,
  mkdirSync as _mkdirSync,
  readFileSync as _readFileSync,
  renameSync as _renameSync,
  writeFileSync as _writeFileSync,
} from 'node:fs';
import { join as _join } from 'node:path';
import { homedir as _homedir } from 'node:os';

/**
 * Snapshot of the on-disk layout. `root` anchors the tree; the four
 * subdirectory paths are deterministic joins (`<root>/sessions`,
 * `<root>/skills`, `<root>/automations`, `<root>/audit`); `settingsFile`
 * is the canonical settings.json at the root.
 *
 * StorageLayout is a pure value — no filesystem side-effects. Pair with
 * {@link ensureStorageLayout} to materialize the dirs and
 * {@link atomicWriteJson} to write content.
 */
export interface StorageLayout {
  root: string;
  sessions: string;
  skills: string;
  automations: string;
  audit: string;
  settingsFile: string;
}

/**
 * Compute the on-disk layout. With no argument, anchors to
 * `~/.mad-council-claw/` under the operator's home directory; with
 * `rootOverride`, anchors to the supplied path (used by tests + by
 * non-default install scenarios).
 *
 * Pure function — does NOT touch the filesystem. Callers must invoke
 * {@link ensureStorageLayout} to materialize the directory tree.
 */
export function getStorageLayout(rootOverride?: string): StorageLayout {
  const root = rootOverride ?? _join(_homedir(), '.mad-council-claw');
  return {
    root,
    sessions: _join(root, 'sessions'),
    skills: _join(root, 'skills'),
    automations: _join(root, 'automations'),
    audit: _join(root, 'audit'),
    settingsFile: _join(root, 'settings.json'),
  };
}

/**
 * Materialize the layout's directory tree. Idempotent: re-runs do not
 * throw on existing dirs (mkdir uses `recursive: true`). Does NOT create
 * `settingsFile` — that's a JSON file whose lifecycle is owned by
 * {@link atomicWriteJson}.
 */
export function ensureStorageLayout(layout: StorageLayout): void {
  for (const dir of [
    layout.root,
    layout.sessions,
    layout.skills,
    layout.automations,
    layout.audit,
  ]) {
    if (!_existsSync(dir)) {
      _mkdirSync(dir, { recursive: true });
    }
  }
}

/**
 * Atomic JSON write per kit's `concurrency-safety.md` §2.
 *
 * Steps:
 *   1. Serialize content as pretty-printed JSON (2-space indent).
 *   2. Write to `<path>.tmp` via writeFileSync.
 *   3. Rename `<path>.tmp` → `<path>` — atomic on POSIX + Windows NTFS.
 *
 * A reader that opens `<path>` either sees the pre-update file or the
 * post-update file — never a half-written one. The `.tmp` orphan is
 * consumed by the rename; on a successful return, no `.tmp` file remains.
 *
 * On a writer crash between step 2 and step 3, the `.tmp` orphans;
 * the startup sweep (non-scope here; see ledger §Edge cases) reclaims it.
 */
export function atomicWriteJson(path: string, content: unknown): void {
  const tmp = `${path}.tmp`;
  _writeFileSync(tmp, JSON.stringify(content, null, 2), 'utf8');
  _renameSync(tmp, path);
}

/**
 * Read + JSON-parse a file. Typed for caller convenience; on parse error
 * the underlying SyntaxError propagates (callers handle).
 */
export function readJson<T = unknown>(path: string): T {
  return JSON.parse(_readFileSync(path, 'utf8')) as T;
}
