# Pester tests for debug report generation and secret redaction in Run-LocalEval.ps1
# Run: Invoke-Pester -Path .\Run-LocalEval.Tests.DebugReport.ps1
#
# Compatible with Pester 3.x (no BeforeAll at top level)
# Tests the Invoke-SecretRedaction helper function and debug report generation.

$scriptPath = Join-Path $PSScriptRoot "Run-LocalEval.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract function using brace counting
function Extract-FunctionDef {
    param([string]$Source, [string]$Name)
    $marker = "function $Name {"
    $start = $Source.IndexOf($marker)
    if ($start -lt 0) {
        $marker = "function $Name`r`n{"
        $start = $Source.IndexOf($marker)
    }
    if ($start -lt 0) { return $null }
    $depth = 0; $inFunc = $false
    for ($i = $start; $i -lt $Source.Length; $i++) {
        if ($Source[$i] -eq '{') { $depth++; $inFunc = $true }
        if ($Source[$i] -eq '}') { $depth-- }
        if ($inFunc -and $depth -eq 0) {
            return $Source.Substring($start, $i + 1 - $start)
        }
    }
    return $null
}

$funcDef = Extract-FunctionDef -Source $scriptContent -Name 'Invoke-SecretRedaction'
if ($funcDef) {
    Invoke-Expression $funcDef
} else {
    throw "Could not extract Invoke-SecretRedaction from Run-LocalEval.ps1"
}

# Also extract New-Assertion and Build-DebugReport for integration tests
$newAssertionDef = Extract-FunctionDef -Source $scriptContent -Name 'New-Assertion'
if ($newAssertionDef) { Invoke-Expression $newAssertionDef }

$buildDebugReportDef = Extract-FunctionDef -Source $scriptContent -Name 'Build-DebugReport'
if ($buildDebugReportDef) { Invoke-Expression $buildDebugReportDef }

Describe "Invoke-SecretRedaction" {

    Context "Password patterns" {
        It "Redacts password with equals sign" {
            $input_text = "password = mySecretP@ss123"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "password = [REDACTED]"
        }

        It "Redacts password with colon" {
            $input_text = "password: hunter2"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "password: [REDACTED]"
        }

        It "Is case-insensitive for password" {
            $input_text = "PASSWORD = SuperSecret"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "PASSWORD = [REDACTED]"
        }
    }

    Context "Key patterns" {
        It "Redacts key with equals sign" {
            $input_text = "key = abc123def456"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "key = [REDACTED]"
        }

        It "Redacts API key" {
            $input_text = "ApiKey = sk-1234567890abcdef"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "ApiKey = [REDACTED]"
        }
    }

    Context "Token patterns" {
        It "Redacts token with equals sign" {
            $input_text = "token = eyJhbGciOiJIUzI1NiJ9.payload.signature"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "token = [REDACTED]"
        }
    }

    Context "Secret patterns" {
        It "Redacts secret with colon" {
            $input_text = "client_secret: abcdef123456"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "client_secret: [REDACTED]"
        }
    }

    Context "Connection string patterns" {
        It "Redacts connection string value" {
            $input_text = "connection string = Server=myserver;Database=mydb"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "connection string = [REDACTED]"
        }
    }

    Context "Azure AccountKey patterns" {
        It "Redacts AccountKey in connection string" {
            $input_text = "AccountEndpoint=https://mydb.documents.azure.com:443/;AccountKey=dGhpcyBpcyBhIHNlY3JldCBrZXk=;"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Match "AccountKey=\[REDACTED\]"
            $result | Should Not Match "dGhpcyBpcyBhIHNlY3JldCBrZXk="
        }
    }

    Context "Bearer token patterns" {
        It "Redacts Bearer token" {
            $input_text = "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "Authorization: Bearer [REDACTED]"
        }
    }

    Context "No secrets present" {
        It "Returns content unchanged when no secrets found" {
            $input_text = "This is a normal log line with no secrets"
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Be "This is a normal log line with no secrets"
        }
    }

    Context "Multiple secrets in one string" {
        It "Redacts all secrets" {
            $input_text = @"
password = mypass123
token = abc123
normal line
secret: topsecret
"@
            $result = Invoke-SecretRedaction -Content $input_text
            $result | Should Match "password = \[REDACTED\]"
            $result | Should Match "token = \[REDACTED\]"
            $result | Should Match "normal line"
            $result | Should Match "secret: \[REDACTED\]"
        }
    }

    Context "Empty and null input" {
        It "Returns empty string for empty input" {
            $result = Invoke-SecretRedaction -Content ""
            $result | Should Be ""
        }

        It "Returns empty string for null input" {
            $result = Invoke-SecretRedaction -Content $null
            $result | Should Be ""
        }
    }
}

