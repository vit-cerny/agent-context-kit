// <agent-context-kit:managed>
import { appendFile, mkdir, readFile } from "node:fs/promises"
import { homedir } from "node:os"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

type Settings = {
  mode?: string
  taskTag?: string
  logging?: {
    Usage?: string
    ToolOutput?: string
    Path?: string
  }
}

const configRoot = dirname(dirname(fileURLToPath(import.meta.url)))
const settingsPath = join(configRoot, "agent-context-kit.json")
const logPath = process.platform === "win32"
  ? join(homedir(), "AppData", "Local", "AgentContextKit", "usage.jsonl")
  : join(homedir(), ".local", "state", "agent-context-kit", "usage.jsonl")

async function settings(): Promise<Settings> {
  try {
    return JSON.parse(await readFile(settingsPath, "utf8")) as Settings
  } catch {
    return { logging: { Usage: "Off", ToolOutput: "Off" } }
  }
}

async function writeRecord(record: Record<string, unknown>, logPath: string) {
  try {
    await mkdir(dirname(logPath), { recursive: true })
    await appendFile(logPath, `${JSON.stringify(record)}\n`, { encoding: "utf8", flag: "a" })
  } catch {
    console.warn("[Agent Context Kit] Could not append a local usage record.")
  }
}

function number(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number(value)
  return Number.isFinite(parsed) ? parsed : 0
}

function textCharacters(value: unknown): number {
  if (typeof value === "string") return value.length
  if (!Array.isArray(value)) return 0
  return value.reduce((total, part) => {
    if (typeof part === "string") return total + part.length
    if (part && typeof part === "object" && "text" in part && typeof part.text === "string") {
      return total + part.text.length
    }
    return total
  }, 0)
}

function metadata(config: Settings) {
  return {
    mode: config.mode ?? "Auto",
    taskTag: config.taskTag || null,
    timestamp: new Date().toISOString(),
  }
}

function resolveLogPath(config: Settings) {
  const custom = config.logging?.Path?.trim()
  if (!custom) return logPath
  let resolved = custom.replace(/%([^%]+)%/g, (match, name: string) => process.env[name] ?? match)
  if (resolved.startsWith("~")) {
    resolved = join(homedir(), resolved.slice(1).replace(/^[\\/]+/, ""))
  }
  return resolved
}

export default async function AgentContextKitUsage(input: any) {
  const ctx = input
  const controller = new AbortController()
  const stepMetadata = new Map<string, { agent: string; providerId: string; modelId: string }>()

  void (async () => {
    for await (const event of ctx.event.subscribe({
      types: ["session.step.started", "session.step.ended"],
      signal: controller.signal,
    })) {
      if (event.type === "session.step.started") {
        stepMetadata.set(event.data.assistantMessageID, {
          agent: event.data.agent,
          providerId: event.data.model.providerID,
          modelId: event.data.model.id,
        })
        continue
      }
      const config = await settings()
      if (config.logging?.Usage !== "On") continue
      const data = event.data
      const tokens = data.tokens
      const step = stepMetadata.get(data.assistantMessageID)
      stepMetadata.delete(data.assistantMessageID)
      await writeRecord({
        type: "usage",
        ...metadata(config),
        sessionId: data.sessionID,
        assistantMessageId: data.assistantMessageID,
        agent: step?.agent ?? null,
        providerId: step?.providerId ?? null,
        modelId: step?.modelId ?? null,
        finish: data.finish,
        inputTokens: number(tokens.input),
        outputTokens: number(tokens.output),
        reasoningTokens: number(tokens.reasoning),
        cacheReadTokens: number(tokens.cache?.read),
        cacheWriteTokens: number(tokens.cache?.write),
        costUsd: number(data.cost),
      }, resolveLogPath(config))
    }
  })().catch(() => console.warn("[Agent Context Kit] Usage event listener stopped."))

  await ctx.tool.hook("execute.after", async (event: any) => {
    const config = await settings()
    if (config.logging?.ToolOutput !== "On") return
    const content = event.status === "completed"
      ? (event.result as { content?: unknown }).content
      : undefined
    const resultChars = textCharacters(content)
    await writeRecord({
      type: "tool",
      ...metadata(config),
      sessionId: event.sessionID,
      agent: event.agent,
      tool: event.tool,
      status: event.status,
      resultChars,
      estimatedResultTokens: Math.ceil(resultChars / 4),
    }, resolveLogPath(config))
  })

  return () => controller.abort()
}