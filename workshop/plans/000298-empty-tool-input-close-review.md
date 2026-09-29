# Boundary Review — parley.nvim#298 (whole-issue close)

| field | value |
|-------|-------|
| issue | 298 — Preserve empty tool input objects |
| repo | parley.nvim |
| issue file | workshop/issues/000298-empty-tool-input.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4a3d286687041de8bd590c68fc73d121ac1c5486..ff69bfc8a250685654ef3a04db3a3c15e545ece3 |
| command | sdlc close --issue 298 |
| reviewer | codex |
| timestamp | 2026-09-28T21:08:47-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fulfills issue #298’s Spec and Done-when clauses. It fixes the decoder’s default representation, preserves existing argument parsing, and verifies continuation and transcript replay. No blocking findings.

1. **Strengths**
   - `lua/parley/tools/wire_anthropic.lua:155` corrects the representation at its source.
   - `tests/integration/response_tools_spec.lua:66` covers absent, empty, and explicit `{}` deltas, plus nested object/array preservation.
   - `atlas/providers/tool_use.md:131` accurately documents the correction. No new user-facing commands or configuration require README changes.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes:** Provider tool-use suite, lint, and pinned-range whitespace checks passed. Independent base/head execution confirmed absent and empty deltas encode as `[]` before and `{}` afterward; explicit `{}` remains unchanged. Malformed JSON retains its fallback behavior with the corrected object representation. Live conformance was skipped; process census was unavailable because `ps` was restricted.

6. **Architecture:** **ARCH-DRY: pass**—no duplicated coercion. **ARCH-PURE: pass**—the decoder remains deterministic without IO. **ARCH-PURPOSE: pass**—all documented input states and both downstream paths are covered.

7. **Plan revisions:** None required.

```findings
{}
```
