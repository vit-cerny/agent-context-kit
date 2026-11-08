[CmdletBinding()]
param(
    [ValidateSet('Enable', 'Disable', 'Status')]
    [string] $Action = 'Enable',

    [ValidateSet('OpenCode', 'T3Code', 'Codex', 'ClaudeCode', 'Gemini', 'All')]
    [string] $Harness = 'OpenCode',

    [string] $ConfigRoot,
    [switch] $SetupRtk,
    [switch] $InstallTools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:StartMarker = '<!-- agent-context-kit:start -->'
$script:EndMarker = '<!-- agent-context-kit:end -->'
$script:PolicyBody = @'
## Context budget (Agent Context Kit)
- RTK: supported shell summaries only; use raw output for exact results, failures, audits, security. Graphify: query existing graphs narrowly; verify source; never auto-index or send content to semantic services. Delegate only when asked; split independent work; brief children minimally, request concise evidence; never repeat chat.
'@

function Get-HomeDirectory {
    $homeDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        throw 'Could not determine the current user profile directory.'
    }
    return $homeDirectory
}

function Join-HomePath {
    param([Parameter(Mandatory)][string[]] $Parts)
    $path = Get-HomeDirectory
    foreach ($part in $Parts) {
        $path = Join-Path -Path $path -ChildPath $part
    }
    return $path
}

function Get-TargetPaths {
    if ($ConfigRoot) {
        if ($Harness -ne 'OpenCode') {
            throw '-ConfigRoot is a test/portable override and is supported only with -Harness OpenCode.'
        }
        return ,(Join-Path -Path $ConfigRoot -ChildPath 'AGENTS.md')
    }

    switch ($Harness) {
        'OpenCode'  { return ,(Join-HomePath @('.config', 'opencode', 'AGENTS.md')) }
        'T3Code'    { return ,(Join-HomePath @('.config', 'opencode', 'AGENTS.md')) }
        'Codex'     { return ,(Join-HomePath @('.codex', 'AGENTS.md')) }
        'ClaudeCode'{ return ,(Join-HomePath @('.claude', 'CLAUDE.md')) }
        'Gemini'    { return ,(Join-HomePath @('.gemini', 'GEMINI.md')) }
        'All'       {
            return @(
                (Join-HomePath @('.config', 'opencode', 'AGENTS.md')),
                (Join-HomePath @('.codex', 'AGENTS.md')),
                (Join-HomePath @('.claude', 'CLAUDE.md')),
                (Join-HomePath @('.gemini', 'GEMINI.md'))
            )
        }
        default { throw "Unsupported harness: $Harness" }
    }
}

function Get-Newline {
    param([AllowEmptyString()][string] $Text)
    if ($Text.Contains("`r`n")) { return "`r`n" }
    return "`n"
}

function Get-ManagedSpan {
    param([AllowEmptyString()][string] $Text)

    $start = $Text.IndexOf($script:StartMarker, [StringComparison]::Ordinal)
    $end = $Text.IndexOf($script:EndMarker, [StringComparison]::Ordinal)
    $secondStart = if ($start -ge 0) { $Text.IndexOf($script:StartMarker, $start + $script:StartMarker.Length, [StringComparison]::Ordinal) } else { -1 }
    $secondEnd = if ($end -ge 0) { $Text.IndexOf($script:EndMarker, $end + $script:EndMarker.Length, [StringComparison]::Ordinal) } else { -1 }

    if ($secondStart -ge 0 -or $secondEnd -ge 0 -or (($start -ge 0) -ne ($end -ge 0)) -or ($start -ge 0 -and $end -lt $start)) {
        throw 'Managed markers are malformed or duplicated. No file was changed; repair the marker pair manually.'
    }
    if ($start -lt 0) { return $null }

    return [pscustomobject]@{
        Start = $start
        Length = ($end + $script:EndMarker.Length) - $start
    }
}

function Write-TextSafely {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyString()][string] $Text
    )

    $directory = Split-Path -Parent $Path
    [void][IO.Directory]::CreateDirectory($directory)

    $existed = [IO.File]::Exists($Path)
    $originalHash = $null
    if ($existed) {
        $originalHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        $backupPath = "$Path.agent-context-kit.bak"
        if (-not [IO.File]::Exists($backupPath)) {
            [IO.File]::Copy($Path, $backupPath, $false)
        }
    }

    $tempPath = "$Path.agent-context-kit-$([Guid]::NewGuid().ToString('N')).tmp"
    $encoding = [Text.UTF8Encoding]::new($false)
    try {
        [IO.File]::WriteAllText($tempPath, $Text, $encoding)
        if ($existed) {
            if (-not [IO.File]::Exists($Path) -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $originalHash) {
                throw 'The target changed during installation. The new version was left untouched; rerun after reviewing it.'
            }
        } elseif ([IO.File]::Exists($Path)) {
            throw 'The target appeared during installation. It was left untouched; rerun after reviewing it.'
        }
        [IO.File]::Move($tempPath, $Path, $true)
    } finally {
        if ([IO.File]::Exists($tempPath)) {
            [IO.File]::Delete($tempPath)
        }
    }
}

