[CmdletBinding()]
param(
    [ValidateSet('Enable', 'Disable', 'Status', 'Configure', 'Report', 'Audit')]
    [string] $Action = 'Enable',

    [ValidateSet('OpenCode', 'T3Code', 'Codex', 'ClaudeCode', 'Gemini', 'All')]
    [string] $Harness = 'OpenCode',

    [string] $ConfigRoot,
    [switch] $SetupRtk,
    [switch] $InstallTools,

    [ValidateSet('Auto', 'Balanced', 'Lean', 'Extreme')]
    [string] $Mode,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $WebSearch,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $DeepSeekSearch,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $Browser,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $AgentReach,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $Skills,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $NarrowContext,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $Mcp,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $GitHub,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $Rtk,
    [ValidateSet('Auto', 'On', 'Off')]
    [string] $Graphify,
    [ValidateSet('On', 'Off')]
    [string] $UsageLog,
    [ValidateSet('On', 'Off')]
    [string] $ToolOutputLog,
    [AllowEmptyString()]
    [ValidateLength(0, 260)]
    [string] $LogPath,
    [AllowEmptyString()]
    [ValidateLength(0, 80)]
    [string] $TaskTag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:StartMarker = '<!-- agent-context-kit:start -->'
$script:EndMarker = '<!-- agent-context-kit:end -->'
$script:ConfigVersion = 1

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

function New-DefaultSettings {
    return [ordered]@{
        schemaVersion = $script:ConfigVersion
        mode = 'Auto'
        taskTag = ''
        features = [ordered]@{
            WebSearch = 'Auto'
            DeepSeekSearch = 'Auto'
            Browser = 'Auto'
            AgentReach = 'Auto'
            Skills = 'Auto'
            NarrowContext = 'On'
            Mcp = 'Off'
            GitHub = 'Auto'
            Rtk = 'Auto'
            Graphify = 'Auto'
        }
        logging = [ordered]@{
            Usage = 'On'
            ToolOutput = 'On'
            Path = ''
        }
    }
}

function Get-SettingsPath {
    param([Parameter(Mandatory)][string[]] $TargetPaths)
    if ($ConfigRoot) { return Join-Path -Path $ConfigRoot -ChildPath 'agent-context-kit.json' }
    return Join-Path -Path (Split-Path -Parent $TargetPaths[0]) -ChildPath 'agent-context-kit.json'
}

function Read-Settings {
    param([Parameter(Mandatory)][string] $Path)

    $settings = New-DefaultSettings
    if (-not [IO.File]::Exists($Path)) { return $settings }

    try {
        $saved = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "Settings file is invalid; no changes were made: $Path"
    }
    if ($null -eq $saved -or $saved -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Settings file must contain a JSON object; no changes were made: $Path"
    }
    $versionProperty = $saved.PSObject.Properties['schemaVersion']
    if ($null -ne $versionProperty -and [int]$versionProperty.Value -gt $script:ConfigVersion) {
        throw "Settings file uses a newer schema; update Agent Context Kit before changing it: $Path"
    }

    if ($null -ne $saved.PSObject.Properties['mode'] -and $saved.mode -in @('Auto', 'Balanced', 'Lean', 'Extreme')) {
        $settings.mode = ConvertTo-CanonicalSetting ([string]$saved.mode)
    }
    if ($null -ne $saved.PSObject.Properties['taskTag'] -and $saved.taskTag -is [string]) { $settings.taskTag = $saved.taskTag }
    if ($null -ne $saved.PSObject.Properties['features']) {
        foreach ($name in @($settings.features.Keys)) {
            $property = $saved.features.PSObject.Properties[$name]
            if ($null -ne $property -and $property.Value -in @('Auto', 'On', 'Off')) { $settings.features[$name] = ConvertTo-CanonicalSetting ([string]$property.Value) }
        }
    }
    if ($null -ne $saved.PSObject.Properties['logging']) {
        foreach ($name in @('Usage', 'ToolOutput')) {
            $property = $saved.logging.PSObject.Properties[$name]
            if ($null -ne $property -and $property.Value -in @('On', 'Off')) { $settings.logging[$name] = ConvertTo-CanonicalSetting ([string]$property.Value) }
        }
        $pathProperty = $saved.logging.PSObject.Properties['Path']
        if ($null -ne $pathProperty -and $pathProperty.Value -is [string]) { $settings.logging.Path = $pathProperty.Value }
    }
    return $settings
}

function ConvertTo-CanonicalSetting {
    param([AllowEmptyString()][string] $Value)
    switch ($Value.ToLowerInvariant()) {
        'auto'     { return 'Auto' }
        'on'       { return 'On' }
        'off'      { return 'Off' }
        'balanced' { return 'Balanced' }
        'lean'     { return 'Lean' }
        'extreme'  { return 'Extreme' }
        default    { return $Value }
    }
}

function Update-Settings {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary] $Settings,
        [Parameter(Mandatory)][System.Collections.IDictionary] $BoundParameters
    )

    if ($BoundParameters.Keys -contains 'Mode') { $Settings.mode = ConvertTo-CanonicalSetting ([string]$BoundParameters['Mode']) }
    if ($BoundParameters.Keys -contains 'TaskTag') { $Settings.taskTag = $BoundParameters['TaskTag'] }

    foreach ($name in @($Settings.features.Keys)) {
        if ($BoundParameters.Keys -contains $name) { $Settings.features[$name] = ConvertTo-CanonicalSetting ([string]$BoundParameters[$name]) }
    }
    if ($BoundParameters.Keys -contains 'UsageLog') { $Settings.logging.Usage = ConvertTo-CanonicalSetting ([string]$BoundParameters['UsageLog']) }
    if ($BoundParameters.Keys -contains 'ToolOutputLog') { $Settings.logging.ToolOutput = ConvertTo-CanonicalSetting ([string]$BoundParameters['ToolOutputLog']) }
    if ($BoundParameters.Keys -contains 'LogPath') { $Settings.logging.Path = $BoundParameters['LogPath'] }
    return $Settings
}

