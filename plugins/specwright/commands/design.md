---
description: Generate implementation plan from specification
argument-hint: <ticket> | --amend <ticket>
allowed-tools: Read, Write, Glob, Edit, Task
---

# /design Command

Generates implementation plan from specification.

## Syntax

```
/design <ticket>
/design --amend <ticket>
```

## Prerequisites

| Command | Requires | Error if missing |
|---------|----------|------------------|
| `/design <ticket>` | `.specwright/{ticket}/spec.md` | "No specification found. Run `/define {ticket}` first." |
| `/design --amend <ticket>` | `.specwright/{ticket}/manifest.yaml` with phases | "No existing plan found. Use `/design {ticket}` for initial plan." |

---

## Output Location

All files created/updated in:
```
.specwright/{ticket}/
├── spec.md              # (exists, read-only)
├── manifest.yaml        # Updated with phases
├── phases/
│   ├── phase-1-tasks.yaml
│   ├── phase-2-tasks.yaml
│   ├── ...
│   └── tasks/
│       ├── TASK-001.yaml
│       ├── TASK-002.yaml
│       └── ...
└── audits/              # Created during /build
    └── phase-{n}/

# Shared index (not per-ticket):
.specwright/index/
├── architecture.yaml    # System structure
├── patterns.yaml        # Code conventions
├── dependencies.yaml    # External dependencies
└── symbols/             # Per-domain symbol files
    ├── auth.yaml
    ├── api.yaml
    └── ...
```

---

## /design (Full Generation)

### Step 1: Load Manifest and Project Root

Read `{ticket}` manifest to get project_root:

```yaml
# Read .specwright/{ticket}/manifest.yaml (search from cwd up if needed)
project_root: /absolute/path/to/project  # ← use this for all agent calls
```

**Project root was determined during `/define` and stored in manifest.**

If manifest not found, error: "No manifest found. Run `/define` first."

### Step 2: Read Specification

Read `{project_root}/.specwright/{ticket}/spec.md` completely.

Parse and extract:
- All requirements (REQ-XXX)
- Acceptance criteria
- Constraints
- Dependencies mentioned

### Step 3: Discover Codebase

**Spawn discovery_agent:**
```yaml
project_root: {absolute_path_to_project}
```

Wait for completion. Discovery agent writes to:
- `.specwright/index/architecture.yaml`
- `.specwright/index/patterns.yaml`
- `.specwright/index/dependencies.yaml`

**Spawn indexing_agent:**
```yaml
project_root: {absolute_path_to_project}
query_type: full_index
```

Wait for completion. If indexing fails, STOP and report error.

Index stored at: `.specwright/index/symbols/{domain}.yaml`

### Step 4: Technical Clarification (if needed)

If specification has gaps for implementation planning:
- Ask technical clarifying questions as needed
- Focus on: architecture choices, integration points, error handling strategy

**Only ask what you cannot determine yourself.**
- ✓ User preferences between valid architectural approaches
- ✓ Priority tradeoffs (performance vs maintainability)
- ✗ Existing code patterns (analyze the codebase)
- ✗ File structures, API signatures (use indexing_agent)

Stop when answers yield no new planning information.

### Step 5: Infrastructure Check

**Check `.specwright/index/dependencies.yaml` for:**
```yaml
dependency_management:
  exists: false  # ← If false, create infrastructure task
```

**If dependency management missing OR spec introduces new packages:**
- Create **TASK-001: Project infrastructure** in Phase 1
- Task creates `pyproject.toml` / `requirements.txt` / `package.json` as appropriate
- All other tasks depend on TASK-001

**For ports/migrations:** Never assume old dependencies exist. Always create dependency files fresh.

### Step 6: Two-Step Decomposition

**MANDATORY: Think through decomposition before generating files.**

**Step 1 — Reasoning (write out internally):**
```
Before generating phases and tasks:

1. Implementation boundaries:
   - What are the natural layers? (models → repositories → services → API)
   - What can be built independently?

2. Dependency chain:
   - What must exist before what?
   - Which components share interfaces?

3. Parallel execution opportunities:
   - Which tasks have no shared dependencies?
   - Can multiple tasks run in same phase?

4. File ownership analysis:
   - Which files does each task create/modify?
   - Any potential conflicts between parallel tasks?

5. Test strategy:
   - What tests per task?
   - Any integration tests at phase boundaries?
```

**Step 2 — Generate structure:**

