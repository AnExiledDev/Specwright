---
name: specwright-security-review
description: |
  Security vulnerability checklist for code handling user input, authentication, or sensitive data.

  INVOKE WHEN: Code involves user input handling, authentication/authorization, data storage/transmission, file operations, external APIs, or cryptography. Also invoke when review_agent or verification_agent encounters security-related failures.

  PROVIDES: Injection prevention (SQL, command, XSS, path traversal), authentication patterns, secrets management, input validation requirements, cryptography guidelines, API security standards.

  LANGUAGE REFERENCES: Load references/python.md for Python (Django/Flask/FastAPI security, bcrypt, safe queries). Load references/typescript.md for TypeScript (Express middleware, JWT handling, Zod validation, React XSS prevention).

  USE CASE: Security audits during review. Ensuring implementations don't introduce vulnerabilities. Classifying security-related test failures.
allowed-tools: Read, Grep, Glob
---

# Security Review Standards

Security checklist for code review. Apply when reviewing code that handles user input, authentication, data storage, or external communication.

## Security Review Triggers

Apply this review when code involves:

- User input handling
- Authentication/authorization
- Data storage or transmission
- File system operations
- External API calls
- Cryptography or secrets
- Session management
- Error messages/logging

---

## Critical Vulnerabilities Checklist

### 1. Injection Attacks

**SQL Injection**
- [ ] Parameterized queries used (not string concatenation)
- [ ] ORM queries use parameter binding
- [ ] Dynamic table/column names validated against allowlist

**Command Injection**
- [ ] User input never passed directly to shell
- [ ] If shell required, use allowlist validation
- [ ] Subprocess calls use array form, not shell=True

**XSS (Cross-Site Scripting)**
- [ ] User content escaped before rendering
- [ ] HTML sanitization for rich content
- [ ] CSP headers configured

**Path Traversal**
- [ ] User input not used directly in file paths
- [ ] Paths normalized and validated within allowed directory
- [ ] Symlinks resolved before access check

---

### 2. Authentication & Authorization

**Authentication**
- [ ] Passwords hashed with bcrypt/argon2/scrypt (not MD5/SHA1)
- [ ] Timing-safe comparison for secrets
- [ ] Rate limiting on login attempts
- [ ] Account lockout after failures
- [ ] Secure session token generation (CSPRNG)

**Authorization**
- [ ] Every endpoint checks authorization
- [ ] Authorization at data layer, not just UI
- [ ] No privilege escalation paths
- [ ] Default deny, explicit allow

**Session Management**
- [ ] Sessions invalidated on logout
- [ ] Session timeout implemented
- [ ] Session tokens regenerated after privilege change
- [ ] Secure cookie flags (HttpOnly, Secure, SameSite)

---

### 3. Data Protection

**Sensitive Data**
- [ ] Secrets not hardcoded in source
- [ ] Environment variables or secret manager used
- [ ] No secrets in logs
- [ ] No secrets in error messages
- [ ] PII minimized and encrypted at rest

**Transmission**
- [ ] TLS for all external communication
- [ ] Certificate validation enabled
- [ ] No sensitive data in URLs (query strings logged)

**Storage**
- [ ] Encryption at rest for sensitive data
- [ ] Database credentials not in source code
- [ ] Backups encrypted

---

### 4. Input Validation

**General**
- [ ] Input validated on server side (client validation is UX only)
- [ ] Validation uses allowlist, not denylist
- [ ] Input length limits enforced
- [ ] Type coercion handled safely

**File Uploads**
- [ ] File type validated by content, not extension
- [ ] Maximum file size enforced
- [ ] Files stored outside web root
- [ ] Filename sanitized
- [ ] Malware scanning for uploaded files (if applicable)

---

### 5. Error Handling & Logging

**Error Messages**
- [ ] Stack traces not exposed to users
- [ ] Errors don't reveal system internals
- [ ] Generic messages for auth failures (no "user not found" vs "wrong password")

**Logging**
- [ ] Security events logged (login, logout, failures)
- [ ] No sensitive data in logs (passwords, tokens, PII)
- [ ] Logs protected from tampering
- [ ] Sufficient detail for incident response

---

### 6. Cryptography

**Key Management**
- [ ] Keys not in source code
- [ ] Key rotation supported
- [ ] Different keys per environment

**Algorithm Choice**
- [ ] Modern algorithms (AES-256, RSA-2048+, SHA-256+)
- [ ] No deprecated algorithms (MD5, SHA1, DES)
- [ ] Proper IV/nonce handling (random, never reused)

**Random Numbers**
- [ ] CSPRNG used for security purposes
- [ ] Not seeded with predictable values
- [ ] Sufficient entropy

---

### 7. API Security

**Rate Limiting**
- [ ] Rate limits on all endpoints
- [ ] Stricter limits on auth endpoints
- [ ] Rate limit headers returned

**CORS**
- [ ] Allowed origins explicitly listed
- [ ] No wildcard in production
- [ ] Credentials require specific origin

**Request Validation**
- [ ] Content-Type validated
- [ ] Request size limits enforced
- [ ] CSRF protection for state-changing operations

---

## Severity Classification

| Severity | Impact | Response |
|----------|--------|----------|
| **Critical** | RCE, data breach, auth bypass | Block merge, immediate fix |
| **High** | Privilege escalation, injection vectors | Block merge, fix before release |
| **Medium** | Information disclosure, weak crypto | Fix before release, may accept risk |
| **Low** | Hardening gaps, defense-in-depth | Track, fix when convenient |

---

## Common Vulnerability Patterns

### Pattern: Direct Input in Query
```
# VULNERABLE
query = f"SELECT * FROM users WHERE id = '{user_id}'"

# SECURE
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, [user_id])
```

### Pattern: Hardcoded Secret
```
# VULNERABLE
API_KEY = "sk-12345abcde"

# SECURE
API_KEY = os.environ["API_KEY"]
```

### Pattern: Missing Auth Check
```
# VULNERABLE
def get_user(request, user_id):
    return User.objects.get(id=user_id)

# SECURE
def get_user(request, user_id):
    if request.user.id != user_id and not request.user.is_admin:
        raise PermissionDenied()
    return User.objects.get(id=user_id)
```

---

## Language-Specific Security

Detect project type and apply appropriate patterns:

- **Python** (`pyproject.toml`, `setup.py`): See [python.md](references/python.md)
- **TypeScript** (`package.json` + `tsconfig.json`): See [typescript.md](references/typescript.md)

---

## Security Review Output

When reporting security issues:

```yaml
security_issues:
  - severity: critical
    category: injection
    location: src/api/users.py:45
    description: "SQL query uses string formatting with user input"
    remediation: "Use parameterized query with cursor.execute(query, [param])"

  - severity: high
    category: authentication
    location: src/auth/login.py:23
    description: "No rate limiting on login endpoint"
    remediation: "Add rate limiting middleware, max 5 attempts per minute"
```

Report format:
1. **Severity**: critical | high | medium | low
2. **Category**: injection | auth | crypto | data | config
3. **Location**: File and line number
4. **Description**: What the issue is
5. **Remediation**: How to fix it
