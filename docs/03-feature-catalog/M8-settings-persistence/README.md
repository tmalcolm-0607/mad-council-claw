---
artifact-class: milestone-overview
generated-by: hand-authored (wave-004 / lane-d)
status: red
milestone: M8
short-slug: settings-persistence
features: F-067..F-075
authored: 2026-05-07
---

# M8 — Settings & persistence

The durable-state plane (`foundational-plan.md` § Feature catalog M8). M8 owns the persistence boundary for everything the user configures + everything the engine retains across restarts: global settings, per-automation overrides, encrypted at-rest storage, key management, encrypted cross-machine import/export, and project workspaces (a NEW v1 surface from Message 11). M8 is the trust anchor for M2 governance triad (audit chain integrity depends on F-070/F-071 not being silently bypassed) and the durability layer for M7 automations (per-run state, per-rule overrides) and M5 desktop shell (theme/personality/window-state preferences).

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-067 | settings-shape | Versioned `settings.json` (model/personality/prompts/MCP/perms/theme/telemetry/automation_rules); atomic writes; forward-compat unknown keys preserved |
| F-068 | settings-ui | 7-section Settings modal (Model/Personality/SystemPrompts/MCP/Permissions/Theme/Telemetry); ARIA-correct; theme-token primitives; Save/dirty/cancel semantics |
| F-069 | settings-per-automation-rules | Per-automation overrides (model/permission/MCP/system-prompt-append/cost-cap); validation-failed rules disabled-not-dropped |
| F-070 | encrypted-local-storage | **NEW.** AES-256-GCM at-rest envelope for `settings.json`, audit/, runs/, secrets/; transparent decrypt; tamper-fail = hard error; plaintext-migration on upgrade |
| F-071 | encryption-key-mgmt | **NEW.** Native OS vault: DPAPI (Windows) / Keychain (macOS) / libsecret (Linux); IKeyProvider interface; manual rotation; cross-platform mismatch surfaces clearly |
| F-072 | encrypted-import-export | **NEW.** `<state-dir>.mcc-bundle` portable bundle; Argon2id passphrase wrap; export-as-Dangerous-Operation; round-trip cross-platform |
| F-073 | project-workspace | **NEW.** Named, isolated configuration scopes overlaying global; per-workspace skill/MCP/permission/personality; `default` workspace always present + non-deletable |
| F-074 | workspace-switcher-ui | **NEW.** Window-chrome dropdown switcher; "+ New workspace..." action; type-name-to-confirm delete; default workspace non-deletable in UI |
| F-075 | workspace-persistence | **NEW.** Active workspace persists across restart via `active-workspace.json`; missing-workspace fallback to default with structured warning; immutable workspace IDs; atomic writes |

## Provenance

| Source family | Surfaces |
|---|---|
| `foundational-plan` | M8 catalog row F-067..F-075 + Message 11 NEW additions ("Bring-your-own MCP + encrypted local storage" + "Daily briefing + project workspace") |
| `cp:` (clawpilot) | settings-shape, settings-ui, per-automation-rules patterns (F-067, F-068, F-069) |
| **NEW (no source surface)** | F-070 encrypted-local-storage, F-071 encryption-key-mgmt, F-072 encrypted-import-export, F-073 project-workspace, F-074 workspace-switcher-ui, F-075 workspace-persistence — emergent from Message 11 |
| `kit:` (MAD kit rules) | rules/concurrency-safety.md (atomic writes); rules/single-owner-accountability.md (owner_alias on settings + workspace.json); rules/no-silent-deferrals.md (validation-failed rules visible-disabled, not dropped); rules/no-invented-constraints.md (no implicit workspace caps); rules/dangerous-operations-policy.md (delete-workspace + export consent gates); rules/stride-threat-model.md (Tampering / Info-Disclosure threats for F-070/F-071/F-072); rules/degradation-fallback-policy.md (missing-workspace fallback) |
| `msft-learn:` | DPAPI (Windows), Keychain Services (macOS), libsecret (Linux) — F-071 platform contracts |

## Dependency DAG

```
F-008 (storage layout)  ──→ F-067 (settings.json path)
                        ──→ F-070 (sensitive-paths definition)
                        ──→ F-071 (key-index.json path)
                        ──→ F-073 (workspaces/ subtree)
                        ──→ F-075 (active-workspace.json + workspaces/<id>/)
F-001 (engine kernel)   ──→ F-067 (hosts settings reader/writer)

F-067 (settings shape)  ──→ F-068 (UI consumes shape)
                        ──→ F-069 (automation_rules slot in shape)
                        ──→ F-073 (global is base overlay)
                        ──→ F-070 (settings.json is encryption target)

F-071 (key API)         ──→ F-070 (consumes IKeyProvider.getKey)
                        ──→ F-072 (wraps/unwraps data key during export/import)

F-070 (encrypted store) ──→ F-072 (encrypted state files are export targets)
                        ──→ F-075 (workspace.json + active-workspace.json encryption)

F-073 (workspace)       ──→ F-074 (switcher UI surface)
                        ──→ F-075 (persistence semantics)

F-074 (switcher UI)     ──→ F-075 (active-workspace.json reader/writer)

External (consumers of M8):
F-061..F-066 (M7 automations) ──→ F-069 (consume per-rule overrides)
F-033 (rail)                  ──→ F-073 (filter sessions by active workspace)
F-035 (model picker)          ──→ F-073 (workspace MCP allowlist)
F-039 (theming)               ──→ F-067 (theme key in settings.json)
F-049 (BYO-MCP)               ──→ F-067/F-073 (global allowlist + per-workspace subset)
F-058 (3-tier perms)          ──→ F-067/F-073 (global tier + per-workspace stricter override)
F-113 (telemetry opt-in/out)  ──→ F-068 (consent dialog on toggle)
F-015 (hash-audit chain)      ──→ F-070 (envelope preserves chain integrity per-line)
```

