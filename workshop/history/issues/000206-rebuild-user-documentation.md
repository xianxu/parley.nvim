---
id: 000206
status: done
deps: []
github_issue:
created: 2026-09-01
updated: 2026-09-14
estimate_hours: 2.49
started: 2026-09-02T14:27:21-07:00
actual_hours: 3.49
---

# Rebuild Parley user documentation

## Problem

Parley's README contains the product story, installation, first-use path,
command reference, provider details, advanced Ariadne workflows, and developer
notes in one long stream. The breadth reflects what Parley can do, but it makes
the core chat product difficult for a new user to understand and try. Promoting
Parley requires a concise public entry point and user documentation organized
around real workflows rather than the repository's implementation history.

## Spec

Rebuild the documentation around a first-time Parley user while retaining
accurate reference material for existing users.

- Make `README.md` the concise product landing page: what Parley is, who it is
  for, its differentiating chat workflow, a minimal installation, and one
  successful first conversation. Keep repository-development material out of
  that critical path.
- Establish a linked user-documentation structure for setup/configuration,
  everyday chat and branching, finding and revisiting work, providers and
  CLIProxyAPI, export/sharing, advanced workflows, and troubleshooting. Reuse
  existing authoritative docs and atlas facts rather than maintaining parallel
  explanations (`ARCH-DRY`).
- Clearly separate the core public chat product from optional Ariadne-style
  repository/development workflows. Advanced integration remains documented,
  but it must not define the introductory story (`ARCH-PURPOSE`).
- Audit every documented command, default mapping, provider claim, dependency,
  and configuration example against the shipped product. Examples must be safe
  to copy and must not require private local configuration. Keep a checked
  audit inventory spanning the README, retained user docs, generated help, and
  user-facing atlas links; each claim class names its canonical product source
  and either an automated drift check or recorded manual verification.
- Produce a video-ready walkthrough script/storyboard covering the same
  first-use narrative. It specifies timed scene order, narration/on-screen
  copy, exact commands and keys, expected UI states, synthetic demo prompts and
  files, draft caption/transcript text, privacy-safe capture setup, and links to
  canonical docs. A reviewer and the operator approve it as executable without
  reopening the product narrative. Recording, editing, hosting, and publication
  belong to #207; later fact or narrative changes revise #206 explicitly.
- Keep generated help/panvimdoc inputs and public documentation derived through
  their existing generation seams; do not create another hand-maintained
  command catalogue (`ARCH-PURE`, `ARCH-DRY`). No new runtime dependency is
  introduced (`ARCH-MOCK`: N/A). Documentation navigation and the first-use
  path should remain small enough to verify in one clean-install smoke
  (`ARCH-CONSTRAINTS`).

## Done when

- A new user can understand Parley's core value, install it, configure one
  provider, and complete a first conversation from the README without reading
  developer or Ariadne-specific material.
- Detailed user workflows live in a discoverable linked documentation
  structure, and the README no longer attempts to be the exhaustive manual.
- Core-chat, advanced-integration, and contributor documentation have visible
  boundaries.
- Commands, mappings, defaults, links, and configuration examples are checked
  against the current product, with complete checked audit inventory and
  evidence for automated and manual cases. A clean-install walkthrough starts
  from the supported Neovim baseline with a fresh plugin install, one documented
  public/synthetic provider path, and no private Parley configuration; it ends
  after a persisted Markdown chat receives a successful model response.
- An operator-approved, timed, privacy-safe video script/storyboard contains
  every production input named in the Spec and is the direct input to #207.

## Plan

- [x] Inventory the current README and user-facing documentation against shipped
  behavior in a checked audit, identifying canonical sources and
  stale/duplicated claims.
- [ ] Design and implement the README and user-document information hierarchy.
- [ ] Verify links, commands, configuration examples, generated help, and the
  clean first-conversation path.
- [ ] Write and review the introduction-video script/storyboard for #207.

## Log


- 2026-09-14: closed — All 257 make test specs pass; make lint 448 files zero warnings/errors; final infra/starter mapped suite passes; fresh isolated actual starter seeds and retrieves all three tutorials and native Basics outline exercise lands correctly; all54 atlas pages audited and16 docs-only questions resolved. Historical unchecked manual/video/live-provider Plan items were explicitly superseded by approved 2026-09-14 revision; revised checklist complete, so no-plan-check applies only to those preserved historical items.; review verdict: SHIP
### 2026-09-01

Created while triaging the Parley backlog. Promotion now depends more on a
clear core-chat story and approachable onboarding than on expanding Parley into
unrelated repository tooling. The finished video is intentionally separated
into dependent issue #207.

### 2026-09-02

Took a full shipping-surface inventory before touching docs (three-cluster code
audit + clean-clone install repro). Durable record:
`workshop/plans/000206-shipping-surface-inventory.md`.

The audit changed this issue's footing. Writing a first-use README is not yet
possible, because **a clean clone of parley does not load**: `init.lua:110-111`
calls `issues_mod.setup(M)` at module top level, which reads
`construct/generated/vocabulary/issue.json` — gitignored (`.gitignore:43`) and
generated from the ariadne sibling repo. Reproduced by extracting
`git archive HEAD` into a fresh dir; `require("parley")` raises at
`issue_vocabulary.lua:147`. A `lazy.nvim` install hits the same path.

That makes **#162 (split parley from ariadne) a dependency of this issue**, not a
parallel one: the plugin is unloadable for the public because of an issue-tracker
vocabulary the public has no use for.

