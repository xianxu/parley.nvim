# Constitution

## Workflow Orchestration

### 0. Synchronization
- You should update issue status to working, commit, and push to origin, before
  commencing work. You can use `make issue-sync` to do it.
- This is the locking mechanism for parallelized workstreams.

### 1. Artifact Hierarchy
- Simple case, operate in the single file in `workshop/issues/`
- Complex case, start in `workshop/issues/`, write detailed design in `workshop/plans/`
- In all cases, `atlas/` is for big picture pointers, terminologies to facilitate future high level understanding of this codebase. It is your first level onboarding material for human and agents
- When done, the artifacts in `workshop/issues/` and `workshop/plans/` are moved to `workshop/history/`
- `workshop/parley` contains parley chats related to this repo, think them as brainstorming
- `docs/vision` - visionary notes about this repo. In particular -pensive- are less well structured notes, in a similar vein to `workshop/parley` but more focused on a topic

### 2. Overall Workflow
- Enter brainstorming mode when requirement is unclear
- Enter plan mode for ANY non-trivial task (change more than 3 files, 100 lines)
- Work is offered in issues system and tracked in `workshop/issues/` folder as single-file-per-issue markdown file, and each issue file has the following structure:
    - It may refer to file in `workshop/parley`, parley chats, they serve as a starting point of product exploration between user and AI
	- Brainstorming agent SHOULD use parley chat as a starting point when available
    - Brainstorming result SHOULD be written to `## Spec` section of the issue file
    - Steps and plans SHOULD be written to `## Plan` section of the issue file
    - Log discoveries, tools you used or installed in `## Log`section of the issue file
    - Update your progress in the issue file incrementally and often
	- An issue has status: open, working, blocked, done, wontfix, punt
- For complex work when skills like `superpowers` is used, write detailed designs in `workshop/plans/` using similar file name with -plan at the end.
    - For example, for `workshop/issues/000042-slug.md`, write design in `workshop/plans/000042-slug-plan.md`
- You will discover problems during design stage as you understand more of existing codebase. ALWAYS add tests to test against those unexpected problems
- AVOID READING `workshop/history/*` unless explicitly asked to, they are history, low signal
- Wait for user approval before implementation for ANY non-trivial task
- If something goes sideways, STOP and re-plan immediately: don't keep pushing
- Use plan mode for verification steps, not just building
- Keep high level specs in `atlas/` updated 
- Automate verification steps wherever possible: either by having end to end test; or by adding temporary tracing to mimic manual test
- Failing automated verification, plan for manual verification steps in the issue's Plan section
- Collaborate with user to do trace-driven debugging. Produce clear repro steps for user to follow
- Run commands yourself, don't ask user to

### 3. Subagent Strategy
- Use subagents to keep main context window clean
- Offload research, brainstorming, exploration, and parallel analysis to subagents
- One task per subagent for focused execution
- HOWEVER, **the real axis for "subagent or not" is not "simple vs hairy" — it is "is the context I need to do this task capturable as a prompt?"** Subagents are deliberately context-starved and good for:
  1. **Bounded, well-specified work** — new file with a clear spec, isolated function, TDD cycle with a known signature. Context fits into the prompt cheaply.
  2. **Exploration that would bloat main context** — reading 10 files to summarize a subsystem, grep-and-synthesize, dependency tracing. The subagent loads the raw material into its context and returns a digest, preserving the main session.
  3. **Fresh-eyes review** — code review, plan review, spec review. Main session has confirmation bias from work it just did; fresh eyes are strictly better. Always subagent.
- **Main session wins when the task relies on tacit accumulated context** — modifying a file I just spent ten turns understanding, wiring work that depends on design decisions still warm in this session, iterative debugging where each attempt informs the next, or the cases where user updated their specification as coding discovered previous unknown constraints. Crystallizing that context into a subagent prompt can cost more than just doing the work.
- **For complex multi-milestone work with a written plan in `workshop/plans/*`:** case-by-case judgment per task. Use subagents for tasks matching situations 1-3 above, main session for tasks that depend on session-warm context. Do NOT default to skills like `superpowers:subagent-driven-development` for whole milestones. Do dispatch review subagents at milestone boundaries regardless (see next bullet).
- **Post-milestone code review is MANDATORY** for any multi-milestone plan. Invoke `superpowers:requesting-code-review` → `superpowers:code-reviewer` subagent with `BASE_SHA` = previous milestone close, `HEAD_SHA` = current HEAD. Address Critical and Important findings before starting the next milestone. Log review outcome in the issue's `## Log` section.

### 4. Self-Improvement Loop
- You MUST update `workshop/lessons.md` with the pattern what went wrong when you make mistakes
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

### 8. Maintenance of Atlas
- As you update issue plans and code, continuously update corresponding atlas entries in `atlas/` folder
- Maintain the `atlas/index.md` that links to all atlas files with brief descriptions of their contents.
- Synthesize what we just built into a reusable atlas document. DO NOT over specify — `atlas/` is a practical map for future developers to know the sketch of functionalities, history and intention behind them. Details should live in the code

### 9. Pay attention to User Questions
- When user poses question, answer the question as clearly and directly as possible
- DO NOT proceed to change code, when user asks a question

### 10. Complex Workflows around Tool Call
- Use Web Search tool when you need to
- When a workflow is complex, or need to process a lot of data, work with users to create scripts fetch and process data, instead of processing them directly through you.
- Start with limited data for testing.
- Work with user to create scripts and leverage less expensive LLMs, and local models to do the heavy lifting.
- When generating scripts, you should generate a SKILL.md on the same folder, explaining how to use it. Keep SKILL.md updated for all the scripts you create.

### 11. SKILL.md
- Follow standard in https://agentskills.io/home, generally speaking. Agent skill is a way to modularize and harmonize agent prompting and deterministic code
- Treat any folder with SKILL.md as Agent Skills, regardless where they are

## Task Management
1. **Note starting point**: save current state before making changes (e.g. git commit or branch)
2. **Plan First**: Write plan in the issue file's `## Plan` section with checkable items
3. **Update Atlas**: Reflect changes in `atlas/` files as you go, not after the fact
4. **Verify Plan**: Check in before starting implementation
5. **Track Progress**: Mark plan items complete as you go
6. **Explain Changes**: High-level summary at each step
7. **Document Results**: Add review notes in the issue's `## Log` section
8. **Capture Lessons**: Update `workshop/lessons.md` after corrections

## Core Design Principles
- **Keep It DRY**: Don't Repeat Yourself. Refactor to reuse existing code when possible.
- **Keep It PURE**: Write majority code as pure functions, then with limited code to integrate with UI and IO.
- **Simplicity First**: Make every change as simple as possible. Minimal impact. You should be able to explain in one sentence why a thing is needed before creating it.
- **Find Root Cause**: Find root causes. No temporary fixes, lazy null checks. Senior developer standards.
- **Minimize Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

---

## Directory Structure
- `atlas/` — map of the codebase: feature sketches, terminologies, pointers (always current)
- `workshop/` — where building happens:
  - `workshop/history/` — archived completed work
  - `workshop/issues/` — active work items
  - `workshop/lessons.md` — patterns of what went wrong, rules to prevent repeating
  - `workshop/parley/` — parley chat, typically product exploration
  - `workshop/plans/` — detailed designs (high churn, staging area)

@AGENTS.local.md

