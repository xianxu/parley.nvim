# Boundary Review — Issue #181

| field | value |
|---|---|
| issue | 181 — repo-root read-wide completion for all markdown |
| boundary | whole-issue close |
| window | `7719c33ff31ae977796b1032c4bb64f1693b3fc1..0f0b025f` |
| reviewer | codex |
| timestamp | 2026-07-11 |
| final verdict | `FIX-THEN-SHIP` |

## Review history

The close gate ran several fresh-context passes. Each blocking finding was fixed
and committed before the next pass:

1. Preserve global-chat narrowing and canonicalize policy roots.
2. Make the first existing read candidate authoritative; do not fall through
   after containment rejection.
3. Reject dangling read candidates deterministically.
4. Filter completion through canonical read enforcement and complete
   traceability.
5. Add ordinary nested-Markdown chat and skill regressions that distinguish
   repo-root read widening from the legacy artifact-root behavior.

## Final review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The reviewer found no Critical implementation defect. It confirmed that one
root policy drives read resolution, write confinement, completion, skill/chat
dispatch, and model guidance; completion reuses `resolve_read_path`; attachment
is idempotent; ordinary non-repo Markdown is unchanged; and atlas/traceability
coverage is present.

The sole Important finding was an evidence gap: chat and skill integration
tests used repo-backed chat artifacts whose legacy neighborhood was already the
repo root. The follow-up commit replaced those cases with ordinary
`data/nested/doc.md` buffers, proving repo-root-only reads at both seams. The
chat regression additionally proves the identical relative write lands in the
nested write neighborhood and leaves the repo-root candidate unchanged. The
reviewer's stale dispatcher-annotation note was also resolved.

Verification after the follow-up: mapped `providers/tool_use` and
`skills/skill-system` suites passed; `make -f Makefile.parley test JOBS=1`
passed with lint clean across 244 files and all unit, integration, and
architecture specs green; `git diff --check` passed.

## Architecture

- `ARCH-DRY`: pass — all consumers derive from `RootPolicy` and completion
  acceptance reuses the dispatcher resolver.
- `ARCH-PURE`: pass — deterministic policy/merge/formatting helpers are kept
  separate from filesystem and Neovim adapters.
- `ARCH-PURPOSE`: pass after follow-up — ordinary nested-Markdown regressions
  now demonstrate the issue's actual read-wide/write-narrow purpose.
