# Python Error Handling Patterns

Python-specific error handling patterns. Apply alongside universal principles.

---

## Exception Hierarchy

### Built-in Hierarchy (relevant subset)

```
BaseException
├── SystemExit
├── KeyboardInterrupt
├── GeneratorExit
└── Exception
    ├── StopIteration
    ├── ArithmeticError
    │   └── ZeroDivisionError
    ├── LookupError
    │   ├── KeyError
    │   └── IndexError
    ├── OSError
    │   ├── FileNotFoundError
    │   └── PermissionError
    ├── ValueError
    ├── TypeError
    └── RuntimeError
```

**Never catch `BaseException`** — catches `KeyboardInterrupt` and `SystemExit`.

### Custom Exception Design

```python
class AppError(Exception):
    """Base exception for application errors."""

    def __init__(self, message: str, code: str | None = None):
        super().__init__(message)
        self.code = code


class ValidationError(AppError):
    """Input validation failed."""

    def __init__(self, message: str, field: str | None = None):
        super().__init__(message, code="VALIDATION_ERROR")
        self.field = field


class NotFoundError(AppError):
    """Resource not found."""

    def __init__(self, resource: str, identifier: str):
        super().__init__(f"{resource} not found: {identifier}", code="NOT_FOUND")
        self.resource = resource
        self.identifier = identifier


class DuplicateError(AppError):
    """Resource already exists."""

    def __init__(self, resource: str, field: str, value: str):
        super().__init__(
            f"{resource} with {field}='{value}' already exists",
            code="DUPLICATE",
        )
        self.resource = resource
        self.field = field
        self.value = value
```

---

## Exception Handling Patterns

### Basic Try-Except

```python
# Catch specific exceptions
try:
    user = repository.get_by_id(user_id)
except NotFoundError:
    return None
except RepositoryError as e:
    logger.error(f"Database error: {e}")
    raise

# Multiple exceptions
try:
    result = process_data(data)
except (ValueError, TypeError) as e:
    raise ValidationError(f"Invalid data: {e}") from e
```

### Exception Chaining

```python
# Preserve original exception context
try:
    response = external_api.call(endpoint)
except requests.RequestException as e:
    raise ServiceError(f"API call failed: {endpoint}") from e

# Access chain
try:
    do_something()
except ServiceError as e:
    print(f"Service error: {e}")
    print(f"Caused by: {e.__cause__}")
```

### Context Managers for Cleanup

```python
from contextlib import contextmanager

@contextmanager
def database_transaction(session):
    """Ensure transaction is committed or rolled back."""
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


# Usage
with database_transaction(session) as tx:
    tx.add(user)
    tx.add(profile)
    # Commits on success, rolls back on exception
```

### Suppress Specific Exceptions

```python
from contextlib import suppress

# Ignore specific expected exceptions
with suppress(FileNotFoundError):
    os.remove(temp_file)

# Equivalent to:
try:
    os.remove(temp_file)
except FileNotFoundError:
    pass
```

---

## Error Handling in Async Code

### Async Exception Handling

```python
async def fetch_user(user_id: str) -> User:
    try:
        response = await client.get(f"/users/{user_id}")
        response.raise_for_status()
        return User(**response.json())
    except httpx.HTTPStatusError as e:
        if e.response.status_code == 404:
            raise NotFoundError("User", user_id) from e
        raise ServiceError(f"API error: {e}") from e
    except httpx.RequestError as e:
        raise ServiceError(f"Network error: {e}") from e
```

### Handling Multiple Async Operations

```python
import asyncio

async def fetch_all_users(user_ids: list[str]) -> list[User | None]:
    """Fetch users, returning None for failures."""
    tasks = [fetch_user(uid) for uid in user_ids]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    users = []
    for result in results:
        if isinstance(result, Exception):
            logger.warning(f"Failed to fetch user: {result}")
            users.append(None)
        else:
            users.append(result)
    return users
```

### Async Context Managers

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def managed_connection():
    conn = await create_connection()
    try:
        yield conn
    finally:
        await conn.close()


async with managed_connection() as conn:
    await conn.execute(query)
```

---

## Web Framework Error Handling

### FastAPI

```python
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

app = FastAPI()


# Custom exception handler
@app.exception_handler(NotFoundError)
async def not_found_handler(request: Request, exc: NotFoundError):
    return JSONResponse(
        status_code=404,
        content={
            "error": {
                "code": exc.code,
                "message": str(exc),
                "resource": exc.resource,
            }
        },
    )


@app.exception_handler(ValidationError)
async def validation_handler(request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=400,
        content={
            "error": {
                "code": exc.code,
                "message": str(exc),
                "field": exc.field,
            }
        },
    )


