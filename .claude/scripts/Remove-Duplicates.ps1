[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$propertyNamesPath = "C:\source\consumer-project\sources\dev\CMS\src\Common\Constants\PropertyNames.cs"

Write-Host "Removing duplicate constants from PropertyNames.cs..." -ForegroundColor Cyan

$propertyNamesLines = @(Get-Content -Path $propertyNamesPath)

# Find all instances of StateField
$stateFieldIndices = @()
$newValueIndices = @()

for ($i = 0; $i -lt $propertyNamesLines.Count; $i++) {
    if ($propertyNamesLines[$i] -match 'public const string StateField') {
        $stateFieldIndices += $i
    }
    if ($propertyNamesLines[$i] -match 'public const string NewValue') {
        $newValueIndices += $i
    }
}

Write-Host "Found StateField at lines: $($stateFieldIndices.Count) times" -ForegroundColor Yellow
Write-Host "Found NewValue at lines: $($newValueIndices.Count) times" -ForegroundColor Yellow

if ($stateFieldIndices.Count -gt 1 -or $newValueIndices.Count -gt 1) {
    Write-Host "Duplicates detected, removing duplicates..." -ForegroundColor Yellow

    # We need to remove the lines: 374-379 (the second set of duplicates and their comments)
    # Lines to remove: 374, 375, 376, 377, 378, 379 (0-indexed: 373, 374, 375, 376, 377, 378)

    $updatedLines = @()
    for ($i = 0; $i -lt $propertyNamesLines.Count; $i++) {
        # Skip the duplicate lines (indices 373-378, which are lines 374-379 in editor)
        if ($i -ge 373 -and $i -le 378) {
            Write-Host "Skipping line $($i + 1): $($propertyNamesLines[$i])" -ForegroundColor Gray
            continue
        }
        $updatedLines += $propertyNamesLines[$i]
    }

    $updatedLines | Set-Content -Path $propertyNamesPath
    Write-Host "Duplicates removed!" -ForegroundColor Green
} else {
    Write-Host "No duplicates found" -ForegroundColor Green
}

Write-Host "`nVerifying the fix..." -ForegroundColor Cyan

# Now run build and test
Write-Host "Building Common.csproj..." -ForegroundColor Yellow
&dotnet build "C:\source\consumer-project\sources\dev\CMS\src\Common\Common.csproj"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Build succeeded!" -ForegroundColor Green

# Test
Write-Host "Running test..." -ForegroundColor Yellow
&dotnet test "C:\source\consumer-project\sources\test\CMS\src\Common.Tests\Common.Tests.csproj" `
    --filter "AllJsonPropertyNameValues_ShouldExistInPropertyNamesConstants"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Test failed with exit code $LASTEXITCODE"
}

Write-Host "`nAll operations completed successfully!" -ForegroundColor Green
