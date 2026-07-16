# Boundary Reviews — parley.nvim#189 (milestone M1)

| field | value |
|-------|-------|
| issue | 189 — all finders should have a spinner in case of large input |
| repo | parley.nvim |
| boundary | milestone M1 |
| window | 909fbec1716a4fee67a3319455bee69192bacf75^..HEAD |
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

### Findings

1. Critical: malformed asynchronous root events could pass unregistered failure
   kinds or invalid list/ordinal shapes into asserting reducers and strand the
   producer.
2. Critical: exit-zero stdout with a below-cap unterminated NUL fragment was
   accepted as success and silently dropped.
3. Important: invalid super-repo labels gained `{}` or stringified prefixes.
4. Important: `join_path` and bounded filesystem-error fallback were duplicated
   between traversal and enrichment (`ARCH-DRY`).

### Resolution

`FinderProducer` validates complete event schemas before mutating root state;
invalid ordinals become bounded total failures and malformed known-root events
become bounded root failures. Git EOF requires an empty pending fragment.
Invalid labels render unprefixed as before. Native path joining and bounded IO
fallback are single-sourced in `finder_scan`. Regressions cover delayed malformed
events, truncated exit-zero framing, fallback display/search text, and the
shared helpers.

## Evidence to re-run

- Focused scan/producer/loader, Git source, Markdown materializer/entry-point,
  async filesystem, picker status, and real delayed-picker specs.
- `make test-changed`
- `make lint`
- `sdlc issue validate --issue 189`
- `git diff --check`

This compact record preserves all failed verdicts and resolutions. Raw prompts,
diffs, and terminal transcripts were removed before re-review so they do not
consume the next boundary window.
