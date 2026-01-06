# Cook Plugin 👨‍🍳

Multi-AI collaborative iterative development loops. Cook your tasks with expert feedback from Gemini 3, GPT-5, or both as critics and advisors.

## What is Cook?

Cook is a development methodology that combines **iterative AI loops** with **multi-AI consultation**. Unlike traditional development, Cook uses multiple AI models (Gemini + GPT-5) to review Claude's work each iteration, providing diverse perspectives and catching issues that a single AI might miss.

### Core Concept

```bash
# You run ONCE:
/cook "Your task" --consult-gemini --consult-gpt5 --max-iterations 30

# Then Cook automatically:
# 1. Claude works on the task
# 2. Claude tries to exit
# 3. Stop hook intercepts and sends output to AI consultants
# 4. Gemini 3 reviews as critic & advisor
# 5. GPT-5 reviews with deep reasoning
# 6. Combined feedback fed back to Claude
# 7. Repeat until completion
```

This creates a **collaborative multi-AI development loop** where:
- The prompt stays the same between iterations
- Claude's work persists in files
- Each iteration sees previous work and git history
- Multiple AIs provide complementary feedback
- Claude autonomously improves based on expert advice

## Quick Start

```bash
# Setup API keys
export GEMINI_API_KEY='your-gemini-key'
export OPENAI_API_KEY='your-openai-key'

# Cook with dual AI consultation
/cook "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --consult-gemini --consult-gpt5 --completion-promise "COMPLETE" --max-iterations 30
```

Claude will:
- Implement the API iteratively
- Run tests and see failures
- Receive feedback from both Gemini and GPT-5
- Fix bugs based on multi-AI advice
- Iterate until all requirements met
- Output the completion promise when done

## Installation

1. Install the Cook plugin in your Claude Code plugins directory
2. Get API keys:
   - Gemini: https://aistudio.google.com/apikey
   - OpenAI: https://platform.openai.com/api-keys
3. Set environment variables:
   ```bash
   export GEMINI_API_KEY='your-key'
   export OPENAI_API_KEY='your-key'
   ```

## Commands

### /cook

Start a Cook loop with multi-AI consultation.

**Usage:**
```bash
/cook "<prompt>" [OPTIONS]
```

**Options:**
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise <text>` - Phrase that signals completion
- `--consult-gemini` - Enable Gemini API consultation
- `--consult-gpt5` - Enable GPT-5 API consultation

**Tip:** Use a configuration file to set preferences once. See [Configuration](#configuration) below.

## Configuration

Create `.claude/cook-config.json` to set your preferences once:

```json
{
  "consultation": {
    "enabled": true,
    "consultants": ["gemini", "gpt5"],
    "gemini": {
      "model": "gemini-3-flash-preview"
    },
    "gpt5": {
      "model": "gpt-5.2",
      "reasoning_effort": "xhigh"
    }
  }
}
```

Then run without flags:
```bash
/cook "Your task" --max-iterations 30
```

### Configuration Options

| Option | Values | Description |
|--------|--------|-------------|
| `consultation.enabled` | `true`/`false` | Enable/disable AI consultation |
| `consultation.consultants` | `["gemini"]`, `["gpt5"]`, or `["gemini", "gpt5"]` | Which AI(s) to consult |
| `consultation.gemini.model` | See [Gemini Models](#gemini-models) | Which Gemini model |
| `consultation.gpt5.model` | `gpt-5.2`, `gpt-5.2-pro`, `gpt-5-mini`, `gpt-5-nano` | Which GPT-5 model |
| `consultation.gpt5.reasoning_effort` | `none`, `low`, `medium`, `high`, `xhigh` | Reasoning level |

### Gemini Models

**Latest (Recommended):**
- **`gemini-3-flash-preview`** - Most intelligent + fast, perfect for Cook
- `gemini-3-pro-preview` - Most intelligent, best for complex tasks
- `gemini-2.5-pro` - Advanced thinking with superior reasoning
- `gemini-2.5-flash` - Stable, best price-performance
- `gemini-2.5-flash-lite` - Ultra fast, cost-optimized

### GPT-5 Models

- **`gpt-5.2`** - General purpose, best overall (default)
- `gpt-5.2-pro` - Harder thinking for tough problems
- `gpt-5-mini` - Cost-optimized
- `gpt-5-nano` - High-throughput

## How It Works

Each Cook iteration:
1. **Claude works** on the task
2. **Claude exits** (or tries to)
3. **Stop hook intercepts** the exit
4. **AI consultants review:**
   - Gemini analyzes Claude's output
   - GPT-5 applies deep reasoning
5. **Feedback structured:**
   - What's working
   - Issues found
   - Specific suggestions
   - Focus areas
6. **Prompt + feedback** fed back to Claude
7. **Loop continues** until completion

### Example Multi-AI Feedback

```
🔄 Cook iteration 3 | To stop: output <promise>COMPLETE</promise>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GEMINI FEEDBACK (gemini-3-flash-preview - Critic & Advisor):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**What's Working:**
- Good progress on the API endpoints
- Test structure is solid

