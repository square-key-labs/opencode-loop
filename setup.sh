#!/bin/bash

# OpenLoop Setup Script for OpenCode
# This script installs the OpenLoop plugin and commands
# Usage: curl -fsSL https://raw.githubusercontent.com/square-key-labs/opencode-loop/main/setup.sh | bash
#    or: ./setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OpenCode config directory
OPENCODE_DIR="${HOME}/.opencode"

echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════════════"
echo "           OpenLoop Setup for OpenCode"
echo "═══════════════════════════════════════════════════════════"
echo -e "${NC}"

# Check if bun is installed
check_bun() {
    if ! command -v bun &> /dev/null; then
        echo -e "${YELLOW}Bun is not installed. Installing bun...${NC}"
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
    fi
    echo -e "${GREEN}✓ Bun is available${NC}"
}

# Create directory structure
setup_directories() {
    echo -e "${BLUE}Setting up directories...${NC}"
    mkdir -p "${OPENCODE_DIR}/command"
    mkdir -p "${OPENCODE_DIR}/plugin"
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Create package.json
setup_package_json() {
    echo -e "${BLUE}Setting up package.json...${NC}"
    
    # Check if package.json exists and has content
    if [ -f "${OPENCODE_DIR}/package.json" ]; then
        # Merge or update existing package.json
        if command -v jq &> /dev/null; then
            # Use jq if available for proper JSON merging
            jq -s '.[0] * .[1]' "${OPENCODE_DIR}/package.json" <(echo '{"dependencies": {"@opencode-ai/plugin": "1.0.204"}}') > "${OPENCODE_DIR}/package.json.tmp"
            mv "${OPENCODE_DIR}/package.json.tmp" "${OPENCODE_DIR}/package.json"
        else
            # Simple overwrite if jq not available
            cat > "${OPENCODE_DIR}/package.json" << 'EOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.0.204"
  }
}
EOF
        fi
    else
        cat > "${OPENCODE_DIR}/package.json" << 'EOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.0.204"
  }
}
EOF
    fi
    echo -e "${GREEN}✓ package.json created${NC}"
}

# Create the plugin file
setup_plugin() {
    echo -e "${BLUE}Installing OpenLoop plugin...${NC}"
    cat > "${OPENCODE_DIR}/plugin/open-loop.ts" << 'PLUGIN_EOF'
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
PLUGIN_EOF
    echo -e "${GREEN}✓ OpenLoop plugin installed${NC}"
}

# Create command files
setup_commands() {
    echo -e "${BLUE}Installing slash commands...${NC}"
    
    # /loop command
    cat > "${OPENCODE_DIR}/command/loop.md" << 'EOF'
---
description: Start an OpenLoop for iterative task completion
---

Start an OpenLoop with the following task. Use the openloop-start tool to activate it.

**Task:** $ARGUMENTS

Parse the arguments:
- The main text is the prompt/task
- Look for `--max-iterations N` to set iteration limit
- Look for `--completion-promise TEXT` to set completion signal (default: DONE)

Example inputs:
- `/loop Fix all TypeScript errors` → prompt="Fix all TypeScript errors", defaults
- `/loop "Build REST API" --max-iterations 20` → prompt="Build REST API", max=20
- `/loop "Make tests pass" --completion-promise TESTS_GREEN` → custom completion

After starting the loop, immediately begin working on the task. When you complete work and go idle, the same prompt will be sent again. Your previous work persists in files.

**To complete the loop**, output: `<promise>DONE</promise>` (or your custom promise)

Only output this when the task is TRULY complete. Do not lie to exit.

EOF

    # /cancel-loop command
    cat > "${OPENCODE_DIR}/command/cancel-loop.md" << 'EOF'
---
description: Cancel the active OpenLoop
---

Cancel the current OpenLoop using the openloop-cancel tool.

EOF

    # /loop-status command
    cat > "${OPENCODE_DIR}/command/loop-status.md" << 'EOF'
---
description: Check OpenLoop status
---

Check the status of the current OpenLoop using the openloop-status tool.

EOF

    echo -e "${GREEN}✓ Slash commands installed${NC}"
}

# Install dependencies
install_deps() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    cd "${OPENCODE_DIR}"
    bun install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Main installation
main() {
    check_bun
    setup_directories
    setup_package_json
    setup_plugin
    setup_commands
    install_deps
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           OpenLoop Installation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Available commands in OpenCode:"
    echo -e "  ${YELLOW}/loop <task>${NC}        - Start an iterative loop"
    echo -e "  ${YELLOW}/cancel-loop${NC}        - Cancel the active loop"
    echo -e "  ${YELLOW}/loop-status${NC}        - Check loop status"
    echo ""
    echo -e "Example usage:"
    echo -e "  ${BLUE}/loop Fix all TypeScript errors${NC}"
    echo -e "  ${BLUE}/loop \"Build REST API\" --max-iterations 20${NC}"
    echo ""
    echo -e "${GREEN}Restart OpenCode to load the plugin.${NC}"
    echo ""
}

# Run main
main
