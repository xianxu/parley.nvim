---
id: 000206
status: working
deps: []
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

- [ ] Inventory the current README and user-facing documentation against shipped
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