**Constraints:**
- **Maximum 4 tasks per phase** (8 agents total: 4 implementation + 4 test)
- Target ~2-4 hours of human effort per phase
- Favor more phases over larger phases

### Step 7: Phase Ordering

Apply these principles:

| Priority | Layer | Reason |
|----------|-------|--------|
| 1 | Types/Models | Foundation for all other code |
| 2 | Interfaces | Contracts before implementations |
| 3 | Data Layer | Repositories before services |
| 4 | Business Logic | Services using repositories |
| 5 | API/Controllers | Expose services |
| 6 | Integration | Wire components together |
| 7 | Polish | Error handling, logging, metrics |
| 8 | Documentation | After implementation stable |

### Step 8: Generate Task Files

For each task, create `.specwright/{ticket}/phases/tasks/TASK-XXX.yaml`:

```yaml
id: TASK-001
title: "Create User model"
phase_id: 1
requirements: [REQ-001, REQ-003]

creates:
  files:
    - path: "src/models/user.go"
      purpose: "User domain model with validation"

  functions:
    - name: "NewUser"
      signature: "func NewUser(email, name string) (*User, error)"
    - name: "Validate"
      signature: "func (u *User) Validate() error"

  tests:
    - path: "src/models/user_test.go"
      cases:
        - name: "TestNewUser_ValidInput"
          description: "Creates user with valid email and name"
          input: {email: "test@example.com", name: "Test User"}
          expected: "User object with generated ID, no error"

        - name: "TestNewUser_InvalidEmail"
          description: "Returns error for invalid email format"
          input: {email: "not-an-email", name: "Test"}
          expected: "ErrInvalidEmail"

        - name: "TestNewUser_EmptyName"
          description: "Returns error for empty name"
          input: {email: "test@example.com", name: ""}
          expected: "ErrEmptyName"

modifies:
  files: []   # or list files this task modifies

dependencies:
  tasks: []   # task IDs this depends on
  symbols: ["types.ID", "validation.EmailRegex"]

new_dependencies: []  # packages this task introduces, e.g. ["pydantic>=2.0"]
```

### Step 9: File Ownership Tracking (CRITICAL)

**Each file can only be owned by ONE task per phase.**

During task generation:

1. Build ownership map:
```yaml
file_ownership:
  "src/models/user.go": TASK-001
  "src/models/session.go": TASK-002
  "src/repositories/user_repository.go": TASK-005
```

2. Check for conflicts:
   - If two tasks in same phase create/modify same file → **ADD DEPENDENCY**
   - If dependency creates cycle → **RESTRUCTURE TASKS**

3. Document ownership in task file:
```yaml
# In TASK-005.yaml
creates:
  files:
    - path: "src/repositories/user_repository.go"
      owner: TASK-005        # explicit ownership
      purpose: "PostgreSQL UserRepository implementation"
```

**Conflict resolution:**
```
Problem: TASK-005 and TASK-006 both modify api/routes.go
Solution: Add dependency TASK-006.dependencies.tasks = [TASK-005]
Result: TASK-006 runs after TASK-005 completes
```

### Step 10: Generate Phase Files

Create `.specwright/{ticket}/phases/phase-N-tasks.yaml` for each phase:

```yaml
phase_id: 1
phase_name: "Core Models"
status: pending

tasks:
  - id: TASK-001
    title: "Create User model"
    status: pending
    dependencies: []
    task_file: tasks/TASK-001.yaml

  - id: TASK-002
    title: "Create Session model"
    status: pending
    dependencies: []
    task_file: tasks/TASK-002.yaml

file_ownership:
  "src/models/user.go": TASK-001
  "src/models/session.go": TASK-002
```

### Step 11: Update Manifest

Update `.specwright/{ticket}/manifest.yaml`:

```yaml
ticket: {ticket}
status: planned           # ← changed from 'defined'
current_phase: 1
created: {original_timestamp}
defined: {defined_timestamp}
planned: {timestamp}      # ← added

phases:
  - id: 1
    name: "Core Models"
    status: pending
    task_file: phases/phase-1-tasks.yaml
    task_count: 2

  - id: 2
    name: "Repository Interfaces"
    status: pending
    task_file: phases/phase-2-tasks.yaml
    task_count: 3

  - id: 3
    name: "Repository Implementations"
    status: pending
    task_file: phases/phase-3-tasks.yaml
    task_count: 2

  # ... continues for all phases

total_tasks: 24
```

### Step 12: Present Plan Summary

Show user:

