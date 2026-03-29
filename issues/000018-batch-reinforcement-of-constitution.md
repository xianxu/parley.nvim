---
id: 000018
status: open
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# batch reinforcement of constitution

The ideal is describe in `../design/2026-03-29.08-52-09.171.md`, basically we would want to add as claude hooks, to run certain deterministic steps and inject context. Based on the discussion in the design, we want to:

1/ inject post-write (e.g. after agent changed something), that if there are enough changes, we should check if the "constitution" are still intact, by running `make check`. 

2/ actually, instead of running `make check`, we should run steps independently, currently we have 6 targets in make check.

3/ actually, we shouldn't run all concurrently, as they may change same files. here are the groups I think, lines can run concurrently, but within each line, sequentially. 
    1. check-dry, check-pure
    2. check-test
	3. check-specs
    4. check-plan
    5. check-lessons

4/ they should be run in a mode that doesn't auto commit. 

5/ when those all finish, assemble context for the agent. 

6/ is shell script still a good way to run those multi-process scatter/gather pattern? maybe should use typescript, given all the nice cli are build in it it seems? 

7/ such parallel invocation pattern is also beneficial to `make push`, `make merge`. but if we are to do it, there might be multiple progress bars, one for the parallelism.

## Done when

-

## Plan

- [ ]

## Log

### 2026-03-29

