---
paths:
  - "**/*.yml"
  - "**/*.yaml"
  - ".azure-pipelines/**"
  - "**/deploy/**"
  - "**/*.csproj"
---

> **Kit-policy supplement; canonical LENS does not prescribe.** This file documents kit-internal conventions and operational guidance. The canonical LENS standards live in the `lens-aspnet-structure`, `lens-telemetry`, `lens-pipeline-audit`, and `lens-standards-audit` skills.

# Azure DevOps Workflow Patterns

Standards for ADO workflows: branch policies, PR workflows, pipeline management.

## Branch Naming

Many ADO repos have policies blocking `feature/` or `bugfix/` prefixes. Use `users/<alias>/` pattern.

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `users/<alias>/<name>` | `users/tonym/add-health-endpoint` |
| Bug fix | `users/<alias>/fix-<desc>` | `users/tonym/fix-null-reference` |
| Experiment | `users/<alias>/exp-<desc>` | `users/tonym/exp-cosmos-integration` |

---

## Draft PR Creation

```bash
az repos pr create --draft \
  --title "feat: add stub controllers" \
  --source-branch users/tonym/feature \
  --target-branch main \
  --repository REPO-NAME \
  --organization https://dev.azure.com/ORG \
  --project "PROJECT"
```

---

## Pipeline Types

| Pattern | Purpose | Production Ready |
|---------|---------|------------------|
| `Precheckin_*` | PR validation | No |
| `Official (yaml)` | Official build | Yes |
| `*-Release` | Azure-style deployment | Yes |

**Note**: Precheckin pipelines skip ProductionReadinessCheck for speed. Use Official for deployable artifacts.

---

## Build Commands

```bash
# Queue build
az pipelines run --id PIPELINE_ID --branch users/tonym/feature

# Check status
az pipelines runs show --id BUILD_ID --query "{status:status,result:result}"

# List pipelines
az pipelines list --repository REPO --output table
```

---

## NuGet Authentication

```powershell
# Install credential provider
iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) }"

# Interactive auth (first time)
dotnet restore --interactive
```

---

## Azure Deployment Pipeline Prerequisites

For LENS services deploying via Ev2 + ADO release pipelines (per `references/LENS-Docs/sources/docs/enghub/core/content/CreatingServices/configuringPpeAndProdRings.md:350-354`):

1. **ServiceTree Registration** — Register service, get ServiceTree ID GUID. Configure security group in ServiceTree Metadata so `ServiceSpecification.json` can omit `OwnerGroupObjectId` (resolved automatically — see `LENSEv2Standards.md:76`).
2. **Service Connection** (NPE only) — Format: `{ServiceName}-Release-{Environment}`. Production stages use lockbox + Torus JIT instead of a service connection (AUTH-002).
3. **SAW Machine + LENS Contributor Group elevation** — Ev2 registration cmdlets (`New-AzureServiceRolloutServiceRegistration`, `New-AzureServiceRing`, `Register-AzureServiceSubscription`, `Register-AzureServicePresence`, `New-AzureServiceStageMap`) must be run from a Secure Access Workstation. Before running them, request Entra ID elevation through the PROD DMS shell on the SAW:

   ```powershell
   Request-AzureAdGroupRoleElevation `
     -GroupName "<YourLENSTorusTeam>-Contributor" `
     -Reason "Register Ev2 service, ring artifacts, subscriptions, and stage maps"
   ```

   Without LENS Contributor Group elevation, the registration cmdlets fail with permission errors. Running ad-hoc Ev2 registrations from a non-SAW machine is also not supported.

4. **Required Artifacts** (in `Ev2/ServiceGroupRoot/`): see `cicd-deployment.md` § "Azure Deployment Artifact Structure" for the canonical layout.

---

## PR Workflow

```bash
# 1. Create branch
git checkout -b users/$(whoami)/feature-name

# 2. Push and create draft PR
git push -u origin HEAD
az repos pr create --draft --title "feat: feature" --source-branch HEAD --target-branch main

# 3. Queue precheckin, monitor, publish when ready
az repos pr update --id PR_ID --status active
```

---

## PR Thread Management

Resolve review threads and post comments via `az devops invoke`.

### Resolve a Thread

```bash
# Create status payload
echo '{"status":"fixed"}' > thread-status.json
# Or: echo '{"status":"wontFix"}' > thread-status.json

# PATCH thread status
MSYS_NO_PATHCONV=1 az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project="PROJECT" repositoryId=REPO pullRequestId=PR_ID threadId=THREAD_ID \
  --http-method PATCH --in-file thread-status.json --api-version 7.0 \
  --org https://dev.azure.com/ORG
```

### Post a Comment to a Thread

```bash
echo '{"content":"Response text here","commentType":1}' > comment.json

MSYS_NO_PATHCONV=1 az devops invoke --area git --resource pullRequestThreadComments \
  --route-parameters project="PROJECT" repositoryId=REPO pullRequestId=PR_ID threadId=THREAD_ID \
  --http-method POST --in-file comment.json --api-version 7.0 \
  --org https://dev.azure.com/ORG
```

### Query Thread Status

```bash
# All threads by a specific author
MSYS_NO_PATHCONV=1 az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project="PROJECT" repositoryId=REPO pullRequestId=PR_ID \
  --api-version 7.0 --org https://dev.azure.com/ORG \
  --query "value[?comments[0].author.displayName=='Author Name'].[id,status]" -o tsv
```

