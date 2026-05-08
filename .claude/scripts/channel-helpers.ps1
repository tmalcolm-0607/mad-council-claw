<#
.SYNOPSIS
  Shared channel state helpers — member lookup, session-id binding verification,
  channel.json CRUD, path resolution. Used by every /council-* skill.

.DESCRIPTION
  Collection of functions that operate on channel.json and related state files.
  Centralizes the "how do I find my member entry" / "how do I verify session_id
  binding" / "how do I atomically update a member" logic that otherwise would
  duplicate across all 10 skills.

  Depends on atomic-write.ps1 for all writes.

.NOTES
  Every function below is independently testable. All writes go through
  Write-AtomicJson; no direct Set-Content.

  Used by: every skill. Cited in:
    - rules/concurrency-safety.md (session-id binding enforcement)
    - every skill's plan.md
#>

Set-StrictMode -Version Latest

# Dot-source atomic-write if not already loaded in caller scope.
if (-not (Get-Command -Name Write-AtomicJson -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'atomic-write.ps1')
}

function Resolve-ChannelPath {
    <#
    .SYNOPSIS
      Resolve a channel name to its canonical directory path.

    .PARAMETER Name
      Channel name (alphanumeric + hyphens, lowercase).

    .PARAMETER Root
      Override root for testing. Default: $HOME/claude-data/channels.

    .OUTPUTS
      Absolute path as string. Does NOT verify existence (caller checks).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    if (-not $Root) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $Root = Join-Path $homeDir 'claude-data' 'channels'
    }
    return [System.IO.Path]::Combine($Root, $Name)
}

# Schema version this reader knows how to handle for channel.json. Bumped when
# schema-breaking changes land. Per schemas/README.md §Schema-version increment
# invariant (ADOPT-036): absent → treated as 1; > known → SCHEMA_VERSION_AHEAD.
$script:KnownChannelSchemaVersion = 2

function Assert-ChannelSchemaVersion {
    <#
    .SYNOPSIS
      Validate a channel object's schema_version against the reader's known version.

    .DESCRIPTION
      Per ADOPT-036: absent/lower schema_version → up-convert on read
      (returns a hint so the caller can back-fill defaults); higher → throw
      SCHEMA_VERSION_AHEAD so skills never silently drop unknown fields.

    .OUTPUTS
      Returns the effective schema_version (the stored value, or 1 if absent).
      Throws on forward-incompatible version.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Channel
    )

    $storedVersion = 1
    if ($Channel.PSObject.Properties['schema_version'] -and $null -ne $Channel.schema_version) {
        $storedVersion = [int]$Channel.schema_version
    }
    if ($storedVersion -gt $script:KnownChannelSchemaVersion) {
        throw "SCHEMA_VERSION_AHEAD: channel.json schema_version=$storedVersion, reader knows $script:KnownChannelSchemaVersion. Upgrade the kit or migrate the channel."
    }
    return $storedVersion
}

function Get-ChannelMetadata {
    <#
    .SYNOPSIS
      Read channel.json and return it as PSCustomObject. Asserts schema_version
      per ADOPT-036.

    .PARAMETER Name
      Channel name.

    .PARAMETER Root
      Override root for testing.

    .OUTPUTS
      Parsed channel.json object. Throws on missing, malformed, or
      SCHEMA_VERSION_AHEAD.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $dir = Resolve-ChannelPath -Name $Name -Root $Root
    $jsonPath = Join-Path $dir 'channel.json'
    $channel = Read-AtomicJson -Path $jsonPath
    $null = Assert-ChannelSchemaVersion -Channel $channel
    return $channel
}

