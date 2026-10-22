---
id: 000415
status: open
deps: [ariadne#556, ariadne#558]
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'ad83381f5da10018810a61a01fa7c3e134e91079' # card fields mirrored from issue-cards; edit via sdlc
---

# Adopt typed Plenary flake evidence

## Problem

The native o-entry retry case from parley.nvim#410/#412 has no registrable Lua identity in the current recorded suite. The canonical runner executes whole spec files. An isolated copied/edited spec pass is not same-head evidence. Ariadne's typed implementation and Plenary producer distribution must land before adoption.

## Spec

Adopt ariadne#556 after ariadne#558, with capable fleet binaries deployed first. Leave this issue unclaimed for Parley's owning TL to dispatch. The version-3 suite declaration is a local-gates change whose verification and local-gates-verified label belong to the operator, never the implementing agent.

Exact adoption steps:

1. Add a version-3 suite flake_runners.lua declaration with results: plenary-events-v1 and the actual whole-file Plenary argv. Preserve the current suite command/policy/weight/timeout. The spec path is exactly one complete {path} argv operand; it must not be interpolated into an executable Lua or shell expression. Derive the argv entry from tests/helpers/spec_runner.lua's actual child: nvim --headless --noplugin -n -i NONE -u tests/minimal_init.vim, entering tests.helpers.spec_child.run for that file. If an argv-reading entrypoint is needed, make it a small adapter to the same native child, not a replacement assertion runner.
2. In tests/helpers/spec_child.lua, install scripts/sdlc-plenary-events.lua before busted.run(path). Keep the existing it/progress wrapper, hooks, assertions, native formatting and observed exit semantics. Its current path is absolute: pass a verified repository-relative spec identity to producer.install, matching SDLC_FLAKE_UNIT, without changing the path Plenary uses. Do not parse stdout for result authority.
3. At the managed whole-file invocation boundary, call sdlc flake run --unit lua:tests/integration/session_sync_native_spec.lua; normal make/test-spec keeps the direct native fallback outside typed-capable managed checks. Preserve PARLEY_TEST_ENV_ROOT/HOME/XDG isolation and existing deadline/load/progress behavior. Audit spec_runner's detach=true child/group handling before choosing the boundary: do not accidentally introduce an escaping nested managed group or bypass existing child/job cleanup. Prove cancellation against the real harness.
4. Register the exact identity lua:tests/integration/session_sync_native_spec.lua#session-sync native edits retries refused admission with native o entry (#408 retry) only after NEW typed-capable failure and complete pass on the SAME exact commit, onto the appropriate still-open flake issue (#412 if applicable). Lua retries the whole spec once; positive proof requires this exact case AND whole-file success. A sibling's pass, text saying Success, missing producer channel or a copied/edited isolated spec cannot supply proof.
5. Resume that new original typed attempt; verify no whole-suite rerun, one whole-spec child, native siblings/hooks unchanged, exact case/file proof, status/guard acceptance, repeat without execution, and retained original bytes. Preserve all historical Go-only attempts without rewriting or retroactively upgrading them.

## Done when

- Operator verification authorizes the local-gates declaration after binary deployment and ariadne#558 distribution.
- The native full case label is attributed, registered from new typed-capable same-head fail/pass evidence and resumed by its exact original attempt.
- Missing/ambiguous/omitted-case proof refuses, and only exact case plus whole-file success permits landing; stdout cannot impersonate private results.
- Native assertions/hooks/progress/deadlines, test-environment isolation and actual descendant cleanup remain correct through failure and cancellation.

## Plan

Plan the actual argv and ownership boundary with Parley's TL after both dependencies land; implement producer installation, managed invocation and the operator-verified declaration together. Run private production CLI plus real Neovim/Plenary conformance before activation and normal close/landing. Filing does not authorize activation.

## Log

### 2026-10-22

Filed unclaimed at ops:0's request from ariadne:3. Read-only source inspection confirms spec_runner.lua constructs an absolute file path and owns detached child/process/job cleanup; spec_child.lua wraps native it() for progress before busted.run. TOOLING.md requires the normal make harness and isolated HOME/XDG roots. Peer AGENTS.local.md read; root MEMORY.md is absent. No peer checkout files or branch work changed. Ariadne#556's private native fixture proves the exact motivating full label; #558 separately owns producer distribution and operator-held verification.
