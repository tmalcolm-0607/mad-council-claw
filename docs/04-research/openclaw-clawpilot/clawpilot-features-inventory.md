---
title: Clawpilot features inventory
wave: wave-001
lane: lane-c
topic: 2/6
source-tag: "[CP:m-main]"
generated-by: lane-c-research
generated-by-version: 0.1.0
date: 2026-05-06
status: preview
---

# Clawpilot features inventory

> Walk of `src/features/`, `electron/`, top-level files, recent 100 commits. Enumerate every distinct user-facing or operator-facing feature surface. No Top-N capping.

## 1. Chat / sessions

| Feature | Surface | Confidence |
|---|---|---|
| Multi-session list with persistence | `electron/sessions.ts` (3,292 LOC); `~/.copilot/m-sessions/sessions-index.json` ordered list + `~/.copilot/m-sessions/{id}.json` per-session | HIGH |
| Session search | `electron/session-search.ts` + `electron/session-store.ts` | HIGH |
| Session de-duplication | `electron/sessions.ts` + `electron/sessions-dedup.test.ts` | HIGH |
| Empty-session find-and-reuse | `findAndReuseEmpty` referenced in CLAUDE.md backend rules | HIGH |
| Optimistic file-name preservation during refetch | Recent fix `aecbaf82` "skip session refetch during send to preserve optimistic fileNames" | HIGH |
| Multi-message turn accumulation | `electron/turn-accumulator.ts` aggregates raw SDK events into typed `TurnEvent`s; renderer subscribes to `TurnEvent`s only | HIGH |
| Drafts | `src/features/chat/state/sessionDrafts.ts` | HIGH |
| Permission cards in chat | `src/features/chat/stores/permission-cards-store.ts` + `PermissionCard.tsx` (with telemetry test) | HIGH |
| Inline questions in chat | `src/features/chat/components/InlineQuestion.tsx` | HIGH |
| Live trailing dots | `src/features/chat/components/LiveTrailing.tsx` | HIGH |
| Welcome state | `src/features/chat/components/WelcomeState.tsx` (+ telemetry test) | HIGH |
| Status events during silent recovery | Fix `4b3285ff` — emit status events during silent recovery to prevent frozen-chat UX | HIGH |

## 2. Model picker + personality

| Feature | Surface | Confidence |
|---|---|---|
| Default model picker | `src/features/settings/DefaultModelPicker.tsx` (+ telemetry test) + `electron/ipc/models-ipc.ts` + `electron/model-manager.ts` | HIGH |
| Per-session model override | `src/features/chat/components/ModelPicker.tsx` | HIGH |
| Personality picker | `src/features/chat/components/PersonalityPicker.tsx` + `electron/ipc/personality-ipc.ts` | HIGH |
| System message customization | `electron/system-message.ts` | HIGH |

## 3. MCP wiring

| Feature | Surface | Confidence |
|---|---|---|
| MCP server registry | `electron/mcp-store.ts` + `electron/ipc/mcp-ipc.ts` + UI at `src/features/extensions/McpServersTab.tsx` | HIGH |
| Add MCP dialog | `src/features/extensions/AddMcpDialog.tsx` | HIGH |
| MCP OAuth | `electron/ipc/mcp-oauth-ipc.ts` (separate IPC namespace for OAuth flows) | HIGH |
| Encrypted MCP credential store | `electron/mcp-crypto.ts` | HIGH |
| MCP disabled fallback | `electron/mcp-disabled.ts` | HIGH |
| MCP URL validation | `common/mcp-url-validation.ts` (test confirms structured validation) | HIGH |
| Bundled filesystem MCP | `bundled-mcp/filesystem-server.mjs` shipped in-process | HIGH |
| Playwright MCP | `@playwright/mcp ~0.0.68` external package | HIGH |
| WorkIQ MCP / SDK | `@microsoft/workiq ^0.4.1` external package | HIGH |
| Tool registry / tool description format | `common/tool-registry.ts` + `common/format-tool-description.ts` | HIGH |
| Tool discovery | `electron/tool-discovery.ts` | HIGH |
| Cross-platform MCP spawning | `sidecar/node-runner.exe` on Windows + `/usr/bin/env` on macOS/Linux | HIGH |

## 4. Skills

