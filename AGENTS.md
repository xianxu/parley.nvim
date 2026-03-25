# Constitution

## Workflow Orchestration

### 1. Plan Mode By Default
- Enter plan mode for ANY non-trivial task (3+ steps, architectural decisions, change more than 2 files, 100 lines)
- Wait for user	approval before implementation for ANY non-trivial task
- If something goes sideways, STOP and re-plan immediately: don’t keep pushing
- Use plan mode for verification steps, not just building
- Work for you is in `tasks/issue.md`, you MUST make plan in `tasks/todo.md`
- Keep specs in specs/*, `tasks/todo.md` up to date during your work
- Plan for manual verification steps if necessary, but automate verification as much as possible, add temporary tracing if needed to verify code path triggered before calling it done
- Leverage trace-driven debugging when your fix had no effect. Produce clear repro steps for user to follow.

### 2. Subagent Strategy
- Use subagents to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- When user needs to involve in manual debugging with you, update `tasks/lessons.md` with the pattern what went wrong in the first place.
- Write rules for yourself that prevent the same mistake
- Review lessons at session start for relevant project

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
- As you update `tasks/todo.md` and code, continuously update corresponding specs in specs/ folder
- Maintain a specs/index.md that links to all spec files with brief descriptions of their contents.
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
- **Design for Testability**: Refactor code to be easily testable. Always write regression tests for bugs.

---

## Repo-Specific References
- **[TOOLING.md](constitution/TOOLING.md)** — development commands, test running, fixture refresh
- **[STYLE.md](constitution/STYLE.md)** — code style and Lua conventions
- **[ARCH.md](constitution/ARCH.md)** — project overview and module architecture
