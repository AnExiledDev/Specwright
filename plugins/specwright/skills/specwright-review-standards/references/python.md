# Python Review Standards

Python-specific code review criteria. Apply alongside universal principles.

---

## Style & Formatting

### PEP 8 Compliance
- Line length: 88 characters (Black default) or 79 (strict PEP 8)
- Indentation: 4 spaces, never tabs
- Blank lines: 2 between top-level definitions, 1 between methods
- Imports: `isort` ordering (stdlib → third-party → local)

### Type Hints
- **Required for**: Public functions, class methods, module-level variables
- **Optional for**: Local variables, comprehensions, obvious returns
- Use `from __future__ import annotations` for forward references

```python
# Good
def get_user(user_id: str) -> User | None:
    ...

# Avoid
def get_user(user_id):
    ...
```

### Docstrings
- Use Google or NumPy style consistently
- Required for public modules, classes, functions
- Include Args, Returns, Raises sections

```python
def create_user(email: str, name: str) -> User:
    """Create a new user account.

    Args:
        email: User's email address (must be unique).
        name: Display name for the user.

    Returns:
        Newly created User instance with generated ID.

    Raises:
        DuplicateEmailError: If email already registered.
        ValidationError: If email format invalid.
    """
```

---

## Error Handling

### Exception Patterns
- Catch specific exceptions, not bare `except:`
- Use `from` for exception chaining
- Custom exceptions inherit from appropriate base

```python
# Good
try:
    result = api.fetch(url)
except requests.Timeout as e:
    raise ServiceUnavailableError(f"API timeout: {url}") from e
except requests.RequestException as e:
    raise ServiceError(f"API error: {e}") from e

# Avoid
try:
    result = api.fetch(url)
except:
    pass
```

### Context Managers
- Use `with` for resource management (files, connections, locks)
- Implement `__enter__`/`__exit__` or use `@contextmanager`

```python
# Good
with open(path, 'r') as f:
    data = f.read()

# Avoid
f = open(path, 'r')
data = f.read()
f.close()
```

---

## Data Structures

### Dataclasses
- Use `@dataclass` for data containers
- Use `frozen=True` for immutable data
- Consider `pydantic.BaseModel` for validation

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class User:
    id: str
    email: str
    name: str
```

### Collections
- Prefer `list`/`dict` literals over constructors
- Use comprehensions for simple transforms
- Use generators for large sequences

```python
# Good
users = [User(id=str(i)) for i in range(10)]
active = {u.id: u for u in users if u.active}

# Avoid for simple cases
users = list(map(lambda i: User(id=str(i)), range(10)))
```

---

## Async Patterns

### Async/Await
- Use `async def` for I/O-bound operations
- Avoid blocking calls in async functions
- Use `asyncio.gather` for concurrent operations

```python
# Good
async def fetch_all(urls: list[str]) -> list[Response]:
    return await asyncio.gather(*[fetch(url) for url in urls])

# Avoid
async def fetch_all(urls: list[str]) -> list[Response]:
    results = []
    for url in urls:
        results.append(await fetch(url))  # Sequential, not concurrent
    return results
```

---

## Testing Patterns

### Pytest Conventions
- Test files: `test_*.py` or `*_test.py`
- Test functions: `test_<thing>_<scenario>`
- Fixtures for setup/teardown
- Parametrize for multiple cases

```python
import pytest

@pytest.fixture
def user():
    return User(id="1", email="test@example.com", name="Test")

def test_user_creation_success(user):
    assert user.id == "1"
    assert user.email == "test@example.com"

@pytest.mark.parametrize("email,valid", [
    ("user@example.com", True),
    ("invalid", False),
    ("", False),
])
def test_email_validation(email, valid):
    assert validate_email(email) == valid
```

### Mocking
- Use `unittest.mock` or `pytest-mock`
- Mock at boundaries, not internals
- Prefer dependency injection over patching

```python
def test_service_calls_repository(mocker):
    mock_repo = mocker.Mock(spec=UserRepository)
    mock_repo.get.return_value = User(id="1", email="test@example.com")

    service = UserService(repository=mock_repo)
    result = service.get_user("1")

    mock_repo.get.assert_called_once_with("1")
    assert result.id == "1"
```

---

## Common Issues

| Issue | Problem | Fix |
|-------|---------|-----|
| Mutable default args | `def f(items=[])` shares list | Use `items=None`, then `items = items or []` |
| Late binding closures | Loop variable captured by reference | Use default arg: `lambda x=x: x` |
| Bare except | Catches `KeyboardInterrupt`, `SystemExit` | Catch `Exception` or specific types |
| String concatenation in loop | O(n²) for large loops | Use `''.join(items)` or f-strings |
| `is` vs `==` for values | `is` checks identity, not equality | Use `==` for value comparison |
