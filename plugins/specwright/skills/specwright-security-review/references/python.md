# Python Security Patterns

Python-specific security patterns. Apply alongside universal security checklist.

---

## Injection Prevention

### SQL Injection

**Database Libraries**

```python
# VULNERABLE - string formatting
cursor.execute(f"SELECT * FROM users WHERE id = '{user_id}'")
cursor.execute("SELECT * FROM users WHERE id = '%s'" % user_id)
cursor.execute("SELECT * FROM users WHERE id = " + user_id)

# SECURE - parameterized queries
cursor.execute("SELECT * FROM users WHERE id = %s", [user_id])
cursor.execute("SELECT * FROM users WHERE id = ?", [user_id])  # sqlite
```

**SQLAlchemy ORM**

```python
# VULNERABLE
session.execute(f"SELECT * FROM users WHERE email = '{email}'")
User.query.filter(text(f"email = '{email}'"))

# SECURE
session.query(User).filter(User.email == email)
session.execute(text("SELECT * FROM users WHERE email = :email"), {"email": email})
```

**Django ORM**

```python
# VULNERABLE
User.objects.raw(f"SELECT * FROM users WHERE email = '{email}'")
User.objects.extra(where=[f"email = '{email}'"])

# SECURE
User.objects.filter(email=email)
User.objects.raw("SELECT * FROM users WHERE email = %s", [email])
```

### Command Injection

```python
# VULNERABLE
os.system(f"convert {user_filename} output.png")
subprocess.run(f"echo {user_input}", shell=True)

# SECURE
subprocess.run(["convert", user_filename, "output.png"], shell=False)
subprocess.run(["echo", user_input], shell=False)

# If shell required (avoid if possible)
import shlex
subprocess.run(f"echo {shlex.quote(user_input)}", shell=True)
```

### Path Traversal

```python
# VULNERABLE
def read_file(filename):
    path = f"/uploads/{filename}"
    return open(path).read()

# SECURE
import os
from pathlib import Path

UPLOAD_DIR = Path("/uploads").resolve()

def read_file(filename):
    # Resolve and validate path
    requested = (UPLOAD_DIR / filename).resolve()
    if not requested.is_relative_to(UPLOAD_DIR):
        raise ValueError("Invalid path")
    return requested.read_text()
```

---

## Authentication

### Password Hashing

```python
# VULNERABLE
import hashlib
hashed = hashlib.md5(password.encode()).hexdigest()
hashed = hashlib.sha256(password.encode()).hexdigest()

# SECURE
import bcrypt

# Hashing
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

# Verification
bcrypt.checkpw(password.encode(), stored_hash)

# Alternative: passlib
from passlib.hash import argon2
hashed = argon2.hash(password)
argon2.verify(password, hashed)
```

### Timing-Safe Comparison

```python
# VULNERABLE - timing attack possible
if token == stored_token:
    return True

# SECURE
import hmac
if hmac.compare_digest(token, stored_token):
    return True

# For secrets module (Python 3.6+)
import secrets
secrets.compare_digest(token, stored_token)
```

### Secure Token Generation

```python
# VULNERABLE
import random
token = ''.join(random.choices('abcdef0123456789', k=32))

import uuid
token = str(uuid.uuid4())  # Not cryptographically random

# SECURE
import secrets
token = secrets.token_hex(32)  # 64 character hex string
token = secrets.token_urlsafe(32)  # URL-safe base64
```

---

## Data Protection

### Environment Variables

```python
# VULNERABLE
API_KEY = "sk-12345abcde"
DATABASE_URL = "postgres://user:password@localhost/db"

# SECURE
import os
API_KEY = os.environ["API_KEY"]
DATABASE_URL = os.environ["DATABASE_URL"]

# With default (non-sensitive only)
DEBUG = os.environ.get("DEBUG", "false").lower() == "true"

# Recommended: python-dotenv for development
from dotenv import load_dotenv
load_dotenv()  # Loads from .env file
```

### Sensitive Data in Logs

