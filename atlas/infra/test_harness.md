# Test Harness

How `make test` runs, and the one invariant it defends.

## Shape

- `make test` = `test-clean-env` -> `lint` -> `test-unit` -> `test-integration`,
  chained through recursive `$(MAKE)` so `make -j` cannot reorder the wipe into
  a running suite.
- `test-unit` and `test-integration` fan out with `xargs -P $(JOBS)` (default 8),
  one headless Neovim process per spec file; `RUN_SPEC` captures each file's
  output and appends failures to `$FAILED_LOG` for an authoritative summary.
- `tests/unit/` = pure logic, `tests/integration/` = full runtime,
  `tests/arch/` = fitness functions, `tests/helpers/` = shared spec helpers
  (not collected — the runners glob `*_spec.lua`).

## Scratch placement is the determinism invariant

The harness hands every run its own `HOME`, `XDG_*`, and `TMPDIR` under

```
$TMPDIR/parley-test-env/<checkout>-<cksum-of-path>/{home,xdg,tmp}
```

keyed by checkout so worktrees don't share, overridable via `TEST_ENV_ROOT`.

**That root is outside `$(CURDIR)` on purpose (#202).** Eight parallel jobs
churn the scratch tmp dir all run long, while the `find`/`grep`/`ack` tool specs
traverse the repo to exercise the real tree — and `grep`'s "defaults missing
path to cwd" case cannot be written any other way. With scratch in `.test-tmp/`
those specs raced a directory vanishing mid-traversal, `find` exited nonzero,
and the suite read as randomly flaky. Placement enforces the invariant, so no
spec has to defend itself and no lint has to police traversal roots. `nvim`'s
`directory` (swap) follows `$TMPDIR` for the same reason
(`tests/minimal_init.vim`).

Corollary worth keeping: a full `make test` mutates nothing inside the repo
working tree. That is checkable — snapshot `find . -path ./.git -prune -o -print`
with mtimes before and after, and diff.

## Fixture readiness

Spawned fixtures that bind port 0 publish the port through a file. Two rules,
because a reader cannot tell partial digits from complete ones:

- Publisher writes to a sibling path and renames onto the ready path
  (`tests/fixtures/fake_sse_server`). Existence must imply completeness.
- Consumer waits for a *parseable* port, never for mere existence
  (`tests/helpers/ready_port.lua`), so an incomplete signal is a named timeout
  instead of a nil concatenated into a URL.

## Related

- [Linting](linting.md) — `make lint`, which `make test` runs first.
- `TOOLING.md` — the developer-facing command list and perf report.
