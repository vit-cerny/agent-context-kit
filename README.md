# Agent Context Kit

Small, reversible global defaults for lower-token coding-agent sessions—without disabling quality safeguards or loading skill bodies by default.

This repo combines a short shared policy with existing, specialized tools. It does **not** pretend one hook can compress every tool call in every harness. Host hooks have different coverage; lossy compression can hide evidence.

## Quick start (Windows)

```powershell
pwsh -File .\install.ps1 -Harness OpenCode -SetupRtk
```

This adds a small marked block to the user-global OpenCode `AGENTS.md`, preserving other content and backing it up once. `-SetupRtk` installs RTK's OpenCode hook only if its plugin is not already present. T3 Code uses the same OpenCode profile when it launches OpenCode under the same Windows user.

```powershell
pwsh -File .\install.ps1 -Action Status
pwsh -File .\install.ps1 -Action Disable
pwsh -File .\install.ps1 -Action Enable
```

Disable removes only this repo's marked instruction block. It does not uninstall or disable third-party tools already configured. RTK, Headroom, Ponytail, and Graphify each have their own native controls; see [the stack guide](docs/stack.md).

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
