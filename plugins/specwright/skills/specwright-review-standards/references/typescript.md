# TypeScript Review Standards

TypeScript-specific code review criteria. Apply alongside universal principles.

---

## Style & Formatting

### ESLint/Prettier Compliance
- Use project's ESLint config consistently
- Prettier for formatting (semicolons, quotes, etc.)
- No `@ts-ignore` without explanation comment

### Type Annotations
- **Explicit return types**: On exported functions
- **Avoid `any`**: Use `unknown` for truly unknown types
- **Prefer interfaces**: For object shapes (extendable)
- **Use type aliases**: For unions, intersections, complex types

```typescript
// Good
interface User {
  id: string;
  email: string;
  name: string;
}

export function getUser(id: string): Promise<User | null> {
  // ...
}

// Avoid
export function getUser(id: any): any {
  // ...
}
```

### Strict Mode
- Enable `strict: true` in tsconfig
- Handle `null`/`undefined` explicitly
- Use optional chaining (`?.`) and nullish coalescing (`??`)

```typescript
// Good
const name = user?.profile?.name ?? 'Anonymous';

// Avoid
const name = user && user.profile && user.profile.name || 'Anonymous';
```

---

## Error Handling

### Error Patterns
- Use typed errors or Result types
- Throw `Error` subclasses, not strings
- Catch at appropriate boundaries

```typescript
// Good
class UserNotFoundError extends Error {
  constructor(public readonly userId: string) {
    super(`User not found: ${userId}`);
    this.name = 'UserNotFoundError';
  }
}

async function getUser(id: string): Promise<User> {
  const user = await repository.find(id);
  if (!user) {
    throw new UserNotFoundError(id);
  }
  return user;
}

// Avoid
async function getUser(id: string): Promise<User> {
  const user = await repository.find(id);
  if (!user) {
    throw 'User not found';  // No type, no context
  }
  return user;
}
```

### Async/Await
- Always `await` in try block, handle in catch
- Use `Promise.all` for concurrent operations
- Handle rejections explicitly

```typescript
// Good
async function fetchAll(urls: string[]): Promise<Response[]> {
  try {
    return await Promise.all(urls.map(url => fetch(url)));
  } catch (error) {
    if (error instanceof TypeError) {
      throw new NetworkError('Failed to fetch', { cause: error });
    }
    throw error;
  }
}
```

---

## Data Structures

### Interfaces vs Types
- **Interface**: Object shapes, can be extended/merged
- **Type**: Unions, intersections, mapped types

```typescript
// Interface for object shapes
interface User {
  id: string;
  email: string;
}

interface AdminUser extends User {
  permissions: string[];
}

// Type for unions/complex types
type Result<T> = { ok: true; value: T } | { ok: false; error: Error };
type UserRole = 'admin' | 'user' | 'guest';
```

### Immutability
- Use `readonly` for properties that shouldn't change
- Use `as const` for literal types
- Consider `Readonly<T>` for immutable objects

```typescript
interface Config {
  readonly apiUrl: string;
  readonly timeout: number;
}

const ROLES = ['admin', 'user', 'guest'] as const;
type Role = typeof ROLES[number];  // 'admin' | 'user' | 'guest'
```

### Enums
- Prefer string unions over enums for most cases
- If using enums, prefer `const enum` for inlining
- Use enums for numeric values that need reverse mapping

```typescript
// Prefer string unions
type Status = 'pending' | 'active' | 'closed';

// Use enum for numeric with reverse lookup
enum HttpStatus {
  OK = 200,
  NotFound = 404,
  ServerError = 500,
}
```

---

## React Patterns (if applicable)

### Component Types
- Use `React.FC` sparingly (or avoid entirely)
- Explicit props interface with children if needed
- Use `React.ReactNode` for children type

```typescript
// Good
interface ButtonProps {
  label: string;
  onClick: () => void;
  children?: React.ReactNode;
}

function Button({ label, onClick, children }: ButtonProps) {
  return <button onClick={onClick}>{children ?? label}</button>;
}
```

### Hooks
- Follow Rules of Hooks (top-level, same order)
- Use `useCallback`/`useMemo` for referential stability
- Custom hooks prefix with `use`

```typescript
function useUser(id: string): { user: User | null; loading: boolean } {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchUser(id).then(setUser).finally(() => setLoading(false));
  }, [id]);

  return { user, loading };
}
```

---

## Testing Patterns

### Jest Conventions
- Test files: `*.test.ts` or `*.spec.ts`
- Describe blocks for grouping
- Clear test names: `it('should return user when id exists')`

```typescript
describe('UserService', () => {
  describe('getUser', () => {
    it('should return user when id exists', async () => {
      const user = await service.getUser('123');
      expect(user).toEqual({ id: '123', email: 'test@example.com' });
    });

    it('should throw UserNotFoundError when id does not exist', async () => {
      await expect(service.getUser('nonexistent'))
        .rejects
        .toThrow(UserNotFoundError);
    });
  });
});
```

### Mocking
- Use `jest.mock()` for modules
- Use `jest.spyOn()` for methods
- Clear mocks in `beforeEach`/`afterEach`

```typescript
jest.mock('./repository');

describe('UserService', () => {
  const mockRepository = repository as jest.Mocked<typeof repository>;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should call repository with correct id', async () => {
    mockRepository.find.mockResolvedValue({ id: '123', email: 'test@example.com' });

    await service.getUser('123');

    expect(mockRepository.find).toHaveBeenCalledWith('123');
  });
});
```

---

## Common Issues

| Issue | Problem | Fix |
|-------|---------|-----|
| `any` overuse | Defeats type safety | Use `unknown`, generics, or proper types |
| Missing `await` | Promise returned but not awaited | Add `await` or return Promise explicitly |
| Type assertion abuse | `as Type` bypasses checking | Use type guards or proper types |
| Callback `this` binding | `this` undefined in callbacks | Use arrow functions or `.bind()` |
| Object mutation | Modifying props/state directly | Use spread operator or immutable patterns |
| Implicit `any` in callbacks | Array methods lose type info | Add explicit parameter types |
