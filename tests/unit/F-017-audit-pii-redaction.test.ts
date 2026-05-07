import { describe, it, expect } from 'vitest';
import { redact, redactObject, type RedactionOptions } from '@mad-council-claw/engine-core';

/**
 * F-017 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-017-pii-redaction-egress.md.
 *
 * Behavior contract (lane-b wave-012 brief):
 *   `redact(input, opts)` rewrites a string by replacing emails, phones, GUIDs,
 *   and home paths with `[<CATEGORY>_REDACTED]` markers. Each category is opt-in
 *   via a boolean (defaults all true) plus optional `customPatterns` for
 *   project-specific tokens. `redactObject` recursively applies `redact` to
 *   string leaves of an arbitrary nested object/array, preserving structure.
 *
 * Wave-12 lane-b brief narrows the F-017 ledger's stricter "reject on PII match
 * with PII_DETECTED error" semantics to a redactor-helper shape. The substantive
 * guarantee preserved: PII NEVER lands in audit-log writes / outbound emissions
 * unredacted. The reject-on-detect orchestration around this helper is a future
 * wave's work; the helper is the load-bearing primitive that makes either
 * orchestration shape (silent-redact OR reject-on-detect) trivial to compose.
 *
 * Acceptance scenarios (8):
 *   1. redact email — mid-sentence email replaced with [EMAIL_REDACTED].
 *   2. redact phone — three formats (555-555-5555, (555) 555-5555, +1-555-555-5555).
 *   3. redact GUID — canonical 36-char GUID replaced with [GUID_REDACTED].
 *   4. redact Windows home path — `C:\Users\alice` → `[HOMEPATH_REDACTED]`.
 *   5. redact macOS/Linux home paths — `/Users/alice` and `/home/alice`.
 *   6. opt-out of email redaction — emails preserved when `emails: false`.
 *   7. redactObject recurses through nested objects.
 *   8. customPatterns redact a project-specific token.
 *
 * RED-before-GREEN: `redact` + `redactObject` are not exported from
 * `@mad-council-claw/engine-core` at test-author time. Vitest collect fails
 * with module-resolution error → undefined → TypeError on first call.
 */

describe('F-017 audit-pii-redaction', () => {
  // Scenario 1 — redact email
  it('replaces an email in the middle of a sentence with [EMAIL_REDACTED]', () => {
    const input = 'Contact alice@example.com for support.';
    const out = redact(input);
    expect(out).toBe('Contact [EMAIL_REDACTED] for support.');
  });

  // Scenario 2 — redact phone (multiple formats)
  it('replaces phone numbers in three common formats with [PHONE_REDACTED]', () => {
    const formats = [
      'Call 555-555-5555 today.',
      'Call (555) 555-5555 today.',
      'Call +1-555-555-5555 today.',
    ];
    for (const input of formats) {
      const out = redact(input);
      expect(out).toBe('Call [PHONE_REDACTED] today.');
    }
  });

  // Scenario 3 — redact GUID
  it('replaces a canonical 36-char GUID with [GUID_REDACTED]', () => {
    const input = 'Run id is 550e8400-e29b-41d4-a716-446655440000 done.';
    const out = redact(input);
    expect(out).toBe('Run id is [GUID_REDACTED] done.');
  });

  // Scenario 4 — redact Windows home path
  it('replaces a Windows home path (C:\\Users\\<name>) with [HOMEPATH_REDACTED]', () => {
    const input = 'Trace at C:\\Users\\alice somewhere.';
    const out = redact(input);
    expect(out).toBe('Trace at [HOMEPATH_REDACTED] somewhere.');
  });

  // Scenario 5 — redact macOS/Linux home paths
  it('replaces /Users/<name> and /home/<name> with [HOMEPATH_REDACTED]', () => {
    expect(redact('Path /Users/alice file.')).toBe('Path [HOMEPATH_REDACTED] file.');
    expect(redact('Path /home/alice file.')).toBe('Path [HOMEPATH_REDACTED] file.');
  });

  // Scenario 6 — opt-out of email redaction
  it('preserves emails when emails: false is passed', () => {
    const opts: RedactionOptions = { emails: false };
    const input = 'Contact alice@example.com for support.';
    const out = redact(input, opts);
    expect(out).toBe('Contact alice@example.com for support.');
  });

  // Scenario 7 — redactObject recurses through nested objects
  it('redactObject recurses through nested {key: {key: "email"}} structures', () => {
    const input = {
      user: {
        contact: 'alice@example.com',
        runId: '550e8400-e29b-41d4-a716-446655440000',
      },
      tags: ['safe', 'bob@example.com', 'also-safe'],
      count: 7,
    };
    const out = redactObject(input);
    expect(out).toEqual({
      user: {
        contact: '[EMAIL_REDACTED]',
        runId: '[GUID_REDACTED]',
      },
      tags: ['safe', '[EMAIL_REDACTED]', 'also-safe'],
      count: 7,
    });
  });

  // Scenario 8 — customPatterns redact a project-specific token
  it('customPatterns redact a project-specific token with the supplied name', () => {
    const opts: RedactionOptions = {
      customPatterns: [{ name: 'API_KEY', pattern: /sk-[a-zA-Z0-9]{20,}/g }],
    };
    const input = 'Token sk-abcdefghijklmnopqrstuvwxyz used.';
    const out = redact(input, opts);
    expect(out).toBe('Token [API_KEY_REDACTED] used.');
  });
});
