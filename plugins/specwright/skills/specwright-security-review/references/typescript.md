# TypeScript Security Patterns

TypeScript-specific security patterns. Apply alongside universal security checklist.

---

## Injection Prevention

### SQL Injection

**Raw Queries**

```typescript
// VULNERABLE
const query = `SELECT * FROM users WHERE id = '${userId}'`;
await db.query(query);

// SECURE - parameterized
await db.query('SELECT * FROM users WHERE id = $1', [userId]);
```

**Prisma ORM**

```typescript
// VULNERABLE - raw query with interpolation
await prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;

// SECURE - parameterized
await prisma.user.findUnique({ where: { email } });

// If raw needed, use Prisma.sql
import { Prisma } from '@prisma/client';
await prisma.$queryRaw(Prisma.sql`SELECT * FROM users WHERE email = ${email}`);
```

**TypeORM**

```typescript
// VULNERABLE
await repository
  .createQueryBuilder()
  .where(`email = '${email}'`)
  .getOne();

// SECURE
await repository
  .createQueryBuilder()
  .where('email = :email', { email })
  .getOne();

// Or use repository methods
await repository.findOne({ where: { email } });
```

### Command Injection

```typescript
// VULNERABLE
import { exec } from 'child_process';
exec(`convert ${userFilename} output.png`);

// SECURE - use spawn with array
import { spawn } from 'child_process';
spawn('convert', [userFilename, 'output.png']);

// If shell needed (avoid!)
import { execFile } from 'child_process';
execFile('convert', [userFilename, 'output.png']);
```

### Path Traversal

```typescript
// VULNERABLE
import { readFileSync } from 'fs';
const content = readFileSync(`/uploads/${filename}`);

// SECURE
import { resolve, relative } from 'path';
import { readFileSync } from 'fs';

const UPLOAD_DIR = resolve('/uploads');

function readUpload(filename: string): string {
  const requested = resolve(UPLOAD_DIR, filename);
  const relativePath = relative(UPLOAD_DIR, requested);

  // Check for path traversal
  if (relativePath.startsWith('..') || resolve(relativePath) !== relativePath) {
    throw new Error('Invalid path');
  }

  return readFileSync(requested, 'utf-8');
}
```

---

## XSS Prevention

### React (JSX)

```tsx
// VULNERABLE - dangerouslySetInnerHTML
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// SECURE - React escapes by default
<div>{userContent}</div>

// If HTML needed, sanitize first
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />
```

### Template Literals in DOM

```typescript
// VULNERABLE
element.innerHTML = `<p>${userInput}</p>`;

// SECURE - use textContent
element.textContent = userInput;

// Or sanitize
import DOMPurify from 'dompurify';
element.innerHTML = DOMPurify.sanitize(`<p>${userInput}</p>`);
```

### URL Handling

```typescript
// VULNERABLE - javascript: protocol
<a href={userProvidedUrl}>Link</a>

// SECURE - validate protocol
function sanitizeUrl(url: string): string {
  try {
    const parsed = new URL(url);
    if (!['http:', 'https:'].includes(parsed.protocol)) {
      return '#';
    }
    return url;
  } catch {
    return '#';
  }
}

<a href={sanitizeUrl(userProvidedUrl)}>Link</a>
```

---

## Authentication

### Password Hashing

```typescript
// VULNERABLE
import crypto from 'crypto';
const hash = crypto.createHash('sha256').update(password).digest('hex');

// SECURE - bcrypt
import bcrypt from 'bcrypt';

// Hashing
const saltRounds = 12;
const hash = await bcrypt.hash(password, saltRounds);

// Verification
const match = await bcrypt.compare(password, storedHash);
```

### Timing-Safe Comparison

```typescript
// VULNERABLE
if (token === storedToken) { ... }

// SECURE
import crypto from 'crypto';

function secureCompare(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }
  return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b));
}
```

### Secure Token Generation

```typescript
// VULNERABLE
const token = Math.random().toString(36).substring(2);

// SECURE
import crypto from 'crypto';

const token = crypto.randomBytes(32).toString('hex');
// Or URL-safe
const urlSafeToken = crypto.randomBytes(32).toString('base64url');
```

### JWT Handling

```typescript
// VULNERABLE - no verification
import jwt from 'jsonwebtoken';
const payload = jwt.decode(token);  // No signature check!

// SECURE
const SECRET = process.env.JWT_SECRET!;

// Signing
const token = jwt.sign({ userId: user.id }, SECRET, {
  expiresIn: '1h',
  algorithm: 'HS256',
});

// Verification
try {
  const payload = jwt.verify(token, SECRET, {
    algorithms: ['HS256'],  // Prevent algorithm confusion
  });
} catch (error) {
  // Invalid token
}
```

