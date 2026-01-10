---
name: specwright-review-standards
description: |
  Code quality standards for reviewing implementations, analyzing failures, and assessing correctness.

  INVOKE WHEN: review_agent analyzes verification failures, assessing whether implementation matches spec, or evaluating code quality against standards.

  PROVIDES: Universal principles (function design, naming, organization, comments, error handling), review checklist with severity classifications, language-agnostic quality gates.

  LANGUAGE REFERENCES: Load references/python.md for Python codebases (PEP 8, type hints, pytest patterns). Load references/typescript.md for TypeScript codebases (ESLint, strict mode, React patterns).

  USE CASE: Determining whether implementation_bug or test_bug caused a failure. Ensuring fixes meet quality standards before approval.
allowed-tools: Read, Grep, Glob
---

# Code Review Standards

Standards for reviewing code quality across all languages. Apply these when analyzing implementation correctness or failure root causes.

## Universal Principles

### Function Design
- **Single responsibility**: Each function does one thing
- **Size limit**: Functions under 30 lines preferred; extract beyond 50
- **Nesting depth**: Maximum 3 levels; extract or early-return beyond this
- **Parameter count**: Maximum 4 parameters; use objects/structs beyond this
- **Early returns**: Guard clauses at function start, not nested conditions

### Naming
- **Descriptive**: Names reveal intent, not implementation
- **Consistent**: Same concept uses same name throughout codebase
- **Searchable**: Avoid single-letter names except loop indices
- **No abbreviations**: Unless universally understood (e.g., `id`, `url`)

### Code Organization
- **Imports**: Grouped by standard library, external, internal
- **Constants**: Named, not magic numbers/strings inline
- **Dead code**: No commented-out code blocks
- **DRY**: No duplicate logic; extract shared code

### Comments
- **Why, not what**: Explain reasoning, not mechanics
- **No obvious comments**: `// increment counter` on `counter++` is noise
- **TODO format**: Include ticket/issue reference when possible
- **Docstrings**: Public APIs have purpose, parameters, return documented

### Error Handling
- **No silent failures**: Errors logged or returned, never swallowed
- **Context preserved**: Error messages include what operation failed
- **Appropriate granularity**: Handle at correct boundary, not everywhere
- **Fail fast**: Invalid state detected early, not after side effects

### Testing Indicators
- **Testable design**: Dependencies injectable, not hardcoded
- **Pure functions**: Prefer stateless where possible
- **Side effects isolated**: I/O at boundaries, logic in core

---

## Review Checklist

When reviewing code, verify:

1. [ ] Functions have single responsibility
2. [ ] Nesting depth ≤ 3 levels
3. [ ] No magic numbers/strings
4. [ ] Error cases handled explicitly
5. [ ] No dead code or commented blocks
6. [ ] Names are descriptive and consistent
7. [ ] Public APIs documented
8. [ ] No obvious security issues (see security-review skill)

---

## Language-Specific Standards

Detect project type and apply appropriate standards:

- **Python** (`pyproject.toml`, `setup.py`, `requirements.txt`): See [python.md](references/python.md)
- **TypeScript** (`package.json` + `tsconfig.json`): See [typescript.md](references/typescript.md)

---

## Failure Analysis

When analyzing test or verification failures:

1. **Identify the assertion**: What specifically failed?
2. **Trace the data flow**: Where did the unexpected value originate?
3. **Check boundary conditions**: Off-by-one, null/undefined, empty collections
4. **Verify contracts**: Does implementation match interface/type expectations?
5. **Consider concurrency**: Race conditions, shared state mutations

---

## Severity Classification

| Severity | Criteria | Action |
|----------|----------|--------|
| **Critical** | Security flaw, data loss risk, crash | Must fix before merge |
| **Major** | Logic error, missing error handling | Should fix before merge |
| **Minor** | Style issue, naming, documentation | Fix or acknowledge |
| **Nitpick** | Preference, micro-optimization | Optional |

Focus review feedback on Critical and Major issues. Batch Minor/Nitpick items.