| Feature | Surface | Confidence |
|---|---|---|
| Skills loader + sanitization | `electron/skills.ts` (766 LOC) + `common/skill-sanitization.ts` (with test) | HIGH |
| Bundled skills (8) | `bundled-skills/`: ai-investigator, docx, excalidraw, expense-report, loop, pptx, web-artifacts-builder, xlsx | HIGH |
| First-party-skills overrides | `first-party-skills/` (5 of the 8 have first-party overrides) | HIGH |
| Repo-local review skills (7) | `skills/`: codebase-health, derive-rules, m-code-review, m-pr-ops, m-release-notes, m-review-dashboard, publish-pr | HIGH |
| Workspace skills (`.github/skills/{name}/SKILL.md`) | Per CLAUDE.md skills section | HIGH |
| Global skills (`~/.copilot/skills/{name}/SKILL.md`) | Per CLAUDE.md skills section | HIGH |
| Add Skill dialog | `src/features/extensions/AddSkillDialog.tsx` (with telemetry test) | HIGH |
| Skills tab UI | `src/features/extensions/SkillsTab.tsx` (with telemetry test) | HIGH |
| Skill slash menu | `src/features/chat/components/SkillSlashMenu.tsx` | HIGH |
| Bundled-version tracking | `electron/zip-manifest.test.ts` exists for bundle-import; `electron/github-bundle.ts` for import flow; `electron/github-bundle-import.test.ts` | HIGH |
| AI investigator first-party skill | `electron/ai-investigator/` (4 files) + `src/features/ai-investigator/` + `electron/ipc/ai-investigator-ipc.ts` | HIGH |

## 5. 3-tier permissions

| Feature | Surface | Confidence |
|---|---|---|
| Permission policy engine | `electron/permission-policy.ts` (1,331 LOC) + integration test | HIGH |
| Permission card manager (UI dispatch) | `electron/permission-card-manager.ts` | HIGH |
| Permission classifier | `electron/permission-classifier.ts` + `permission-classifier-types.ts` | HIGH |
| Permission patterns library | `electron/permission-patterns.ts` (test) | HIGH |
| Pattern guardrails | `electron/permission-pattern-guardrails.ts` (test) | HIGH |
| Shell syntax parsing | `electron/permission-shell-syntax.ts` | HIGH |
| Permissions persistence | `electron/permissions.ts` (test) + `electron/permissions-calendar.ts` (calendar-aware permissions) | HIGH |
| Permissions UI | `src/features/permissions/PermissionsPanel.tsx`, `PermissionsEditor.tsx`, `PermissionsSummary.tsx`, `ShellPatternsSection.tsx`, `ToolGroupSection.tsx`, `useToolRegistry.ts`, `permissions-format.ts` | HIGH |
| EditPermissionsDialog | `src/features/settings/EditPermissionsDialog.tsx` | HIGH |
| Permission settings section | `src/features/settings/Sections/PermissionsSection.tsx` (+ telemetry test) | HIGH |
| Copilot SDK 0.3.0 scoped permission model | Commit `0e9b77fa` (recent migration) | HIGH |
| Fail-closed for scheduled automations | Commit `fa3d9d6e` "classify all custom tools + fail-closed for scheduled automations" | HIGH |
| Sensitivity-aware elevation | `electron/sensitivity-elevation.ts` | HIGH |
| Approval broker | `electron/approval-broker.ts` | HIGH |
| Copilot approval adapter | `electron/copilot-approval-adapter.ts` | HIGH |

## 6. Automations (cron / condition / multi-step)

| Feature | Surface | Confidence |
|---|---|---|
| Automation manager | `electron/automations/manager.ts` (test) | HIGH |
| Schedule (cron) | `electron/automations/schedule.ts` (test) | HIGH |
| Condition monitor | `electron/automations/condition-monitor.ts` (test) | HIGH |
| Triggering | `electron/automations/triggering.ts` (test) | HIGH |
| Automation store | `electron/automations/store.ts` (test) | HIGH |
| Zod schemas for automations | `electron/automations/schemas.ts` (test) — types derived from Zod per refactor `d8056042` | HIGH |
| Automation types | `electron/automations/types.ts` | HIGH |
| Top-level automation glue | `electron/automations.ts` | HIGH |
| Automation IPC | `electron/ipc/automations-ipc.ts` + `electron/ipc/automations-desktop-ipc.ts` (separate desktop ops) | HIGH |
| Automation UI | `src/features/automations/`: AutomationsPanel, AutomationListView (+ telemetry), AutomationFormView, AutomationHistoryView, AutomationDeleteDialog, AutomationOverflowMenu, GithubImportView, automation-form-state | HIGH |
| GitHub bundle import | `electron/github-bundle.ts` + `electron/github-bundle-import.test.ts` + `electron/github-token.ts` + `electron/github-api-errors.ts` | HIGH |
| Heartbeat-on-demand per automation | `AutomationCapabilities.heartbeatRunNow` flag in IPC contract | HIGH |
| Per-automation permissions | `AutomationCapabilities.perAutomationPermissions` flag | HIGH |
| Bundle import dialog | `src/features/extensions/ImportDialog.tsx` (test) + `parseCatalogContent.ts` | HIGH |

