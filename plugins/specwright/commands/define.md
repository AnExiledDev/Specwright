---
description: Create a new ticket with specification from description
argument-hint: <description>
allowed-tools: Read, Write, Glob, Edit
---

# /define Command

Creates a new ticket with specification from user description.

## Syntax

```
/define <description>
```

## Output Location

All files created in:
```
.specwright/{ticket}/
├── spec.md           # Specification document
└── manifest.yaml     # Workflow state (initial)
```

---

## Workflow

### Step 1: Parse Description and Detect Type

**Type detection algorithm:**

| Keyword Pattern | Type | Prefix |
|-----------------|------|--------|
| "add", "create", "implement", "build", "new" | Feature | `FEAT-` |
| "fix", "bug", "broken", "error", "crash" | Bug | `BUG-` |
| "improve", "enhance", "better", "optimize" | Enhancement | `ENH-` |
| "refactor", "restructure", "clean", "reorganize" | Refactor | `REFACTOR-` |
| "investigate", "research", "explore", "understand" | Research | `RESEARCH-` |
| "update", "upgrade", "maintain", "dependency" | Maintenance | `MAINT-` |

**Default:** `FEAT-` if no keywords match.

### Step 2: Generate Ticket ID

Extract key nouns from description, convert to kebab-case:

```
"Add JWT authentication to the API"
→ FEAT-jwt-authentication

"Fix login timeout causing session loss"
→ BUG-login-timeout-session-loss

"Improve database query performance"
→ ENH-database-query-performance
```

**Present to user:**
```
Ticket ID: `FEAT-jwt-authentication`
Proceed with this ID? (or provide alternative)
```

Wait for user confirmation or alternative.

### Step 3: Create Folder Structure

After ticket ID confirmed:

```bash
mkdir -p .specwright/{ticket}
```

Create initial `manifest.yaml`:
```yaml
ticket: {ticket}
status: defining
current_phase: 0
phases: []
created: {timestamp}
```

**Status values for manifest:**
| Status | Meaning |
|--------|---------|
| `defining` | In /define, spec incomplete |
| `defined` | Spec complete, ready for /design |
| `planned` | Design complete, ready for /build |
| `in_progress` | Build running |
| `blocked` | Phase blocked, needs intervention |
| `completed` | All phases done |

### Step 4: Requirement Elicitation

**Gather requirements through structured questioning.**

**Question format:**
- Each question offers 2-4 options
- Mark one option "(Recommended)" with one-sentence justification
- User can select option or provide freeform answer

**Critical rule: Ask ONLY questions the user can answer.**
- ✓ Business intent, preferences, constraints, priorities
- ✓ Desired behavior, acceptance criteria, edge case handling preferences
- ✗ Existing code patterns (analyze the codebase yourself)
- ✗ File locations, API signatures, dependencies (use indexing_agent)
- ✗ Technical implementation details you can determine from context

**Question categories (cover as relevant):**

1. **Scope**:
   - What's included in this work?
   - What's explicitly excluded?
   - What's the minimal viable delivery?

2. **Behavior**:
   - What happens in the happy path?
   - What happens when things go wrong?
   - What user actions trigger what system responses?

3. **Constraints**:
   - Performance requirements?
   - Security requirements?
   - Compatibility requirements?

4. **Integration**:
   - What external systems are involved?
   - What data migrations needed?
   - What breaking changes are acceptable?

5. **Edge Cases**:
   - What happens with invalid input?
   - What happens under load?
   - What happens when dependencies fail?

**Stop asking when:**
- User signals completion ("that's enough", "proceed", "looks good")
- All relevant categories have been covered for this feature
- Answers are yielding no new requirement information
- You're asking questions you could answer yourself from code analysis

### Step 5: Two-Step Specification Generation

**MANDATORY: Think before writing.**

**Step 1 — Reasoning (write out internally):**
```
Before writing the specification:

1. Core requirements: What MUST the system do?
   - [list from answers]

2. Implicit requirements: What did the user assume but not state?
   - [inferences from context]

3. Assumptions I'm making:
   - [list assumptions]

4. Potential conflicts:
   - [any contradictions in requirements]

5. Open questions remaining:
   - [unresolved items]
```

**Step 2 — Write spec.md:**

```markdown
# {Ticket Title}

**Ticket**: {ticket}
**Type**: {type}
**Created**: {date}
**Status**: Draft

## Summary

[1-2 sentence overview of what this ticket delivers]

## Requirements

### Functional

- REQ-001: [Requirement in EARS format]
- REQ-002: [Requirement in EARS format]
- REQ-003: [Requirement in EARS format]

### Non-Functional

- REQ-NFR-001: [Performance/security/etc requirement]
- REQ-NFR-002: [Performance/security/etc requirement]

## Acceptance Criteria

- [ ] [Testable criterion that can be verified]
- [ ] [Testable criterion that can be verified]
- [ ] [Testable criterion that can be verified]

## Constraints

- [Technical constraint]
- [Business constraint]
- [Timeline constraint if any]

## Out of Scope

- [Explicitly excluded item]
- [Explicitly excluded item]

## Open Questions

- [Any unresolved items marked "decide later"]
- [Clarification needed from stakeholder]

## Assumptions

- [Assumption confirmed during questioning]
- [Assumption inferred from context]

## Dependencies

- [External system dependency]
- [Team/resource dependency]
```