**Issues Found:**
- Missing input validation on POST /todos
- No error handling for DB failures

**Suggestions:**
1. Add schema validation
2. Implement try-catch for DB ops
3. Add error case tests

**Focus Areas:**
Priority: Input validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GPT-5 FEEDBACK (gpt-5.2 - xhigh reasoning):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**What's Working:**
- RESTful design principles followed
- Good separation of concerns

**Issues Found:**
- SQL injection vulnerability in GET /todos/:id
- Race condition in concurrent POSTs
- Memory leak in connection pooling

**Suggestions:**
1. Use parameterized queries
2. Implement transaction isolation
3. Add connection pool limits

**Focus Areas:**
CRITICAL: Security vulnerabilities first
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## When to Use Cook

**Perfect for:**
- Complex tasks needing multiple AI perspectives
- Code that requires thorough review
- Security-critical implementations
- Learning from diverse AI approaches
- Tasks where single-AI blind spots exist

**Not for:**
- Simple, trivial tasks
- When API costs are a major concern
- Tasks with immediately clear solutions

## Dual AI Benefits

Using both Gemini and GPT-5 provides:
- **Diverse Perspectives:** Different architectures spot different issues
- **Complementary Strengths:** Gemini's speed + GPT-5's depth
- **Higher Quality:** More edge cases caught
- **Richer Feedback:** Multiple viewpoints on approach

## Best Practices

### 1. Clear Completion Criteria

❌ Bad: "Build a todo API"

✅ Good:
```
Build a REST API for todos.

Requirements:
- All CRUD endpoints working
- Input validation implemented
- Tests passing (>80% coverage)
- README with API docs

Output <promise>COMPLETE</promise> when all requirements met.
```

### 2. Use Both AIs for Complex Tasks

```bash
# Simple task - one AI is fine
/cook "Add logging to function X" --consult-gemini --max-iterations 5

# Complex task - use both!
/cook "Implement auth system with JWT" --consult-gemini --consult-gpt5 --max-iterations 30
```

### 3. Set Safety Limits

Always use `--max-iterations` as a safety net:
```bash
/cook "Your task" --consult-gemini --consult-gpt5 --max-iterations 30
```

### 4. Configure Once, Use Forever

Create `.claude/cook-config.json` or `~/.claude/cook-config.json` with your preferences:
```json
{
  "consultation": {
    "enabled": true,
    "consultants": ["gemini", "gpt5"],
    "gemini": {"model": "gemini-3-flash-preview"},
    "gpt5": {"model": "gpt-5.2", "reasoning_effort": "high"}
  }
}
```

Then just run:
```bash
/cook "Task" --max-iterations 20
```

## Philosophy

Cook embodies key principles:

### 1. Collaboration > Solo Work
Multiple AI perspectives beat single AI every time.

### 2. Iteration > Perfection
Don't aim for perfect on first try. Let the loop and AI feedback refine the work.

### 3. Diverse Feedback > Echo Chamber
Different AIs have different blind spots. Use multiple models.

### 4. Trust the Process
The AI consultants will guide you. Don't output false completion promises.

## Real-World Results

Cook builds on the proven Ralph Wiggum methodology which has:
- Generated 6 repositories overnight in Y Combinator testing
- Completed $50k contracts for $297 in API costs
- Created entire programming languages through iterative loops

With multi-AI consultation, Cook takes this further by adding expert review and diverse perspectives to every iteration.

## Learn More

- Ralph Wiggum technique: https://ghuntley.com/ralph/
- Gemini AI Studio: https://aistudio.google.com
- OpenAI Platform: https://platform.openai.com

## For Help

Run `/cook --help` for command reference and examples.