```
Plan generated for {ticket}

Phases: 8
Total Tasks: 24

Phase Breakdown:
  1. Core Models (2 tasks)
  2. Repository Interfaces (3 tasks)
  3. Repository Implementations (2 tasks)
  4. Service Layer (4 tasks)
  5. API Handlers (3 tasks)
  6. Middleware (2 tasks)
  7. Integration (3 tasks)
  8. Documentation (2 tasks)

Dependency Graph:
  Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
                                    ↓
                              Phase 6 → Phase 7 → Phase 8

Files: .specwright/{ticket}/phases/

Next: Run `/build {ticket}` to start implementation
```

---

## /design --amend

Updates existing plan based on spec changes.

### Safety Check (CRITICAL)

**Check ALL tasks across ALL phases:**

```yaml
# For each phase file
FOR phase IN phases:
  FOR task IN phase.tasks:
    IF task.status != "pending":
      BLOCK_AMENDMENT = true
      ADD task TO worked_tasks
```

**If ANY task has been worked (status != pending):**

```
ERROR: Cannot amend plan with worked tasks.

Tasks with work:
- TASK-003: completed (Phase 1)
- TASK-005: in_progress (Phase 2)
- TASK-008: failed (Phase 3)

Options:
1. Reset ALL tasks to pending (WARNING: loses completed work)
   Run: /design --amend --force {ticket}

2. Create new ticket with revised spec
   Run: /define "revised {description}"

3. Manually update specific task files
   Edit: .specwright/{ticket}/phases/tasks/TASK-XXX.yaml
```

**Do NOT proceed with amendment if worked tasks exist.**

### Amendment Flow (if all tasks pending)

1. **Read current state:**
   - manifest.yaml
   - All phase files
   - All task files

2. **Read updated spec.md**

3. **Diff requirements:**
   - Added requirements → new tasks needed
   - Removed requirements → tasks to remove
   - Modified requirements → tasks to update

4. **Update affected tasks only:**
   - Preserve unchanged task files exactly
   - Update modified task files
   - Create new task files for new requirements
   - Mark removed tasks as deprecated (don't delete)

5. **Re-validate file ownership:**
   - Ensure no new conflicts introduced
   - Add dependencies if needed

6. **Update phase files and manifest**

7. **Report changes:**
```
Plan amended for {ticket}

Changes:
- Added: TASK-025, TASK-026 (new auth requirements)
- Modified: TASK-008 (updated validation logic)
- Deprecated: TASK-012 (removed refresh token requirement)

New task count: 26 (was 24)

Run `/build {ticket}` to continue
```

---

## Task Granularity Guidelines

| Too Coarse | Right Size | Too Fine |
|------------|------------|----------|
| "Implement user service" | "Implement CreateUser method" | "Add import statement" |
| "Add authentication" | "Implement JWT token validation" | "Write one test case" |
| "Build API" | "Create /users POST endpoint" | "Add error message" |

**Each task should:**
- Be completable in one agent session (15-30 min equivalent)
- Have clear success criteria
- Produce testable output
- Own specific files (no overlap with parallel tasks)
- Map to 1-3 requirements

**Phase constraints:**
- Maximum 4 tasks per phase
- If more tasks needed, create additional phases

---

## Error Handling

| Condition | Action |
|-----------|--------|
| spec.md not found | Error: "No specification found. Run `/define {ticket}` first." |
| Indexing fails | Error: "Codebase indexing failed: {error}. Fix and retry." |
| manifest.yaml not found (--amend) | Error: "No existing plan. Use `/design {ticket}` for initial plan." |
| Worked tasks exist (--amend) | Error with list of worked tasks and options |
| Circular dependency detected | Error: "Circular dependency: TASK-A → TASK-B → TASK-A. Restructure needed." |
| File ownership conflict | Error: "Conflict: {file} owned by both TASK-X and TASK-Y. Add dependency." |

---

## Critical Reminders

1. **Discover then index** — Run discovery_agent then indexing_agent before decomposition
2. **Max 4 tasks per phase** — Keeps agent count manageable (8 agents per phase)
3. **Two-step decomposition** — Reason through structure before generating
4. **File ownership** — NO conflicts between parallel tasks
5. **Task files contain tests** — test_agent reads same file as implementation_agent
6. **Dependencies explicit** — Both task dependencies and symbol dependencies
7. **Preserve on amend** — Don't regenerate unchanged tasks
8. **Block worked amendments** — Never lose completed work silently
9. **Status transitions** — defined → planned
10. **Shared index** — Index lives at `.specwright/index/`, not per-ticket
