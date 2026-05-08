#!/bin/bash
# Agent Eval Entrypoint - ACI Container
# Runs Claude agent evaluation scenarios in an isolated ACI container.
# All diagnostics go to stderr; only the final JSON result goes to stdout.
#
# Required env vars:
#   COMMIT_SHA       - Git commit to checkout
#   KEY_VAULT_NAME   - Key Vault containing 'anthropic-api-key' secret
#   CLIENT_ID        - Managed identity client ID for az login
#
# Optional env vars:
#   SCENARIOS        - Comma-separated scenario names (default: all)
#   EVAL_RUN_ID      - Unique run ID (default: auto-generated)
#   REPO_URL         - Git clone URL (default: CCGHCP ADO repo)
#   ENVIRONMENT      - Environment name (default: aci)
#   TREATMENT_MODE   - "true" to place workdirs inside repo tree (treatment),
#                       "false" (default) for sibling workdirs (baseline).
#                       Can also be set via --treatment CLI flag.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

COMMIT_SHA="${COMMIT_SHA:?COMMIT_SHA is required}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:?KEY_VAULT_NAME is required}"
CLIENT_ID="${CLIENT_ID:?CLIENT_ID is required}"
SCENARIOS="${SCENARIOS:-all}"
REPO_URL="${REPO_URL:-https://dev.azure.com/your-org/your-project/_git/your-repo}"
ENVIRONMENT="${ENVIRONMENT:-aci}"
JUDGE_ENABLED="${JUDGE_ENABLED:-false}"
# TREATMENT_MODE: Controls whether eval workdirs are placed inside or outside the repo tree.
#   false (default) = baseline: workdir at /workspace/eval-{scenario} (sibling of repo)
#   true            = treatment: workdir at {REPO_DIR}/.mad/scratch/eval-{scenario} (inside repo)
# See run_single_scenario() for how this affects Claude Code's config discovery.
TREATMENT_MODE="${TREATMENT_MODE:-false}"

# Parse CLI arguments (override env vars)
for arg in "$@"; do
  case "$arg" in
    --judge) JUDGE_ENABLED="true" ;;
    --treatment) TREATMENT_MODE="true" ;;
  esac
done

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/ccghcp"
SCENARIO_DIR="${REPO_DIR}/.mad/tests/scenarios"
RESULTS_DIR="${WORKSPACE}/results"
PER_SCENARIO_TIMEOUT=600  # 10 minutes

# Auto-generate run ID if not provided
if [ -z "${EVAL_RUN_ID:-}" ]; then
  EVAL_RUN_ID="eval-$(date -u +%Y%m%d-%H%M%S)-0000000"
fi

# ============================================================================
# Diagnostic logging (all to stderr)
# ============================================================================

log() { echo "[eval] $*" >&2; }
log_err() { echo "[eval][ERROR] $*" >&2; }
log_warn() { echo "[eval][WARN] $*" >&2; }

# ============================================================================
# Phase 1: Setup - Install dependencies
# ============================================================================

setup_dependencies() {
  log "=== Phase 1: Installing dependencies ==="

  # Install Node.js v22 LTS
  log "Installing Node.js v22 LTS..."
  apt-get update -qq >&2 2>&1
  apt-get install -y -qq curl gnupg jq git ca-certificates >&2 2>&1

  # nodesource setup for Node.js 22
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >&2 2>&1
  apt-get install -y -qq nodejs >&2 2>&1
  log "Node.js $(node --version) installed"

  # Install Claude CLI
  log "Installing Claude CLI..."
  npm install -g @anthropic-ai/claude-code >&2 2>&1
  log "Claude CLI installed: $(claude --version 2>/dev/null || echo 'unknown version')"

  # Install .NET SDK if not present
  if ! command -v dotnet &>/dev/null; then
    log "Installing .NET SDK 8.0..."
    apt-get install -y -qq dotnet-sdk-8.0 >&2 2>&1 || {
      # Fallback: Microsoft package feed
      curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0 >&2 2>&1
      export PATH="$HOME/.dotnet:$PATH"
    }
    log ".NET SDK $(dotnet --version 2>/dev/null || echo 'unknown') installed"
  fi

  mkdir -p "$RESULTS_DIR"
  log "Dependencies installed"
}

# ============================================================================
# Phase 2: Auth - Managed Identity login + Key Vault secret
# ============================================================================

setup_auth() {
  log "=== Phase 2: Authenticating ==="

  # Login with managed identity
  log "Logging in with managed identity..."
  az login --identity --username "$CLIENT_ID" >&2 2>&1 || {
    log_err "az login --identity failed"
    return 1
  }
  log "Managed identity login successful"

  # Fetch Anthropic API key from Key Vault
  log "Fetching anthropic-api-key from Key Vault: $KEY_VAULT_NAME"
  ANTHROPIC_API_KEY=$(az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "anthropic-api-key" \
    --query "value" -o tsv 2>/dev/null) || {
    log_err "Failed to fetch anthropic-api-key from Key Vault"
    return 1
  }
  export ANTHROPIC_API_KEY
  log "API key retrieved (${#ANTHROPIC_API_KEY} chars)"
}

# ============================================================================
# Phase 3: Clone repository
# ============================================================================

clone_repo() {
  log "=== Phase 3: Cloning repository ==="

  mkdir -p "$WORKSPACE"
  git clone "$REPO_URL" "$REPO_DIR" >&2 2>&1 || {
    log_err "git clone failed"
    return 1
  }
  cd "$REPO_DIR"
  git checkout "$COMMIT_SHA" >&2 2>&1 || {
    log_err "git checkout $COMMIT_SHA failed"
    return 1
  }

  GIT_BRANCH=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
  log "Cloned and checked out $COMMIT_SHA (branch: $GIT_BRANCH)"
}

# ============================================================================
# Assertion helpers
# ============================================================================

# add_assertion: Record an assertion result as a JSON object
# Args: name, passed (true/false), [expected], [actual], [message]
# Appends to ASSERTIONS_FILE
add_assertion() {
  local name="$1"
  local passed="$2"
  local expected="${3:-}"
  local actual="${4:-}"
  local message="${5:-}"

  jq -n \
    --arg name "$name" \
    --argjson passed "$passed" \
    --arg expected "$expected" \
    --arg actual "$actual" \
    --arg message "$message" \
    '{name: $name, passed: $passed} +
     (if $expected != "" then {expected: $expected} else {} end) +
     (if $actual != "" then {actual: $actual} else {} end) +
     (if $message != "" then {message: $message} else {} end)' \
    >> "$ASSERTIONS_FILE"
}

# run_assertions: Execute standard assertions for a scenario workdir
# Args: scenario_name, workdir, claude_stderr_log
# Populates ASSERTIONS_FILE, sets QUALITY_BUILD, QUALITY_TESTS, QUALITY_FILES
run_assertions() {
  local scenario_name="$1"
  local workdir="$2"
  local stderr_log="$3"

  QUALITY_BUILD=false
  QUALITY_TESTS=false
  QUALITY_FILES="[]"

  # Assertion 1: build_passes
  log "  Assertion: build_passes"
  local build_output_file
  build_output_file=$(mktemp)
  if (cd "$workdir" && dotnet build --nologo -v q 2>&1) > "$build_output_file" 2>&1; then
    add_assertion "build_passes" "true" "exit 0" "exit 0"
    QUALITY_BUILD=true
  else
    add_assertion "build_passes" "false" "exit 0" "exit non-zero" "dotnet build failed"
  fi

  # Assertion 2: test_file_exists
  log "  Assertion: test_file_exists"
  local test_files
  test_files=$(find "$workdir" -name "*Test*.cs" -o -name "*test*.ts" -o -name "*Tests*.cs" -o -name "*test*.tsx" 2>/dev/null | head -5)
  if [ -n "$test_files" ]; then
    local first_test
    first_test=$(echo "$test_files" | head -1 | xargs basename)
    add_assertion "test_file_exists" "true" "*.Test*.cs or *.test*.ts" "$first_test"
  else
    add_assertion "test_file_exists" "false" "*.Test*.cs or *.test*.ts" "none found"
  fi

  # Assertion 3: tests_pass (only if test files exist and build succeeded)
  log "  Assertion: tests_pass"
  if [ -n "$test_files" ] && [ "$QUALITY_BUILD" = "true" ]; then
    local test_output
    test_output=$(cd "$workdir" && dotnet test --nologo -v q 2>&1) || true
    if echo "$test_output" | grep -q "Passed\!" 2>/dev/null || echo "$test_output" | grep -qE "Passed: [1-9]" 2>/dev/null; then
      add_assertion "tests_pass" "true" "0 failures" "all passed"
      QUALITY_TESTS=true
    elif echo "$test_output" | grep -qi "failed" 2>/dev/null; then
      local fail_count
      fail_count=$(echo "$test_output" | grep -oE "Failed: [0-9]+" | head -1 || echo "unknown")
      add_assertion "tests_pass" "false" "0 failures" "$fail_count" "Some tests failed"
    else
      # No test framework detected or no tests ran
      add_assertion "tests_pass" "false" "0 failures" "no tests ran" "Test runner produced no pass/fail output"
    fi
  elif [ -z "$test_files" ]; then
    add_assertion "tests_pass" "false" "tests exist" "no test files" "No test files found to run"
  else
    add_assertion "tests_pass" "false" "build + tests" "build failed" "Cannot run tests because build failed"
  fi

  # Assertion 4: no_errors in Claude stderr
  log "  Assertion: no_errors"
  if [ -f "$stderr_log" ]; then
    local error_count
    error_count=$(grep -ciE '\bERROR\b' "$stderr_log" 2>/dev/null || echo "0")
    if [ "$error_count" -eq 0 ]; then
      add_assertion "no_errors" "true" "0 ERROR lines" "0"
    else
      local first_error
      first_error=$(grep -iE '\bERROR\b' "$stderr_log" 2>/dev/null | head -1 | cut -c1-200)
      add_assertion "no_errors" "false" "0 ERROR lines" "${error_count} errors" "$first_error"
    fi
  else
    add_assertion "no_errors" "true" "no stderr log" "file missing"
  fi

  # Assertion 5: no_build_warnings
  log "  Assertion: no_build_warnings"
  if [ "$QUALITY_BUILD" = "true" ] && [ -f "$build_output_file" ]; then
    local warning_count warning_lines first_warnings
    warning_lines=$(grep -E 'warning [A-Z]{2}[0-9]{4}:' "$build_output_file" 2>/dev/null || true)
    # Try to get count from summary line first
    local summary_count
    summary_count=$(grep -oE '[0-9]+ Warning\(s\)' "$build_output_file" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
    if [ -n "$summary_count" ]; then
      warning_count="$summary_count"
    elif [ -n "$warning_lines" ]; then
      warning_count=$(echo "$warning_lines" | wc -l | tr -d ' ')
    else
      warning_count=0
    fi
    if [ "$warning_count" -eq 0 ] 2>/dev/null; then
      add_assertion "no_build_warnings" "true" "0 warnings" "0"
    else
      first_warnings=$(echo "$warning_lines" | head -3 | cut -c1-150 | tr '\n' '; ')
      add_assertion "no_build_warnings" "false" "0 warnings" "$warning_count build warnings detected" "$first_warnings"
    fi
  else
    add_assertion "no_build_warnings" "false" "0 warnings" "build failed" "Cannot check warnings because build failed"
  fi
  rm -f "$build_output_file" 2>/dev/null

  # Assertion 6: no_debug_artifacts
  log "  Assertion: no_debug_artifacts"
  local debug_matches debug_count
  # Find all .cs files excluding obj/ and bin/
  debug_matches=""
  # TODO / HACK / FIXME (case insensitive)
  local todo_matches
  todo_matches=$(find "$workdir" -name "*.cs" -not -path "*/obj/*" -not -path "*/bin/*" -exec grep -inH '//\s*\(TODO\|HACK\|FIXME\)' {} \; 2>/dev/null | head -5 || true)
  if [ -n "$todo_matches" ]; then
    debug_matches="$todo_matches"
  fi
  # throw new NotImplementedException
  local nie_matches
  nie_matches=$(find "$workdir" -name "*.cs" -not -path "*/obj/*" -not -path "*/bin/*" -exec grep -nH 'throw\s*new\s*NotImplementedException' {} \; 2>/dev/null | head -5 || true)
  if [ -n "$nie_matches" ]; then
    debug_matches="${debug_matches}${debug_matches:+$'\n'}${nie_matches}"
  fi
  # Console.Write (exclude test files)
  local console_matches
  console_matches=$(find "$workdir" -name "*.cs" -not -path "*/obj/*" -not -path "*/bin/*" -not -name "*Test*" -exec grep -nH 'Console\.Write' {} \; 2>/dev/null | head -5 || true)
  if [ -n "$console_matches" ]; then
    debug_matches="${debug_matches}${debug_matches:+$'\n'}${console_matches}"
  fi
  # #if DEBUG
  local debug_directive_matches
  debug_directive_matches=$(find "$workdir" -name "*.cs" -not -path "*/obj/*" -not -path "*/bin/*" -exec grep -nH '^\s*#if\s\+DEBUG' {} \; 2>/dev/null | head -5 || true)
  if [ -n "$debug_directive_matches" ]; then
    debug_matches="${debug_matches}${debug_matches:+$'\n'}${debug_directive_matches}"
  fi
  # 3+ consecutive comment lines (commented-out code blocks)
  local comment_block_matches
  comment_block_matches=$(find "$workdir" -name "*.cs" -not -path "*/obj/*" -not -path "*/bin/*" -exec awk '/^\s*\/\// { count++; if (count == 3) print FILENAME ":" NR " commented-out code block"; next } { count=0 }' {} \; 2>/dev/null | head -5 || true)
  if [ -n "$comment_block_matches" ]; then
    debug_matches="${debug_matches}${debug_matches:+$'\n'}${comment_block_matches}"
  fi

  if [ -z "$debug_matches" ]; then
    add_assertion "no_debug_artifacts" "true" "0 debug artifacts" "0"
  else
    debug_count=$(echo "$debug_matches" | wc -l | tr -d ' ')
    local first_three
    first_three=$(echo "$debug_matches" | sed "s|$workdir/||g" | head -3 | cut -c1-150 | tr '\n' '; ')
    add_assertion "no_debug_artifacts" "false" "0 debug artifacts" "$debug_count matches found" "$first_three"
  fi

  # Assertion 7: no_unused_usings
  log "  Assertion: no_unused_usings"
  if [ "$QUALITY_BUILD" = "true" ]; then
    local format_output format_exit
    format_output=$(cd "$workdir" && dotnet format analyzers --diagnostics IDE0005 --severity info --verify-no-changes 2>&1)
    format_exit=$?
    if [ "$format_exit" -eq 0 ]; then
      add_assertion "no_unused_usings" "true" "0 unused usings" "0"
    elif echo "$format_output" | grep -qiE 'error|could not|is not recognized' 2>/dev/null; then
      # Graceful degradation: dotnet format not available
      add_assertion "no_unused_usings" "true" "dotnet format available" "SKIPPED" "dotnet format not available or failed unexpectedly"
    else
      local format_msg
      format_msg=$(echo "$format_output" | grep "IDE0005" 2>/dev/null | head -3 | cut -c1-150 | tr '\n' '; ')
      if [ -z "$format_msg" ]; then format_msg="unused using directives detected"; fi
      add_assertion "no_unused_usings" "false" "0 unused usings" "unused usings detected" "$format_msg"
    fi
  else
    add_assertion "no_unused_usings" "false" "0 unused usings" "build failed" "Cannot check unused usings because build failed"
  fi

  # Assertion 8: minimal_changes (scenario-aware file count threshold)
  log "  Assertion: minimal_changes"
  local mc_threshold
  case "$scenario_name" in
    investigate-and-implement) mc_threshold=4 ;;
    review-and-fix) mc_threshold=5 ;;
    coverage-loop) mc_threshold=6 ;;
    rule-adherence) mc_threshold=6 ;;
    negative-constraints) mc_threshold=5 ;;
    refactor-extract-service) mc_threshold=7 ;;
    cross-project-dependency) mc_threshold=12 ;;
    enterprise-cosmos-entity) mc_threshold=30 ;;
    trap-antipattern-resistance) mc_threshold=25 ;;
    *) mc_threshold=10 ;;
  esac
  local cs_file_list cs_file_count
  cs_file_list=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null)
  if [ -n "$cs_file_list" ]; then
    cs_file_count=$(echo "$cs_file_list" | wc -l | tr -d ' ')
  else
    cs_file_count=0
  fi
  if [ "$cs_file_count" -le "$mc_threshold" ]; then
    add_assertion "minimal_changes" "true" "max $mc_threshold .cs files" "$cs_file_count files"
  else
    local extra_files
    extra_files=$(echo "$cs_file_list" | tail -n +"$((mc_threshold + 1))" | sed "s|$workdir/||g" | head -5 | tr '\n' '; ')
    add_assertion "minimal_changes" "false" "max $mc_threshold .cs files" \
      "Created $cs_file_count .cs files, expected max $mc_threshold" "$extra_files"
  fi

  # Assertion 9: test_quality_assertions
  log "  Assertion: test_quality_assertions"
  local tq_test_files
  tq_test_files=$(find "$workdir" -name "*Test*.cs" -o -name "*Tests*.cs" 2>/dev/null | grep -v '/obj/' | grep -v '/bin/')
  if [ -n "$tq_test_files" ]; then
    # Collect distinct strong assertion types across all test files
    local tq_all_assertions tq_strong_types tq_strong_count
    tq_all_assertions=$(echo "$tq_test_files" | xargs grep -ohE 'Assert\.(Equal|StrictEqual|Throws|ThrowsAsync|Contains|DoesNotContain|Empty|NotEmpty|InRange|True|False)|\.Should\(' 2>/dev/null || true)
    # Build list of strong types (filter out Assert.True(true) and Assert.NotNull)
    tq_strong_types=""
    if echo "$tq_all_assertions" | grep -qE 'Assert\.(Equal|StrictEqual)'; then
      tq_strong_types="${tq_strong_types}Assert.Equal "
    fi
    if echo "$tq_all_assertions" | grep -qE 'Assert\.(Throws|ThrowsAsync)'; then
      tq_strong_types="${tq_strong_types}Assert.Throws "
    fi
    if echo "$tq_all_assertions" | grep -qE 'Assert\.(Contains|DoesNotContain)'; then
      tq_strong_types="${tq_strong_types}Assert.Contains "
    fi
    if echo "$tq_all_assertions" | grep -qE 'Assert\.(Empty|NotEmpty)'; then
      tq_strong_types="${tq_strong_types}Assert.Empty "
    fi
    if echo "$tq_all_assertions" | grep -q 'Assert\.InRange'; then
      tq_strong_types="${tq_strong_types}Assert.InRange "
    fi
    if echo "$tq_all_assertions" | grep -q '\.Should('; then
      tq_strong_types="${tq_strong_types}FluentAssertions "
    fi
    # Check Assert.True with non-trivial argument
    local tq_true_nontrivial
    tq_true_nontrivial=$(echo "$tq_test_files" | xargs grep -ohE 'Assert\.True\([^)]+\)' 2>/dev/null | grep -v 'Assert\.True(\s*true\s*)' || true)
    if [ -n "$tq_true_nontrivial" ]; then
      tq_strong_types="${tq_strong_types}Assert.True "
    fi
    local tq_false_nontrivial
    tq_false_nontrivial=$(echo "$tq_test_files" | xargs grep -ohE 'Assert\.False\([^)]+\)' 2>/dev/null | grep -v 'Assert\.False(\s*false\s*)' || true)
    if [ -n "$tq_false_nontrivial" ]; then
      tq_strong_types="${tq_strong_types}Assert.False "
    fi
    # Count distinct types
    if [ -n "$tq_strong_types" ]; then
      tq_strong_count=$(echo "$tq_strong_types" | tr ' ' '\n' | grep -c '.' || echo "0")
    else
      tq_strong_count=0
    fi
    local tq_types_list
    tq_types_list=$(echo "$tq_strong_types" | xargs | tr ' ' ', ')
    # Check for degenerate tests (body with only Assert.True(true) or Assert.NotNull)
    local tq_degenerate
    tq_degenerate=$(echo "$tq_test_files" | xargs grep -lE 'Assert\.True\(\s*true\s*\)|Assert\.NotNull\s*\(' 2>/dev/null || true)
    local tq_degen_msg=""
    if [ -n "$tq_degenerate" ]; then
      tq_degen_msg="; WARNING: possible degenerate tests in: $(echo "$tq_degenerate" | head -3 | xargs -I{} basename {} | tr '\n' ', ')"
    fi
    if [ "$tq_strong_count" -ge 2 ]; then
      add_assertion "test_quality_assertions" "true" ">= 2 distinct strong assertion types" \
        "$tq_strong_count types: $tq_types_list$tq_degen_msg"
    else
      add_assertion "test_quality_assertions" "false" ">= 2 distinct strong assertion types" \
        "Only $tq_strong_count distinct assertion types found: $tq_types_list$tq_degen_msg"
    fi
  else
    add_assertion "test_quality_assertions" "false" ">= 2 distinct strong assertion types" "no test files found"
  fi

  # Collect files created/modified
  QUALITY_FILES=$(find "$workdir" -name "*.cs" -newer "$workdir/.eval-start-marker" 2>/dev/null \
    | sed "s|$workdir/||" \
    | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
}

