# Pester tests for Parse-ClaudeTokens in Run-LocalEval.ps1
# Run: Invoke-Pester -Path .\Run-LocalEval.Tests.ParseClaudeTokens.ps1
#
# Compatible with Pester 3.x (no BeforeAll at top level)
# Tests the Parse-ClaudeTokens helper function.

$scriptPath = Join-Path $PSScriptRoot "Run-LocalEval.ps1"
$scriptContent = Get-Content $scriptPath -Raw

# Extract Parse-ClaudeTokens function using brace counting
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

$funcDef = Extract-FunctionDef -Source $scriptContent -Name 'Parse-ClaudeTokens'
if ($funcDef) {
    Invoke-Expression $funcDef
} else {
    throw "Could not extract Parse-ClaudeTokens from Run-LocalEval.ps1"
}

Describe "Parse-ClaudeTokens" {

    Context "Missing or empty file" {
        It "Returns zero defaults when file does not exist" {
            $result = Parse-ClaudeTokens -OutputFile "C:\nonexistent\file.json"
            $result.input_tokens | Should Be 0
            $result.output_tokens | Should Be 0
            $result.total_tokens | Should Be 0
            $result.cost_usd | Should Be 0
            $result.num_turns | Should Be 0
            $result.duration_ms | Should Be 0
            $result.duration_api_ms | Should Be 0
            $result.stop_reason | Should Be ""
            $result.session_id | Should Be ""
            $result.model_breakdown.Count | Should Be 0
        }
    }

    Context "Full Claude CLI JSON output" {
        It "Parses all fields from a standard result JSON" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                $json = @'
{"type":"result","subtype":"success","duration_ms":84073,"duration_api_ms":69755,"num_turns":12,"total_cost_usd":0.32661,"is_error":false,"session_id":"abc-123","usage":{"input_tokens":6626,"output_tokens":4571,"cache_read_input_tokens":319468,"cache_creation_input_tokens":73660},"modelUsage":{"claude-opus-4-6":{"inputTokens":13,"outputTokens":2375,"cacheReadInputTokens":233613,"cacheCreationInputTokens":6422,"costUSD":0.216384},"claude-haiku-4-5-20251001":{"inputTokens":6613,"outputTokens":2196,"cacheReadInputTokens":85855,"cacheCreationInputTokens":67238,"costUSD":0.110226}}}
'@
                Set-Content -Path $tmpFile -Value $json -Encoding UTF8

                $result = Parse-ClaudeTokens -OutputFile $tmpFile

                # Basic token fields
                $result.input_tokens | Should Be 6626
                $result.output_tokens | Should Be 4571
                $result.total_tokens | Should Be 11197
                $result.cache_read_tokens | Should Be 319468
                $result.cache_creation_tokens | Should Be 73660

                # Cost
                $result.cost_usd | Should Be 0.32661

                # Turns
                $result.num_turns | Should Be 12

                # Duration fields
                $result.duration_ms | Should Be 84073
                $result.duration_api_ms | Should Be 69755

                # Stop reason and session
                $result.stop_reason | Should Be "success"
                $result.session_id | Should Be "abc-123"

                # Model breakdown
                $result.model_breakdown.Count | Should Be 2
                $result.model_breakdown['claude-opus-4-6'].input_tokens | Should Be 13
                $result.model_breakdown['claude-opus-4-6'].output_tokens | Should Be 2375
                $result.model_breakdown['claude-opus-4-6'].cache_read_tokens | Should Be 233613
                $result.model_breakdown['claude-opus-4-6'].cache_creation_tokens | Should Be 6422
                $result.model_breakdown['claude-opus-4-6'].cost_usd | Should Be 0.216384

                $result.model_breakdown['claude-haiku-4-5-20251001'].input_tokens | Should Be 6613
                $result.model_breakdown['claude-haiku-4-5-20251001'].output_tokens | Should Be 2196
                $result.model_breakdown['claude-haiku-4-5-20251001'].cache_read_tokens | Should Be 85855
                $result.model_breakdown['claude-haiku-4-5-20251001'].cache_creation_tokens | Should Be 67238
                $result.model_breakdown['claude-haiku-4-5-20251001'].cost_usd | Should Be 0.110226
            } finally {
                Remove-Item $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Single model output (no modelUsage)" {
        It "Returns empty model_breakdown when modelUsage is absent" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                $json = @'
{"type":"result","subtype":"success","duration_ms":5000,"num_turns":3,"total_cost_usd":0.05,"usage":{"input_tokens":100,"output_tokens":200}}
'@
                Set-Content -Path $tmpFile -Value $json -Encoding UTF8

                $result = Parse-ClaudeTokens -OutputFile $tmpFile

                $result.input_tokens | Should Be 100
                $result.output_tokens | Should Be 200
                $result.total_tokens | Should Be 300
                $result.duration_ms | Should Be 5000
                $result.duration_api_ms | Should Be 0
                $result.model_breakdown.Count | Should Be 0
            } finally {
                Remove-Item $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Error result" {
        It "Parses error_max_turns subtype" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                $json = @'
{"type":"result","subtype":"error_max_turns","duration_ms":120000,"duration_api_ms":90000,"num_turns":25,"total_cost_usd":1.50,"session_id":"err-456","usage":{"input_tokens":50000,"output_tokens":10000},"modelUsage":{"claude-opus-4-6":{"inputTokens":50000,"outputTokens":10000,"cacheReadInputTokens":0,"cacheCreationInputTokens":0,"costUSD":1.50}}}
'@
                Set-Content -Path $tmpFile -Value $json -Encoding UTF8

                $result = Parse-ClaudeTokens -OutputFile $tmpFile

                $result.stop_reason | Should Be "error_max_turns"
                $result.session_id | Should Be "err-456"
                $result.num_turns | Should Be 25
                $result.duration_ms | Should Be 120000
                $result.duration_api_ms | Should Be 90000
                $result.model_breakdown.Count | Should Be 1
                $result.model_breakdown['claude-opus-4-6'].cost_usd | Should Be 1.50
            } finally {
                Remove-Item $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Backward compatibility with old model parsing" {
        It "Does not break when obj.model is absent and modelUsage is present" {
            $tmpFile = [System.IO.Path]::GetTempFileName()
            try {
                # Ensure the old obj.model path does not interfere
                $json = @'
{"type":"result","subtype":"success","duration_ms":10000,"num_turns":5,"total_cost_usd":0.10,"usage":{"input_tokens":500,"output_tokens":300},"modelUsage":{"claude-sonnet-4-20250514":{"inputTokens":500,"outputTokens":300,"cacheReadInputTokens":1000,"cacheCreationInputTokens":200,"costUSD":0.10}}}
'@
                Set-Content -Path $tmpFile -Value $json -Encoding UTF8

                $result = Parse-ClaudeTokens -OutputFile $tmpFile

                $result.model_breakdown.Count | Should Be 1
                $result.model_breakdown['claude-sonnet-4-20250514'].input_tokens | Should Be 500
                $result.model_breakdown['claude-sonnet-4-20250514'].output_tokens | Should Be 300
                $result.model_breakdown['claude-sonnet-4-20250514'].cache_read_tokens | Should Be 1000
                $result.model_breakdown['claude-sonnet-4-20250514'].cache_creation_tokens | Should Be 200
                $result.model_breakdown['claude-sonnet-4-20250514'].cost_usd | Should Be 0.10
            } finally {
                Remove-Item $tmpFile -ErrorAction SilentlyContinue
            }
        }
    }
}
