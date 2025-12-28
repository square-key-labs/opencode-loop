# OpenLoop for OpenCode

A self-referential loop plugin for [OpenCode](https://opencode.ai) that keeps the AI working on a task until completion. Inspired by the "Ralph Wiggum" agentic loop technique.

## What is OpenLoop?

OpenLoop allows you to give OpenCode a task and have it keep working on it automatically until it's done. When the AI goes idle, the same prompt is sent again, allowing it to continue working. The loop continues until:

1. The AI outputs a completion signal (`<promise>DONE</promise>`)
2. Maximum iterations are reached (if set)
3. You manually cancel it

This is perfect for iterative tasks like:
- "Fix all TypeScript errors"
- "Make all tests pass"
- "Refactor this codebase to use async/await"
- "Build a REST API with all CRUD operations"

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/square-key-labs/opencode-loop/main/setup.sh | bash
```

### Manual Installation

```bash
git clone https://github.com/square-key-labs/opencode-loop.git
cd opencode-loop
./setup.sh
```

### Requirements

- [OpenCode](https://opencode.ai) installed
- [Bun](https://bun.sh) (will be installed automatically if missing)

## Usage

### Start a Loop

```
/loop Fix all TypeScript errors in this project
```

### With Options

```
/loop "Build a REST API" --max-iterations 20
/loop "Make tests pass" --completion-promise TESTS_GREEN
```

### Check Status

```
/loop-status
```

### Cancel a Loop

```
/cancel-loop
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--max-iterations N` | Maximum number of iterations (0 = unlimited) | `0` |
| `--completion-promise TEXT` | Custom completion signal text | `DONE` |

## How It Works

1. You start a loop with `/loop <your task>`
2. OpenCode works on the task
3. When it goes idle, the plugin automatically sends the prompt again
4. The AI sees its previous work in the files and continues
5. When the task is truly complete, the AI outputs `<promise>DONE</promise>`
6. The loop ends

### Completion Detection

The AI signals completion by outputting:

```
<promise>DONE</promise>
```

Or with a custom promise:

```
<promise>YOUR_CUSTOM_TEXT</promise>
```

## Files Installed

| File | Location | Description |
|------|----------|-------------|
| `open-loop.ts` | `~/.opencode/plugin/` | Main plugin file |
| `loop.md` | `~/.opencode/command/` | `/loop` command |
| `cancel-loop.md` | `~/.opencode/command/` | `/cancel-loop` command |
| `loop-status.md` | `~/.opencode/command/` | `/loop-status` command |

## Uninstallation

### Using the uninstall script

```bash
curl -fsSL https://raw.githubusercontent.com/square-key-labs/opencode-loop/main/uninstall.sh | bash
```

Or if you cloned the repo:

```bash
./uninstall.sh
```

### Manual Uninstallation

```bash
rm ~/.opencode/plugin/open-loop.ts
rm ~/.opencode/command/loop.md
rm ~/.opencode/command/cancel-loop.md
rm ~/.opencode/command/loop-status.md
```

## Example Session

```
You: /loop Fix all TypeScript errors and make the build pass

OpenCode: I'll start working on fixing the TypeScript errors...
[Works on fixing errors]

═══════════════════════════════════════════════════════════
🔄 OpenLoop - Iteration 1
═══════════════════════════════════════════════════════════

[Continues working...]

═══════════════════════════════════════════════════════════
🔄 OpenLoop - Iteration 2
═══════════════════════════════════════════════════════════

[Finds and fixes remaining errors...]

All TypeScript errors have been fixed and the build passes successfully!

<promise>DONE</promise>

✅ OpenLoop: Completion detected! <promise>DONE</promise>
   Finished after 2 iteration(s).
```

## Troubleshooting

### Loop not starting?

1. Make sure you restarted OpenCode after installation
2. Check that the plugin file exists: `ls ~/.opencode/plugin/open-loop.ts`
3. Verify dependencies are installed: `cd ~/.opencode && bun install`

### Loop not stopping?

The AI must output `<promise>DONE</promise>` (or your custom promise) for the loop to end. You can always use `/cancel-loop` to force stop.

### State file issues?

If a loop gets stuck, you can manually clear the state:

```bash
find ~ -name "open-loop.state.json" -path "*/.opencode/*" -delete
```

## Contributing

Issues and PRs welcome at [github.com/square-key-labs/opencode-loop](https://github.com/square-key-labs/opencode-loop)

## License

MIT