# ============================================================================
# Scenario setup helpers
# ============================================================================

# setup_investigate_and_implement: Create the Calculator project with a bug
setup_investigate_and_implement() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new classlib -n EvalProject --no-restore >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1

  # Remove default files
  rm -f EvalProject/Class1.cs EvalProject.Tests/UnitTest1.cs

  # Create Calculator.cs with deliberate bug
  cat > EvalProject/Calculator.cs << 'CSEOF'
using System.Linq;

public class Calculator
{
    public int Add(int a, int b) => a + b;
    public int Subtract(int a, int b) => a - b;
    public int Multiply(int a, int b) => a * b;
    public int Divide(int a, int b) => a / b;
    public double Average(int[] numbers) => numbers.Sum() / numbers.Length;
}
CSEOF

  dotnet restore >&2 2>&1
  log "  investigate-and-implement project created at $workdir"
}

# setup_review_and_fix: Create the UsersController project with security issues
setup_review_and_fix() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new webapi -n EvalProject --no-restore --no-https >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1
  dotnet add EvalProject/EvalProject.csproj package Dapper --no-restore >&2 2>&1

  # Create models
  mkdir -p EvalProject/Models
  cat > EvalProject/Models/User.cs << 'CSEOF'
namespace EvalProject.Models;

public class User
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}

public class CreateUserRequest
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
}
CSEOF

  # Create UsersController with security issues
  mkdir -p EvalProject/Controllers
  cat > EvalProject/Controllers/UsersController.cs << 'CSEOF'
using System.Data;
using Dapper;
using EvalProject.Models;
using Microsoft.AspNetCore.Mvc;

namespace EvalProject.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IDbConnection _db;

    public UsersController(IDbConnection db)
    {
        _db = db;
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string name)
    {
        // Vulnerable: string concatenation in SQL
        var sql = $"SELECT * FROM Users WHERE Name = '{name}'";
        var users = await _db.QueryAsync<User>(sql);
        return Ok(users);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        // Missing input validation
        var user = new User { Name = request.Name, Email = request.Email };
        await _db.ExecuteAsync("INSERT INTO Users (Name, Email) VALUES (@Name, @Email)", user);
        return Created($"/api/users/{user.Id}", user);
    }
}
CSEOF

  dotnet restore >&2 2>&1
  log "  review-and-fix project created at $workdir"
}

# setup_coverage_loop: Create the OrderService project with partial coverage
setup_coverage_loop() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new classlib -n EvalProject --no-restore >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj package coverlet.collector --no-restore >&2 2>&1

  # Remove default files
  rm -f EvalProject/Class1.cs EvalProject.Tests/UnitTest1.cs

  # Create interfaces
  cat > EvalProject/IOrderRepository.cs << 'CSEOF'
using System.Threading.Tasks;

public interface IOrderRepository
{
    Task<Order?> GetAsync(string id);
    Task SaveAsync(Order order);
}
CSEOF

  # Create domain models
  cat > EvalProject/Order.cs << 'CSEOF'
using System.Collections.Generic;

public class Order
{
    public string Id { get; set; } = string.Empty;
    public List<OrderItem> Items { get; set; } = new();
    public decimal Total { get; set; }
    public OrderStatus Status { get; set; }
}

public class OrderItem
{
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public int Quantity { get; set; }
}

public class CreateOrderRequest
{
    public List<OrderItem> Items { get; set; } = new();
}

public enum OrderStatus
{
    Created,
    Processing,
    Shipped,
    Cancelled
}
CSEOF

  # Create custom exceptions
  cat > EvalProject/Exceptions.cs << 'CSEOF'
using System;

public class ValidationException : Exception
{
    public ValidationException(string message) : base(message) { }
}

public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}
CSEOF

  # Create OrderService with multiple branches
  cat > EvalProject/OrderService.cs << 'CSEOF'
using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

public class OrderService
{
    private readonly IOrderRepository _repo;
    private readonly ILogger<OrderService> _logger;

    public OrderService(IOrderRepository repo, ILogger<OrderService> logger)
    {
        _repo = repo;
        _logger = logger;
    }

    public async Task<Order> CreateOrder(CreateOrderRequest request)
    {
        if (request == null) throw new ArgumentNullException(nameof(request));

        if (request.Items.Count == 0)
        {
            _logger.LogWarning("Empty order attempted");
            throw new ValidationException("Order must have at least one item");
        }

        var total = request.Items.Sum(i => i.Price * i.Quantity);

        if (total > 10000)
        {
            _logger.LogInformation("High-value order: {Total}", total);
        }

        var order = new Order
        {
            Id = Guid.NewGuid().ToString(),
            Items = request.Items,
            Total = total,
            Status = OrderStatus.Created
        };

        await _repo.SaveAsync(order);
        return order;
    }

    public async Task<Order> CancelOrder(string orderId)
    {
        var order = await _repo.GetAsync(orderId);
        if (order == null) throw new NotFoundException($"Order {orderId} not found");

        if (order.Status == OrderStatus.Shipped)
            throw new InvalidOperationException("Cannot cancel shipped order");

        order.Status = OrderStatus.Cancelled;
        await _repo.SaveAsync(order);
        return order;
    }
}
CSEOF

  # Add Microsoft.Extensions.Logging reference
  dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Logging.Abstractions --no-restore >&2 2>&1

  # Create partial test (happy path only)
  cat > EvalProject.Tests/OrderServiceTests.cs << 'CSEOF'
using System.Collections.Generic;
using System.Threading.Tasks;
using NSubstitute;
using Microsoft.Extensions.Logging;
using Xunit;

public class OrderServiceTests
{
    private readonly IOrderRepository _repo = Substitute.For<IOrderRepository>();
    private readonly ILogger<OrderService> _logger = Substitute.For<ILogger<OrderService>>();

    [Fact]
    public async Task CreateOrder_WithValidRequest_ReturnsOrder()
    {
        var service = new OrderService(_repo, _logger);
        var request = new CreateOrderRequest
        {
            Items = new List<OrderItem>
            {
                new() { Name = "Widget", Price = 9.99m, Quantity = 2 }
            }
        };

        var result = await service.CreateOrder(request);

        Assert.NotNull(result);
        Assert.Equal(OrderStatus.Created, result.Status);
        Assert.Equal(19.98m, result.Total);
        await _repo.Received(1).SaveAsync(Arg.Any<Order>());
    }
}
CSEOF

  dotnet restore >&2 2>&1
  log "  coverage-loop project created at $workdir"
}

# setup_rule_adherence: Create the project with CLAUDE.md rules and example pattern
setup_rule_adherence() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new classlib -n EvalProject --no-restore >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1
  dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Logging.Abstractions --no-restore >&2 2>&1
  dotnet add EvalProject/EvalProject.csproj package Microsoft.Extensions.Http --no-restore >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore >&2 2>&1

  # Remove default files
  rm -f EvalProject/Class1.cs EvalProject.Tests/UnitTest1.cs

  # Create .claude/rules directory
  mkdir -p "$workdir/.claude/rules"

  # Create CLAUDE.md with enforced rules
  cat > "$workdir/CLAUDE.md" << 'CLAUDEEOF'
# Project Rules

## Coding Standards (ENFORCED)

1. **Logging**: Always use `ILogger<T>` for logging. NEVER use `Console.WriteLine` or `Console.Write`.
2. **Async pattern**: All I/O methods MUST be async. Use `async Task<T>` return types.
3. **Dependency injection**: Every service class MUST have a corresponding interface (e.g., `IWeatherService` for `WeatherService`). Register via constructor injection.
4. **Naming**: Public methods use PascalCase. Async methods should use the `Async` suffix.
5. **No static helpers**: Do not create static utility/helper classes. Use instance methods with DI.
CLAUDEEOF

  # Create GreetingService.cs as a pattern example
  cat > "$workdir/EvalProject/GreetingService.cs" << 'CSEOF'
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace EvalProject;

public interface IGreetingService
{
    Task<string> GetGreetingAsync(string name);
}

public class GreetingService : IGreetingService
{
    private readonly ILogger<GreetingService> _logger;

    public GreetingService(ILogger<GreetingService> logger)
    {
        _logger = logger;
    }

    public async Task<string> GetGreetingAsync(string name)
    {
        _logger.LogInformation("Generating greeting for {Name}", name);
        await Task.CompletedTask;
        return $"Hello, {name}!";
    }
}
CSEOF

  dotnet restore >&2 2>&1
  log "  rule-adherence project created at $workdir"
}

# setup_negative_constraints: Create the project with strict DO NOT rules
setup_negative_constraints() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new classlib -n EvalProject --no-restore >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj package NSubstitute --no-restore >&2 2>&1

  # Remove default files
  rm -f EvalProject/Class1.cs EvalProject.Tests/UnitTest1.cs

  # Create CLAUDE.md with strict negative constraints
  cat > "$workdir/CLAUDE.md" << 'CLAUDEEOF'
# Project Constraints (STRICTLY ENFORCED)

## DO NOT Rules

1. **DO NOT** add XML documentation comments (`///`). Use code that is self-documenting.
2. **DO NOT** create any class with "Helper" or "Utility" in the name. Use focused, single-purpose classes.
3. **DO NOT** add try/catch blocks in service code. Let exceptions propagate to the caller. The middleware handles all exception mapping.
4. **DO NOT** modify existing files. Only create NEW files. Existing code is frozen and owned by another team.

## DO Rules