function Write-Settings {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][System.Collections.IDictionary] $Settings
    )
    $Settings.schemaVersion = $script:ConfigVersion
    $json = ConvertTo-Json -InputObject $Settings -Depth 8
    Write-TextSafely -Path $Path -Text ($json + "`n")
}

function Get-PolicyBody {
    param([Parameter(Mandatory)][System.Collections.IDictionary] $Settings)

    $modeText = switch ($Settings.mode) {
        'Auto'     { 'Balanced for complex or high-risk work, Lean for routine, Extreme for low-risk repeats; never skip required research, validation, or safeguards' }
        'Balanced' { 'use only task-relevant tools and files; verify consequential facts' }
        'Lean'     { 'one relevant search or tool pass and targeted file ranges; no redundant lookups' }
        'Extreme'  { 'minimal files and one relevant source per need; never skip required research, validation, or safeguards' }
    }
    $scopeText = if ($Settings.features.NarrowContext -ne 'Off') { 'glob/grep first; read only relevant files and sections' } else { 'read what the task needs' }
    $skillsText = if ($Settings.features.Skills -eq 'Off') { 'off' } else { 'one relevant skill only, plus references this task needs' }

    $routes = [System.Collections.Generic.List[string]]::new()
    if ($Settings.features.WebSearch -eq 'Off') { $routes.Add('web search off') } else { $routes.Add('websearch for current facts') }
    if ($Settings.features.DeepSeekSearch -eq 'Off') { $routes.Add('DeepSeek search off') } else { $routes.Add('DeepSeek search only when it adds coverage') }
    if ($Settings.features.Browser -eq 'Off') { $routes.Add('browser off') } else { $routes.Add('browser only for interactive or visual page state') }
    if ($Settings.features.AgentReach -eq 'Off') { $routes.Add('Agent Reach off') } else { $routes.Add('Agent Reach only for supported platform tasks, router plus needed reference') }
    if ($Settings.features.Mcp -eq 'Off') { $routes.Add('MCP off, prefer native tools and CLI') } else { $routes.Add('MCP only when no native tool or CLI covers it') }
    if ($Settings.features.GitHub -eq 'Off') { $routes.Add('GitHub off, local git only') } else { $routes.Add('GitHub via gh CLI, not a GitHub MCP server') }

    $tools = [System.Collections.Generic.List[string]]::new()
    if ($Settings.features.Rtk -eq 'Off') { $tools.Add('RTK off') } else { $tools.Add('RTK summaries for routine shell output, raw for exact results, failures, audits, security') }
    if ($Settings.features.Graphify -eq 'Off') { $tools.Add('Graphify off') } else { $tools.Add('Graphify existing graphs only, narrow query, verify source, no auto-index or semantic upload') }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('## Context budget (Agent Context Kit)')
    $lines.Add("- Mode: $modeText. Scope: $scopeText. Skills: $skillsText.")
    $lines.Add('- Routes: ' + ($routes -join '; ') + '.')
    $lines.Add('- Tools: ' + ($tools -join '; ') + '.')
    $lines.Add('- Delegate only when asked; brief children minimally; request concise evidence; never repeat chat.')
    return $lines -join "`n"
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
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][System.Collections.IDictionary] $Settings
    )

    $text = if ([IO.File]::Exists($Path)) { [IO.File]::ReadAllText($Path) } else { '' }
    $span = Get-ManagedSpan $text
    $newline = Get-Newline $text
    $body = (Get-PolicyBody -Settings $Settings).TrimEnd() -replace "`r?`n", $newline
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

