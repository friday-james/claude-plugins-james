#!/bin/bash

# Cook Stop Hook
# Prevents session exit when a cook loop is active
# Feeds Claude's output back with multi-AI consultation feedback

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if ralph-loop is active
COOK_STATE_FILE=".claude/cook-loop.local.md"

if [[ ! -f "$COOK_STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$COOK_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
# Extract consult_gemini flag (defaults to false if not present)
CONSULT_GEMINI=$(echo "$FRONTMATTER" | grep '^consult_gemini:' | sed 's/consult_gemini: *//' || echo "false")
# Extract consult_gpt5 flag (defaults to false if not present)
CONSULT_GPT5=$(echo "$FRONTMATTER" | grep '^consult_gpt5:' | sed 's/consult_gpt5: *//' || echo "false")
# Extract model configurations
GEMINI_MODEL=$(echo "$FRONTMATTER" | grep '^gemini_model:' | sed 's/gemini_model: *//' | sed 's/^"\(.*\)"$/\1/' || echo "gemini-3-flash-preview")
GPT5_MODEL=$(echo "$FRONTMATTER" | grep '^gpt5_model:' | sed 's/gpt5_model: *//' | sed 's/^"\(.*\)"$/\1/' || echo "gpt-5.2")
GPT5_REASONING=$(echo "$FRONTMATTER" | grep '^gpt5_reasoning:' | sed 's/gpt5_reasoning: *//' | sed 's/^"\(.*\)"$/\1/' || echo "xhigh")

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Cook loop: State file corrupted" >&2
  echo "   File: $COOK_STATE_FILE" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Cook loop is stopping. Run /ralph-loop again to start fresh." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Cook loop: State file corrupted" >&2
  echo "   File: $COOK_STATE_FILE" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "" >&2
  echo "   This usually means the state file was manually edited or corrupted." >&2
  echo "   Cook loop is stopping. Run /ralph-loop again to start fresh." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Cook loop: Max iterations ($MAX_ITERATIONS) reached."
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Cook loop: Transcript file not found" >&2
  echo "   Expected: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a Claude Code internal issue." >&2
  echo "   Cook loop is stopping." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format - one JSON per line)
# First check if there are any assistant messages
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Cook loop: No assistant messages found in transcript" >&2
  echo "   Transcript: $TRANSCRIPT_PATH" >&2
  echo "   This is unusual and may indicate a transcript format issue" >&2
  echo "   Cook loop is stopping." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Extract last assistant message with explicit error handling
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
if [[ -z "$LAST_LINE" ]]; then
  echo "⚠️  Cook loop: Failed to extract last assistant message" >&2
  echo "   Cook loop is stopping." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Parse JSON with error handling
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>&1)

# Check if jq succeeded
if [[ $? -ne 0 ]]; then
  echo "⚠️  Cook loop: Failed to parse assistant message JSON" >&2
  echo "   Error: $LAST_OUTPUT" >&2
  echo "   This may indicate a transcript format issue" >&2
  echo "   Cook loop is stopping." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "⚠️  Cook loop: Assistant message contained no text content" >&2
  echo "   Cook loop is stopping." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Check for completion promise (only if set)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  # -0777 slurps entire input, s flag makes . match newlines
  # .*? is non-greedy (takes FIRST tag), whitespace normalized
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  # Use = for literal string comparison (not pattern matching)
  # == in [[ ]] does glob pattern matching which breaks with *, ?, [ characters
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Cook loop: Detected <promise>$COMPLETION_PROMISE</promise>"
    rm "$COOK_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
# Skip first --- line, skip until second --- line, then print everything after
# Use i>=2 instead of i==2 to handle --- in prompt content
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$COOK_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Cook loop: State file corrupted or incomplete" >&2
  echo "   File: $COOK_STATE_FILE" >&2
  echo "   Problem: No prompt text found" >&2
  echo "" >&2
  echo "   This usually means:" >&2
  echo "     • State file was manually edited" >&2
  echo "     • File was corrupted during writing" >&2
  echo "" >&2
  echo "   Cook loop is stopping. Run /ralph-loop again to start fresh." >&2
  rm "$COOK_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter (portable across macOS and Linux)
# Create temp file, then atomically replace
TEMP_FILE="${COOK_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$COOK_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$COOK_STATE_FILE"

# Consult Gemini if enabled
GEMINI_FEEDBACK=""
if [[ "$CONSULT_GEMINI" == "true" ]]; then
  echo "🤖 Consulting Gemini for feedback..." >&2

  # Get the script directory to find consult-gemini.sh
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"

  # Call Gemini with the prompt, Claude's output, and model name
  if GEMINI_FEEDBACK=$("$SCRIPT_DIR/consult-gemini.sh" "$PROMPT_TEXT" "$LAST_OUTPUT" "$NEXT_ITERATION" "$GEMINI_MODEL" 2>&1); then
    echo "✅ Gemini ($GEMINI_MODEL) feedback received" >&2
  else
    echo "⚠️  Gemini consultation failed, continuing without feedback" >&2
    GEMINI_FEEDBACK=""
  fi
fi

# Consult GPT-5 if enabled
GPT5_FEEDBACK=""
if [[ "$CONSULT_GPT5" == "true" ]]; then
  echo "🤖 Consulting $GPT5_MODEL for feedback ($GPT5_REASONING reasoning)..." >&2

  # Get the script directory to find consult-gpt5.sh
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"

  # Call GPT-5 with the prompt, Claude's output, model, and reasoning level
  if GPT5_FEEDBACK=$("$SCRIPT_DIR/consult-gpt5.sh" "$PROMPT_TEXT" "$LAST_OUTPUT" "$NEXT_ITERATION" "$GPT5_MODEL" "$GPT5_REASONING" 2>&1); then
    echo "✅ $GPT5_MODEL feedback received" >&2
  else
    echo "⚠️  GPT-5 consultation failed, continuing without feedback" >&2
    GPT5_FEEDBACK=""
  fi
fi

# Build system message with iteration count and completion promise info
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | To stop: output <promise>$COMPLETION_PROMISE</promise> (ONLY when statement is TRUE - do not lie to exit!)"
else
  SYSTEM_MSG="🔄 Ralph iteration $NEXT_ITERATION | No completion promise set - loop runs infinitely"
fi

# Append Gemini feedback to system message if available
if [[ -n "$GEMINI_FEEDBACK" ]]; then
  SYSTEM_MSG="${SYSTEM_MSG}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GEMINI FEEDBACK ($GEMINI_MODEL - Critic & Advisor):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${GEMINI_FEEDBACK}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Append GPT-5 feedback to system message if available
if [[ -n "$GPT5_FEEDBACK" ]]; then
  SYSTEM_MSG="${SYSTEM_MSG}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GPT-5 FEEDBACK ($GPT5_MODEL - $GPT5_REASONING reasoning):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${GPT5_FEEDBACK}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Output JSON to block the stop and feed prompt back
# The "reason" field contains the prompt that will be sent back to Claude
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0