# Catch-all for unexpected errors
@app.exception_handler(Exception)
async def generic_handler(request: Request, exc: Exception):
    logger.exception("Unexpected error")
    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "An unexpected error occurred",
            }
        },
    )
```

### Flask

```python
from flask import Flask, jsonify

app = Flask(__name__)


@app.errorhandler(NotFoundError)
def handle_not_found(error):
    return jsonify({
        "error": {
            "code": error.code,
            "message": str(error),
        }
    }), 404


@app.errorhandler(ValidationError)
def handle_validation(error):
    return jsonify({
        "error": {
            "code": error.code,
            "message": str(error),
            "field": error.field,
        }
    }), 400


@app.errorhandler(Exception)
def handle_generic(error):
    app.logger.exception("Unexpected error")
    return jsonify({
        "error": {
            "code": "INTERNAL_ERROR",
            "message": "An unexpected error occurred",
        }
    }), 500
```

---

## Logging Best Practices

### Structured Logging

```python
import structlog

logger = structlog.get_logger()

def create_user(email: str, name: str) -> User:
    log = logger.bind(email=email, action="create_user")

    try:
        user = repository.create(email=email, name=name)
        log.info("user_created", user_id=user.id)
        return user
    except DuplicateError as e:
        log.warning("duplicate_email")
        raise
    except Exception as e:
        log.exception("create_user_failed")
        raise
```

### Standard Library Logging

```python
import logging

logger = logging.getLogger(__name__)

def process_order(order_id: str) -> Order:
    logger.info("Processing order", extra={"order_id": order_id})

    try:
        order = repository.get(order_id)
        result = payment_service.charge(order)
        logger.info(
            "Order processed",
            extra={"order_id": order_id, "amount": order.total},
        )
        return result
    except PaymentError as e:
        logger.warning(
            "Payment failed",
            extra={"order_id": order_id, "error": str(e)},
        )
        raise
    except Exception:
        logger.exception("Unexpected error processing order")
        raise
```

---

## Retry Patterns

### Simple Retry with Tenacity

```python
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=0.1, max=10),
    retry=retry_if_exception_type((ConnectionError, TimeoutError)),
)
def call_external_service(data: dict) -> dict:
    response = requests.post(API_URL, json=data, timeout=5)
    response.raise_for_status()
    return response.json()
```

### Manual Retry

```python
import time
from typing import TypeVar, Callable

T = TypeVar("T")

def with_retry(
    func: Callable[[], T],
    max_attempts: int = 3,
    retry_on: tuple[type[Exception], ...] = (Exception,),
    backoff: float = 0.1,
) -> T:
    """Execute function with retry logic."""
    last_exception: Exception | None = None

    for attempt in range(max_attempts):
        try:
            return func()
        except retry_on as e:
            last_exception = e
            if attempt < max_attempts - 1:
                sleep_time = backoff * (2 ** attempt)
                time.sleep(sleep_time)

    raise last_exception  # type: ignore
```

---

## Result Type Pattern

### Using Result Instead of Exceptions

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")
E = TypeVar("E")


@dataclass
class Ok(Generic[T]):
    value: T


@dataclass
class Err(Generic[E]):
    error: E


Result = Ok[T] | Err[E]


def parse_int(s: str) -> Result[int, str]:
    try:
        return Ok(int(s))
    except ValueError:
        return Err(f"Cannot parse '{s}' as integer")


# Usage
match parse_int(user_input):
    case Ok(value):
        print(f"Got number: {value}")
    case Err(error):
        print(f"Error: {error}")
```

---

## Common Patterns

### Null Object Pattern

```python
class NullUser:
    """Null object for missing users."""

    id = None
    email = ""
    name = "Anonymous"

    def is_authenticated(self) -> bool:
        return False


def get_current_user(request) -> User | NullUser:
    """Return user or null object, never None."""
    token = request.headers.get("Authorization")
    if not token:
        return NullUser()
    try:
        return verify_token(token)
    except InvalidTokenError:
        return NullUser()


# Usage - no None checks needed
user = get_current_user(request)
print(f"Hello, {user.name}")  # Works for both User and NullUser
```

### Guard Clauses

```python
def process_order(order: Order | None, user: User | None) -> Receipt:
    # Guard clauses - fail fast
    if order is None:
        raise ValueError("Order is required")
    if user is None:
        raise ValueError("User is required")
    if order.status != "pending":
        raise InvalidStateError(f"Order must be pending, got: {order.status}")
    if not user.can_purchase():
        raise PermissionError("User cannot make purchases")

    # Main logic - no nesting
    return payment_service.process(order, user)
```