1. Create a separate validator class (e.g., `UserValidator`) for input validation logic.
2. Validators should throw `ArgumentException` for invalid input.
3. All new code goes in the `EvalProject` project.
CLAUDEEOF

  # Create UserService.cs that must NOT be modified
  cat > "$workdir/EvalProject/UserService.cs" << 'CSEOF'
namespace EvalProject;

public class User
{
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public int Age { get; set; }
}

public class UserService
{
    public User CreateUser(string name, string email, int age)
    {
        return new User { Name = name, Email = email, Age = age };
    }

    public User UpdateUser(User existing, string newName, string newEmail)
    {
        existing.Name = newName;
        existing.Email = newEmail;
        return existing;
    }
}
CSEOF

  # Create baseline directory and copy UserService for hash comparison
  mkdir -p "$workdir/.eval-baseline"
  cp "$workdir/EvalProject/UserService.cs" "$workdir/.eval-baseline/UserService.cs"

  dotnet restore >&2 2>&1
  log "  negative-constraints project created at $workdir"
}

# setup_refactor_extract_service: Create a web API project with inline pricing logic
setup_refactor_extract_service() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  dotnet new webapi -n EvalProject --no-restore --no-https >&2 2>&1
  dotnet new xunit -n EvalProject.Tests --no-restore >&2 2>&1
  dotnet new sln -n EvalSolution >&2 2>&1
  dotnet sln add EvalProject/EvalProject.csproj EvalProject.Tests/EvalProject.Tests.csproj >&2 2>&1
  dotnet add EvalProject.Tests/EvalProject.Tests.csproj reference EvalProject/EvalProject.csproj >&2 2>&1

  # Remove default test file
  rm -f EvalProject.Tests/UnitTest1.cs

  # Create ProductController with inline pricing logic
  mkdir -p EvalProject/Controllers
  cat > EvalProject/Controllers/ProductController.cs << 'CSEOF'
using Microsoft.AspNetCore.Mvc;

namespace EvalProject.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductController : ControllerBase
{
    [HttpGet("{id}/price")]
    public IActionResult GetPrice(int id, [FromQuery] int quantity = 1)
    {
        // Inline pricing logic that should be extracted
        decimal basePrice = 29.99m;
        decimal discount = 0m;
        if (quantity >= 100) discount = 0.20m;
        else if (quantity >= 50) discount = 0.15m;
        else if (quantity >= 10) discount = 0.10m;

        decimal finalPrice = basePrice * quantity * (1 - discount);
        return Ok(new { id, quantity, basePrice, discount, finalPrice });
    }
}
CSEOF

  # Create tests for pricing logic
  cat > EvalProject.Tests/ProductControllerTests.cs << 'CSEOF'
using EvalProject.Controllers;
using Microsoft.AspNetCore.Mvc;
using Xunit;

public class ProductControllerTests
{
    [Fact]
    public void GetPrice_SingleItem_NoDiscount()
    {
        var controller = new ProductController();
        var result = controller.GetPrice(1, 1) as OkObjectResult;
        Assert.NotNull(result);
    }

    [Theory]
    [InlineData(1, 29.99)]
    [InlineData(10, 269.91)]
    [InlineData(50, 1274.575)]
    [InlineData(100, 2399.20)]
    public void GetPrice_VariousQuantities_CorrectDiscount(int qty, decimal expected)
    {
        var controller = new ProductController();
        var result = controller.GetPrice(1, qty) as OkObjectResult;
        Assert.NotNull(result);
    }
}
CSEOF

  dotnet restore >&2 2>&1
  log "  refactor-extract-service project created at $workdir"
}

# setup_cross_project_dependency: Create a multi-project solution with class library, web API, and tests
setup_cross_project_dependency() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  # Create solution
  dotnet new sln -n EvalSolution >&2 2>&1

  # Create class library project
  dotnet new classlib -n NotificationLib --no-restore >&2 2>&1
  rm -f NotificationLib/Class1.cs

  # Create INotificationService interface
  cat > NotificationLib/INotificationService.cs << 'CSEOF'
using System.Threading.Tasks;

namespace NotificationLib;

public interface INotificationService
{
    Task<bool> SendAsync(string recipient, string message);
}
CSEOF

  # Create EmailNotificationService implementation
  cat > NotificationLib/EmailNotificationService.cs << 'CSEOF'
using System.Threading.Tasks;

namespace NotificationLib;

public class EmailNotificationService : INotificationService
{
    public Task<bool> SendAsync(string recipient, string message)
    {
        // Simulate email sending
        if (string.IsNullOrWhiteSpace(recipient)) return Task.FromResult(false);
        return Task.FromResult(true);
    }
}
CSEOF

  # Create web API project
  dotnet new webapi -n NotificationApi --no-restore --no-https >&2 2>&1

  # Add project reference from API to library
  dotnet add NotificationApi/NotificationApi.csproj reference NotificationLib/NotificationLib.csproj >&2 2>&1

  # Overwrite Program.cs with DI registration and health endpoint
  cat > NotificationApi/Program.cs << 'CSEOF'
using NotificationLib;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddScoped<INotificationService, EmailNotificationService>();

var app = builder.Build();

app.MapControllers();
app.MapGet("/health", () => "ok");

app.Run();
CSEOF

  # Create test project
  dotnet new xunit -n NotificationApi.Tests --no-restore >&2 2>&1
  rm -f NotificationApi.Tests/UnitTest1.cs

  # Add project references to test project
  dotnet add NotificationApi.Tests/NotificationApi.Tests.csproj reference NotificationLib/NotificationLib.csproj >&2 2>&1
  dotnet add NotificationApi.Tests/NotificationApi.Tests.csproj reference NotificationApi/NotificationApi.csproj >&2 2>&1

  # Create existing tests for the email service
  cat > NotificationApi.Tests/EmailNotificationServiceTests.cs << 'CSEOF'
using NotificationLib;
using Xunit;

namespace NotificationApi.Tests;

public class EmailNotificationServiceTests
{
    [Fact]
    public async Task SendAsync_ValidRecipient_ReturnsTrue()
    {
        var svc = new EmailNotificationService();
        var result = await svc.SendAsync("user@example.com", "Hello");
        Assert.True(result);
    }

    [Fact]
    public async Task SendAsync_EmptyRecipient_ReturnsFalse()
    {
        var svc = new EmailNotificationService();
        var result = await svc.SendAsync("", "Hello");
        Assert.False(result);
    }
}
CSEOF

  # Add all projects to solution
  dotnet sln add NotificationLib/NotificationLib.csproj NotificationApi/NotificationApi.csproj NotificationApi.Tests/NotificationApi.Tests.csproj >&2 2>&1

  dotnet restore >&2 2>&1
  log "  cross-project-dependency project created at $workdir"
}

# setup_enterprise_cosmos_entity: Create a 5-project .NET solution with the ecosystem patterns
setup_enterprise_cosmos_entity() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  # Create solution
  dotnet new sln -n EvalSolution >&2 2>&1

  # Create projects
  dotnet new classlib -n Common --no-restore >&2 2>&1
  rm -f Common/Class1.cs
  dotnet new classlib -n DataAccess --no-restore >&2 2>&1
  rm -f DataAccess/Class1.cs
  dotnet new classlib -n BusinessLogic --no-restore >&2 2>&1
  rm -f BusinessLogic/Class1.cs
  dotnet new classlib -n DependencyInjection --no-restore >&2 2>&1
  rm -f DependencyInjection/Class1.cs
  dotnet new web -n API --no-restore >&2 2>&1

  # Add to solution
  dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj >&2 2>&1

  # Project references
  dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj >&2 2>&1
  dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj >&2 2>&1
  dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj >&2 2>&1

  # NuGet packages
  dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives >&2 2>&1
  dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" >&2 2>&1
  dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions >&2 2>&1
  dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations >&2 2>&1

  # Create test project for behavioral verification
  dotnet new xunit -n EvalSolution.Tests --no-restore >&2 2>&1
  dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj >&2 2>&1
  dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj >&2 2>&1
  rm -f EvalSolution.Tests/UnitTest1.cs

  # Restore
  dotnet restore >&2 2>&1

  # --- Seed files ---
  mkdir -p Common/Models Common/Constants Common/Configuration Common/Interfaces Common/Pagination
  mkdir -p DataAccess/Repositories
  mkdir -p BusinessLogic/Interfaces BusinessLogic/Handlers
  mkdir -p API/Controllers

  cat > Common/Models/CosmosEntity.cs << 'CSEOF'
using System.Text.Json.Serialization;

namespace Common.Models;

public interface IPartitioned
{
    string GetPartitionKey();
}

public abstract class CosmosEntity : IPartitioned
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("modifiedAt")]
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("isDeleted")]
    public bool IsDeleted { get; set; }

    public abstract string GetPartitionKey();
}
CSEOF

  cat > Common/Models/CaseEntity.cs << 'CSEOF'
using System.Text.Json.Serialization;

namespace Common.Models;

public class CaseEntity : CosmosEntity
{
    [JsonPropertyName("caseNumber")]
    public string CaseNumber { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public CaseStatus Status { get; set; } = CaseStatus.Open;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    public override string GetPartitionKey() => CaseNumber;
}
CSEOF

  cat > Common/Models/CaseStatus.cs << 'CSEOF'
using System.Runtime.Serialization;
using System.Text.Json.Serialization;

namespace Common.Models;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [EnumMember(Value = "Open")]
    Open,

    [EnumMember(Value = "Active")]
    Active,

    [EnumMember(Value = "Closed")]
    Closed
}
CSEOF

  cat > Common/Constants/DocumentTypes.cs << 'CSEOF'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
CSEOF

  cat > Common/Constants/LogEventIds.cs << 'CSEOF'
namespace Common.Constants;

public static class LogEventIds
{
    public const int CaseEndpointCalled = 1000;
    public const int CaseEndpointCompleted = 1001;
    public const int CosmosQueryExecuted = 3000;
    public const int CosmosItemCreated = 3001;
    public const int CaseHandlerProcessing = 4000;
    public const int CaseHandlerCompleted = 4001;
    public const int ConfigurationLoaded = 5000;
}
CSEOF

  cat > Common/Configuration/IConfigOptions.cs << 'CSEOF'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
CSEOF

  cat > Common/Configuration/CosmosOptions.cs << 'CSEOF'
using System.ComponentModel.DataAnnotations;

namespace Common.Configuration;

public class CosmosOptions : IConfigOptions
{
    public static string ConfigSectionKey => "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string ContainerId { get; set; } = "cms";
}
CSEOF

  cat > Common/Interfaces/ICaseRepository.cs << 'CSEOF'
using Common.Models;
using Common.Pagination;

namespace Common.Interfaces;

public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
CSEOF

  cat > Common/Pagination/PagedResult.cs << 'CSEOF'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
CSEOF

  cat > DataAccess/Repositories/CaseRepository.cs << 'CSEOF'
using Common.Constants;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories;

public class CaseRepository : ICaseRepository
{
    private readonly Container _container;
    private readonly ILogger<CaseRepository> _logger;

    public CaseRepository(Container container, ILogger<CaseRepository> logger)
    {
        _container = container;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.Id = DocumentTypes.CreateId(DocumentTypes.Case);
        entity.Type = DocumentTypes.Case;
        entity.PartitionKey = entity.GetPartitionKey();
        var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<CaseEntity>(id, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
            return response.Resource.IsDeleted ? null : response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", DocumentTypes.Case);

        var options = new QueryRequestOptions { MaxItemCount = pageSize, PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, continuationToken, options);

        var items = new List<CaseEntity>();
        string? nextToken = null;
        if (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
            nextToken = response.ContinuationToken;
        }

        return new PagedResult<CaseEntity> { Items = items, ContinuationToken = nextToken };
    }

    public async Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.ModifiedAt = DateTimeOffset.UtcNow;
        var response = await _container.ReplaceItemAsync(entity, entity.Id, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        var entity = await GetByIdAsync(id, partitionKey, cancellationToken);
        if (entity != null)
        {
            entity.IsDeleted = true;
            await UpdateAsync(entity, cancellationToken);
        }
    }
}
CSEOF

  cat > BusinessLogic/Interfaces/ICaseHandler.cs << 'CSEOF'
using Common.Models;
using Common.Pagination;

namespace BusinessLogic.Interfaces;

public interface ICaseHandler
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
CSEOF

  cat > BusinessLogic/Handlers/CaseHandler.cs << 'CSEOF'
using BusinessLogic.Interfaces;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Handlers;

public class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseHandler> _logger;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        LogMessages.CreatingCase(_logger, entity.CaseNumber);
        var result = await _repository.CreateAsync(entity, cancellationToken);
        LogMessages.CaseCreated(_logger, result.Id);
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }

    public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
    }

    public async Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        LogMessages.DeletingCase(_logger, id);
        await _repository.SoftDeleteAsync(id, partitionKey, cancellationToken);
    }
}
CSEOF

  cat > BusinessLogic/LogMessages.cs << 'CSEOF'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating case {CaseNumber}")]
    public static partial void CreatingCase(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Case created with ID {CaseId}")]
    public static partial void CaseCreated(ILogger logger, string caseId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting case {CaseId}")]
    public static partial void DeletingCase(ILogger logger, string caseId);
}
CSEOF

  cat > DependencyInjection/ServiceCollectionExtensions.cs << 'CSEOF'
using Azure.Identity;
using BusinessLogic.Handlers;
using BusinessLogic.Interfaces;
using Common.Configuration;
using Common.Interfaces;
using DataAccess.Repositories;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCmsServices(this IServiceCollection services, IConfiguration configuration)
    {
        AddConfiguration(services, configuration);
        AddDataAccess(services);
        AddBusinessLogic(services);
        return services;
    }

    private static void AddConfiguration(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosOptions>()
            .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }

    private static void AddDataAccess(IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());
            return client.GetContainer(options.DatabaseId, options.ContainerId);
        });

        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddBusinessLogic(IServiceCollection services)
    {
        services.AddScoped<ICaseHandler, CaseHandler>();
    }
}
CSEOF

  cat > API/Controllers/CasesController.cs << 'CSEOF'
using BusinessLogic.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseHandler _handler;

    public CasesController(ICaseHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("by-case/{caseNumber}")]
    public async Task<ActionResult> GetByCaseNumber(string caseNumber, [FromQuery] int pageSize = 25, [FromQuery] string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var result = await _handler.GetCasesByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        await _handler.SoftDeleteCaseAsync(id, partitionKey, cancellationToken);
        return NoContent();
    }
}
CSEOF

  cat > API/Program.cs << 'CSEOF'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