function Find-MemberBySession {
    <#
    .SYNOPSIS
      Find the member entry matching a given session_id.

    .PARAMETER Channel
      Parsed channel.json object.

    .PARAMETER SessionId
      Claude Code session ID to match.

    .OUTPUTS
      The matching member object, or $null if no match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Channel,

        [Parameter(Mandatory = $true)]
        [string] $SessionId
    )

    if ($null -eq $Channel.members) { return $null }
    $matches = @($Channel.members | Where-Object { $_.session_id -eq $SessionId })
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Find-MemberByAlias {
    <#
    .SYNOPSIS
      Find the member entry matching a given alias.

    .PARAMETER Channel
      Parsed channel.json object.

    .PARAMETER Alias
      Member alias (case-sensitive).

    .OUTPUTS
      The matching member object, or $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Channel,

        [Parameter(Mandatory = $true)]
        [string] $Alias
    )

    if ($null -eq $Channel.members) { return $null }
    $matches = @($Channel.members | Where-Object { $_.alias -eq $Alias })
    if ($matches.Count -eq 0) { return $null }
    return $matches[0]
}

function Assert-SessionBinding {
    <#
    .SYNOPSIS
      Verify that a given session_id matches the currently-registered session
      for the given alias in the channel. Throws on mismatch (spoofing defense).

    .DESCRIPTION
      This is the core anti-spoofing check per rules/stride-threat-model.md §Spoofing
      and mad.council.a2a.md §7.2. Called before any post-write-as-member operation.

    .PARAMETER Channel
      Parsed channel.json.

    .PARAMETER Alias
      Claimed alias.

    .PARAMETER SessionId
      This session's ID.

    .OUTPUTS
      None. Throws "SessionMismatch: alias '$Alias' has session X but caller is Y"
      on mismatch. Throws "AliasNotMember: '$Alias' not in channel.members[]" if alias unknown.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Channel,

        [Parameter(Mandatory = $true)]
        [string] $Alias,

        [Parameter(Mandatory = $true)]
        [string] $SessionId
    )

    $m = Find-MemberByAlias -Channel $Channel -Alias $Alias
    if (-not $m) {
        throw "AliasNotMember: '$Alias' not in channel.members[]"
    }
    if ($m.session_id -ne $SessionId) {
        throw "SessionMismatch: alias '$Alias' has session '$($m.session_id)' but caller is '$SessionId'"
    }
}

function Update-ChannelMember {
    <#
    .SYNOPSIS
      Atomically update a single member entry in channel.json.

    .DESCRIPTION
      Reads channel.json, modifies the specified member (by alias), writes atomically.

    .PARAMETER Name
      Channel name.

    .PARAMETER Alias
      Alias of the member to update.

    .PARAMETER Patch
      Hashtable of fields to update. Keys must match member schema fields.
      Example: @{ status = 'disconnected'; last_seen_utc = (Get-Date).ToUniversalTime().ToString('o') }

    .PARAMETER Root
      Override root for testing.

    .OUTPUTS
      None. Throws on failure or unknown alias.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Alias,

        [Parameter(Mandatory = $true)]
        [hashtable] $Patch,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $dir = Resolve-ChannelPath -Name $Name -Root $Root
    $jsonPath = Join-Path $dir 'channel.json'
    $channel = Read-AtomicJson -Path $jsonPath

    $idx = -1
    for ($i = 0; $i -lt @($channel.members).Count; $i++) {
        if ($channel.members[$i].alias -eq $Alias) { $idx = $i; break }
    }
    if ($idx -lt 0) { throw "UpdateChannelMember: alias '$Alias' not in channel '$Name'" }

    foreach ($k in $Patch.Keys) {
        $channel.members[$idx] | Add-Member -NotePropertyName $k -NotePropertyValue $Patch[$k] -Force
    }

    Write-AtomicJson -Path $jsonPath -Content $channel
}

