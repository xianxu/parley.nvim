---
id: 000202
status: working
deps: []
github_issue:
created: 2026-08-20
updated: 2026-08-21
estimate_hours:
started: 2026-08-21T22:47:58-07:00
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

## Spec

- `make test` is deterministic from a dirty working tree: two consecutive runs
  with no source change produce the same result.
- No spec's assertions depend on the contents of a directory another spec may be
  writing during the same run.
- If a scratch dir must be shared, the harness cleans it before the run rather
  than leaving each spec to cope.

## Done when

- [ ] `tools_builtin_find_spec` no longer scans harness scratch dirs (scope the
      `find` to a fixture tree, or exclude `.test-*`).
- [ ] `chat_progress_process_spec` either retries its bind or is given a port it
      does not have to race for.
- [ ] `make test` cleans `.test-tmp`/`.test-home`/`.test-xdg` before running, or
      the specs are made independent of their contents.
- [ ] Ten consecutive `make test` runs on an unchanged tree all agree.

## Plan

- [ ] Reproduce each mechanism with a minimal case
- [ ] Fix the `find` spec's traversal scope
- [ ] Fix or bound the port race
- [ ] Add the scratch-dir clean to the harness
- [ ] Run the suite ten times to confirm determinism

## Log

### 2026-08-20

Filed from #200's M1 boundary review, which noted the diagnosis would otherwise
be archived with that issue and lost. Full evidence in #200's `## Log` entries
for rounds 6 and 8.