## 7. Settings + persistence

| Feature | Surface | Confidence |
|---|---|---|
| Settings store | `electron/settings-store.ts` (test) + `electron/settings-manager.ts` | HIGH |
| Settings migration | `electron/settings-migration.test.ts` (covers cross-version migration) | HIGH |
| Settings panel | `src/features/settings/SettingsPanel.tsx` + 8 sections | HIGH |
| Settings sections | `src/features/settings/Sections/`: AboutSection, AppearanceSection, MemorySection, PermissionsSection, PowerManagementSection, PrivacySection, SessionRetentionSection, WindowBehaviorSection | HIGH |
| Default settings | `common/default-settings.ts` | HIGH |
| Workspace dir setting (override default) | Commit `b0293ec0` "add workspaceDir setting to override default workspace folder" | HIGH |
| Workspace dir fallback | Recent fix `2e47d360` "workspace dir fallback when Documents is inaccessible" | HIGH |
| Diagnostics section | `src/features/settings/DiagnosticsSection.tsx` + `electron/ipc/diagnostics-ipc.ts` + `electron/diagnostic-logger.ts` | HIGH |
| Workspace store | `electron/workspace-store.ts` + `electron/ipc/workspace-ipc.ts` | HIGH |
| Preferences IPC | `electron/ipc/preferences-ipc.ts` | HIGH |
| Tenant IPC | `electron/ipc/tenant-ipc.ts` + `electron/tenant-policy.ts` | HIGH |

## 8. MSAL/WAM auth + auth screen

| Feature | Surface | Confidence |
|---|---|---|
| MSAL provider | `electron/auth/msal-provider.ts` (test) | HIGH |
| Deep-link loopback (`ms-clawpilot://auth/callback`) | `electron/auth/deep-link-loopback.ts` (test) | HIGH |
| WAM (Windows broker) | `electron/m365-token-wam.ts` + expiry handling + gate | HIGH |
| WAM gate (org-only tenant filter on macOS broker) | `electron/m365-token-wam-gate.ts` + recent fix `89be5fa5` | HIGH |
| M365 token entry | `electron/m365-token.ts` (WAM-first on Windows, MSAL fallback) | HIGH |
| Auth state cache | `src/features/auth/cache.ts` | HIGH |
| Auth stage derivation | `src/features/auth/deriveStage.ts` | HIGH |
| Auth flow hook | `src/features/auth/useAuthFlow.ts` | HIGH |
| GitHub auth hook | `src/features/auth/useGitHubAuth.ts` | HIGH |
| M365 auth hook | `src/features/auth/useM365Auth.ts` | HIGH |
| Telemetry tenant ID hook | `src/features/auth/useTelemetryTenantId.ts` | HIGH |
| Telemetry user ID hook | `src/features/auth/useTelemetryUserId.ts` | HIGH |
| Auth screen | `src/features/auth/AuthScreen.tsx` (+ telemetry test) | HIGH |
| Auth error banner | `src/features/auth/AuthErrorBanner.tsx` | HIGH |
| Auth stages (10 cards) | `src/features/auth/stages/`: AuthCardShell, AuthCheckingCard, ConnectGitHubCard, ConnectM365Card, CopilotAccessRequiredCard, GitHubDeviceCodeCard, M365AccessDeniedCard, M365SigningInCard, SignInStartCard, TermsFooter | HIGH |
| Gateway auth (AAD via web relay) | `electron/backend/gateway/auth-controller.ts` + `electron/auth/gateway-auth-store.ts` + `src/features/auth/gateway/` (5 components) | HIGH |
| OpenClaw device pairing | `src/features/auth/gateway/PairingDialog.tsx` + commit `8c39a277` "Gateway: AAD sign-in via MSAL + OpenClaw device pairing flow" | HIGH |
| Fake JWT form (dev/test) | `src/features/auth/gateway/FakeJwtForm.tsx` | HIGH |
| Sessions auth-emit harness | `electron/sessions-auth-emit.test.ts` | HIGH |
| Auth errors common module | `common/auth-errors.ts` | HIGH |

## 9. Marketplace + extensions

