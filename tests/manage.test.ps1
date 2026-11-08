$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$manager = Join-Path (Split-Path -Parent $PSScriptRoot) 'install.ps1'
$base = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'Temp/opencode'
$testRoot = Join-Path $base "agent-context-kit-test-$([Guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($testRoot)

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "TEST FAILED: $Message" }
}

try {
    $file = Join-Path $testRoot 'AGENTS.md'
    [IO.File]::WriteAllText($file, "User-owned rule.`r`n", [Text.UTF8Encoding]::new($false))

    & $manager -Action Enable -Harness OpenCode -ConfigRoot $testRoot
    & $manager -Action Enable -Harness OpenCode -ConfigRoot $testRoot
    $text = [IO.File]::ReadAllText($file)
    Assert-True (($text.Split('<!-- agent-context-kit:start -->').Length - 1) -eq 1) 'enable must be idempotent'
    Assert-True ($text.Contains('User-owned rule.')) 'existing instructions must survive install'
    Assert-True ($text.Contains('no auto-index or semantic upload')) 'Graphify privacy guardrail must survive install'
    Assert-True ($text.Contains('Delegate only when asked; brief children minimally')) 'delegation limits must survive install'
    Assert-True ([IO.File]::Exists("$file.agent-context-kit.bak")) 'first edit must create a backup'
    Assert-True ([IO.File]::ReadAllText("$file.agent-context-kit.bak").Contains('User-owned rule.')) 'backup must preserve original text'

    $settingsFile = Join-Path $testRoot 'agent-context-kit.json'
    $loggerPlugin = Join-Path $testRoot 'plugins/agent-context-kit.ts'
    Assert-True ([IO.File]::Exists($settingsFile)) 'enable must persist configurable settings'
    Assert-True ([IO.File]::Exists($loggerPlugin)) 'default logging must install the local OpenCode plugin'
    Assert-True ($text.Contains('one relevant skill')) 'policy must keep skill loading lazy'
    Assert-True ($text.Contains('glob/grep first')) 'policy must scope project reads'

    & $manager -Action Configure -Harness OpenCode -ConfigRoot $testRoot -Mode Extreme -DeepSeekSearch Off -Mcp On -GitHub Off -UsageLog Off -ToolOutputLog Off -TaskTag sample-task
    $settings = [IO.File]::ReadAllText($settingsFile) | ConvertFrom-Json
    $text = [IO.File]::ReadAllText($file)
    Assert-True ($settings.mode -eq 'Extreme') 'configure must persist selected mode'
    Assert-True ($settings.features.DeepSeekSearch -eq 'Off') 'configure must persist individual route toggles'
    Assert-True ($settings.features.GitHub -eq 'Off') 'configure must persist the GitHub toggle'
    Assert-True ($settings.taskTag -eq 'sample-task') 'configure must persist comparison tag'
    Assert-True ($text.Contains('DeepSeek search off')) 'disabled routes must be reflected in the policy'
    Assert-True ($text.Contains('GitHub off, local git only')) 'disabled GitHub route must be reflected in the policy'
    Assert-True (-not [IO.File]::Exists($loggerPlugin)) 'disabling all loggers must remove the unchanged plugin'

    $audit = & $manager -Action Audit -Harness OpenCode -ConfigRoot $testRoot *>&1 | Out-String
    Assert-True ($audit -match 'Policy: \d+ chars') 'audit must report the always-on policy size'
    Assert-True ($audit.Contains('MCP and GitHub toggles change instructions only')) 'audit must state what toggles do not unload'
    Assert-True ($audit.Contains('GitHub off, local git only')) 'audit must show the active policy lines'

    & $manager -Action Configure -Harness OpenCode -ConfigRoot $testRoot -GitHub off -UsageLog off
    $settings = [IO.File]::ReadAllText($settingsFile) | ConvertFrom-Json
    Assert-True ($settings.features.GitHub -ceq 'Off') 'lowercase values must be stored canonically'
    Assert-True ($settings.logging.Usage -ceq 'Off') 'lowercase log values must be stored canonically'

    & $manager -Action Enable -Harness OpenCode -ConfigRoot $testRoot -Mode Auto -DeepSeekSearch Auto -Mcp Off -GitHub Auto -UsageLog On -ToolOutputLog On -TaskTag ''

    [IO.File]::AppendAllText($file, "Manual addition.`r`n")
    & $manager -Action Disable -Harness OpenCode -ConfigRoot $testRoot
    $text = [IO.File]::ReadAllText($file)
    Assert-True (-not $text.Contains('<!-- agent-context-kit:start -->')) 'disable must remove managed block'
    Assert-True ($text.Contains('User-owned rule.')) 'disable must preserve existing instructions'
    Assert-True ($text.Contains('Manual addition.')) 'disable must preserve later manual edits'
    Assert-True (-not [IO.File]::Exists($loggerPlugin)) 'disable must remove the unchanged logger plugin'

    $toggleRoot = Join-Path $testRoot 'toggle'
    [void][IO.Directory]::CreateDirectory($toggleRoot)
    $toggleFile = Join-Path $toggleRoot 'AGENTS.md'
    $toggleOriginal = "Unmanaged rule.`r`n"
    [IO.File]::WriteAllText($toggleFile, $toggleOriginal, [Text.UTF8Encoding]::new($false))
    1..3 | ForEach-Object {
        & $manager -Action Enable -Harness OpenCode -ConfigRoot $toggleRoot
        & $manager -Action Disable -Harness OpenCode -ConfigRoot $toggleRoot
    }
    $toggleText = [IO.File]::ReadAllText($toggleFile)
    Assert-True ($toggleText -ceq $toggleOriginal) 'repeated toggles must not add trailing whitespace'

    [IO.File]::WriteAllText($file, "<!-- agent-context-kit:start -->`r`nmalformed`r`n", [Text.UTF8Encoding]::new($false))
    $before = [IO.File]::ReadAllText($file)
    $failed = $false
    try { & $manager -Action Disable -Harness OpenCode -ConfigRoot $testRoot } catch { $failed = $true }
    Assert-True $failed 'malformed markers must fail closed'
    Assert-True ([IO.File]::ReadAllText($file) -ceq $before) 'malformed input must remain unchanged'

    Write-Host 'All tests passed.'
} finally {
    if ([IO.Directory]::Exists($testRoot)) {
        [IO.Directory]::Delete($testRoot, $true)
    }
}
