<#
.SYNOPSIS
    Run agent eval scenarios locally or in ACI containers.

.DESCRIPTION
    Creates isolated test projects, runs composite agent evals against them,
    and collects metrics (correctness, token usage, timing). Supports:
    - Local execution (default): Creates temp project, runs assertions
    - ACI execution (--ACI): Deploys container with Claude Code CLI, runs eval remotely
    - Comparison mode (--Compare): Runs same task with composite vs direct agents

.PARAMETER Scenario
    Which eval scenario to run. Maps to .mad/tests/scenarios/eval-<name>.md
    Options: investigate-and-implement, review-and-fix, coverage-loop, all

.PARAMETER Mode
    Execution mode: local (default) or aci
    Local: Creates temp .NET project, runs assertions directly
    ACI: Deploys eval container to Azure, collects results

.PARAMETER Compare
    If set, runs each scenario twice (composite vs direct agents) and compares metrics.

.PARAMETER OutputDir
    Directory for results. Default: .mad/tests/results/<timestamp>

.PARAMETER DryRun
    Show what would be done without executing.

.EXAMPLE
    .\Run-AgentEval.ps1 -Scenario investigate-and-implement
    .\Run-AgentEval.ps1 -Scenario all -Compare
    .\Run-AgentEval.ps1 -Scenario coverage-loop -Mode aci

.EXAMPLE
    # Quick structural validation only (no LLM cost)
    .\Run-AgentEval.ps1 -Scenario all -DryRun
#>

