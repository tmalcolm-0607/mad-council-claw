#Requires -Version 7
# Pester 5.x suite for MAD/ui/extract-help-catalog.ps1.

BeforeAll {
    . (Join-Path $PSScriptRoot 'extract-help-catalog.ps1')

    $script:Fake = Join-Path ([System.IO.Path]::GetTempPath()) ("mad-help-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $script:Fake 'skills' 'council-foo') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:Fake 'skills' 'council-bar') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:Fake 'schemas') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:Fake 'rules') -Force | Out-Null

    @'
---
name: council-foo
description: Opens a test channel.
argument-hint: <name> <purpose>
allowed-tools: Read, Write, Bash
---

# council-foo

Body of skill.
'@ | Set-Content -LiteralPath (Join-Path $script:Fake 'skills' 'council-foo' 'SKILL.md') -Encoding UTF8

    @'
---
name: council-bar
description: Posts to the channel.
---

Body.
'@ | Set-Content -LiteralPath (Join-Path $script:Fake 'skills' 'council-bar' 'SKILL.md') -Encoding UTF8

    @'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "channel",
  "description": "A council channel.",
  "type": "object"
}
'@ | Set-Content -LiteralPath (Join-Path $script:Fake 'schemas' 'channel.schema.json') -Encoding UTF8

    @'
---
id: R-001
---

# Rule one title

First real paragraph, with a sentence. Multi-line wraps still count as one paragraph.

Second paragraph.
'@ | Set-Content -LiteralPath (Join-Path $script:Fake 'rules' 'rule-one.md') -Encoding UTF8

    $script:Cat = Get-HelpCatalog -MadRoot $script:Fake
}

AfterAll {
    if ($script:Fake -and (Test-Path -LiteralPath $script:Fake)) {
        Remove-Item -LiteralPath $script:Fake -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'extract-help-catalog.ps1' {

    It 'returns commands array with parsed frontmatter' {
        @($script:Cat.commands).Count | Should -Be 2
        $foo = $script:Cat.commands | Where-Object name -eq 'council-foo'
        $foo                 | Should -Not -BeNullOrEmpty
        $foo.description     | Should -Be 'Opens a test channel.'
        $foo.argument_hint   | Should -Be '<name> <purpose>'
        $foo.allowed_tools   | Should -Be 'Read, Write, Bash'
        $foo.source          | Should -Match 'skills/council-foo/SKILL\.md'
    }

    It 'handles skills without argument-hint or allowed-tools' {
        $bar = $script:Cat.commands | Where-Object name -eq 'council-bar'
        $bar.description    | Should -Be 'Posts to the channel.'
        $bar.argument_hint  | Should -Be ''
        $bar.allowed_tools  | Should -Be ''
    }

    It 'emits schema entries with raw content + description' {
        @($script:Cat.schemas).Count | Should -Be 1
        $s = $script:Cat.schemas[0]
        $s.name        | Should -Be 'channel.schema.json'
        $s.description | Should -Be 'A council channel.'
        $s.content     | Should -Match '"title"\s*:\s*"channel"'
    }

    It 'emits rule entries with title + first paragraph' {
        @($script:Cat.rules).Count | Should -Be 1
        $r = $script:Cat.rules[0]
        $r.name             | Should -Be 'rule-one.md'
        $r.title            | Should -Be 'Rule one title'
        $r.first_paragraph  | Should -Match 'First real paragraph'
        # Frontmatter must not leak into first_paragraph
        $r.first_paragraph  | Should -Not -Match 'R-001'
    }

    It 'is tolerant to a missing skills/schemas/rules directory' {
        $empty = Join-Path ([System.IO.Path]::GetTempPath()) ("mad-empty-help-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        $c = Get-HelpCatalog -MadRoot $empty
        @($c.commands).Count | Should -Be 0
        @($c.schemas).Count  | Should -Be 0
        @($c.rules).Count    | Should -Be 0
    }
}