### Thread Status Values

| Status | When to Use |
|--------|-------------|
| `fixed` | Concern addressed in code |
| `wontFix` | Not applicable, deferred, or duplicate |
| `active` | Default — needs attention |
| `closed` | Resolved without code change |

---

## Windows / Git Bash Compatibility

On Windows with Git Bash (MSYS2), route parameters containing `/` are mangled into file paths. Prefix commands with `MSYS_NO_PATHCONV=1` to prevent this.

```bash
# WRONG: Git Bash converts route-parameters to file paths
az devops invoke --route-parameters project="My Project Core" ...

# CORRECT: Disable path conversion
MSYS_NO_PATHCONV=1 az devops invoke --route-parameters project="My Project Core" ...
```

**Also applies to**: Any `az devops invoke` with `--route-parameters` on Windows.

**Note**: `--in-file` paths must use Windows-compatible locations (e.g., `C:/source/file.json`), not `/tmp/` which may not exist in all shells.

---

## Work Item Management

### Query Stories by Area Path

```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.State] \
  FROM workitems \
  WHERE [System.AreaPath] UNDER 'YourArea\Case Management' \
  AND [System.WorkItemType] = 'User Story' \
  ORDER BY [System.Id]" \
  --org https://dev.azure.com/ORG --project PROJECT --output json
```

### Get Work Items Linked to a PR

```bash
az repos pr work-item list --id PR_ID \
  --org https://dev.azure.com/ORG --detect false --output json
```

### Show Work Item Details

Use `--query` with JMESPath to extract specific fields. **Note**: `--fields` and `--expand` cannot be combined.

```bash
# Get title, state, acceptance criteria, description
az boards work-item show --id WI_ID \
  --org https://dev.azure.com/ORG \
  --query "fields.[\"System.Title\",\"System.State\",\"Microsoft.VSTS.Common.AcceptanceCriteria\",\"System.Description\"]" \
  --output json
```

### Close a Story

```bash
az boards work-item update --id WI_ID \
  --state Closed --reason "Acceptance tests pass" \
  --org https://dev.azure.com/ORG --output json
```

### Unassign a Work Item

```bash
az boards work-item update --id WI_ID \
  --state New --assigned-to "" \
  --org https://dev.azure.com/ORG --output json
```

### Post-PR Story Review Checklist

After merging a PR, review linked and potentially-covered stories:

1. **Get linked work items** from the PR (`az repos pr work-item list`)
2. **Query all stories** in the area path to find unlinked but potentially-covered items
3. **Compare acceptance criteria** of each story against what the PR delivered
4. **Close** stories where all AC items are met or where remaining gaps are covered by other stories
5. **Unassign and reset to New** stories that are only partially covered
6. **Leave as-is** stories where coverage is unclear — don't close speculatively

### Work Item State Transitions

| From | To | Reason | When |
|------|----|--------|------|
| New | Active | Implementation started | Work begins |
| Active | Closed | Acceptance tests pass | All AC met, PR merged |
| Active | New | (reset) | Unassigning partially-covered work |
| Closed | Active | Reactivated | Reopened for additional work |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| `feature/` branch prefix | `users/<alias>/` prefix |
| Non-draft PRs for WIP | Start with `--draft` |
| Official builds on feature branch | Use Precheckin pipelines |
| Hardcoded PATs in NuGet.config | Use credential provider |
| Missing ServiceTree registration | Register before Azure deployment pipeline setup |
| Ignoring review threads | Resolve all threads with correct disposition |
| `az devops invoke` without `MSYS_NO_PATHCONV=1` on Windows | Always prefix on Git Bash |
| Using `/tmp/` for `--in-file` on Windows | Use project-relative or `C:/` paths |
| Closing stories without checking AC | Always compare acceptance criteria against delivered code |
| Leaving completed stories Active after PR merge | Review and close all covered stories post-merge |
| Closing partially-covered stories | Only close when ALL acceptance criteria are met |
| Using `--fields` with `--expand` | Use `--query` with JMESPath instead |
| `az repos pr show --project` flag | Use `--detect false` instead; `--project` is not valid for this command |

---

## PR Description Limits

ADO PR descriptions are capped at **4000 characters**. For longer content:

```bash
# Write description to file, pass via subshell
echo "Long description..." > pr-body.txt
az repos pr create --description "$(cat pr-body.txt)" ...

# Or use the wrapper script which handles this internally
powershell.exe -NoProfile -File .claude/scripts/Ado-PR-Manage.ps1 -Action create ...

# Or summarize to fit the limit
# Keep summary bullets + link to full spec in the PR
```

**Rule**: If description exceeds 4000 chars, truncate with a link to the full spec/plan document.

---

## Audit Scope

**Default rule**: When auditing, reviewing, or scanning — always cover ALL repos in the ecosystem unless explicitly told to scope down.

| Scope | When |
|-------|------|
| All ecosystem repos | Default for audits, pattern reviews, cross-repo comparisons |
| Subset of repos | Only when user explicitly specifies which repos |
| Single repo | Only for targeted PR reviews or bug investigations |

**Anti-pattern**: Defaulting to 2-3 "representative" repos and missing patterns in the rest.
