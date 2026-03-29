# Constitution

## Workflow Orchestration

### 1. Overall
- Enter plan mode for ANY non-trivial task (3+ steps, architectural decisions, change more than 2 files, 50 lines)
- Work is tracked in `issues/` folder as single-file-per-issue markdown
- Plan within the issue file's `## Plan` section (checklist), log discoveries, tools you used or installed in `## Log`
- IGNORE `history/*` — they are archived completed issues
- Wait for user approval before implementation for ANY non-trivial task
- If something goes sideways, STOP and re-plan immediately: don't keep pushing
- Use plan mode for verification steps, not just building
- Keep specs in `specs/*` and the issue's Plan section up to date during your work
- Automate verification steps wherever possible: either by having end to end test; or by adding temporary tracing to mimic manual test
- Failing automated verification, plan for manual verification steps in the issue's Plan section
- Leverage trace-driven debugging when your fix had no effect. Produce clear repro steps for user to follow.

### 2. Subagent Strategy
- Use subagents to keep main context window clean
- Offload research, brainstorming, exploration, and parallel analysis to subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- You MUST update `tasks/lessons.md` with the pattern what went wrong when you make mistakes
- Write rules for yourself that prevent the same mistake
- You MUST Review lessons at session start for relevant project

### 4. Verification Before Done
- NEVER mark a task complete without proving it works
- Diff behavior between main and your changes
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance
- For non-trivial changes: pause and ask "is there a more general and elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- If a change feels repetitive: "How can I refactor to reuse existing code?"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user

### 7. Maintenance of Specs and Documentation
- As you update issue plans and code, continuously update corresponding specs in `specs/` folder
- Maintain the `specs/index.md` that links to all spec files with brief descriptions of their contents.
- Synthesize what we just built into a reusable spec document. DO NOT over specify — `specs/` is a practical way pointer for future developers to know the sketch of functionalities, history and intention behind them. Details should live in the code

### 8. Pay attention to User Questions
- When user poses question, answer the question as clearly and directly as possible
- DO NOT proceed to change code, when user asks a question

## Task Management
1. **Note starting point**: save current state before making changes (e.g. git commit or branch)
2. **Plan First**: Write plan in the issue file's `## Plan` section with checkable items
3. **Update Spec**: Reflect changes in `specs/` files as you go, not after the fact
4. **Verify Plan**: Check in before starting implementation
5. **Track Progress**: Mark plan items complete as you go
6. **Explain Changes**: High-level summary at each step
7. **Document Results**: Add review notes in the issue's `## Log` section
8. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Design Principles
- **Keep It DRY**: Don't Repeat Yourself. Refactor to reuse existing code when possible.
- **Keep It PURE**: Write majority code as pure functions, then with limited code to integrate with UI and IO.
- **Simplicity First**: Make every change as simple as possible. Minimal impact.
- **Find Root Cause**: Find root causes. No temporary fixes, lazy null checks. Senior developer standards.
- **Minimize Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

---

## Repo-Specific References
- **[TOOLING.md](TOOLING.md)** — development commands, test running, fixture refresh
- **[STYLE.md](STYLE.md)** — code style and Lua conventions
- **[ARCH.md](ARCH.md)** — project overview and module architecture
