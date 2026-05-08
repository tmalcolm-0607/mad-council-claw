# Deployment Failure Diagnosis

> **First action when a deploy looks stuck, slow, or failed:**
> ```
> pwsh -NoProfile -File .claude/scripts/Diagnose-LensDcsDeploy.ps1 -Environment <env> -ReleaseRunId <id>
> ```
> Do NOT poll the pipeline. Do NOT infer from one ARM signal. The script is the canonical
> multi-source diagnostic. It returns one of: `DEPLOY_SUCCEEDED` (exit 0), `STILL_RUNNING`
> (exit 1), `STAGING_DEPLOYED_NO_SWAP` (exit 2), `ROLLOUT_FAILED` (exit 3), `UNKNOWN` (exit 4).
>
> If you find yourself running `az deployment group list` / `az pipelines runs show` / `az webapp config appsettings list` ad-hoc, you are repeating the iter12 + iter13 anti-pattern.
> The script combines all of those signals (plus deploymentScript container logs and BuildVersion comparison across slots) into a single verdict. **Use the script first.**

When an ADO release pipeline reports "succeeded" but the deployed environment doesn't
reflect the new build (App Service env vars unchanged, missing resources, BuildVersion
still showing the old value, etc.), **do NOT keep watching the pipeline**. Check the
ARM activity log directly. That is the source of truth for whether resources actually
deployed.

## Why a single signal is not enough

ADO pipeline orchestrator status (`inProgress` / `succeeded` / `failed`) is computed
asynchronously from the underlying Ev2 rollout state, with significant lag and well-known
hang patterns:

- **Pipeline `inProgress` while Ev2 has declared rollout `Failed`** — observed in iter12
  and iter13. The pipeline's Ev2 Monitoring task keeps polling but doesn't surface the
  failure for tens of minutes. ARM activity log + Ev2 portal show the truth long before
  the pipeline does.
- **Pipeline `succeeded` while ARM resources are unchanged** — Ev2 reports rollout
  submitted, not rollout completed. Resources may finish minutes later, fail silently,
  or be skipped due to RolloutSpec configuration.
- **Single ARM activity entry is incomplete** — observing one `Microsoft.Resources/deployments` event
  ("Running") does not tell you (a) what the wrapped operation is doing, (b) whether
  the deploymentScripts succeeded, (c) whether the App Service slot was swapped, or
  (d) whether the integration test ran.

The canonical fix is to **fetch every signal that bears on the deploy state** in one
pass and compute a verdict from the combined set, not from any one signal.

## What the diagnostic script always fetches

The script (`.claude/scripts/Diagnose-LensDcsDeploy.ps1`) fetches all of these for the
specified environment + release-run window:

| # | Signal | Why |
|---|---|---|
| 1 | ADO pipeline run state (`status`, `result`, `startTime`, `finishTime`) | Bounds the time window; reveals orchestrator-hang pattern |
| 2 | ARM deployment list per RG (filtered to `>= startTime`) | Real provisioningState per deployment definition |
| 3 | Failed deployment drilldown (operation list, error codes, target resources) | Identifies the specific resource that failed and why |
| 4 | deploymentScripts list per RG with provisioningState + outputs + endTime | Distinguishes "succeeded long ago" from "ran during this rollout" |
| 5 | deploymentScripts ACI container logs (`az deployment-scripts show-log`) | Actual stdout from the script (e.g. inttest test failures) |
| 6 | App Service BuildVersion: production + staging slots, BOTH regions | Definitive proof of whether code was promoted |
| 7 | Combined verdict (5 classes, exit codes 0-4) | Single answer, no inference required |

If any of those signal sources is missing, that's a Context Gap that the script reports
explicitly — never silently fills in by guessing.

## Verdict classes

| Verdict | Exit | Meaning |
|---|--:|---|
| `DEPLOY_SUCCEEDED` | 0 | Production BuildVersion === staging in all regions; integration test passed within window |
| `STILL_RUNNING` | 1 | Pipeline inProgress, no failures yet, swap not done — keep monitoring |
| `STAGING_DEPLOYED_NO_SWAP` | 2 | Pipeline finished but production != staging — swap was skipped or failed silently |
| `ROLLOUT_FAILED` | 3 | Ev2 reports failed (or ARM has failures + orchestrator hung) — requeue needed |
| `UNKNOWN` | 4 | Signal collection incomplete — script reports which step failed |

