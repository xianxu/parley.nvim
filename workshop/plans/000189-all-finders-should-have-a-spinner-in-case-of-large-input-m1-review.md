# Boundary Review — parley.nvim#189 (milestone M1)

| field | value |
|-------|-------|
| issue | 189 — all finders should have a spinner in case of large input |
| repo | parley.nvim |
| boundary | milestone M1 |
| milestone | M1 |
| window | 909fbec1716a4fee67a3319455bee69192bacf75^..HEAD |
| command | `sdlc milestone-close --issue 189 --milestone M1` |
| reviewer | codex |
| timestamp | 2026-07-16T00:07:06-07:00 |
| verdict | REWORK |

## Findings

### Critical

1. `FinderProducer` accepted `{kind="record", value=nil}` and later indexed the
   payload from a scheduled callback, which could strand the session.
2. Async enrichment accepted any successful stat, allowing a tracked Markdown
   symlink whose target was a directory to become selectable.
3. The issue and plan described `cancelled` as a `ScanOutcome`, while the
   implementation deliberately cancels and retires without settlement.
4. The plan classified stateful, scheduler-driven `SliceBatcher` as PURE.

### Important

1. Total-failure status omitted the finder name and aggregate root/file counts.
2. Loader and producer duplicated total-failure construction (`ARCH-DRY`).
3. The plan claimed real submodule coverage, but the fixture only built a nested
   repository.
4. No production-entry test proved a real spinner advanced during delayed disk
   discovery and transitioned to results.
5. README omitted immediate asynchronous loading and Markdown's exact Git
   inclusion boundary.

## Resolutions

- Validate adapter record payloads at the producer boundary; invalid payloads
  become `invalid_adapter_result` without escaping scheduled work.
- Require enriched stat targets to be files, retaining symlink-to-file support
  while rejecting directory targets as `invalid_path`.
- Define cancellation as non-settling retirement in the issue and plan, and
  classify `SliceBatcher` as INTEGRATION.
- Single-source total failures in `finder_scan.total_failure` and render bounded
  finder/root/file aggregate status.
- Construct a real local Git submodule fixture and assert it remains opaque to
  the parent listing.
- Add a real process → Markdown finder → async stat → real float-picker test.
  The test exposed a libuv fast-event UI call; `FinderLoadSession` now schedules
  terminal delivery through its injected main-loop scheduler.
- Document immediate cancellable scanning and tracked-union-untracked-
  nonignored Git semantics in README; map the new integration spec in atlas.

## Evidence to re-run

- Focused finder producer/loader/scan, async file source, Git Markdown source,
  Markdown finder, picker status, and real Markdown async integration specs.
- `make test-changed`
- `make lint`
- `git diff --check`

This compact record preserves the failed verdict and actionable review history;
the generated prompt, repository diff, and raw terminal transcript were removed
before re-review so they do not consume the next boundary window.
