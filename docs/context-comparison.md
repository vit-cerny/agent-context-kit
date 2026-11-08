# Context comparison: with and without the kit

## What is compared

Same task, same model, same prompt. The only difference is the marked block this kit appends to the global instructions file. The user message does not change.

Example prompt:

> Fix the whitespace bug in the toggle script and run its tests.

Without the kit, the model sees the prompt plus your own global instructions. With the kit, it sees exactly the same prompt and instructions plus this block:

```md
<!-- agent-context-kit:start -->
## Context budget (Agent Context Kit)
- Mode: Balanced for complex or high-risk work, Lean for routine, Extreme for low-risk repeats; never skip required research, validation, or safeguards. Scope: glob/grep first; read only relevant files and sections. Skills: one relevant skill only, plus references this task needs.
- Routes: websearch for current facts; DeepSeek search only when it adds coverage; browser only for interactive or visual page state; Agent Reach only for supported platform tasks, router plus needed reference; MCP off, prefer native tools and CLI; GitHub via gh CLI, not a GitHub MCP server.
- Tools: RTK summaries for routine shell output, raw for exact results, failures, audits, security; Graphify existing graphs only, narrow query, verify source, no auto-index or semantic upload.
- Delegate only when asked; brief children minimally; request concise evidence; never repeat chat.
<!-- agent-context-kit:end -->
```

## Static cost on this machine

Measured with `kit.cmd audit` on 2026-11-08:

| Item | Characters | Rough tokens (chars / 4) |
|---|---:|---:|
| Whole global `AGENTS.md` | 3,374 | ~844 |
| Your own instructions (Ponytail, security, vision, skill hints) | 2,406 | ~602 |
| Kit block including markers | 968 | ~243 |
| Kit policy text only | 905 | ~227 |

The token column is an estimate, not provider billing. The block is 7 lines: 2 markers, 1 heading, 4 directive lines.

## Earlier A/B run

The first release used a shorter three-line policy (about 84 tokens including markers). Four matched runs per mode, same model and prompt:

| Metric | Policy off | Policy on |
|---|---:|---:|
| Average context tokens | 7,930 | 8,106 |
| Difference | baseline | +176 |
| Exact output success | 3 of 4 | 4 of 4 |

The ranges overlapped, so this does not show a saving and does not establish a quality gain from four samples. The current block is larger than the one tested, so expect roughly +243 context tokens if tool behavior stays the same.

## Does it save tokens?

The policy does not shrink the prompt. It adds about 243 tokens on every request. It can only pay for itself by changing behavior:

- fewer speculative web searches and redundant lookups
- fewer broad file reads
- fewer MCP calls when a native tool or CLI exists
- smaller shell output through RTK summaries
- fewer child agents and shorter briefs

Those effects are workload-dependent. No claim of a net saving is supported until a matched run shows fewer total tokens with equal task success.

## Verdict

- Prompt cost: positive, about 243 tokens, always on.
- Tool-call savings: possible, not established.
- Quality: unchanged in the small sample, with a slight edge for the policy that is not statistically usable.
- Unnecessary material: the kit itself loads no skill body, no MCP schema, no project file, and no web page.

One known duplication in this setup: the delegation line repeats a rule already present in the user's global instructions. It is kept because other harnesses do not have that rule. Removing it would save about 25 tokens.

## Verify it yourself

```powershell
kit.cmd status   # policy enabled, toggles as expected
kit.cmd audit    # exact block, per-line cost, your own instruction size
kit.cmd report   # observed tokens, cache, cost, tool output after real runs
```

For a fair comparison:

1. Pick one small task with a checkable result.
2. Tag it, for example `-TaskTag parser-refactor`.
3. Run it in `balanced`, then in `lean` with the same prompt.
4. Run `report`. Compare token totals and whether both runs passed.

Treat a delta as observed, not causal. Cache hits, session length, and tool choices can dominate.

## What is not loaded

| Candidate | Loaded by this kit? |
|---|---|
| Skill descriptions | Host decides; the policy only says to pick one relevant skill |
| Skill bodies and references | No, except the one skill the task needs |
| MCP server schemas | No; the MCP toggle is instruction-only |
| Project files | No; glob/grep and targeted reads are requested instead |
| Web pages | No; search and fetch are explicit tool calls |
| Prompts, tool output, file contents, credentials | Never written to the usage log |
