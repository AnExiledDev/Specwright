---
description: Resume in-progress work on a ticket (token-efficient)
argument-hint: <ticket>
allowed-tools: Read, Write, Glob, Edit, Bash, Task
---

# /resume Command

Token-efficient resumption of in-progress work.

## Syntax

```
/resume <ticket>
```

## Prerequisites

- `.specwright/{ticket}/manifest.yaml` exists
- `manifest.status` is `in_progress` or `blocked`

**Error if missing:** "No in-progress work found. Use `/build {ticket}` to start."

---

## File Locations Reference

```
.specwright/{ticket}/
├── manifest.yaml                    # Read to determine state
├── blocked.md                       # Read if status: blocked
├── phases/
│   └── phase-{N}-tasks.yaml         # Current phase tasks
└── audits/
    └── phase-{n}/                   # Scan for incomplete work
        ├── TASK-XXX_implementation.yaml
        └── TASK-XXX_test.yaml

# Shared index (staleness check):
.specwright/index/
└── symbols/{domain}.yaml
```

---

## Difference from /build

| Aspect | /build | /resume |
|--------|--------|---------|
| State discovery | Full manifest scan | Minimal read |
| Index refresh | Always | Only if stale |
| Status reporting | Verbose | Terse |
| Spec re-reading | Yes | No |
| Use case | Fresh start or uncertain | Known in-progress |

`/resume` is optimized for continuing interrupted work with minimal token overhead.

---

## Execution Flow

### Step 1: Quick State Load

```
Read .specwright/{ticket}/manifest.yaml
Extract:
  - status (assert: in_progress | blocked)
  - current_phase
  - blocked_since (if blocked)

Read .specwright/{ticket}/phases/phase-{current_phase}-tasks.yaml
```

**No spec re-reading.** **No full manifest analysis.**

### Step 2: Validate Project Root

Before any file operations, validate project_root:

```
IF project_root not absolute path:
  Error: "project_root must be absolute path"

IF project_root does not exist:
  Error: "Project root not found: {path}"
```

All subsequent file paths derived from project_root.

### Step 3: Staleness Detection

Check if index needs refresh:

**Staleness algorithm:**
```
# Check any domain file in shared index
Read .specwright/index/symbols/ (pick first .yaml file)
Extract: generated timestamp

Find most recent source file modification:
  find {project_root} -type f \( -name "*.go" -o -name "*.ts" -o -name "*.py" \) \
    -newer .specwright/index/symbols/*.yaml | head -1

IF any source file newer than index:
  index_stale = true
ELSE:
  index_stale = false
```

**If stale:**
```
Spawn indexing_agent:
  project_root: {absolute_path}
  query_type: full_index

Wait for completion
```

**If not stale:**
```
Skip indexing (saves tokens)
```

### Step 4: Scan Existing Audits

Check for incomplete work from previous run:

```
Scan .specwright/{ticket}/audits/phase-{current_phase}/

IF audit files exist:
  # Determine which tasks already have audits
  completed_audits = []
  FOR each TASK-XXX_implementation.yaml:
    IF corresponding TASK-XXX_test.yaml exists:
      completed_audits.append(TASK-XXX)

  # Tasks with audits may not need re-execution
  # status_agent will reconcile
```

### Step 5: Handle Based on Status

#### If `status: in_progress`

Continue phase execution directly:

```
Identify ready tasks in current phase
Execute phase loop (same as /build Step 4)
```

#### If `status: blocked`

```
Read .specwright/{ticket}/blocked.md
Extract:
  - Remaining failures
  - Required actions
  - Last fix iteration

Report to user:
  "Phase {N} ({name}) is blocked.

  Issues:
  {summary from blocked.md}

  Options:
  1. Retry with fresh fix attempt (resets in_progress tasks)
  2. View full details: .specwright/{ticket}/blocked.md
  3. Cancel

  Choice?"
```

**If user confirms retry:**
```
# Reset in_progress tasks to pending
FOR task IN phase.tasks:
  IF task.status == "in_progress":
    task.status = "pending"

# Clear fix iteration counter (start fresh)
fix_iteration = 1

# Update manifest
manifest.status = "in_progress"
DELETE manifest.blocked_since

# Resume phase execution
EXECUTE_PHASE(current_phase)
```

### Step 6: Terse Progress Reporting

Unlike `/build`, `/resume` uses minimal output:

```
Resuming {ticket} at Phase {N}

Phase {N}/8: {remaining} tasks
- TASK-012 ✓
- TASK-013 ✓
- TASK-014 ✓
- TASK-015 ✓
Verify: PASS

Phase {N+1}/8: {remaining} tasks
[...]
```

