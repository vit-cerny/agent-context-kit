# Stack and harness notes

## Use each tool for the waste it addresses

| Tool | Best fit | Limits / quality guard |
|---|---|---|
| **RTK** | Noisy supported shell output (tests, Git, package managers, search) | Its OpenCode integration hooks shell/bash calls; built-in `read`, `grep`, and other MCP/file tools may not pass through it. Read exact diffs and diagnose failures with raw output. Vendor output-reduction percentages are not end-to-end bill savings. |
| **Headroom** | Repeated/structured tool output and supported agent/provider traffic | Local reversible compression is useful, but low-redundancy prose may not shrink. Configure the correct upstream before using a proxy. For DeepSeek, use the explicit upstream documented by Headroom; a default wrapper route can otherwise send traffic to OpenAI. |
| **Graphify** | Codebase discovery and cross-file relationships | It is a knowledge graph, not a general compressor. Build/query a code-only graph locally when appropriate; semantic extraction for docs/media can call a model. Query small slices and verify source facts. Do not inject the full report on every prompt. |
| **Ponytail** | Reduce unnecessary implementation work while retaining correctness | Your existing global rules already distill its core behavior. Avoid adding a duplicate always-on prompt. Upstream benchmarks are project-authored and task/model-specific. |

Avoid stacking multiple lossy filters on the same content until a representative before/after test shows an end-to-end win with no quality regression. RTK and Headroom can be complementary (shell filtering before request-level compression), but compare actual usage and inspect difficult failures.

## OpenCode and T3 Code

OpenCode loads user-global instructions from `~/.config/opencode/AGENTS.md` and user plugins from `~/.config/opencode/plugins/`. T3 Code is a local control surface for agents; when it launches the same OpenCode build as the same user, these global instructions/plugins are the relevant integration point. Confirm with one test session in T3 after installing.

OpenCode V2 provides global `tool_output` and `compaction` settings, and server-plugin hooks can alter outgoing request context. This kit does not rewrite history or delete tools: aggressive message rewriting can hide information needed later. If you choose to set output caps, use values appropriate for your workload and test large failures/diffs before making them global. OpenCode docs: [config](https://opencode.ai/docs/config/) and [server plugin hooks](https://opencode.ai/docs/build/plugins/server/).

### Headroom + OpenCode + DeepSeek

Headroom's documented flow is a local proxy between OpenCode and DeepSeek. Install Headroom, then follow its [current DeepSeek guide](https://docs.headroomlabs.ai/docs/opencode-deepseek) to configure the upstream and add a Headroom provider. Keep credentials in a local secret store or supported secret reference; never commit them to this repository. Do not copy a stale model list—the proxy must expose the model IDs in your installed versions.

For a one-off wrapped terminal session, Headroom documents `headroom wrap opencode` with an explicit DeepSeek upstream. This is not automatically equivalent to T3 Code launching OpenCode directly. For T3, configure its OpenCode provider route as in the Headroom guide, then verify proxy health and token statistics before using it for important work.

### RTK controls

If RTK is installed, set up its OpenCode hook with:

```powershell
rtk init -g --opencode
```

Preview first with `rtk init -g --opencode --dry-run`. RTK's uninstall command can also remove its shared RTK instruction reference files; inspect its dry-run before using it. A one-command raw fallback is `rtk bypass <command>`.

## DeepSeek Harness (DSH)

DeepSeek Harness has its own, first-party compaction packages; OpenCode configuration does not configure DSH. When your DSH version supports these packages, mount the token meter, optional tool-result pruner, and compaction backend in this order:

Merge [`profiles/deepseek-harness-compaction.yaml`](../profiles/deepseek-harness-compaction.yaml) into the DSH configuration's plugin list:

```yaml
plugins:
  - name: '@deepseek-ai/dsh-token-meter'
  - name: '@deepseek-ai/dsh-compaction-tool-result-pruner'
  - name: '@deepseek-ai/dsh-compaction-basic'
```

The pruner trims oversized text to a head, marker, and tail only after compaction pressure qualifies; it makes no extra model call, but its middle truncation is syntactic. Check the version-matched [pruner docs](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/compaction/compaction-tool-result-pruner) and [compaction backend docs](https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/compaction/compaction-basic) before enabling. DSH is developer-preview software; review its [safety notice](https://github.com/deepseek-ai/deepseek-harness/blob/master/SAFETY.md) and use normal OS sandbox/permission controls.

DeepSeek API prompt caching can reduce the cost of repeated matching prefixes. It does **not** reduce context size; keep stable system/tool prefixes stable, and measure cached and uncached usage separately. See [DeepSeek caching docs](https://api-docs.deepseek.com/guides/kv_cache).

## Other harnesses

`install.ps1 -Harness All` adds the same short instruction block to OpenCode, Codex, Claude Code, and Gemini global rules files. It does not install hooks for those hosts. Install RTK/Headroom/Graphify through each project's supported native adapter and verify the hook is active. Open formats such as `AGENTS.md` and `SKILL.md` are portable content, not portable lifecycle behavior.

## Measure without fooling yourself

1. Pick 3–5 repeatable tasks (one routine change, one large test failure, one exact diff/review task).
2. Run baseline and optimized sessions with the same model, repo state, prompt, and permission level.
3. Record actual provider input/output tokens, cache hit/miss tokens where available, number of model/tool turns, latency, and whether required tests/security checks still pass.
4. Inspect any compressed result that changes a decision. If a critical detail is missing, use the raw/retrieval path and adjust or disable that filter.
5. Keep a layer only if the overall task stays correct and its full-session cost improves.

Never judge the whole stack by a shell-output compression percentage alone. More tool turns, a second summarization call, prompt-cache misses, or repeated retrieval can erase the apparent savings.