function Add-ChannelMember {
    <#
    .SYNOPSIS
      Atomically add a new member to channel.json.

    .PARAMETER Name
      Channel name.

    .PARAMETER Member
      Full member entry hashtable (alias, session_id, project, joined_utc, etc.).

    .PARAMETER Root
      Override root for testing.

    .OUTPUTS
      None. Throws on duplicate alias.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [hashtable] $Member,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    foreach ($req in 'alias', 'session_id', 'joined_utc', 'status') {
        if (-not $Member.ContainsKey($req)) {
            throw "AddChannelMember: missing required field '$req'"
        }
    }

    $dir = Resolve-ChannelPath -Name $Name -Root $Root
    $jsonPath = Join-Path $dir 'channel.json'
    $channel = Read-AtomicJson -Path $jsonPath

    if (Find-MemberByAlias -Channel $channel -Alias $Member.alias) {
        throw "AddChannelMember: alias '$($Member.alias)' already exists in channel '$Name'"
    }

    $newMember = [pscustomobject]$Member
    $channel.members = @($channel.members) + $newMember

    Write-AtomicJson -Path $jsonPath -Content $channel
}

function Get-SessionRegistry {
    <#
    .SYNOPSIS
      Read ~/claude-data/.sessions.json for the current session.

    .PARAMETER Root
      Override root for testing. Default: $HOME/claude-data.

    .OUTPUTS
      Parsed PSCustomObject per schemas/sessions.schema.json. If file missing,
      returns a fresh skeleton { session_id = null; memberships = @() }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    if (-not $Root) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $Root = Join-Path $homeDir 'claude-data'
    }
    $jsonPath = Join-Path $Root '.sessions.json'

    if (-not (Test-Path -LiteralPath $jsonPath)) {
        return [pscustomobject]@{
            session_id  = $null
            started_utc = (Get-Date).ToUniversalTime().ToString('o')
            memberships = @()
        }
    }
    return Read-AtomicJson -Path $jsonPath
}

function Update-SessionRegistry {
    <#
    .SYNOPSIS
      Atomic update to .sessions.json. Creates the file if absent.

    .PARAMETER SessionId
      This session's ID.

    .PARAMETER ChannelName
      Channel being added or removed from this session's membership list.

    .PARAMETER Alias
      Member alias in the channel (required for Add; ignored for Remove).

    .PARAMETER Action
      'Add' or 'Remove'.

    .PARAMETER CronTaskId
      Optional CronCreate task id to associate with the membership (informational).

    .PARAMETER Root
      Override root for testing.

    .OUTPUTS
      None.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $SessionId,
        [Parameter(Mandatory = $true)] [string] $ChannelName,
        [Parameter(Mandatory = $false)] [string] $Alias,
        [Parameter(Mandatory = $true)] [ValidateSet('Add', 'Remove')] [string] $Action,
        [Parameter(Mandatory = $false)] [string] $CronTaskId,
        [Parameter(Mandatory = $false)] [string] $Root = $null
    )

    if (-not $Root) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $Root = Join-Path $homeDir 'claude-data'
    }
    if (-not (Test-Path -LiteralPath $Root)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $jsonPath = Join-Path $Root '.sessions.json'

    $registry = Get-SessionRegistry -Root $Root
    if (-not $registry.session_id) {
        $registry.session_id = $SessionId
    } elseif ($registry.session_id -ne $SessionId) {
        # This session's registry was used by a different session_id. Reset to current.
        $registry = [pscustomobject]@{
            session_id  = $SessionId
            started_utc = (Get-Date).ToUniversalTime().ToString('o')
            memberships = @()
        }
    }

    $memberships = @($registry.memberships)
    switch ($Action) {
        'Add' {
            if (-not $Alias) { throw 'Update-SessionRegistry: Alias required for Add' }
            # Deduplicate: remove any existing entry for this channel first.
            $memberships = @($memberships | Where-Object { $_.channel -ne $ChannelName })
            $newEntry = [ordered]@{
                channel     = $ChannelName
                alias       = $Alias
                joined_utc  = (Get-Date).ToUniversalTime().ToString('o')
            }
            if ($CronTaskId) { $newEntry['cron_task_id'] = $CronTaskId }
            $memberships += [pscustomobject]$newEntry
        }
        'Remove' {
            $memberships = @($memberships | Where-Object { $_.channel -ne $ChannelName })
        }
    }
    $registry.memberships = $memberships

    Write-AtomicJson -Path $jsonPath -Content $registry
}
