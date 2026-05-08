[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Files to modify
$propertyNamesPath = "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\Common\Constants\PropertyNames.cs"
$updateDftRequestPath = "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\Common\DTOs\Requests\UpdateDftRequest.cs"

Write-Host "Fixing missing PropertyNames constants for UpdateDftRequest..." -ForegroundColor Cyan

# 1. Update PropertyNames.cs
Write-Host "Step 1: Updating PropertyNames.cs..." -ForegroundColor Yellow

$propertyNamesLines = @(Get-Content -Path $propertyNamesPath)

# Find the index of the line containing "public const string DataCategories"
$dataCategoriesIndex = $null
for ($i = 0; $i -lt $propertyNamesLines.Count; $i++) {
    if ($propertyNamesLines[$i] -match 'public const string DataCategories') {
        $dataCategoriesIndex = $i
        break
    }
}

if ($null -eq $dataCategoriesIndex) {
    Write-Error "Could not find DataCategories line in PropertyNames.cs"
}

# Find the closing brace of the Dft class (should be shortly after DataCategories)
$dftClassCloseIndex = $null
for ($i = $dataCategoriesIndex + 1; $i -lt $propertyNamesLines.Count; $i++) {
    if ($propertyNamesLines[$i] -match '^\s*\}') {
        $dftClassCloseIndex = $i
        break
    }
}

if ($null -eq $dftClassCloseIndex) {
    Write-Error "Could not find closing brace of Dft class"
}

Write-Host "Found DataCategories at line $($dataCategoriesIndex + 1)" -ForegroundColor Gray
Write-Host "Found Dft class close at line $($dftClassCloseIndex + 1)" -ForegroundColor Gray

# Insert new constants before the closing brace
$newLines = @(
    "",
    "        /// <summary>State field property (collectionState, publishState, or deliveryState).</summary>",
    "        public const string StateField = ""stateField"";",
    "",
    "        /// <summary>New state value property.</summary>",
    "        public const string NewValue = ""newValue"";"
)

# Insert at the correct position
$updatedLines = @()
for ($i = 0; $i -lt $dftClassCloseIndex; $i++) {
    $updatedLines += $propertyNamesLines[$i]
}

$updatedLines += $newLines

for ($i = $dftClassCloseIndex; $i -lt $propertyNamesLines.Count; $i++) {
    $updatedLines += $propertyNamesLines[$i]
}

# Write the updated content back
$updatedLines | Set-Content -Path $propertyNamesPath

Write-Host "PropertyNames.cs updated successfully!" -ForegroundColor Green

# 2. Update UpdateDftRequest.cs
Write-Host "Step 2: Updating UpdateDftRequest.cs..." -ForegroundColor Yellow

$updateDftContent = Get-Content -Path $updateDftRequestPath -Raw

# Replace the hardcoded property names with constants
$updateDftContent = $updateDftContent -replace '\[JsonPropertyName\("stateField"\)\]', '[JsonPropertyName(PropertyNames.Dft.StateField)]'
$updateDftContent = $updateDftContent -replace '\[JsonPropertyName\("newValue"\)\]', '[JsonPropertyName(PropertyNames.Dft.NewValue)]'

Set-Content -Path $updateDftRequestPath -Value $updateDftContent -NoNewline

Write-Host "UpdateDftRequest.cs updated successfully!" -ForegroundColor Green

Write-Host "`nFix complete! Now building and testing..." -ForegroundColor Cyan

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
