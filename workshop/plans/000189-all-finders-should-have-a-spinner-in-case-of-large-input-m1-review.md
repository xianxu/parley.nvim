# Boundary Reviews — parley.nvim#189 (milestone M1)

| field | value |
|-------|-------|
| issue | 189 — all finders should have a spinner in case of large input |
| repo | parley.nvim |
| boundary | milestone M1 |
| command | `sdlc milestone-close --issue 189 --milestone M1` |
| reviewer | codex |

## Review 1 — REWORK

Malformed adapter records and directory-valued symlink targets could strand or
pollute results; cancellation and `SliceBatcher` were misclassified in the
artifacts; aggregate failure policy was duplicated/incomplete; real submodule,
production-spinner, and README coverage were missing.

Resolved by validating producer/stat payloads, single-sourcing failures,
scheduling UI settlement, revising the contracts/classification, and adding the
real process, picker, submodule, directory-target, and documentation coverage.

## Review 2 — REWORK

Git stream errors did not retire their pipe, pending fragments were not truly
retention-bounded, and canonical identity keys were incorrectly reused as
native selectable paths.

Resolved by terminal stream stop/close, incremental cap-before-concatenation
NUL parsing, native path selection, and fake-process plus real backslash-path
regressions.

## Review 3 — REWORK

Malformed asynchronous root events could reach asserting reducers; exit-zero
stdout with an unterminated NUL fragment could silently drop a path; invalid
super-repo labels gained visible prefixes; and adjacent filesystem path/error
helpers were duplicated (`ARCH-DRY`).

Resolved by full root-event schema validation, strict EOF framing, unprefixed
fallback labels, and shared native path/error policy in `finder_scan`.

## Review 4 — FIX-THEN-SHIP

The M1 vertical slice was confirmed genuinely asynchronous, Git-aware,
deterministically materialized, documented, and broadly covered. Two Important
cancellation cleanup gaps remained:

1. Window invalidation and programmatic `picker.close()` performed raw UI
   teardown without notifying the picker-owned loader subscription, allowing
   its producer to outlive the UI (`ARCH-PURPOSE`).
2. Queue cancellation suppressed all late callbacks, so an uncancellable
   `fs_open` that later succeeded could return a descriptor no owner saw or
   closed.

### Resolution

Raw teardown remains the selection/mapping completion path; every
non-selection dismissal now routes through one idempotent cancellation
notification. The operation queue accepts a per-job late-completion disposer,
and file enrichment uses it to directly close a successful late `fs_open`
descriptor. Regressions destroy a real loading Markdown picker, assert one
producer cancellation and no late repaint, and model failed `uv.cancel`
followed by a successful open whose descriptor is closed exactly once.

### Evidence

- Focused Markdown loading-picker, float-picker, and async-file-source specs.
- `make test-changed`
- `make lint`
- `sdlc issue validate --issue 189`
- `git diff --check`

The generated raw prompts, diff, ANSI output, and duplicated reviewer response
were compacted before commit; the durable verdict chronology, findings,
resolutions, and reproducible evidence are preserved here.