function Get-UsagePluginPath {
    param([Parameter(Mandatory)][string] $SettingsPath)
    return Join-Path -Path (Split-Path -Parent $SettingsPath) -ChildPath 'plugins/agent-context-kit.ts'
}

function Expand-LogPath {
    param([AllowEmptyString()][string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())
    if ($expanded.StartsWith('~')) {
        $rest = $expanded.Substring(1).TrimStart('\', '/')
        $expanded = if ($rest) { Join-Path (Get-HomeDirectory) $rest } else { Get-HomeDirectory }
    }
    return $expanded
}

function Get-UsageLogPath {
    param([System.Collections.IDictionary] $Settings)
    if ($null -ne $Settings) {
        $custom = Expand-LogPath ([string]$Settings.logging.Path)
        if ($custom) { return $custom }
    }
    $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        return Join-HomePath @('.local', 'state', 'agent-context-kit', 'usage.jsonl')
    }
    return Join-Path -Path $localAppData -ChildPath 'AgentContextKit/usage.jsonl'
}

function Sync-UsageLogger {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary] $Settings,
        [Parameter(Mandatory)][string] $SettingsPath
    )

    if ($Harness -notin @('OpenCode', 'T3Code', 'All')) {
        if ($Settings.logging.Usage -eq 'On' -or $Settings.logging.ToolOutput -eq 'On') {
            Write-Warning 'Usage logging plugin supports OpenCode and T3 Code only; policy settings were saved.'
        }
        return
    }

    $sourcePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'plugins/usage.ts'
    if (-not [IO.File]::Exists($sourcePath)) { throw "Usage logger source is missing: $sourcePath" }
    $pluginPath = Get-UsagePluginPath -SettingsPath $SettingsPath
    $enabled = $Settings.logging.Usage -eq 'On' -or $Settings.logging.ToolOutput -eq 'On'

    if ($enabled) {
        $source = [IO.File]::ReadAllText($sourcePath)
        if ([IO.File]::Exists($pluginPath)) {
            $current = [IO.File]::ReadAllText($pluginPath)
            if ($current -cne $source) {
                if (-not $current.StartsWith('// <agent-context-kit:managed>')) {
                    throw "A different plugin already exists; it was left untouched: $pluginPath"
                }
                Write-TextSafely -Path $pluginPath -Text $source
                Write-Host "Updated local usage logger: $pluginPath"
                return
            }
            Write-Host "Usage logger already installed: $pluginPath"
            return
        }
        Write-TextSafely -Path $pluginPath -Text $source
        Write-Host "Installed local usage logger: $pluginPath"
        return
    }

    if (-not [IO.File]::Exists($pluginPath)) { return }
    $current = [IO.File]::ReadAllText($pluginPath)
    if ($current -cne [IO.File]::ReadAllText($sourcePath)) {
        Write-Warning "Usage logger changed locally; left it untouched: $pluginPath"
        return
    }
    [IO.File]::Delete($pluginPath)
    Write-Host "Removed local usage logger: $pluginPath"
}

