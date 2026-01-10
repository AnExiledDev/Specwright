---
description: Check progress status for a ticket (read-only)
argument-hint: [ticket]
allowed-tools: Read, Glob
---

# /status Command

Read-only progress check.

## Syntax

```
/status <ticket>
/status              # List all tickets
```

## Prerequisites

None. Works at any stage, including when ticket doesn't exist.

---

## File Locations Reference

```
.specwright/
├── {ticket-1}/
│   ├── spec.md
│   ├── manifest.yaml
│   ├── blocked.md           # Read if exists
│   └── phases/
│       └── phase-{N}-tasks.yaml
├── {ticket-2}/
│   └── ...
```

---

## Behavior

Read ticket state and report. **Do NOT spawn work agents.**

### Step 1: Check Ticket Exists

```
IF .specwright/{ticket}/ not found:
  Report: "Ticket '{ticket}' not found."
  List available tickets (Step 6)
  EXIT
```

### Step 2: Read Available Files

```
spec_exists = file_exists(".specwright/{ticket}/spec.md")
manifest_exists = file_exists(".specwright/{ticket}/manifest.yaml")

IF manifest_exists:
  Read .specwright/{ticket}/manifest.yaml
  Extract: status, current_phase, phases[], timestamps

blocked_exists = file_exists(".specwright/{ticket}/blocked.md")

IF blocked_exists:
  Read .specwright/{ticket}/blocked.md
  Extract: blocked_since, remaining failures summary
```

### Step 3: Determine Stage

| Files Present | Manifest Status | Stage |
|---------------|-----------------|-------|
| Only folder | - | Created (abandoned /define?) |
| spec.md only | - | Defined (pre-manifest) |
| spec.md + manifest | `defining` | Defining (incomplete) |
| spec.md + manifest | `defined` | Defined (ready for /design) |
| spec.md + manifest | `planned` | Planned (ready for /build) |
| spec.md + manifest | `in_progress` | Building |
| spec.md + manifest | `blocked` | Blocked |
| spec.md + manifest | `completed` | Complete |

### Step 4: Read Phase Details (if building/blocked)

If status is `in_progress` or `blocked`:

```
Read .specwright/{ticket}/phases/phase-{current_phase}-tasks.yaml
Extract task statuses for current phase

Count across all phases:
- completed_tasks
- pending_tasks
- in_progress_tasks
- failed_tasks
- blocked_tasks
```

### Step 5: Report by Stage

#### Created (folder only)
```
Ticket: {ticket}
Status: Created (incomplete)

The ticket folder exists but has no specification.
This may be from an abandoned /define command.

Options:
- Complete definition: /define {description}
- Remove folder: rm -rf .specwright/{ticket}
```

#### Defining
```
Ticket: {ticket}
Status: Defining (incomplete specification)

Specification started but not completed.

Next: Complete the /define process or start fresh.
```

#### Defined
```
Ticket: {ticket}
Status: Specification complete
Created: {date}

Spec: .specwright/{ticket}/spec.md

Next: Run `/design {ticket}` to generate implementation plan
```

#### Planned
```
Ticket: {ticket}
Status: Plan ready
Created: {date}
Planned: {date}

Phases: {count}
Tasks: {count} total

Phase breakdown:
  1. {name} ({task_count} tasks)
  2. {name} ({task_count} tasks)
  ...

Next: Run `/build {ticket}` to start implementation
```

#### Building (in_progress)
```
Ticket: {ticket}
Status: In progress
Started: {date}

Progress:
  Phase 1 ({name}): ✓ Complete
  Phase 2 ({name}): ✓ Complete
  Phase 3 ({name}): In progress
    - TASK-008: ✓ completed
    - TASK-009: ✓ completed
    - TASK-010: ● in_progress
    - TASK-011: ○ pending
  Phase 4-8: ○ Pending

Overall: {completed}/{total} tasks ({percentage}%)

Next: Run `/resume {ticket}` to continue
```

#### Blocked
```
Ticket: {ticket}
Status: BLOCKED at Phase {N} ({name})
Blocked since: {date}

Issues (from blocked.md):
  {summary of remaining failures}

Fix attempts: 3/3 exhausted

Required actions:
  - [ ] {action from blocked.md}
  - [ ] {action from blocked.md}

Details: .specwright/{ticket}/blocked.md

Next: Resolve issues, then `/resume {ticket}`
```

