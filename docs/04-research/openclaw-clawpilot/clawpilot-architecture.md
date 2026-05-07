---
title: Clawpilot architecture inventory
wave: wave-001
lane: lane-c
topic: 1/6
source-tag: "[CP:m-main]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# Clawpilot architecture inventory

> Read-only walk of `C:\Users\tonym\Repos\m-main` (commit `38659a58`, v0.22.66). All citations cite file paths inside `m-main/`. Nothing in this directory was modified.

## 1. Two-process Electron shape

| Process | Path | Purpose |
|---|---|---|
| Main | `electron/` | Window management, IPC handlers, Copilot SDK client, session lifecycle, permission dialogs, MCP server configuration |
| Renderer | `src/` | React 19 UI; communicates with main exclusively via IPC + preload bridge |
| Sidecar | `sidecar/` | Cross-platform Node runner (`node-runner.exe` on Windows for `ELECTRON_RUN_AS_NODE=1`) used to spawn MCP servers without console windows |
| Bundled MCP | `bundled-mcp/filesystem-server.mjs` | Single bundled MCP server (filesystem). Other MCPs (Playwright, WorkIQ) are external NPM packages |

Confidence: HIGH. Cited from `CLAUDE.md:42-46` + filesystem walk.

## 2. `electron/` top-level files (architecture-bearing only)

Total enumerated: 134 top-level files in `electron/` (test + source). Architecture-bearing breakdown:

| File | LOC | Role |
|---|---:|---|
| `main.ts` | — | Composition root; wires backends, registers IPC, sets up deep-link `ms-clawpilot://` protocol |
| `sessions.ts` | **3,292** | Session lifecycle, persistence, dedup, lookup. Backend-agnostic (must not import `backend/gateway/**` or `backend/copilot-*.ts`). |
| `permission-policy.ts` | **1,331** | 3-tier permission engine (auto-approve / prompt / block) with shell-syntax parsing |
| `permission-card-manager.ts` | — | Approval UI orchestration, integrates with `permission-policy` |
| `permission-classifier.ts` | — | Classifies tool calls into permission categories |
| `permission-pattern-guardrails.ts` | — | Pattern-based block list |
| `permissions.ts` | — | Permission persistence + rules store |
| `automations.ts` | — | Top-level automation entry; cron + condition + multi-step |
| `skills.ts` | **766** | Skills loader, sanitization, install/uninstall, bundled vs first-party merge |
| `preload.cjs` | — | Context-bridge preload script exposing namespaced IPC APIs to renderer |
| `updater.ts` | — | electron-updater integration; beta + stable channels |
| `tray.ts` | — | System tray; show/hide |
| `notifications.ts` | — | Native notifications |
| `notification-router.ts` | — | Routes notifications to UI / mini-mode / background |
| `system-message.ts` | — | System prompt construction (per-personality + custom user system message) |
| `model-manager.ts` | — | Model picker state, alias resolution, per-backend availability |
| `tool-discovery.ts` | — | Discovers tools available from active backend + MCP servers |
| `mock-mode.ts` + `mock-copilot-client.ts` + `mock-session.ts` | — | Mock backend for E2E and dev |
| `m365-token.ts` + `m365-token-wam.ts` + `m365-tools.ts` | — | M365 token broker (WAM-first on Windows, MSAL fallback) |
| `mcp-store.ts` + `mcp-tools.ts` + `mcp-crypto.ts` + `mcp-disabled.ts` | — | MCP server registry, tool discovery, encrypted credential store |
| `legacy-memory-store.ts` + `shadowing-memora-store.ts` | — | Memory subsystem (shadowing layer wraps Loki Memora behind feature flag) |
| `tray.ts` + `keep-awake.ts` + `power.ts` + `apply-keep-awake-settings.ts` | — | Power management, prevent system sleep during long runs |
| `sensitivity-elevation.ts` | — | MIP sensitivity-label-aware elevation prompts |
| `safe-storage-file.ts` | — | OS-keychain-backed encryption for tokens / secrets |
| `tenant-policy.ts` + `m365-token-wam-gate.ts` | — | Tenant filtering (org-only on macOS broker per recent fix) |
| `audit-log.ts` | — | Append-only audit trail |
| `cert-pins.ts` | — | TLS cert pinning for selected outbound calls |
| `untrusted-wrap.ts` | — | Sandboxes content from untrusted sources before display |
| `screen-capture.ts` | — | Screenshot capability for multimodal input |
| `teams-relay.ts` + `teams-relay-lifecycle.ts` | — | Teams relay (incoming Teams DMs route through here) |
| `theme.ts` + `theme-flash-prevention.ts` | — | Light/dark with flash prevention |
| `update-progress.ts` + `updater.ts` | — | Update progress UI + electron-updater integration |
| `heartbeat.ts` + `background-service.ts` | — | Per-session heartbeat tracking + bg-service for pings |
| `horizon.ts` + `horizon-formatter.ts` | — | Horizon = Daily-briefing engine (calendar + email + tasks aggregation) |
| `session-search.ts` + `session-store.ts` + `session-index-writer.ts` + `session-view-builder.ts` | — | Session indexing, search, persistence layers |
| `turn-accumulator.ts` | — | Aggregates SDK events into typed `TurnEvent`s for renderer |
| `event-forwarding.ts` + `view-emission.ts` | — | Event bus from main → renderer |
| `sanitize.ts` + `markdown-utils.ts` + `html-utils.ts` + `image-utils.ts` + `mask-email.ts` + `yaml-utils.ts` | — | Content sanitization + safe markdown/HTML rendering |
| `error-formatting.ts` + `telemetry-errors.ts` + `diagnostic-logger.ts` | — | Structured error formatting + telemetry-friendly error scrubbing |
| `mini-mode.ts` + `mini-mode/` + `mini-mode-page/` | — | Mini-mode floating window (compact view) |
| `main-window-controller.ts` | — | Main window state machine |
| `show-hide-shortcut.ts` | — | Global hotkey for toggle |
| `browser-detect.ts` + `open-external.ts` | — | Browser detection + safe external-url opening |

