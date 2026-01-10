---
description: Revise an existing ticket specification
argument-hint: <ticket>
allowed-tools: Read, Write, Glob, Edit
---

# /revise Command

Revises an existing specification.

## Syntax

```
/revise <ticket>
```

## Prerequisites

- `.specwright/{ticket}/spec.md` exists

**Error if missing:** "No specification found. Use `/define {ticket}` to create one."

---

## File Locations Reference

```
.specwright/{ticket}/
├── spec.md           # Read and update
├── manifest.yaml     # Check for plan existence
└── phases/           # Check for worked tasks (if plan exists)
```

---

## Behavior

### Step 1: Load Existing Spec

```
Read .specwright/{ticket}/spec.md
Parse sections:
  - Summary
  - Requirements (functional, non-functional)
  - Acceptance Criteria
  - Constraints
  - Out of Scope
  - Open Questions
  - Assumptions
  - Dependencies
```

### Step 2: Check Build State

**Before showing spec, check if work has started:**

```
IF .specwright/{ticket}/manifest.yaml exists:
  Read manifest
  IF manifest.status IN [in_progress, blocked, completed]:
    WARN user (see Build State Warning)
  ELSE IF manifest.status == "planned":
    NOTE: Plan exists, changes will require /design --amend
```

**Build state warning:**
```
WARNING: Build is {status} for this ticket.

Current progress:
- Phase: {current_phase}/{total_phases}
- Completed tasks: {count}

Revising the specification will NOT affect in-progress work.
To apply changes, you must:
1. Complete current work
2. Create new ticket with revised requirements

Continue with revision? (changes won't affect current build)
```

### Step 3: Present Current State

```
Current specification for {ticket}:

Summary: {first sentence}

Requirements: {func_count} functional, {nfr_count} non-functional
Acceptance Criteria: {count}
Constraints: {count}
Open Questions: {count}

Sections:
1. Requirements
2. Acceptance Criteria
3. Constraints
4. Out of Scope
5. Assumptions

What would you like to revise?
- Specific section (e.g., "update REQ-003")
- Add new requirements
- Remove requirements
- General changes
```

### Step 4: Gather Revisions

Accept user input describing changes:

**Supported revision types:**
- Modify specific requirement: "Change REQ-003 to require 2FA"
- Add new requirement: "Add requirement for audit logging"
- Remove requirement: "Remove REQ-005"
- Modify acceptance criteria: "Update criterion 2 to include edge case"
- Add constraint: "Add performance constraint for API response time"
- Clarify scope: "Add X to out of scope"

### Step 5: Clarifying Questions (if needed)

If revision introduces ambiguity:
- Ask focused questions (same format as /define)
- Max 3 rounds for revisions
- Options with recommendations

**Question triggers:**
- New requirement lacks detail
- Conflict with existing requirement
- Scope unclear
- Implementation impact unclear

### Step 6: Two-Step Revision

**MANDATORY: Think before writing.**

**Step 1 — Reasoning (write out internally):**
```
Before updating the specification:

1. What exactly is changing?
   - [list specific changes]

2. Does this conflict with unchanged requirements?
   - [check for contradictions]

3. Cascading effects?
   - [other sections that need updating]

4. Do acceptance criteria need updating?
   - [verify criteria still match requirements]

5. Impact on existing plan (if any)?
   - [which tasks would be affected]
```

**Step 2 — Prepare changes:**

Prepare diff without applying yet.

### Step 7: Show Diff

Present changes clearly before applying:

```
Changes to spec.md:

MODIFIED:
  - REQ-003: WHEN user logs in, system SHALL validate credentials
    → REQ-003: WHEN user logs in, system SHALL validate credentials AND require 2FA

ADDED:
  - REQ-012: The system SHALL log all authentication events to audit trail
  - AC-007: Audit log contains timestamp, user ID, action, and result

DEPRECATED:
  - REQ-005: System SHALL allow password hints
    (Reason: Security concern - hints weaken password security)

UNCHANGED:
  - REQ-001, REQ-002, REQ-004, REQ-006 through REQ-011
  - AC-001 through AC-006
  - All constraints
  - All assumptions

Proceed with these changes?
```

### Step 8: Apply Changes

On user confirmation:

**Update spec.md with these rules:**
- Preserve unchanged sections exactly
- Update modified items with change markers
- Add new items with new IDs (continue numbering)
- Mark removed items as deprecated (don't delete)
- Update revision timestamp

**Deprecation format:**
```markdown
- ~~REQ-005: System SHALL allow password hints~~ *(deprecated: security concern)*
```

**Modified format:**
```markdown
- REQ-003: WHEN user logs in, system SHALL validate credentials AND require 2FA *(modified: added 2FA requirement)*
```

### Step 9: Report Impact

**If no plan exists:**
```
Specification updated.

Changes:
- Modified: 1 requirement
- Added: 1 requirement, 1 acceptance criterion
- Deprecated: 1 requirement

File: .specwright/{ticket}/spec.md

Next: Run `/design {ticket}` when ready to plan implementation
```

**If plan exists (status: planned, all tasks pending):**
```
Specification updated.

Changes:
- Modified: REQ-003 (2FA requirement)
- Added: REQ-012 (audit logging)
- Deprecated: REQ-005 (password hints)

WARNING: Existing plan may be affected.

Potentially impacted tasks:
- TASK-005: Login handler (REQ-003)
- TASK-008: User service (REQ-003)
- New tasks needed for REQ-012

Options:
1. Run `/design --amend {ticket}` to update plan incrementally
2. Run `/design {ticket}` to regenerate plan completely
3. Leave plan as-is (not recommended)
```

**If build in progress:**
```
Specification updated for future reference.

WARNING: Build is currently in progress.
Changes will NOT affect the current build.

To apply these changes:
1. Complete or cancel current build
2. Run `/design --amend {ticket}` or `/design {ticket}`
3. Start new build with `/build {ticket}`

Current build status:
- Phase: 3/8
- Completed: 10 tasks
```

---

## Preserving History

Revisions preserve history through deprecation and modification markers:

```markdown
## Requirements

### Functional

- REQ-001: System SHALL authenticate users via JWT
- ~~REQ-002: System SHALL store sessions in Redis~~ *(deprecated: replaced by REQ-012)*
- REQ-003: WHEN token expires, system SHALL return 401 *(modified: updated error code)*
- REQ-012: System SHALL use stateless JWT (no session storage) *(added: 2025-01-09)*
```

**Benefits:**
- Traceability of changes
- Understanding of design evolution
- Audit trail for decisions

---

## Conflict Detection

When revising, check for conflicts:

```
Potential conflict detected:

  Existing: REQ-001: "System SHALL require email verification before login"
  New:      REQ-013: "System SHALL allow immediate login after registration"

These requirements conflict. Options:
  (a) Email verification is optional, not required
  (b) Email verification required, blocks login until complete
  (c) Other (explain your preference)

Select an option to resolve:
```

**Never proceed with unresolved conflicts.**

---

## Error Handling

| Condition | Action |
|-----------|--------|
| No spec found | Error: "No specification found. Use `/define {ticket}` to create one." |
| Spec file corrupted | Error: "Specification file corrupted or unreadable. Check: {path}" |
| Build in progress | Warning (not error) — changes won't affect current build |
| Conflicting requirements | Block until user resolves |
| Invalid requirement ID | "REQ-{N} not found. Current requirements: REQ-001 through REQ-{max}" |
| Empty revision | "No changes specified. What would you like to revise?" |

---

## Example Session

```
User: /revise FEAT-jwt-auth

Orchestrator:
Loading specification for FEAT-jwt-auth...

Current specification:

Summary: Add JWT authentication to the API

Requirements: 8 functional, 3 non-functional
Acceptance Criteria: 6
Constraints: 2
Open Questions: 0

Plan exists: Yes (8 phases, 24 tasks)
Build status: Not started

What would you like to revise?

User: Add requirement for audit logging of all auth events

Orchestrator:
Adding audit logging requirement.

Questions:

1. What events should be logged?
   - (a) All auth events (login, logout, token refresh, failures) (Recommended - comprehensive)
   - (b) Only failures and security events
   - (c) Custom selection

2. Where should audit logs be stored?
   - (a) Database table (Recommended - queryable)
   - (b) External logging service
   - (c) File system

User: 1a, 2a

Orchestrator:
Changes to spec.md:

ADDED:
  - REQ-012: The system SHALL log all authentication events (login, logout,
    token refresh, failures) to an audit_logs database table
  - REQ-013: Each audit log entry SHALL include: timestamp, user_id, event_type,
    ip_address, user_agent, and result (success/failure)
  - AC-007: Audit logs are queryable by user_id and date range

UNCHANGED:
  - REQ-001 through REQ-011
  - AC-001 through AC-006
  - All constraints and assumptions

Proceed with these changes?

User: Yes

Orchestrator:
Specification updated.

Changes:
- Added: 2 requirements, 1 acceptance criterion

WARNING: Existing plan needs updating.

New requirements will need new tasks:
- Database migration for audit_logs table
- Audit logging service/middleware
- Audit log query endpoints (if API exposure needed)

Options:
1. Run `/design --amend FEAT-jwt-auth` to add new tasks
2. Run `/design FEAT-jwt-auth` to regenerate entire plan
3. Leave plan as-is (not recommended)
```

---

## Critical Reminders

1. **Check build state first** — Warn if work in progress
2. **Show diff before applying** — User must approve changes
3. **Deprecate, don't delete** — Maintain history
4. **Detect conflicts** — Don't allow contradictory requirements
5. **Report plan impact** — If plan exists, show affected tasks
6. **Two-step generation** — Reason through changes before applying
7. **Continue numbering** — New REQ-{N} uses next available number
8. **Mark modifications** — Add *(modified: reason)* marker
9. **Clarifying questions** — If revision is ambiguous
10. **Point to next action** — Tell user about /design --amend
