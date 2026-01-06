---
description: "Cancel the active Cook loop"
argument-hint: ""
allowed-tools: ["Bash(rm -f .claude/cook-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Cook Loop

Remove the Cook loop state file to stop the loop:

```!
rm -f .claude/cook-loop.local.md
```

Cook loop cancelled. The next time Claude tries to exit, it will be allowed to do so normally.