| Feature | Surface | Confidence |
|---|---|---|
| Extensions panel | `src/features/extensions/ExtensionsPanel.tsx` (+ test) | HIGH |
| Extensions card | `src/features/extensions/ExtensionsCard.tsx` (+ test) | HIGH |
| Extensions detail dialog | `src/features/extensions/ExtensionsDetailDialog.tsx` (+ telemetry test) | HIGH |
| Skills tab | `src/features/extensions/SkillsTab.tsx` (+ telemetry test) | HIGH |
| MCP servers tab | `src/features/extensions/McpServersTab.tsx` (+ telemetry test) | HIGH |
| Catalog parsing | `src/features/extensions/parseCatalogContent.ts` (+ test) | HIGH |
| Horizontal carousel | `src/features/extensions/HorizontalCarousel.tsx` | HIGH |
| Import dialog | `src/features/extensions/ImportDialog.tsx` (+ test) + `electron/ipc/import-conflict-dialog.ts` | HIGH |
| Add MCP / Add Skill dialogs | `AddMcpDialog.tsx` + `AddSkillDialog.tsx` (above) | HIGH |
| Extensions actions hook | `src/features/extensions/useExtensionsActions.ts` | HIGH |
| Extensions data hook | `src/features/extensions/useExtensionsData.ts` | HIGH |
| Extensions catalog | `common/extensions-catalog/` | HIGH |
| Extensions IPC | `electron/ipc/extensions-ipc.ts` (+ test) | HIGH |

> No first-party storage backend (no Azure Storage account discovered in `package.json`); marketplace fetches likely use the Copilot SDK directly. **MEDIUM-confidence finding** — to investigate in P1 if marketplace surface is in scope.

## 10. 1JS telemetry / Hugin

| Feature | Surface | Confidence |
|---|---|---|
| 1DS / Hugin telemetry | `@1js/diagnostics 1.2.135` + `@1js/hugin-schema 3.2.79` + `@1js/hugin-shared-middleware 2.2.118` + `@1js/hugin-sink-1ds 1.1.137` + `@1js/hugin-sink-console 1.1.139` + `@1js/midgard-error 7.2.136` + `@1js/px-telemetry 22.16.36` | HIGH |
| 1JS auth helper script | `pnpm auth:1js` (refreshes midgard feed credentials in `~/.npmrc`) | HIGH |
| Telemetry directory | `common/telemetry/` | HIGH |
| Telemetry tenant + user ID hooks | `src/features/auth/useTelemetryTenantId.ts` + `useTelemetryUserId.ts` | HIGH |
| Telemetry errors | `electron/telemetry-errors.ts` (test) | HIGH |
| CPU architecture telemetry | Recent feature `b42212ba` "add CPU architecture to 1DS telemetry" | HIGH |
| Per-feature telemetry tests | `*.telemetry.test.tsx` exist for: AutomationListView, AuthScreen, ChatInput, ChatMessage, DefaultModelPicker, ExtensionsDetailDialog, HorizonPanel, IntegrationsPanel, McpServersTab, PermissionCard, PermissionsSection, SkillsTab, WelcomeState | HIGH |

## 11. electron-builder packaging + auto-update

| Feature | Surface | Confidence |
|---|---|---|
| Builder config | `electron-builder.json5` | HIGH |
| Patches dir (post-install patches) | `patches/` | HIGH |
| Build orchestration | `scripts/build-release.cjs` | HIGH |
| Bundled MCP build | `pnpm build:mcp` (`scripts/bundle-mcp-filesystem.mjs`) | HIGH |
| Skills install script | `pnpm install:skills` (`scripts/install-skills.mjs`) | HIGH |
| Bundled skills initialization | `scripts/initialize-bundled-skills.mjs` | HIGH |
| Beta + stable release channels | Feature `71478871` "beta + stable release channels" | HIGH |
| Cut beta script | `pnpm release:cut-beta` (`scripts/release/cut-beta.mjs`) | HIGH |
| Promote-to-stable script | `pnpm release:promote` (`scripts/release/promote-to-stable.mjs`) | HIGH |
| Verify /releases/latest after promotion | Fix `5bcfef47` | HIGH |
| `make_latest=true` on stable promotion | Fix `11b57d62` | HIGH |
| Updater IPC | `electron/ipc/update-ipc.ts` (+ test) + `electron/updater.ts` (+ test) | HIGH |
| Update progress | `electron/update-progress.ts` (+ test) | HIGH |
| Minimum-version floor | `minimum-version.json` | HIGH |
| Mini-mode (compact UI) | `electron/mini-mode.ts` + `electron/mini-mode/` (5 files) + `electron/mini-mode-page/` (HTML/CSS/JS) + `src/features/mini-mode/` (settings) | HIGH |
| Mini-mode settings | `common/mini-mode-settings.ts` | HIGH |

