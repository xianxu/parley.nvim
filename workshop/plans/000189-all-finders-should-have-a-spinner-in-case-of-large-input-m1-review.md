# Boundary Reviews — parley.nvim#189 (milestone M1)

| field | value |
|-------|-------|
| issue | 189 — all finders should have a spinner in case of large input |
| repo | parley.nvim |
| boundary | milestone M1 |
| window | 909fbec1716a4fee67a3319455bee69192bacf75^..HEAD |
| command | `sdlc milestone-close --issue 189 --milestone M1` |
| reviewer | codex |

## Review 1 — 2026-07-16T00:07:06-07:00

**Verdict:** REWORK

### Findings

1. Critical: a `{kind="record", value=nil}` adapter result could crash a
   scheduled producer callback and strand the session.
2. Critical: successful stat accepted a directory reached through a tracked
   symlink as a selectable Markdown record.
3. Critical: the issue/plan described cancellation as a settled outcome while
   implementation used non-settling retirement.
4. Critical: the stateful scheduler-driven `SliceBatcher` was classified PURE.
5. Important: total-failure presentation omitted finder/root/file aggregates;
   failure construction was duplicated (`ARCH-DRY`).
6. Important: real submodule and production delayed-spinner coverage were
   missing, and README omitted the loading/Git inclusion boundary.

### Resolution

Validated producer and stat payload shapes; single-sourced aggregate failure;
scheduled session terminal delivery onto the main loop; added real submodule,
real process-to-picker spinner, and directory-target tests; documented the UI
and Git boundary; revised cancellation and batcher classification.

## Review 2 — 2026-07-16

**Verdict:** REWORK

### Findings

1. Critical: stdout/stderr read errors killed the child without retiring that
   pipe, so a missing later EOF could leave `scanning…` forever.
2. Critical: `identity.key` normalized backslashes and was reused as the picker
   value, corrupting legal POSIX native paths.
3. Important: the pending NUL fragment threshold detected overflow only after
   concatenation and continued accepting chunks, so it was not a retention cap.

### Resolution

Stream errors now stop/close their side, mark it terminal, and settle once after
child exit. NUL chunks are consumed incrementally and retire stdout before any
retained fragment can exceed 16,384 bytes; later chunks are ignored. Markdown
uses resolved/unresolved native paths for selection and reserves canonical keys
for deduplication/sorting. Fake-process tests cover stdout/stderr errors and
repeated post-cap chunks; real Git plus pure materialization cover a tracked
backslash-bearing filename.

## Evidence to re-run

- Focused Git Markdown source, Markdown materializer/entry-point, producer,
  loader, scan, async filesystem, picker status, and real delayed-picker specs.
- `make test-changed`
- `make lint`
- `sdlc issue validate --issue 189`
- `git diff --check`

This compact record preserves both failed verdicts and their resolutions. Raw
prompts, diffs, and terminal transcripts were removed before re-review so they
do not consume the next boundary window.
