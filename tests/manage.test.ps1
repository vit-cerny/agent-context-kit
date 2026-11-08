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
    Assert-True ([IO.File]::Exists("$file.agent-context-kit.bak")) 'first edit must create a backup'
    Assert-True ([IO.File]::ReadAllText("$file.agent-context-kit.bak").Contains('User-owned rule.')) 'backup must preserve original text'

    [IO.File]::AppendAllText($file, "Manual addition.`r`n")
    & $manager -Action Disable -Harness OpenCode -ConfigRoot $testRoot
    $text = [IO.File]::ReadAllText($file)
    Assert-True (-not $text.Contains('<!-- agent-context-kit:start -->')) 'disable must remove managed block'
    Assert-True ($text.Contains('User-owned rule.')) 'disable must preserve existing instructions'
    Assert-True ($text.Contains('Manual addition.')) 'disable must preserve later manual edits'

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
