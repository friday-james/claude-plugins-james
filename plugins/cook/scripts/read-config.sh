#!/bin/bash

# Read Ralph configuration from .claude/ralph-config.json
# Outputs config values as shell variables

set -euo pipefail

# Look for config in current directory first, then home directory
CONFIG_FILE=""
if [[ -f ".claude/ralph-config.json" ]]; then
  CONFIG_FILE=".claude/ralph-config.json"
elif [[ -f "$HOME/.claude/ralph-config.json" ]]; then
  CONFIG_FILE="$HOME/.claude/ralph-config.json"
fi

# If no config file, output defaults
if [[ -z "$CONFIG_FILE" ]]; then
  echo "CONSULT_GEMINI=false"
  echo "CONSULT_GPT5=false"
  echo "GEMINI_MODEL=gemini-3-flash-preview"
  echo "GPT5_MODEL=gpt-5.2"
  echo "GPT5_REASONING=xhigh"
  exit 0
fi

# Read and parse config
CONSULTATION_ENABLED=$(jq -r '.consultation.enabled // false' "$CONFIG_FILE")
CONSULTANTS=$(jq -r '.consultation.consultants // [] | join(",")' "$CONFIG_FILE")

# Determine which consultants are enabled
CONSULT_GEMINI="false"
CONSULT_GPT5="false"

if [[ "$CONSULTATION_ENABLED" == "true" ]]; then
  if echo "$CONSULTANTS" | grep -q "gemini"; then
    CONSULT_GEMINI="true"
  fi
  if echo "$CONSULTANTS" | grep -q "gpt5"; then
    CONSULT_GPT5="true"
  fi
fi

# Read model configurations
GEMINI_MODEL=$(jq -r '.consultation.gemini.model // "gemini-3-flash-preview"' "$CONFIG_FILE")
GPT5_MODEL=$(jq -r '.consultation.gpt5.model // "gpt-5.2"' "$CONFIG_FILE")
GPT5_REASONING=$(jq -r '.consultation.gpt5.reasoning_effort // "xhigh"' "$CONFIG_FILE")

# Output as shell variables
echo "CONSULT_GEMINI=$CONSULT_GEMINI"
echo "CONSULT_GPT5=$CONSULT_GPT5"
echo "GEMINI_MODEL=$GEMINI_MODEL"
echo "GPT5_MODEL=$GPT5_MODEL"
echo "GPT5_REASONING=$GPT5_REASONING"
