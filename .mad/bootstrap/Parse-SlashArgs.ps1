#Requires -Version 7

<#
.SYNOPSIS
  Parse a slash-command $ARGUMENTS string into positional[] + named{} + flags[].
  Used by plugins/mad-council/commands/*.md to map Claude Code's single-string
  arg blob into pwsh-native parameters.

.DESCRIPTION
  Handles:
    - Quoted strings: `"my channel purpose"` → one atom.
    - Switch flags:  `--triage` or `-triage`  → present in `flags[]`.
    - Named params:  `--tier local`           → named['tier'] = 'local'.
    - Bare tokens (positional):               → positional[] in order.

  Paired with per-command mapping in each `commands/*.md` body: the command
  knows its positional order (e.g., council-open takes `<name> <purpose>`)
  and maps them to the skill's named parameters.

.PARAMETER ArgumentsString
  The raw `$ARGUMENTS` value from a slash-command invocation.

.OUTPUTS
  PSCustomObject: { positional = @(...); named = @{...}; flags = @(...) }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $ArgumentsString
)

Set-StrictMode -Version Latest

function ConvertFrom-SlashArgs {
    param([string] $Text)

    $tokens = [System.Collections.ArrayList]::new()
    $i = 0
    $len = $Text.Length

    while ($i -lt $len) {
        # Skip whitespace
        while ($i -lt $len -and [char]::IsWhiteSpace($Text[$i])) { $i++ }
        if ($i -ge $len) { break }

        $ch = $Text[$i]
        if ($ch -eq '"') {
            # Quoted atom — consume until matching unescaped "
            $i++
            $sb = [System.Text.StringBuilder]::new()
            while ($i -lt $len -and $Text[$i] -ne '"') {
                if ($Text[$i] -eq '\' -and $i + 1 -lt $len -and $Text[$i + 1] -eq '"') {
                    [void]$sb.Append('"')
                    $i += 2
                } else {
                    [void]$sb.Append($Text[$i])
                    $i++
                }
            }
            if ($i -lt $len -and $Text[$i] -eq '"') { $i++ }   # consume closing "
            [void]$tokens.Add($sb.ToString())
        } else {
            # Bare token — consume until whitespace
            $sb = [System.Text.StringBuilder]::new()
            while ($i -lt $len -and -not [char]::IsWhiteSpace($Text[$i])) {
                [void]$sb.Append($Text[$i])
                $i++
            }
            [void]$tokens.Add($sb.ToString())
        }
    }

    # Classify tokens
    $positional = [System.Collections.ArrayList]::new()
    $named = @{}
    $flags = [System.Collections.ArrayList]::new()

    $idx = 0
    while ($idx -lt $tokens.Count) {
        $t = $tokens[$idx]
        if ($t -match '^--?(.+)$') {
            $flagName = $Matches[1]
            # Does the NEXT token look like a value (not another flag)?
            $nextIsValue = ($idx + 1 -lt $tokens.Count) -and ($tokens[$idx + 1] -notmatch '^--?[A-Za-z]')
            if ($nextIsValue) {
                $named[$flagName] = $tokens[$idx + 1]
                $idx += 2
            } else {
                [void]$flags.Add($flagName)
                $idx++
            }
        } else {
            [void]$positional.Add($t)
            $idx++
        }
    }

    return [pscustomobject]@{
        positional = @($positional)
        named      = $named
        flags      = @($flags)
    }
}

return ConvertFrom-SlashArgs -Text $ArgumentsString
