---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-078
short-slug: auth-screen-initial
milestone: M9
provenance:
  surfaces:
    - cp:src/features/auth/AuthScreen.tsx
    - cp:src/features/auth/useM365Auth.ts
    - cp:src/features/auth/stages/AuthCardShell.tsx
    - cp:src/features/auth/stages/AuthCheckingCard.tsx
    - cp:src/features/auth/stages/ConnectM365Card.tsx
    - cp:src/features/auth/stages/M365SigningInCard.tsx
    - cp:src/features/auth/stages/M365AccessDeniedCard.tsx
    - cp:src/features/auth/stages/SignInStartCard.tsx
    - cp:src/features/auth/stages/CopilotAccessRequiredCard.tsx
    - cp:src/features/auth/stages/ConnectGitHubCard.tsx
    - cp:src/features/auth/stages/GitHubDeviceCodeCard.tsx
    - cp:src/features/auth/stages/TermsFooter.tsx
    - cp:AuthScreen.telemetry.test.tsx
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-078-auth-screen-initial-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-076, F-077]
out-of-scope-notes: |
  GitHub auth (ConnectGitHubCard, GitHubDeviceCodeCard) is part of the
  clawpilot stage-card pattern but is NOT in engine v1 scope — engine v1 is
  M365-only. The shell + telemetry pattern is reused; the GitHub-specific
  cards land in v1.5 if engine adds GitHub integrations.
  CopilotAccessRequiredCard depicts a clawpilot-specific Copilot license
  check; engine v1 reuses the card shell but the gating logic is M365-license-
  centric, not Copilot-centric.
confidence: high
---

# F-078 — Auth screen (initial launch)

## Behavior contract

On first launch (no cached tokens per F-079) the engine MUST present an auth screen modeled after clawpilot's stage-card pattern. The screen renders one of N state-driven cards based on the current auth phase: `AuthCheckingCard` (probing for cached tokens / WAM availability), `SignInStartCard` (user-initiated sign-in), `ConnectM365Card` (M365 connection prompt), `M365SigningInCard` (in-flight MSAL/WAM acquisition), `M365AccessDeniedCard` (failure state with retry). Each stage card emits per-stage telemetry (matching clawpilot's `AuthScreen.telemetry.test.tsx` pattern). The screen blocks engine usage until either a valid token is acquired (transitions to main shell) or the user explicitly cancels (engine remains in `opening` lifecycle without proceeding).

## Acceptance scenarios

1. **Given** a fresh install with no cached tokens, **When** the engine launches, **Then** the auth screen renders `AuthCheckingCard` first, transitions to `SignInStartCard` after the cache miss, and emits stage-transition telemetry per transition.
2. **Given** the user clicks "Sign in" on `SignInStartCard`, **When** MSAL (F-076) initiates the deep-link flow, **Then** the screen transitions to `M365SigningInCard` with a progress indicator, and on success transitions to the main shell.
3. **Given** the user's tenant is rejected by the WAM gate (F-077) AND MSAL also fails (e.g., conditional access blocks), **When** the failure is observed, **Then** the screen transitions to `M365AccessDeniedCard` with a retry affordance and emits a denial-stage telemetry event.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/auth/auth-screen-stage-transitions.test.tsx` | browser | RED | scenario 1 |
| (TBD) `tests/browser/auth/auth-screen-msal-success.test.tsx` | browser | RED | scenario 2 |
| (TBD) `tests/browser/auth/auth-screen-access-denied.test.tsx` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine lifecycle blocks at `opening` until auth completes), F-076 (MSAL flow drives most stages), F-077 (WAM availability check drives `AuthCheckingCard`)
- **Soft:** F-079 (token cache hit short-circuits the auth screen entirely on relaunch)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/auth/AuthScreen.tsx | top-level auth screen container; orchestrates stage transitions |
| cp:src/features/auth/useM365Auth.ts | hook that exposes auth state to the screen and stage cards |
| cp:src/features/auth/stages/AuthCardShell.tsx | shared shell layout (logo, title, footer) for all stage cards |
| cp:src/features/auth/stages/AuthCheckingCard.tsx | initial probe card (token cache + WAM availability) |
| cp:src/features/auth/stages/ConnectM365Card.tsx | M365 connection prompt |
| cp:src/features/auth/stages/M365SigningInCard.tsx | in-flight MSAL/WAM acquisition progress |
| cp:src/features/auth/stages/M365AccessDeniedCard.tsx | failure state with retry |
| cp:src/features/auth/stages/SignInStartCard.tsx | user-initiated sign-in entry point |
| cp:src/features/auth/stages/CopilotAccessRequiredCard.tsx | informs the gating-card pattern (engine v1 adapts for M365 license, not Copilot) |
| cp:src/features/auth/stages/ConnectGitHubCard.tsx | informs the multi-provider stage-card shell pattern (out of scope for v1 engine) |
| cp:src/features/auth/stages/GitHubDeviceCodeCard.tsx | informs device-code card pattern (out of scope for v1 engine) |
| cp:src/features/auth/stages/TermsFooter.tsx | terms-of-service footer pattern shared across cards |
| cp:AuthScreen.telemetry.test.tsx | per-stage telemetry test pattern to match |

## Implementation notes

(empty — populated when implementation begins)
