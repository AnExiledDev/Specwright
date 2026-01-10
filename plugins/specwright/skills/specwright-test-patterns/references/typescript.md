# TypeScript Test Patterns

TypeScript-specific testing patterns using Jest. Apply alongside universal principles.

---

## Jest Fundamentals

### Test Discovery

Jest finds tests automatically:

- Files: `*.test.ts`, `*.spec.ts`, `__tests__/*.ts`
- Functions: `test()` or `it()`
- Suites: `describe()`

### Basic Test Structure

```typescript
describe('UserRepository', () => {
  describe('create', () => {
    it('should return user with generated id', async () => {
      // Arrange
      const userData = { email: 'test@example.com', name: 'Test User' };
      const repository = new UserRepository();

      // Act
      const user = await repository.create(userData);

      // Assert
      expect(user.id).toBeDefined();
      expect(user.email).toBe('test@example.com');
    });
  });
});
```

---

## Setup and Teardown

### Lifecycle Hooks

```typescript
describe('UserService', () => {
  let service: UserService;
  let mockRepository: jest.Mocked<UserRepository>;

  beforeAll(() => {
    // Run once before all tests in this describe
  });

  beforeEach(() => {
    // Run before each test
    mockRepository = createMockRepository();
    service = new UserService(mockRepository);
  });

  afterEach(() => {
    // Run after each test
    jest.clearAllMocks();
  });

  afterAll(() => {
    // Run once after all tests
  });
});
```

### Factory Functions

```typescript
function createTestUser(overrides: Partial<User> = {}): User {
  return {
    id: '123',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: new Date('2025-01-01'),
    ...overrides,
  };
}

it('should update user email', async () => {
  const user = createTestUser({ email: 'old@example.com' });
  // ...
});
```

---

## Assertions (Expect)

### Common Matchers

```typescript
// Equality
expect(result).toBe(expected);           // Strict equality (===)
expect(result).toEqual(expected);        // Deep equality
expect(result).toStrictEqual(expected);  // Deep equality + type

// Truthiness
expect(result).toBeTruthy();
expect(result).toBeFalsy();
expect(result).toBeNull();
expect(result).toBeUndefined();
expect(result).toBeDefined();

// Numbers
expect(value).toBeGreaterThan(3);
expect(value).toBeLessThanOrEqual(10);
expect(value).toBeCloseTo(0.3, 5);  // Floating point

// Strings
expect(str).toMatch(/pattern/);
expect(str).toContain('substring');

// Arrays
expect(array).toContain(item);
expect(array).toHaveLength(3);
expect(array).toContainEqual({ id: '1' });

// Objects
expect(obj).toHaveProperty('key');
expect(obj).toHaveProperty('nested.key', 'value');
expect(obj).toMatchObject({ id: '1' });  // Partial match
```

### Exception Testing

```typescript
// Sync
expect(() => {
  throwingFunction();
}).toThrow();

expect(() => {
  throwingFunction();
}).toThrow(ValidationError);

expect(() => {
  throwingFunction();
}).toThrow('specific message');

// Async
await expect(asyncThrowingFunction()).rejects.toThrow(NotFoundError);

await expect(asyncThrowingFunction()).rejects.toMatchObject({
  message: 'User not found',
  code: 'NOT_FOUND',
});
```

### Snapshot Testing

```typescript
it('should match snapshot', () => {
  const user = createTestUser();
  expect(user).toMatchSnapshot();
});

it('should match inline snapshot', () => {
  const user = createTestUser();
  expect(user).toMatchInlineSnapshot(`
    Object {
      "email": "test@example.com",
      "id": "123",
      "name": "Test User",
    }
  `);
});
```

---

## Mocking

### Mock Functions

```typescript
// Create mock function
const mockFn = jest.fn();
const mockFnWithReturn = jest.fn().mockReturnValue('result');
const mockFnAsync = jest.fn().mockResolvedValue('async result');

// Verify calls
expect(mockFn).toHaveBeenCalled();
expect(mockFn).toHaveBeenCalledTimes(2);
expect(mockFn).toHaveBeenCalledWith('arg1', 'arg2');
expect(mockFn).toHaveBeenLastCalledWith('lastArg');
```

### Mock Implementations

```typescript
const mockFn = jest.fn()
  .mockReturnValueOnce('first')
  .mockReturnValueOnce('second')
  .mockReturnValue('default');

// Or with implementation
const mockFn = jest.fn((x: number) => x * 2);
```

### Mocking Modules

```typescript
// Mock entire module
jest.mock('./userRepository');

import { UserRepository } from './userRepository';
const MockedRepository = UserRepository as jest.MockedClass<typeof UserRepository>;

beforeEach(() => {
  MockedRepository.mockClear();
});

it('should use mocked repository', () => {
  const instance = new MockedRepository();
  instance.find.mockResolvedValue({ id: '123', email: 'test@example.com' });
  // ...
});
```