function Set-Policy {
    param([Parameter(Mandatory)][string] $Path)

    $text = if ([IO.File]::Exists($Path)) { [IO.File]::ReadAllText($Path) } else { '' }
    $span = Get-ManagedSpan $text
    $newline = Get-Newline $text
    $body = $script:PolicyBody.TrimEnd() -replace "`r?`n", $newline
    $block = $script:StartMarker + $newline + $body + $newline + $script:EndMarker

    if ($null -ne $span) {
        $updated = $text.Substring(0, $span.Start) + $block + $text.Substring($span.Start + $span.Length)
    } else {
        $separator = if ($text.Length -eq 0 -or $text.EndsWith("`n") -or $text.EndsWith("`r")) { '' } else { $newline }
        $updated = $text + $separator + $block + $newline
    }

    if ($updated -cne $text) {
        Write-TextSafely -Path $Path -Text $updated
    }
    Write-Host "Enabled policy: $Path"
}

function Remove-Policy {
    param([Parameter(Mandatory)][string] $Path)

    if (-not [IO.File]::Exists($Path)) {
        Write-Host "Inactive: $Path"
        return
    }
    $text = [IO.File]::ReadAllText($Path)
    $span = Get-ManagedSpan $text
    if ($null -eq $span) {
        Write-Host "Inactive: $Path"
        return
    }
    $tailStart = $span.Start + $span.Length
    $tail = $text.Substring($tailStart)
    $updated = $text.Remove($span.Start, $span.Length)
    $newline = Get-Newline $text
    if ($tail -ceq $newline) {
        $updated = $updated.Substring(0, $updated.Length - $newline.Length)
    }
    Write-TextSafely -Path $Path -Text $updated
    Write-Host "Disabled policy: $Path"
}

function Show-PolicyStatus {
    param([Parameter(Mandatory)][string] $Path)

    $active = $false
    if ([IO.File]::Exists($Path)) {
        $text = [IO.File]::ReadAllText($Path)
        $active = $null -ne (Get-ManagedSpan $text)
    }
    $state = if ($active) { 'enabled' } else { 'disabled' }
    Write-Host "$state : $Path"
}

function Install-OptionalTools {
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uv) {
        throw 'Install uv first, then rerun with -InstallTools. No package was installed.'
    }
    $installed = (& $uv.Source tool list 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not inspect uv tool registrations; no optional package was installed.'
    }

    if ($installed -notmatch '(?im)^headroom-ai(?:\s|$)') {
        & $uv.Source tool install 'headroom-ai[proxy]'
        if ($LASTEXITCODE -ne 0) { throw 'Headroom installation failed.' }
    } else {
        Write-Host 'Headroom CLI already installed; unchanged.'
    }

    if ($installed -notmatch '(?im)^graphifyy(?:\s|$)') {
        & $uv.Source tool install graphifyy
        if ($LASTEXITCODE -ne 0) { throw 'Graphify installation failed.' }
    } else {
        Write-Host 'Graphify CLI already installed; unchanged.'
    }
}

function Setup-OpenCodeRtk {
    if ($Harness -notin @('OpenCode', 'T3Code', 'All')) {
        throw '-SetupRtk requires -Harness OpenCode, T3Code, or All.'
    }
    $pluginPath = Join-HomePath @('.config', 'opencode', 'plugins', 'rtk.ts')
    if ([IO.File]::Exists($pluginPath)) {
        Write-Host "RTK OpenCode plugin already exists; unchanged: $pluginPath"
        return
    }
    $rtk = Get-Command rtk -ErrorAction SilentlyContinue
    if (-not $rtk) {
        Write-Warning 'RTK is not installed. Install RTK from its official project, then rerun with -SetupRtk.'
        return
    }
    & $rtk.Source init -g --opencode
    if ($LASTEXITCODE -ne 0) { throw 'RTK OpenCode setup failed.' }
}

$paths = @(Get-TargetPaths)
switch ($Action) {
    'Enable' {
        foreach ($path in $paths) { Set-Policy -Path $path }
        if ($SetupRtk) { Setup-OpenCodeRtk }
        if ($InstallTools) { Install-OptionalTools }
    }
    'Disable' {
        if ($SetupRtk -or $InstallTools) { throw 'Setup switches cannot be combined with -Action Disable.' }
        foreach ($path in $paths) { Remove-Policy -Path $path }
        Write-Host "Third-party integrations are unchanged; use each tool's native control if you also want those disabled."
    }
    'Status' {
        if ($SetupRtk -or $InstallTools) { throw "Setup switches cannot be combined with -Action Status." }
        foreach ($path in $paths) { Show-PolicyStatus -Path $path }
    }
}