Describe "Build-DebugReport" {

    Context "Basic report generation" {
        It "Includes scenario name in header" {
            $assertions = @(
                (New-Assertion -Name "build_passed" -Passed $true -Expected "exit 0" -Actual "exit 0")
            )
            $report = Build-DebugReport -ScenarioName "investigate-and-implement" `
                -EvalRunId "eval-20260214-120000-abc1234" -Status "passed" `
                -AssertionResults $assertions -WorkDir "C:\temp\eval"
            $report | Should Match "investigate-and-implement"
        }

        It "Includes run ID" {
            $assertions = @(
                (New-Assertion -Name "build_passed" -Passed $true -Expected "exit 0" -Actual "exit 0")
            )
            $report = Build-DebugReport -ScenarioName "test-scenario" `
                -EvalRunId "eval-20260214-120000-abc1234" -Status "passed" `
                -AssertionResults $assertions -WorkDir "C:\temp\eval"
            $report | Should Match "eval-20260214-120000-abc1234"
        }

        It "Shows correct pass/fail counts" {
            $assertions = @(
                (New-Assertion -Name "build_passed" -Passed $true -Expected "exit 0" -Actual "exit 0")
                (New-Assertion -Name "tests_passed" -Passed $true -Expected "all pass" -Actual "all pass")
                (New-Assertion -Name "file_created" -Passed $false -Expected "file exists" -Actual "file missing" -Message "Expected output.cs")
            )
            $report = Build-DebugReport -ScenarioName "test-scenario" `
                -EvalRunId "eval-123" -Status "failed" `
                -AssertionResults $assertions -WorkDir "C:\temp\eval"
            $report | Should Match "Total: 3"
            $report | Should Match "Passed: 2"
            $report | Should Match "Failed: 1"
        }
    }

    Context "Per-assertion details" {
        It "Includes assertion name and status for passing assertion" {
            $assertions = @(
                (New-Assertion -Name "build_passed" -Passed $true -Expected "exit 0" -Actual "exit 0")
            )
            $report = Build-DebugReport -ScenarioName "test" `
                -EvalRunId "eval-123" -Status "passed" `
                -AssertionResults $assertions -WorkDir "C:\temp\eval"
            $report | Should Match "build_passed"
            $report | Should Match "PASS"
        }

        It "Includes assertion name and status for failing assertion" {
            $assertions = @(
                (New-Assertion -Name "file_created" -Passed $false -Expected "file exists" -Actual "file missing" -Message "Expected output.cs")
            )
            $report = Build-DebugReport -ScenarioName "test" `
                -EvalRunId "eval-123" -Status "failed" `
                -AssertionResults $assertions -WorkDir "C:\temp\eval"
            $report | Should Match "file_created"
            $report | Should Match "FAIL"
            $report | Should Match "file exists"
            $report | Should Match "file missing"
            $report | Should Match "Expected output.cs"
        }
    }

    Context "Empty assertions" {
        It "Handles empty assertion list" {
            $report = Build-DebugReport -ScenarioName "test" `
                -EvalRunId "eval-123" -Status "error" `
                -AssertionResults @() -WorkDir "C:\temp\eval"
            $report | Should Match "Total: 0"
            $report | Should Match "Passed: 0"
            $report | Should Match "Failed: 0"
        }
    }
}