## 12. Compliance / MIP / enterprise

| Feature | Surface | Confidence |
|---|---|---|
| MIP sensitivity labels | `electron/m365/sensitivity-labels.ts` (+ test) + `electron/m365/mip-labels.integration.test.ts` + commit `c07f77d0` "mip-labels" merge | HIGH |
| Sensitivity-aware elevation | `electron/sensitivity-elevation.ts` (+ test) | HIGH |
| Sensitivity badge UI | `src/features/chat/components/SensitivityBadge.tsx` | HIGH |
| Group Policy ADMX template | `enterprise/clawpilot.admx` + `enterprise/en-US/` | HIGH |
| Append-only audit log | `electron/audit-log.ts` (+ test) | HIGH |
| TLS cert pinning | `electron/cert-pins.ts` (+ test) | HIGH |
| OS keychain encryption wrapper | `electron/safe-storage-file.ts` (+ test) | HIGH |
| Tenant filtering policy | `electron/tenant-policy.ts` (+ test) | HIGH |
| Email masking utility | `electron/mask-email.ts` (+ test) | HIGH |
| Untrusted-content wrapper | `electron/untrusted-wrap.ts` (+ test) | HIGH |
| Sanitization | `electron/sanitize.ts` (+ test) + `common/skill-sanitization.ts` | HIGH |

## 13. Loki + Memora (recent integration — recent commits)

| Feature | Surface | Confidence |
|---|---|---|
| Loki client | `electron/loki/client.ts` (+ test) | HIGH |
| Loki experiments migration | `electron/loki/experiments-migration.ts` (+ test) | HIGH |
| Loki IPC | `electron/loki/ipc.ts` (+ test) | HIGH |
| Loki shared types | `electron/loki/shared.ts` | HIGH |
| Memora client (vector memory) | `electron/memora/client.ts` (+ test) | HIGH |
| Memora memory store | `electron/memora/memory-store.ts` (+ test) | HIGH |
| Shadowing memora store (legacy → vector migration shim) | `electron/shadowing-memora-store.ts` (+ test) | HIGH |
| Loki Memora experiment introduction | Commit `71d515fa` "Introducing Loki Memora under an experiment" | HIGH |
| Legacy memory store | `electron/legacy-memory-store.ts` (+ test) | HIGH |
| Memory IPC | `electron/ipc/memory-ipc.ts` | HIGH |
| Memory section UI | `src/features/settings/Sections/MemorySection.tsx` + `src/features/memories/MemoriesPanel.tsx` (+ test) | HIGH |
| Memory category schema | `MemoryCategory = "preference" \| "fact" \| "decision" \| "context"` per `common/ipc-contract.ts:38` | HIGH |
| Memory settings | `MemorySettings { maxMemories, decayDays }` per `common/ipc-contract.ts:48` | HIGH |

## 14. Horizon / Daily Brief / Project Workspace

| Feature | Surface | Confidence |
|---|---|---|
| Horizon engine | `electron/horizon.ts` + `electron/horizon-formatter.ts` (+ tests) | HIGH |
| Horizon IPC (3 namespaces) | `electron/ipc/horizon-ipc.ts` (base) + `horizon-ipc-email.ts` + `horizon-ipc-teams.ts` (test) | HIGH |
| Horizon panel | `src/features/horizon/HorizonPanel.tsx` (+ telemetry test + general test) | HIGH |
| Brief button | `src/features/horizon/BriefButton.tsx` (+ test) + `EmailBriefButton.tsx` + `SendBriefButton.tsx` | HIGH |
| Horizon action pane | `src/features/horizon/HorizonActionPane.tsx` (+ test) | HIGH |
| Prevent duplicate brief automations | Recent fix `71fcbec3` "horizon: prevent duplicate brief automations" | HIGH |

## 15. Teams / progress narrator / relay