[CmdletBinding()]
param(
    [ValidateSet("investigate-and-implement", "review-and-fix", "coverage-loop", "all")]
    [string]$Scenario = "all",

    [ValidateSet("local", "aci")]
    [string]$Mode = "local",

    [switch]$Compare,
    [string]$OutputDir,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\source\CCGHCP\.mad\scripts" }
$ProjectRoot = Split-Path (Split-Path $ScriptRoot -Parent) -Parent
$TestsDir = Join-Path $ProjectRoot ".mad\tests"
$ScenariosDir = Join-Path $TestsDir "scenarios"

if (-not $OutputDir) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $TestsDir "results\eval-$timestamp"
}

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Status {
    param([string]$Message, [ValidateSet("Info","Success","Warning","Error")][string]$Type = "Info")
    $colors = @{ Info="Cyan"; Success="Green"; Warning="Yellow"; Error="Red" }
    $prefix = @{ Info="[*]"; Success="[+]"; Warning="[!]"; Error="[-]" }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function New-TestProject {
    param([string]$Name, [string]$TempDir)

    $projDir = Join-Path $TempDir $Name
    if ($DryRun) {
        Write-Status "[DRY-RUN] Would create test project at $projDir" -Type Info
        return $projDir
    }

    # Create .NET project
    dotnet new classlib -n $Name -o $projDir --force 2>&1 | Out-Null
    dotnet new mstest -n "$Name.Tests" -o "$projDir.Tests" --force 2>&1 | Out-Null

    # Add project reference
    dotnet add "$projDir.Tests/$Name.Tests.csproj" reference "$projDir/$Name.csproj" 2>&1 | Out-Null

    # Create solution
    $slnPath = Join-Path $TempDir "$Name.sln"
    dotnet new sln -n $Name -o $TempDir --force 2>&1 | Out-Null
    dotnet sln $slnPath add $projDir 2>&1 | Out-Null
    dotnet sln $slnPath add "$projDir.Tests" 2>&1 | Out-Null

    return $projDir
}

function Initialize-Git {
    param([string]$Dir)
    if ($DryRun) { return }
    Push-Location $Dir
    git init 2>&1 | Out-Null
    git add -A 2>&1 | Out-Null
    git commit -m "Initial test project" 2>&1 | Out-Null
    Pop-Location
}

function Measure-Assertions {
    param([string]$ProjectDir, [string]$ScenarioName, [string]$ResultFile)

    $results = @()
    $scenarioFile = Join-Path $ScenariosDir "eval-$ScenarioName.md"

    # Extract assertion blocks from scenario file
    $content = Get-Content $scenarioFile -Raw
    $assertionBlocks = [regex]::Matches($content, '```bash\s*\n((?:(?!```)[\s\S])*?)```')

    $passCount = 0
    $failCount = 0

    foreach ($block in $assertionBlocks) {
        $commands = $block.Groups[1].Value -split "`n" | Where-Object { $_ -match '\S' -and $_ -notmatch '^#' }
        foreach ($cmd in $commands) {
            $cmd = $cmd.Trim()
            if (-not $cmd) { continue }

            if ($DryRun) {
                Write-Status "[DRY-RUN] Would run assertion: $cmd" -Type Info
                continue
            }

            try {
                Push-Location $ProjectDir
                $output = bash -c $cmd 2>&1
                $exitCode = $LASTEXITCODE

                if ($exitCode -eq 0) {
                    $passCount++
                    $results += [PSCustomObject]@{ Assertion=$cmd; Status="PASS"; Output=$output }
                } else {
                    $failCount++
                    $results += [PSCustomObject]@{ Assertion=$cmd; Status="FAIL"; Output=$output }
                }
                Pop-Location
            } catch {
                $failCount++
                $results += [PSCustomObject]@{ Assertion=$cmd; Status="ERROR"; Output=$_.Exception.Message }
                if ((Get-Location).Path -ne $ProjectRoot) { Pop-Location }
            }
        }
    }

    # Write results
    if (-not $DryRun) {
        $results | ConvertTo-Json -Depth 3 | Set-Content $ResultFile
    }

    return @{ Pass=$passCount; Fail=$failCount; Total=($passCount+$failCount); Results=$results }
}

# ── Scenario Runners ─────────────────────────────────────────────────────────

function Run-InvestigateAndImplement {
    param([string]$TempDir, [string]$ResultDir)

    Write-Status "Setting up investigate-and-implement scenario..." -Type Info

    $projDir = New-TestProject -Name "EvalCalculator" -TempDir $TempDir

    if (-not $DryRun) {
        # Write the buggy Calculator.cs
        $calcCode = @'
using System.Linq;

namespace EvalCalculator;

public class Calculator
{
    public int Add(int a, int b) => a + b;
    public int Subtract(int a, int b) => a - b;
    public int Multiply(int a, int b) => a * b;
    public int Divide(int a, int b) => a / b;
    public double Average(int[] numbers) => numbers.Sum() / numbers.Length;  // Bug: integer division
}
'@
        Set-Content (Join-Path $projDir "Calculator.cs") $calcCode

        # Remove default Class1.cs
        Remove-Item (Join-Path $projDir "Class1.cs") -ErrorAction SilentlyContinue

        # Build to verify setup
        dotnet build (Join-Path $TempDir "EvalCalculator.sln") 2>&1 | Out-Null
        Initialize-Git $TempDir
    }

    Write-Status "Test project ready at: $projDir" -Type Success

    return @{
        ProjectDir = $projDir
        SolutionDir = $TempDir
        TaskPrompt = "Fix the bug in Calculator.Average - it uses integer division instead of floating-point division. Also add a guard for empty arrays. Project path: $projDir"
        AgentName = "investigate-and-implement"
        ScenarioName = "investigate-and-implement"
    }
}

function Run-ReviewAndFix {
    param([string]$TempDir, [string]$ResultDir)

    Write-Status "Setting up review-and-fix scenario..." -Type Info

    $projDir = New-TestProject -Name "EvalWebApi" -TempDir $TempDir

    if (-not $DryRun) {
        # Write the vulnerable controller
        $controllerCode = @'
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;

namespace EvalWebApi;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string name)
    {
        // Simulated vulnerable query
        var sql = $"SELECT * FROM Users WHERE Name = '{name}'";
        // In real code this would execute against a database
        await Task.CompletedTask;
        return Ok(sql);
    }
}
'@
        Set-Content (Join-Path $projDir "UsersController.cs") $controllerCode
        Remove-Item (Join-Path $projDir "Class1.cs") -ErrorAction SilentlyContinue
        Initialize-Git $TempDir
    }

    return @{
        ProjectDir = $projDir
        SolutionDir = $TempDir
        TaskPrompt = "Review and fix security issues in UsersController.cs. Files changed: UsersController.cs. Review focus: security."
        AgentName = "review-and-fix"
        ScenarioName = "review-and-fix"
    }
}

