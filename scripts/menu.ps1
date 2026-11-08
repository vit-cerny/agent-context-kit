[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$installer = Join-Path (Split-Path -Parent $PSScriptRoot) 'install.ps1'

$features = @(
    @{ Label = 'Skills'; Name = 'Skills'; Kind = 'Feature' }
    @{ Label = 'Web search (built in)'; Name = 'WebSearch'; Kind = 'Feature' }
    @{ Label = 'DeepSeek search'; Name = 'DeepSeekSearch'; Kind = 'Feature' }
    @{ Label = 'Browser'; Name = 'Browser'; Kind = 'Feature' }
    @{ Label = 'Agent Reach'; Name = 'AgentReach'; Kind = 'Feature' }
    @{ Label = 'Narrow context (targeted reads)'; Name = 'NarrowContext'; Kind = 'Feature' }
    @{ Label = 'MCP tools'; Name = 'Mcp'; Kind = 'Feature' }
    @{ Label = 'GitHub CLI'; Name = 'GitHub'; Kind = 'Feature' }
    @{ Label = 'RTK output summaries'; Name = 'Rtk'; Kind = 'Feature' }
    @{ Label = 'Graphify'; Name = 'Graphify'; Kind = 'Feature' }
    @{ Label = 'Usage log'; Name = 'UsageLog'; Kind = 'Log' }
    @{ Label = 'Tool output log'; Name = 'ToolOutputLog'; Kind = 'Log' }
    @{ Label = 'Work mode'; Name = 'Mode'; Kind = 'Mode' }
)

function Invoke-Kit {
    param([hashtable] $Arguments)
    & $installer @Arguments
}

while ($true) {
    Invoke-Kit @{ Action = 'Status' }
    Write-Host ''
    for ($i = 0; $i -lt $features.Count; $i++) {
        $entry = $features[$i]
        $values = switch ($entry.Kind) {
            'Mode' { 'Auto, Balanced, Lean, Extreme' }
            'Log'  { 'On, Off' }
            default { 'Auto, On, Off' }
        }
        Write-Host ("{0,2}) {1,-32} {2}" -f ($i + 1), $entry.Label, $values)
    }
    Write-Host '  q) quit'
    $choice = Read-Host "Pick a number (1-$($features.Count)), or q"
    if ($choice -eq 'q') { break }
    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $features.Count) {
        Write-Host 'Not a valid number.'
        continue
    }
    $entry = $features[$index - 1]
    if ($entry.Kind -eq 'Mode') {
        $answer = Read-Host 'Mode: 1) Auto  2) Balanced  3) Lean  4) Extreme'
        $mode = @{ '1' = 'Auto'; '2' = 'Balanced'; '3' = 'Lean'; '4' = 'Extreme' }
        if (-not $mode.ContainsKey($answer)) { Write-Host 'Cancelled.'; continue }
        Invoke-Kit @{ Action = 'Configure'; Mode = $mode[$answer] }
    }
    elseif ($entry.Kind -eq 'Log') {
        $answer = Read-Host 'State: 1) On  2) Off'
        $state = @{ '1' = 'On'; '2' = 'Off' }
        if (-not $state.ContainsKey($answer)) { Write-Host 'Cancelled.'; continue }
        Invoke-Kit @{ Action = 'Configure'; $entry.Name = $state[$answer] }
    }
    else {
        $answer = Read-Host 'State: 1) Auto  2) On  3) Off'
        $state = @{ '1' = 'Auto'; '2' = 'On'; '3' = 'Off' }
        if (-not $state.ContainsKey($answer)) { Write-Host 'Cancelled.'; continue }
        Invoke-Kit @{ Action = 'Configure'; $entry.Name = $state[$answer] }
    }
    Write-Host ''
}