```python
# VULNERABLE
logger.info(f"User logged in: {user.email}, password: {password}")
logger.error(f"API call failed: {response.text}")  # May contain secrets

# SECURE
logger.info(f"User logged in: {user.id}")
logger.error(f"API call failed: status={response.status_code}")

# Redact sensitive fields
def redact(data: dict, fields: list[str]) -> dict:
    return {k: "***" if k in fields else v for k, v in data.items()}

logger.info(f"Request: {redact(request_data, ['password', 'token'])}")
```

---

## Input Validation

### Pydantic Validation

```python
from pydantic import BaseModel, EmailStr, Field, validator

class UserCreate(BaseModel):
    email: EmailStr
    name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=0, le=150)

    @validator('name')
    def name_must_be_alphanumeric(cls, v):
        if not v.replace(' ', '').isalnum():
            raise ValueError('Name must be alphanumeric')
        return v

# Usage
try:
    user = UserCreate(**request_data)
except ValidationError as e:
    return {"error": e.errors()}
```

### File Upload Validation

```python
import magic  # python-magic library

ALLOWED_TYPES = {'image/jpeg', 'image/png', 'image/gif'}
MAX_SIZE = 5 * 1024 * 1024  # 5MB

def validate_upload(file_content: bytes, filename: str) -> bool:
    # Check size
    if len(file_content) > MAX_SIZE:
        raise ValueError("File too large")

    # Check content type (not extension!)
    mime = magic.from_buffer(file_content, mime=True)
    if mime not in ALLOWED_TYPES:
        raise ValueError(f"Invalid file type: {mime}")

    # Sanitize filename
    safe_filename = secure_filename(filename)

    return True

def secure_filename(filename: str) -> str:
    """Remove path components and dangerous characters."""
    import re
    filename = os.path.basename(filename)
    filename = re.sub(r'[^\w\s\-\.]', '', filename)
    return filename
```

---

## Web Framework Security

### Django

```python
# settings.py security settings
DEBUG = False  # Never True in production

# HTTPS
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True

# Cookies
SESSION_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_SECURE = True

# XSS
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# Allowed hosts
ALLOWED_HOSTS = ['example.com', 'www.example.com']
```

### Flask

```python
from flask import Flask
from flask_talisman import Talisman

app = Flask(__name__)

# Security headers
Talisman(app,
    force_https=True,
    strict_transport_security=True,
    session_cookie_secure=True,
    session_cookie_http_only=True,
)

# CSRF protection
from flask_wtf.csrf import CSRFProtect
csrf = CSRFProtect(app)

# Rate limiting
from flask_limiter import Limiter
limiter = Limiter(app, key_func=get_remote_address)

@app.route("/login", methods=["POST"])
@limiter.limit("5 per minute")
def login():
    ...
```

### FastAPI

```python
from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from slowapi import Limiter
from slowapi.util import get_remote_address

app = FastAPI()
limiter = Limiter(key_func=get_remote_address)

# Authentication dependency
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    user = verify_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user

@app.get("/users/me")
async def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user
```

---

## Cryptography

### Encryption

```python
# VULNERABLE - ECB mode, weak key derivation
from Crypto.Cipher import AES
cipher = AES.new(key, AES.MODE_ECB)

# SECURE - using cryptography library
from cryptography.fernet import Fernet

# Key generation (store securely!)
key = Fernet.generate_key()

# Encryption
f = Fernet(key)
encrypted = f.encrypt(b"secret message")

# Decryption
decrypted = f.decrypt(encrypted)
```

### Key Derivation

```python
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
import os

def derive_key(password: str, salt: bytes = None) -> tuple[bytes, bytes]:
    if salt is None:
        salt = os.urandom(16)

    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=480000,  # OWASP 2023 recommendation
    )
    key = kdf.derive(password.encode())
    return key, salt
```

---

## Common Vulnerabilities

| Vulnerability | Detection Pattern | Fix |
|--------------|-------------------|-----|
| Pickle deserialization | `pickle.loads(user_data)` | Use JSON, validate schema |
| YAML unsafe load | `yaml.load(data)` | Use `yaml.safe_load()` |
| eval/exec | `eval(user_input)` | Never eval user input |
| assert in production | `assert user.is_admin` | Assertions can be disabled; use if/raise |
| Mutable default arg | `def f(items=[])` | Use `items=None` |
