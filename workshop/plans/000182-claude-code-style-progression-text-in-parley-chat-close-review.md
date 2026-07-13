# Boundary Review — #182

| field | value |
|-------|-------|
| boundary | whole-issue close |
| window | `27a778b7876adfdf3816b8c701e2b355252c357b..3653c0c` |
| reviewer | codex |
| timestamp | 2026-07-13T03:34:31-07:00 |
| verdict | REWORK |

## Findings

1. `skill_invoke.invoke` registered Definition's terminal cleanup before several
   fallible synchronous setup operations, but protected only `llm.query`.
   Payload preparation or later setup could therefore escape and leak the
   selection spinner plus in-flight ownership.
2. The plan claimed `fake_sse_server` implemented activity-only and
   tool-use-only modes that were actually covered by callback-driven entry
   tests, not the process fixture.

## Resolution

- `8dd14b4` protects the complete synchronous setup region after terminal
  registration and converges exceptions through the exact-once `finish` owner.
- A real `define_visual` regression injects throwing payload preparation and
  verifies no escaped error, spinner, footnote, or stale in-flight ownership.
- The plan's Core concepts entry now enumerates the fixture's actual default,
  delayed, broken-transfer, unauthorized, and partial-HTTP-500 modes and names
  callback-driven activity/tool-only coverage separately.
- Verification: 16 shared skill-lifecycle, 24 Definition, and 5 caller-teardown
  cases pass; lint and full `JOBS=1 make test` exit 0.

The raw initial transcript was compacted before re-review because it embedded
the complete 11,000-line review prompt and test output; including that generated
artifact in the next diff exhausted the review context and produced an unknown
verdict without reviewing the fix. This record preserves every actionable
finding and its resolution while keeping the re-review window inspectable.
