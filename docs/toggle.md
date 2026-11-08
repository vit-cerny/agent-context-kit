# Toggle guide

`kit.cmd` is the everyday control panel on Windows. It runs `install.ps1` with short commands. PowerShell-only users can call `install.ps1` directly; the actions are identical.

## Install

```powershell
git clone https://github.com/vit-cerny/agent-context-kit
cd agent-context-kit
kit.cmd install
```

`kit.cmd install` enables the policy, installs the settings file and local usage logger, and runs optional RTK setup when RTK is present. If you prefer explicit flags:

```powershell
pwsh -File .\install.ps1 -Harness OpenCode -SetupRtk
pwsh -File .\install.ps1 -Harness OpenCode -InstallTools
```

`-InstallTools` adds the Headroom and Graphify CLIs through `uv`. It does not start a proxy or change provider routes.

## Everyday commands

| Command | Effect |
|---|---|
| `kit.cmd menu` | Numbered menu; cycle any toggle, no flags to remember. |
| `kit.cmd on` | Enable the policy and logger; saved toggles stay. |
| `kit.cmd off` | Remove only this kit's marked block and its unchanged logger. |
| `kit.cmd status` | Policy state, every toggle, mode, logger state. |
| `kit.cmd audit` | Exact block, per-line cost, and your own instruction size. |
| `kit.cmd report` | Observed tokens, cache, cost, tool output, and same-tag deltas. |
| `kit.cmd set mcp off` | Set one toggle to `on`, `off`, or `auto`. |
| `kit.cmd mode lean` | Set `auto`, `balanced`, `lean`, or `extreme`. |
| `kit.cmd logs D:\Kit` | Keep the usage log on another drive. |

Double-click `kit.cmd` for the command list.

## Toggles

Each feature accepts `Auto`, `On`, or `Off`, except the two log switches, which accept `On` or `Off`. `Auto` keeps the route available only when the task needs it.

| Name for `set` | What it controls |
|---|---|
| `skills` | Load one relevant skill and only the references the task needs. |
| `websearch` | Built-in web search for current facts. |
| `deepseek` | DeepSeek search when the host exposes it. |
| `browser` | Browser tools for interactive or visual page state. |
| `agentreach` | Platform-specific router plus one needed reference. |
| `narrowcontext` | Glob/grep first and read only relevant file sections. |
| `mcp` | Use MCP tools only when no native tool or CLI covers the job. |
| `github` | Use the `gh` CLI for repos, issues, and PRs instead of a GitHub MCP server. |
| `rtk` | Shell output summaries for routine commands; raw output for exact work. |
| `graphify` | Query an existing code graph narrowly; never auto-index. |
| `usagelog` | Log provider token, cache, and cost records. |
| `tooloutputlog` | Log tool result character counts and rough token estimates. |

## What a toggle does not do

These are instruction toggles. They change what the agent chooses to load or call. They do not uninstall tools, delete skills, remove MCP servers from `opencode.json`, or edit provider routes. That is deliberate: turning a route off must not destroy the feature, so turning it back on needs no reinstall.

To cut real tool-schema tokens, disable the MCP server in OpenCode's own config. To keep the feature, leave it configured and let the policy route around it.

## Check that it works

1. `kit.cmd status` must say the target file is `enabled` and show your toggle values.
2. `kit.cmd audit` must show the four policy lines and their token estimate.
3. Run one real task, then `kit.cmd report`. A first record proves the logger is live.
4. For a comparison, tag two runs of the same task:

```
kit.cmd mode balanced
pwsh -File .\install.ps1 -Action Configure -TaskTag parser-refactor
rem run the task
kit.cmd mode lean
rem run the same task again
kit.cmd report
```

Use a neutral tag, not the prompt text. `report` compares sessions that share a tag. A delta is observed, not proof of causation.

## Recovery

- `off` removes only the marked block. Your own instructions before and after it stay.
- The first edit creates `AGENTS.md.agent-context-kit.bak` once. It is never overwritten.
- Malformed or duplicated markers stop the tool before any write.
- A foreign plugin at `plugins/agent-context-kit.ts` is never overwritten. Only a file carrying the `// <agent-context-kit:managed>` marker is upgraded.
- Settings live in `agent-context-kit.json` beside the managed file. Delete it to return to defaults.
- Logs contain no prompts, tool output, file contents, or credentials.

## Other harnesses

```powershell
pwsh -File .\install.ps1 -Harness Codex
pwsh -File .\install.ps1 -Harness ClaudeCode
pwsh -File .\install.ps1 -Harness Gemini
pwsh -File .\install.ps1 -Harness All
```

`kit.cmd` targets the OpenCode profile. For another harness, call `install.ps1` with `-Harness` explicitly. Adapters are separate because permissions, hooks, and compaction differ.