| Feature | Surface | Confidence |
|---|---|---|
| Teams relay | `electron/teams-relay.ts` (+ test) + `electron/teams-relay-lifecycle.ts` (+ test) | HIGH |
| Teams relay IPC | `electron/ipc/teams-relay-ipc.ts` (+ test) | HIGH |
| Teams routing in sessions | `electron/sessions-teams-routing.test.ts` | HIGH |
| Teams relay status store (renderer) | `src/features/integrations/teamsRelayStatusStore.ts` (+ test) + `useTeamsRelayStatus.ts` + `useTeamsRelayNetworkChangeForwarder.ts` | HIGH |
| Progress narrator (long-running task pings) | `electron/teams/progress-narrator.ts` (+ test) + `progress-narrator-prompt.ts` + commit `0a8871db` docs | HIGH |
| Narrator over WebSocket | Recent fix `c8162b94` "route narrator updates over WS to share idle timer" | HIGH |
| Narrator fires every tick | Recent fix `4d3ff7d5` + `11f5dc29` (resolved suppression bugs) | HIGH |
| Lifecycle reconnect respects user intent | Recent fix `642d9441` | HIGH |
| Teams manifest | `teams-manifest/manifest.json` + `color.png` + `outline.png` + `README.md` | HIGH |
| M365 Teams tools | `electron/m365/teams-tools.ts` (+ test) + `teams-utils.ts` (+ test) | HIGH |

## 16. M365 (Graph integration surface)

| Feature | Surface | Confidence |
|---|---|---|
| Calendar tools | `electron/m365/calendar-tools.ts` (+ test) + `calendar-utils.ts` (+ test) | HIGH |
| Email tools | `electron/m365/email-tools.ts` (+ test) + `email-extended-tools.ts` (+ test) + `email-utils.ts` (+ test) | HIGH |
| Graph query helper | `electron/m365/graph-query.ts` (+ test) | HIGH |
| OneDrive tools | `electron/m365/onedrive-tools.ts` (+ test) | HIGH |
| Outlook timezone | `electron/m365/outlook-timezone.ts` (+ test) | HIGH |
| People tools + persona photo | `electron/m365/people-tools.ts` (+ test) + `persona-photo.ts` (+ test) | HIGH |
| Planner tools | `electron/m365/planner-tools.ts` | HIGH |
| Presence tools | `electron/m365/presence-tools.ts` | HIGH |
| Tasks tools | `electron/m365/tasks-tools.ts` | HIGH |
| Meetings tools | `electron/m365/meetings-tools.ts` | HIGH |
| Teams tools (above) | (link) | HIGH |
| MIP labels (above) | (link) | HIGH |
| M365 integration tests | `electron/m365/m365-tools.integration.test.ts` + dedicated `pnpm test:m365` runner | HIGH |
| Test helpers for M365 | `electron/m365/test-helpers/` | HIGH |

## 17. Power management / system

| Feature | Surface | Confidence |
|---|---|---|
| Keep awake | `electron/keep-awake.ts` (+ test) + `electron/apply-keep-awake-settings.ts` (+ test) + `PowerManagementSection.tsx` | HIGH |
| Power module | `electron/power.ts` (+ test) | HIGH |
| Tray | `electron/tray.ts` (+ test) | HIGH |
| Show/hide global shortcut | `electron/show-hide-shortcut.ts` (+ test) | HIGH |
| Notifications | `electron/notifications.ts` + `electron/notification-router.ts` (+ test) | HIGH |
| Native window controls IPC | `electron/ipc/window-controls-ipc.ts` (+ test) | HIGH |
| Main window controller | `electron/main-window-controller.ts` (+ test) | HIGH |
| Mini-mode (above) | (link) | HIGH |
| Heartbeat (per-session liveness) | `electron/heartbeat.ts` (+ test) + `electron/background-service.ts` (+ test) + `electron/ipc/heartbeat-ipc.ts` (+ test) + `src/features/heartbeat/` | HIGH |

## 18. AI Investigator (deep-investigation skill)

| Feature | Surface | Confidence |
|---|---|---|
| AI investigator manager | `electron/ai-investigator/ai-investigator-manager.ts` (+ test) | HIGH |
| Payload assembly | `electron/ai-investigator/ai-investigator-payload.ts` (+ test) | HIGH |
| IPC | `electron/ipc/ai-investigator-ipc.ts` (+ test) | HIGH |
| UI surface | `src/features/ai-investigator/` | HIGH |
| Bundled skill body | `bundled-skills/ai-investigator/` | HIGH |
| Identity composer (used by ai-investigator) | `electron/identity/identity-composer.ts` (+ test) + `electron/ipc/identity-ipc.ts` | HIGH |

## 19. Other surfaces (less obvious)

