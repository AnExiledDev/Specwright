---
name: specwright-error-handling
description: |
  Error handling patterns for implementing failure modes, exception hierarchies, and recovery logic.

  INVOKE WHEN: implementation_agent writes code that handles failures, validates input, communicates with external services, or needs structured error responses. Also useful when fix_agent addresses error-handling-related failures.

  PROVIDES: Error categories (expected vs unexpected vs panic), design patterns (typed errors, error context, hierarchy), boundary handling, logging guidelines (structured logging, context preservation), retry patterns, user-facing error message standards.

  LANGUAGE REFERENCES: Load references/python.md for Python (exception hierarchy, context managers, async error handling, FastAPI/Flask handlers, tenacity retry). Load references/typescript.md for TypeScript (custom error classes, Result type, Express middleware, Zod validation).

  USE CASE: Implementing robust error handling that matches codebase patterns. Ensuring errors are caught at appropriate boundaries with proper context.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Error Handling Patterns

Standards for error handling across all languages. Apply when implementing code that deals with failure modes.

## Universal Principles

### Error Handling Philosophy

1. **Fail fast**: Detect invalid state early, before side effects
2. **Fail loudly**: Errors should be visible, not silently swallowed
3. **Fail gracefully**: Users get helpful messages, systems recover when possible
4. **Handle at the right level**: Not too early (lose context), not too late (state corrupted)

---

## Error Categories

### 1. Expected Errors (Handle)
Normal failure modes that are part of the API contract:
- User not found
- Invalid input
- Permission denied
- Resource conflict (duplicate)

**Response:** Return typed error, let caller decide action.

### 2. Unexpected Errors (Log & Propagate)
Programming errors or system failures:
- Null pointer on non-null value
- Database connection failure
- Out of memory

**Response:** Log with context, propagate up, show generic message to user.

### 3. Panic Conditions (Abort)
Unrecoverable states:
- Invariant violations
- Configuration errors at startup
- Corrupted data structures

**Response:** Abort operation (or program at startup), alert operations team.

---

## Error Design Patterns

### Typed Errors

Define specific error types for each failure mode:

```
# Good: Specific error types
UserNotFoundError
DuplicateEmailError
InvalidCredentialsError

# Bad: Generic errors with strings
Error("user not found")
Exception("Something went wrong")
```

### Error Context

Include enough context to diagnose without reading code:

```
# Good
"Failed to create user: email 'test@example.com' already exists (user_id: abc123)"

# Bad
"Duplicate key error"
"Creation failed"
```

### Error Hierarchy

Organize errors by domain:

```
RepositoryError
├── NotFoundError
├── DuplicateError
└── ConnectionError

ValidationError
├── RequiredFieldError
├── InvalidFormatError
└── OutOfRangeError
```

---

## Boundary Handling

### Where to Handle Errors

| Boundary | Handle | Action |
|----------|--------|--------|
| **API entry** | All | Return appropriate HTTP status |
| **Service layer** | Business errors | Transform or propagate |
| **Repository layer** | Data errors | Wrap in domain errors |
| **External calls** | Network/timeout | Retry, circuit break, or fail |

### Transformation Rules

- **Repository → Service**: `SQLIntegrityError` → `DuplicateEmailError`
- **Service → API**: `UserNotFoundError` → 404 response
- **External → Internal**: `HTTPError` → `ServiceUnavailableError`

---

## Logging Guidelines

### What to Log

| Log Level | When | What |
|-----------|------|------|
| **ERROR** | Unexpected failures | Stack trace, request context |
| **WARN** | Recoverable issues | What happened, what was done |
| **INFO** | Significant events | User actions, state changes |
| **DEBUG** | Troubleshooting | Internal state, decision points |

### Error Log Format

```
ERROR [2025-01-15T10:30:00Z] Failed to create user
  error: DuplicateEmailError
  email: test@example.com
  request_id: abc123
  user_id: null
  stack: <stack trace>
```

### What NOT to Log

