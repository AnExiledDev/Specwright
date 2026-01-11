---
description: Execute the implementation plan for a ticket
argument-hint: <ticket>
allowed-tools: Read, Write, Glob, Edit, Bash, Task
---

# /build Command

Executes the implementation plan.

## Syntax

```
/build <ticket>
```

## Prerequisites

- `.specwright/{ticket}/manifest.yaml` exists
- `manifest.status` is `planned`, `in_progress`, or `blocked`
- At least one phase defined in `manifest.phases`

**Error if missing:** "No plan found. Run `/design {ticket}` first."

---

## File Locations Reference

```
.specwright/{ticket}/
├── spec.md                          # Read-only specification
├── manifest.yaml                    # Workflow state (updated)
├── blocked.md                       # Created if escalation needed
├── phases/
│   ├── phase-1-tasks.yaml           # Phase 1 task list (updated)
│   ├── phase-2-tasks.yaml           # Phase 2 task list
│   └── tasks/
│       ├── TASK-001.yaml            # Individual task specs
│       └── ...
└── audits/
    └── phase-{n}/                   # Per-phase audit files
        ├── TASK-XXX_implementation.yaml
        ├── TASK-XXX_test.yaml
        ├── phase_verification.yaml
        ├── review.yaml              # If fixes needed
        └── fix_iteration_{n}.yaml   # Fix attempts

# Shared index (not per-ticket):
.specwright/index/
├── architecture.yaml
├── patterns.yaml
├── dependencies.yaml
└── symbols/{domain}.yaml
```

---

## Execution Flow

### Step 1: Initialize

```
Read .specwright/{ticket}/manifest.yaml
Determine current_phase (from manifest, or 1 if fresh start)
Update manifest.status → in_progress (if was 'planned')
```

### Step 2: State Discovery

Determine execution mode from manifest status:

| Manifest Status | Behavior |
|-----------------|----------|
| `planned` | Fresh start from phase 1 |
| `in_progress` | Resume from `current_phase` |
| `blocked` | Retry blocked phase (reset `in_progress` tasks to `pending`) |
| `completed` | Report: "Already complete. Nothing to do." → EXIT |
| `defining` | Error: "Specification incomplete. Complete `/define`." |
| `defined` | Error: "No plan. Run `/design {ticket}` first." |

### Step 3: Update Index

**Before starting any phase execution:**

```
Spawn indexing_agent:
  project_root: {absolute_path}
  query_type: full_index
```

Wait for completion. If indexing fails, STOP and report error.

Index stored at `.specwright/index/symbols/` (shared across tickets).

### Step 4: Phase Loop

For each phase from `current_phase` to final phase:

```
EXECUTE_PHASE(phase_id):
  1. Read .specwright/{ticket}/phases/phase-{phase_id}-tasks.yaml
  2. Identify ready tasks
  3. Execute ready tasks (parallel: impl + test per task)
  4. Collect audits
  5. Update task statuses via status_agent
  6. Run verification
  7. Handle verification result
     ├── PASS → mark phase complete, proceed to next
     └── FAIL → enter review-fix loop
  8. If blocked after 3 iterations → escalate
```

### Step 5: Ready Task Identification

A task is ready when:
- `status: pending` OR `status: failed` (retry)
- All tasks in `dependencies` array have `status: completed`

```yaml
# Example: TASK-006 is ready if TASK-005 is completed
- id: TASK-006
  status: pending
  dependencies: [TASK-005]   # Check: TASK-005.status == completed
```

Skip tasks with `status: blocked` — include in escalation report.

### Step 6: Parallel Task Execution

For each ready task, spawn **in parallel**:

**implementation_agent:**
```yaml
ticket: {ticket}
phase_id: {phase_id}
task_file: .specwright/{ticket}/phases/tasks/TASK-XXX.yaml  # absolute path
symbols: [max 10 relevant symbols from index]
```

**test_agent:**
```yaml
ticket: {ticket}
phase_id: {phase_id}
task_file: .specwright/{ticket}/phases/tasks/TASK-XXX.yaml  # same path
symbols: [same symbols]
```