| Feature | Surface | Confidence |
|---|---|---|
| Diagnostic export | `electron/ipc/diagnostics-ipc.ts` (+ test) + `electron/diagnostic-logger.ts` (+ test) | HIGH |
| File export | `electron/ipc/file-export-ipc.ts` (+ test) | HIGH |
| Activities IPC + UI | `electron/ipc/activities-ipc.ts` (+ test) + `src/features/activities/` (likely Agent execution timeline + replay scrubber surface) | HIGH |
| App-level events | `electron/ipc/app-ipc.ts` | HIGH |
| Backend conformance | `electron/backend/conformance.test.ts` (every backend must pass conformance) | HIGH |
| Backend factory | `electron/backend/create-backend.ts` | HIGH |
| Backend ports | `electron/backend/ports.ts` | HIGH |
| Mock backend | `electron/mock-mode.ts` + `electron/mock-copilot-client.ts` + `electron/mock-session.ts` | HIGH |
| Mock scenarios common | `common/mock-scenarios.ts` | HIGH |
| Permission servers (preset configurations) | `common/permission-servers.ts` (+ test) | HIGH |
| Quick title (auto-name session) | `common/quick-title.ts` (+ test) | HIGH |
| Logger | `common/logger.ts` (+ test) | HIGH |
| Error format | `common/error-format.ts` (+ test) + `electron/error-formatting.ts` (+ test) | HIGH |
| Context picker utils + components | `common/context-picker-utils.ts` + `src/features/chat/components/context-picker/` + `electron/ipc/context-picker/` | HIGH |
| Activities screen + activity events | `src/features/activities/` | HIGH (subdir present) |
| PeopleIQ panel | `src/features/peopleiq/PeopleIqPanel.tsx` | HIGH |
| Integrations panel + M365 status card | `src/features/integrations/IntegrationsPanel.tsx` + `M365StatusCard.tsx` | HIGH |
| Image utilities (multimodal — screenshot) | `electron/image-utils.ts` (+ test) + `electron/screen-capture.ts` | HIGH |
| HTML utilities | `electron/html-utils.ts` (+ test) | HIGH |
| Markdown utilities | `electron/markdown-utils.ts` | HIGH |
| YAML utilities (skills frontmatter) | `electron/yaml-utils.ts` (+ test) | HIGH |
| Browser detect / open external | `electron/browser-detect.ts` (+ test) + `electron/open-external.ts` (+ test) | HIGH |
| Theme (light/dark + flash prevention) | `electron/theme.ts` + `electron/theme-flash-prevention.test.ts` | HIGH |
| Timezone utils | `electron/timezone-utils.test.ts` | HIGH |
| Self-tools (Clawpilot self-introspection) | `electron/self-tools.ts` (+ test) | HIGH |
| Background service | `electron/background-service.ts` (+ test) | HIGH |
| Busy tracker | `electron/busy-tracker.ts` (+ test) | HIGH |
| Capture preload (multimodal capture in renderer) | `electron/capture-preload.cjs` | HIGH |
| Net fetch wrapper | `electron/net-fetch.ts` | HIGH |
| Avatar | `electron/avatar.ts` | HIGH |
| Personality IPC (above) | (link) | HIGH |
| Sessions login lifecycle | `electron/sessions-login.test.ts` | HIGH |
| Sessions roundtrip | `electron/sessions-roundtrip.test.ts` | HIGH |
| Sessions incoming/outgoing | `electron/sessions-incoming.test.ts` + `electron/sessions-outgoing.test.ts` | HIGH |
| Settings panel `useSettings` hook | `src/features/settings/useSettings.ts` + `useDefaultWorkspaceDir.ts` | HIGH |
| GitHub bundle import telemetry path | `electron/github-bundle.ts` + `electron/github-bundle-import.test.ts` + `electron/github-token.ts` | HIGH |
| Shell IPC (with permissions) | `electron/ipc/shell-ipc.ts` (+ test) | HIGH |
| Shell timeout default raised 60s→120s | Recent fix `49fecdbe` | HIGH |
| `with-timeout` IPC helper | `electron/ipc/with-timeout.ts` | HIGH |
| IPC limits (size caps) | `electron/ipc/ipc-limits.ts` (+ test) | HIGH |
| `useIpcMutation` shared helper | Refactor `f141b665` "adopt useMutation via shared useIpcMutation helper" | HIGH |
| Approval broker | `electron/approval-broker.ts` (+ test) | HIGH |
| Schema validation | `electron/schemas/session-schema.ts` (Zod) + `common/skill-sanitization.ts` (Zod) + automation Zod schemas | HIGH |
| Heartbeat in renderer | `src/features/heartbeat/` | HIGH |
| Consent UI | `src/features/consent/` | HIGH (subdir present) |
| Create panel | `src/features/create/` | HIGH (subdir present, contents not enumerated this lane) |

