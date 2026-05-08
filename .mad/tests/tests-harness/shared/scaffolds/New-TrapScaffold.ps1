# New-TrapScaffold.ps1 - Parameterized .NET scaffold generator for eval scenarios
#
# Generates a minimal .NET project structure with optional antipatterns injected.
# This is a lightweight generator for new eval types; existing Setup-* functions
# in Run-LocalEval.ps1 continue to work as-is for their scenarios.

$ErrorActionPreference = 'Stop'

function New-TrapScaffold {
    <#
    .SYNOPSIS
        Generate a .NET project scaffold with optional antipatterns for eval scenarios.
    .DESCRIPTION
        Creates a minimal .NET solution structure in the specified output directory.
        Supports multiple scaffold types (enterprise 5-layer, basic 3-layer, minimal).
        Optionally injects antipatterns into the scaffold for agent testing.

        NOTE: This does NOT replicate the full 500+ line Setup-TrapAntipatternResistance
        or Setup-EnterpriseCosmosEntity functions. Those continue to work as-is.
        This function provides a lighter-weight generator for new eval types.
    .PARAMETER OutputPath
        Directory where the scaffold will be created.
    .PARAMETER ScaffoldType
        Type of scaffold to generate:
        - 'enterprise-5layer': API, DI, BusinessLogic, DataAccess, Common (matching the ecosystem)
        - 'basic-3layer': API, Core, Data
        - 'minimal': Single project with Program.cs
    .PARAMETER Antipatterns
        Optional array of antipattern descriptors to inject.
        Each: @{file='Service.cs'; line=10; description='Missing null check'; category='null-handling'}
    .PARAMETER ProjectConfig
        Optional project configuration overrides.
        @{namespace='EvalProject'; projectName='EvalSolution'; targetFramework='net8.0'}
    .EXAMPLE
        New-TrapScaffold -OutputPath 'C:\temp\eval' -ScaffoldType 'enterprise-5layer'
    .EXAMPLE
        $traps = @(@{file='Service.cs'; line=5; description='Bare catch'; category='error-handling'})
        New-TrapScaffold -OutputPath 'C:\temp\eval' -ScaffoldType 'basic-3layer' -Antipatterns $traps
    #>
    param(
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)]
        [ValidateSet('enterprise-5layer', 'basic-3layer', 'minimal')]
        [string]$ScaffoldType,
        [hashtable[]]$Antipatterns,
        [hashtable]$ProjectConfig
    )

    # Defaults
    $ns = if ($ProjectConfig -and $ProjectConfig.namespace) { $ProjectConfig.namespace } else { 'EvalProject' }
    $slnName = if ($ProjectConfig -and $ProjectConfig.projectName) { $ProjectConfig.projectName } else { 'EvalSolution' }
    $tfm = if ($ProjectConfig -and $ProjectConfig.targetFramework) { $ProjectConfig.targetFramework } else { 'net8.0' }

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    Push-Location $OutputPath
    try {
        # Create solution
        $ErrorActionPreference = 'Continue'
        & dotnet new sln -n $slnName 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: create solution (exit code $LASTEXITCODE)" }

        switch ($ScaffoldType) {
            'enterprise-5layer' {
                $projects = @('Common', 'DataAccess', 'BusinessLogic', 'DependencyInjection', 'API')
                foreach ($proj in $projects) {
                    if ($proj -eq 'API') {
                        & dotnet new web -n $proj --no-restore 2>&1 | Out-Null
                    } else {
                        & dotnet new classlib -n $proj --no-restore 2>&1 | Out-Null
                        Remove-Item -Path "$proj/Class1.cs" -ErrorAction SilentlyContinue
                    }
                    if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: create project $proj (exit code $LASTEXITCODE)" }
                }
                & dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add projects to solution (exit code $LASTEXITCODE)" }
                & dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add DataAccess references (exit code $LASTEXITCODE)" }
                & dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add BusinessLogic references (exit code $LASTEXITCODE)" }
                & dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add DependencyInjection references (exit code $LASTEXITCODE)" }
                & dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add API references (exit code $LASTEXITCODE)" }

                # Add NuGet packages for enterprise-5layer
                & dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" 2>&1 | Out-Null
                & dotnet add DataAccess/DataAccess.csproj package Newtonsoft.Json 2>&1 | Out-Null
                & dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
                & dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
                & dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity 2>&1 | Out-Null
                & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions 2>&1 | Out-Null
            }
            'basic-3layer' {
                $projects = @('Core', 'Data', 'API')
                foreach ($proj in $projects) {
                    if ($proj -eq 'API') {
                        & dotnet new web -n $proj --no-restore 2>&1 | Out-Null
                    } else {
                        & dotnet new classlib -n $proj --no-restore 2>&1 | Out-Null
                        Remove-Item -Path "$proj/Class1.cs" -ErrorAction SilentlyContinue
                    }
                    if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: create project $proj (exit code $LASTEXITCODE)" }
                }
                & dotnet sln add Core/Core.csproj Data/Data.csproj API/API.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add projects to solution (exit code $LASTEXITCODE)" }
                & dotnet add Data/Data.csproj reference Core/Core.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add Data references (exit code $LASTEXITCODE)" }
                & dotnet add API/API.csproj reference Core/Core.csproj Data/Data.csproj 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add API references (exit code $LASTEXITCODE)" }
            }
            'minimal' {
                & dotnet new console -n $ns --no-restore 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: create minimal project (exit code $LASTEXITCODE)" }
                & dotnet sln add "$ns/$ns.csproj" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: add minimal project to solution (exit code $LASTEXITCODE)" }
            }
        }

        & dotnet restore 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Scaffold setup failed at: dotnet restore (exit code $LASTEXITCODE)" }

        # Inject antipatterns if provided
        if ($Antipatterns) {
            foreach ($trap in $Antipatterns) {
                $trapFile = Join-Path $OutputPath $trap.file
                $resolvedTrap = [System.IO.Path]::GetFullPath($trapFile)
                $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
                if (-not $resolvedTrap.StartsWith($resolvedOutput, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Write-Warning "Antipattern file '$($trap.file)' resolves outside OutputPath. Skipping."
                    continue
                }
                $trapDir = Split-Path $trapFile -Parent
                if (-not (Test-Path $trapDir)) {
                    New-Item -ItemType Directory -Path $trapDir -Force | Out-Null
                }
                # Create a marker comment in the file for the antipattern
                if (-not (Test-Path $trapFile)) {
                    $markerContent = "// ANTIPATTERN[$($trap.category)]: $($trap.description)`n"
                    [System.IO.File]::WriteAllText($trapFile, $markerContent, (New-Object System.Text.UTF8Encoding $false))
                }
            }
        }
    }
    finally {
        $ErrorActionPreference = 'Stop'
        Pop-Location
    }

    return @{
        scaffold_type = $ScaffoldType
        output_path   = $OutputPath
        solution_name = $slnName
        namespace     = $ns
        antipatterns  = if ($Antipatterns) { $Antipatterns.Count } else { 0 }
    }
}