Both agents read the same task file. Implementation writes code, test writes tests.

### Step 7: Collect Agent Responses

Wait for **ALL** spawned agents to return. Each agent returns a concise response and writes its own audit file:

```yaml
# implementation_agent response (concise)
status: completed
audit: .specwright/{ticket}/audits/phase-{n}/TASK-006_implementation.yaml
issues: 0

# test_agent response (concise)
status: completed
audit: .specwright/{ticket}/audits/phase-{n}/TASK-006_test.yaml
issues: 0
```

Agents write detailed audits to their audit files. Orchestrator only receives status.

**CRITICAL:** Do NOT spawn verification_agent until ALL implementation_agent and test_agent calls for this phase have returned.

### Step 8: Update Task Statuses

**Spawn status_agent:**
```yaml
ticket: {ticket}
audit_path: .specwright/{ticket}/audits/phase-{n}/
manifest_path: .specwright/{ticket}/manifest.yaml
phase_file: .specwright/{ticket}/phases/phase-{N}-tasks.yaml
action: update_tasks
```

status_agent reads audit files from `audit_path` directory.

**Status combination logic (handled by status_agent):**

| Implementation | Test | Task Status |
|----------------|------|-------------|
| completed | completed | **completed** |
| completed | failed | **failed** |
| failed | completed | **failed** |
| failed | failed | **failed** |
| blocked | any | **blocked** |
| any | blocked | **blocked** |

### Step 9: Verification

**Spawn verification_agent:**
```yaml
ticket: {ticket}
phase_id: {phase_id}
phase_path: .specwright/{ticket}/phases/phase-{N}-tasks.yaml
project_root: {absolute_path}
```

Verification runs sequentially: lint → type check → tests

### Step 10: Verification Result Handling

**If PASS:**
```
Spawn status_agent:
  ticket: {ticket}
  manifest_path: .specwright/{ticket}/manifest.yaml
  phase_file: .specwright/{ticket}/phases/phase-{N}-tasks.yaml
  action: mark_phase_complete

Proceed to Phase N+1
```

**If FAIL → Enter Review-Fix Loop:**

### Step 11: Review-Fix Loop

```
fix_iteration = 1

WHILE fix_iteration <= 3 AND verification.status == failed:

  # Step A: Analyze failures
  Spawn review_agent:
    ticket: {ticket}
    phase_id: {phase_id}
    iteration: {fix_iteration}
    audit_path: .specwright/{ticket}/audits/phase-{n}/
    task_files: [affected task file paths]   # absolute paths

  # review_agent writes: .specwright/{ticket}/audits/phase-{n}/review.yaml

  # Step B: Apply fixes
  Spawn fix_agent:
    ticket: {ticket}
    phase_id: {phase_id}
    iteration: {fix_iteration}
    review_file: .specwright/{ticket}/audits/phase-{n}/review.yaml
    task_files: [affected task file paths]   # absolute paths

  # fix_agent writes: .specwright/{ticket}/audits/phase-{n}/fix_iteration_{n}.yaml

  # Step C: Re-verify
  Spawn verification_agent (same params as Step 9)

  fix_iteration += 1

IF verification.status == passed:
  Continue to Step 10 (PASS branch)
ELSE:
  Escalate (Step 12)
```

**Iteration tracking:**
- `iteration` parameter passed to review_agent and fix_agent
- Iteration 1: Aggressive fixes
- Iteration 2: More conservative
- Iteration 3: Only confident fixes, escalate uncertainty

### Step 12: Escalation

When verification fails after 3 fix iterations:

**1. Write blocked.md:**
```markdown
# Phase {N} Blocked

**Ticket**: {ticket}
**Phase**: {N} - {phase_name}
**Blocked since**: {timestamp}
**Fix attempts**: 3/3

## Iteration History

### Iteration 1
**Review summary**: {review_agent.analysis_summary}
**Issues found**: {count}
**Fixes applied**: {count}
**Result**: Verification failed

### Iteration 2
**Review summary**: {review_agent.analysis_summary}
**Issues found**: {count}
**Fixes applied**: {count}
**Result**: Verification failed

### Iteration 3
**Review summary**: {review_agent.analysis_summary}
**Issues found**: {count}
**Fixes applied/skipped**: {applied}/{skipped}
**Result**: Verification failed

## Remaining Failures

{verification.failures formatted}

## Escalated Issues

{review_agent.escalations if any}

## Required Actions

- [ ] {specific action from review_agent}
- [ ] {specific action from review_agent}

## How to Resume

After resolving issues:
```
/resume {ticket}
```
```

**2. Update manifest:**
```yaml
status: blocked
current_phase: {N}
blocked_since: {timestamp}
```

**3. Report to user:**
```
Phase {N} ({phase_name}) blocked after 3 fix attempts.

Remaining issues: {count}
See: .specwright/{ticket}/blocked.md

After resolving issues, run: /resume {ticket}
```

### Step 13: Workflow Completion

When all phases complete:

**1. Update manifest:**
```yaml
status: completed
completed: {timestamp}
```

**2. Report:**
```
Build complete for {ticket}

Summary:
- Phases: {N}/{N} completed
- Tasks: {total}/{total} completed
- Duration: {time}

All implementation and tests passing.
```

---

## Task Status Handling on Resume

When resuming mid-phase (status: `in_progress`):

| Task Status | Action |
|-------------|--------|
| `completed` | Skip |
| `pending` | Execute if dependencies met |
| `in_progress` | Reset to `pending` (partial work discarded) |
| `failed` | Queue for fix_agent |
| `blocked` | Skip, include in escalation report |

---

## Error Handling

| Condition | Action |
|-----------|--------|
| No manifest | Error: "No plan found. Run `/design {ticket}`." |
| Indexing fails | Error: "Codebase indexing failed. Fix and retry." |
| Agent spawn fails | Retry once, then mark task failed |
| Circular dependency | Error: "Circular dependency detected" (should be caught in /design) |
| User interrupts | Save current state, can resume with `/build` or `/resume` |
| All tasks in phase blocked | Mark phase blocked, escalate |

---

## Example Session

```
User: /build FEAT-jwt-auth

Orchestrator:
Starting build for FEAT-jwt-auth
Status: planned → in_progress

Refreshing codebase index...
Index: 156 symbols from 57 files

Phase 1/8: Core Models

Spawning agents for ready tasks...
- implementation_agent(TASK-001) ✓
- test_agent(TASK-001) ✓
- implementation_agent(TASK-002) ✓
- test_agent(TASK-002) ✓

Updating task statuses...
- TASK-001: completed
- TASK-002: completed

Running verification...
✓ Lint passed
✓ Type check passed
✓ Tests passed (12/12)

Phase 1 complete.

Phase 2/8: Repository Interfaces
[... continues ...]

---

Phase 5/8: API Handlers

Spawning agents...
[agents complete]

Running verification...
✗ Tests failed (18/20)

Starting fix iteration 1/3...
- Review: 2 issues found (1 impl bug, 1 test bug)
- Fix: Applied 2 fixes
- Verify: ✓ All tests passed

Phase 5 complete.
[... continues to completion ...]

Build complete for FEAT-jwt-auth
- Phases: 8/8
- Tasks: 24/24
- Duration: 45 minutes
```

---

## Critical Reminders

1. **Wait for ALL agents** — Do NOT spawn verification until all impl+test agents return
2. **Parallel impl+test** — Both agents get same task file
3. **Concise responses** — Agents write audit files, return only status to orchestrator
4. **Audit paths** — Pass audit_path directory, agents read/write their own files
5. **Max 3 fix iterations** — Then escalate to user
6. **Track iteration number** — Pass to review/fix agents
7. **Write blocked.md** — User needs detailed failure info
8. **Absolute paths** — All file paths passed to agents are absolute
9. **Shared index** — Index at `.specwright/index/`, not per-ticket
10. **Status transitions** — planned → in_progress → completed/blocked