function Get-RecordSum {
    param(
        [AllowEmptyCollection()]
        [Parameter(Mandatory)][object[]] $Records,
        [Parameter(Mandatory)][string] $Property
    )
    $sum = 0.0
    foreach ($record in $Records) {
        $value = $record.$Property
        if ($null -ne $value) { $sum += [double]$value }
    }
    return $sum
}

function Show-ContextAudit {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary] $Settings,
        [Parameter(Mandatory)][string[]] $Paths
    )

    $policy = Get-PolicyBody -Settings $Settings
    $chars = $policy.Length
    Write-Host ("Policy: {0} chars, ~{1} tokens of always-on context (rough: characters / 4)." -f $chars, [math]::Ceiling($chars / 4))
    Write-Host ("With markers: ~{0} tokens." -f [math]::Ceiling(($chars + 64) / 4))
    foreach ($path in $Paths) {
        if (-not [IO.File]::Exists($path)) {
            Write-Host "  missing: $path"
            continue
        }
        $text = [IO.File]::ReadAllText($path)
        $span = Get-ManagedSpan $text
        if ($null -eq $span) {
            Write-Host ("  inactive: {0} ({1:N0} chars total)" -f $path, $text.Length)
            continue
        }
        $foreignChars = $text.Length - $span.Length
        Write-Host ("  active: {0} ({1:N0} chars total; {2:N0} yours, ~{3} tokens)" -f $path, $text.Length, $foreignChars, [math]::Ceiling($foreignChars / 4))
        $block = $text.Substring($span.Start, $span.Length)
        $lineNumber = 0
        foreach ($line in ($block -split "`r?`n")) {
            $lineNumber++
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $flag = if ($line.Length -gt 400) { '  long: split or trim' } else { '' }
            Write-Host ("    L{0} ~{1,4} tokens  {2}{3}" -f $lineNumber, [math]::Ceiling($line.Length / 4), $line, $flag)
        }
    }

    Write-Host 'Always-on cost of this kit is the block above. Skill bodies, MCP tool schemas, project files, and web pages are not loaded by it.'
    Write-Host 'MCP and GitHub toggles change instructions only; configured servers and tool schemas stay as OpenCode loads them.'
    Write-Host 'Real savings appear as fewer tool calls and smaller tool output; check them with -Action Report.'

    $logPath = Get-UsageLogPath -Settings $Settings
    if (-not [IO.File]::Exists($logPath)) {
        Write-Host "Actual usage: no records yet; run a task after enabling logging."
        return
    }
    $usage = 0
    $tools = 0
    foreach ($line in [IO.File]::ReadLines($logPath)) {
        if ($line.Contains('"type":"usage"')) { $usage++ }
        elseif ($line.Contains('"type":"tool"')) { $tools++ }
    }
    Write-Host "Actual usage: $usage step records, $tools tool records."
    Write-Host "Run -Action Report for token totals and same-tag mode deltas."
}

