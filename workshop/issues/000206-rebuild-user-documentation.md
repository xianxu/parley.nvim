---
id: 000206
status: blocked
deps: [#208, #209, #210, #211, #212, #213]
github_issue:
created: 2026-09-01
updated: 2026-09-02
estimate_hours:
started: 2026-09-02T14:27:21-07:00
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
