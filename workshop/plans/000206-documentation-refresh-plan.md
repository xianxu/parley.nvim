# Documentation refresh (#206)

## Core concepts

| Name | Lives in | Kind | Status |
|---|---|---|---|
| Documentation catalog | lua/parley/help_content.lua | PURE | modified |
| Product entry and tutorials | README.md; packaging/tutorials/*.md | PURE content | modified |
| Feature reference and index | atlas/**/*.md; atlas/index.md | PURE content | modified |

Preserve existing APIs; add no exported function. Fixed tutorial topic IDs map to three packaged paths. Existing atlas discovery remains linked from index, so agents can find reference pages without broad filesystem access (ARCH-DRY/PURPOSE).

## Integration points

| Name | Lives in | Kind | Status | Wraps |
|---|---|---|---|---|
| Bundled help reader | lua/parley/help.lua; tools/builtin/parley_help.lua | INTEGRATION | existing reader, updated description | installed release files |
| Tutorial initialization | lua/parley/starter.lua | INTEGRATION | unchanged | copies missing tutorials into profile |

The installed runtime is the documentation version boundary; no network fetch or new dependency. Help keeps its fixed allowlist, realpath/symlink checks, 128KiB/file limit and 256-topic ceiling. Add exactly three allowed tutorial files; read errors remain explicit. Listing remains linear in the ~55 atlas pages and three guides, with a hard topic bound; no per-keystroke work, mutable model state or durable artifact added (ARCH-SECURE/CONSTRAINTS/ORDER/FUNERAL). Maintain separation of pure catalog projection from file IO (ARCH-PURE). No external service is added; real filesystem tests use temporary runtimes (ARCH-MOCK).

## Work

- Append the approved scope revision to #206 and reserve it. Preserve old findings as dated evidence.
- Audit every atlas Markdown page in three disjoint groups against the feature code/tests. Produce a checked inventory naming each page, findings/corrections, sources and relevant question. Keep current technical details when they help navigation; remove obsolete implementation-history claims. Mark optional repo integrations and known limitations explicitly.
- Rewrite README to the idea, supported app install, and canonical tutorial links, with compact plugin/contributor references. Retain the marked product introduction consumed by help. Move still-useful removed facts into existing atlas owners only when absent; avoid copied command tables.
- Correct canonical tutorials: chat outlines omit headings, branch insertion already enters Insert mode, and examples/default claims must follow current code. Keep workshop demo transcripts unchanged.
- Expose tutorial topics through existing catalog and clarify AI instructions to consult tutorials for guided usage and atlas for reference, with shipped behavior taking precedence over planned sections. Add failing unit tests for catalog topics and limits plus real-reader tests for valid/missing/symlinked tutorial files; prove no access to arbitrary workshop files.
- Refresh atlas/index summaries and add any missing page links. Check all README/tutorial/atlas relative links and local code/test references. Add meaningful deterministic conformance assertions for reported drift (tags syntax, headings policy, defaults) using existing code seams rather than source-string snapshots where possible.
- Build a representative user-question matrix (installation, accounts/models, storage, shortcuts/customization, tags, branch/outline, context/privacy, attachments, web search, export, troubleshooting). A fresh agent answers from the exact catalog-retrieved documents and flags unsupported answers; this checks retrieval/answerability, not live provider conformance. Record evidence and fix gaps.
- Verify affected unit/integration specs, full make test/lint, isolated starter tutorial onboarding using existing harness without real auth/provider calls, and links. Commit, close through the binary-owned fresh review, address findings and publish PR; operator controls merge.

## Verification strategy

`help_content.parse`: adversarial README lacking markers, invalid/oversized index, duplicate/path-like links and topic limit; assert exact allowlisted IDs/paths and errors. `help.read`: real temporary installed trees with present/missing/symlinked tutorials; assert returned bytes and refusal, including traversal and personal-file inputs. Documentation: semantic assertions tie the discovered stale claims to current runtime values/parser behavior; checked inventory ties the rest to source/tests and questions. Tests must read the canonical packaged tutorials, not user-edited profile or workshop copies.

The README is a public entry point, tutorials are exercises, atlas is answerable reference plus code map. Existing API behavior is described accurately; this task does not implement deferred product capabilities, rewrite optional integrations, or use private credentials for live answer testing.
