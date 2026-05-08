[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$propertyNamesPath = "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\Common\Constants\PropertyNames.cs"
$updateDftPath = "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\Common\DTOs\Requests\UpdateDftRequest.cs"

Write-Host "Restoring files from git..." -ForegroundColor Cyan

# Restore the files
&git -C "C:\source\CCGHCP\src\LENS-CMS" checkout -- "sources/dev/CMS/src/Common/Constants/PropertyNames.cs"
&git -C "C:\source\CCGHCP\src\LENS-CMS" checkout -- "sources/dev/CMS/src/Common/DTOs/Requests/UpdateDftRequest.cs"

Write-Host "Files restored!" -ForegroundColor Green

# Now apply the correct fix
Write-Host "`nApplying the correct fix..." -ForegroundColor Cyan

Write-Host "Step 1: Updating PropertyNames.cs..." -ForegroundColor Yellow

$propertyNamesLines = @(Get-Content -Path $propertyNamesPath)

# Find the closing brace of the Dft class
$dftClassLines = @()
$inDftClass = $false
$dftClassStart = -1
$dftClassEnd = -1

for ($i = 0; $i -lt $propertyNamesLines.Count; $i++) {
    if ($propertyNamesLines[$i] -match 'public static class Dft') {
        $inDftClass = $true
        $dftClassStart = $i
    }

    if ($inDftClass -and $propertyNamesLines[$i] -match '^\s*\}' -and $i -gt $dftClassStart) {
        $dftClassEnd = $i
        break
    }
}

Write-Host "Found Dft class from line $($dftClassStart + 1) to $($dftClassEnd + 1)" -ForegroundColor Gray

# Insert new constants before the closing brace
$newLines = @(
    "",
    "        /// <summary>State field property (collectionState, publishState, or deliveryState).</summary>",
    "        public const string StateField = ""stateField"";",
    "",
    "        /// <summary>New state value property.</summary>",
    "        public const string NewValue = ""newValue"";"
)

# Build the updated lines array
$updatedLines = @()
for ($i = 0; $i -lt $dftClassEnd; $i++) {
    $updatedLines += $propertyNamesLines[$i]
}

# Add the new lines
$updatedLines += $newLines

# Add the closing brace and everything after
for ($i = $dftClassEnd; $i -lt $propertyNamesLines.Count; $i++) {
    $updatedLines += $propertyNamesLines[$i]
}

# Write back
$updatedLines | Set-Content -Path $propertyNamesPath

Write-Host "PropertyNames.cs updated successfully!" -ForegroundColor Green

# Step 2: Update UpdateDftRequest.cs
Write-Host "Step 2: Updating UpdateDftRequest.cs..." -ForegroundColor Yellow

$updateDftContent = Get-Content -Path $updateDftPath -Raw

# Replace the hardcoded property names
$updateDftContent = $updateDftContent -replace '\[JsonPropertyName\("stateField"\)\]', '[JsonPropertyName(PropertyNames.Dft.StateField)]'
$updateDftContent = $updateDftContent -replace '\[JsonPropertyName\("newValue"\)\]', '[JsonPropertyName(PropertyNames.Dft.NewValue)]'

Set-Content -Path $updateDftPath -Value $updateDftContent -NoNewline

Write-Host "UpdateDftRequest.cs updated successfully!" -ForegroundColor Green

Write-Host "`nVerifying the fix..." -ForegroundColor Cyan

# Build
Write-Host "Building Common.csproj..." -ForegroundColor Yellow
&dotnet build "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\Common\Common.csproj"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}

Write-Host "Build succeeded!" -ForegroundColor Green

# Test
Write-Host "Running test..." -ForegroundColor Yellow
&dotnet test "C:\source\CCGHCP\src\LENS-CMS\sources\test\CMS\src\Common.Tests\Common.Tests.csproj" `
    --filter "AllJsonPropertyNameValues_ShouldExistInPropertyNamesConstants"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Test failed with exit code $LASTEXITCODE"
}

Write-Host "`nAll operations completed successfully!" -ForegroundColor Green
