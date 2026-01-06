# Ralph Wiggum Plugin

Implementation of the Ralph Wiggum technique for iterative, self-referential AI development loops in Claude Code.

## What is Ralph?

Ralph is a development methodology based on continuous AI agent loops. As Geoffrey Huntley describes it: **"Ralph is a Bash loop"** - a simple `while true` that repeatedly feeds an AI agent a prompt file, allowing it to iteratively improve its work until completion.

The technique is named after Ralph Wiggum from The Simpsons, embodying the philosophy of persistent iteration despite setbacks.

### Core Concept

This plugin implements Ralph using a **Stop hook** that intercepts Claude's exit attempts:

```bash
# You run ONCE:
/ralph-loop "Your task description" --completion-promise "DONE"

# Then Claude Code automatically:
# 1. Works on the task
# 2. Tries to exit
# 3. Stop hook blocks exit
# 4. Stop hook feeds the SAME prompt back
# 5. Repeat until completion
```

The loop happens **inside your current session** - you don't need external bash loops. The Stop hook in `hooks/stop-hook.sh` creates the self-referential feedback loop by blocking normal session exit.

This creates a **self-referential feedback loop** where:
- The prompt never changes between iterations
- Claude's previous work persists in files
- Each iteration sees modified files and git history
- Claude autonomously improves by reading its own past work in files

## Quick Start

```bash
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --completion-promise "COMPLETE" --max-iterations 50
```

Claude will:
- Implement the API iteratively
- Run tests and see failures
- Fix bugs based on test output
- Iterate until all requirements met
- Output the completion promise when done

**With AI consultation for enhanced feedback:**

```bash
# Using Gemini 3 Flash (fast + intelligent)
export GEMINI_API_KEY='your-api-key'
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --consult-gemini --completion-promise "COMPLETE" --max-iterations 50

# Using GPT-5.2 (maximum reasoning)
export OPENAI_API_KEY='your-api-key'
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --consult-gpt5 --completion-promise "COMPLETE" --max-iterations 50

# Using BOTH for dual AI feedback (recommended for complex tasks!)
export GEMINI_API_KEY='your-gemini-key'
export OPENAI_API_KEY='your-openai-key'
/ralph-loop "Build a REST API for todos. Requirements: CRUD operations, input validation, tests. Output <promise>COMPLETE</promise> when done." --consult-gemini --consult-gpt5 --completion-promise "COMPLETE" --max-iterations 50
```

The AI consultants will review Claude's work each iteration, catching bugs, suggesting improvements, and providing expert feedback.

## Commands

### /ralph-loop

Start a Ralph loop in your current session.

**Usage:**
```bash
/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"
```

**Options:**
- `--max-iterations <n>` - Stop after N iterations (default: unlimited)
- `--completion-promise <text>` - Phrase that signals completion
- `--consult-gemini` - Enable Gemini API consultation each iteration (requires GEMINI_API_KEY env var)
- `--consult-gpt5` - Enable GPT-5 API consultation with xhigh reasoning (requires OPENAI_API_KEY env var)