Source: filesystem walk of `electron/` (Bash `ls` 2026-05-06). Confidence: HIGH for file enumeration; MEDIUM for "role" descriptions (inferred from filename + tests, did not read every file body).

## 3. `electron/` subdirectories (sub-systems)

| Subdir | File count | Purpose |
|---|---:|---|
| `electron/auth/` | 6 | MSAL provider, deep-link loopback (`ms-clawpilot://auth/callback`), gateway auth store |
| `electron/automations/` | 13 | Schedule + condition-monitor + manager + store + triggering + Zod schemas + types |
| `electron/backend/` | 14 + `gateway/` subdir | `IBackendProvider` abstraction; copilot backend; backend factory; conformance tests; ports |
| `electron/backend/gateway/` | 14 + `automation/` + `desktop-capabilities/` subdirs | AAD-MSAL gateway (web-relay backend); `auth-controller`, `device-identity`, `model-id`, `session-sync`, `ws-client`, OpenClaw device pairing flow |
| `electron/ipc/` | ~60 files (28 handler pairs + tests) | Per-namespace IPC handlers: activities / ai-investigator / app / automations / automations-desktop / backend / copilot / diagnostics / extensions / file-export / heartbeat / horizon (3 files: base + email + teams) / identity / import-conflict-dialog / m365-auth / mcp / mcp-oauth / memory / mini-mode / models / permissions / personality / preferences / sessions / settings / shell / skills / teams-relay / tenant / update / window-controls / workspace + `context-picker/` subdir + `with-timeout.ts` + `ipc-handle.ts` (typed wrapper) + `ipc-limits.ts` |
| `electron/m365/` | ~25 + `test-helpers/` | Calendar, email (4 files), Graph queries, MIP labels (integration test), OneDrive, Outlook timezone, people, persona-photo, planner, presence, sensitivity-labels, tasks, Teams (3 files), shared utils, integration tests |
| `electron/loki/` | 5 | Loki client + experiments-migration + IPC + shared types (recent: shadow Loki Memora behind experiment flag) |
| `electron/memora/` | 4 | Memora client + memory-store (Memora is the new vector-memory subsystem) |
| `electron/teams/` | 3 | Progress narrator (sends "still working…" pings into Teams during long runs) |
| `electron/identity/` | 2 | Identity composer (per-user identity from auth providers) |
| `electron/schemas/` | 1 | `session-schema.ts` (Zod schema for stored sessions) |
| `electron/ai-investigator/` | 4 | AI investigator manager + payload (deep-investigation skill) |
| `electron/mini-mode/` | 5 | Position, state, theme, types, window |
| `electron/mini-mode-page/` | 3 | HTML/CSS/JS for mini-mode floating window content |
| `electron/test-helpers/` | 10 | Test utilities (call-ipc, flush-microtasks, gateway test access, mock-call-arg, parse-written-json, stub-client-factory, etc.) |

