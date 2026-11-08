# Agent Context Kit

Small, reversible global defaults for lower-token coding-agent sessions—without disabling quality safeguards or loading skill bodies by default.

This repo combines a short shared policy with existing, specialized tools. It does **not** pretend one hook can compress every tool call in every harness. Host hooks have different coverage; lossy compression can hide evidence.

## Install from GitHub (Windows)

```powershell
git clone https://github.com/vit-cerny/agent-context-kit
cd agent-context-kit
pwsh -File .\install.ps1 -Harness OpenCode -SetupRtk
```

Clone first so you can read the scripts before running them. The installer needs `scripts/manage.ps1`, so running `install.ps1` alone from a URL is not supported.

## Wrapper: `kit.cmd`

`kit.cmd` runs the same `install.ps1` actions with shorter commands:

```
kit.cmd install           Enable everything, set up RTK
kit.cmd on | off          Enable or disable the policy
kit.cmd status            Show mode, toggles, logger state
kit.cmd menu              Interactive numbered toggles
kit.cmd report            Show measured tokens and mode deltas
kit.cmd audit             Print always-on policy size (characters and rough tokens) with per-line breakdown
kit.cmd mode lean|balanced|auto|extreme
kit.cmd set <toggle> on|off|auto
kit.cmd logs <folder>
```

`set` accepts: `websearch deepseek browser agentreach skills narrowcontext mcp github rtk graphify usagelog tooloutputlog`.

`audit` prints the always-on policy size in characters and rough tokens, plus a per-line breakdown of what is always loaded. Full instructions: [toggle guide](docs/toggle.md). Cost and A/B results: [context comparison](docs/context-comparison.md).

Usage log can live on another drive. `logs <folder>` sets `-LogPath <folder>\usage.jsonl`, for example:

```
kit.cmd logs D:\AgentContextKit
```

which is equivalent to `-LogPath D:\AgentContextKit\usage.jsonl`. Token deltas in `report` are observed measurements, not guarantees.

## Quick start (Windows)
 
```powershell
pwsh -File .\install.ps1 -Harness OpenCode -SetupRtk
```

This adds a small marked block to the user-global OpenCode `AGENTS.md`, preserving other content and backing it up once. `-SetupRtk` installs RTK's OpenCode hook only if its plugin is not already present. T3 Code uses the same OpenCode profile when it launches OpenCode under the same Windows user.

```powershell
pwsh -File .\install.ps1 -Action Status
pwsh -File .\install.ps1 -Action Disable
pwsh -File .\install.ps1 -Action Enable
pwsh -File .\install.ps1 -Action Configure -Mode Lean -DeepSeekSearch Off -Graphify Off
pwsh -File .\install.ps1 -Action Report
pwsh -File .\install.ps1 -Action Audit
```

`Disable` removes this repo's marked instruction block and its unchanged logger plugin. It leaves third-party tools, OpenCode config, saved settings, and logs untouched. RTK, Headroom, Ponytail, and Graphify keep their native controls; see [the stack guide](docs/stack.md).

## Modes, toggles, and logs

Settings live in `agent-context-kit.json` beside the managed instructions. `-Action Configure` updates settings and applies the policy. Each tool toggle accepts `Auto`, `On`, or `Off`; `Auto` keeps that route available only when relevant.

| Setting | Choices | Purpose |
|---|---|---|
| `-Mode` | `Auto`, `Balanced`, `Lean`, `Extreme` | Choose how aggressively to avoid optional context and tool work. `Auto` picks by task risk; every mode keeps required research, validation, and safeguards. |
| `-WebSearch`, `-DeepSeekSearch`, `-Browser` | `Auto`, `On`, `Off` | Route current research, optional DeepSeek search, and interactive/visual browsing. |
| `-AgentReach`, `-Skills` | `Auto`, `On`, `Off` | Use the relevant platform router or one task-specific skill, never load all skill bodies/references. |
| `-NarrowContext` | `Auto`, `On`, `Off` | Search paths first and read only relevant files/sections. |
| `-Mcp` | `Auto`, `On`, `Off` | Tell the agent to avoid MCPs (`Off`, default) or allow them when needed. This is an instruction toggle, not a hard OpenCode server policy; the toolkit does not edit `opencode.json(c)` or add MCP servers. |
| `-GitHub` | `Auto`, `On`, `Off` | Prefer the `gh` CLI for repos, issues, and PRs; `Off` keeps work local. Instruction only. |
| `-Rtk`, `-Graphify` | `Auto`, `On`, `Off` | Control existing integrations; Graphify is query-only and never auto-indexes. |
| `-UsageLog`, `-ToolOutputLog` | `On`, `Off` | Log actual OpenCode token/cost/cache usage and tool-result size metadata. |

Examples:

```powershell
# Auto chooses Balanced, Lean, or Extreme per task.
pwsh -File .\install.ps1 -Action Configure -Mode Auto

# Turn off only redundant or unwanted routes.
pwsh -File .\install.ps1 -Action Configure -Mode Extreme -DeepSeekSearch Off -Browser Off -Graphify Off

# Disable this toolkit's telemetry while keeping its policy active.
pwsh -File .\install.ps1 -Action Configure -UsageLog Off -ToolOutputLog Off

# Compare the same task under Balanced and Lean; use a neutral tag, not prompt text.
pwsh -File .\install.ps1 -Action Configure -Mode Balanced -TaskTag parser-refactor
# Run task, then switch mode and repeat the same task.
pwsh -File .\install.ps1 -Action Configure -Mode Lean -TaskTag parser-refactor
pwsh -File .\install.ps1 -Action Report
```

