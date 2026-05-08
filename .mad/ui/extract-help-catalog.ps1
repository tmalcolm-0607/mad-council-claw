#Requires -Version 7
<#
.SYNOPSIS
  Parse `MAD/skills/*/SKILL.md` frontmatter + scan `schemas/` and `rules/`
  to produce the /api/help payload.

.DESCRIPTION
  Phase-1c Day 3 deliverable per `plans/phase-1c-local-ui.md`.

  Shape:
    {
      commands: [ { name, description, argument_hint, allowed_tools, source } ],
      schemas:  [ { name, description?, content (string raw) } ],
      rules:    [ { name, title, first_paragraph } ]
    }

  Pure filesystem read. No network. Caller typically wraps in `/api/help`.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $MadRoot = $null
)

Set-StrictMode -Version Latest

if (-not $MadRoot) {
    $MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
}

function script:Parse-Frontmatter {
    param([string] $Raw)
    # Expects leading `---\n...\n---\n` block; returns hashtable of keys.
    if (-not $Raw.StartsWith('---')) { return @{} }
    $lines = $Raw -split "`r?`n"
    if ($lines.Count -lt 2 -or $lines[0] -notmatch '^---\s*$') { return @{} }
    $map = @{}
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^---\s*$') { break }
        if ($lines[$i] -match '^\s*#') { continue }
        if ($lines[$i] -match '^([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()
            # Strip surrounding quotes
            if ($val.Length -ge 2 -and (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'")))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            $map[$key] = $val
        }
    }
    return $map
}

function Get-HelpCatalog {
    [CmdletBinding()]
    param(
        [string] $MadRoot,
        [string] $ClaudeRoot
    )

    # In the consumer-install layout, skills/schemas/rules live under .claude/ — a
    # sibling of MadRoot (.mad/). Older fake-dir unit tests still put them under
    # MadRoot directly. Resolve each with a fallback: prefer MadRoot if populated,
    # otherwise probe ClaudeRoot, then sibling .claude/, finally repo-root .claude/.
    function script:Resolve-CatalogDir {
        param([string] $LeafName, [string] $Mad, [string] $Claude)
        $candidates = @()
        if ($Mad)    { $candidates += (Join-Path $Mad    $LeafName) }
        if ($Claude) { $candidates += (Join-Path $Claude $LeafName) }
        if ($Mad) {
            $siblingClaude = Join-Path (Split-Path $Mad -Parent) '.claude'
            $candidates += (Join-Path $siblingClaude $LeafName)
        }
        foreach ($c in $candidates) {
            if (Test-Path -LiteralPath $c -PathType Container) { return $c }
        }
        return $null
    }

    $skillsDir  = script:Resolve-CatalogDir -LeafName 'skills'  -Mad $MadRoot -Claude $ClaudeRoot
    $schemasDir = script:Resolve-CatalogDir -LeafName 'schemas' -Mad $MadRoot -Claude $ClaudeRoot
    $rulesDir   = script:Resolve-CatalogDir -LeafName 'rules'   -Mad $MadRoot -Claude $ClaudeRoot

    $commands = @()
    if ($skillsDir -and (Test-Path -LiteralPath $skillsDir)) {
        foreach ($skillDir in (Get-ChildItem -LiteralPath $skillsDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            $skillMd = Join-Path $skillDir.FullName 'SKILL.md'
            if (-not (Test-Path -LiteralPath $skillMd)) { continue }
            try {
                $raw = Get-Content -LiteralPath $skillMd -Raw -Encoding UTF8
                $fm  = script:Parse-Frontmatter -Raw $raw
                $commands += [pscustomobject]@{
                    name           = if ($fm.ContainsKey('name'))           { $fm['name']           } else { $skillDir.Name }
                    description    = if ($fm.ContainsKey('description'))    { $fm['description']    } else { '' }
                    argument_hint  = if ($fm.ContainsKey('argument-hint'))  { $fm['argument-hint']  } elseif ($fm.ContainsKey('argument_hint')) { $fm['argument_hint'] } else { '' }
                    allowed_tools  = if ($fm.ContainsKey('allowed-tools'))  { $fm['allowed-tools']  } elseif ($fm.ContainsKey('allowed_tools')) { $fm['allowed_tools'] } else { '' }
                    source         = "skills/$($skillDir.Name)/SKILL.md"
                }
            } catch { continue }
        }
    }

    $schemas = @()
    if ($schemasDir -and (Test-Path -LiteralPath $schemasDir)) {
        foreach ($sf in (Get-ChildItem -LiteralPath $schemasDir -Filter '*.schema.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            try {
                $content = Get-Content -LiteralPath $sf.FullName -Raw -Encoding UTF8
                $desc = $null
                try {
                    $parsed = $content | ConvertFrom-Json
                    if ($parsed.PSObject.Properties['description']) { $desc = [string]$parsed.description }
                    elseif ($parsed.PSObject.Properties['title'])   { $desc = [string]$parsed.title }
                } catch { }
                $schemas += [pscustomobject]@{
                    name        = $sf.Name
                    description = $desc
                    content     = $content
                }
            } catch { continue }
        }
    }

    $rules = @()
    if ($rulesDir -and (Test-Path -LiteralPath $rulesDir)) {
        foreach ($rf in (Get-ChildItem -LiteralPath $rulesDir -Filter '*.md' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            try {
                $raw = Get-Content -LiteralPath $rf.FullName -Raw -Encoding UTF8
                # Strip frontmatter if present
                $body = $raw
                if ($raw.StartsWith('---')) {
                    $end = $raw.IndexOf("`n---", 3)
                    if ($end -gt 0) { $body = $raw.Substring($end + 4) }
                }
                # First H1 or leading ## heading
                $title = $rf.BaseName
                $mTitle = [regex]::Match($body, '(?m)^\s*#\s+(.+?)\s*$')
                if ($mTitle.Success) { $title = $mTitle.Groups[1].Value }
                # First non-empty, non-heading paragraph
                $firstPara = ''
                $paragraphs = ($body -split "(?:`r?`n){2,}") | Where-Object { $_.Trim() -and -not ($_.Trim() -match '^[#`\-]') }
                if ($paragraphs -and @($paragraphs).Count -gt 0) {
                    $firstPara = ($paragraphs[0] -replace "`r?`n", ' ').Trim()
                    if ($firstPara.Length -gt 400) { $firstPara = $firstPara.Substring(0, 400) + '…' }
                }
                $rules += [pscustomobject]@{
                    name            = $rf.Name
                    title           = $title
                    first_paragraph = $firstPara
                }
            } catch { continue }
        }
    }

    return [pscustomobject]@{
        commands = @($commands)
        schemas  = @($schemas)
        rules    = @($rules)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Get-HelpCatalog -MadRoot $MadRoot | ConvertTo-Json -Depth 8
}
