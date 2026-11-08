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

$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot 'scripts/manage.ps1'

& $manager @PSBoundParameters
