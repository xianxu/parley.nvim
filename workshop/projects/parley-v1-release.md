---
type: project
name: "parley-v1-release"
goal: "Make parley.nvim installable, safe, and comprehensible for a public audience as a Neovim chat product, separating the shipped user product from ariadne development infrastructure."
done_when: "A user on a supported Neovim baseline installs parley.nvim from a fresh clone with no ariadne repo present, completes a first persisted Markdown chat against one documented provider path, and encounters no unprompted network egress, no unrequested filesystem writes outside the chat directory, and no bound keybinding for an inert feature."
status: ideation
created: 2026-09-02
updated: 2026-09-02
---

# parley-v1-release

## PRD

### Goal

Make parley.nvim installable, safe, and comprehensible for a public audience as a
Neovim **chat product**, separating what ships to users from the ariadne
development infrastructure it grew up inside.

### Why now

Promotion is blocked on something stronger than documentation. A three-cluster
code audit (2026-09-02) found that `require("parley")` **raises on any machine
without the ariadne sibling repo** — reproduced by extracting `git archive HEAD`
into a fresh directory. parley is currently installable only by its author.

Behind that sit nine further blockers, most of them *defaults* rather than bugs:
unrequested network egress at startup, a write-capable agent with no confirmation
and no tests, read access to every sibling directory, an unprompted third-party
binary download on the main loop, the author's iCloud and blog paths as product
defaults, and ~370 private workshop files tracked in the repository.

### Requirements

1. **Installable.** A fresh clone loads and runs with no ariadne repo present.
2. **Safe by default.** No unprompted network egress, no filesystem writes
   outside the chat directory, no unconfirmed file mutation, no executable placed
   on disk without the user asking.
3. **Neutral.** No author-specific path, credential, or private working material
   ships as a default or a tracked file.
4. **Honest.** A feature that cannot work in the current context is not bound and
   presents no empty affordance; `:checkhealth` can go red.
5. **Comprehensible.** A new user can understand the product, install it,
   configure one provider, and complete a first conversation from the README.

### Acceptance boundary

Scope is the **core chat product**. The ariadne workflow surface is *gated*, not
removed and not extracted — a repo split (#162) is explicitly out of scope; see
the Log. Feature work beyond what already ships is out of scope; this project
makes the existing product shippable, it does not extend it.

### Non-goals

- Splitting parley into two plugins (#162) — deferred, reasoning in the Log.
- New chat features.
- Reviving Google Drive, which is advertised but inert
  (2,464 loc + 110 tests behind an OAuth client the user must register
  themselves). Decide separately: document the setup, or stop advertising it.

## Estimate

Not yet costed. Per the workflow contract, `estimate_hours` is derived per issue
after each plan clears `change-code`'s plan-quality gate — not guessed at project
open. Sequencing below is dependency order, not a schedule.

## Breakdown

Dependency order. #208 unblocks everything; #206 and #207 are last because the
product they document must be settled first.

- [ ] **#208** — parley must install and load from a fresh clone *(B1 + the dev/user separation)*
- [ ] **#209** — safe-by-default posture for a public release *(B2, B4, B5)*
- [ ] **#210** — consent model for write-capable tools *(B3; revisits #157)*
- [ ] **#211** — remove personal configuration from product defaults *(B6, B7)*
- [ ] **#212** — gate the ariadne surface behind repo detection *(B8, B9, Tier 3)*
- [ ] **#213** — delete dead code and make checkhealth honest *(Tier 4, B10)*
- [ ] **#214** — audit and curate the default keybinding surface *(policy on top of #212's mechanism)*
- [ ] **#206** — rebuild Parley user documentation *(step 1 done: the audit)*
- [ ] **#207** — produce Parley introduction video *(depends on #206)*
- [ ] **#162** — split parley into two plugins — **deferred**, see Log

## Log

### 2026-09-02 — opened

Opened from a shipping-surface audit of the whole plugin, recorded at
`workshop/plans/000206-shipping-surface-inventory.md`. That document is a dated
audit snapshot and the input to this breakdown; it is **not** a status surface.
Progress lives here and in the issue files, so the two cannot drift.

Method: three parallel code-audit passes over `lua/parley/` and `tests/` (chat
core; providers and tools; discovery and workflow), plus per-module git recency,
an ariadne-coupling grep, and a clean-clone install reproduction. Every finding
carries a `file:line`.

**Scale.** 50,346 loc of plugin against 59,506 loc of tests in 200 spec files. A
full `TODO|FIXME|XXX|HACK` sweep returns two hits, neither functional — the
incompleteness is structural, not abandoned. Coverage is real but unevenly
aimed: 60+ tests on fold projection, zero on `edit_file`.

**On #162 (split parley into two plugins) — deferred, with the finding recorded.**
#162 asked how isolated the two halves are. The coupling grep answers it: ariadne
concepts are concentrated in `issues.lua` (82 refs), `vision.lua`,
`super_repo.lua`, `neighborhood.lua`, `artifact_ref.lua` and the two finders,
while the chat core sits at 0-6 refs and `init.lua` (71 refs) is the single
wiring hub. So a split is tractable — but no launch blocker requires it. B1 needs
one vendored 4,776-byte file, not an extraction, and every Tier 3 failure is a
*gating* problem. Gating is also a strict prerequisite of splitting, so #212 is
step one of #162 either way and is not throwaway work.

Against that: the ariadne half is the maintainer's daily driver, so a split turns
that daily editor into two plugins that must version together, with a public seam
to design and maintain — the highest-risk refactor available, done under launch pressure.
Decision: gate now, ship the chat product, revisit #162 if public traction
justifies the maintenance separation.

**#214 added the same day.** The audit treated the keybinding land-grab (B9) as a
gating problem only. The operator raised the missing half: even where a feature
works, a default binding is a claim on the user's keyspace that must be
justified, and ariadne bindings should be explicitly configured rather than
defaulted. #212 owns the mechanism (context-filtered registration); #214 owns the
policy it enforces. #214 is quality work, not a launch blocker, and is sequenced
after #212 to avoid reworking the same call sites twice.

**Documentation findings held for #206.** 63 commands ship and ~20 are
documented. `:ParleyChatDirs`/`ChatDirAdd`/`ChatDirRemove` and `<C-g>h` are
documented but do not exist; `:ToggleWebSearch` is missing its prefix; the file
reference is `@@path@@` with both delimiters and a scheme/path prefix
(`chat_parser.lua:497-512`), not the `@@path` the README shows; `<M-q>` is
undocumented. Root cause of the drift is structural: **keybindings have a single
source** (`keybinding_registry.lua` drives both help and registration, so they
cannot diverge) and every documented key is correct except one — while
**commands have no such seam**, being ad-hoc `M.cmd.X = ...` assignments
scattered across `init.lua`. #206 should fix the seam, not just the text.
