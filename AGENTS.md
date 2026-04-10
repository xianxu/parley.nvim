# Constitution

## Workflow Orchestration

### 1. Overall Workflow
- Enter brainstorming mode when requirement is unclear 
- Enter plan mode for ANY non-trivial task (change more than 2 files, 50 lines)
- Work is offered in issues system and tracked in `issues/` folder as single-file-per-issue markdown file 
    - Write overall within the issue file's `## Plan` section
    - Log discoveries, tools you used or installed in the issue file's `## Log`section
    - Write brainstorming result in `## Spec` section
    - Record your progress in the `issues/` file incrementally and often
- For complex work when skills like `superpowers` is used, write detailed designs in `docs/plans/` using similar file name with -plan at the end. 
    - For example, for `issues/000042-an-complex-issue.md`, write design in `docs/plans/000042-an-complex-issue-plan.md`
    - You will discover problems during design stage as you understand more of existing codebase. ALWAYS add tests to test against those unexpected problems
- AVOID READING `history/*` unless explicitly asked to, they are history, low signal
- Wait for user approval before implementation for ANY non-trivial task
- If something goes sideways, STOP and re-plan immediately: don't keep pushing
- Use plan mode for verification steps, not just building
- Keep specs in `specs/*` and the issue's Plan section up to date during your work
- Automate verification steps wherever possible: either by having end to end test; or by adding temporary tracing to mimic manual test
- Failing automated verification, plan for manual verification steps in the issue's Plan section
- Collaborate with user to do trace-driven debugging. Produce clear repro steps for user to follow
- Run commands yourself, don't ask user to

### 2. Artifact Hierarchy
- Simple case, operate in the single file in `issues/`
- Complex case, start in `issues/`, write detailed design in `docs/plans`. Complex case involves thousands of lines in the design file
- In all cases, `specs/` is for big picture pointers, terminologies to facilitate future high level understanding of this codebase
- When done, the artifacts in `issues/` and `docs/plans/` are moved to `history/`

### 3. Subagent Strategy
- Use subagents to keep main context window clean
- Offload research, brainstorming, exploration, and parallel analysis to subagents
- One task per subagent for focused execution
- HOWEVER, **the real axis for "subagent or not" is not "simple vs hairy" — it is "is the context I need to do this task capturable as a prompt?"** Subagents are deliberately context-starved and good for:
  1. **Bounded, well-specified work** — new file with a clear spec, isolated function, TDD cycle with a known signature. Context fits into the prompt cheaply.
  2. **Exploration that would bloat main context** — reading 10 files to summarize a subsystem, grep-and-synthesize, dependency tracing. The subagent loads the raw material into its context and returns a digest, preserving the main session.
  3. **Fresh-eyes review** — code review, plan review, spec review. Main session has confirmation bias from work it just did; fresh eyes are strictly better. Always subagent.
- **Main session wins when the task relies on tacit accumulated context** — modifying a file I just spent ten turns understanding, wiring work that depends on design decisions still warm in this session, iterative debugging where each attempt informs the next, or the cases where user updated their specification as coding discovered previous unknown constraints. Crystallizing that context into a subagent prompt can cost more than just doing the work. 
- **For complex multi-milestone work with a written plan in `docs/plans/*`:** case-by-case judgment per task. Use subagents for tasks matching situations 1-3 above, main session for tasks that depend on session-warm context. Do NOT default to skills like `superpowers:subagent-driven-development` for whole milestones. Do dispatch review subagents at milestone boundaries regardless (see next bullet).
- **Post-milestone code review is MANDATORY** for any multi-milestone plan. Invoke `superpowers:requesting-code-review` → `superpowers:code-reviewer` subagent with `BASE_SHA` = previous milestone close, `HEAD_SHA` = current HEAD. Address Critical and Important findings before starting the next milestone. Log review outcome in the issue's `## Log` section.

### 4. Self-Improvement Loop
- You MUST update `tasks/lessons.md` with the pattern what went wrong when you make mistakes
- Write rules for yourself that prevent the same mistake
- You MUST Review lessons at session start for relevant project. You should also simplify what is in lessons to keep it concise

### 5. Verification Before Done
- NEVER mark a task complete without proving it works
- Diff behavior between main and your changes
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 6. Demand Elegance
- For non-trivial changes: pause and ask "is there a more general and elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- If a change feels repetitive: "How can I refactor to reuse existing code?"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 7. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user

### 8. Maintenance of Specs and Documentation
- As you update issue plans and code, continuously update corresponding specs in `specs/` folder
- Maintain the `specs/index.md` that links to all spec files with brief descriptions of their contents.
- Synthesize what we just built into a reusable spec document. DO NOT over specify — `specs/` is a practical way pointer for future developers to know the sketch of functionalities, history and intention behind them. Details should live in the code

### 9. Pay attention to User Questions
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