## Equivalent ad-hoc query (only when the script is unavailable)

```bash
# Single-RG variant; the canonical script does this for both regions plus 5 more signals.
MSYS_NO_PATHCONV=1 az deployment group list \
  --resource-group <rg> --subscription <sub> \
  --query "[?properties.timestamp >= '<ISO since>'].{name:name,state:properties.provisioningState,timestamp:properties.timestamp,error:properties.error.details[0]}" \
  -o json | jq '[.[] | select(.state=="Failed")]'
```

This ad-hoc query is what both Claude sessions on 2026-05-02 used in isolation. It only
captures signal #2 from the table above. Always prefer the script.

## Common verdicts and their remediation

### `ROLLOUT_FAILED` after AppService deploymentScript transient

Pattern (iter12 + iter13): `AppServiceResourceDefinition-w` fails with
`DeploymentScriptResourceConflict` or `DeploymentScriptOperationFailed` referencing an
ACI container UAMI. Ev2 may or may not retry; if `Retry Attempt: 0` after 15+ minutes,
treat as terminal and queue a fresh release run with the same parameters.

```bash
# Cancel the stalled release (cleanup only — Ev2 has already declared it failed)
az pipelines runs update --id <run-id> --status cancelling --org <org> --project <project>

# Queue a fresh release run with same parameters
az pipelines run --id 51817 --org https://o365exchange.visualstudio.com --project "O365 Core" \
  --branch <branch> --parameters environment=npe4 rolloutSpec=RolloutSpec.json
```

The 30-minute window between attempts is usually enough for the ACI/UAMI propagation to
clear. Both iter12 and iter13 hit the same transient class — see L29 in
`.claude/rules/lens-dcs-loop-lessons.md`.

### `STAGING_DEPLOYED_NO_SWAP`

Pattern: zipdeploy succeeded (staging slot has new BuildVersion) but the swap script
didn't run or didn't promote. Investigate the `swap-app-lensdcs-<env>-<region>-staging`
deploymentScript: read its container log to find the reason.

### `STILL_RUNNING`

The script ran in a window where the rollout was actively progressing. Re-run in 5-10
minutes. If the same verdict returns 3 times consecutively with no progress on the
ARM activity log, escalate to investigating Ev2 portal directly.

## Related rules and scripts

- `.claude/scripts/Diagnose-LensDcsDeploy.ps1` — the canonical diagnostic.
- `.claude/rules/deployment-scripts.md` — full deployment-script reference.
- `.claude/rules/quality-gates.md` — verify-actual-state pattern; same principle.
- `.claude/rules/lens-dcs-loop-lessons.md` L26 / L29 / L30 — recurring transient class
  + ARM-truth discipline + pipeline-orchestrator hang pattern.
- Memory: `feedback_no_speculation.md` ("Fix diagnostics access first, read actual logs,
  never guess root causes") — the App Insights variant of the same lesson.

## Anti-patterns

| Wrong | Right |
|---|---|
| Wait for the pipeline's Ev2 Monitoring stage to surface an error | Run `Diagnose-LensDcsDeploy.ps1` immediately |
| Re-trigger the deploy because "maybe it'll work this time" | Run the diagnostic; identify the specific failure; then make the requeue / fix decision with evidence |
| Trust "Rollout: succeeded" without verifying actual resource state | The script's `DEPLOY_SUCCEEDED` verdict requires production BuildVersion match + integration-test-passed-within-window; not just pipeline status |
| Cancel a stuck release without diagnosing | Diagnose first — the script tells you whether to cancel-and-requeue, wait, or investigate Ev2 directly |
| Run `az deployment group list` / `az pipelines runs show` / `az webapp config appsettings list` ad-hoc and try to correlate them by hand | The script does the correlation; the verdict is computed from all signals together. Skipping the script is how the same diagnostic mistake gets repeated across sessions. |