### Partial Mocks

```typescript
jest.mock('./utils', () => ({
  ...jest.requireActual('./utils'),
  specificFunction: jest.fn().mockReturnValue('mocked'),
}));
```

### Spy on Methods

```typescript
const spy = jest.spyOn(object, 'method');
spy.mockReturnValue('mocked');

// After test
spy.mockRestore();
```

---

## Async Testing

### Async/Await

```typescript
it('should fetch user', async () => {
  const user = await userService.getUser('123');
  expect(user.id).toBe('123');
});
```

### Promise Matchers

```typescript
it('should resolve with user', async () => {
  await expect(userService.getUser('123')).resolves.toEqual({
    id: '123',
    email: 'test@example.com',
  });
});

it('should reject with error', async () => {
  await expect(userService.getUser('invalid')).rejects.toThrow('Not found');
});
```

### Timers

```typescript
beforeEach(() => {
  jest.useFakeTimers();
});

afterEach(() => {
  jest.useRealTimers();
});

it('should call callback after delay', () => {
  const callback = jest.fn();
  scheduleCallback(callback, 1000);

  expect(callback).not.toHaveBeenCalled();

  jest.advanceTimersByTime(1000);

  expect(callback).toHaveBeenCalled();
});
```

---

## Type-Safe Mocking

### Typed Mock Objects

```typescript
function createMockRepository(): jest.Mocked<UserRepository> {
  return {
    find: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  };
}

it('should call repository with correct arguments', async () => {
  const mockRepo = createMockRepository();
  mockRepo.find.mockResolvedValue({ id: '123', email: 'test@example.com' });

  const service = new UserService(mockRepo);
  await service.getUser('123');

  expect(mockRepo.find).toHaveBeenCalledWith('123');
});
```

### Utility Type for Mocks

```typescript
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

function createMockUser(overrides: DeepPartial<User> = {}): User {
  return {
    id: '123',
    email: 'test@example.com',
    name: 'Test User',
    profile: {
      avatar: null,
      bio: '',
    },
    ...overrides,
    profile: {
      avatar: null,
      bio: '',
      ...overrides.profile,
    },
  };
}
```

---

## React Testing (if applicable)

### React Testing Library

```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

describe('UserProfile', () => {
  it('should display user name', () => {
    render(<UserProfile user={createTestUser()} />);

    expect(screen.getByText('Test User')).toBeInTheDocument();
  });

  it('should call onEdit when button clicked', async () => {
    const onEdit = jest.fn();
    render(<UserProfile user={createTestUser()} onEdit={onEdit} />);

    fireEvent.click(screen.getByRole('button', { name: /edit/i }));

    expect(onEdit).toHaveBeenCalled();
  });

  it('should show loading state', async () => {
    render(<UserProfile userId="123" />);

    expect(screen.getByText(/loading/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
    });
  });
});
```

### Testing Hooks

```typescript
import { renderHook, act } from '@testing-library/react';

describe('useCounter', () => {
  it('should increment counter', () => {
    const { result } = renderHook(() => useCounter());

    act(() => {
      result.current.increment();
    });

    expect(result.current.count).toBe(1);
  });
});
```

---

## Common Patterns

### API Testing

```typescript
import request from 'supertest';
import { app } from './app';

describe('POST /users', () => {
  it('should create user and return 201', async () => {
    const response = await request(app)
      .post('/users')
      .send({ email: 'test@example.com', name: 'Test User' })
      .expect(201);

    expect(response.body).toMatchObject({
      email: 'test@example.com',
      name: 'Test User',
    });
    expect(response.body.id).toBeDefined();
  });

  it('should return 400 for invalid email', async () => {
    const response = await request(app)
      .post('/users')
      .send({ email: 'invalid', name: 'Test User' })
      .expect(400);

    expect(response.body.error).toContain('email');
  });
});
```

### Database Testing

```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

beforeEach(async () => {
  await prisma.user.deleteMany();
});

afterAll(async () => {
  await prisma.$disconnect();
});

it('should persist user to database', async () => {
  const repository = new UserRepository(prisma);

  await repository.create({ email: 'test@example.com', name: 'Test' });

  const users = await prisma.user.findMany();
  expect(users).toHaveLength(1);
  expect(users[0].email).toBe('test@example.com');
});
```

### Date/Time Testing

```typescript
beforeEach(() => {
  jest.useFakeTimers();
  jest.setSystemTime(new Date('2025-01-15T12:00:00Z'));
});

afterEach(() => {
  jest.useRealTimers();
});

it('should set expiration to 1 hour from now', () => {
  const token = createToken({ expiresIn: '1h' });

  expect(token.expiresAt).toEqual(new Date('2025-01-15T13:00:00Z'));
});
```