The local logger writes `%LOCALAPPDATA%\AgentContextKit\usage.jsonl` on Windows. It stores provider-reported input/output/reasoning/cache tokens, cost, session IDs, tool names, and output character counts—not prompts, tool output, file contents, or credentials. Tool token estimates use `characters / 4` and are rough, not billed usage. `Report` compares actual token totals only for sessions sharing a user-supplied task tag; differences are observed deltas, not proof that the mode caused savings. `Status` verifies whether the policy and logger are active.

OpenCode's built-in websearch and a separate DeepSeek search tool are distinct routes. The built-in V2 websearch providers do not include DeepSeek; this toolkit routes to a DeepSeek tool only when the host exposes one. It does not install skills, configure credentials, add browser/MCP tools, or load every project file.

Optional CLI installs (downloads packages from their official registries):

```powershell
pwsh -File .\install.ps1 -Harness OpenCode -InstallTools
```

This installs Headroom and Graphify CLIs through `uv` if they are missing. It does not start a proxy, change model/provider configuration, add API credentials, or install a Graphify skill. Configure Headroom separately before routing any traffic through it.

## What gets enabled

| Layer | Use | Default behavior |
|---|---|---|
| Short global instructions | Keep work scoped; keep skill use lazy; give child agents compact briefs | Enabled by `install.ps1`; global OpenCode instructions also apply to child sessions in the same config context |
| RTK | Condense supported shell commands | Existing RTK integration is reused; only shell calls exposed to its hook are covered |
| Headroom | Compress supported request/tool context, with local retrieval of originals | Optional; not configured until you choose a provider/proxy route |
| Graphify | Query a code knowledge graph for a narrow codebase slice | CLI only; use per project when a graph exists. No automatic indexing or semantic API calls |
| Ponytail | Prefer the smallest complete change while retaining validation, safety, and quality | Reuse your existing global Ponytail-derived rules; this repo does not add a second copy |

## Design rules

- Keep always-on instructions short. Do not install or enumerate extra skills just to save tokens; load a specialized skill only when needed or requested.
- Reduce repeated/noisy context, not evidence. Use exact/raw output for diffs, security checks, test failures, and anything that must be cited precisely.
- Query a relevant Graphify subgraph when one already exists; verify important claims against source files.
- Delegate only independent work. Give each child a scoped brief with only needed context and ask for concise, evidence-backed results.
- Measure end-to-end input/output tokens and task correctness. A tool's “90% output reduction” is not a 90% bill reduction.

## Other harnesses

Use the shared policy with supported `AGENTS.md`/rules-file hosts:

```powershell
pwsh -File .\install.ps1 -Harness Codex
pwsh -File .\install.ps1 -Harness ClaudeCode
pwsh -File .\install.ps1 -Harness Gemini
pwsh -File .\install.ps1 -Harness All
```

Harness adapters are intentionally separate: permissions, hooks, compaction, and provider endpoints are not portable. The DeepSeek Harness fragment and T3 Code notes are in [docs/stack.md](docs/stack.md); the DSH fragment is at [`profiles/deepseek-harness-compaction.yaml`](profiles/deepseek-harness-compaction.yaml).

## Research and sources

Findings were checked against current project repositories and official docs on 2026-11-07:

- [OpenCode global config](https://opencode.ai/docs/config/) — user-wide config, compaction, tool-output limits, and plugin loading.
- [OpenCode server plugins](https://opencode.ai/docs/build/plugins/server/) — V2 hook APIs and their limits; context hooks change outgoing requests, not stored history.
- [RTK](https://github.com/rtk-ai/rtk) — supported command-output filters and OpenCode integration. RTK says it filters shell output; built-in file tools may bypass the shell hook.
- [Headroom](https://github.com/headroomlabs-ai/headroom) — local compression, proxy/wrapper, MCP and reversible retrieval. Its published savings are workload-dependent.
- [Headroom + OpenCode + DeepSeek](https://docs.headroomlabs.ai/docs/opencode-deepseek) — provider routing requires an explicit DeepSeek upstream; otherwise a wrapper may target OpenAI by default.
- [Graphify](https://github.com/Graphify-Labs/graphify) — local code graph/query workflow; code parsing can be local, while semantic extraction for documents/media may use a model.
- [Ponytail](https://github.com/DietrichGebert/ponytail) — concise behavior rules and quality-preserving benchmark claims; the published benchmark is project-authored and not a universal guarantee.
- [DeepSeek Harness tool-result pruner](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/compaction/compaction-tool-result-pruner) — optional, first-party pruning during compaction; it is syntactic head/tail trimming.
- [T3 Code](https://github.com/pingdotgg/t3code) — local-agent control surface; OpenCode global configuration applies when T3 launches the same OpenCode installation/profile.
- [DeepSeek context caching](https://api-docs.deepseek.com/guides/kv_cache) — repeated-prefix cache savings lower cost but do not shrink context-window use.

Claims in upstream READMEs are attributed as project claims, not independently established guarantees. See [the full stack guide](docs/stack.md) for installation, compatibility, and quality caveats.
