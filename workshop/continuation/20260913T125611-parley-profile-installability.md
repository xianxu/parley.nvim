---
type: continuation
slug: parley-profile-installability
agent: codex
created: 2026-09-13T12:56:11
branch: 000208-fresh-clone-installability
worktree: /Users/xianxu/workspace/parley.nvim
issues: [000244, 000208, 000219]
---

# Continuation: parley-profile-installability

## NEXT ACTION

Run `sdlc state`, then resolve the already-filed #219 directory-creation race that blocked #208's full fresh-clone acceptance. Read `workshop/issues/000219-prepare-dir-races-on-concurrent-setup-failing-specs-intermittently.md` (resolve actual filename with rg); the failure is in `/tmp/parley208-archive-full.log` lines 501–523, shared `claude/parley-harness/state`. Do not normalize it by rerunning until green. Claim/design/change-code through SDLC, preserving #208's staged work; use a worktree if the separate issue needs isolation. The user approved continuing deployment work; routine fixes are authorized.

Then adopt the merged upstream `.github/workflows/merge-check.yml` seed from `/Users/xianxu/workspace/ariadne` (main `2aff87d`, PR122 passed hosted CI). The real root Makefile is already adopted. Finish #208 full archive verification, close/review/PR/merge, then continue the packaging project's starter profile and deployment work.

## State of play

#244 shipped in Parley PR176, merged `82045c38`; image shrinking is done. #208 is working on `000208-fresh-clone-installability`, runtime commit `3e2daf4`, with substantial staged code/build/test/docs changes and an unstaged issue checkpoint log. No #208 close/PR yet. ariadne#225 is complete and merged; no agent still owns active work. Its narrow review-policy repair permits pinned-diff evidence for prose-only fixes while retaining regression proof for behavior changes.

The overall deployment goal remains incomplete. The user explicitly said “go ahead” after approving #208 plus ariadne#225. Do not ask for that approval again. A prior persistent goal was marked blocked waiting for that approval; the user's reply resumed the work. Do not mark the goal complete until a separate profile can actually install and run.

## Thread arc & user model

The user started at the packaging project and #244, then clarified today's result: deploy Parley easily on another machine under a new Neovim app profile. Use `~/.config/nvim` as the base for packaged defaults. They expect autonomous implementation after approval, not repeated permission pauses. Fixing plugin fresh-clone startup is a prerequisite, not the final deliverable.

The planned product is `brew install xianxu/parley/parley`, a `parley` launcher with `NVIM_APPNAME=parley`, managed cliproxy login, and clean Tart VM acceptance. Preserve the real personal profile. Its useful defaults include Moonfly, space leader, wrapped prose/linebreak/breakindent/smoothscroll, unnamedplus, smartcase/spell and wrapped-line navigation. Its unquoted showbreak value is invalid Lua; package the quoted intent. Exclude personal checkout paths, credential commands, user folders and unrelated plugins. Configure cliproxy auth_dir inside the profile: NVIM_APPNAME alone does not isolate `~/.cli-proxy-api`.

## Artifact map

Read `workshop/projects/parley-packaging.md`, then #208's issue and `workshop/plans/000208-fresh-clone-installability-plan.md`. The issue now contains current results and the archive failure. Plan revisions explain module-root loading, real shell alias expansion, shared default status and model-generation cache invalidation. The plan gate accepted round2 and estimate2.494h is already recorded. Do not reread archived issues.

Runtime code: `lua/parley/issue_vocabulary.lua` validates dense/disjoint status arrays and transitions, bounds regular-file reads to1MiB, caches ready/unavailable results, reloads on setup. `issues.lua` and finder adapters refuse issue actions without a model, preserve files and chat, and support real sdlc binary/function/alias routes with quoted arguments. Vendored JSON is the only shipped construct runtime artifact. Tests include unavailable-data regressions and filesystem-backed fake_sdlc/fake_vocabulary executables.

Build/acceptance: staged `scripts/check-fresh-clone.sh` uses a private index and git archive, rejects escaping/dangling symlinks, isolates HOME/XDG/TMPDIR, exercises real require/setup/chat under intact/missing/corrupt/malformed data, and optionally runs the full suite. It never borrows untracked user files. `scripts/check-vocabulary.sh` compares full generated JSON content; `scripts/ci-setup.sh` builds actual CUE0.16.1/exporter in RUNNER_TEMP; `scripts/merge-checks.d/20-vocabulary.sh` enforces drift. Generic CI seed still needs adoption. Makefile.parley has explicit PLENARY override and dependency advice. All 28 tracked escaping links are removed from the index; maintainer link files are preserved locally/ignored, root Makefile is real. Never broad-stage the operator's untracked workshop/parley chats/assets.

Docs and routing updates: TOOLING.md, atlas/infra/test_harness.md, atlas/issues/issue-management.md and atlas/traceability.yaml. Issue plan checkboxes remain unticked pending final acceptance; update them honestly before close. `make test` locally passed except missing new spec routing entries, now repaired (focused architecture suite21/21). Full archive then exposed #219 and stopped during units, so integration suite is not yet proven in the full archive.

## Decisions & dead ends

Keep upstream-owned Makefile and generic CI as seeded real files; fix propagation at ariadne source instead of maintaining a local fork. ariadne#225 tested real scratch bootstrap and repeated weave without overwriting product files. No live consumer weave was performed.

No synthetic open status when vocabulary is unavailable. Model absence is an optional-feature failure, not a reason for plugin load to fail. Use model identity to invalidate cached records on reload. Preserve shell aliases/functions by leaving only the safe command identifier bare while quoting every argument.

Do not add vacuous prose string tests to satisfy reviews. ariadne225 had three reviews stuck solely on a faulty universal test mandate; its narrow source contract repair was itself tested, and final fresh review shipped without bypasses.

## Lessons learned

Archive cwd must be isolated as well as HOME, otherwise tests can borrow developer data and falsely pass. Check full generated content rather than an adjacent source stamp. Shared test state exposed a real mkdir race already filed as #219; preserve the failing evidence.

## Live deliberations

Useful logs: `/tmp/parley208-runtime-acceptance.log` (four variants pass), `/tmp/parley208-archive-full.log` (race failure), `/tmp/parley208-full-test.log` (local suite routing failure), `/tmp/parley208-arch.log` (routing now21/21), `/tmp/parley208-ci-setup.log` (isolated real provisioning and exporter match), `/tmp/parley208-ci-root` (scratch root path). `/tmp/parley244-spec.sh <spec>` is the isolated focused runner despite its legacy name. PLENARY is `/Users/xianxu/.local/share/nvim/lazy/plenary.nvim`.

Remaining packaging issues include #209/#211/#213 prerequisites, #245 dependency registry, #246 starter config, #247 brew/launcher, #206 docs. Read their current scope before new design. Cached Tart tahoe VMs are stopped; tools-test is running and belongs to other work. No profile installation has been claimed.