function Run-CoverageLoop {
    param([string]$TempDir, [string]$ResultDir)

    Write-Status "Setting up coverage-loop scenario..." -Type Info

    $projDir = New-TestProject -Name "EvalOrders" -TempDir $TempDir

    if (-not $DryRun) {
        $serviceCode = @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace EvalOrders;

public class OrderService
{
    private readonly IOrderRepository _repo;

    public OrderService(IOrderRepository repo) { _repo = repo; }

    public async Task<Order> CreateOrder(CreateOrderRequest request)
    {
        if (request == null) throw new ArgumentNullException(nameof(request));
        if (request.Items.Count == 0) throw new ArgumentException("Order must have items");

        var total = request.Items.Sum(i => i.Price * i.Quantity);
        var order = new Order { Id = Guid.NewGuid().ToString(), Total = total, Status = "Created" };
        await _repo.SaveAsync(order);
        return order;
    }

    public async Task<Order> CancelOrder(string orderId)
    {
        var order = await _repo.GetAsync(orderId);
        if (order == null) throw new KeyNotFoundException($"Order {orderId} not found");
        if (order.Status == "Shipped") throw new InvalidOperationException("Cannot cancel shipped order");
        order.Status = "Cancelled";
        await _repo.SaveAsync(order);
        return order;
    }
}

public class Order { public string Id { get; set; } = ""; public decimal Total { get; set; } public string Status { get; set; } = ""; }
public class CreateOrderRequest { public List<OrderItem> Items { get; set; } = new(); }
public class OrderItem { public decimal Price { get; set; } public int Quantity { get; set; } }
public interface IOrderRepository
{
    Task SaveAsync(Order order);
    Task<Order?> GetAsync(string id);
}
'@
        Set-Content (Join-Path $projDir "OrderService.cs") $serviceCode
        Remove-Item (Join-Path $projDir "Class1.cs") -ErrorAction SilentlyContinue

        # Write partial test (only happy path)
        $testCode = @'
using EvalOrders;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace EvalOrders.Tests;

[TestClass]
public class OrderServiceTests
{
    [TestMethod]
    public async Task CreateOrder_HappyPath_ReturnsOrder()
    {
        var repo = new FakeOrderRepo();
        var svc = new OrderService(repo);
        var request = new CreateOrderRequest { Items = new List<OrderItem> { new() { Price = 10, Quantity = 2 } } };
        var order = await svc.CreateOrder(request);
        Assert.IsNotNull(order);
        Assert.AreEqual(20m, order.Total);
    }
}

public class FakeOrderRepo : IOrderRepository
{
    private readonly Dictionary<string, Order> _store = new();
    public Task SaveAsync(Order order) { _store[order.Id] = order; return Task.CompletedTask; }
    public Task<Order?> GetAsync(string id) => Task.FromResult(_store.GetValueOrDefault(id));
}
'@
        $testDir = "$projDir.Tests"
        Set-Content (Join-Path $testDir "OrderServiceTests.cs") $testCode
        Remove-Item (Join-Path $testDir "UnitTest1.cs") -ErrorAction SilentlyContinue
        Initialize-Git $TempDir
    }

    return @{
        ProjectDir = $projDir
        SolutionDir = $TempDir
        TaskPrompt = "Close the coverage gap for OrderService.cs. Only the happy-path CreateOrder test exists. Write tests for all branches including null input, empty items, CancelOrder happy path, cancel non-existent, and cancel shipped order. Worktree path: $projDir"
        AgentName = "coverage-loop"
        ScenarioName = "coverage-loop"
    }
}

# ── ACI Deployment ───────────────────────────────────────────────────────────

function Deploy-AciEval {
    param([hashtable]$Scenario, [string]$ResultDir)

    Write-Status "ACI eval deployment not yet implemented" -Type Warning
    Write-Status "ACI eval will:" -Type Info
    Write-Status "  1. Build container image with .NET SDK + Claude Code CLI" -Type Info
    Write-Status "  2. Deploy to ACI with managed identity" -Type Info
    Write-Status "  3. Run eval scenario inside container" -Type Info
    Write-Status "  4. Collect results via container logs" -Type Info
    Write-Status "  5. Clean up container" -Type Info
    Write-Status "" -Type Info
    Write-Status "To implement: Create Dockerfile at .mad/tests/Dockerfile.eval" -Type Info
    Write-Status "Then: az container create with scenario mounted as volume" -Type Info

    # Placeholder for ACI eval structure
    $aciConfig = @{
        ContainerImage = "mcr.microsoft.com/dotnet/sdk:10.0"
        AdditionalTools = @("claude-code-cli", "git")
        ManagedIdentity = $true
        Scenario = $Scenario.ScenarioName
        Timeout = 600  # 10 minutes
        VNet = "vnet-cms-tonym-westus3"  # Use existing VNet
        Subnet = "aci-subnet"
    }

    $aciConfig | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $ResultDir "aci-config.json")
    return $aciConfig
}

