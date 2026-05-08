Import-Module Pester -MinimumVersion 5.0
$tests = Get-ChildItem /mad/MAD -Filter '*.Tests.ps1' -Recurse | ForEach-Object FullName
$r = Invoke-Pester -Path $tests -PassThru -Output None
Write-Host "Total: $($r.TotalCount)  Passed: $($r.PassedCount)  Failed: $($r.FailedCount)"
foreach ($t in $r.Failed) {
    Write-Host ''
    Write-Host "FAIL: $($t.ExpandedPath)"
    Write-Host "  Message: $($t.ErrorRecord.Exception.Message)"
    Write-Host "  Location: $($t.ScriptBlock.File):$($t.ScriptBlock.StartPosition.StartLine)"
}