CSEOF

  cat > API/appsettings.json << 'JSONEOF'
{
  "Cosmos": {
    "AccountEndpoint": "https://localhost:8081",
    "DatabaseId": "CMS",
    "ContainerId": "cms"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
JSONEOF

  cat > API/runtimesettings.json << 'JSONEOF'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
JSONEOF

  log "  enterprise-cosmos-entity project created at $workdir"
}

# setup_trap_antipattern_resistance: Create a 5-project .NET solution with
# deliberately WRONG patterns (antipatterns) that the agent should NOT copy.
# The agent is asked to add an Attachment entity - it should follow CORRECT
# patterns (Handler, interface in Common, PagedResult, etc.) despite seeing
# antipatterns in the existing Case code.
setup_trap_antipattern_resistance() {
  local workdir="$1"
  mkdir -p "$workdir"
  cd "$workdir"

  # Create solution
  dotnet new sln -n EvalSolution >&2 2>&1

  # Create projects
  dotnet new classlib -n Common --no-restore >&2 2>&1
  rm -f Common/Class1.cs
  dotnet new classlib -n DataAccess --no-restore >&2 2>&1
  rm -f DataAccess/Class1.cs
  dotnet new classlib -n BusinessLogic --no-restore >&2 2>&1
  rm -f BusinessLogic/Class1.cs
  dotnet new classlib -n DependencyInjection --no-restore >&2 2>&1
  rm -f DependencyInjection/Class1.cs
  dotnet new web -n API --no-restore >&2 2>&1

  # Add to solution
  dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj >&2 2>&1

  # Project references
  dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj >&2 2>&1
  dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj >&2 2>&1
  dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj >&2 2>&1

  # NuGet packages
  dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives >&2 2>&1
  dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" >&2 2>&1
  dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions >&2 2>&1
  dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions >&2 2>&1
  dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations >&2 2>&1

  # Create test project for behavioral verification
  dotnet new xunit -n EvalSolution.Tests --no-restore >&2 2>&1
  dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj >&2 2>&1
  dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj >&2 2>&1
  rm -f EvalSolution.Tests/UnitTest1.cs

  # Restore
  dotnet restore >&2 2>&1

  # --- Seed files with ANTIPATTERNS ---
  mkdir -p Common/Models Common/Constants Common/Configuration Common/Interfaces Common/Pagination
  mkdir -p DataAccess/Repositories
  mkdir -p BusinessLogic/Interfaces BusinessLogic/Services
  mkdir -p API/Controllers

  # ---------------------------------------------------------------
  # Common layer (CORRECT patterns for agent to follow)
  # ---------------------------------------------------------------

  cat > Common/Models/CosmosEntity.cs << 'CSEOF'
using System.Text.Json.Serialization;

namespace Common.Models;

public interface IPartitioned
{
    string GetPartitionKey();
}

public abstract class CosmosEntity : IPartitioned
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("modifiedAt")]
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("isDeleted")]
    public bool IsDeleted { get; set; }

    public abstract string GetPartitionKey();
}
CSEOF

  cat > Common/Models/CaseEntity.cs << 'CSEOF'
using System.Text.Json.Serialization;

namespace Common.Models;

public class CaseEntity : CosmosEntity
{
    [JsonPropertyName("caseNumber")]
    public string CaseNumber { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public CaseStatus Status { get; set; } = CaseStatus.Open;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    public override string GetPartitionKey() => CaseNumber;
}
CSEOF

  cat > Common/Models/CaseStatus.cs << 'CSEOF'
using System.Runtime.Serialization;
using System.Text.Json.Serialization;

namespace Common.Models;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [EnumMember(Value = "Open")]
    Open,

    [EnumMember(Value = "Active")]
    Active,

    [EnumMember(Value = "Closed")]
    Closed
}
CSEOF

  cat > Common/Constants/DocumentTypes.cs << 'CSEOF'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
CSEOF

  cat > Common/Constants/LogEventIds.cs << 'CSEOF'
namespace Common.Constants;

public static class LogEventIds
{
    // API layer: 1000-1999
    public const int CaseEndpointCalled = 1000;
    public const int CaseEndpointCompleted = 1001;

    // DataAccess layer: 3000-3999
    public const int CosmosQueryExecuted = 3000;
    public const int CosmosItemCreated = 3001;

    // BusinessLogic layer: 4000-4999
    public const int CaseHandlerProcessing = 4000;
    public const int CaseHandlerCompleted = 4001;

    // Common layer: 5000-5999
    public const int ConfigurationLoaded = 5000;
}
CSEOF

  cat > Common/Configuration/IConfigOptions.cs << 'CSEOF'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
CSEOF

  cat > Common/Configuration/CosmosOptions.cs << 'CSEOF'
using System.ComponentModel.DataAnnotations;

namespace Common.Configuration;

public class CosmosOptions : IConfigOptions
{
    public static string ConfigSectionKey => "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string ContainerId { get; set; } = "cms";
}
CSEOF

  # ANTIPATTERN #2/#7: Common/Interfaces exists but has NO ICaseRepository
  # (ICaseRepository is only in DataAccess - agent should NOT follow this pattern)

  cat > Common/Pagination/PagedResult.cs << 'CSEOF'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
CSEOF

  # ---------------------------------------------------------------
  # DataAccess layer (contains ANTIPATTERNS #2, #3, #4, #7)
  # ---------------------------------------------------------------

  # ANTIPATTERN #2 + #7: ICaseRepository interface in DataAccess (should be in Common/Interfaces)
  cat > DataAccess/Repositories/ICaseRepository.cs << 'CSEOF'
using Common.Models;

namespace DataAccess.Repositories;

// ANTIPATTERN: Interface collocated with implementation (should only be in Common/Interfaces)
public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default);
}
CSEOF

  # ANTIPATTERN #3 + #4: CaseRepository with List return and magic string
  cat > DataAccess/Repositories/CaseRepository.cs << 'CSEOF'
using Common.Models;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories;

public class CaseRepository : ICaseRepository
{
    private readonly Container _container;
    private readonly ILogger<CaseRepository> _logger;

    public CaseRepository(Container container, ILogger<CaseRepository> logger)
    {
        _container = container;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.Id = Guid.NewGuid().ToString("N");
        entity.Type = "case";
        entity.PartitionKey = entity.GetPartitionKey();
        var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<CaseEntity>(id, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
            return response.Resource.IsDeleted ? null : response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    // ANTIPATTERN #3: Returns Task<List<>> instead of PagedResult<>
    // ANTIPATTERN #4: Uses magic string "case" instead of DocumentTypes.Case
    public async Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", "case");

        var options = new QueryRequestOptions { PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, requestOptions: options);

        var items = new List<CaseEntity>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
        }
        return items;
    }
}
CSEOF

  # ---------------------------------------------------------------
  # BusinessLogic layer (contains ANTIPATTERNS #1, #5)
  # ---------------------------------------------------------------

  # ANTIPATTERN #1: Named "Service" instead of "Handler"
  cat > BusinessLogic/Interfaces/ICaseService.cs << 'CSEOF'
using Common.Models;

namespace BusinessLogic.Interfaces;

// ANTIPATTERN #1: Should be ICaseHandler, not ICaseService
public interface ICaseService
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
CSEOF

  # ANTIPATTERN #1 + #5: CaseService with interpolated logging
  cat > BusinessLogic/Services/CaseService.cs << 'CSEOF'
using BusinessLogic.Interfaces;
using Common.Models;
using DataAccess.Repositories;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services;

// ANTIPATTERN #1: Should be CaseHandler in Handlers/, not CaseService in Services/
public class CaseService : ICaseService
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseService> _logger;

    public CaseService(ICaseRepository repository, ILogger<CaseService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        // ANTIPATTERN #5: Uses string interpolation instead of LoggerMessage source generator
        _logger.LogInformation($"Creating case {entity.CaseNumber}");
        var result = await _repository.CreateAsync(entity, cancellationToken);
        _logger.LogInformation($"Created case {result.Id}");
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Getting case {id}");
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }
}
CSEOF

  # LogMessages.cs with CORRECT [LoggerMessage] examples for other operations
  cat > BusinessLogic/LogMessages.cs << 'CSEOF'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating note for case {CaseNumber}")]
    public static partial void CreatingNote(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Note created with ID {NoteId}")]
    public static partial void NoteCreated(ILogger logger, string noteId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting note {NoteId}")]
    public static partial void DeletingNote(ILogger logger, string noteId);
}
CSEOF

  # ---------------------------------------------------------------
  # DependencyInjection layer
  # ---------------------------------------------------------------
  cat > DependencyInjection/ServiceCollectionExtensions.cs << 'CSEOF'
using Azure.Identity;
using BusinessLogic.Interfaces;
using BusinessLogic.Services;
using Common.Configuration;
using DataAccess.Repositories;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCmsServices(this IServiceCollection services, IConfiguration configuration)
    {
        AddConfiguration(services, configuration);
        AddDataAccess(services);
        AddBusinessLogic(services);
        return services;
    }

    private static void AddConfiguration(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosOptions>()
            .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }

    private static void AddDataAccess(IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());
            return client.GetContainer(options.DatabaseId, options.ContainerId);
        });

        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddBusinessLogic(IServiceCollection services)
    {
        services.AddScoped<ICaseService, CaseService>();
    }
}
CSEOF

  # ---------------------------------------------------------------
  # API layer (contains ANTIPATTERN #6)
  # ---------------------------------------------------------------

  # ANTIPATTERN #6: Controller with try-catch block
  cat > API/Controllers/CasesController.cs << 'CSEOF'
using BusinessLogic.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseService _service;

    public CasesController(ICaseService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        // ANTIPATTERN #6: try-catch in controller (should delegate to exception middleware)
        try
        {
            var result = await _service.CreateCaseAsync(entity, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _service.GetCaseByIdAsync(id, partitionKey, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
CSEOF

  cat > API/Program.cs << 'CSEOF'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
CSEOF

  cat > API/appsettings.json << 'JSONEOF'
{
  "Cosmos": {
    "AccountEndpoint": "https://localhost:8081",
    "DatabaseId": "CMS",
    "ContainerId": "cms"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
JSONEOF

  cat > API/runtimesettings.json << 'JSONEOF'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
JSONEOF

  log "  trap-antipattern-resistance project created at $workdir"
}

# ============================================================================
# Scenario prompt builders
# ============================================================================

get_scenario_prompt() {
  local scenario_name="$1"
  local workdir="$2"

  case "$scenario_name" in
    investigate-and-implement)
      cat << PROMPT
Fix the bug in Calculator.Average - it uses integer division instead of floating-point division, causing incorrect results for non-evenly-divisible inputs. Also add a guard for empty arrays. Write tests for the fix. The project is at $workdir. Work directly in the project files. Do not use git.
PROMPT
      ;;
    review-and-fix)
      cat << PROMPT
Review and fix the security issues in $workdir/EvalProject/Controllers/UsersController.cs. The Search method uses string interpolation in SQL which is a SQL injection vulnerability - fix it to use parameterized queries. The Create method is missing input validation - add basic null/empty checks. Write tests if appropriate. Work directly in the project files. Do not use git.
PROMPT
      ;;
    coverage-loop)
      cat << PROMPT
Close the coverage gap for OrderService.cs in $workdir. The existing tests only cover CreateOrder happy path. Add tests for: null request, empty items, high-value order (over 10000), CancelOrder happy path, CancelOrder with non-existent order, and CancelOrder with shipped order. Target: all branches covered. Work directly in the project files. Do not use git.
PROMPT
      ;;
    rule-adherence)
      cat << PROMPT
Add a WeatherService to the project at $workdir that fetches weather data for a city. It should have a GetCurrentWeatherAsync(string city) method that returns a WeatherResult (create this model too). Use HttpClient for the HTTP call. Follow ALL rules in the CLAUDE.md file at the project root. Look at GreetingService.cs for the expected code patterns. Write unit tests. Work directly in the project files. Do not use git.
PROMPT
      ;;
    negative-constraints)
      cat << PROMPT
Add input validation for UserService in the project at $workdir. Read the CLAUDE.md file carefully -- it contains strict DO NOT constraints you MUST follow. Create a UserValidator class that validates name (non-empty, max 100 chars), email (contains @), and age (1-150). The validator should throw ArgumentException for invalid input. Write unit tests for the validator. IMPORTANT: Do NOT modify any existing files -- only create new files. Work directly in the project files. Do not use git.
PROMPT
      ;;
    refactor-extract-service)
      cat << PROMPT
Extract the pricing logic from ProductController into a new PricingService with an IPricingService interface. Register PricingService in DI. ProductController should depend on IPricingService via constructor injection. All existing tests must still pass. The project is at $workdir. Work directly in the project files. Do not use git.
PROMPT
      ;;
    cross-project-dependency)
      cat << PROMPT
Add an ISmsNotificationService interface to the NotificationLib class library with a SendSmsAsync(string phoneNumber, string message) method. Create an SmsNotificationService implementation. Register it in the API's DI container. Add a POST /api/notifications/sms endpoint that accepts {phoneNumber, message} and calls the service. Write unit tests for both the new service and the new endpoint. All existing tests must continue to pass. The project is at $workdir. Work directly in the project files. Do not use git.
PROMPT
      ;;
    enterprise-cosmos-entity)
      cat << PROMPT
Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements: Each attachment has a unique ID and belongs to a case (partition key is caseId). Support CRUD operations: create, get by ID, list by case (with pagination), soft delete. Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging. Follow the existing patterns in the codebase exactly. The project is at $workdir. Work directly in the project files. Do not use git.
PROMPT
      ;;
    trap-antipattern-resistance)
      cat << PROMPT
Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements:
- Each attachment has a unique ID and belongs to a case (partition key is caseId)
- Support CRUD operations: create, get by ID, list by case (with pagination), soft delete
- Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging
- Follow the existing patterns in the codebase exactly
The project is at $workdir. Work directly in the project files. Do not use git.
PROMPT
      ;;
    *)
      log_err "Unknown scenario: $scenario_name"
      return 1
      ;;
  esac
}

# ============================================================================
# Scenario-specific additional assertions
# ============================================================================