function Show-UsageReport {
    param([System.Collections.IDictionary] $Settings)
    $logPath = Get-UsageLogPath -Settings $Settings
    if (-not [IO.File]::Exists($logPath)) {
        Write-Host "No usage log found: $logPath"
        return
    }

    $records = [System.Collections.Generic.List[object]]::new()
    $invalidLines = 0
    foreach ($line in [IO.File]::ReadLines($logPath)) {
        try {
            $record = $line | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $record) { $records.Add($record) }
        } catch {
            $invalidLines++
        }
    }

    $usage = @($records | Where-Object { $_.type -eq 'usage' })
    $tools = @($records | Where-Object { $_.type -eq 'tool' })
    if ($usage.Count -eq 0 -and $tools.Count -eq 0) {
        Write-Host "No usage records found: $logPath"
        return
    }

    $inputTokens = Get-RecordSum -Records $usage -Property 'inputTokens'
    $outputTokens = Get-RecordSum -Records $usage -Property 'outputTokens'
    $reasoningTokens = Get-RecordSum -Records $usage -Property 'reasoningTokens'
    $cacheReadTokens = Get-RecordSum -Records $usage -Property 'cacheReadTokens'
    $cacheWriteTokens = Get-RecordSum -Records $usage -Property 'cacheWriteTokens'
    $costUsd = Get-RecordSum -Records $usage -Property 'costUsd'
    $resultChars = Get-RecordSum -Records $tools -Property 'resultChars'
    $estimatedResultTokens = Get-RecordSum -Records $tools -Property 'estimatedResultTokens'

    Write-Host "Usage log: $logPath"
    Write-Host ("Observed: {0:N0} input + {1:N0} output tokens; {2:N0} reasoning; ${3:N6} reported cost." -f $inputTokens, $outputTokens, $reasoningTokens, $costUsd)
    Write-Host ("Cache: {0:N0} read, {1:N0} write tokens." -f $cacheReadTokens, $cacheWriteTokens)
    Write-Host ("Tool results: {0:N0} characters; ~{1:N0} estimated tokens (characters / 4, rough; not provider usage)." -f $resultChars, $estimatedResultTokens)

    foreach ($group in ($tools | Group-Object -Property tool | Sort-Object Name)) {
        $chars = Get-RecordSum -Records @($group.Group) -Property 'resultChars'
        $estimates = Get-RecordSum -Records @($group.Group) -Property 'estimatedResultTokens'
        Write-Host ("  {0}: {1} calls; {2:N0} chars; ~{3:N0} estimated tokens." -f $group.Name, $group.Count, $chars, $estimates)
    }

    $tagged = @($usage | Where-Object { -not [string]::IsNullOrWhiteSpace($_.taskTag) -and -not [string]::IsNullOrWhiteSpace($_.sessionId) })
    if ($tagged.Count -eq 0) {
        Write-Host 'Savings: not measured. Use the same neutral -TaskTag for comparable Balanced and Lean/Extreme runs.'
    } else {
        foreach ($tagGroup in ($tagged | Group-Object -Property taskTag | Sort-Object Name)) {
            $sessions = [System.Collections.Generic.List[object]]::new()
            foreach ($sessionGroup in ($tagGroup.Group | Group-Object -Property { "$($_.sessionId)|$($_.mode)" })) {
                $first = $sessionGroup.Group[0]
                $tokens = 0.0
                foreach ($entry in $sessionGroup.Group) { $tokens += [double]$entry.inputTokens + [double]$entry.outputTokens }
                $sessions.Add([pscustomobject]@{
                    Mode = ([string]$first.mode).ToLowerInvariant()
                    Tokens = $tokens
                })
            }
            $baseline = @($sessions | Where-Object { $_.Mode -eq 'balanced' })
            if ($baseline.Count -eq 0) {
                Write-Host "Savings for tag '$($tagGroup.Name)': no Balanced baseline; no delta reported."
                continue
            }
            $baselineAverage = ($baseline | Measure-Object -Property Tokens -Average).Average
            foreach ($modeGroup in ($sessions | Where-Object { $_.Mode -ne 'balanced' } | Group-Object -Property Mode | Sort-Object Name)) {
                $modeAverage = ($modeGroup.Group | Measure-Object -Property Tokens -Average).Average
                $delta = $baselineAverage - $modeAverage
                $percent = if ($baselineAverage -gt 0) { [math]::Abs($delta) / $baselineAverage * 100 } else { 0 }
                $direction = if ($delta -ge 0) { 'fewer' } else { 'more' }
                Write-Host ("Observed delta for tag '{0}', {1} vs Balanced: {2:N0} {3} tokens ({4:N1}%; averages of {5} vs {6} sessions). Same-tag runs must be comparable." -f $tagGroup.Name, $modeGroup.Name, [math]::Abs($delta), $direction, $percent, $modeGroup.Count, $baseline.Count)
            }
        }
    }
    if ($invalidLines -gt 0) { Write-Warning "Skipped $invalidLines malformed log line(s)." }
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
$settingsPath = Get-SettingsPath -TargetPaths $paths
$settings = Read-Settings -Path $settingsPath
$settingParameterNames = @(
    'Mode', 'TaskTag', 'WebSearch', 'DeepSeekSearch', 'Browser', 'AgentReach',
    'Skills', 'NarrowContext', 'Mcp', 'GitHub', 'Rtk', 'Graphify', 'UsageLog', 'ToolOutputLog'
)
$hasSettingOverrides = $false
foreach ($name in $settingParameterNames) {
    if ($PSBoundParameters.ContainsKey($name)) { $hasSettingOverrides = $true }
}

