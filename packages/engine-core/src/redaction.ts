/**
 * F-017 — audit-pii-redaction.
 *
 * Per docs/03-feature-catalog/M2-governance-triad/F-017-pii-redaction-egress.md.
 *
 * Pattern-based redactor: rewrites a string by replacing common PII categories
 * (emails, phones, GUIDs, home paths) with `[<CATEGORY>_REDACTED]` markers.
 * Each built-in category is opt-in via a boolean (defaults all true). Callers
 * may pass `customPatterns` for project-specific tokens (API keys, JWTs, etc.).
 *
 * Wave-12 lane-b scope (per brief): redactor-helper primitive only. The
 * F-017 ledger's stricter "reject on detect with PII_DETECTED error"
 * orchestration is composed atop this primitive in a future wave; the helper
 * is shape-agnostic between silent-redact and reject-on-detect.
 *
 * `redactObject` recursively walks an arbitrary nested object/array, applying
 * `redact` to every string leaf. Non-string primitives pass through unchanged.
 * Useful for sanitizing audit-log entry bodies before write, telemetry export
 * payloads, and outbound LLM-call prompts.
 */

export interface RedactionOptions {
  /** Replace email addresses with [EMAIL_REDACTED]. Default true. */
  emails?: boolean;
  /** Replace phone numbers with [PHONE_REDACTED]. Default true. */
  phones?: boolean;
  /** Replace GUIDs with [GUID_REDACTED]. Default true. */
  guids?: boolean;
  /**
   * Replace OS home paths (Windows `C:\Users\<name>` or POSIX `/Users/<name>`
   * / `/home/<name>`) with [HOMEPATH_REDACTED]. Default true.
   */
  homePaths?: boolean;
  /**
   * Project-specific patterns. Each entry's `pattern` is run as `replace`
   * against the input; matches are replaced with `[<name>_REDACTED]`.
   * Patterns SHOULD use the global flag (`g`) to redact every occurrence.
   */
  customPatterns?: { name: string; pattern: RegExp }[];
}

const DEFAULTS: Required<Omit<RedactionOptions, 'customPatterns'>> = {
  emails: true,
  phones: true,
  guids: true,
  homePaths: true,
};

const EMAIL_RE = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const PHONE_RE = /(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b/g;
const GUID_RE = /\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b/g;
const HOME_PATH_RE = /(?:[A-Za-z]:\\Users\\[^\\\s]+|\/(?:home|Users)\/[^\/\s]+)/g;

/**
 * Redact PII patterns in a string.
 *
 * Order of operations: emails → GUIDs → phones → home paths → custom patterns.
 * GUIDs MUST run before phones — a GUID's last 12-hex block (e.g.
 * `446655440000`) contains digit sequences that match the phone pattern's
 * 3-3-4 shape and would otherwise be partially absorbed by phone redaction.
 */
export function redact(input: string, opts: RedactionOptions = {}): string {
  const o = { ...DEFAULTS, ...opts };
  let s = input;
  // Order matters: GUIDs are run BEFORE phones because a GUID's hex tail can
  // contain a phone-shaped substring (12 hex chars in the last block include
  // sequences that match the phone pattern's 3-3-4 digit shape). Removing
  // GUIDs first prevents that false-match.
  if (o.emails) s = s.replace(EMAIL_RE, '[EMAIL_REDACTED]');
  if (o.guids) s = s.replace(GUID_RE, '[GUID_REDACTED]');
  if (o.phones) s = s.replace(PHONE_RE, '[PHONE_REDACTED]');
  if (o.homePaths) s = s.replace(HOME_PATH_RE, '[HOMEPATH_REDACTED]');
  for (const p of opts.customPatterns ?? []) {
    s = s.replace(p.pattern, `[${p.name}_REDACTED]`);
  }
  return s;
}

/**
 * Recursively redact PII in every string leaf of an arbitrary value.
 *
 * - Strings: passed through `redact(value, opts)`.
 * - Arrays: each element walked with `redactObject`.
 * - Plain objects: each value walked; keys are NOT redacted (callers should
 *   not put PII in keys).
 * - Other primitives (number / boolean / null / undefined / bigint / symbol):
 *   passed through unchanged.
 *
 * Type parameter `T` is preserved so callers can sanitize a typed payload
 * without losing the type at the call site. Internally the function uses
 * `unknown` casts for the recursion; the structure of `T` is preserved.
 */
export function redactObject<T>(obj: T, opts: RedactionOptions = {}): T {
  if (typeof obj === 'string') return redact(obj, opts) as unknown as T;
  if (Array.isArray(obj)) return obj.map(v => redactObject(v, opts)) as unknown as T;
  if (obj && typeof obj === 'object') {
    const result: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(obj)) {
      result[k] = redactObject(v, opts);
    }
    return result as unknown as T;
  }
  return obj;
}
