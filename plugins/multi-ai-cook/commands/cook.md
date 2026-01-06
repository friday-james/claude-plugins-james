---
description: "Start Cook loop - iterative development with multi-AI consultation"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT] [--consult-gemini] [--consult-gpt5]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-cook-loop.sh)"]
hide-from-slash-command-tool: "true"
---

# Cook Command

Execute the setup script to initialize the Cook loop with multi-AI consultation:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-cook-loop.sh" $ARGUMENTS
```

Cook your task iteratively with feedback from Gemini 3, GPT-5, or both! When you try to exit, Cook will feed the prompt back along with AI critic feedback, creating a collaborative multi-AI development loop.

**CRITICAL RULE:** If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop.