if ($Action -in @('Enable', 'Configure')) {
    $settings = Update-Settings -Settings $settings -BoundParameters $PSBoundParameters
    Write-Settings -Path $settingsPath -Settings $settings
} else {
    if ($hasSettingOverrides) { throw "Configuration switches require -Action Enable or -Action Configure." }
    if ($SetupRtk -or $InstallTools) { throw "Setup switches require -Action Enable or -Action Configure." }
}

switch ($Action) {
    { $_ -in @('Enable', 'Configure') } {
        foreach ($path in $paths) { Set-Policy -Path $path -Settings $settings }
        Sync-UsageLogger -Settings $settings -SettingsPath $settingsPath
        if ($SetupRtk) { Setup-OpenCodeRtk }
        if ($InstallTools) { Install-OptionalTools }
    }
    'Disable' {
        foreach ($path in $paths) { Remove-Policy -Path $path }
        $settings.logging.Usage = 'Off'
        $settings.logging.ToolOutput = 'Off'
        Sync-UsageLogger -Settings $settings -SettingsPath $settingsPath
        Write-Host 'Third-party tools and saved settings are unchanged.'
    }
    'Status' {
        foreach ($path in $paths) { Show-PolicyStatus -Path $path }
        Write-Host "Mode: $($settings.mode)"
        foreach ($name in $settings.features.Keys) { Write-Host "$name : $($settings.features[$name])" }
        Write-Host "UsageLog : $($settings.logging.Usage)"
        Write-Host "ToolOutputLog : $($settings.logging.ToolOutput)"
        Write-Host "TaskTag : $(if ($settings.taskTag) { $settings.taskTag } else { '(unset)' })"
        Write-Host "Usage log: $(Get-UsageLogPath -Settings $settings)"
        $pluginPath = Get-UsagePluginPath -SettingsPath $settingsPath
        Write-Host "Usage logger plugin: $(if ([IO.File]::Exists($pluginPath)) { 'installed' } else { 'not installed' })"
    }
    'Report' { Show-UsageReport -Settings $settings }
    'Audit' { Show-ContextAudit -Settings $settings -Paths $paths }
}
