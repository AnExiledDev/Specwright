# TypeScript Error Handling Patterns

TypeScript-specific error handling patterns. Apply alongside universal principles.

---

## Error Class Hierarchy

### Custom Error Classes

```typescript
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(
    message: string,
    public readonly field?: string,
  ) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

export class NotFoundError extends AppError {
  constructor(
    public readonly resource: string,
    public readonly identifier: string,
  ) {
    super(`${resource} not found: ${identifier}`, 'NOT_FOUND', 404);
  }
}

export class DuplicateError extends AppError {
  constructor(
    public readonly resource: string,
    public readonly field: string,
    public readonly value: string,
  ) {
    super(
      `${resource} with ${field}='${value}' already exists`,
      'DUPLICATE',
      409,
    );
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 'UNAUTHORIZED', 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Permission denied') {
    super(message, 'FORBIDDEN', 403);
  }
}
```

### Type Guards for Errors

```typescript
function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}

function isNotFoundError(error: unknown): error is NotFoundError {
  return error instanceof NotFoundError;
}

// Usage
try {
  await getUser(id);
} catch (error) {
  if (isNotFoundError(error)) {
    return null;
  }
  throw error;
}
```

---

## Try-Catch Patterns

### Basic Error Handling

```typescript
async function getUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);

    if (!response.ok) {
      if (response.status === 404) {
        throw new NotFoundError('User', id);
      }
      throw new AppError(`API error: ${response.statusText}`, 'API_ERROR');
    }

    return await response.json();
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    throw new AppError(`Failed to fetch user: ${error}`, 'FETCH_ERROR');
  }
}
```

### Handling Multiple Error Types

```typescript
async function createUser(data: UserInput): Promise<User> {
  try {
    return await repository.create(data);
  } catch (error) {
    if (error instanceof DuplicateError) {
      // Expected error - let it propagate
      throw error;
    }
    if (error instanceof ValidationError) {
      // Expected error - let it propagate
      throw error;
    }
    // Unexpected error - wrap with context
    throw new AppError(
      `Failed to create user: ${error instanceof Error ? error.message : error}`,
      'CREATE_USER_ERROR',
    );
  }
}
```

---

## Result Type Pattern

### Result Type Definition

```typescript
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

// Helper functions
function Ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

function Err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}

// Usage
function parseJson<T>(json: string): Result<T, SyntaxError> {
  try {
    return Ok(JSON.parse(json));
  } catch (error) {
    return Err(error as SyntaxError);
  }
}

const result = parseJson<User>('{"id": "1"}');
if (result.ok) {
  console.log(result.value.id);
} else {
  console.error(result.error.message);
}
```

### Async Result

```typescript
type AsyncResult<T, E = Error> = Promise<Result<T, E>>;

async function fetchUser(id: string): AsyncResult<User, NotFoundError> {
  try {
    const user = await repository.findById(id);
    if (!user) {
      return Err(new NotFoundError('User', id));
    }
    return Ok(user);
  } catch (error) {
    return Err(error as NotFoundError);
  }
}

// Usage
const result = await fetchUser('123');
if (!result.ok) {
  // Handle error without throwing
  return notFoundResponse(result.error);
}
const user = result.value;
```

---

## Promise Error Handling

### Promise Chain Error Handling

```typescript
function processOrder(orderId: string): Promise<Receipt> {
  return getOrder(orderId)
    .then(validateOrder)
    .then(processPayment)
    .then(generateReceipt)
    .catch((error) => {
      if (error instanceof ValidationError) {
        throw error; // Let validation errors propagate
      }
      logger.error('Order processing failed', { orderId, error });
      throw new AppError(`Order processing failed: ${orderId}`, 'ORDER_ERROR');
    });
}
```

### Promise.all with Error Handling

```typescript
async function fetchAllUsers(ids: string[]): Promise<(User | null)[]> {
  const results = await Promise.allSettled(ids.map((id) => getUser(id)));

  return results.map((result, index) => {
    if (result.status === 'fulfilled') {
      return result.value;
    }
    logger.warn('Failed to fetch user', {
      id: ids[index],
      error: result.reason,
    });
    return null;
  });
}
```

### Retry with Promises

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  options: {
    maxAttempts?: number;
    backoffMs?: number;
    retryOn?: (error: unknown) => boolean;
  } = {},
): Promise<T> {
  const { maxAttempts = 3, backoffMs = 100, retryOn = () => true } = options;

  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (attempt === maxAttempts || !retryOn(error)) {
        throw error;
      }

      const delay = backoffMs * Math.pow(2, attempt - 1);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// Usage
const user = await withRetry(() => fetchUser(id), {
  maxAttempts: 3,
  retryOn: (error) => error instanceof NetworkError,
});
```

---

## Express Error Handling

### Error Middleware

```typescript
import { Request, Response, NextFunction } from 'express';

// Error handler middleware (must have 4 parameters)
export function errorHandler(
  error: Error,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  // Log unexpected errors
  if (!(error instanceof AppError)) {
    logger.error('Unexpected error', {
      error: error.message,
      stack: error.stack,
      path: req.path,
      method: req.method,
    });
  }

  // Send appropriate response
  if (error instanceof AppError) {
    res.status(error.statusCode).json({
      error: {
        code: error.code,
        message: error.message,
      },
    });
    return;
  }

  // Generic error response for unexpected errors
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  });
}

