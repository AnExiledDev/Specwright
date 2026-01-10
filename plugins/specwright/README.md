# Specwright Plugin

Spec-driven development automation with phased implementation, parallel execution, and verification loops.

## Commands

| Command | Description |
|---------|-------------|
| `/define` | Create a new ticket with specification from description |
| `/design` | Generate implementation plan from specification |
| `/build` | Execute the implementation plan for a ticket |
| `/resume` | Resume in-progress work on a ticket (token-efficient) |
| `/revise` | Revise an existing ticket specification |
| `/status` | Check progress status for a ticket (read-only) |

## Workflow

1. **Define** - Create ticket specification from requirements
2. **Design** - Generate phased implementation plan with tasks
3. **Build** - Execute plan with parallel agents, verification loops, and fix iterations

## Agents

- `implementation` - Writes production code from task specs
- `test` - Writes tests from task specs (runs in parallel with implementation)
- `review` - Analyzes verification failures and produces fix instructions
- `fix` - Applies fixes based on review instructions
- `verification` - Runs lint, type check, and tests
- `indexing` - Builds symbol index for token-efficient context
- `status` - Updates task and phase status files

## Skills

- `specwright-error-handling` - Error handling patterns
- `specwright-test-patterns` - Test generation patterns
- `specwright-review-standards` - Code review standards
- `specwright-security-review` - Security vulnerability checklist