Confidence: HIGH (filesystem walk).

## 4. `src/features/*` (renderer feature modules)

Top-level features in `src/features/`:

| Feature | Files (approx) | Purpose |
|---|---:|---|
| `chat/` | 30+ in `components/`, plus `editor/`, `hooks/`, `state/`, `stores/`, `testing/`, `types.ts`, `index.ts` | Chat UI: ChatPanel, ChatInput (+ telemetry tests), ChatMessage, AssistantRun, ModelPicker, PersonalityPicker, PermissionCard (+ telemetry), SkillSlashMenu, Timeline, AttachmentPillList (+ browser test), EntityPill, InlineQuestion, SensitivityBadge, WelcomeState, LiveTrailing, CollapsibleIndicator, ChatInputActions, ChatInputAddOns, `state/sessionDrafts.ts`, `stores/permission-cards-store.ts`, `components/context-picker/` |
| `auth/` | ~18 + `gateway/` (10) + `stages/` (16) | AuthScreen + AuthErrorBanner + cache + deriveStage + useAuthFlow + useGitHubAuth + useM365Auth + useTelemetryTenantId + useTelemetryUserId. Stages: AuthCardShell, AuthCheckingCard, ConnectGitHubCard, ConnectM365Card, CopilotAccessRequiredCard, GitHubDeviceCodeCard, M365AccessDeniedCard, M365SigningInCard, SignInStartCard, TermsFooter, LockShieldIcon, copy.ts. Gateway: FakeJwtForm, GatewayAuthGate, GatewayLoginScreen, PairingDialog (OpenClaw device pairing), useGatewayAuth |
| `automations/` | 9 | AutomationDeleteDialog, AutomationFormView, AutomationHistoryView, AutomationListView (+ telemetry), AutomationOverflowMenu, AutomationsPanel, GithubImportView, automation-form-state |
| `permissions/` | 9 | PermissionsEditor, PermissionsPanel, PermissionsSummary, ShellPatternsSection, ToolGroupSection, useToolRegistry, permissions-format |
| `extensions/` | 17 | AddMcpDialog, AddSkillDialog, ExtensionsCard, ExtensionsDetailDialog (+ telemetry), ExtensionsDialogs, ExtensionsPanel, HorizontalCarousel, ImportDialog, McpServersTab (+ telemetry), parseCatalogContent, SkillsTab (+ telemetry), useExtensionsActions, useExtensionsData |
| `horizon/` | 8 | BriefButton, EmailBriefButton, HorizonActionPane, HorizonPanel (+ telemetry), SendBriefButton |
| `integrations/` | 8 | IntegrationsPanel (+ telemetry), M365StatusCard, teamsRelayStatusStore, useTeamsRelayNetworkChangeForwarder, useTeamsRelayStatus |
| `memories/` | 2 | MemoriesPanel (+ test) |
| `peopleiq/` | 1 | PeopleIqPanel (PeopleIQ surfaces) |
| `settings/` | ~12 + `Sections/` (10) | DefaultModelPicker (+ telemetry), DiagnosticsSection, EditPermissionsDialog, SettingsPanel, SettingsRow, useDefaultWorkspaceDir, useSettings. Sections: AboutSection, AppearanceSection, MemorySection, PermissionsSection (+ telemetry), PowerManagementSection, PrivacySection, SessionRetentionSection, WindowBehaviorSection |
| `consent/` | (subdir present, not enumerated) | Consent flow |
| `create/` | (subdir present) | "Create" surfaces (likely creating skills / automations) |
| `ai-investigator/` | (subdir present) | AI investigator UI |
| `heartbeat/` | (subdir present) | Heartbeat surfaces |
| `activities/` | (subdir present) | Activity timeline (likely Agent execution timeline + replay) |