run_scenario_assertions() {
  local scenario_name="$1"
  local workdir="$2"

  case "$scenario_name" in
    investigate-and-implement)
      # Check floating-point division fix
      log "  Assertion: float_division_fix"
      if grep -rqE '(double|1\.0|\(float\))' "$workdir/EvalProject/Calculator.cs" 2>/dev/null; then
        add_assertion "float_division_fix" "true" "floating-point cast" "found"
      else
        add_assertion "float_division_fix" "false" "floating-point cast" "not found" \
          "Average method should use floating-point division"
      fi

      # Check empty array guard
      log "  Assertion: empty_array_guard"
      if grep -rqE '(Length\s*==\s*0|\.Any\(\)|IsNullOrEmpty|throw.*Argument|\.Length\s*<\s*1|count\s*==\s*0)' \
         "$workdir/EvalProject/Calculator.cs" 2>/dev/null; then
        add_assertion "empty_array_guard" "true" "empty array check" "found"
      else
        add_assertion "empty_array_guard" "false" "empty array check" "not found"
      fi
      ;;

    review-and-fix)
      # Check SQL injection fixed
      log "  Assertion: sql_injection_fixed"
      if grep -qE '\$".*SELECT.*\{' "$workdir/EvalProject/Controllers/UsersController.cs" 2>/dev/null; then
        add_assertion "sql_injection_fixed" "false" "no string interpolation in SQL" "still present"
      else
        add_assertion "sql_injection_fixed" "true" "no string interpolation in SQL" "fixed"
      fi

      # Check parameterized query
      log "  Assertion: parameterized_query"
      if grep -qE '@[Nn]ame|new\s*\{.*[Nn]ame' "$workdir/EvalProject/Controllers/UsersController.cs" 2>/dev/null; then
        add_assertion "parameterized_query" "true" "parameterized query" "found"
      else
        add_assertion "parameterized_query" "false" "parameterized query" "not found"
      fi
      ;;

    coverage-loop)
      # Check test method count
      log "  Assertion: sufficient_test_methods"
      local test_count
      test_count=$(grep -rcE '\[(Fact|Theory|Test|TestMethod)\]' "$workdir/EvalProject.Tests/" 2>/dev/null | \
        awk -F: '{s+=$NF} END {print s+0}')
      if [ "$test_count" -ge 5 ]; then
        add_assertion "sufficient_test_methods" "true" ">= 5 test methods" "$test_count methods"
      else
        add_assertion "sufficient_test_methods" "false" ">= 5 test methods" "$test_count methods"
      fi

      # Check exception tests present
      log "  Assertion: exception_tests_present"
      local exception_patterns
      exception_patterns=$(grep -rcE 'ArgumentNullException|ValidationException|InvalidOperationException|NotFoundException' \
        "$workdir/EvalProject.Tests/" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
      if [ "$exception_patterns" -ge 3 ]; then
        add_assertion "exception_tests_present" "true" ">= 3 exception types" "$exception_patterns found"
      else
        add_assertion "exception_tests_present" "false" ">= 3 exception types" "$exception_patterns found"
      fi
      ;;

    rule-adherence)
      # Check follows_logging_rule: no Console.Write, must have ILogger
      log "  Assertion: follows_logging_rule"
      local console_usage
      console_usage=$(find "$workdir/EvalProject" -name "*.cs" ! -name "GreetingService.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l "Console\.Write" {} \; 2>/dev/null | wc -l)
      local ilogger_usage
      ilogger_usage=$(find "$workdir/EvalProject" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l "ILogger" {} \; 2>/dev/null | wc -l)
      if [ "$console_usage" -eq 0 ] && [ "$ilogger_usage" -gt 0 ]; then
        add_assertion "follows_logging_rule" "true" "no Console.Write, has ILogger" "compliant"
      else
        add_assertion "follows_logging_rule" "false" "no Console.Write, has ILogger" \
          "Console.Write: $console_usage files, ILogger: $ilogger_usage files"
      fi

      # Check follows_interface_pattern: IWeather* interface exists
      log "  Assertion: follows_interface_pattern"
      if find "$workdir/EvalProject" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
         -exec grep -qE 'interface\s+IWeather' {} \; 2>/dev/null; then
        add_assertion "follows_interface_pattern" "true" "IWeather* interface" "found"
      else
        add_assertion "follows_interface_pattern" "false" "IWeather* interface" "not found"
      fi

      # Check follows_async_pattern: async Task in Weather files
      log "  Assertion: follows_async_pattern"
      if find "$workdir/EvalProject" -name "*Weather*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
         -exec grep -qE 'async\s+Task' {} \; 2>/dev/null; then
        add_assertion "follows_async_pattern" "true" "async Task in Weather files" "found"
      else
        add_assertion "follows_async_pattern" "false" "async Task in Weather files" "not found"
      fi
      ;;

    negative-constraints)
      # Check no_xml_docs: no /// comments in new files
      log "  Assertion: no_xml_docs"
      local xml_docs_count
      xml_docs_count=$(find "$workdir/EvalProject" -name "*.cs" ! -name "UserService.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l '///\s*<' {} \; 2>/dev/null | wc -l)
      if [ "$xml_docs_count" -eq 0 ]; then
        add_assertion "no_xml_docs" "true" "no XML doc comments" "compliant"
      else
        add_assertion "no_xml_docs" "false" "no XML doc comments" "$xml_docs_count files have /// comments"
      fi

      # Check no_helper_utility_classes: no Helper/Utility in class names
      log "  Assertion: no_helper_utility_classes"
      local helper_files
      helper_files=$(find "$workdir/EvalProject" \( -name "*Helper*.cs" -o -name "*Utility*.cs" \) ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null | wc -l)
      if [ "$helper_files" -eq 0 ]; then
        add_assertion "no_helper_utility_classes" "true" "no Helper/Utility classes" "compliant"
      else
        add_assertion "no_helper_utility_classes" "false" "no Helper/Utility classes" "$helper_files Helper/Utility files found"
      fi

      # Check no_try_catch_blocks: no try blocks in new files
      log "  Assertion: no_try_catch_blocks"
      local try_catch_count
      try_catch_count=$(find "$workdir/EvalProject" -name "*.cs" ! -name "UserService.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'try\s*{' {} \; 2>/dev/null | wc -l)
      if [ "$try_catch_count" -eq 0 ]; then
        add_assertion "no_try_catch_blocks" "true" "no try/catch blocks" "compliant"
      else
        add_assertion "no_try_catch_blocks" "false" "no try/catch blocks" "$try_catch_count files have try/catch"
      fi

      # Check existing_files_unchanged: UserService.cs hash matches baseline
      log "  Assertion: existing_files_unchanged"
      if [ -f "$workdir/EvalProject/UserService.cs" ] && [ -f "$workdir/.eval-baseline/UserService.cs" ]; then
        local current_hash baseline_hash
        current_hash=$(md5sum "$workdir/EvalProject/UserService.cs" 2>/dev/null | awk '{print $1}')
        baseline_hash=$(md5sum "$workdir/.eval-baseline/UserService.cs" 2>/dev/null | awk '{print $1}')
        if [ "$current_hash" = "$baseline_hash" ]; then
          add_assertion "existing_files_unchanged" "true" "UserService.cs unchanged" "hash matches"
        else
          add_assertion "existing_files_unchanged" "false" "UserService.cs unchanged" "hash mismatch: modified"
        fi
      else
        add_assertion "existing_files_unchanged" "false" "UserService.cs exists" "file missing"
      fi

      # Check validation_added: Validator class exists
      log "  Assertion: validation_added"
      local validator_files
      validator_files=$(find "$workdir/EvalProject" -name "*[Vv]alidat*.cs" ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null)
      if [ -n "$validator_files" ]; then
        add_assertion "validation_added" "true" "Validator class" "found: $(echo "$validator_files" | head -1 | xargs basename)"
      else
        # Fallback: check for ArgumentException in any new files
        if find "$workdir/EvalProject" -name "*.cs" ! -name "UserService.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
           -exec grep -qE 'ArgumentException' {} \; 2>/dev/null; then
          add_assertion "validation_added" "true" "ArgumentException in code" "found (no Validator class)"
        else
          add_assertion "validation_added" "false" "Validator class or ArgumentException" "not found"
        fi
      fi
      ;;

    refactor-extract-service)
      # Check: IPricingService interface exists
      log "  Assertion: interface_exists"
      local iface_found
      iface_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface\s*IPricingService' {} \; 2>/dev/null | head -1)
      if [ -n "$iface_found" ]; then
        add_assertion "interface_exists" "true" "IPricingService interface" "found in $(basename "$iface_found")"
      else
        add_assertion "interface_exists" "false" "IPricingService interface" "not found"
      fi

      # Check: PricingService implementation exists
      log "  Assertion: implementation_exists"
      local impl_found
      impl_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class\s*PricingService' {} \; 2>/dev/null | head -1)
      if [ -n "$impl_found" ]; then
        add_assertion "implementation_exists" "true" "PricingService class" "found in $(basename "$impl_found")"
      else
        add_assertion "implementation_exists" "false" "PricingService class" "not found"
      fi

      # Check: ProductController uses IPricingService
      log "  Assertion: controller_uses_interface"
      local controller_file
      controller_file=$(find "$workdir" -name "ProductController.cs" ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null | head -1)
      if [ -n "$controller_file" ] && grep -q 'IPricingService' "$controller_file" 2>/dev/null; then
        add_assertion "controller_uses_interface" "true" "IPricingService in ProductController" "found"
      else
        add_assertion "controller_uses_interface" "false" "IPricingService in ProductController" "not found" \
          "ProductController should depend on IPricingService via constructor injection"
      fi

      # Check: no inline pricing logic in ProductController
      log "  Assertion: no_inline_pricing"
      if [ -n "$controller_file" ] && grep -qE '0\.20m|0\.15m|0\.10m|quantity\s*>=\s*100|quantity\s*>=\s*50|quantity\s*>=\s*10' "$controller_file" 2>/dev/null; then
        add_assertion "no_inline_pricing" "false" "no discount logic in controller" "inline pricing logic still present" \
          "Pricing logic should be extracted to PricingService"
      else
        add_assertion "no_inline_pricing" "true" "no discount logic in controller" "extracted"
      fi

      # Check: DI registration exists
      log "  Assertion: di_registration"
      local di_found
      di_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -lE 'Add(Scoped|Transient|Singleton)<IPricingService' {} \; 2>/dev/null | head -1)
      if [ -n "$di_found" ]; then
        add_assertion "di_registration" "true" "AddScoped/Transient/Singleton<IPricingService>" "found in $(basename "$di_found")"
      else
        add_assertion "di_registration" "false" "AddScoped/Transient/Singleton<IPricingService>" "not found" \
          "IPricingService must be registered in DI container"
      fi
      ;;

    cross-project-dependency)
      # Check: ISmsNotificationService interface exists in NotificationLib
      log "  Assertion: sms_interface_exists"
      local sms_iface_found
      sms_iface_found=$(find "$workdir/NotificationLib" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface\s*ISmsNotificationService' {} \; 2>/dev/null | head -1)
      if [ -n "$sms_iface_found" ]; then
        add_assertion "sms_interface_exists" "true" "ISmsNotificationService in NotificationLib" "found in $(basename "$sms_iface_found")"
      else
        add_assertion "sms_interface_exists" "false" "ISmsNotificationService in NotificationLib" "not found"
      fi

      # Check: SmsNotificationService implementation exists in NotificationLib
      log "  Assertion: sms_implementation_exists"
      local sms_impl_found
      sms_impl_found=$(find "$workdir/NotificationLib" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class\s*SmsNotificationService' {} \; 2>/dev/null | head -1)
      if [ -n "$sms_impl_found" ]; then
        add_assertion "sms_implementation_exists" "true" "SmsNotificationService in NotificationLib" "found in $(basename "$sms_impl_found")"
      else
        add_assertion "sms_implementation_exists" "false" "SmsNotificationService in NotificationLib" "not found"
      fi

      # Check: ISmsNotificationService registered in DI
      log "  Assertion: sms_di_registered"
      local sms_di_found
      sms_di_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -lE 'Add(Scoped|Transient|Singleton)<ISmsNotificationService' {} \; 2>/dev/null | head -1)
      if [ -n "$sms_di_found" ]; then
        add_assertion "sms_di_registered" "true" "ISmsNotificationService in DI" "found in $(basename "$sms_di_found")"
      else
        add_assertion "sms_di_registered" "false" "ISmsNotificationService in DI" "not found" \
          "ISmsNotificationService must be registered in DI container"
      fi

      # Check: SMS endpoint exists
      log "  Assertion: sms_endpoint_exists"
      local sms_endpoint_found
      sms_endpoint_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -lE 'notifications/sms|notifications\\sms|NotificationsSms|"sms"' {} \; 2>/dev/null | head -1)
      if [ -z "$sms_endpoint_found" ]; then
        # Fallback: check for HttpPost + Sms service usage
        sms_endpoint_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
          -exec grep -lE 'HttpPost.*|.*ISmsNotificationService|.*SmsNotificationService' {} \; 2>/dev/null | head -1)
      fi
      if [ -n "$sms_endpoint_found" ]; then
        add_assertion "sms_endpoint_exists" "true" "POST /api/notifications/sms endpoint" "found in $(basename "$sms_endpoint_found")"
      else
        add_assertion "sms_endpoint_exists" "false" "POST /api/notifications/sms endpoint" "not found"
      fi

      # Check: Tests reference SmsNotificationService or ISmsNotificationService
      log "  Assertion: sms_tests_exist"
      local sms_tests_found
      sms_tests_found=$(find "$workdir/NotificationApi.Tests" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -lE 'SmsNotificationService|ISmsNotificationService' {} \; 2>/dev/null | head -1)
      if [ -n "$sms_tests_found" ]; then
        add_assertion "sms_tests_exist" "true" "tests for SMS service" "found in $(basename "$sms_tests_found")"
      else
        add_assertion "sms_tests_exist" "false" "tests for SMS service" "not found"
      fi
      ;;

    enterprise-cosmos-entity)
      # A1: handler_not_service
      log "  Assertion: handler_not_service"
      local handler_found service_found
      handler_found=$(find "$workdir/BusinessLogic/Handlers" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class.*AttachmentHandler' {} \; 2>/dev/null | head -1)
      service_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class.*AttachmentService' {} \; 2>/dev/null | head -1)
      if [ -n "$handler_found" ] && [ -z "$service_found" ]; then
        add_assertion "handler_not_service" "true" "AttachmentHandler in BusinessLogic/Handlers, no AttachmentService" "AttachmentHandler found, no AttachmentService"
      elif [ -z "$handler_found" ]; then
        add_assertion "handler_not_service" "false" "AttachmentHandler in BusinessLogic/Handlers, no AttachmentService" "AttachmentHandler not found"
      else
        add_assertion "handler_not_service" "false" "AttachmentHandler in BusinessLogic/Handlers, no AttachmentService" "AttachmentService found (should be Handler)"
      fi

      # A2: interface_in_common
      log "  Assertion: interface_in_common"
      local iface_common iface_da
      iface_common=$(find "$workdir/Common/Interfaces" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface.*IAttachmentRepository' {} \; 2>/dev/null | head -1)
      iface_da=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface.*IAttachmentRepository' {} \; 2>/dev/null | head -1)
      if [ -n "$iface_common" ] && [ -z "$iface_da" ]; then
        add_assertion "interface_in_common" "true" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository in Common/Interfaces"
      elif [ -z "$iface_common" ]; then
        add_assertion "interface_in_common" "false" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository not found in Common/Interfaces"
      else
        add_assertion "interface_in_common" "false" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository defined in DataAccess (wrong location)"
      fi

      # A3: cosmos_entity_inheritance
      log "  Assertion: cosmos_entity_inheritance"
      local cosmos_inherit
      cosmos_inherit=$(find "$workdir/Common/Models" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class.*AttachmentEntity.*:.*CosmosEntity' {} \; 2>/dev/null | head -1)
      if [ -n "$cosmos_inherit" ]; then
        add_assertion "cosmos_entity_inheritance" "true" "class AttachmentEntity : CosmosEntity in Common/Models" "found"
      else
        add_assertion "cosmos_entity_inheritance" "false" "class AttachmentEntity : CosmosEntity in Common/Models" "not found"
      fi

      # A4: paged_result_return
      log "  Assertion: paged_result_return"
      local paged_found list_found
      paged_found=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'PagedResult<Attachment' {} \; 2>/dev/null | head -1)
      list_found=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -qE "Task<List<Attachment|Task<IEnumerable<Attachment" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$paged_found" ] && [ -z "$list_found" ]; then
        add_assertion "paged_result_return" "true" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "PagedResult used, no raw List returns"
      elif [ -z "$paged_found" ]; then
        add_assertion "paged_result_return" "false" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "PagedResult not found in DataAccess"
      else
        add_assertion "paged_result_return" "false" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "Raw List/IEnumerable return found"
      fi

      # A5: document_type_constant
      log "  Assertion: document_type_constant"
      local doctype_used magic_string
      doctype_used=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'DocumentTypes\.Attachment' {} \; 2>/dev/null | head -1)
      magic_string=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -q "\"attachment\"" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$doctype_used" ] && [ -z "$magic_string" ]; then
        add_assertion "document_type_constant" "true" "DocumentTypes.Attachment in DataAccess, no magic string" "DocumentTypes.Attachment used"
      elif [ -z "$doctype_used" ]; then
        add_assertion "document_type_constant" "false" "DocumentTypes.Attachment in DataAccess, no magic string" "DocumentTypes.Attachment not found"
      else
        add_assertion "document_type_constant" "false" "DocumentTypes.Attachment in DataAccess, no magic string" "Magic string found in DataAccess"
      fi

      # A6: logger_message_generator
      log "  Assertion: logger_message_generator"
      local logger_attr string_interp
      logger_attr=$(find "$workdir/BusinessLogic" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -q "\[LoggerMessage" "$1" && grep -qi "ttach" "$1" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      string_interp=$(find "$workdir/BusinessLogic" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -qE "Log(Information|Warning|Error)\(\$\"" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$logger_attr" ] && [ -z "$string_interp" ]; then
        add_assertion "logger_message_generator" "true" "[LoggerMessage] for attachment ops, no interpolated logging" "[LoggerMessage] used correctly"
      elif [ -z "$logger_attr" ]; then
        add_assertion "logger_message_generator" "false" "[LoggerMessage] for attachment ops, no interpolated logging" "[LoggerMessage] for attachment not found"
      else
        add_assertion "logger_message_generator" "false" "[LoggerMessage] for attachment ops, no interpolated logging" "String interpolation logging found"
      fi

      # A7: no_controller_trycatch
      log "  Assertion: no_controller_trycatch"
      local trycatch_found
      trycatch_found=$(find "$workdir/API/Controllers" -name "*Attachment*Controller*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -qE "catch\s*\(" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -z "$trycatch_found" ]; then
        add_assertion "no_controller_trycatch" "true" "No catch blocks in AttachmentsController" "No try-catch found"
      else
        add_assertion "no_controller_trycatch" "false" "No catch blocks in AttachmentsController" "try-catch found in controller"
      fi

      # A8: namespace_matches_path
      log "  Assertion: namespace_matches_path"
      local ns_match_count=0 ns_mismatch_count=0 ns_mismatches=""
      while IFS= read -r f; do
        [ -z "$f" ] && continue
        local relpath="${f#$workdir/}"
        if echo "$relpath" | grep -qi "ttach"; then
          local ns
          ns=$(grep -oP 'namespace\s+\K[\w.]+' "$f" 2>/dev/null | head -1)
          if [ -n "$ns" ]; then
            local expected_ns
            expected_ns=$(echo "${relpath%/*}" | tr '/' '.')
            if [ "$ns" = "$expected_ns" ]; then
              ns_match_count=$((ns_match_count + 1))
            else
              ns_mismatch_count=$((ns_mismatch_count + 1))
              ns_mismatches="$ns_mismatches $relpath(got:$ns expected:$expected_ns)"
            fi
          fi
        fi
      done < <(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null)
      if [ "$ns_mismatch_count" -eq 0 ] && [ "$ns_match_count" -gt 0 ]; then
        add_assertion "namespace_matches_path" "true" "All new .cs file namespaces match folder paths" "$ns_match_count files correct"
      elif [ "$ns_match_count" -eq 0 ]; then
        add_assertion "namespace_matches_path" "false" "All new .cs file namespaces match folder paths" "No attachment .cs files found"
      else
        add_assertion "namespace_matches_path" "false" "All new .cs file namespaces match folder paths" "$ns_mismatch_count mismatches:$ns_mismatches"
      fi
      ;;

    trap-antipattern-resistance)
      # A1: handler_not_service - Agent should name it AttachmentHandler, not AttachmentService
      log "  Assertion: handler_not_service"
      local handler_found service_found
      handler_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class\s*AttachmentHandler' {} \; 2>/dev/null | head -1)
      service_found=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class\s*AttachmentService' {} \; 2>/dev/null | head -1)
      if [ -n "$handler_found" ] && [ -z "$service_found" ]; then
        add_assertion "handler_not_service" "true" "class AttachmentHandler, no class AttachmentService" "AttachmentHandler found, no AttachmentService"
      elif [ -z "$handler_found" ] && [ -z "$service_found" ]; then
        add_assertion "handler_not_service" "false" "class AttachmentHandler, no class AttachmentService" "Neither AttachmentHandler nor AttachmentService found"
      elif [ -z "$handler_found" ]; then
        add_assertion "handler_not_service" "false" "class AttachmentHandler, no class AttachmentService" "AttachmentService found but no AttachmentHandler (copied antipattern)"
      else
        add_assertion "handler_not_service" "false" "class AttachmentHandler, no class AttachmentService" "Both AttachmentHandler and AttachmentService found"
      fi

      # A2: interface_in_common - IAttachmentRepository should be in Common/Interfaces, NOT in DataAccess
      log "  Assertion: interface_in_common"
      local iface_common iface_da
      iface_common=$(find "$workdir/Common/Interfaces" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface.*IAttachmentRepository' {} \; 2>/dev/null | head -1)
      iface_da=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface.*IAttachmentRepository' {} \; 2>/dev/null | head -1)
      if [ -n "$iface_common" ] && [ -z "$iface_da" ]; then
        add_assertion "interface_in_common" "true" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository in Common/Interfaces only"
      elif [ -z "$iface_common" ] && [ -n "$iface_da" ]; then
        add_assertion "interface_in_common" "false" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository in DataAccess (copied antipattern)"
      elif [ -z "$iface_common" ]; then
        add_assertion "interface_in_common" "false" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository not found in Common/Interfaces"
      else
        add_assertion "interface_in_common" "false" "IAttachmentRepository in Common/Interfaces, not in DataAccess" "IAttachmentRepository in both Common and DataAccess"
      fi

      # A3: paged_result_return - Should use PagedResult<>, not Task<List<>> or Task<IEnumerable<>>
      log "  Assertion: paged_result_return"
      local paged_found list_found
      paged_found=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'PagedResult<Attachment' {} \; 2>/dev/null | head -1)
      list_found=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -qE "Task<List<Attachment|Task<IEnumerable<Attachment" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$paged_found" ] && [ -z "$list_found" ]; then
        add_assertion "paged_result_return" "true" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "PagedResult used, no raw List/IEnumerable returns"
      elif [ -z "$paged_found" ]; then
        add_assertion "paged_result_return" "false" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "PagedResult<Attachment not found in DataAccess"
      else
        add_assertion "paged_result_return" "false" "PagedResult<Attachment in DataAccess, no Task<List<Attachment" "Raw List/IEnumerable return found (copied antipattern)"
      fi

      # A4: document_type_constant - Should use DocumentTypes.Attachment, not magic string "attachment"
      log "  Assertion: document_type_constant"
      local doctype_used magic_string
      doctype_used=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'DocumentTypes\.Attachment' {} \; 2>/dev/null | head -1)
      magic_string=$(find "$workdir/DataAccess" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -v "^\s*//" "$1" | grep -q "\"attachment\"" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$doctype_used" ] && [ -z "$magic_string" ]; then
        add_assertion "document_type_constant" "true" "DocumentTypes.Attachment in DataAccess, no magic string" "DocumentTypes.Attachment used, no magic strings"
      elif [ -z "$doctype_used" ]; then
        add_assertion "document_type_constant" "false" "DocumentTypes.Attachment in DataAccess, no magic string" "DocumentTypes.Attachment not found in DataAccess"
      else
        add_assertion "document_type_constant" "false" "DocumentTypes.Attachment in DataAccess, no magic string" "Magic string 'attachment' found in DataAccess (copied antipattern)"
      fi

      # A5: logger_message_generator - Should use [LoggerMessage] source gen, not string interpolation
      log "  Assertion: logger_message_generator"
      local logger_attr string_interp
      # Check for [LoggerMessage] attribute mentioning attachment in any BusinessLogic .cs file
      logger_attr=$(find "$workdir/BusinessLogic" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -q "\[LoggerMessage" "$1" && grep -qi "ttach" "$1" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      # Check for string interpolation logging in attachment-related files
      string_interp=$(find "$workdir/BusinessLogic" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec sh -c 'grep -qi "ttach" "$1" && grep -v "^\s*//" "$1" | grep -qE "Log(Information|Warning|Error)\(\$\"" && echo "$1"' _ {} \; 2>/dev/null | head -1)
      if [ -n "$logger_attr" ] && [ -z "$string_interp" ]; then
        add_assertion "logger_message_generator" "true" "[LoggerMessage] for attachment ops, no interpolated logging" "[LoggerMessage] used for attachment ops, no string interpolation"
      elif [ -z "$logger_attr" ]; then
        add_assertion "logger_message_generator" "false" "[LoggerMessage] for attachment ops, no interpolated logging" "[LoggerMessage] for attachment ops not found in BusinessLogic"
      else
        add_assertion "logger_message_generator" "false" "[LoggerMessage] for attachment ops, no interpolated logging" "String interpolation logging found for attachment ops (copied antipattern)"
      fi

      # A6: no_controller_trycatch - No try-catch in AttachmentsController
      log "  Assertion: no_controller_trycatch"
      local trycatch_found
      trycatch_found=$(find "$workdir/API/Controllers" -name "*Attachment*Controller*.cs" -o -name "*Attachments*Controller*.cs" \
        2>/dev/null | while read -r f; do
          grep -v '^\s*//' "$f" | grep -qE 'catch\s*\(' && echo "$f" && break
        done)
      if [ -z "$trycatch_found" ]; then
        add_assertion "no_controller_trycatch" "true" "No catch blocks in AttachmentsController" "No try-catch found"
      else
        add_assertion "no_controller_trycatch" "false" "No catch blocks in AttachmentsController" "try-catch found in AttachmentsController (copied antipattern)"
      fi

      # A7: interface_not_collocated - IAttachmentRepository not in same dir as AttachmentRepository
      log "  Assertion: interface_not_collocated"
      local iface_dir impl_dir
      iface_dir=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'interface\s*IAttachmentRepository' {} \; 2>/dev/null | head -1 | xargs -r dirname 2>/dev/null)
      impl_dir=$(find "$workdir" -name "*.cs" ! -path "*/obj/*" ! -path "*/bin/*" \
        -exec grep -l 'class\s*AttachmentRepository' {} \; 2>/dev/null | head -1 | xargs -r dirname 2>/dev/null)
      if [ -n "$iface_dir" ] && [ -n "$impl_dir" ]; then
        if [ "$iface_dir" != "$impl_dir" ]; then
          add_assertion "interface_not_collocated" "true" "IAttachmentRepository not in same directory as AttachmentRepository" "Interface and implementation in different directories"
        else
          add_assertion "interface_not_collocated" "false" "IAttachmentRepository not in same directory as AttachmentRepository" "Interface collocated with implementation in same directory (copied antipattern)"
        fi
      elif [ -n "$iface_dir" ] && [ -z "$impl_dir" ]; then
        add_assertion "interface_not_collocated" "false" "IAttachmentRepository not in same directory as AttachmentRepository" "IAttachmentRepository found but no AttachmentRepository implementation"
      elif [ -z "$iface_dir" ] && [ -n "$impl_dir" ]; then
        add_assertion "interface_not_collocated" "false" "IAttachmentRepository not in same directory as AttachmentRepository" "AttachmentRepository found but no IAttachmentRepository interface"
      else
        add_assertion "interface_not_collocated" "false" "IAttachmentRepository not in same directory as AttachmentRepository" "Neither IAttachmentRepository nor AttachmentRepository found"
      fi
      ;;

  esac
}

# ============================================================================
# Behavioral correctness verification (hidden test injection)
# ============================================================================

# run_behavioral_verification: Inject a hidden verification test after the agent
# completes, run it, and report whether the code actually works correctly.
# Args: scenario_name, workdir
# Appends to ASSERTIONS_FILE
run_behavioral_verification() {
  local scenario_name="$1"
  local workdir="$2"

  # Scenarios that should be skipped (no deterministic verification test)
  case "$scenario_name" in
    review-and-fix|coverage-loop|rule-adherence|negative-constraints|cross-project-dependency)
      log "  Assertion: behavioral_correctness (SKIPPED)"
      add_assertion "behavioral_correctness" "true" "verification test" "SKIPPED" \
        "No verification test for $scenario_name scenario"
      return
      ;;
  esac

  case "$scenario_name" in
    investigate-and-implement)
      local test_dir="$workdir/EvalProject.Tests"
      local test_file="$test_dir/VerifyFix.cs"
      local test_filter="FullyQualifiedName~VerifyFix"

      log "  Assertion: behavioral_correctness"

      if [ ! -d "$test_dir" ]; then
        add_assertion "behavioral_correctness" "false" "test project exists" \
          "EvalProject.Tests not found" "Cannot inject verification test -- test project directory missing"
        return
      fi

      # Inject the verification test
      cat > "$test_file" << 'VERIFYEOF'
using System;
using Xunit;

public class VerifyFix
{
    [Fact]
    public void Average_ShouldReturnDecimalResult()
    {
        var calc = new Calculator();
        var result = calc.Average(new[] { 2, 3 });
        Assert.Equal(2.5, result, precision: 1);
    }

    [Fact]
    public void Average_EmptyArray_ShouldThrow()
    {
        var calc = new Calculator();
        Assert.ThrowsAny<Exception>(() => calc.Average(Array.Empty<int>()));
    }
}
VERIFYEOF

      # Run only verification tests
      local verify_output verify_exit
      verify_output=$(cd "$workdir" && dotnet test --nologo -v q --filter "$test_filter" 2>&1) || true
      verify_exit=$?

      # Clean up injected file
      rm -f "$test_file" 2>/dev/null

      if echo "$verify_output" | grep -q "Passed" 2>/dev/null && [ "$verify_exit" -eq 0 ]; then
        add_assertion "behavioral_correctness" "true" "verification tests pass" "all passed"
      else
        local fail_info
        fail_info=$(echo "$verify_output" | grep -iE 'Failed|Error|Assert' 2>/dev/null | head -3 | cut -c1-100 | tr '\n' '; ')
        if [ -z "$fail_info" ]; then fail_info="dotnet test exit code $verify_exit"; fi
        add_assertion "behavioral_correctness" "false" "verification tests pass" "tests failed" "$fail_info"
      fi
      ;;

    refactor-extract-service)
      local test_dir="$workdir/EvalProject.Tests"
      local test_file="$test_dir/VerifyRefactor.cs"
      local test_filter="FullyQualifiedName~VerifyRefactor"

      log "  Assertion: behavioral_correctness"

      if [ ! -d "$test_dir" ]; then
        add_assertion "behavioral_correctness" "false" "test project exists" \
          "EvalProject.Tests not found" "Cannot inject verification test -- test project directory missing"
        return
      fi

      # Inject the verification test
      cat > "$test_file" << 'VERIFYEOF'
using System;
using System.Linq;
using System.Reflection;
using Xunit;

public class VerifyRefactor
{
    [Theory]
    [InlineData(1, 29.99)]
    [InlineData(10, 269.91)]
    [InlineData(50, 1274.575)]
    [InlineData(100, 2399.20)]
    public void PricingService_MustPreserveBehavior(int qty, decimal expected)
    {
        // Find PricingService type via reflection
        var pricingType = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(a => { try { return a.GetTypes(); } catch { return Array.Empty<Type>(); } })
            .FirstOrDefault(t => t.Name == "PricingService" && !t.IsInterface);

        Assert.NotNull(pricingType);

        var instance = Activator.CreateInstance(pricingType);
        Assert.NotNull(instance);

        // Find a method that calculates price (CalculatePrice, GetPrice, ComputePrice, Calculate)
        var method = pricingType.GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(m =>
                m.Name.Contains("Price", StringComparison.OrdinalIgnoreCase) ||
                m.Name.Contains("Calculate", StringComparison.OrdinalIgnoreCase) ||
                m.Name.Contains("Compute", StringComparison.OrdinalIgnoreCase));

        Assert.NotNull(method);

        // Determine parameter types and invoke
        var parameters = method.GetParameters();
        object result;
        if (parameters.Length == 2)
        {
            var p0Type = parameters[0].ParameterType;
            var p1Type = parameters[1].ParameterType;
            object arg0 = p0Type == typeof(decimal) ? (object)(decimal)29.99m : (object)1;
            object arg1 = p1Type == typeof(decimal) ? (object)(decimal)qty : (object)qty;
            result = method.Invoke(instance, new[] { arg0, arg1 });
        }
        else if (parameters.Length == 1)
        {
            result = method.Invoke(instance, new object[] { qty });
        }
        else
        {
            var args = new object[parameters.Length];
            for (int i = 0; i < parameters.Length; i++)
            {
                if (parameters[i].ParameterType == typeof(int))
                    args[i] = parameters[i].Name.Contains("qty", StringComparison.OrdinalIgnoreCase) ||
                              parameters[i].Name.Contains("quantity", StringComparison.OrdinalIgnoreCase)
                        ? qty : 1;
                else if (parameters[i].ParameterType == typeof(decimal))
                    args[i] = 29.99m;
                else
                    args[i] = Activator.CreateInstance(parameters[i].ParameterType);
            }
            result = method.Invoke(instance, args);
        }

        Assert.NotNull(result);
        var decimalResult = Convert.ToDecimal(result);
        Assert.Equal(expected, decimalResult);
    }

    [Fact]
    public void ProductController_MustUseDI()
    {
        var controllerType = AppDomain.CurrentDomain.GetAssemblies()
            .SelectMany(a => { try { return a.GetTypes(); } catch { return Array.Empty<Type>(); } })
            .FirstOrDefault(t => t.Name == "ProductController");

        Assert.NotNull(controllerType);

        var ctorParams = controllerType.GetConstructors()[0].GetParameters();
        Assert.Contains(ctorParams, p => p.ParameterType.Name == "IPricingService");
    }
}
VERIFYEOF

      # Run only verification tests
      local verify_output verify_exit
      verify_output=$(cd "$workdir" && dotnet test --nologo -v q --filter "$test_filter" 2>&1) || true
      verify_exit=$?

      # Clean up injected file
      rm -f "$test_file" 2>/dev/null

      if echo "$verify_output" | grep -q "Passed" 2>/dev/null && [ "$verify_exit" -eq 0 ]; then
        add_assertion "behavioral_correctness" "true" "verification tests pass" "all passed"
      else
        local fail_info
        fail_info=$(echo "$verify_output" | grep -iE 'Failed|Error|Assert' 2>/dev/null | head -3 | cut -c1-100 | tr '\n' '; ')
        if [ -z "$fail_info" ]; then fail_info="dotnet test exit code $verify_exit"; fi
        add_assertion "behavioral_correctness" "false" "verification tests pass" "tests failed" "$fail_info"
      fi
      ;;

    enterprise-cosmos-entity|trap-antipattern-resistance)
      local test_dir="$workdir/EvalSolution.Tests"
      local test_file="$test_dir/VerifyEnterprisePatterns.cs"
      local test_filter="FullyQualifiedName~VerifyEnterprisePatterns"

      log "  Assertion: behavioral_correctness"

      if [ ! -d "$test_dir" ]; then
        add_assertion "behavioral_correctness" "false" "test project exists" \
          "EvalSolution.Tests not found" "Cannot inject verification test"
        return
      fi

      cat > "$test_file" << 'VERIFYEOF'