## 20. Recent commit themes (top 100)

Grouped from `git log --oneline -100`:

| Theme | Example commits | Count (approx) |
|---|---|---|
| Permissions / SDK 0.3.0 migration / fail-closed scheduled automations | `0e9b77fa`, `fa3d9d6e` | 2-3 |
| Loki Memora experiment introduction | `71d515fa` | 1 |
| MIP labels merge | `c07f77d0`, `9f1a07bf` | 2 |
| macOS broker / WAM tenant filter | `89be5fa5`, `9f7989a4`, `d6b15b21` | 3 |
| Gateway: AAD MSAL + OpenClaw device pairing | `8c39a277` | 1 |
| Beta + stable release channels | `71478871` | 1 |
| Promote-to-stable + /releases/latest verification | `b167e3a2`, `5bcfef47`, `11b57d62`, `b1afd9b0`, `35a0c711` | 5 |
| Teams relay narrator (multi-fix saga) | `cf64e36c`, `2604969f`, `c8162b94`, `4d3ff7d5`, `11f5dc29` | 5 |
| Teams relay lifecycle reconnect | `fb37957b`, `642d9441`, `d01139ae`, `d30b7da5`, `8f0157f4` | 5 |
| Heartbeat (PR #1599) review iterations | `9fae207d`, `aab3eeda`, `3cd25393` | 3 |
| Sessions: status events during silent recovery | `4b3285ff` | 1 |
| Sessions: skip refetch during send (preserve optimistic file names) | `aecbaf82` | 1 |
| Workspace dir setting + fallback | `b0293ec0`, `2e47d360` | 2 |
| useIpcMutation refactor across panels | `f141b665`, `71d71bea`, `0d5bd820`, `8078b9c0`, `ba6df6b6` | 5 |
| Automation form refactor + Zod typing | `9f42a65b`, `d8056042`, `bdba6d47`, `e9f05481`, `ce1853dc`, `f2185da0`, `64c88bc4`, `09bf3674`, `d090253f` | 9 |
| AI investigator review feedback | `9d8cdaa3`, `38f63b22` | 2 |
| Cocreate Zoom support | `c32a2b60` | 1 |
| Horizon: prevent duplicate brief automations | `71fcbec3` | 1 |
| Shell timeout 60→120s | `49fecdbe` | 1 |
| CPU arch telemetry | `b42212ba`, `3c977de8`, `671409a7`, `8e2cdf5b` | 4 |
| Skill rename (release-notes → m-release-notes) | `2d1b0d08`, `b27fc90e` | 2 |
| Repo lint fixes / chore template | `b94a4d33` | 1 |
| Dashboard filter (failing CI hidden) | `32317c74`, `cb707036`, `4d3ff7d5`, `b59f511c`, `0352b53f` | 5 |
| Send-message session-clear-error fix | `e74f934d` | 1 |
| Launch-review terminal app probe | `ff04db16` | 1 |
| Mini-mode (recent) | (no recent commits in top 100; mature surface) | 0 in window |
| Telemetry tenant ID hook | (no recent) | 0 in window |

## 21. Findings explicitly marked "no findings"

- **No first-party voice-input feature surface found** — multimodal "voice + screenshot-to-prompt" listed as a NEW v1 desire is NOT yet in clawpilot. Only `screen-capture.ts` exists for screenshots. Voice would be net-new.
- **No "encrypted local storage" surface beyond `safe-storage-file.ts`** — but `mcp-crypto.ts` does encrypt MCP credentials; expanding to full BYO-MCP-with-encrypted-store may need new work.
- **No "agent execution timeline + replay scrubber" surface explicitly named** — `src/features/activities/` likely covers timeline; "replay scrubber" is net-new.
- **No "project workspace" surface** beyond workspace-dir setting — Daily-briefing exists (Horizon); per-project workspace cluster is net-new.
- **No "cost ledger" surface** in Clawpilot — would be net-new for governance triad.
- **No "hash-audit" surface** for skills/MCPs at install time — would be net-new for governance triad.
- **No "halt" gesture beyond cancel** — would be net-new.

These map directly to the user's NEW-v1 list (multimodal voice, agent execution timeline + replay scrubber, daily briefing + project workspace, BYO MCP + encrypted local storage, governance triad).

---

**Lane C topic 2/6 complete.** Total surfaces enumerated: ~210 distinct features/files-as-features across 21 sections. Next: OpenClaw issue #43367.