## Open decisions (D-3, D-5)

Two M8 design decisions are OPEN, tracked in `docs/10-backlog/design-decisions-pending.md`:

- **D-3** — encryption key source default. F-071 assumes OS keychain (DPAPI/Keychain/libsecret) as the v1 default. If user input or threat-model review prefers BYOK or passphrase-only, F-071 extends IKeyProvider; the F-070/F-072 contracts hold either way.
- **D-5** — storage encryption: BYOK vs system-managed default for v1. Inflects F-070 + F-071 + F-073/F-075 layout conventions (single-root `<state-dir>/workspaces/<id>/` subtree assumed in this milestone's ledgers).

These are explicitly NOT silently deferred per `kit:rules/no-silent-deferrals.md`; both ledgers reference the open decision + state the working assumption + describe what changes if the decision closes otherwise.

## Milestone exit criteria

- All 9 ledgers GREEN
- A fresh install on Windows + macOS + Linux produces an encrypted `settings.json` from first save (per F-070) without user intervention
- Tampering with the on-disk ciphertext is observable as `DECRYPT_AUTHENTICATION_FAILED` on next read; no silent fallback to plaintext
- DPAPI / Keychain / libsecret integration round-trips a 256-bit key on each platform's CI runner
- A `<state-dir>.mcc-bundle` round-trips between Windows + macOS without data loss + with passphrase verification
- `default` workspace is always present + non-deletable + non-renameable (display name only is editable)
- Switching workspaces flips the rail (F-033), info panel (F-034), model picker (F-035) within ≤1s
- Per-automation rules (F-069) override only the keys they set; validation-failed rules persist on disk with a `[DISABLED]` flag visible in audit
- Settings UI (F-068) keyboard navigates fully + telemetry opt-in fires the consent dialog before applying
- D-3 + D-5 closed (verdict files in `docs/05-design-reviews/`) before any F-070/F-071/F-073/F-075 implementation begins

## Out of scope (tracked elsewhere)

- Cloud-synced settings + workspaces (live sync via OneDrive / iCloud / Microsoft Account roaming) → v1.5
- HSM-backed keys + hardware tokens → M19 deferred (F-D-005 identity-crypto)
- Per-field encryption (encrypt only secrets, leave non-sensitive plaintext) → v1.5
- Recovery codes / printable backup phrase for key loss → v1.5
- Workspace templates (start a new workspace from a snapshot) → v1.5
- Workspace history (auto-snapshot on every change) → v1.5
- Drag-and-drop workspace reordering + workspace icons / colors → v1.5
- Per-workspace cost-budget caps + cumulative cost tracking → v1.5
- Multi-window with different active workspaces (per F-043 multi-window) → v1.5
- Cross-workspace rule inheritance + workspace-template inheritance → v1.5
- Schema migration tooling for major-version bumps → M19 deferred (F-D-004)
- Searching / filtering the workspace list → v1.5
- Cross-machine workspace sync (live, not via F-072 export bundle) → v1.5
- Sandbox / dry-run preview of an automation rule's effects → v1.5
- Centralized rule-conflict resolution UI → v1.5
- Settings search / filter UI → v1.5; v1 ships with section tabs
- In-place keybinding remap + chord shortcuts → v1.5

## Cross-milestone hooks

| Consumer milestone | Where it touches M8 |
|---|---|
| M0 bootstrap | F-008 (storage layout) is M8's hard dep — M0 declares the path conventions |
| M1 backend | F-067 stores active model + provider for backend factory (per F-012) to read on startup |
| M2 governance triad | F-015 hash-audit chain integrity preserved across F-070 envelope (per-line encryption, not per-file) |
| M3 cron | F-069 per-automation rules carry cron-driven automation overrides (cost cap, model override) |
| M5 desktop shell | F-067 stores theme (F-039) + personality (F-036) + window-state pointer (F-032 stores its own file plaintext) |
| M6 MCP & tools | F-067 stores global MCP allowlist; F-073 stores per-workspace subset |
| M7 skills+perms+auto | F-067 stores enabled skill list; F-069 stores per-automation overrides; F-073 stores per-workspace skill/perm subset |
| M9 M365 integration | F-070 covers the MSAL token cache + WorkIQ refresh tokens at-rest |
| M11 soul/introspect/replay | F-067 stores soul-boundary configuration; F-070 covers replay snapshot files |
| M16 telemetry | F-067 stores telemetry opt-in flag; F-068 fires consent dialog on toggle |

## Wave attribution

Wave 4 / Lane D authored all 9 ledgers + this README + `docs/06-agent-team-outputs/wave-004/lane-d-summary.md` in a single ≤5 min wall-clock sweep per `kit:rules/loop-cadence-discipline.md`. Provenance maps cleanly to foundational-plan + clawpilot settings + Message 11; D-3 + D-5 are explicit open decisions (not silently deferred).