Confidence: HIGH (filesystem walk + file naming convention).

## 5. `common/` shared code

```
auth-errors.ts            constants.ts                context-picker-utils.ts
default-settings.ts       error-format.ts             extensions-catalog/
format-tool-description.ts gateway-auth-presets.ts    ipc-contract.ts (2,075 LOC — IPC source-of-truth)
logger.ts                  mcp-url-validation.ts       mini-mode-settings.ts
mock-scenarios.ts          permission-servers.ts       quick-title.ts
skill-sanitization.ts      telemetry/                  tool-registry.ts
```

`common/ipc-contract.ts` (2,075 LOC, source: `wc -l`) is the **single source of truth** for IPC RPC method groups, domain types, event payloads, and namespace API interfaces. Discovered RPC namespaces (from `electron/ipc/*-ipc.ts` enumeration):

| Namespace | Purpose |
|---|---|
| `activities` | Activity timeline |
| `ai-investigator` | AI investigator deep-investigation |
| `app` | App-level events (focus, blur, etc.) |
| `automations` | Automation CRUD + history |
| `automations-desktop` | Desktop-specific automation operations |
| `backend` | Backend selection, conformance, capabilities |
| `copilot` | Copilot SDK proxy |
| `diagnostics` | Diagnostic export, log retrieval |
| `extensions` | Extensions tab actions |
| `file-export` | File export |
| `heartbeat` | Heartbeat ping |
| `horizon` | Horizon brief generation (3 IPC files: base + email + teams) |
| `identity` | Identity composer |
| `import-conflict-dialog` | Skill/extension import conflicts |
| `m365-auth` | M365 auth lifecycle |
| `mcp` | MCP server registry |
| `mcp-oauth` | MCP OAuth flows |
| `memory` | Legacy memory store |
| `mini-mode` | Mini-mode toggle |
| `models` | Model picker |
| `permissions` | Permissions management |
| `personality` | Personality picker |
| `preferences` | User preferences |
| `sessions` | Session CRUD |
| `settings` | Settings (general) |
| `shell` | Shell command execution (with permissions) |
| `skills` | Skills CRUD + install |
| `teams-relay` | Teams relay status |
| `tenant` | Tenant policy |
| `update` | App update |
| `window-controls` | Window min/max/close |
| `workspace` | Workspace folder management |

Confidence: HIGH for namespace list (filesystem walk). MEDIUM for purpose (inferred from filename).

## 6. Test infrastructure

| Config | Purpose |
|---|---|
| `vitest.config.ts` | 4 projects: `unit` (happy-dom, `src/**/*.test.tsx`), `browser` (playwright headless Chrome, `src/**/*.browser.test.tsx`), `node` (Node, `electron/**/*.test.ts`), `integration` (Node, 30s timeout, `electron/**/*.integration.test.ts`) |
| `playwright.config.ts` | E2E tests in `e2e/` (Electron + Playwright) |
| `playwright.perf.config.ts` | Perf E2E tests |
| `e2e-integration/` | Integration runner (`runner.mjs`, `publish-results.mjs`) |
| `e2e/` | Standard E2E tests |

