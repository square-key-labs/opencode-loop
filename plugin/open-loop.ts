import type { Plugin } from "@opencode-ai/plugin"
import { tool } from "@opencode-ai/plugin"
import { readFile, writeFile, unlink, access, mkdir } from "fs/promises"
import { join } from "path"

/**
 * OpenLoop Plugin for OpenCode
 * 
 * A self-referential loop plugin that keeps the AI working on a task
 * until completion. Inspired by the Ralph Wiggum technique.
 * 
 * Usage:
 *   /loop "Your task description" --max-iterations 20 --completion-promise "DONE"
 *   /cancel-loop
 *   /loop-status
 */

interface OpenLoopState {
  active: boolean
  sessionId: string
  prompt: string
  iteration: number
  maxIterations: number
  completionPromise: string
  startedAt: string
}

const STATE_FILE = ".opencode/open-loop.state.json"
const DEFAULT_COMPLETION_PROMISE = "DONE"
const DEFAULT_MAX_ITERATIONS = 0 // 0 = unlimited

export const OpenLoopPlugin: Plugin = async ({ client, directory }) => {
  const statePath = join(directory, STATE_FILE)

  // State management helpers
  const readState = async (): Promise<OpenLoopState | null> => {
    try {
      await access(statePath)
      const content = await readFile(statePath, "utf-8")
      return JSON.parse(content)
    } catch {
      return null
    }
  }

  const writeState = async (state: OpenLoopState): Promise<void> => {
    const dir = join(directory, ".opencode")
    try {
      await access(dir)
    } catch {
      await mkdir(dir, { recursive: true })
    }
    await writeFile(statePath, JSON.stringify(state, null, 2))
  }

  const clearState = async (): Promise<void> => {
    try {
      await unlink(statePath)
    } catch {
      // File doesn't exist, that's fine
    }
  }

  // Track the last assistant message text for completion detection
  let lastAssistantText = ""
  let currentSessionId = ""

  return {
    // Capture session info when session is created/updated
    "session.updated": async (event: any) => {
      if (event?.id) {
        currentSessionId = event.id
      }
    },

    "session.created": async (event: any) => {
      if (event?.id) {
        currentSessionId = event.id
      }
    },

    // Track message updates to capture last assistant output
    "message.part.updated": async (event: any) => {
      if (event?.type === "text" && event?.text) {
        lastAssistantText = event.text
      }
    },

    // Core loop logic - fires when session goes idle
    event: async ({ event }) => {
      // Only handle session.idle events
      if (event.type !== "session.idle") return

      const state = await readState()
      if (!state?.active) return

      // Check max iterations (if set)
      if (state.maxIterations > 0 && state.iteration >= state.maxIterations) {
        console.log(`\n🛑 OpenLoop: Max iterations (${state.maxIterations}) reached.`)
        console.log(`   Task may not be complete. Review the work and restart if needed.`)
        await clearState()
        return
      }

      // Check for completion promise in last output
      // Matches: <promise>DONE</promise> (with optional whitespace)
      const promiseRegex = /<promise>\s*(.*?)\s*<\/promise>/is
      const match = lastAssistantText.match(promiseRegex)
      
      if (match && match[1].trim() === state.completionPromise) {
        console.log(`\n✅ OpenLoop: Completion detected! <promise>${state.completionPromise}</promise>`)
        console.log(`   Finished after ${state.iteration} iteration(s).`)
        await clearState()
        return
      }

      // Not complete - continue the loop
      state.iteration++
      await writeState(state)

      // Build iteration message
      const iterationHeader = [
        ``,
        `═══════════════════════════════════════════════════════════`,
        `🔄 OpenLoop - Iteration ${state.iteration}${state.maxIterations > 0 ? ` / ${state.maxIterations}` : ""}`,
        `═══════════════════════════════════════════════════════════`,
        ``,
        `COMPLETION: Output <promise>${state.completionPromise}</promise> when task is TRULY complete.`,
        ``,
        `RULES:`,
        `  • Only output the promise when the statement is 100% true`,
        `  • Do NOT lie to exit the loop`,
        `  • Your previous work is in the files - build on it`,
        `  • Check git status/diff to see what changed`,
        ``,
        `═══════════════════════════════════════════════════════════`,
        ``,
      ].join("\n")

      console.log(`\n🔄 OpenLoop: Starting iteration ${state.iteration}...`)

      // Send the same prompt again
      try {
        await client.session.prompt({
          path: { id: state.sessionId },
          body: {
            parts: [
              { type: "text", text: iterationHeader + state.prompt }
            ],
          },
        })
      } catch (err) {
        console.error(`\n❌ OpenLoop: Failed to send prompt:`, err)
        await clearState()
      }
    },

    // Custom tools for starting/canceling loops
    tool: {
      "openloop-start": tool({
        description: `Start an OpenLoop - a self-referential loop that re-sends the same prompt each time the session goes idle. The loop continues until you output <promise>COMPLETION_TEXT</promise> or max iterations is reached. Use this for iterative tasks like "fix all errors", "make tests pass", etc.`,
        args: {
          prompt: tool.schema.string().describe("The task prompt to iterate on"),
          maxIterations: tool.schema.number().optional().describe("Maximum iterations (0 = unlimited, default: 0)"),
          completionPromise: tool.schema.string().optional().describe("Text that signals completion when wrapped in <promise> tags (default: DONE)"),
        },
        async execute(args, ctx) {
          // Check if loop already active
          const existingState = await readState()
          if (existingState?.active) {
            return `❌ OpenLoop already active (iteration ${existingState.iteration}). Use openloop-cancel to stop it first.`
          }

          const sessionId = currentSessionId || (ctx as any)?.sessionId || ""
          if (!sessionId) {
            return `❌ Could not determine session ID. Please try again.`
          }

          const state: OpenLoopState = {
            active: true,
            sessionId,
            prompt: args.prompt,
            iteration: 0,
            maxIterations: args.maxIterations ?? DEFAULT_MAX_ITERATIONS,
            completionPromise: args.completionPromise ?? DEFAULT_COMPLETION_PROMISE,
            startedAt: new Date().toISOString(),
          }

          await writeState(state)

          const response = [
            ``,
            `🔄 OpenLoop Started!`,
            `═══════════════════════════════════════════════════════════`,
            ``,
            `Prompt: "${args.prompt.length > 100 ? args.prompt.substring(0, 100) + "..." : args.prompt}"`,
            ``,
            `Max Iterations: ${state.maxIterations === 0 ? "Unlimited" : state.maxIterations}`,
            `Completion: <promise>${state.completionPromise}</promise>`,
            ``,
            `The loop will start on your next idle. Work on the task now!`,
            `When complete, output: <promise>${state.completionPromise}</promise>`,
            ``,
            `═══════════════════════════════════════════════════════════`,
          ].join("\n")

          return response
        },
      }),

      "openloop-cancel": tool({
        description: "Cancel the active OpenLoop",
        args: {},
        async execute() {
          const state = await readState()
          if (!state?.active) {
            return `ℹ️ No active OpenLoop to cancel.`
          }

          const iterations = state.iteration
          await clearState()

          return [
            ``,
            `🛑 OpenLoop Cancelled`,
            `═══════════════════════════════════════════════════════════`,
            ``,
            `Completed iterations: ${iterations}`,
            `Original prompt: "${state.prompt.substring(0, 50)}..."`,
            ``,
            `═══════════════════════════════════════════════════════════`,
          ].join("\n")
        },
      }),

      "openloop-status": tool({
        description: "Check the status of the current OpenLoop",
        args: {},
        async execute() {
          const state = await readState()
          if (!state?.active) {
            return `ℹ️ No active OpenLoop.`
          }

          const elapsed = Date.now() - new Date(state.startedAt).getTime()
          const elapsedMin = Math.floor(elapsed / 60000)

          return [
            ``,
            `📊 OpenLoop Status`,
            `═══════════════════════════════════════════════════════════`,
            ``,
            `Active: Yes`,
            `Iteration: ${state.iteration}${state.maxIterations > 0 ? ` / ${state.maxIterations}` : ""}`,
            `Running for: ${elapsedMin} minutes`,
            `Completion: <promise>${state.completionPromise}</promise>`,
            ``,
            `Prompt: "${state.prompt.substring(0, 80)}..."`,
            ``,
            `═══════════════════════════════════════════════════════════`,
          ].join("\n")
        },
      }),
    },
  }
}
