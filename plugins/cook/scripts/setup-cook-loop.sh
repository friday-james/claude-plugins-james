#!/bin/bash

# Cook Loop Setup Script
# Creates state file for in-session Cook loop with multi-AI consultation

set -euo pipefail

# Load configuration from file if exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/read-config.sh" ]]; then
  eval "$("$SCRIPT_DIR/read-config.sh")"
else
  # Defaults if config reader not available
  CONSULT_GEMINI="false"
  CONSULT_GPT5="false"
  GEMINI_MODEL="gemini-3-flash-preview"
  GPT5_MODEL="gpt-5.2"
  GPT5_REASONING="xhigh"
fi

# Parse arguments (command-line flags override config)
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Parse options and positional arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Cook - Multi-AI collaborative iterative development loop

USAGE:
  /cook [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start cooking (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  --consult-gemini               Enable Gemini API consultation each iteration (requires GEMINI_API_KEY env var)
  --consult-gpt5                 Enable GPT-5.2 API consultation with xhigh reasoning (requires OPENAI_API_KEY env var)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Cook loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use this for:
  - Multi-AI collaborative development with Gemini and/or GPT-5
  - Tasks requiring iterative refinement with expert AI feedback
  - Complex problems that benefit from multiple AI perspectives

EXAMPLES:
  /cook Build a todo API --consult-gemini --completion-promise 'DONE' --max-iterations 20
  /cook --consult-gpt5 --max-iterations 10 Fix the auth bug
  /cook --consult-gemini --consult-gpt5 Refactor cache layer  (dual AI feedback!)
  /cook --completion-promise 'TASK COMPLETE' Create a REST API

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Cook runs infinitely by default!

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/cook-loop.local.md

  # View full state:
  head -10 .claude/cook-loop.local.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --max-iterations requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   You provided: --max-iterations (with no number)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 50" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        echo "" >&2
        echo "   Invalid: decimals (10.5), negative numbers (-5), text" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --completion-promise requires a text argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --completion-promise 'DONE'" >&2
        echo "     --completion-promise 'TASK COMPLETE'" >&2
        echo "     --completion-promise 'All tests passing'" >&2
        echo "" >&2
        echo "   You provided: --completion-promise (with no text)" >&2
        echo "" >&2
        echo "   Note: Multi-word promises must be quoted!" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --consult-gemini)
      CONSULT_GEMINI="true"
      shift
      ;;
    --consult-gpt5)
      CONSULT_GPT5="true"
      shift
      ;;
    *)
      # Non-option argument - collect all as prompt parts
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# Join all prompt parts with spaces
PROMPT="${PROMPT_PARTS[*]}"

# Validate prompt is non-empty
if [[ -z "$PROMPT" ]]; then
  echo "❌ Error: No prompt provided" >&2
  echo "" >&2
  echo "   Cook needs a task description to work on." >&2
  echo "" >&2
  echo "   Examples:" >&2
  echo "     /cook Build a REST API for todos --consult-gemini" >&2
  echo "     /cook Fix the auth bug --max-iterations 20 --consult-gpt5" >&2
  echo "     /cook --completion-promise 'DONE' Refactor code --consult-gemini --consult-gpt5" >&2
  echo "" >&2
  echo "   For all options: /cook --help" >&2
  exit 1
fi

# Validate Gemini API key if consultation is enabled
if [[ "$CONSULT_GEMINI" == "true" ]] && [[ -z "$GEMINI_API_KEY" ]]; then
  echo "❌ Error: --consult-gemini requires GEMINI_API_KEY environment variable" >&2
  echo "" >&2
  echo "   Set your Gemini API key:" >&2
  echo "     export GEMINI_API_KEY='your-api-key-here'" >&2
  echo "" >&2
  echo "   Get an API key at: https://aistudio.google.com/apikey" >&2
  exit 1
fi

# Validate OpenAI API key if GPT-5 consultation is enabled
if [[ "$CONSULT_GPT5" == "true" ]] && [[ -z "$OPENAI_API_KEY" ]]; then
  echo "❌ Error: --consult-gpt5 requires OPENAI_API_KEY environment variable" >&2
  echo "" >&2
  echo "   Set your OpenAI API key:" >&2
  echo "     export OPENAI_API_KEY='your-api-key-here'" >&2
  echo "" >&2
  echo "   Get an API key at: https://platform.openai.com/api-keys" >&2
  exit 1
fi

# Create state file for stop hook (markdown with YAML frontmatter)
mkdir -p .claude

# Quote completion promise for YAML if it contains special chars or is not null
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/cook-loop.local.md <<EOF
---
active: true
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
consult_gemini: $CONSULT_GEMINI
consult_gpt5: $CONSULT_GPT5
gemini_model: "$GEMINI_MODEL"
gpt5_model: "$GPT5_MODEL"
gpt5_reasoning: "$GPT5_REASONING"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# Output setup message
cat <<EOF
👨‍🍳 Cook loop activated - Multi-AI collaborative development!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/} (ONLY output when TRUE - do not lie!)"; else echo "none (runs forever)"; fi)
Gemini consultation: $(if [[ "$CONSULT_GEMINI" == "true" ]]; then echo "enabled ($GEMINI_MODEL)"; else echo "disabled"; fi)
GPT-5 consultation: $(if [[ "$CONSULT_GPT5" == "true" ]]; then echo "enabled ($GPT5_MODEL - $GPT5_REASONING reasoning)"; else echo "disabled"; fi)

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you along with AI consultant feedback, creating a collaborative
multi-AI development loop where you iteratively improve based on expert advice.

$(if [[ "$CONSULT_GEMINI" == "true" ]]; then echo "🤖 $GEMINI_MODEL will review your output each iteration as critic & advisor"; fi)
$(if [[ "$CONSULT_GPT5" == "true" ]]; then echo "🤖 $GPT5_MODEL will review your output with $GPT5_REASONING reasoning"; fi)

To monitor: head -10 .claude/cook-loop.local.md

⚠️  WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

👨‍🍳
EOF

# Output the initial prompt if provided
if [[ -n "$PROMPT" ]]; then
  echo ""
  echo "$PROMPT"
fi

# Display completion promise requirements if set
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "CRITICAL - Cook Loop Completion Promise"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "To complete this loop, output this EXACT text:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo ""
  echo "STRICT REQUIREMENTS (DO NOT VIOLATE):"
  echo "  ✓ Use <promise> XML tags EXACTLY as shown above"
  echo "  ✓ The statement MUST be completely and unequivocally TRUE"
  echo "  ✓ Do NOT output false statements to exit the loop"
  echo "  ✓ Do NOT lie even if you think you should exit"
  echo ""
  echo "IMPORTANT - Trust the multi-AI process:"
  echo "  Even if you believe you're stuck, the task is impossible,"
  echo "  or you've been running too long - you MUST NOT output a"
  echo "  false promise statement. The AI consultants will provide"
  echo "  guidance. The loop is designed to continue until the"
  echo "  promise is GENUINELY TRUE. Trust the collaborative process."
  echo ""
  echo "  If the loop should stop, the promise statement will become"
  echo "  true naturally through iterative improvement. Do not force it."
  echo "═══════════════════════════════════════════════════════════"
fi