### Step 6: Present and Confirm

Show draft specification to user:
```
Here's the draft specification for {ticket}:

[Summary section preview]

Requirements: {count} functional, {count} non-functional
Acceptance Criteria: {count}
Open Questions: {count}

Should I finalize this specification?
```

### Step 7: Save and Update Status

On user confirmation:

1. **Save spec.md** to `.specwright/{ticket}/spec.md`

2. **Update manifest.yaml:**
```yaml
ticket: {ticket}
status: defined        # ← changed from 'defining'
current_phase: 0
phases: []
created: {original_timestamp}
defined: {timestamp}   # ← added
```

3. **Report completion:**
```
Specification saved to .specwright/{ticket}/spec.md

Next steps:
- Review and edit spec.md if needed
- Run `/design {ticket}` to generate implementation plan
```

---

## EARS Format Reference

Requirements should use EARS (Easy Approach to Requirements Syntax):

| Pattern | Template | Example |
|---------|----------|---------|
| Ubiquitous | The system SHALL [action] | The system SHALL encrypt all passwords |
| Event-driven | WHEN [trigger], the system SHALL [action] | WHEN user submits login, the system SHALL validate credentials |
| State-driven | WHILE [state], the system SHALL [action] | WHILE session is active, the system SHALL refresh token |
| Optional | WHERE [feature enabled], the system SHALL [action] | WHERE 2FA is enabled, the system SHALL require verification code |
| Complex | IF [condition] THEN the system SHALL [action] | IF login fails 3 times THEN the system SHALL lock account |

---

## Error Handling

| Condition | Action |
|-----------|--------|
| Ticket folder exists | Ask: "Ticket `{ticket}` exists. Options: 1) Revise with `/revise {ticket}`, 2) Choose different name" |
| User abandons mid-question | Save partial spec as draft, keep status: `defining` |
| Conflicting requirements detected | Surface conflict explicitly, ask user to resolve before proceeding |
| Empty description | Error: "Please provide a description. Example: `/define Add user authentication`" |

---

## Example Session

```
User: /define Add JWT authentication to the API

Orchestrator:
Detected type: Feature
Suggested ticket ID: `FEAT-jwt-authentication`
Proceed with this ID? (or provide alternative)

User: Yes

Orchestrator:
Created .specwright/FEAT-jwt-authentication/

Let me gather requirements.

**Round 1: Scope**

1. Which endpoints need authentication?
   - (a) All endpoints (Recommended - consistent security model)
   - (b) Only write operations (GET public, POST/PUT/DELETE protected)
   - (c) Specific endpoints (list which ones)

2. Should the API support multiple authentication methods?
   - (a) JWT only (Recommended - simpler implementation)
   - (b) JWT + API keys
   - (c) JWT + OAuth providers

3. What's the minimal delivery?
   - (a) Login endpoint + token validation middleware
   - (b) Full auth flow including registration and password reset (Recommended - complete feature)
   - (c) Other (describe)

User: 1a, 2a, 3b

Orchestrator:
**Round 2: Behavior**

1. Token expiration strategy?
   - (a) Short-lived access (15min) + refresh tokens (Recommended - security best practice)
   - (b) Long-lived access tokens (24h)
   - (c) Session-based with sliding expiration

[... continues through rounds ...]

Orchestrator:
Here's the draft specification:

**FEAT-jwt-authentication**
Add complete JWT authentication to the API including registration,
login, token refresh, and password reset flows.

Requirements: 8 functional, 3 non-functional
Acceptance Criteria: 6
Open Questions: 1 (email provider for password reset)

Should I finalize this specification?

User: Yes

Orchestrator:
Specification saved to .specwright/FEAT-jwt-authentication/spec.md

Next steps:
- Review and edit spec.md if needed
- Run `/design FEAT-jwt-authentication` to generate implementation plan
```

---

## Critical Reminders

1. **Confirm ticket ID** — Never create folder without user confirmation
2. **Create manifest immediately** — Track status from the start
3. **Use EARS format** — Consistent, testable requirements
4. **Two-step generation** — Think through spec before writing
5. **Mark recommendations** — Guide user toward best practices
6. **Surface conflicts** — Don't hide contradictory requirements
7. **Track status transitions** — defining → defined
8. **Show next steps** — User should know what command to run next