---

## Data Protection

### Environment Variables

```typescript
// VULNERABLE
const API_KEY = 'sk-12345abcde';

// SECURE
const API_KEY = process.env.API_KEY;
if (!API_KEY) {
  throw new Error('API_KEY environment variable required');
}

// Type-safe config
interface Config {
  apiKey: string;
  databaseUrl: string;
}

function loadConfig(): Config {
  const apiKey = process.env.API_KEY;
  const databaseUrl = process.env.DATABASE_URL;

  if (!apiKey || !databaseUrl) {
    throw new Error('Missing required environment variables');
  }

  return { apiKey, databaseUrl };
}
```

### Sensitive Data in Logs

```typescript
// VULNERABLE
console.log('User login:', { email, password });
console.log('API response:', response.data);  // May contain secrets

// SECURE
console.log('User login:', { email, password: '[REDACTED]' });

// Utility function
function redact<T extends object>(obj: T, fields: (keyof T)[]): T {
  const result = { ...obj };
  for (const field of fields) {
    if (field in result) {
      (result as any)[field] = '[REDACTED]';
    }
  }
  return result;
}

console.log('Request:', redact(userData, ['password', 'ssn']));
```

---

## Input Validation

### Zod Validation

```typescript
import { z } from 'zod';

const UserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150),
});

type User = z.infer<typeof UserSchema>;

// Usage
function createUser(data: unknown): User {
  return UserSchema.parse(data);  // Throws on invalid
}

// Or with error handling
const result = UserSchema.safeParse(data);
if (!result.success) {
  return { error: result.error.format() };
}
```

### File Upload Validation

```typescript
import fileType from 'file-type';

const ALLOWED_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif']);
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

async function validateUpload(buffer: Buffer, filename: string): Promise<string> {
  // Check size
  if (buffer.length > MAX_SIZE) {
    throw new Error('File too large');
  }

  // Check content type (not extension!)
  const type = await fileType.fromBuffer(buffer);
  if (!type || !ALLOWED_TYPES.has(type.mime)) {
    throw new Error(`Invalid file type: ${type?.mime ?? 'unknown'}`);
  }

  // Sanitize filename
  const safeName = sanitizeFilename(filename);

  return safeName;
}

function sanitizeFilename(filename: string): string {
  return filename
    .replace(/[^a-zA-Z0-9.\-_]/g, '')
    .replace(/\.+/g, '.');
}
```

---

## API Security

### Express Security Middleware

```typescript
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

const app = express();

// Security headers
app.use(helmet());

// CORS
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? [],
  credentials: true,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
});
app.use(limiter);

// Stricter limit for auth endpoints
const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5,
});
app.use('/api/auth', authLimiter);

// Body size limit
app.use(express.json({ limit: '10kb' }));
```

### CSRF Protection

```typescript
import csrf from 'csurf';
import cookieParser from 'cookie-parser';

app.use(cookieParser());
app.use(csrf({ cookie: true }));

// Provide token to client
app.get('/api/csrf-token', (req, res) => {
  res.json({ csrfToken: req.csrfToken() });
});

// Client must include X-CSRF-Token header or _csrf body field
```

### Authorization Middleware

```typescript
interface AuthRequest extends Request {
  user?: User;
}

async function requireAuth(req: AuthRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const payload = jwt.verify(token, SECRET);
    req.user = await getUserById(payload.userId);
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

function requireRole(...roles: string[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

// Usage
app.get('/admin', requireAuth, requireRole('admin'), adminHandler);
```

---

## Common Vulnerabilities

| Vulnerability | Detection Pattern | Fix |
|--------------|-------------------|-----|
| Prototype pollution | `obj[userKey] = value` | Validate key, use Map |
| ReDoS | Complex regex on user input | Use RE2, limit input length |
| Insecure deserialization | `JSON.parse` with `eval` | Use standard JSON.parse |
| Open redirect | `res.redirect(userUrl)` | Validate against allowlist |
| SSRF | `fetch(userUrl)` | Validate URL, use allowlist |
| npm script injection | Dynamic package.json scripts | Never use user input in scripts |

### Prototype Pollution Prevention

```typescript
// VULNERABLE
function merge(target: any, source: any) {
  for (const key in source) {
    target[key] = source[key];  // Can pollute __proto__
  }
}

// SECURE
function safeMerge<T extends object>(target: T, source: Partial<T>): T {
  for (const key of Object.keys(source) as (keyof T)[]) {
    if (key === '__proto__' || key === 'constructor' || key === 'prototype') {
      continue;
    }
    target[key] = source[key]!;
  }
  return target;
}

// Or use Object.assign with null prototype
const result = Object.assign(Object.create(null), source);
```