- Passwords, tokens, secrets
- Full credit card numbers
- Personal health information
- Stack traces for expected errors

---

## Retry Patterns

### When to Retry

✅ Transient failures (network timeout, rate limit)
✅ Idempotent operations (read, idempotent write)
❌ Validation errors (won't change on retry)
❌ Authentication failures (won't change on retry)
❌ Non-idempotent operations (may cause duplicates)

### Retry Strategy

```
attempt 1: immediate
attempt 2: wait 100ms
attempt 3: wait 200ms
attempt 4: wait 400ms (exponential backoff)
...
max attempts: 3-5
max delay: 30s
add jitter: ±10% to prevent thundering herd
```

---

## Circuit Breaker Pattern

For external service calls:

```
CLOSED: Normal operation
  ↓ failures > threshold
OPEN: Fail immediately (don't call service)
  ↓ timeout expires
HALF-OPEN: Allow one request to test
  ↓ success → CLOSED
  ↓ failure → OPEN
```

Protects against cascading failures when downstream service is unhealthy.

---

## User-Facing Errors

### Error Response Format

```json
{
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "An account with this email already exists",
    "field": "email",
    "request_id": "abc123"
  }
}
```

### Error Message Guidelines

- **Be specific**: "Email format invalid" not "Validation error"
- **Be helpful**: "Use format user@domain.com" not just "Invalid"
- **Be consistent**: Same error type = same message format
- **No internals**: Never expose stack traces, SQL, or paths

### HTTP Status Code Mapping

| Error Type | Status | When |
|------------|--------|------|
| ValidationError | 400 | Invalid input |
| AuthenticationError | 401 | Not logged in |
| AuthorizationError | 403 | Logged in, no permission |
| NotFoundError | 404 | Resource doesn't exist |
| ConflictError | 409 | Duplicate, version conflict |
| RateLimitError | 429 | Too many requests |
| InternalError | 500 | Unexpected failure |
| ServiceUnavailable | 503 | Downstream failure |

---

## Anti-Patterns

### Silent Failure

```
# BAD: Error swallowed
try:
    do_something()
except:
    pass

# GOOD: At minimum, log
try:
    do_something()
except Exception as e:
    logger.error(f"do_something failed: {e}")
    raise
```

### Over-Catching

```
# BAD: Catches everything, including bugs
try:
    user = get_user(id)
    send_email(user.email)
except Exception:
    return "Something went wrong"

# GOOD: Catch specific errors
try:
    user = get_user(id)
except UserNotFoundError:
    return "User not found"

try:
    send_email(user.email)
except EmailDeliveryError as e:
    logger.warning(f"Email failed: {e}")
    # Continue - email is not critical
```

### Error Message as Control Flow

```
# BAD: Parsing error messages
try:
    create_user(email)
except Exception as e:
    if "duplicate" in str(e):
        return "Email exists"

# GOOD: Typed errors
try:
    create_user(email)
except DuplicateEmailError:
    return "Email exists"
```

### Naked Re-Raise

```
# BAD: Loses context
try:
    external_api.call()
except APIError:
    raise

# GOOD: Add context
try:
    external_api.call()
except APIError as e:
    raise ServiceError(f"External API failed: {e}") from e
```

---

## Language-Specific Patterns

Detect project type and apply appropriate patterns:

- **Python** (`pyproject.toml`, `setup.py`): See [python.md](references/python.md)
- **TypeScript** (`package.json` + `tsconfig.json`): See [typescript.md](references/typescript.md)

---

## Error Handling Checklist

When implementing error handling:

- [ ] Specific error types for each failure mode
- [ ] Errors include context (what failed, with what inputs)
- [ ] Errors handled at appropriate boundary
- [ ] User-facing messages are helpful, not technical
- [ ] Unexpected errors logged with stack trace
- [ ] Expected errors not logged as errors (info/debug)
- [ ] External calls have timeout and retry logic
- [ ] No silent failures (swallowed exceptions)
