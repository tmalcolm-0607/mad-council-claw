import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  getStorageLayout,
  ensureStorageLayout,
  atomicWriteJson,
  readJson,
  type StorageLayout,
} from '@mad-council-claw/engine-core';

/**
 * F-008 RED → GREEN test.
 * Per docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md
 * acceptance scenarios + wave-010 lane-d brief.
 *
 * Behavior contract: the engine writes all persistent state under a single
 * `~/.mad-council-claw/` root with subdirectories (sessions, skills,
 * automations, audit) and a settings.json file. Atomic write helpers per
 * `concurrency-safety.md` §2 ensure writers never produce a half-readable
 * file: writeFileSync to a `<path>.tmp`, then rename to the final path.
 *
 * Each test runs against an isolated temp dir under `os.tmpdir()` so
 * concurrent test runs and the operator's actual `~/.mad-council-claw/`
 * are not perturbed.
 *
 * Acceptance scenarios mirrored from the F-008 ledger + brief:
 *   1. (brief) `getStorageLayout(rootOverride)` returns 5 paths
 *      (root, sessions, skills, automations, audit, settingsFile) all
 *      anchored under rootOverride.
 *   2. (brief) `ensureStorageLayout(layout)` creates every directory
 *      under root; calling it twice is idempotent (no error on existing
 *      dirs).
 *   3. (brief) `atomicWriteJson(path, content)` writes valid JSON readable
 *      via `readJson(path)` round-trip (deeply-nested objects survive).
 *   4. (ledger §2) Atomic write does not leave a `.tmp` orphan after a
 *      successful write — the rename consumes the temp file.
 *   5. Atomic write does not corrupt a prior file when the new write
 *      succeeds — readers always observe a fully-formed JSON document.
 *   6. `getStorageLayout()` without override defaults to `~/.mad-council-claw`
 *      under the operator's home directory (path-shape check only — no
 *      directory creation in the operator's home during the unit run).
 *
 * Out of scope (per F-008 ledger §out-of-scope-notes + this brief):
 *   - Encrypted-at-rest storage of secrets/keys (M8 / F-070-F-071).
 *   - Sweep of orphaned `<path>.tmp` files on startup (ledger §Edge cases;
 *     follow-on flip will land it).
 *   - Concurrent writer race testing (last-write-wins is the
 *     concurrency-safety §2 guarantee for digest.json-class files; the
 *     atomic helper itself is the building block, not the race-test
 *     harness).
 */
describe('F-008 local-storage-layout', () => {
  let tempRoot: string;

  beforeEach(() => {
    // Each test gets its own isolated root under os.tmpdir(). Avoids
    // perturbing ~/.mad-council-claw and avoids cross-test state leaks.
    tempRoot = mkdtempSync(join(tmpdir(), 'mad-council-claw-f008-'));
  });

  afterEach(() => {
    if (existsSync(tempRoot)) {
      rmSync(tempRoot, { recursive: true, force: true });
    }
  });

  it('scenario 1: getStorageLayout returns 5 paths anchored under root', () => {
    const layout: StorageLayout = getStorageLayout(tempRoot);

    expect(layout.root).toBe(tempRoot);
    expect(layout.sessions).toBe(join(tempRoot, 'sessions'));
    expect(layout.skills).toBe(join(tempRoot, 'skills'));
    expect(layout.automations).toBe(join(tempRoot, 'automations'));
    expect(layout.audit).toBe(join(tempRoot, 'audit'));
    expect(layout.settingsFile).toBe(join(tempRoot, 'settings.json'));
  });

  it('scenario 2: ensureStorageLayout creates all dirs, idempotent on rerun', () => {
    const layout = getStorageLayout(tempRoot);

    // First call — root is fresh; subdirs do not yet exist.
    ensureStorageLayout(layout);
    expect(existsSync(layout.root)).toBe(true);
    expect(existsSync(layout.sessions)).toBe(true);
    expect(existsSync(layout.skills)).toBe(true);
    expect(existsSync(layout.automations)).toBe(true);
    expect(existsSync(layout.audit)).toBe(true);

    // Second call — must not throw on existing dirs (idempotent).
    expect(() => ensureStorageLayout(layout)).not.toThrow();

    // settingsFile is NOT created by ensureStorageLayout — it is a file,
    // and atomic-write owns its lifecycle.
    expect(existsSync(layout.settingsFile)).toBe(false);
  });

  it('scenario 3: atomicWriteJson + readJson round-trip with deeply-nested content', () => {
    const layout = getStorageLayout(tempRoot);
    ensureStorageLayout(layout);

    const settings = {
      version: '0.0.1',
      flags: { telemetry: true, autoUpdate: false },
      providers: [
        { name: 'anthropic', model: 'claude-opus-4-7', priority: 1 },
        { name: 'copilot', model: 'gpt-5', priority: 2 },
      ],
      nested: { deeply: { very: { much: { yes: 'leaf' } } } },
    };

    atomicWriteJson(layout.settingsFile, settings);

    expect(existsSync(layout.settingsFile)).toBe(true);
    const roundTrip = readJson<typeof settings>(layout.settingsFile);
    expect(roundTrip).toEqual(settings);
    expect(roundTrip.nested.deeply.very.much.yes).toBe('leaf');
    expect(roundTrip.providers).toHaveLength(2);
  });

  it('scenario 4: atomicWriteJson does not leave a .tmp orphan after successful write', () => {
    const layout = getStorageLayout(tempRoot);
    ensureStorageLayout(layout);

    atomicWriteJson(layout.settingsFile, { ok: true });

    expect(existsSync(layout.settingsFile)).toBe(true);
    expect(existsSync(`${layout.settingsFile}.tmp`)).toBe(false);
  });

  it('scenario 5: atomic write replaces prior content without producing a half-read', () => {
    const layout = getStorageLayout(tempRoot);
    ensureStorageLayout(layout);

    // Seed a prior file directly (simulating an existing settings file).
    writeFileSync(layout.settingsFile, JSON.stringify({ generation: 1 }), 'utf8');
    expect(readJson<{ generation: number }>(layout.settingsFile).generation).toBe(1);

    // Atomic write replaces it. Reader observes the new content fully formed.
    atomicWriteJson(layout.settingsFile, { generation: 2, payload: 'fresh' });
    const after = readJson<{ generation: number; payload: string }>(layout.settingsFile);
    expect(after.generation).toBe(2);
    expect(after.payload).toBe('fresh');

    // Sanity: the file content parses as valid JSON (no half-write).
    const raw = readFileSync(layout.settingsFile, 'utf8');
    expect(() => JSON.parse(raw)).not.toThrow();
    expect(existsSync(`${layout.settingsFile}.tmp`)).toBe(false);
  });

  it('scenario 6: getStorageLayout() without override defaults to ~/.mad-council-claw', () => {
    const layout = getStorageLayout();
    // Path-shape check only — never create directories in the operator's
    // home during the unit run. The path must end with the canonical
    // root segment.
    expect(layout.root.endsWith('.mad-council-claw')).toBe(true);
    expect(layout.sessions.endsWith(join('.mad-council-claw', 'sessions'))).toBe(true);
    expect(layout.skills.endsWith(join('.mad-council-claw', 'skills'))).toBe(true);
    expect(layout.automations.endsWith(join('.mad-council-claw', 'automations'))).toBe(true);
    expect(layout.audit.endsWith(join('.mad-council-claw', 'audit'))).toBe(true);
    expect(layout.settingsFile.endsWith(join('.mad-council-claw', 'settings.json'))).toBe(true);
  });
});
