---
id: '000202'
status: done
started: 2026-08-21T22:47:58-07:00
created: 2026-08-20
updated: 2026-08-22
estimate_hours: 1.64
actual_hours: 1.89
---

# make test is unreliable: specs traverse and mutate a shared .test-tmp

## Problem

`make test` fails intermittently on specs that have nothing to do with the
change under test, which makes every SDLC close gate noisier than it should be
and trains agents to dismiss real failures as flakes. Diagnosed during #200,
where it cost two false alarms before being investigated.

Two distinct mechanisms, both rooted in the harness sharing one scratch tree:

1. **`tests/unit/tools_builtin_find_spec.lua` traverses a directory the suite is
   writing.** `Makefile.parley:28` sets `TMPDIR=$(CURDIR)/.test-tmp`, and the
   spec runs the `find` tool over the repo root — which contains `.test-tmp`,
   populated by previous runs and actively mutated by the current one. `find`
   exits nonzero when the tree changes under its traversal, and the spec asserts
   `is_error == false`.

   Evidence: the spec passes 4/4 in isolation (repeatedly), passes under the
   suite's own `TEST_ENV`, and fails under the full suite. It reproduces with all
   #200 changes stashed, so it is not fold-related. `rm -rf .test-tmp .test-home
   .test-xdg` before `make test` gives exit 0.

2. **`tests/integration/chat_progress_process_spec.lua` intermittently gets no
   port.** It binds a local HTTP server; under full-suite contention the bind
   sometimes fails and the spec errors with `attempt to concatenate local 'port'
   (a nil value)`. Passes 7/7 in isolation.

Separately, under the agent sandbox `git_markdown_source_spec` and
`markdown_finder_async_spec` fail because `git init` cannot copy its template
hooks into the sandbox-redirected `TMPDIR`. That one is environmental rather
than a harness defect, but it compounds the same "is this real?" problem.
