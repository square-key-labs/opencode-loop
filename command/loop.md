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
