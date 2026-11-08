@echo off
setlocal EnableExtensions
set "KIT=%~dp0install.ps1"
set "PS=pwsh"
where pwsh >nul 2>nul || set "PS=powershell"

if "%~1"=="" goto help
if /i "%~1"=="install" goto install
if /i "%~1"=="on" goto on
if /i "%~1"=="off" goto off
if /i "%~1"=="status" goto status
if /i "%~1"=="report" goto report
if /i "%~1"=="audit" goto audit
if /i "%~1"=="mode" goto mode
if /i "%~1"=="set" goto set
if /i "%~1"=="menu" goto menu
if /i "%~1"=="logs" goto logs
if /i "%~1"=="help" goto help
goto help

:install
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Enable -Harness OpenCode -SetupRtk
goto end

:on
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Enable -Harness OpenCode
goto end

:off
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Disable -Harness OpenCode
goto end

:status
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Status -Harness OpenCode
goto end

:report
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Report -Harness OpenCode
goto end

:audit
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Audit -Harness OpenCode
goto end

:mode
if "%~2"=="" (
    echo Usage: kit.cmd mode auto^|balanced^|lean^|extreme
    goto end
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Configure -Harness OpenCode -Mode "%~2"
goto end

:set
if "%~2"=="" (
    echo Usage: kit.cmd set ^<toggle^> on^|off^|auto
    echo Toggles: websearch deepseek browser agentreach skills narrowcontext mcp github rtk graphify usagelog tooloutputlog
    goto end
)
set "NAME=%~2"
set "VALUE=%~3"
if "%VALUE%"=="" set "VALUE=auto"
set "PARAM="
if /i "%NAME%"=="websearch"     set "PARAM=-WebSearch"
if /i "%NAME%"=="deepseek"      set "PARAM=-DeepSeekSearch"
if /i "%NAME%"=="browser"       set "PARAM=-Browser"
if /i "%NAME%"=="agentreach"    set "PARAM=-AgentReach"
if /i "%NAME%"=="skills"        set "PARAM=-Skills"
if /i "%NAME%"=="narrowcontext" set "PARAM=-NarrowContext"
if /i "%NAME%"=="mcp"           set "PARAM=-Mcp"
if /i "%NAME%"=="github"        set "PARAM=-GitHub"
if /i "%NAME%"=="rtk"           set "PARAM=-Rtk"
if /i "%NAME%"=="graphify"      set "PARAM=-Graphify"
if /i "%NAME%"=="usagelog"      set "PARAM=-UsageLog"
if /i "%NAME%"=="tooloutputlog" set "PARAM=-ToolOutputLog"
if not defined PARAM (
    echo Unknown toggle: %NAME%
    goto help
)
if /i "%NAME%"=="usagelog"      if /i "%VALUE%"=="auto" set "VALUE=On"
if /i "%NAME%"=="tooloutputlog" if /i "%VALUE%"=="auto" set "VALUE=On"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Configure -Harness OpenCode %PARAM% "%VALUE%"
goto end

:menu
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\menu.ps1"
goto end

:logs
if "%~2"=="" (
    echo Usage: kit.cmd logs ^<folder-on-HDD^>
    echo Example: kit.cmd logs D:\AgentContextKit
    goto end
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%KIT%" -Action Configure -Harness OpenCode -LogPath "%~2\usage.jsonl"
goto end

:help
echo Agent Context Kit
echo.
echo   kit.cmd menu                 Interactive numbered toggles
echo   kit.cmd install              Enable everything, set up RTK
echo   kit.cmd on^|off              Enable or disable the policy
echo   kit.cmd status               Show mode, toggles, logger state
echo   kit.cmd audit                Check what context is always loaded
echo   kit.cmd report               Show measured tokens and mode deltas
echo   kit.cmd mode lean            Set mode: auto^|balanced^|lean^|extreme
echo   kit.cmd set mcp off          Toggle one route: on^|off^|auto
echo   kit.cmd logs D:\Kit          Keep usage logs on another disk
goto end

:end
endlocal
