# Constitution

## Workflow Orchestration

### 1. Overall
- Enter plan mode for ANY non-trivial task (3+ steps, architectural decisions, change more than 2 files, 50 lines)
- Work for you is in `tasks/issue.md`, you MUST make plan in `tasks/todo.md`
- IGNORE history/*`, they are for history records only
- Wait for user	approval before implementation for ANY non-trivial task
- If something goes sideways, STOP and re-plan immediately: don’t keep pushing
- Use plan mode for verification steps, not just building
- Keep specs in `specs/*` and `tasks/todo.md` up to date during your work
- Automate verification steps wherever possible: either by having end to end test; or by adding temporary tracing to mimic manual test
- Failing automated verification, plan for manual verification steps in `tasks/todo.md`
- Leverage trace-driven debugging when your fix had no effect, then produce clear repro steps for user to follow.

### 2. Subagent Strategy
- Use subagents to keep main context window clean
- Offload research, brainstorming, exploration, and parallel analysis to subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- You MUST update `tasks/lessons.md` with the pattern what went wrong when you make mistakes
- Write rules for yourself that prevent the same mistake
- You MUST Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: “Would a staff engineer approve this?”
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance
- For non-trivial changes: pause and ask “is there a more general and elegant way?”
- If a fix feels hacky: “Knowing everything I know now, implement the elegant solution”
- If a change feels repetitive: “How can I refactor to reuse existing code?”
- Skip this for simple, obvious fixes - don’t over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don’t ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user

### 7. Maintenance of Specs and Documentation
- As you update `tasks/todo.md` and code, continuously update corresponding specs in `specs/` folder
- Maintain the `specs/index.md` that links to all spec files with brief descriptions of their contents.
- Synthesize what we just built into a reusable spec document. DO NOT over specify — `specs/` is a practical way pointer for future developers to know the sketch of functionalities, history and intention behind them. Details should live in the cod

### 8. Pay attention to User Questions
- When user poses question, answer the question as clearly and directly as possible
- DO NOT proceed to change code, when user asks a question

## Task Management
1. **Note starting point**: save current state before making changes (e.g. git commit or branch)
2. **Plan First**: Write plan to `tasks/todo.md` with checkable items
3. **Update Spec**: Reflect	changes in `specs/` files as you go, not after the fact
4. **Verify Plan**: Check in before starting implementation
5. **Track Progress**: Mark items complete as you go
6. **Explain Changes**: High-level summary at each step
7. **Document Results**: Add review section to `tasks/todo.md`
8. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Minimal impact.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what’s necessary. Avoid introducing bugs.
- **Keep It DRY**: Don’t Repeat Yourself. Refactor to reuse existing code when possible.
- **Design for Testability**: Refactor code to be easily testable. This means to write pure functions for business logic that testable in unit tests, then some integration code to connect to UI and IO. Always write regression tests for bugs.

---

## Repo-Specific References
- **[TOOLING.md](TOOLING.md)** — development commands, test running, fixture refresh
- **[STYLE.md](STYLE.md)** — code style and Lua conventions
- **[ARCH.md](ARCH.md)** — project overview and module architecture
