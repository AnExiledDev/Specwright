---
name: specwright-test-patterns
description: |
  Test generation patterns for writing behavioral tests from task specifications.

  INVOKE WHEN: test_agent writes tests from creates.tests spec, needs to infer additional test cases for coverage, or must match existing test patterns in the codebase.

  PROVIDES: AAA structure (Arrange-Act-Assert), naming conventions (Method_Scenario_Expected), test categories (happy path, edge cases, error cases, integration), coverage expectations, mocking guidelines, fixture patterns.

  LANGUAGE REFERENCES: Load references/python.md for Python (pytest, fixtures, parametrize, async testing, conftest). Load references/typescript.md for TypeScript (Jest, React Testing Library, type-safe mocking).

  USE CASE: Generating comprehensive test suites that validate specification behavior. Adding inferred_cases for scenarios not explicitly in spec.
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Test Generation Patterns

Standards for writing tests across all languages. Apply these when creating test cases from specifications.

## Universal Principles

### Test Structure: Arrange-Act-Assert (AAA)

Every test follows this pattern:

```
ARRANGE: Set up test data and dependencies
ACT:     Execute the code under test
ASSERT:  Verify the outcome
```

Keep each section clearly separated. One blank line between sections.

### Naming Convention

Test names describe behavior, not implementation:

```
Format: test_<unit>_<scenario>_<expected_outcome>

Good:  test_create_user_with_duplicate_email_returns_error
Bad:   test_create_user_1
Bad:   test_user_repository
```

### One Concept Per Test

Each test verifies exactly one behavior:

- Single assertion *concept* (multiple assertions on same object OK)
- Single code path tested
- Clear failure diagnosis

```
Good: test_user_creation_generates_uuid
Good: test_user_creation_sets_created_timestamp

Bad:  test_user_creation  # Tests UUID, timestamp, email, name...
```

### Test Independence

Tests must not depend on each other:

- No shared mutable state between tests
- No required execution order
- Each test sets up its own data
- Each test cleans up after itself (or uses isolated fixtures)

---

## Test Case Categories

### 1. Happy Path
The primary success scenario. Always test first.

```
Input: Valid data
Expected: Success result
```

### 2. Edge Cases
Boundary conditions and limits:

- Empty inputs (empty string, empty list, zero)
- Single item collections
- Maximum values
- Minimum values
- Boundary values (off-by-one)

### 3. Error Cases
Invalid inputs and failure modes:

- Null/None/undefined inputs
- Invalid format (malformed email, negative ID)
- Missing required fields
- Type mismatches
- Permission/authorization failures

### 4. State Transitions
For stateful operations:

- Initial state → action → expected state
- Invalid state transitions rejected
- Idempotency (same action twice = same result)

---

## Coverage Expectations

### Minimum Coverage Per Function

| Category | Required Tests |
|----------|----------------|
| Happy path | At least 1 |
| Error handling | Each documented error type |
| Null/empty inputs | If accepted, test behavior |
| Boundary values | Where applicable |

### What NOT to Test

- Third-party library internals
- Language features (unless wrapping them)
- Private implementation details
- Trivial getters/setters (unless with logic)

---

## Mocking Guidelines

### When to Mock

✅ External services (APIs, databases, file systems)
✅ Time/date for deterministic tests
✅ Random/UUID generation for reproducibility
✅ Slow operations for fast test execution

### When NOT to Mock

❌ The unit under test
❌ Pure data transformations
❌ Simple collaborators that are fast and deterministic

### Mock Boundaries

Mock at architectural boundaries:

```
┌─────────────────────────────────────────┐
│ Unit Test                               │
│  ┌─────────────┐    ┌────────────────┐  │
│  │ Service     │───→│ Repository     │  │  ← Mock here
│  │ (test this) │    │ (mock this)    │  │
│  └─────────────┘    └────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Fixture Patterns

### Setup/Teardown

- Use framework fixtures (`@pytest.fixture`, `beforeEach`)
- Prefer factory functions over shared instances
- Clean up resources in teardown

### Test Data Factories

Create functions that generate test data:

```
create_user(overrides) → User with sensible defaults
create_order(user, items) → Order with required relationships
```

Benefits:
- Consistent test data
- Easy to customize per test
- Single place to update when model changes

---

## Assertion Best Practices

### Be Specific

```
Good: assert user.email == "test@example.com"
Bad:  assert user is not None  # Passes even if email wrong
```

### Assert Minimal

Only assert what the test is verifying:

```
Good: assert result.id is not None  # Testing ID generation
Bad:  assert result == expected_full_object  # Brittle to unrelated changes
```

### Error Messages

Include context in assertion messages:

```
Good: assert len(users) == 3, f"Expected 3 users, got {len(users)}"
```

---

## Language-Specific Patterns

Detect project type and apply appropriate patterns:

- **Python** (`pyproject.toml`, `setup.py`): See [python.md](references/python.md)
- **TypeScript** (`package.json` + `tsconfig.json`): See [typescript.md](references/typescript.md)

---

## Test-Driven from Specification

When writing tests from task specifications:

1. **Read the specification completely** — understand expected behavior
2. **Identify test cases** — map each `expected` to a test
3. **Write failing test first** — verify test can detect failure
4. **Consider edge cases** — add cases beyond specification if obvious

### Specification Mapping Example

```yaml
# From task specification
creates:
  tests:
    - name: "TestCreate_Success"
      input: {user: "valid User object"}
      expected: "No error, user persisted with generated ID"
```

Maps to:

```
test_create_success:
  ARRANGE: Create valid User object
  ACT: Call repository.create(user)
  ASSERT:
    - No error returned
    - User has non-empty ID
    - User can be retrieved (persisted)
```

---

## Test File Organization

```
tests/
├── unit/                    # Fast, isolated tests
│   ├── services/
│   │   └── user_service_test.py
│   └── repositories/
│       └── user_repository_test.py
├── integration/             # Tests with real dependencies
│   └── api/
│       └── user_api_test.py
└── fixtures/                # Shared test utilities
    ├── factories.py
    └── mocks.py
```

Keep test files parallel to source structure. Test file naming: `<source>_test.py` or `<source>.test.ts`.