Test command surface: `pnpm test`, `pnpm test:watch`, `pnpm test:coverage`, `pnpm test:e2e`, `pnpm test:e2e:file`, `pnpm test:integration`, `pnpm test:m365`, `pnpm test:perf`, `pnpm test:python` (Python tests in skills), `pnpm test:scripts` (script tests).

Confidence: HIGH (cited from `package.json:scripts`).

## 7. External dependencies (production, from `package.json`)

| Group | Packages |
|---|---|
| **1JS telemetry** | `@1js/diagnostics 1.2.135`, `@1js/functional 7.0.94`, `@1js/guid 5.1.136`, `@1js/hugin-schema 3.2.79`, `@1js/hugin-shared-middleware 2.2.118`, `@1js/hugin-sink-1ds 1.1.137`, `@1js/hugin-sink-console 1.1.139`, `@1js/midgard-error 7.2.136`, `@1js/px-telemetry 22.16.36` |
| **MSAL** | `@azure/msal-node ^5.1.2`, `@azure/msal-node-extensions ^5.1.2` (token-cache encryption) |
| **Copilot SDK** | `@github/copilot-sdk ^0.3.0` (recent — adopted scoped permission model per commit `0e9b77fa`) |
| **WorkIQ** | `@microsoft/workiq ^0.4.1` (Microsoft AI internal-only — Teams/email/calendar context) |
| **MCP** | `@modelcontextprotocol/sdk ^1.29.0`, `@modelcontextprotocol/server-filesystem ^2026.1.14`, `@playwright/mcp ~0.0.68` |
| **UI** | `react ^19.2.5`, `radix-ui ^1.4.3`, `shadcn ^4.2.0`, `cmdk ^1.1.1`, `class-variance-authority ^0.7.1`, `tailwind-merge ^3.5.0`, `tw-animate-css ^1.4.0`, `lucide-react ^1.8.0`, `@fluentui/react-brand-icons ^2.0.198` |
| **Editor** | `@monaco-editor/react ^4.7.0`, `monaco-editor ^0.55.1`, `lexical ^0.43.0`, `@lexical/react ^0.43.0`, `@lexical/utils ^0.43.0` |
| **Markdown / sanitization** | `dompurify ^3.3.3`, `streamdown ^2.5.0`, `@streamdown/mermaid ^1.0.2`, `rehype-harden ^1.1.8`, `@shikijs/core ^4.0.2` (+ engine-javascript, langs, themes) |
| **State / data** | `@tanstack/react-query ^5.97.0`, `zod ^4.3.6` |
| **Notifications / UX** | `sonner ^2.0.7`, `use-stick-to-bottom ^1.1.3` |
| **Networking** | `ws ^8.20.0` |
| **Build** | `electron ^41.1.1`, `electron-builder ^26.8.1`, `vite`, `@vitejs/plugin-react ^6.0.1`, `typescript ^6.0.2` |
| **Lint / format** | `oxlint ^1.61.0`, `oxfmt ^0.46.0`, `oxlint-tsgolint ^0.21.1`, `eslint ^10.2.1` (only for plugins: tanstack/query, playwright, react-hooks, testing-library, better-tailwindcss) |
| **Test runners** | `@vitest/browser ^4.1.5`, `@vitest/browser-playwright ^4.1.5`, `@vitest/coverage-v8 ^4.1.5`, `@playwright/test ^1.58.2`, `happy-dom ^20.8.9`, `@testing-library/react ^16.3.2` (+ dom, jest-dom, user-event) |
| **Pre-commit** | `husky ^9.1.7`, `lint-staged ^16.3.3` |
| **Misc tooling** | `chrome-remote-interface ^0.34.0`, `fallow ^2.47.0` (skills sandbox?) |

Confidence: HIGH (cited verbatim from `package.json:43-103`).

## 8. Bundled vs first-party skills + bundled MCP

Bundled skills (`bundled-skills/`): `ai-investigator`, `docx`, `excalidraw`, `expense-report`, `loop`, `pptx`, `web-artifacts-builder`, `xlsx`.