#### Complete
```
Ticket: {ticket}
Status: Complete
Started: {start_date}
Completed: {end_date}
Duration: {time}

Summary:
  Phases: {count}/{count}
  Tasks: {count}/{count}

All implementation and tests passing.
```

### Step 6: List All Tickets (no ticket specified)

```
/status

Active tickets in .specwright/:

  FEAT-jwt-auth      in_progress  Phase 3/8 (42%)
  BUG-login-timeout  completed    Done
  FEAT-user-profile  planned      Ready to build
  ENH-cache-layer    blocked      Phase 5 - needs resolution

Total: 4 tickets (1 building, 1 blocked, 1 ready, 1 complete)
```

**List format:**
```
{ticket}  {status}  {brief_detail}
```

---

## Status Symbols

| Symbol | Meaning |
|--------|---------|
| ✓ | Completed |
| ● | In progress |
| ○ | Pending |
| ✗ | Failed |
| ⊘ | Blocked |

---

## Progress Calculation

```
completed_tasks = count tasks where status == "completed"
total_tasks = count all tasks across all phases

percentage = (completed_tasks / total_tasks) * 100
```

**Include all phases**, not just current phase.

---

## Blocked.md Integration

When status is `blocked`:

1. **Read blocked.md** — Extract summary info
2. **Show in report** — Key issues and required actions
3. **Point to file** — For full details

Do NOT repeat entire blocked.md content — summarize.

**Summary extraction from blocked.md:**
- Remaining failures section (first 3 items)
- Required actions section (all items)

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Ticket not found | List available tickets with hint |
| .specwright/ doesn't exist | "No specwright tickets found. Use `/define` to create one." |
| Manifest corrupted | "Manifest unreadable. File may be corrupted: {path}" |
| Phase file missing | "Phase {N} file missing. Plan may be incomplete." |
| blocked.md missing when blocked | Report blocked status, note missing details file |

---

## Example Sessions

**Full status check:**
```
User: /status FEAT-jwt-auth

Orchestrator:
Ticket: FEAT-jwt-auth
Status: In progress
Started: 2025-01-09 14:00

Progress:
  Phase 1 (Core Models): ✓ Complete
  Phase 2 (Repositories): ✓ Complete
  Phase 3 (Services): In progress
    - TASK-008: ✓ completed
    - TASK-009: ✓ completed
    - TASK-010: ● in_progress
    - TASK-011: ○ pending
  Phase 4-8: ○ Pending

Overall: 10/24 tasks (42%)

Next: Run `/resume FEAT-jwt-auth` to continue
```

**Blocked status:**
```
User: /status FEAT-jwt-auth

Orchestrator:
Ticket: FEAT-jwt-auth
Status: BLOCKED at Phase 5 (API Handlers)
Blocked since: 2025-01-09 16:30

Issues:
  - TestAuthMiddleware_ExpiredToken: Expected 401, got 500
  - TestAuthMiddleware_InvalidToken: Assertion failed

Fix attempts: 3/3 exhausted

Required actions:
  - [ ] Review token expiration handling in middleware
  - [ ] Check error response formatting

Details: .specwright/FEAT-jwt-auth/blocked.md

Next: Resolve issues, then `/resume FEAT-jwt-auth`
```

**List all tickets:**
```
User: /status

Orchestrator:
Active tickets in .specwright/:

  FEAT-jwt-auth      in_progress  Phase 3/8 (42%)
  BUG-login-timeout  completed    Done
  FEAT-user-profile  planned      Ready to build

Total: 3 tickets

To check specific ticket: /status <ticket>
```

**Ticket not found:**
```
User: /status FEAT-nonexistent

Orchestrator:
Ticket 'FEAT-nonexistent' not found.

Available tickets:
  - FEAT-jwt-auth (in_progress)
  - BUG-login-timeout (completed)
  - FEAT-user-profile (planned)

To create new ticket: /define <description>
```

---

## Critical Reminders

1. **Read-only** — Never spawn work agents
2. **Check all states** — Handle every manifest status value
3. **Read blocked.md** — When blocked, include issue summary
4. **Calculate progress** — Across all phases, not just current
5. **Show next action** — Tell user what command to run
6. **Handle missing files** — Graceful degradation with helpful messages
7. **List tickets** — Support no-argument invocation
8. **Symbols** — Consistent visual indicators
9. **Summarize, don't dump** — Extract key info from blocked.md
10. **Always show path** — User should know where files are