using Common.Constants;
using Common.Models;
using Xunit;

public class VerifyEnterprisePatterns
{
    [Fact]
    public void DocumentTypes_HasAttachmentConstant()
    {
        var field = typeof(DocumentTypes).GetField("Attachment");
        Assert.NotNull(field);
        var value = field!.GetValue(null) as string;
        Assert.False(string.IsNullOrEmpty(value), "DocumentTypes.Attachment should not be empty");
    }
}
VERIFYEOF

      local verify_output verify_exit
      verify_output=$(cd "$workdir" && dotnet test --nologo -v q --filter "$test_filter" 2>&1) || true
      verify_exit=$?

      rm -f "$test_file" 2>/dev/null

      if echo "$verify_output" | grep -q "Passed" 2>/dev/null && [ "$verify_exit" -eq 0 ]; then
        add_assertion "behavioral_correctness" "true" "verification tests pass" "all passed"
      else
        local fail_info
        fail_info=$(echo "$verify_output" | grep -iE 'Failed|Error|Assert' 2>/dev/null | head -3 | cut -c1-100 | tr '\n' '; ')
        [ -z "$fail_info" ] && fail_info="dotnet test exit code $verify_exit"
        add_assertion "behavioral_correctness" "false" "verification tests pass" "tests failed" "$fail_info"
      fi
      ;;

    *)
      # Unknown scenario -- skip
      log "  Assertion: behavioral_correctness (SKIPPED)"
      add_assertion "behavioral_correctness" "true" "verification test" "SKIPPED" \
        "No verification test for $scenario_name scenario"
      ;;
  esac
}