**Tip:** Instead of using flags every time, create a configuration file to set your preferences once. See [Configuration](#configuration) below.

### /cancel-ralph

Cancel the active Ralph loop.

**Usage:**
```bash
/cancel-ralph
```

## Configuration

Instead of passing flags every time you run Ralph, you can create a configuration file to set your preferences once.

### Setup

1. Copy the example config to your project or home directory:
   ```bash
   # For project-specific config
   cp .claude-plugin/ralph-config.example.json .claude/ralph-config.json

   # OR for global config (applies to all Ralph loops)
   cp .claude-plugin/ralph-config.example.json ~/.claude/ralph-config.json
   ```

2. Edit the config file to enable consultation and choose your AI models:
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

3. Set your API keys:
   ```bash
   export GEMINI_API_KEY='your-gemini-key'
   export OPENAI_API_KEY='your-openai-key'
   ```

4. Run Ralph without flags - it will use your config:
   ```bash
   /ralph-loop "Your task" --max-iterations 30 --completion-promise "DONE"
   ```

### Configuration Options

| Option | Values | Description |
|--------|--------|-------------|
| `consultation.enabled` | `true`/`false` | Enable/disable AI consultation globally |
| `consultation.consultants` | `["gemini"]`, `["gpt5"]`, or `["gemini", "gpt5"]` | Which AI(s) to consult |
| `consultation.gemini.model` | See [Gemini Models](#gemini-models) below | Which Gemini model to use |
| `consultation.gpt5.model` | `gpt-5.2`, `gpt-5.2-pro`, `gpt-5-mini`, `gpt-5-nano` | Which GPT-5 model to use |
| `consultation.gpt5.reasoning_effort` | `none`, `low`, `medium`, `high`, `xhigh` | How much reasoning to use |

### Gemini Models

**Latest Models (Recommended):**
- `gemini-3-pro-preview` - Most intelligent, best for complex tasks
- **`gemini-3-flash-preview` (Recommended)** - Most intelligent + fast, perfect for consultation
- `gemini-2.5-flash` - Stable, best price-performance
- `gemini-2.5-pro` - Advanced thinking model with superior reasoning
- `gemini-2.5-flash-lite` - Ultra fast, cost-optimized

**Previous Generation:**
- `gemini-2.0-flash` - Second generation workhorse with 1M context
- `gemini-2.0-flash-lite` - Fast and cost-efficient

Get a Gemini API key at: https://aistudio.google.com/apikey

### GPT-5 Models

- **`gpt-5.2` (Recommended)** - General purpose, best overall
- `gpt-5.2-pro` - Uses more compute for harder thinking on tough problems
- `gpt-5-mini` - Cost-optimized while maintaining quality
- `gpt-5-nano` - High-throughput for simple tasks

Get an OpenAI API key at: https://platform.openai.com/api-keys

### Command-Line Overrides

Command-line flags override config file settings:
```bash
# Config says Gemini only, but this uses both
/ralph-loop "Task" --consult-gemini --consult-gpt5 --max-iterations 20
```

## AI Consultation

Ralph can consult external AI models (Google Gemini, OpenAI GPT-5, or both) each iteration to act as **critics and advisors**, providing multi-AI feedback on Claude's work. This creates multi-AI collaboration loops where other AIs review Claude's output and provide structured feedback.

### Quick Start

**Option 1: Using Config File (Recommended)**
1. Create `.claude/ralph-config.json` (see [Configuration](#configuration))
2. Set API keys: `export GEMINI_API_KEY='...'` and/or `export OPENAI_API_KEY='...'`
3. Run: `/ralph-loop "Your task" --max-iterations 30`

**Option 2: Using Command-Line Flags**
```bash
# With Gemini
export GEMINI_API_KEY='your-key'
/ralph-loop "Build REST API with tests" --consult-gemini --max-iterations 30

# With GPT-5
export OPENAI_API_KEY='your-key'
/ralph-loop "Build REST API with tests" --consult-gpt5 --max-iterations 30

# With both (dual AI feedback!)
/ralph-loop "Build REST API with tests" --consult-gemini --consult-gpt5 --max-iterations 30
```

### How It Works

Each iteration:
1. Claude works on the task
2. Claude tries to exit
3. Stop hook intercepts and sends Claude's output to the configured AI(s)
4. AI consultant(s) review the work and provide feedback as critics & advisors
5. Feedback is included in the system message
6. The original prompt + AI feedback is fed back to Claude
7. Loop continues

**AI Feedback Structure:**
- **What's Working:** Acknowledges progress and correct approaches
- **Issues Found:** Identifies bugs, errors, or missed requirements
- **Suggestions:** Specific, actionable advice for next iteration
- **Focus Areas:** What to prioritize next

### When to Use AI Consultation

**Good for:**
- Complex tasks that benefit from multiple perspectives
- Catching subtle bugs or logical errors Claude might miss
- Learning from different AI approaches to problem-solving
- Tasks requiring code review or quality checks
- Comparing different AI reasoning styles (Gemini vs GPT-5)

**Not needed for:**
- Simple, straightforward tasks
- When API costs are a concern (adds API calls per iteration)
- Tasks where Claude has clear success criteria (tests, linters)

### Dual AI Consultation (Gemini + GPT-5)

Using both consultants provides:
- **Diverse Perspectives:** Different AI architectures spot different issues
- **Complementary Strengths:** Gemini 3's speed + GPT-5.2's deep reasoning
- **Higher Quality:** Catching more edge cases and providing richer feedback

Example config for dual consultation:
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
      "reasoning_effort": "high"
    }
  }
}
```

### Example Output

```
🔄 Ralph iteration 3 | To stop: output <promise>COMPLETE</promise>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GEMINI FEEDBACK (gemini-3-flash-preview - Critic & Advisor):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**What's Working:**
- Good progress on the API endpoints
- Test structure is solid

**Issues Found:**
- Missing input validation on POST /todos endpoint
- No error handling for database connection failures

**Suggestions:**
1. Add request body validation using a schema validator
2. Implement try-catch blocks around DB operations
3. Add tests for error cases

**Focus Areas:**
Priority: Input validation and error handling
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 GPT-5 FEEDBACK (gpt-5.2 - xhigh reasoning):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**What's Working:**
- RESTful design principles followed correctly
- Good separation of concerns in route handlers

**Issues Found:**
- SQL injection vulnerability in the GET /todos/:id endpoint
- Race condition possible in concurrent POST requests
- Memory leak in database connection pooling

**Suggestions:**
1. Use parameterized queries for all SQL operations
2. Implement transaction isolation for concurrent writes
3. Add connection pool timeout and max limit configuration

**Focus Areas:**
Critical: Security vulnerabilities must be addressed before anything else
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Prompt Writing Best Practices

### 1. Clear Completion Criteria

❌ Bad: "Build a todo API and make it good."

✅ Good:
```markdown
Build a REST API for todos.

When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- README with API docs
- Output: <promise>COMPLETE</promise>
```

### 2. Incremental Goals

❌ Bad: "Create a complete e-commerce platform."

✅ Good:
```markdown
Phase 1: User authentication (JWT, tests)
Phase 2: Product catalog (list/search, tests)
Phase 3: Shopping cart (add/remove, tests)

Output <promise>COMPLETE</promise> when all phases done.
```

### 3. Self-Correction

❌ Bad: "Write code for feature X."

✅ Good:
```markdown
Implement feature X following TDD:
1. Write failing tests
2. Implement feature
3. Run tests
4. If any fail, debug and fix
5. Refactor if needed
6. Repeat until all green
7. Output: <promise>COMPLETE</promise>
```

### 4. Escape Hatches

Always use `--max-iterations` as a safety net to prevent infinite loops on impossible tasks:

```bash
# Recommended: Always set a reasonable iteration limit
/ralph-loop "Try to implement feature X" --max-iterations 20

# In your prompt, include what to do if stuck:
# "After 15 iterations, if not complete:
#  - Document what's blocking progress
#  - List what was attempted
#  - Suggest alternative approaches"
```

**Note**: The `--completion-promise` uses exact string matching, so you cannot use it for multiple completion conditions (like "SUCCESS" vs "BLOCKED"). Always rely on `--max-iterations` as your primary safety mechanism.

## Philosophy

Ralph embodies several key principles:

### 1. Iteration > Perfection
Don't aim for perfect on first try. Let the loop refine the work.

### 2. Failures Are Data
"Deterministically bad" means failures are predictable and informative. Use them to tune prompts.

### 3. Operator Skill Matters
Success depends on writing good prompts, not just having a good model.

### 4. Persistence Wins
Keep trying until success. The loop handles retry logic automatically.

## When to Use Ralph

**Good for:**
- Well-defined tasks with clear success criteria
- Tasks requiring iteration and refinement (e.g., getting tests to pass)
- Greenfield projects where you can walk away
- Tasks with automatic verification (tests, linters)

**Not good for:**
- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Production debugging (use targeted debugging instead)

## Real-World Results

- Successfully generated 6 repositories overnight in Y Combinator hackathon testing
- One $50k contract completed for $297 in API costs
- Created entire programming language ("cursed") over 3 months using this approach

## Learn More

- Original technique: https://ghuntley.com/ralph/
- Ralph Orchestrator: https://github.com/mikeyobrien/ralph-orchestrator

## For Help

Run `/help` in Claude Code for detailed command reference and examples.
