<#
.SYNOPSIS
Validate that a council-review verdict file does NOT claim ACCEPT/ACCEPT-WITH-FIXES
while having CRITICAL count > 0. Exits 2 on violation (silent-deferral pattern).

.DESCRIPTION
Per memory/feedback_critical_findings_block_pipeline.md: any review-gate verdict
with N >= 1 CRITICAL findings MUST halt the pipeline and trigger remediation, NOT
write "ACCEPT-WITH-FIXES" and proceed.

This script provides mechanical detection. Run it against any verdict file (council
review, mad-spec spec-review, mad-plan plan-council-verdict, etc.) before allowing
the pipeline to proceed.

.PARAMETER VerdictFile
Path to the verdict markdown file to validate.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Validate-CouncilVerdict.ps1 \
  -VerdictFile specs/15-collab-engine-canonical-e/reviews/spec-rereview-verdict.md

.NOTES
Exit codes:
  0 = OK (verdict is consistent: 0 CRITICALs OR not claiming ACCEPT)
  2 = VIOLATION (claims ACCEPT-WITH-FIXES with CRITICAL count > 0; silent-deferral)
  3 = SETUP_ERROR (file missing, unreadable, or unparseable)
#>

param(
  [Parameter(Mandatory = $true)] [string]$VerdictFile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $VerdictFile)) {
  Write-Error "Verdict file not found: $VerdictFile"
  exit 3
}

$content = Get-Content -Path $VerdictFile -Raw
if ([string]::IsNullOrWhiteSpace($content)) {
  Write-Error "Verdict file is empty: $VerdictFile"
  exit 3
}

# ---- Detect verdict claim ----
# Look for explicit "Decision:" or "Verdict consensus:" lines (case-insensitive)
$verdictClaim = "(none detected)"
$claimsAccept = $false
$claimsAcceptWithFixes = $false

# Match "Decision: ACCEPT" or "Verdict consensus: ACCEPT-WITH-FIXES" patterns
$lines = $content -split "`n"
foreach ($line in $lines) {
  $l = $line.Trim()
  if ($l -match "^[*\s]*(Decision|Verdict consensus|Decision consensus|Outcome)\s*:\s*(.+)$") {
    $verdictClaim = $matches[2].Trim()
    if ($verdictClaim -match "^ACCEPT(-WITH-FIXES)?\b" -or $verdictClaim -match "^ACCEPT\s+pending\b") {
      $claimsAccept = $true
      if ($verdictClaim -match "WITH-FIXES" -or $verdictClaim -match "pending") {
        $claimsAcceptWithFixes = $true
      }
    }
    break
  }
}

# ---- Count CRITICALs from the verdict body ----
# Strategy: gather the maximum CRITICAL count cited anywhere in the body.
# Multiple patterns, applied in order; track highest detected count for the
# "remaining unresolved" interpretation. RESOLVED counts are discounted.
$criticalCount = 0
$criticalEvidence = @()

# Pattern 1: aggregate row in 3-reviewer table:
#   | **Aggregate** | **N** | ...
#   | Aggregate | N | ...
$m1 = [regex]::Matches($content, '(?im)^\s*\|\s*\*{0,2}\s*Aggregate\s*\*{0,2}\s*\|\s*\*{0,2}\s*(\d+)\s*\*{0,2}\s*\|')
foreach ($m in $m1) {
  $n = [int]$m.Groups[1].Value
  if ($n -gt $criticalCount) { $criticalCount = $n }
  $criticalEvidence += "aggregate-row CRITICAL=$n"
}

# Pattern 2 (prose form) DROPPED — too many false positives from "9 CRITICAL findings RESOLVED"
# style language. Aggregate row (Pattern 1) + explicit "NEW CRITICAL: N" (Pattern 4) +
# status table (Pattern 5) are the canonical signals.

# Pattern 3: explicit table column "| CRITICAL | N |" (header-then-value) — catches old shape
$m3 = [regex]::Matches($content, '(?im)^\s*\|\s*CRITICAL\s*\|\s*(\d+)\s*\|')
foreach ($m in $m3) {
  $n = [int]$m.Groups[1].Value
  if ($n -gt $criticalCount) { $criticalCount = $n }
  $criticalEvidence += "header-row CRITICAL=$n"
}

# Pattern 4: standalone "CRITICAL: N"
$m4 = [regex]::Matches($content, '(?im)^\s*(NEW\s+)?CRITICAL\s*:\s*(\d+)\s*$')
foreach ($m in $m4) {
  $n = [int]$m.Groups[2].Value
  if ($n -eq 0) { continue }
  if ($criticalEvidence -notcontains "line CRITICAL=$n") {
    if ($n -gt $criticalCount) { $criticalCount = $n }
    $criticalEvidence += "line CRITICAL=$n"
  }
}

# Pattern 5: "C-status" / resolution status — count UNRESOLVED only
# Matches "C1 status: NOT-RESOLVED" or "PARTIAL"
$m5 = [regex]::Matches($content, '(?im)C\d+\s+status\s*:\s*(NOT-RESOLVED|PARTIAL)')
$unresolvedFromStatus = $m5.Count
if ($unresolvedFromStatus -gt 0) {
  $criticalEvidence += "status-table unresolved=$unresolvedFromStatus"
  if ($unresolvedFromStatus -gt $criticalCount) { $criticalCount = $unresolvedFromStatus }
}

# ---- Decision ----
$result = @{
  verdict_file       = $VerdictFile
  verdict_claim      = $verdictClaim
  claims_accept      = $claimsAccept
  claims_accept_fixes = $claimsAcceptWithFixes
  critical_count     = $criticalCount
  critical_evidence  = $criticalEvidence
  generated_at       = (Get-Date).ToString("o")
}

# Stdout summary
"verdict file:      $VerdictFile"
"verdict claim:     $verdictClaim"
"claims ACCEPT:     $claimsAccept"
"claims w/FIXES:    $claimsAcceptWithFixes"
"CRITICAL count:    $criticalCount"
"evidence:          $($criticalEvidence -join '; ')"

if ($claimsAccept -and $criticalCount -gt 0) {
  Write-Host ""
  Write-Host "VIOLATION: verdict claims ACCEPT/ACCEPT-WITH-FIXES with CRITICAL count = $criticalCount." -ForegroundColor Red
  Write-Host "Per memory/feedback_critical_findings_block_pipeline.md: pipeline MUST halt; orchestrator MUST surface findings + remediate before proceeding." -ForegroundColor Red
  exit 2
}

if ($criticalCount -gt 0) {
  Write-Host ""
  Write-Host "NOTE: verdict has CRITICAL count = $criticalCount but does NOT claim ACCEPT. Pipeline halt is correct." -ForegroundColor Yellow
}

if ($criticalCount -eq 0 -and $claimsAccept) {
  Write-Host ""
  Write-Host "OK: verdict is consistent. Pipeline may proceed." -ForegroundColor Green
}

exit 0