# ============================================================================
# Token parsing from Claude CLI JSON output
# ============================================================================

parse_tokens() {
  local claude_output_file="$1"

  # Claude --output-format json produces NDJSON with usage info
  # Try to extract token counts from the output
  local input_tokens=0 output_tokens=0 cache_read=0 cache_creation=0
  local cost_usd="0" num_turns=0

  # Parse NDJSON: accumulate tokens across all lines
  if [ -f "$claude_output_file" ] && [ -s "$claude_output_file" ]; then
    # Accumulate input/output tokens from all usage objects
    input_tokens=$(jq -s '[.[] | (.usage.input_tokens // 0) + (if .result and (.result | type == "object") then .result.usage.input_tokens // 0 else 0 end)] | add // 0' "$claude_output_file" 2>/dev/null || echo "0")
    output_tokens=$(jq -s '[.[] | (.usage.output_tokens // 0) + (if .result and (.result | type == "object") then .result.usage.output_tokens // 0 else 0 end)] | add // 0' "$claude_output_file" 2>/dev/null || echo "0")
    cache_read=$(jq -s '[.[] | (.usage.cache_read_input_tokens // .usage.cache_read_tokens // 0) + (if .result and (.result | type == "object") then .result.usage.cache_read_input_tokens // 0 else 0 end)] | add // 0' "$claude_output_file" 2>/dev/null || echo "0")
    cache_creation=$(jq -s '[.[] | (.usage.cache_creation_input_tokens // .usage.cache_creation_tokens // 0) + (if .result and (.result | type == "object") then .result.usage.cache_creation_input_tokens // 0 else 0 end)] | add // 0' "$claude_output_file" 2>/dev/null || echo "0")

    # Extract cost_usd: sum of total_cost_usd or cost_usd from all lines
    cost_usd=$(jq -s '[.[] | (.total_cost_usd // .cost_usd // 0) + (if .result and (.result | type == "object") then .result.total_cost_usd // 0 else 0 end)] | add // 0' "$claude_output_file" 2>/dev/null || echo "0")

    # Extract num_turns: take the max value found across all lines
    num_turns=$(jq -s '[.[] | (.num_turns // 0), (if .result and (.result | type == "object") then .result.num_turns // 0 else 0 end)] | max // 0' "$claude_output_file" 2>/dev/null || echo "0")

    # Extract per-model breakdown: group by model, sum tokens and cost
    local model_breakdown
    model_breakdown=$(jq -s '
      [.[] | select(.model and .usage) | {model: .model, input: (.usage.input_tokens // 0), output: (.usage.output_tokens // 0), cost: (.total_cost_usd // .cost_usd // 0)}]
      | group_by(.model)
      | map({
          key: .[0].model,
          value: {
            input_tokens: (map(.input) | add),
            output_tokens: (map(.output) | add),
            cost_usd: (map(.cost) | add)
          }
        })
      | from_entries // {}' "$claude_output_file" 2>/dev/null || echo "{}")
  else
    local model_breakdown="{}"
  fi

  # Ensure numeric
  input_tokens=$((input_tokens + 0)) 2>/dev/null || input_tokens=0
  output_tokens=$((output_tokens + 0)) 2>/dev/null || output_tokens=0
  cache_read=$((cache_read + 0)) 2>/dev/null || cache_read=0
  cache_creation=$((cache_creation + 0)) 2>/dev/null || cache_creation=0
  num_turns=$((num_turns + 0)) 2>/dev/null || num_turns=0

  local total=$((input_tokens + output_tokens))

  jq -n \
    --argjson input "$input_tokens" \
    --argjson output "$output_tokens" \
    --argjson total "$total" \
    --argjson cache_read "$cache_read" \
    --argjson cache_creation "$cache_creation" \
    --argjson cost "$cost_usd" \
    --argjson turns "$num_turns" \
    --argjson models "$model_breakdown" \
    '{input_tokens: $input, output_tokens: $output, total_tokens: $total,
      cache_read_tokens: $cache_read, cache_creation_tokens: $cache_creation,
      cost_usd: $cost, num_turns: $turns, model_breakdown: $models}'
}

# ============================================================================
# LLM-as-Judge evaluation
# ============================================================================

# run_llm_judge: Invoke Haiku to grade scenario output against a rubric
# Args: scenario_name, workdir
# Outputs: JSON object to stdout (or "null" on failure)
run_llm_judge() {
  local scenario_name="$1"
  local work_dir="$2"

  local rubric_path
  rubric_path="$(dirname "$0")/rubrics/${scenario_name}.md"
  if [ ! -f "$rubric_path" ]; then
    log_warn "No rubric found for $scenario_name, skipping judge"
    echo "null"
    return
  fi

  # Collect .cs files (max 5, max 200 lines each)
  local code_content=""
  local count=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    code_content+="--- $(basename "$f") ---
$(head -200 "$f")

"
    count=$((count + 1))
  done < <(find "$work_dir" -name "*.cs" -type f ! -path "*/obj/*" ! -path "*/bin/*" 2>/dev/null | head -5)

  if [ -z "$code_content" ]; then
    log_warn "No .cs files found for judge"
    echo "null"
    return
  fi

  local rubric
  rubric=$(cat "$rubric_path")

  # Write prompt to temp file to avoid shell escaping issues
  local prompt_file="/tmp/judge-prompt-${scenario_name}.txt"
  cat > "$prompt_file" << JUDGEEOF
${rubric}

## Source Code to Evaluate

${code_content}

## Your Response

Return ONLY a JSON object with the structure specified in the rubric above. No markdown, no explanation outside the JSON.
JUDGEEOF

  local judge_output
  judge_output=$(claude --print --max-turns 1 --output-format json --model claude-haiku-4-5-20251001 -p "$(cat "$prompt_file")" 2>/dev/null) || true

  if [ -z "$judge_output" ]; then
    log_warn "Judge returned empty output"
    echo "null"
    return
  fi

  # Parse the result - find the actual judge JSON in the NDJSON output
  local result_text
  result_text=$(echo "$judge_output" | jq -r '
    select(.result) |
    if .result | type == "string" then .result
    elif .result.text then .result.text
    elif .result.content then .result.content
    else empty
    end' 2>/dev/null | head -1)

  if [ -z "$result_text" ]; then
    log_warn "Judge returned no result"
    echo "null"
    return
  fi

  # Strip markdown code fences if present
  result_text=$(echo "$result_text" | sed 's/^```json//;s/^```//;s/```$//' | sed '/^$/d')

  # Validate the judge JSON has required fields
  local judge_score
  judge_score=$(echo "$result_text" | jq '.score // empty' 2>/dev/null)
  if [ -z "$judge_score" ]; then
    log_warn "Judge response missing score field"
    echo "null"
    return
  fi

  # Extract cost and token data from NDJSON
  local judge_cost judge_input judge_output_tokens
  judge_cost=$(echo "$judge_output" | jq -s '[.[] | (.total_cost_usd // .cost_usd // 0)] | add // 0' 2>/dev/null || echo "0")
  judge_input=$(echo "$judge_output" | jq -s '[.[] | (.usage.input_tokens // 0)] | add // 0' 2>/dev/null || echo "0")
  judge_output_tokens=$(echo "$judge_output" | jq -s '[.[] | (.usage.output_tokens // 0)] | add // 0' 2>/dev/null || echo "0")

  # Build final judge object: merge parsed result with metadata
  echo "$result_text" | jq \
    --arg model "claude-haiku-4-5-20251001" \
    --argjson cost "${judge_cost:-0}" \
    --argjson input_tok "${judge_input:-0}" \
    --argjson output_tok "${judge_output_tokens:-0}" \
    '. + {model: $model, cost_usd: $cost, tokens: {input_tokens: $input_tok, output_tokens: $output_tok}}' 2>/dev/null || echo "null"
}

# ============================================================================
# Phase 4: Run scenarios
# ============================================================================

# Discover which scenarios to run
get_scenario_list() {
  local smoke_scenarios="investigate-and-implement review-and-fix coverage-loop rule-adherence negative-constraints refactor-extract-service cross-project-dependency"
  local enterprise_scenarios="enterprise-cosmos-entity trap-antipattern-resistance"

  case "$SCENARIOS" in
    all)
      echo "$enterprise_scenarios $smoke_scenarios"
      ;;
    smoke)
      echo "$smoke_scenarios"
      ;;
    enterprise)
      echo "$enterprise_scenarios"
      ;;
    "")
      # Default: only enterprise (discriminating) scenarios
      echo "$enterprise_scenarios"
      ;;
    *)
      echo "$SCENARIOS" | tr ',' ' '
      ;;
  esac
}

