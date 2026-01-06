#!/bin/bash

# GPT-5 Consultation Script for Ralph Loop
# Sends Claude's output to GPT-5.2 for review with maximum reasoning effort

set -euo pipefail

# Check for required environment variable
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "Error: OPENAI_API_KEY not set" >&2
  exit 1
fi

# Read arguments
TASK_PROMPT="$1"
CLAUDE_OUTPUT="$2"
ITERATION="$3"
GPT5_MODEL="${4:-gpt-5.2}"
GPT5_REASONING="${5:-xhigh}"

# Build the prompt text
PROMPT_TEXT="You are an expert code reviewer and technical advisor working with an AI agent (Claude) that is iteratively solving a programming task in a loop.

**Original Task:**
${TASK_PROMPT}

**Claude's Latest Output (Iteration ${ITERATION}):**
${CLAUDE_OUTPUT}

**Your Role:**
Act as a critic and advisor. Review Claude's work and provide:

1. **What's Working:** Briefly acknowledge progress and correct approaches
2. **Issues Found:** Identify bugs, logical errors, missed requirements, or poor practices
3. **Suggestions:** Specific, actionable advice for the next iteration
4. **Focus Areas:** What Claude should prioritize next

Be concise but thorough. Focus on actionable feedback that will help Claude improve in the next iteration. If the work looks complete and correct, say so clearly.

**Your Feedback:**"

# Build GPT-5.2 API request using Responses API with configured reasoning
REQUEST_BODY=$(jq -n \
  --arg model "$GPT5_MODEL" \
  --arg text "$PROMPT_TEXT" \
  --arg reasoning "$GPT5_REASONING" \
  '{
    "model": $model,
    "input": $text,
    "reasoning": {
      "effort": $reasoning
    },
    "text": {
      "verbosity": "medium"
    }
  }')

# Call GPT-5.2 API using Responses endpoint
RESPONSE=$(curl -s -X POST \
  "https://api.openai.com/v1/responses" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$REQUEST_BODY" 2>&1)

# Check for API errors
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
  echo "GPT-5 API Error: $ERROR_MSG" >&2
  exit 1
fi

# Extract the text content from response
# GPT-5.2 Responses API returns items array with text content
FEEDBACK=$(echo "$RESPONSE" | jq -r '
  .items[]?
  | select(.type == "text")
  | .text
  // empty' | head -1)

if [[ -z "$FEEDBACK" ]]; then
  echo "Warning: GPT-5 returned empty response" >&2
  exit 1
fi

echo "$FEEDBACK"
