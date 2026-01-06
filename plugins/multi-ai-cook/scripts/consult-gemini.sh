#!/bin/bash

# Gemini Consultation Script for Ralph Loop
# Sends Claude's output to Gemini for review and advice

set -euo pipefail

# Check for required environment variable
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY not set" >&2
  exit 1
fi

# Read arguments
TASK_PROMPT="$1"
CLAUDE_OUTPUT="$2"
ITERATION="$3"
GEMINI_MODEL="${4:-gemini-3-flash-preview}"

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

# Build Gemini API request using jq to properly escape JSON
REQUEST_BODY=$(jq -n \
  --arg text "$PROMPT_TEXT" \
  '{
    "contents": [{
      "parts": [{
        "text": $text
      }]
    }],
    "generationConfig": {
      "temperature": 0.7,
      "maxOutputTokens": 2048
    }
  }')

# Call Gemini API
RESPONSE=$(curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$REQUEST_BODY" 2>&1)

# Check for API errors
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
  echo "Gemini API Error: $ERROR_MSG" >&2
  exit 1
fi

# Extract and output the feedback
FEEDBACK=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // "No response from Gemini"')

if [[ -z "$FEEDBACK" ]] || [[ "$FEEDBACK" == "No response from Gemini" ]]; then
  echo "Warning: Gemini returned empty response" >&2
  exit 1
fi

echo "$FEEDBACK"