# Run a single scenario in a subshell to isolate failures
run_single_scenario() {
  local scenario_name="$1"
  local scenario_result_file="${RESULTS_DIR}/${scenario_name}.json"

  # Workdir placement determines whether Claude Code discovers the repo's .claude/ config.
  #
  # BASELINE (default, TREATMENT_MODE=false):
  #   workdir = /workspace/eval-{scenario}  (sibling of /workspace/ccghcp)
  #   Claude Code walks up from /workspace/eval-{scenario} -> /workspace -> / and never
  #   encounters /workspace/ccghcp/.claude/, so the run is config-free (true baseline).
  #
  # TREATMENT (TREATMENT_MODE=true):
  #   workdir = /workspace/ccghcp/.mad/scratch/eval-{scenario}  (inside the repo tree)
  #   Claude Code walks up from .mad/scratch/eval-{scenario} -> .mad/scratch -> .mad ->
  #   /workspace/ccghcp and discovers .claude/ + CLAUDE.md, so rules are active.
  #
  # This sibling-vs-child distinction is the ACI equivalent of the local eval's
  # -ProjectRoot parameter (present = treatment, absent = baseline).
  local workdir
  if [ "$TREATMENT_MODE" = "true" ]; then
    workdir="${REPO_DIR}/.mad/scratch/eval-${scenario_name}"
  else
    workdir="${WORKSPACE}/eval-${scenario_name}"
  fi
  local stderr_log="/tmp/claude-stderr-${scenario_name}.log"
  local claude_output="/tmp/claude-output-${scenario_name}.json"
  ASSERTIONS_FILE="/tmp/assertions-${scenario_name}.jsonl"

  log "--- Scenario: $scenario_name ---"

  # Record start time
  local start_utc
  start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local start_epoch
  start_epoch=$(date +%s)

  # Initialize assertions file
  : > "$ASSERTIONS_FILE"

  # Status tracking
  local status="passed"
  local error_message=""

  # Setup the test project
  log "  Setting up project..."
  case "$scenario_name" in
    investigate-and-implement)
      setup_investigate_and_implement "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    review-and-fix)
      setup_review_and_fix "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    coverage-loop)
      setup_coverage_loop "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    rule-adherence)
      setup_rule_adherence "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    negative-constraints)
      setup_negative_constraints "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    refactor-extract-service)
      setup_refactor_extract_service "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    cross-project-dependency)
      setup_cross_project_dependency "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    enterprise-cosmos-entity)
      setup_enterprise_cosmos_entity "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    trap-antipattern-resistance)
      setup_trap_antipattern_resistance "$workdir" || { status="error"; error_message="Project setup failed"; }
      ;;
    *)
      status="skipped"
      error_message="Unknown scenario: $scenario_name"
      ;;
  esac

  # Pre-flight: verify scaffold builds before invoking agent (enterprise scenarios)
  if [ "$status" != "error" ] && [ "$status" != "skipped" ] && { [ "$scenario_name" = "enterprise-cosmos-entity" ] || [ "$scenario_name" = "trap-antipattern-resistance" ]; }; then
    log "  Pre-flight: verifying scaffold builds..."
    local preflight_output preflight_exit
    preflight_output=$(cd "$workdir" && dotnet build --no-restore --nologo -v q 2>&1) || true
    preflight_exit=$?
    if [ "$preflight_exit" -ne 0 ] || echo "$preflight_output" | grep -qi "error"; then
      log "  SCAFFOLD BUILD FAILED - skipping agent invocation"
      status="error"
      error_message="scaffold_build_failed"
      add_assertion "scaffold_build" "false" "scaffold compiles" "build failed" "$(echo "$preflight_output" | tail -5 | tr '\n' '; ')"
    else
      log "  Scaffold builds successfully"
    fi
  fi

  local tokens_json='{"input_tokens":0,"output_tokens":0,"total_tokens":0,"cache_read_tokens":0,"cache_creation_tokens":0}'
  local claude_raw_output=""

  if [ "$status" != "error" ] && [ "$status" != "skipped" ]; then
    # Create a start marker for file tracking
    touch "$workdir/.eval-start-marker"
    sleep 1

    # Build the prompt
    local prompt
    prompt=$(get_scenario_prompt "$scenario_name" "$workdir") || {
      status="error"
      error_message="Failed to build prompt for $scenario_name"
    }

    if [ "$status" != "error" ]; then
      # Run Claude CLI with per-scenario timeout
      log "  Running Claude CLI (timeout: ${PER_SCENARIO_TIMEOUT}s)..."
      local claude_exit=0
      timeout "$PER_SCENARIO_TIMEOUT" \
        claude --print --max-turns 40 --output-format json --dangerously-skip-permissions \
        "$prompt" \
        > "$claude_output" 2>"$stderr_log" || claude_exit=$?

      if [ "$claude_exit" -eq 124 ]; then
        log_err "  Scenario $scenario_name timed out after ${PER_SCENARIO_TIMEOUT}s"
        status="error"
        error_message="Timed out after ${PER_SCENARIO_TIMEOUT}s"
      elif [ "$claude_exit" -ne 0 ]; then
        log_err "  Claude CLI exited with code $claude_exit"
        # Don't mark as error -- the assertions will determine pass/fail
      fi

      # Parse tokens from Claude output
      if [ -f "$claude_output" ] && [ -s "$claude_output" ]; then
        tokens_json=$(parse_tokens "$claude_output")

        # Capture raw output (truncated to 10KB)
        claude_raw_output=$(head -c 10240 "$claude_output" | jq -Rs '.' 2>/dev/null || head -c 10240 "$claude_output")
      fi

      # Run assertions
      log "  Running assertions..."
      run_assertions "$scenario_name" "$workdir" "$stderr_log"
      run_scenario_assertions "$scenario_name" "$workdir"

      # Behavioral correctness verification (hidden test injection)
      run_behavioral_verification "$scenario_name" "$workdir"

      # Assertion: agent_completed -- verify agent did not hit max turns and ran enough turns
      log "  Assertion: agent_completed"
      local hit_max_turns="false"
      if [ -f "$claude_output" ] && [ -s "$claude_output" ]; then
        local max_turns_check
        max_turns_check=$(jq -r 'select(.type == "result" and .subtype == "error_max_turns") | "found"' "$claude_output" 2>/dev/null | head -1)
        if [ "$max_turns_check" = "found" ]; then
          hit_max_turns="true"
        fi
      fi
      local ac_num_turns
      ac_num_turns=$(echo "$tokens_json" | jq '.num_turns // 0' 2>/dev/null || echo "0")
      ac_num_turns=$((ac_num_turns + 0)) 2>/dev/null || ac_num_turns=0
      if [ "$hit_max_turns" = "true" ]; then
        add_assertion "agent_completed" "false" "no error_max_turns" "error_max_turns detected" \
          "Agent hit max turns limit without completing"
      elif [ "$ac_num_turns" -lt 3 ]; then
        add_assertion "agent_completed" "false" "num_turns >= 3" "num_turns = $ac_num_turns" \
          "Agent completed too few turns, likely did not engage with the task"
      else
        add_assertion "agent_completed" "true" "num_turns >= 3, no error_max_turns" "num_turns = $ac_num_turns"
      fi

      # LLM-as-Judge evaluation (optional, gated by --judge flag)
      if [ "$JUDGE_ENABLED" = "true" ]; then
        log "  Running LLM judge..."
        JUDGE_RESULT=$(run_llm_judge "$scenario_name" "$workdir")
        if [ "$JUDGE_RESULT" != "null" ] && [ -n "$JUDGE_RESULT" ]; then
          local judge_score_val judge_max_val
          judge_score_val=$(echo "$JUDGE_RESULT" | jq '.score // 0' 2>/dev/null || echo "0")
          judge_max_val=$(echo "$JUDGE_RESULT" | jq '.max_score // 3' 2>/dev/null || echo "3")
          log "  Judge score: ${judge_score_val}/${judge_max_val}"
          # Add judge_score assertion for visibility
          if [ "$judge_score_val" -ge 2 ] 2>/dev/null; then
            add_assertion "judge_score" "true" "score >= 2/3" "score = ${judge_score_val}/${judge_max_val}"
          else
            add_assertion "judge_score" "false" "score >= 2/3" "score = ${judge_score_val}/${judge_max_val}"
          fi
        else
          JUDGE_RESULT="null"
        fi
      else
        JUDGE_RESULT="null"
      fi
    fi
  fi

  # Record end time
  local end_utc
  end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local end_epoch
  end_epoch=$(date +%s)
  local duration=$((end_epoch - start_epoch))

  # Determine final status from assertions (if not already error/skipped)
  if [ "$status" = "passed" ]; then
    local any_failed
    any_failed=$(jq -s 'map(select(.passed == false)) | length' "$ASSERTIONS_FILE" 2>/dev/null || echo "0")
    if [ "$any_failed" -gt 0 ]; then
      status="failed"
    fi
  fi

  # Compute per-scenario score (assertion pass rate as decimal)
  local scenario_score="0"
  local sc_total_assertions sc_passed_assertions
  sc_total_assertions=$(jq -s 'length' "$ASSERTIONS_FILE" 2>/dev/null || echo "0")
  sc_passed_assertions=$(jq -s 'map(select(.passed == true)) | length' "$ASSERTIONS_FILE" 2>/dev/null || echo "0")
  if [ "$sc_total_assertions" -gt 0 ]; then
    scenario_score=$(echo "scale=4; $sc_passed_assertions / $sc_total_assertions" | bc 2>/dev/null || echo "0")
  fi

  # Build assertions JSON array
  local assertions_json
  assertions_json=$(jq -s '.' "$ASSERTIONS_FILE" 2>/dev/null || echo "[]")

  # Build quality_checks object
  local quality_json
  quality_json=$(jq -n \
    --argjson build "$QUALITY_BUILD" \
    --argjson tests "$QUALITY_TESTS" \
    --argjson files "$QUALITY_FILES" \
    '{build_passed: $build, tests_passed: $tests, files_created: $files}')

  # Build scenario result JSON
  local judge_arg="null"
  if [ "${JUDGE_RESULT:-null}" != "null" ]; then
    judge_arg="$JUDGE_RESULT"
  fi

  jq -n \
    --arg name "$scenario_name" \
    --arg status "$status" \
    --arg start_utc "$start_utc" \
    --arg end_utc "$end_utc" \
    --argjson duration "$duration" \
    --argjson tokens "$tokens_json" \
    --argjson assertions "$assertions_json" \
    --argjson quality "$quality_json" \
    --arg claude_output "$claude_raw_output" \
    --arg error_message "$error_message" \
    --argjson llm_judge "$judge_arg" \
    '{
      name: $name,
      status: $status,
      timing: {start_utc: $start_utc, end_utc: $end_utc, duration_seconds: $duration},
      tokens: $tokens,
      assertions: $assertions,
      quality_checks: $quality,
      claude_output: $claude_output,
      error_message: (if $error_message == "" then null else $error_message end)
    } + (if $llm_judge != null then {llm_judge: $llm_judge} else {} end)' > "$scenario_result_file"

  log "  Scenario $scenario_name: $status (${duration}s)"
}

# ============================================================================
# Phase 5: Aggregate results
# ============================================================================

aggregate_results() {
  log "=== Phase 5: Aggregating results ==="

  local timestamp_utc
  timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Collect all scenario result files
  local scenario_files
  scenario_files=$(find "$RESULTS_DIR" -name "*.json" -type f 2>/dev/null | sort)

  if [ -z "$scenario_files" ]; then
    log_err "No scenario results found"
    jq -n \
      --arg run_id "$EVAL_RUN_ID" \
      --arg sha "$COMMIT_SHA" \
      --arg branch "${GIT_BRANCH:-main}" \
      --arg ts "$timestamp_utc" \
      --arg env "$ENVIRONMENT" \
      '{run_id: $run_id, git_commit_sha: $sha, git_branch: $branch,
        timestamp_utc: $ts, trigger: "aci", environment: $env,
        scenarios: [],
        summary: {total_scenarios: 0, passed: 0, failed: 0, errors: 0, skipped: 0,
                  total_duration_seconds: 0, total_tokens: 0, assertion_pass_rate: 0}}'
    return
  fi

  # Merge scenario JSON files into array
  local scenarios_json
  scenarios_json=$(jq -s '.' $scenario_files)

  # Compute summary
  local total passed failed errors skipped total_duration total_tokens
  local total_assertions passed_assertions

  total=$(echo "$scenarios_json" | jq 'length')
  passed=$(echo "$scenarios_json" | jq '[.[] | select(.status == "passed")] | length')
  failed=$(echo "$scenarios_json" | jq '[.[] | select(.status == "failed")] | length')
  errors=$(echo "$scenarios_json" | jq '[.[] | select(.status == "error")] | length')
  skipped=$(echo "$scenarios_json" | jq '[.[] | select(.status == "skipped")] | length')
  total_duration=$(echo "$scenarios_json" | jq '[.[].timing.duration_seconds] | add // 0')
  total_tokens=$(echo "$scenarios_json" | jq '[.[].tokens.total_tokens] | add // 0')
  total_assertions=$(echo "$scenarios_json" | jq '[.[].assertions | length] | add // 0')
  passed_assertions=$(echo "$scenarios_json" | jq '[.[].assertions[] | select(.passed == true)] | length // 0')

  local pass_rate="0"
  if [ "$total_assertions" -gt 0 ]; then
    pass_rate=$(echo "scale=4; $passed_assertions / $total_assertions" | bc 2>/dev/null || echo "0")
  fi

  # Compute judge aggregation (if any scenarios have llm_judge)
  local judge_count
  judge_count=$(echo "$scenarios_json" | jq '[.[] | select(.llm_judge != null)] | length' 2>/dev/null || echo "0")
  local avg_judge_score="null"
  local total_judge_cost="null"
  if [ "$judge_count" -gt 0 ]; then
    avg_judge_score=$(echo "$scenarios_json" | jq '
      [.[] | select(.llm_judge != null) | .llm_judge.score / .llm_judge.max_score]
      | (add / length) | . * 10000 | round / 10000' 2>/dev/null || echo "null")
    total_judge_cost=$(echo "$scenarios_json" | jq '
      [.[] | select(.llm_judge != null) | .llm_judge.cost_usd // 0]
      | add | . * 1000000 | round / 1000000' 2>/dev/null || echo "null")
  fi

  # Build final output
  jq -n \
    --arg run_id "$EVAL_RUN_ID" \
    --arg sha "$COMMIT_SHA" \
    --arg branch "${GIT_BRANCH:-main}" \
    --arg ts "$timestamp_utc" \
    --arg env "$ENVIRONMENT" \
    --argjson scenarios "$scenarios_json" \
    --argjson total "$total" \
    --argjson passed "$passed" \
    --argjson failed "$failed" \
    --argjson errors "$errors" \
    --argjson skipped "$skipped" \
    --argjson total_duration "$total_duration" \
    --argjson total_tokens "$total_tokens" \
    --argjson pass_rate "$pass_rate" \
    --argjson avg_judge "$avg_judge_score" \
    --argjson judge_cost "$total_judge_cost" \
    '{
      run_id: $run_id,
      git_commit_sha: $sha,
      git_branch: $branch,
      timestamp_utc: $ts,
      trigger: "aci",
      environment: $env,
      scenarios: $scenarios,
      summary: ({
        total_scenarios: $total,
        passed: $passed,
        failed: $failed,
        errors: $errors,
        skipped: $skipped,
        total_duration_seconds: $total_duration,
        total_tokens: $total_tokens,
        assertion_pass_rate: $pass_rate
      } + (if $avg_judge != null then {avg_judge_score: $avg_judge} else {} end)
        + (if $judge_cost != null then {total_judge_cost_usd: $judge_cost} else {} end))
    }'
}

# ============================================================================
# Main
# ============================================================================

main() {
  local main_start
  main_start=$(date +%s)

  # Phase 1: Setup
  setup_dependencies

  # Phase 2: Auth
  setup_auth

  # Phase 3: Clone
  clone_repo

  # Phase 4: Run scenarios (failures handled per-scenario, do not abort)
  log "=== Phase 4: Running scenarios ==="
  local scenario_list
  scenario_list=$(get_scenario_list)
  log "Scenarios to run: $scenario_list"

  set +e  # Individual scenario failures must not abort the run
  for scenario in $scenario_list; do
    (
      # Run in subshell so a fatal error in one scenario does not kill others
      run_single_scenario "$scenario"
    ) || {
      log_err "Scenario $scenario crashed (subshell exited non-zero)"
      # Write a minimal error result
      jq -n \
        --arg name "$scenario" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{name: $name, status: "error", timing: {start_utc: $ts, end_utc: $ts, duration_seconds: 0},
          tokens: {input_tokens:0, output_tokens:0, total_tokens:0, cache_read_tokens:0, cache_creation_tokens:0},
          assertions: [], quality_checks: {build_passed: false, tests_passed: false, files_created: []},
          claude_output: "", error_message: "Scenario subshell crashed"}' \
        > "${RESULTS_DIR}/${scenario}.json"
    }
  done
  set -e

  # Phase 5: Aggregate and output (only JSON goes to stdout)
  local final_json
  final_json=$(aggregate_results)

  local main_duration=$(( $(date +%s) - main_start ))
  log "=== Eval complete: ${main_duration}s total ==="

  # Final output: only this JSON goes to stdout
  echo "$final_json"
}

main "$@"
