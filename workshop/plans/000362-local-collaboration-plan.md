# Local collaboration compatibility implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to choose bounded delegation or session execution. Steps use checkbox syntax.

**Goal:** Execute the approved local, single-artifact interpretation of collaboration routing without importing impossible side-doc/chat IO.

**Architecture:** Pure frontmatter/section resolution returns routing by row, notices and protected chat spans. The review driver owns admission and notifications; an invocation-owned edit validator refuses proposals touching protected spans before any tool execution. Canonical exports remain byte-faithful; the Parley-owned adapter states the local override.

**Tech Stack:** Lua, existing frontmatter scalar helpers, Plenary tests and the recorded suite. No Python/YAML runtime dependency.

## Core concepts

| Name | Lives in | Status |
|------|----------|--------|
| Collaboration routing | lua/parley/skills/review/collaboration.lua | new |
| Collaboration frontmatter value | lua/parley/skills/review/collaboration_value.lua | new |
| Local proposal permission | lua/parley/skills/review/collaboration.lua | new |

The value parser handles the canonical scalar, block/flow mapping and heading-list forms, including quoting and comments. It is deliberately scoped to this field: malformed or unsupported input refuses visibly instead of silently defaulting. Duplicate mapping keys refuse. No external decoder is needed. Existing flat frontmatter parsing supplies the leading block boundary.

Routing normalizes names by lowercase, whitespace collapse and dropping one trailing parenthesized annotation. It scans ATX levels 1–6 outside matching backtick/tilde fences, inherits the nearest named ancestor, applies repeated names to every matching heading, and warns for unmatched names. Invalid mode names and cross-mode normalized conflicts refuse. Frontmatter bytes are excluded from the edit region. Chat headings and all descendant content through the next equal/higher heading are protected; named descendants may override their inherited mode.

The proposal validator resolves the exact invocation snapshot and checks each unique old_string span against protected bytes. Reject the whole call before execution on any overlap, including a replacement spanning both editable and chat content. The validator is invocation-owned, never a model input. Refusals preserve the whole document; ordinary tool validation still owns missing/nonunique old strings.

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Local review admission | lua/parley/skills/review/init.lua | modified | buffer snapshot, vim.notify, marker readiness |
| Proposal validation hook | lua/parley/skill_invoke.lua | modified | decoded propose_edits call before tool execution |
| Local compatibility instructions | lua/parley/skills/review/local-adapter.md | modified | canonical prompt to local tool capabilities |

ARCH-DRY/PURE: one resolver supplies notices, admission, resubmission and edit permission; no second mode parser or prompt builder. ARCH-PURPOSE: verify the protocol's operations against the artifact-bound tool. Chat content remains a single protected resource for the lifetime of one invocation, rather than checking the model's intent. The existing tool filesystem lane and snapshot continue to own file effects. No process, persistent state, baseline or side-doc lifecycle is introduced.

## Implementation steps

### Pure values and routing

- [ ] Write failing unit tests in tests/unit/review_collaboration_spec.lua for absent/scalar/block/flow values, quoted names/comments, nested inheritance, levels 4–6, duplicate headings, fences, unknown/default/key modes, normalized conflicts and unmatched-name warnings.
- [ ] Run through make test-spec SPEC=modes/review (add the test to its mapping if needed); confirm missing implementation fails.
- [ ] Implement collaboration_value.parse(lines) and collaboration.resolve(lines), returning a plan or diagnostic. Each row maps to a mode; the result lists chat section names, discussion presence, warnings and whether any editable body exists.
- [ ] Test proposal spans: editable only passes, chat-only and crossing replacements refuse, no-op/empty batches remain subject to existing tool validation, frontmatter edits refuse.
- [ ] Run focused unit tests and commit.

### Local driver and tool seam

- [ ] Add regressions to tests/integration/review_send_spec.lua and tests/integration/skill_invoke_review_spec.lua for default questions, explicit collaboration, mixed chat/normal, all-chat and no-marker notices, malformed routing, and non-chat resubmission counting.
- [ ] Use existing stateful fake provider/tool filesystem seams for a response attempting a forbidden chat edit; prove no write. Exercise a normal edit in the same mixed document.
- [ ] Resolve routing at run_via_invoke before marker admission. Notify once on the user-triggered round: discussion answered in place, chat sections skipped because the hub agent answers chat, plus unmatched-name warnings. Empty/all-chat or marker-only with no eligible ready markers generates nothing.
- [ ] Attach an optional validate_edits hook to invocation options, consulted after tool-input normalization and before tool execution. A rejected batch returns a tool error with no effects. The review caller supplies the pure snapshot validator. Other skills have no hook and preserve their behavior.
- [ ] Filter chat markers from admission and remaining-ready counts. Keep whole-document selected review modes working on eligible sections even without markers. Direct/manual review uses the same admission, not only review_send.
- [ ] Update the Parley-owned local adapter: local in-place collaboration interpretation overrides imported discussion routing; chat content is immutable; no cross-file actions, side docs or fabricated baseline; notices are already emitted by Parley.
- [ ] Run mapped review tests and targeted invocation tests, then commit.

### Verification and landing

- [ ] Document the local behavior and limitations in README and atlas/modes/review.md; retain BR-1/BR-2 dispositions and lessons in the issue Log.
- [ ] Exact pinned-source --check must still pass; generated canonical files stay unchanged by the compatibility correction.
- [ ] Push the code head and run sdlc local-check run --name suite; retain any failure and apply the issue-backed one-retry rule.
- [ ] Run sdlc close with explicit focused/full-suite evidence. Its binary-owned full review checks the enlarged diff; no separate boundary review.
- [ ] On SHIP run sdlc pr and sdlc merge --yes, verify the merge with Git and report to the hub. No multi-file/baseline work belongs in this issue.
