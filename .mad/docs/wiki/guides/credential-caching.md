# Credential Caching Strategy

How authentication tokens are cached across deployment tools.

## Tool Caching Matrix

| Tool | Auth Method | Caching |
|------|------------|---------|
| `az` CLI | `az login` (browser OAuth) | MSAL token cache (DPAPI-encrypted on Windows) - reused across all processes |
| Azure deployment-pipeline PowerShell module | Browser OAuth via the pipeline module | **In-memory only** - dies when `powershell.exe` exits |
| Git | HTTPS with ADO | Windows Credential Manager - persistent |
| ACI IMDS | Automatic (no user action) | MI token from IMDS (169.254.169.254); takes 10-30s after container start |
| ADO PR APIs | `az` CLI (via `az devops invoke`) | MSAL token cache - reused across all processes |
| `dotnet` CLI | N/A (local tool) | NuGet credentials via Azure Artifacts credential provider |

## Key Insight

The Azure deployment-pipeline auth tokens are in-memory only and NOT shared between `powershell.exe` processes. Each invocation is a fresh session requiring a new browser auth. This is why wrapper scripts are critical - they authenticate once and run all deployment-pipeline operations in a single session. The `az` CLI uses MSAL with DPAPI encryption, so its tokens persist securely across process boundaries. Lesson: when a tool's auth cache is process-local, wrap the tool in a long-running script so you only pay the login cost once per session.

## Why Wrapper Scripts Matter

- Each `powershell.exe` invocation is a **fresh session** - deployment-pipeline auth tokens are not cached between calls
- Polling deployment-pipeline status 10 times = 10 browser auth prompts for the user
- The wrapper scripts authenticate once and poll internally, reducing auth prompts to 1 per operation
- This also reduces Claude's token usage since we don't process verbose module loading output 10x
- **PR operations**: `Ado-PR-Collect.ps1` replaces 5+ inline `az` calls with one script that saves all data to files
- **Quality gates**: `Run-DotnetGates.ps1` replaces ~200 lines of raw dotnet output with ~15 lines of summary
