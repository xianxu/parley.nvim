---
id: 000015
status: open
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# make some part of workflow deterministic
Right now, part of my ai workflow is stitched together with free text should follow, however, LLM being stochastic, will forget things, just like human. We should "lift" some deterministic steps into build scripts (and future CI). The following are the constraints I would want to lift from "constitution" described in AGENTS.md into Makefile.workflow.

I want before merge/push, the following steps to be done. Each step should be guarded by a user prompt, default to Y, but can be skipped if user chooses to. 

1/ did the agent follow DRY and PURE principle. e.g. write small pure and unit-testable functions, with small stub to wire those pure functions to the environment (UI/IO etc.), reuse code as much as possible through refactor. Maybe this are two steps: `make check-dry`, `make check-pure`. 

2/ did the agent update the issues/000000-feature.md with plan, did all steps finish, did they write log. call this `make check-plan`.

3/ did the agent run all tests, this is `make test`, but should be invoked before merge/push. we can call this `make check-test`

4/ did the agent update documentation in specs/ with this change. Did README.md get out of sync? this is `make check-specs`

5/ is there lessons agent should write. Only write important lessons. `make check-lessons`

Each of this steps (`make check-*`) are invocation to coding agent (this should be configurable, default to claude) with dedicated prompt. 

Given we are doing this in 6 different things, we should keep it DRY, and have a table of prompts to use, outcome to expect. one consistent outcome is if this step results in some change in repo state (file changed or untracked file appeared), we should ask user to either accept it (they will manually inspect in another terminal), or discard those and move on. 

Make those steps very clear with coloring in the interaction with user. 

Let's call those pre-merge checks, and instead of asking user's initial confirmation if they want to do this, we should have some way to ask this from get go, and have a way to configure default. e.g. given those 6 questions, maybe user just need to type yyynny, to run 1, 2, 3, 6 but skip 4, 5. Propose something here.

## Done when

-

## Plan

- [ ]

## Log

### 2026-03-29