**No redundant status messages.** Only:
- Phase number and remaining tasks
- Task completion markers
- Verification result
- Errors if they occur

### Step 7: Continue Normal Flow

After resumption setup, execution follows `/build` flow:
- Phase loop (Step 4)
- Ready task identification (Step 5)
- Parallel execution (Step 6)
- Status updates (Step 8)
- Verification (Step 9)
- Review-fix loop if needed (Step 11)
- Escalation if needed (Step 12)
- Completion (Step 13)

---

## When to Use /resume vs /build

| Scenario | Recommended | Reason |
|----------|-------------|--------|
| Fresh start after `/design` | `/build` | Full initialization needed |
| Context window cleared mid-execution | `/resume` | State exists, just continue |
| Session timeout during build | `/resume` | State preserved |
| After fixing blocked.md manually | `/resume` | Retry with fixes applied |
| Unsure of current state | `/build` | Full state discovery |
| After manual code changes | `/build` | Need full index refresh |
| After editing task files | `/build` | Need full state analysis |

---

## Staleness Scenarios

| Scenario | Index Stale? | Action |
|----------|--------------|--------|
| No source files changed | No | Skip indexing |
| User edited implementation | Yes | Refresh index |
| Only .specwright files changed | No | Skip indexing |
| New files added | Yes | Refresh index |
| Files deleted | Yes | Refresh index |

**Staleness check is cheap** — just file timestamp comparison.

---

## Blocked State Handling

When resuming from `blocked` status:

1. **Show blocked.md summary** — User needs context
2. **Confirm retry** — Don't auto-retry forever
3. **Reset in_progress tasks** — Clean slate for new attempt
4. **Reset fix_iteration** — Fresh 3 attempts
5. **Clear blocked markers** — Manifest and phase file

**Blocked.md is not deleted** — preserved for history. New blocked.md overwrites if blocked again.

---

## Error Handling

| Condition | Action |
|-----------|--------|
| status: planned | Error: "Work not started. Use `/build {ticket}`." |
| status: completed | Error: "Already complete. Nothing to resume." |
| status: defining | Error: "Specification incomplete. Complete `/define`." |
| status: defined | Error: "No plan. Run `/design {ticket}`." |
| Manifest corrupted | Error: "Manifest unreadable. Use `/status {ticket}` to diagnose." |
| Phase file missing | Error: "Phase {N} file missing. Run `/design {ticket}` to regenerate." |
| Index file missing | Trigger full reindex (not an error) |

---

## Example Session

```
User: /resume FEAT-jwt-auth

Orchestrator:
Resuming FEAT-jwt-auth at Phase 5

Checking index... up to date

Phase 5/8: 2 tasks remaining
- TASK-018 ✓
- TASK-019 ✓
Verify: PASS

Phase 6/8: 2 tasks
- TASK-020 ✓
- TASK-021 ✓
Verify: PASS

Phase 7/8: 3 tasks
- TASK-022 ✓
- TASK-023 ✓
- TASK-024 ✓
Verify: PASS

Phase 8/8: 2 tasks
- TASK-025 ✓
- TASK-026 ✓
Verify: PASS

Complete.
- Phases: 8/8
- Tasks: 26/26
```

**Example with blocked state:**

```
User: /resume FEAT-jwt-auth

Orchestrator:
Phase 5 (API Handlers) is blocked.

Issues:
- TestAuthMiddleware_ExpiredToken: Expected 401, got 500
- Attempted 3 fix iterations without resolution

Options:
1. Retry with fresh fix attempt
2. View details: .specwright/FEAT-jwt-auth/blocked.md
3. Cancel

User: 1

Orchestrator:
Resetting blocked state...

Checking index... stale, refreshing...
Index: 162 symbols

Phase 5/8: 3 tasks
- TASK-016 (was blocked) → pending
- TASK-017 ✓
- TASK-018 ✓
Verify: ✗ 1 failure

Fix iteration 1/3:
- Review: Token expiration check missing
- Fix: Added expiration validation
Verify: PASS

Phase 5 complete.
[continues...]
```

---

## Critical Reminders

1. **Validate project_root** — Must be absolute, must exist
2. **Scan audit files** — Check for completed work from previous run
3. **Staleness check** — Compare timestamps, not file contents
4. **Terse output** — Token efficiency is the point
5. **Confirm blocked retry** — User should know what they're retrying
6. **Reset on retry** — in_progress → pending, fresh fix iterations
7. **Absolute paths** — All paths derived from project_root
8. **Shared index** — Check `.specwright/index/`, not per-ticket
9. **No full manifest scan** — Trust current_phase from manifest
10. **Graceful degradation** — Missing index triggers refresh, not error
