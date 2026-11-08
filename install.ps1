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

$ErrorActionPreference = 'Stop'
$manager = Join-Path $PSScriptRoot 'scripts/manage.ps1'

& $manager @PSBoundParameters