Nine further launch blockers are catalogued as B2–B10 in the inventory: default
`tool_read_roots = {'../'}`; `@all` write tools with no confirmation and no tests
on `edit_file`; unprompted `memory_prefs` egress of the chat archive at startup;
unprompted third-party binary download on the main loop; personal paths as
product defaults (iCloud, `~/blogs`, `~/.personal`); ~370 private workshop files
tracked in the repo; shipped prompt text linking outside the repo; a keybinding
land-grab that binds inert `<C-y>*`/`<C-j>*` scopes for every user; and a
`checkhealth` that reports green on a broken install.

Documentation findings proper (retained for the eventual rewrite): 63 commands
ship, ~20 are documented; `:ParleyChatDirs`/`ChatDirAdd`/`ChatDirRemove` and
`<C-g>h` are documented but do not exist; `:ToggleWebSearch` is missing its
prefix; `@@path` should be `@@path@@` with a scheme/path prefix
(`chat_parser.lua:497-512`); `brew install cliproxyapi` is not required given
`auto_download`; `<M-q>` is undocumented; there is no `doc/` or panvimdoc and the
`<!-- panvimdoc-ignore -->` markers at README:1,7 are orphans. Keybindings have a
single source (`keybinding_registry.lua`) and did not drift; commands have none
and did.

Plan step 1 is complete. Steps 2–4 are blocked on the Tier 0 sweep.

### 2026-09-11

One more stale line for the rewrite: README:223's `live_models` example still
quotes `"codex:gpt-5.6"`, while `config.lua`'s default is now
`"codex:gpt-6,gpt-5"` (`5596d22`). Deliberately not patched in place — the
README is being rewritten here; don't carry the old example forward.



## Revisions

### 2026-09-14 — App tutorials and AI-queryable reference replace a separate manual

Reason: the app now ships welcome.md, basics.md, and advanced.md; parley_help exposes installed documentation. Operator approved a concise README, an atlas audit for answerability and code consistency, and exposing canonical tutorials to AI help.

Current scope supersedes the earlier separate user-manual hierarchy and mandatory video storyboard. README covers the product idea, app-first installation, and links to canonical packaging/tutorials files; plugin/contributor links remain secondary. Tutorials teach the workflow. Atlas pages describe observable shipped behavior, invocation/configuration/defaults, limitations, and source/test pointers; they remain a structured code map, not an exhaustive manual. Ctrl+g ? remains the live configured shortcut reference.

The old dependency list is removed for this scope: document current shipped behavior accurately rather than waiting for every optional safety/integration issue to be implemented. This does not close those issues or assert their desired changes shipped. #208's former clean-clone blocker has shipped runtime vocabulary and fresh-clone tests; app installation and onboarding now exist. #207 retains video production; no storyboard is required to finish this issue.

Current acceptance:
- Concise app-first README links the three canonical tutorials and retains the introduction markers consumed by help.
- Every atlas page is checked for current behavior, source evidence, discoverability, and useful user answers; index summaries agree with pages.
- Canonical tutorials receive necessary factual corrections; workshop demonstration copies are preserved.
- parley_help lists and safely reads the three bundled tutorials, with no arbitrary path access and existing size/symlink protections intact.
- Durable checked audit inventory and representative user-question evidence; links/retrieval/claim checks plus applicable test suite and isolated starter verification pass.

Implementation plan: workshop/plans/000206-documentation-refresh-plan.md. The original checked inventory remains historical evidence; its old blockers are not presumed current. No video deliverable or live provider/account access is required for this documentation revision.


## Estimate

Re-estimated for the 2026-09-14 scope after plan-quality approval. Provisional estimate-logic-v3.1: design/audit structure 3h × 0.2 resolved-spec factor = 0.6h; documentation audit/rewrite and help/test implementation 4h × 0.4 = 1.6h, including atlas inventory, tutorial corrections, README, link checks, retrieval verification and publication. One fresh closing review 0.5h × 0.4 = 0.2h. Familiar repository, parallel page audits; 15% design buffer. No live account setup or video production.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.6 impl=1.6
item: milestone-review design=0 impl=0.2
design-buffer: 0.15
total: 2.49
```


### 2026-09-14 — Implemented revised scope

The original ## Plan remains as historical evidence; its separate manual/video and live-provider acceptance are superseded by the earlier dated revision. Current plan:

- [x] Rewrite README around app installation, product idea and canonical tutorials.
- [x] Audit all 54 feature pages and index against code; record sources/corrections in workshop/plans/000206-documentation-audit.md.
- [x] Correct tutorial outline exercises and make all three safely retrievable through parley_help.
- [x] Check user answerability against exact retrieved docs and address identified scope/recovery/default contradictions.
- [x] Verify 257 test specs, lint (448 files), local documentation links, reader boundaries, and isolated starter tutorial exercise.

The initial full suite identified a missing traceability route and a README-specific shortcut regression check. Added the route and moved the six-headline-chord guarantee to the callable atlas; full rerun passes. New doc claim checks exercise the actual tag parser and chat outline, rather than pinning descriptive source strings. ARCH-DRY: retain current configured help as the live key reference; ARCH-SECURE: tutorial catalog extends only three fixed paths; explicit inclusion and model tool root policies are documented separately. The source audits corrected historical claims about broad chat search, background memory, shared credentials and raw log privacy. No deferred product behavior is implemented here.

Fresh binary-owned close review and PR publication follow this implementation record. Merge remains operator-controlled.
