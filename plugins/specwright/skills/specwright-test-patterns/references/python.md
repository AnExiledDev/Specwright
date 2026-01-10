# Python Test Patterns

Python-specific testing patterns using pytest. Apply alongside universal principles.

---

## Pytest Fundamentals

### Test Discovery

Pytest finds tests automatically:

- Files: `test_*.py` or `*_test.py`
- Functions: `test_*`
- Classes: `Test*` (no `__init__`)
- Methods: `test_*` within test classes

### Basic Test Structure

```python
def test_create_user_returns_user_with_id():
    # Arrange
    user_data = {"email": "test@example.com", "name": "Test User"}
    repository = UserRepository()

    # Act
    user = repository.create(user_data)

    # Assert
    assert user.id is not None
    assert user.email == "test@example.com"
```

---

## Fixtures

### Basic Fixture

```python
import pytest

@pytest.fixture
def user():
    """Provide a test user."""
    return User(id="123", email="test@example.com", name="Test User")

def test_user_has_email(user):
    assert user.email == "test@example.com"
```

### Fixture Scope

```python
@pytest.fixture(scope="function")  # Default: new instance per test
def user(): ...

@pytest.fixture(scope="class")     # Shared within test class
def database(): ...

@pytest.fixture(scope="module")    # Shared within module
def api_client(): ...

@pytest.fixture(scope="session")   # Shared across entire session
def expensive_resource(): ...
```

### Fixture with Teardown

```python
@pytest.fixture
def temp_file():
    # Setup
    path = Path("/tmp/test_file.txt")
    path.write_text("test content")

    yield path  # Provide to test

    # Teardown
    path.unlink(missing_ok=True)
```

### Factory Fixtures

```python
@pytest.fixture
def create_user():
    """Factory for creating test users."""
    created_users = []

    def _create_user(email: str = "test@example.com", name: str = "Test"):
        user = User(id=str(uuid4()), email=email, name=name)
        created_users.append(user)
        return user

    yield _create_user

    # Cleanup
    for user in created_users:
        # cleanup logic if needed
        pass
```

---

## Parametrization

### Basic Parametrize

```python
@pytest.mark.parametrize("email,is_valid", [
    ("user@example.com", True),
    ("user@domain.org", True),
    ("invalid-email", False),
    ("", False),
    (None, False),
])
def test_email_validation(email, is_valid):
    assert validate_email(email) == is_valid
```

### Multiple Parameters

```python
@pytest.mark.parametrize("a,b,expected", [
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
    (100, 200, 300),
])
def test_addition(a, b, expected):
    assert add(a, b) == expected
```

### IDs for Readability

```python
@pytest.mark.parametrize("input_value,expected", [
    pytest.param("hello", "HELLO", id="lowercase"),
    pytest.param("WORLD", "WORLD", id="already_upper"),
    pytest.param("MiXeD", "MIXED", id="mixed_case"),
])
def test_uppercase(input_value, expected):
    assert input_value.upper() == expected
```

---

## Assertions

### Standard Assertions

```python
# Equality
assert result == expected
assert result != unexpected

# Identity
assert result is None
assert result is not None

# Truthiness
assert condition
assert not condition

# Membership
assert item in collection
assert item not in collection

# Type
assert isinstance(result, User)
```

### Exception Testing

```python
def test_create_user_with_invalid_email_raises():
    with pytest.raises(ValidationError) as exc_info:
        create_user(email="invalid")

    assert "email" in str(exc_info.value)
```

### Approximate Comparisons

```python
# Float comparison with tolerance
assert result == pytest.approx(3.14159, rel=1e-5)

# Dictionary subset
assert actual == pytest.approx({"value": 3.14}, rel=0.01)
```

---

## Mocking

### Using unittest.mock

```python
from unittest.mock import Mock, patch, MagicMock

def test_service_calls_repository():
    # Arrange
    mock_repo = Mock(spec=UserRepository)
    mock_repo.get.return_value = User(id="123", email="test@example.com")
    service = UserService(repository=mock_repo)

    # Act
    result = service.get_user("123")

    # Assert
    mock_repo.get.assert_called_once_with("123")
    assert result.id == "123"
```

### Patching

```python
@patch("myapp.services.user_service.UserRepository")
def test_service_with_patched_repo(MockRepo):
    mock_instance = MockRepo.return_value
    mock_instance.get.return_value = User(id="123")

    service = UserService()
    result = service.get_user("123")

    assert result.id == "123"
```

### pytest-mock

```python
def test_service_calls_api(mocker):
    mock_response = mocker.Mock()
    mock_response.json.return_value = {"id": "123"}
    mocker.patch("requests.get", return_value=mock_response)

    result = fetch_user("123")

    assert result["id"] == "123"
```

---

## Async Testing

### pytest-asyncio

```python
import pytest

@pytest.mark.asyncio
async def test_async_fetch_user():
    # Arrange
    client = AsyncUserClient()

    # Act
    user = await client.get_user("123")

    # Assert
    assert user.id == "123"
```

### Async Fixtures

```python
@pytest.fixture
async def async_client():
    client = AsyncClient()
    await client.connect()
    yield client
    await client.disconnect()

@pytest.mark.asyncio
async def test_with_async_client(async_client):
    result = await async_client.fetch("/users")
    assert result.status == 200
```

---

## Markers

### Built-in Markers

```python
@pytest.mark.skip(reason="Not implemented yet")
def test_future_feature(): ...

@pytest.mark.skipif(sys.platform == "win32", reason="Unix only")
def test_unix_specific(): ...

@pytest.mark.xfail(reason="Known bug #123")
def test_known_failure(): ...

@pytest.mark.slow
def test_slow_operation(): ...  # Run with: pytest -m slow
```

### Custom Markers

```python
# conftest.py
def pytest_configure(config):
    config.addinivalue_line("markers", "integration: integration tests")

# test file
@pytest.mark.integration
def test_database_connection(): ...
```

---

## Conftest Patterns

### Shared Fixtures

```python
# tests/conftest.py - available to all tests

@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.rollback()
    session.close()

@pytest.fixture(autouse=True)
def reset_singletons():
    """Reset singletons before each test."""
    SingletonClass.reset()
```

### Plugin Hooks

```python
# conftest.py
def pytest_collection_modifyitems(items):
    """Add slow marker to tests with 'slow' in name."""
    for item in items:
        if "slow" in item.nodeid:
            item.add_marker(pytest.mark.slow)
```

---

## Common Patterns

### Database Test Pattern

```python
@pytest.fixture
def db_session():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    yield session

    session.close()

def test_user_persistence(db_session):
    user = User(email="test@example.com")
    db_session.add(user)
    db_session.commit()

    retrieved = db_session.query(User).filter_by(email="test@example.com").first()
    assert retrieved is not None
```

### API Test Pattern

```python
from fastapi.testclient import TestClient

@pytest.fixture
def client():
    return TestClient(app)

def test_create_user_endpoint(client):
    response = client.post("/users", json={"email": "test@example.com"})

    assert response.status_code == 201
    assert response.json()["email"] == "test@example.com"
```

### Time-Dependent Test Pattern

```python
from freezegun import freeze_time

@freeze_time("2025-01-15 12:00:00")
def test_token_expiration():
    token = create_token(expires_in=3600)

    assert token.expires_at == datetime(2025, 1, 15, 13, 0, 0)
```