First-party-skills (`first-party-skills/`): `excalidraw`, `expense-report`, `loop`, `pptx`, `web-artifacts-builder` (5 — overrides for some bundled).

Repo-local review skills (`skills/`): `codebase-health`, `derive-rules`, `m-code-review`, `m-pr-ops`, `m-release-notes`, `m-review-dashboard`, `publish-pr`.

Bundled MCP (`bundled-mcp/`): `filesystem-server.mjs` (single file). Other MCPs are external packages.

Sidecar (`sidecar/`): Node runner for cross-platform MCP spawning. `node-runner.cs` + `node-runner.exe` (Windows-specific, `ELECTRON_RUN_AS_NODE=1` + `CreateNoWindow`).

Confidence: HIGH (filesystem walk).

## 9. Enterprise / compliance shape

| Path | Purpose |
|---|---|
| `enterprise/clawpilot.admx` + `enterprise/en-US/` | Group Policy template for enterprise-managed Clawpilot deployments (admin can lock down settings) |
| `electron/sensitivity-elevation.ts` + `electron/m365/sensitivity-labels.ts` + `electron/m365/mip-labels.integration.test.ts` | MIP (Microsoft Information Protection) labels: read sensitivity from documents/emails, elevate consent prompts on confidential content |
| `electron/audit-log.ts` | Append-only audit log |
| `electron/cert-pins.ts` | TLS cert pinning |
| `electron/safe-storage-file.ts` | OS-keychain encryption wrapper for tokens |
| `electron/tenant-policy.ts` + `m365-token-wam-gate.ts` | Tenant filtering (org-only on macOS broker — recent fix `89be5fa5`) |
| `teams-manifest/` | MS Teams manifest (`manifest.json`, `color.png`, `outline.png`, `README.md`) — Clawpilot exposes a Teams bot/app |
| `minimum-version.json` | Force-update floor (enterprise control) |

Confidence: HIGH (filesystem walk + cited commits).

## 10. Backend abstraction (current state)

Per `CLAUDE.md:78-101`:

- **`IBackendProvider`** abstraction in `electron/backend/`
- Two backends today: **`copilot`** (`copilot-backend.ts`, `copilot-automation-backend.ts`) and **`gateway`** (subdir `electron/backend/gateway/`, AAD-MSAL web-relay)
- 5 invariants enforced by oxlint `no-restricted-imports`:
  1. `electron/sessions.ts` MUST NOT import `backend/gateway/**` or `backend/copilot-*.ts`
  2. Shared code MAY reference `backend.origin` only for validation + visibility filter, NOT to fork behavior
  3. `ISessionBackend` must declare only methods implementable by any backend
  4. Per-backend machinery lives in `backend/<name>/` or `backend/<name>-*.ts`
  5. Composition root (`main.ts`) is exempt from rule 2
- Index rows missing `backendOrigin` default to `"copilot"` (pre-spec sessions)

Confidence: HIGH (verbatim from CLAUDE.md).

## 11. Auth surfaces

Per `CLAUDE.md:153-160`:

- **MSAL** (`electron/auth/msal-provider.ts`) — primary on all platforms; deep-link redirect URI `ms-clawpilot://auth/callback`
- **Deep-link loopback** (`electron/auth/deep-link-loopback.ts`) — custom `ILoopbackClient`; macOS via `open-url`, Windows/Linux via `second-instance`; registered in `main.ts` + `electron-builder.json5`
- **WAM** (`electron/m365-token-wam.ts`) — Windows-only silent broker; requires local console session, AAD-joined device, valid PRT; falls back gracefully
- **Entry point**: `electron/m365-token.ts` — WAM-first on Windows, MSAL fallback
- **Gateway auth**: `electron/auth/gateway-auth-store.ts` + `electron/backend/gateway/auth-controller.ts` + OpenClaw device pairing flow (`PairingDialog.tsx`, commit `8c39a277`)

Confidence: HIGH (CLAUDE.md + filesystem).

## 12. Permission system shape

Per `CLAUDE.md:166-171`:

- 3-tier in `electron/permission-card-manager.ts` + `permission-policy.ts`:
  1. **Auto-approve**: read-only commands (`ls`, `cat`, `grep`, `git status`, etc.)
  2. **Prompt**: writes / deletes / network ops show dialog
  3. **Block**: dangerous patterns blocked outright
- Recent shift to **SDK 0.3.0 scoped permission model** (commit `0e9b77fa`)
- Scheduled automations now **fail-closed for unclassified custom tools** (commit `fa3d9d6e`)
- Components: `permission-classifier.ts`, `permission-pattern-guardrails.ts`, `permission-patterns.ts`, `permission-shell-syntax.ts`, `permission-policy.ts` (1,331 LOC)

Confidence: HIGH (CLAUDE.md + commits + filesystem).

## 13. STRIDE delta vs MAD-Council kit

| Category | Clawpilot exposes | Mitigation |
|---|---|---|
| Spoofing | OS-level deep-link protocol can be spoofed by another app on same OS | Cert pinning + WAM-bound tenant filtering |
| Tampering | Encrypted token cache via `@azure/msal-node-extensions` + `safe-storage-file.ts` | OS keychain |
| Repudiation | Append-only `audit-log.ts` | Immutable append |
| Info Disclosure | MIP sensitivity labels integrated; sensitivity-elevation.ts | Pre-elevation consent prompt |
| DoS | No explicit rate-limiting in scanned files (HIGH-confidence gap to dig into in P2) | (gap) |
| Elevation | 3-tier permission engine with explicit fail-closed for scheduled automations | Pattern guardrails |

Confidence: MEDIUM for "no rate limiting" claim (HIGH-confidence files scanned, no rate limiter found in `electron/` top-level naming, but `with-timeout.ts` exists in `ipc/` — not full rate limiter).

## 14. Notable architectural patterns to consider porting

1. **`ipc-contract.ts` as single source of truth** — every IPC handler signature, every event payload, every namespace API in one file. Extract this pattern verbatim.
2. **Typed `ipcHandle()` wrapper** — automatic E2E stub routing
3. **Backend abstraction with 5 invariants enforced by oxlint `no-restricted-imports`** — port the rule, port the lint enforcement
4. **`turn-accumulator.ts` enriches raw SDK events** — renderer never sees raw events, only `TurnEvent`
5. **`Sessions persistence with index + per-session files` partitioned by `backendOrigin`** — survives both backends, never clobbers
6. **3-tier permission engine with shell-syntax parsing** — reusable for any tool-call gating
7. **WAM-first → MSAL fallback** for M365 tokens, with explicit silent-failure handling
8. **MIP sensitivity-label integration** at the `sensitivity-elevation.ts` boundary (pre-prompt-on-confidential-content)
9. **Mock backend (`mock-mode.ts`, `mock-copilot-client.ts`, `mock-session.ts`)** — lets E2E tests run without real Copilot SDK
10. **Sidecar `node-runner.exe` for cross-platform MCP spawning** — addresses Windows console-window flash
11. **Append-only `audit-log.ts`**
12. **Cert pinning (`cert-pins.ts`)** for outbound calls

Confidence: HIGH for items 1-11 (file paths exist); MEDIUM for "port verbatim" recommendation (we should evaluate fit per item — some are LENS-specific anti-patterns).

## 15. Findings explicitly marked "no findings"

- **No `package.json:scripts:lint:fix`** — repo uses `oxlint --deny-warnings` only; fixes happen via `oxfmt`. No linter auto-fix mode.
- **No `cosmos-db` / `sqlite` / `pg` deps** — Clawpilot is fully filesystem-backed for sessions; no embedded database.
- **No `worker_threads` direct use** in main `package.json` — concurrency is achieved via Electron child processes + sidecar.
- **No `langchain` / `langgraph`** — Clawpilot wraps Copilot SDK directly, no LLM abstraction layer.

Confidence: HIGH (grep on `package.json`).

---

**Lane C topic 1/6 complete.** Next: features inventory.