# ── Main Execution ───────────────────────────────────────────────────────────

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MAD Agent Eval Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) { Write-Status "DRY RUN MODE" -Type Warning; Write-Host "" }

# Create output directory
if (-not $DryRun) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}

Write-Status "Scenario: $Scenario" -Type Info
Write-Status "Mode: $Mode" -Type Info
Write-Status "Output: $OutputDir" -Type Info
Write-Host ""

# Determine scenarios to run
$scenarios = if ($Scenario -eq "all") {
    @("investigate-and-implement", "review-and-fix", "coverage-loop")
} else {
    @($Scenario)
}

$overallResults = @()

foreach ($scenarioName in $scenarios) {
    Write-Host ""
    Write-Host "────────────────────────────────────" -ForegroundColor DarkGray
    Write-Status "Running: $scenarioName" -Type Info
    Write-Host ""

    $startTime = Get-Date

    # Create isolated temp directory
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "eval-$scenarioName-$(Get-Date -Format 'HHmmss')"
    if (-not $DryRun) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }

    $scenarioResultDir = Join-Path $OutputDir $scenarioName
    if (-not $DryRun) { New-Item -Path $scenarioResultDir -ItemType Directory -Force | Out-Null }

    # Setup scenario
    $scenarioConfig = switch ($scenarioName) {
        "investigate-and-implement" { Run-InvestigateAndImplement -TempDir $tempDir -ResultDir $scenarioResultDir }
        "review-and-fix"           { Run-ReviewAndFix -TempDir $tempDir -ResultDir $scenarioResultDir }
        "coverage-loop"            { Run-CoverageLoop -TempDir $tempDir -ResultDir $scenarioResultDir }
    }

    if ($Mode -eq "aci") {
        Deploy-AciEval -Scenario $scenarioConfig -ResultDir $scenarioResultDir
        continue
    }

    # Save scenario config
    if (-not $DryRun) {
        $scenarioConfig | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $scenarioResultDir "scenario-config.json")
    }

    $elapsed = (Get-Date) - $startTime

    Write-Status "Setup complete in $([math]::Round($elapsed.TotalSeconds, 1))s" -Type Success
    Write-Status "" -Type Info
    Write-Status "To run this eval with Claude Code:" -Type Info
    Write-Status "  claude --print 'Read .claude/agents/$($scenarioConfig.AgentName).md and follow its protocol. Task: $($scenarioConfig.TaskPrompt)'" -Type Info
    Write-Status "" -Type Info
    Write-Status "Task prompt saved to: $(Join-Path $scenarioResultDir 'task-prompt.txt')" -Type Info

    if (-not $DryRun) {
        Set-Content (Join-Path $scenarioResultDir "task-prompt.txt") $scenarioConfig.TaskPrompt
        Set-Content (Join-Path $scenarioResultDir "project-dir.txt") $scenarioConfig.ProjectDir
    }

    $overallResults += [PSCustomObject]@{
        Scenario = $scenarioName
        SetupTime = "$([math]::Round($elapsed.TotalSeconds, 1))s"
        ProjectDir = $scenarioConfig.ProjectDir
        Status = "READY"
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Eval Setup Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$overallResults | Format-Table -AutoSize

if (-not $DryRun) {
    $overallResults | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $OutputDir "summary.json")
    Write-Status "Results directory: $OutputDir" -Type Info
}

Write-Host ""
Write-Status "Next: Run composite agents against each scenario, then run assertions" -Type Info
Write-Status "  powershell.exe -NoProfile -File .mad/scripts/Run-AgentEval.ps1 -Scenario all" -Type Info
