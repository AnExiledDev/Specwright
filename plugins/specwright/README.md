# Specwright Plugin

Spec-driven development automation that transforms natural language requirements into fully implemented, tested, and verified code through orchestrated AI agents.

## What Specwright Does

Specwright solves the problem of specification-implementation drift by using the **spec as the single source of truth**. When you describe what you want:

1. It generates a formal specification through guided questions
2. It decomposes that spec into phased tasks with clear dependencies
3. Implementation and test agents work **in parallel from the same spec**—divergence is caught immediately when tests fail
4. A verification pipeline (lint → type check → tests) runs after each phase
5. If verification fails, an automatic review-fix loop attempts repairs up to 3 times before escalating

The result: auditable, resumable workflows where every decision is tracked and code always matches spec.

## Installation

```bash
# Add the marketplace
/plugin marketplace add AnExiledDev/Specwright

# Install the plugin
/plugin install specwright
```

### Prerequisites

The `indexing` agent requires [ast-grep](https://ast-grep.github.io/) for codebase symbol extraction.

```bash
# npm (recommended)
npm install -g @ast-grep/cli

# Cargo
cargo install ast-grep --locked

# pip
pip install ast-grep-cli

# Homebrew (macOS/Linux)
brew install ast-grep

# Arch Linux
pacman -S ast-grep
```

Verify installation: `ast-grep --version`

## Usage

Launch Claude Code with the orchestrator system prompt:

```bash
claude --system-prompt-file /path/to/ORCHESTRATOR.md
```

---

## Complete Workflow

### Phase 1: Define (`/define`)

Creates a formal specification from your description.

```
You: /define Add JWT authentication to the API

Specwright:
  1. Detects ticket type → FEAT-jwt-authentication
  2. Asks structured questions about scope, behavior, constraints
  3. Generates spec.md in EARS format
  4. Presents for your approval
  5. Creates manifest.yaml (status: defined)
```

**Output:** `.specwright/FEAT-jwt-authentication/spec.md`

The specification uses [EARS format](https://www.iaria.org/conferences2009/filesICCGI09/ICCGI_2009_Tutorial_EARS_Mavin.pdf) for unambiguous requirements:

| Pattern | Example |
|---------|---------|
| Ubiquitous | "The system SHALL encrypt all passwords" |
| Event-driven | "WHEN user submits login, system SHALL validate credentials" |
| State-driven | "WHILE session is active, system SHALL refresh token every 15 minutes" |
| Optional | "WHERE 2FA is enabled, system SHALL require verification code" |
| Complex | "IF login fails 3 times THEN system SHALL lock account for 30 minutes" |

### Phase 2: Design (`/design`)

Decomposes the specification into an executable plan.

```
Specwright:
  1. Reads spec.md completely
  2. Indexes your codebase (extracts types, functions, interfaces)
  3. Asks technical clarification questions if needed
  4. Generates phased task hierarchy
  5. Updates manifest.yaml (status: planned)
```

**Output:**
- `.specwright/{ticket}/phases/phase-1-tasks.yaml` through `phase-N-tasks.yaml`
- `.specwright/{ticket}/phases/tasks/TASK-001.yaml` through `TASK-NNN.yaml`
- `.specwright/{ticket}/index/symbols.yaml`

**Phasing Strategy:**
- Each phase represents ~2-4 hours of human developer effort
- Phases follow architectural layers: Types → Interfaces → Data → Services → API → Integration
- No file ownership conflicts within a phase (enables parallelism)
- More smaller phases = tighter verification loops = easier debugging

**Task Structure:**
```yaml
id: TASK-006
title: "Implement PostgreSQL UserRepository"
creates:
  files: ["src/repositories/user_repository.py"]
  functions:
    - name: create
      signature: "def create(self, user: User) -> User"
  tests:
    - name: test_create_success
      input: "valid User object"
      expected: "No error, user persisted with ID"
dependencies:
  tasks: [TASK-005]              # Must complete first
  symbols: ["models.User"]       # Needs this interface
```

### Phase 3: Build (`/build`)

Executes the plan with parallel agents and verification.

```
FOR each phase:
  1. Index codebase (updates symbol cache)
  2. Find ready tasks (pending status, dependencies met)
  3. For each ready task, spawn IN PARALLEL:
     - implementation_agent → writes production code
     - test_agent → writes tests from same spec
  4. Wait for both agents to complete
  5. Run verification pipeline:
     - Lint (ruff, eslint, golangci-lint, etc.)
     - Type check (mypy, tsc, go build, etc.)
     - Tests (pytest, npm test, go test, etc.)

  IF verification passes → next phase

  IF verification fails → enter review-fix loop:
     - Iteration 1: Find all issues, apply all fixes
     - Iteration 2: Focus on remaining issues, conservative fixes
     - Iteration 3: Surgical fix on root cause

     IF still failing after 3 iterations:
       → Write blocked.md with failure history
       → Set status: blocked
       → Escalate to user
```

**Why parallel implementation + tests?** Both agents read the same task specification. If the implementation doesn't match what the test expects (based on the spec), the test fails. Drift is caught immediately, not weeks later.

### Resuming & Revising

**`/resume`** - Continue interrupted work

```
Specwright:
  1. Loads manifest.yaml (minimal read)
  2. Checks if symbol index is stale (compares timestamps)
  3. If stale: re-indexes. If fresh: skips (token efficient)
  4. Continues from current_phase

  If status is 'blocked':
    → Shows failure history from blocked.md
    → Asks if you want to retry
    → Resets failed tasks to in_progress
```

**`/revise`** - Modify specification

```
Specwright:
  1. Loads existing spec.md
  2. Warns if build is in progress
  3. Gathers your revision requests
  4. Shows before/after diff
  5. Requires your approval
  6. Updates spec with modification markers (preserves history)
  7. Reports impact on existing plan
```

Safe to revise only when all tasks are still pending. Mid-build revisions require careful consideration.

### Checking Status

**`/status`** - Read-only progress report

```
Specwright:
  - Reads manifest.yaml
  - Shows: ticket status, current phase, task completion counts
  - No agents spawned, no modifications made
```

---

## File Structure

After running `/define` and `/design`, your project contains:

```
.specwright/FEAT-jwt-authentication/
├── spec.md                     # Your specification (EARS format)
├── manifest.yaml               # State machine + progress tracking
├── blocked.md                  # Created only if escalation needed
├── index/
│   └── symbols.yaml            # Codebase symbol map
└── phases/
    ├── phase-1-tasks.yaml      # Phase 1 task list + file ownership
    ├── phase-2-tasks.yaml      # Phase 2 task list + file ownership
    └── tasks/
        ├── TASK-001.yaml       # Individual task specifications
        ├── TASK-002.yaml
        └── ...
```

**manifest.yaml** tracks the state machine:

```yaml
ticket_id: FEAT-jwt-authentication
status: in_progress  # defining → defined → planned → in_progress → completed|blocked
current_phase: 2
phases:
  - id: 1
    name: "Core Models"
    status: completed
    task_count: 3
  - id: 2
    name: "Repository Layer"
    status: in_progress
    task_count: 4
timestamps:
  created: 2024-01-15T10:30:00Z
  last_updated: 2024-01-15T14:22:00Z
```

---

## Agents

Seven specialized agents handle execution:

| Agent | Purpose | Runs | Input | Output |
|-------|---------|------|-------|--------|
| **implementation** | Writes production code | Parallel with test | Task spec + 10 relevant symbols | Implementation files |
| **test** | Writes tests from spec | Parallel with impl | Task spec + 10 relevant symbols | Test files |
| **verification** | Runs lint → type → tests | After impl+test | Phase files + project | Pass/fail report |
| **review** | Analyzes failures | After failed verification | Failures + task specs | Fix instructions |
| **fix** | Applies fixes | After review | Issues + instructions | Modified files |
| **indexing** | Extracts codebase symbols | Phase start | Project root | symbols.yaml |
| **status** | Updates manifest | After agents complete | Agent audits | Updated manifest |

**Token Efficiency:** The indexing agent extracts all symbols (functions, types, interfaces) from your codebase. Implementation and test agents receive only the **10 most relevant symbols** for their task—not entire files. This keeps context focused and costs down.

---

## Skills

Optional knowledge libraries that agents can invoke:

| Skill | When Used |
|-------|-----------|
| **specwright-error-handling** | Implementing error handling, retry logic, logging |
| **specwright-test-patterns** | Writing tests (AAA structure, naming, coverage) |
| **specwright-review-standards** | Reviewing code quality (function design, organization) |
| **specwright-security-review** | Security-sensitive code (auth, injection, secrets) |

Agents invoke skills automatically when relevant to their task.

---

## Error Handling & Escalation

Three-tier approach:

| Tier | Error Type | Action |
|------|------------|--------|
| **Auto-fix** | Implementation bugs, test bugs | Fixed immediately by agents |
| **Review-fix loop** | Verification failures | Up to 3 automated attempts |
| **User escalation** | Spec ambiguity, environment issues | Blocked status, awaits your decision |

When blocked, `.specwright/{ticket}/blocked.md` contains:
- Complete failure history
- What was tried
- Root cause analysis
- Suggested resolution paths

---

## Quick Reference

| Command | Prerequisites | Creates/Updates |
|---------|--------------|-----------------|
| `/define` | Description of what you want | spec.md, manifest.yaml |
| `/design` | spec.md exists, status: defined | phases/*.yaml, tasks/*.yaml, symbols.yaml |
| `/build` | Plan exists, status: planned | Implementation files, test files |
| `/resume` | Any in-progress or blocked ticket | Continues from current state |
| `/revise` | spec.md exists | Updated spec.md with history |
| `/status` | Any ticket exists | Nothing (read-only) |

---

## Example Session

```
> /define Add rate limiting to the API endpoints

[Specwright asks: Which endpoints? What limits? How to handle exceeded limits?]

> All authenticated endpoints. 100 requests per minute per user. Return 429 with retry-after header.

[Specwright generates spec.md, asks for approval]

> Approved

[manifest.yaml created: status=defined]

> /design

[Specwright indexes codebase, finds existing middleware patterns]
[Generates 3 phases, 8 tasks]
[Phase 1: Rate limit types + interface]
[Phase 2: Redis-backed implementation]
[Phase 3: Middleware integration + tests]

[manifest.yaml updated: status=planned]

> /build

[Phase 1: implementation_agent + test_agent run in parallel]
[verification_agent: lint ✓, type check ✓, tests ✓]
[Phase 1 complete]

[Phase 2: agents run...]
[verification fails: Redis connection test failing]
[review_agent: missing test Redis setup]
[fix_agent: adds test container configuration]
[verification: all pass]
[Phase 2 complete]

[Phase 3: completes successfully]
[manifest.yaml: status=completed]

Rate limiting implemented:
- src/middleware/rate_limiter.py
- tests/middleware/test_rate_limiter.py
- src/config/rate_limit.py
- Updated src/server/routes.py
```

---

## Further Documentation

- **ORCHESTRATOR.md** - Complete orchestrator rules and state machine
- **commands/*.md** - Detailed command specifications
- **agents/*.md** - Agent input/output contracts

## License

MIT - See LICENSE file.