// Async wrapper to catch errors
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Usage
app.get(
  '/users/:id',
  asyncHandler(async (req, res) => {
    const user = await getUser(req.params.id);
    res.json(user);
  }),
);

app.use(errorHandler);
```

### Route-Level Error Handling

```typescript
app.get(
  '/users/:id',
  asyncHandler(async (req, res) => {
    try {
      const user = await getUser(req.params.id);
      res.json(user);
    } catch (error) {
      if (error instanceof NotFoundError) {
        res.status(404).json({
          error: { code: 'NOT_FOUND', message: error.message },
        });
        return;
      }
      throw error; // Let middleware handle
    }
  }),
);
```

---

## Logging Patterns

### Structured Logging

```typescript
import pino from 'pino';

const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
});

function createChildLogger(context: Record<string, unknown>) {
  return logger.child(context);
}

// Usage in service
class UserService {
  private log = createChildLogger({ service: 'UserService' });

  async createUser(email: string): Promise<User> {
    const log = this.log.child({ email, action: 'createUser' });
    log.info('Creating user');

    try {
      const user = await this.repository.create({ email });
      log.info({ userId: user.id }, 'User created');
      return user;
    } catch (error) {
      if (error instanceof DuplicateError) {
        log.warn('Duplicate email');
        throw error;
      }
      log.error({ error }, 'Failed to create user');
      throw error;
    }
  }
}
```

### Request Context Logging

```typescript
import { AsyncLocalStorage } from 'async_hooks';

interface RequestContext {
  requestId: string;
  userId?: string;
}

const contextStorage = new AsyncLocalStorage<RequestContext>();

// Middleware to set context
app.use((req, res, next) => {
  const context: RequestContext = {
    requestId: req.headers['x-request-id'] as string ?? crypto.randomUUID(),
    userId: req.user?.id,
  };

  contextStorage.run(context, () => {
    next();
  });
});

// Logger that includes context
function log(level: string, message: string, data?: Record<string, unknown>) {
  const context = contextStorage.getStore();
  logger[level]({
    ...context,
    ...data,
    message,
  });
}
```

---

## Validation Patterns

### Zod with Error Handling

```typescript
import { z } from 'zod';

const UserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
});

function validateUser(data: unknown): User {
  const result = UserSchema.safeParse(data);

  if (!result.success) {
    const firstError = result.error.errors[0];
    throw new ValidationError(firstError.message, firstError.path.join('.'));
  }

  return result.data;
}
```

### Class Validator

```typescript
import { validate, IsEmail, Length } from 'class-validator';
import { plainToInstance } from 'class-transformer';

class CreateUserDto {
  @IsEmail()
  email: string;

  @Length(1, 100)
  name: string;
}

async function validateDto<T extends object>(
  cls: new () => T,
  data: unknown,
): Promise<T> {
  const instance = plainToInstance(cls, data);
  const errors = await validate(instance);

  if (errors.length > 0) {
    const firstError = errors[0];
    const message = Object.values(firstError.constraints ?? {})[0];
    throw new ValidationError(message, firstError.property);
  }

  return instance;
}
```

---

## Common Patterns

### Guard Clauses

```typescript
function processOrder(order: Order | null, user: User | null): Receipt {
  // Guard clauses - fail fast
  if (!order) {
    throw new ValidationError('Order is required');
  }
  if (!user) {
    throw new ValidationError('User is required');
  }
  if (order.status !== 'pending') {
    throw new ValidationError(`Order must be pending, got: ${order.status}`);
  }
  if (!user.canPurchase()) {
    throw new ForbiddenError('User cannot make purchases');
  }

  // Main logic - no nesting
  return paymentService.process(order, user);
}
```

### Exhaustive Error Checking

```typescript
type OrderStatus = 'pending' | 'processing' | 'completed' | 'cancelled';

function getStatusMessage(status: OrderStatus): string {
  switch (status) {
    case 'pending':
      return 'Order is waiting to be processed';
    case 'processing':
      return 'Order is being processed';
    case 'completed':
      return 'Order has been completed';
    case 'cancelled':
      return 'Order was cancelled';
    default:
      // TypeScript ensures this is never reached if all cases handled
      const exhaustiveCheck: never = status;
      throw new Error(`Unhandled status: ${exhaustiveCheck}`);
  }
}
```

### Optional Chaining with Errors

```typescript
interface Config {
  database?: {
    host?: string;
    port?: number;
  };
}

function getDatabaseUrl(config: Config): string {
  const host = config.database?.host;
  const port = config.database?.port;

  if (!host) {
    throw new ValidationError('Database host is required', 'database.host');
  }
  if (!port) {
    throw new ValidationError('Database port is required', 'database.port');
  }

  return `postgresql://${host}:${port}`;
}
```
