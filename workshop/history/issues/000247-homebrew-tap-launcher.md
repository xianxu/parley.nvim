---
id: 000247
status: done
deps: [000246]
github_issue:
created: 2026-09-13
updated: 2026-09-14
estimate_hours: 4.159
started: 2026-09-13T14:26:40-07:00
actual_hours: 11.92
---

# Homebrew tap and parley launcher: brew install xianxu/parley/parley, tested on a clean tart VM

## Problem

The `parley-packaging` project's end state: `brew install xianxu/parley/parley`
followed by `parley` starts a working chat for someone who has never used
Neovim, with Claude, Codex and Gemini available through the managed cliproxy
and no API key typed.

## Spec

- **A personal tap** (`xianxu/homebrew-parley`): Homebrew core will not take
  an editor-plugin app, and a tap keeps the release cadence in our hands.
  The formula depends on `neovim` and on the advisory tools #245 lists for
  macOS (ripgrep; ImageMagick only if #244 needs it beyond `sips`), installs
  the starter config from #246 as the app's config under
  `$(brew --prefix)/share/parley/config`, and installs a `parley` launcher.
- **The launcher**: `NVIM_APPNAME=parley` with `XDG_CONFIG_HOME` pointed at a
  per-user copy of the starter config (first run copies it to
  `~/.config/parley/` so the user may edit it; later formula upgrades never
  overwrite an edited copy — they place a `.new` beside it). Arguments pass
  through to nvim, so `parley notes.md` works.
- **cliproxyapi stays parley-managed** (downloaded on first use, updated by
  `:ParleyProxy update`) — it is not a formula dependency, by operator
  decision: its configuration is complex and parley owns it.
- **Testing on a clean machine** is part of the definition of done, not a
  manual step: a `tart` VM image with macOS and Homebrew, no `~/.config/nvim`,
  runs the formula install and a scripted first chat (headless nvim,
  `:ParleyProxy login` cannot be automated — the login step is asserted up to
  its prompt; a provider with an API key in the VM's keychain covers the send)
  plus the "existing `~/.config/nvim` untouched" check with a decoy config.
- A release process: tagging the plugin publishes a formula bump (a script
  in this repo writes the tap's formula with the new tag and sha256).
- Explicitly out for now: Linux and Windows packaging; auto-upgrading
  advisory tools.

## Done when

- The project's `done_when` holds on the tart VM: install, `parley`, a
  provider login reaches its prompt, a question with a pasted image is
  answered through a keyed provider, and a decoy `~/.config/nvim` is
  byte-identical afterwards.
- `brew uninstall parley` plus removing `~/.config/parley` and
  `~/.local/share/parley` leaves no trace.
- The formula's dependency list matches #245's advisory tier (test).
- The tag→formula bump script is documented and used for at least one release.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only; calibration remains provisional. Formula maps
to a smaller module (base design 0.15h, impl 0.35h). Launcher maps to one API/IO
integration (1h/0.75h), release orchestration to API integration (1.5h/1h), and
VM orchestration to API integration (2h/1.5h). Guest chat acceptance maps to one
Lua feature (2h/1h). Docs use 0.1h/0.1h; review 0h/0.35h; two live discovery
surfaces use 0h/0.45h each; the generated tap handoff uses small cross-repo
coordination 0.2h/0.2h. Detailed approved contracts apply ×0.2 design discount;
v3.1 applies ×0.4 implementation scaling. Familiarity is 1.0 (existing shell,
Neovim and Git patterns); mature brew/Tart/gh CLIs avoid a novel VM API client.
15% design buffer, no vendor propagation multiplier. Operator OAuth availability
is an external dependency, not fabricated active implementation hours.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: smaller-go-module design=0.03 impl=0.14
item: api-integration design=0.2 impl=0.3
item: api-integration design=0.3 impl=0.4
item: api-integration design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.4
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0 impl=0.14
item: real-api-discovery design=0 impl=0.18
item: real-api-discovery design=0 impl=0.18
item: cross-repo-refactor-small design=0.04 impl=0.08
design-buffer: 0.15
total: 4.159
```

## Plan

- [x] Tap repo + formula skeleton depending on neovim; launcher script
- [x] First-run copy of the starter config; upgrade never overwrites
- [x] tart VM recipe: image, install, scripted first chat, decoy-config check
- [x] Release bump script; README install section (brew path first)

## Log


- 2026-09-14: closed — Streaming integration tests passed for shared cursor-follow default; app inheritance asserted; git diff --check clean. Fresh-machine acceptance remains pending; acceptance checkboxes and project completion deliberately remain open.; review verdict: SHIP
### 2026-09-13 — implementation and VM checkpoint
- 2026-09-13: closed — Full make test passed (/tmp/parley-shared-verified.log); subsequent explicit-global-path repo regression passed starter_project 5/5; git diff --check clean. Fresh-machine operator acceptance remains pending, so project completion and acceptance checkboxes deliberately remain open.; review verdict: FIX-THEN-SHIP
- 2026-09-13: closed — Bootstrap real-float regression7/7, login15/15, login UI4/4, catalog66/66 pass; full suite only found two corrected architecture integration failures, both rechecked passing. Exact release archive suite /tmp/parley-v2.4.1-archive.log must pass before tagging. User authorizes fresh-machine testing publication; live acceptance plan/project remain unchecked and PR remains open.; review verdict: SHIP
- 2026-09-13: closed — Committed archive passed all 254 test files and lint 444 files. Review fixes pass starter 16/16 and packaging VM 17/17 including real Tart conformance; final corrected archive suite in /tmp/parley-v2.4.0-final-archive.log must pass before tag. Plan/project checks remain open because operator requested publication for fresh-machine acceptance; no merge/archive until acceptance completes.; review verdict: SHIP
- 2026-09-13: closed — Code findings BR1-BR3 all disposed round3; Codex reviewer failed only because its sandbox denies loopback binds. Normal host rerun at reviewed9202b955 passed all11VMcases, exact log /tmp/parley247-reviewed-head-vm.log. Full246specs/lint431 and focused2formula+6release+3upgrade pass. Please verify loopback with supported Claude runner. Approved tag/tap publication then realVM acceptance remain before merge; --no-plan-check only local gate.; review verdict: FIX-THEN-SHIP

Operator approved implementation with “continue”; #246 is merged as PR #180
and released v2.2.0. #247 passed change-code plan quality round 1 and estimate
gates. Formula/release tests pass (8 cases); launcher passes 10 adversarial
filesystem/process cases, including the owner-record initialization race found
and repaired during testing. VM harness tests pass 7 cases; actual upgrade and
final removal verification are being integrated.

One owned clean VM is booted and guest Homebrew is ready. Its manifest is
`/private/tmp/parley-vm-247-20260913/manifest.json`; reservation is
`~/.cache/parley-vm-acceptance.owner`. Resume through the harness; preserve
`tools-test` and the cached image. Clone observed 184320 bytes additional disk
allocation with auto-pruning disabled. No public tap has been created yet.
Actual managed-proxy OAuth and image response remain pending guest login.

### 2026-09-13 — local checks

Launcher preparation measured over 20 warm runs: median 16.1 ms, maximum 20.1 ms.
Lint passed 428 Lua files plus all three packaging Lua files. First full suite
passed behavioral specs; the architecture-only failure identified omitted
packaging scan scope and missing traceability. Corrected both; all 21 focused
architecture checks now pass. Final VM reducer and guest upgrade conformance
remain in progress before the local close review.

### 2026-09-13 — local implementation accepted by tests

Final make test passed all 246 spec files and lint across 431 Lua files.
The owned VM harness now requires five evidence records and successful VM
removal before reporting completion. Actual public tap installation, real guest
Homebrew upgrade and managed OAuth/image response follow the local review under
the approved plan; these remain unchecked and must precede merge. The local tap
README and generated formula shape are reviewable; the real archive SHA is only
available after the reviewed immutable tag is published.

### 2026-09-13 — close review round 1 repaired

BR-1 installed-layout-conformance: reproduced the missing-starter failure with
an actual prefix/share vs libexec fixture, then read the installed share source
and made both fixture versions move it as Homebrew does. Public restoration now
runs the real launcher. All 3 upgrade cases pass, including a failure assertion
that proves brew upgrade itself was reached. BR-2 pure-test-io-separation:
moved Ruby syntax execution to release integration; 2 pure renderer and 6 release
cases pass. Lint remains clean across 431 files. Both finding classes are recorded
in lessons; public/live acceptance is still pending the reviewed release.

### 2026-09-13 — close review round 2 repaired

BR-1 and BR-2 were accepted as addressed. BR-3 found fake VM tests still consumed
the host's real disk budget. The VM entry now accepts an injected capacity probe;
its test-only runner supplies deterministic capacity and proves 59 GiB refuses
before any Tart call while releasing ownership. The production entry still uses
actual disk capacity with no bypass CLI/environment input. Test-first runner
failed before the seam; all 11 VM cases now pass. No real VM state was changed.

### 2026-09-13 — FIX-THEN-SHIP corrections verified

The alternate reviewer passed all packaging tests including loopback and returned
FIX-THEN-SHIP. BR-4 now models Tart's exit 2 for unknown stop/delete, confirms
absence before releasing a reservation, and retains ownership if deletion fails.
BR-5 adds persistent --keep-on-failure with safe phase/command/reason evidence
and retained guest logs. BR-7 selects canonical model providers, tested with a
healthy but empty Codex catalog. BR-8 uses one release-local rendering entry and
one upload helper. BR-6 remains an explicit final acceptance gate: project row
is unchecked until public install, actual upgrade, live image response and
uninstall/owned-VM cleanup all pass.

Final verification after these fixes: make test passed 247 spec files and lint
433 Lua files. Real Tart 2.32.1 unknown-resource stop/delete both exit 2, matching
the fake. The fixes and close metadata are bundled into this single commit per
the gate's post-verdict protocol. Publish the reviewed tag/tap next, then run the
retained clean VM with --keep-on-failure for conformance diagnosis. No merge yet.

### 2026-09-13 — public release and actual guest conformance

Published v2.3.0 at 67d14b6fae8f9b830110091dbb5315cc588001c6 and public
xianxu/homebrew-parley at 59fa5f6. Release script generated, reviewed and published
archive SHA256 b8f2b2ada24adbe48dcf831896e8a7c28c76dc7d7e76648ccc34c45fb5e72631.
PR #181 is open; CI run 34790826347 passed. Actual guest installed Parley 2.3.0,
Neovim 0.12.5_1 and ripgrep 15.2.0 and opened the welcome chat.

Actual boot exposed an acceptance-probe typo (:Parley vs shipped :ParleyConnect).
A real launcher/starter regression reproduces it and passes after correction.
The retained install can now resume in the same owned VM, checking its existing
decoy hash before retry; 16 VM harness cases pass. Guest boot/containment/decoy
acceptance now passes. These post-close harness fixes need delta review before
merge; released application code has not changed.

Guest fake first-use is blocked by Python HTTPServer reverse-DNS startup: a
real process sample shows socket_gethostbyaddr -> mdns_hostbyaddr before listen.
Direct socket binding works and guest firewall is disabled. Fix the local fixture
server's unnecessary DNS dependency; do not change product proxy networking.
The real brew upgrade phase is in progress. Retained VM/manifest ownership is
unchanged; --keep-on-failure has preserved diagnostic evidence. Live OAuth and
image response remain pending, and the project stays unchecked.

## Revisions

### 2026-09-13T14:43:00-07:00 — packaging execution scope

The operator confirmed #246 then #247. The formula uses #245's default
Darwin projection (ripgrep) plus Neovim; alternate image backends stay optional.
This supersedes all-advisory dependency parity in the original spec.

The implementation plan is [Homebrew launcher](../plans/000247-homebrew-launcher-plan.md).
The launcher respects standard XDG roots, preserves editable init.lua and offers
one atomic init.lua.new candidate. Removal covers config/data/state/cache after
explicitly stopping the owned proxy. These supersede the original XDG_CONFIG_HOME
wording and two-directory removal shorthand.

Live VM acceptance must complete the shipped managed-proxy login → live model →
image-response path. A direct keyed-provider response cannot substitute for it.
A VM credential is usable only if it authenticates that same managed proxy;
otherwise the operator completes OAuth in the guest. That input remains pending.
Fresh-context plan review completed; implementation approval is pending.

### 2026-09-14 — operator VM acceptance and simplified defaults

The user completed managed Claude login and text response in their own
`parley.nvim-test` VM, then reproduced successful define integration with explicit
port/key overrides. They requested default port 8317, `parley-local`, all Ctrl+g
bindings and Alt chords. The starter now implements those defaults, removes its
generated-key owner, and preserves private profile data permissions. Old key files
are ignored. Two unit cases and eleven isolated startup cases pass, including
actual shortcut registration and an existing-key profile; changed-file lint and
diff checks pass.

Stopped the VM's old owned proxy and overlaid only the two updated starter
modules in its installed v2.3.0 runtime for acceptance. The installed define,
with DEFINE_LLM_BASE_URL, DEFINE_LLM_API_KEY and Anthropic credentials unset,
returned PONG on port 8317 in 1.082 seconds. The same VM verified Ctrl+g f/c/?,
Ctrl+g Ctrl+g and Alt+Return/v/t mappings. This is a test overlay, not a published
Homebrew upgrade. A new reviewed release remains required; image/upgrade/removal
acceptance remains pending. Other running VMs were untouched.

### 2026-09-14 — flat welcome and automatic onboarding verified

The user's local welcome conversation was invisible because finder discovery is
nonrecursive. Per their revised request, new profiles now create `chats/welcome.md`
with setup instructions before an example question. Chat filename recognition is
shared by attachment, topic lookup and finder discovery. Legacy `chats/welcome/`
transcripts migrate through the existing tree mover, preserving contents/assets
and refusing clashes; empty containers are removed. Existing welcome.md contents
are preserved. The generated preamble is excluded from the parsed question.

Interactive startup without a real selected model now opens the existing model
picker when a connected provider serves models, or Connect when account setup is
needed. Successful login opens the picker; network failures remain errors,
cancellation is respected, and headless startup is silent. The placeholder is
hidden from selectable agents. Ctrl+g and Alt shortcuts are derived through the
registry resolver. Verification: `make test` passed all 249 spec files and lint
435 files (`/tmp/parley247-first-use-full.log`); 13 onboarding cases and 12 isolated
starter cases cover the flow. These changes are not yet a published Homebrew
release and have not been applied to the user's local installation.

### 2026-09-14 — floating provider picker

Per user request, Connect now uses the same float_picker component as the agent
selector, with stable provider IDs, filtering and selection recall. Cancellation
clears the in-flight prompt, while successful login still opens the model picker.
Verified 14 onboarding cases and 12 starter integration cases. The integration
probe opens the real floating window and invokes its Enter mapping before
checking managed download/login; failure coverage also passes. Changed-file lint
and diff checks pass. This UI change is local and pending release with the other
first-use corrections.

### 2026-09-14 — action fallback and source-profile launch

Implemented provider-scoped model selection and `:ParleyProxy connect`; removed
the standalone Connect command. Semantic LLM entry points defer before building
requests and resume only with unchanged source context. Regression proves a real
chat request uses the newly selected model (13 starter integration cases pass).
Dedicated profile now disables both chat_memory and memory_prefs; regression
failed before adding chat_memory=false. Checkout launch documented using
NVIM_APPNAME=parley PARLEY_RUNTIME=$PWD and the packaged init.lua. Latest full
verification pending; all changes remain unpublished.

Verification follow-up: full test run had one architecture documentation failure
(missing agent_picker row in Core concepts); added that row and all 21 architecture
cases pass. All other spec files passed that run. The 13 starter integration cases
pass again with effective chat_memory=false and memory_prefs=false assertions.
Two starter policy cases and 17 onboarding cases pass. Logs:
`/tmp/parley247-fallback-full.log`, `/tmp/parley247-fallback-arch.log`,
`/tmp/parley247-memory-starter.log`. No release or local installation updated.

### 2026-09-14 — product boundary and configuration ownership

User clarified that Homebrew Parley is a standalone app backed by Neovim, while
parley.nvim is independently configurable inside an existing editor. Expanded
atlas/infra/starter.md with ownership, release behavior, regression coverage and
the direct-checkout test command; linked it from the atlas index and configuration
map. Recorded shared portable defaults as intended direction, with current
differences explicit and #211 as the existing personal-default migration work.
No plugin defaults or personal machine configuration changed in this docs pass.

### 2026-09-14 — picker fallback when account checks are unavailable

User acceptance showed a blocking account-health error instead of setup UI.
Unknown health now falls through to catalog discovery; usable models open the
provider-scoped agent picker. Unavailable catalogs or initial proxy startup
open provider selection without duplicate setup errors. Explicit login retains
its operational error reporting. Cancellation/resume callbacks stay intact.
Regression first reproduced four failures under the previous policy.

### 2026-09-14 — bundled help approved by user

Approved design and test steps: workshop/plans/000247-homebrew-launcher-plan.md,
section “approved bundled product help”. Add a fixed shipped Markdown guide,
parley_help topic tool (index/read, no arbitrary file paths), and overview-derived
introduction with current app/plugin mode. Enable only this help tool in the app;
plugin @all defaults discover it without widening explicit custom tool lists.
Update welcome question; verify dispatcher reads, invalid topic rejection, prompt
context and actual starter live agents. This extends the approved first-use work.

### 2026-09-14 — implemented README/atlas help

User revised documentation source to existing README and atlas. Added marked
README introduction, post-resolution app/plugin context, and parley_help topic
listing/reading. App live and placeholder agents expose only help; plugin @all
discovers it while explicit tool lists remain unchanged. The module reads only
README and atlas-indexed Markdown under its own runtime, bounds size and rejects
symlink redirection. Lua source already ships but is not exposed by help.
Changed the new welcome question. Added parser and real dispatcher tests, prompt
precedence/idempotence/opt-out, invalid input and missing-doc cases. Fresh review
found two stale atlas links; regression reproduced them, index corrected and all
advertised topics now read successfully. Recorded prevention in lessons.
Focused help (6), config-tools (26) and actual starter (13) cases pass. Broader
verification log: /tmp/parley247-help-full2.log. Changes remain unreleased.

Final verification: full make test exited 0, all 253 spec files passed; lint checked 443 files with zero warnings/errors.

### 2026-09-14 — MarkdownPreview app dependency

Added pinned iamcco/markdown-preview.nvim to the app bootstrap with explicit
manual startup and localhost-only defaults. Uses upstream versioned prebuilt
installer (120s timeout) plus binary version check (5s), no Node/Yarn dependency.
Bootstrap stateful installer fixture covers success, failed download and wrong
version. Six bootstrap cases pass; changed-file lint, artifact scan and diff
checks pass. Live isolated Apple Silicon conformance downloaded server 0.0.10,
started preview, fetched actual HTML and stopped it; no browser opened. Log:
/tmp/parley247-preview-live.log. Docs describe commands and retry. Source profile
updated; Homebrew release not yet published.

### 2026-09-14 — MarkdownPreview Lazy build E117

User hit Unknown function mkdp#util#get_platform in Lazy build. Root cause:
function builders run before plugin autoload files are loaded; earlier smoke
preloaded plugin and fixture stub hid the dependency. Removed that call and
derive installed binary platform using Neovim host information. Regression now
builds with no mkdp functions present: failed before fix, all six bootstrap
cases pass afterward, including installer and version-check failures.

Live verification through actual Lazy build passed without preloaded autoload
functions; preview served HTML and stopped cleanly. Log:
/tmp/parley247-preview-lazy-live.log. Changed-file lint and artifact scan pass.

### 2026-09-14 — stable basics tutorial name

Renamed the user's second tutorial to basics.md, preserving the active buffer
and its edits through the app's RPC server. Added filename explanation to its
preamble. Chat recognition and Finder now accept basics.md alongside welcome.md;
ordinary chat names remain timestamped. Tests verify named-chat recognition,
Finder discovery and no topic-slug rename. Thirteen starter integration cases
and the chat-finder suite pass. Second tutorial remains locally authored, not
yet part of automatic fresh-profile seeding.

### 2026-09-13 — Advanced tutorial and app path behavior

Created the locally authored advanced.md tutorial (topic 3. Advanced), linked
from basics.md, covering transcript context, outline/branches, marker-only
project folders, repo-root tool paths, local file/chat-search tools, and image
pasting with Option+v. Named tutorials remain separate from automatic seeding.
Image exercise starts a timestamped chat, which supplies the attachment ID.

Enabled everyday app tools and removed implicit sibling read access; chat-history
tool searches obey trusted dispatcher root policy. Ordinary Markdown navigation
links now resolve beside their source document. The starter detects .parley
without requiring Git and applies project chat storage despite its global
fallback chat directory. Atlas and regression coverage describe these rules.

Verification: make test with local Plenary passed (exit 0), log
/tmp/parley247-advanced-final.log. The architecture producer inventory and the
explicit-sibling completion fixture were updated for the intentional changes.
Headless parser verified advanced.md is recognized and has one exchange;
git diff --check passed. These changes remain local and unreleased.

### 2026-09-13 — v2.4.0 release review passed

Bundled all three authored tutorials, preserving only their preambles and initial
questions. Missing tutorials seed atomically beside their destination, including
projects on another filesystem; existing edits survive startup. Review corrections
cover EXDEV and failed-publication cleanup, real Tart missing-resource conformance,
and integration classification of auth metadata checks.

Exact corrected commit d682f69d passed all 254 test files and lint (444 files,
zero warnings/errors) from an isolated archive; log
/tmp/parley-v2.4.0-final-archive.log. SDLC boundary review returned SHIP, no open
findings. Project checkbox restored to pending because fresh-machine acceptance
is the user's next step. Publication authorized; PR remains open, no archive.

Published v2.4.0 at source commit 3f5b0b8c; GitHub release is public and the tap
commit is 66c6b86. Downloaded tagged archive SHA256:
03bf478df6fb8c4f3ef677a06b2d2ab29ce6381cbf0a26eda479ea331ca89e61.
Ruby syntax passed; GitHub API formula bytes exactly match the rendered formula.
Fresh-machine install command: brew install xianxu/parley/parley. User acceptance
remains pending; no local Homebrew reinstall or operator profile reset performed.

### 2026-09-13 — fresh-machine usability corrections

User found welcome in Lazy's installer float on first launch. Bootstrap now
restores the captured main window before starter opens the chat and closes Lazy's
view through its lifecycle API. Real-float regression failed before and passes
after, including cached startup (bootstrap 7/7).

Replaced interactive login log dumps with a disposable friendly progress view:
browser open/copy, visible device codes, optional details, dismiss and explicit
cancel. Existing process completion latch remains owner; headless diagnostics
stay available. Login integration 15/15 and presentation 4/4 pass.

Actual proxy v7.3.2 Codex rows reproduce equal-date alphabetical omission of
Astra. GPT numeric-version ties now prefer newer versions. User clarified three
results per search: each configured term gets its own legacy per_provider quota,
with order and deduplication preserved, and app reuses product search terms.
Catalog 66/66 and starter option regressions pass. Related #230 remains open for
its separately proposed !N syntax. Full archive verification precedes publication.

User reviewed configuration convergence: shared response prompt/📝 summaries,
web search and @all tools; automatic memory off; remove ToolOpus; shared default
model searches. Personal chat/notes and blog export paths remain local. The same
agent picker now handles missing setup for app and plugin. Shared auth explicitly
uses ~/.cli-proxy-api; legacy profile credentials copy without overwrite.

Verification: full `make test` passed after shared-default and unified-picker
fixture updates (log /tmp/parley-shared-verified.log). Subsequent personal repo
selection regression passed with starter project suite 5/5. Live map inspection
confirmed the reported Ctrl+g a issue was Markdown add-reference binding caused
by explicit global chat_dir suppressing implicit repo selection; personal config
now selects the marked root through the shared helper.

Boundary review returned FIX-THEN-SHIP with BR-11: outdated credential ownership
and deletion claims. Updated both packaging guides consistently: shared OAuth
credentials live outside app roots and survive removal. Review independently
passed 163 starter checks, 69 packaging checks and lint. Fresh-machine acceptance
remains open.

Published v2.4.1 at bcbb0143; Homebrew tap ce28540. Public release and exact
remote formula bytes verified; source archive SHA256
177b39288912af98e8686a90408ef5d87aeaf3d166ac81921972dbe816b29ad7.
PR #181 remains open pending fresh-machine acceptance.

User requests publication of cursor-follow enabled by default. Shared
chat_free_cursor=false is inherited by the app; saved preferences still override
the default. Existing streaming integration suite passed; release archive checks
and boundary review precede v2.4.2 publication.

Cursor-follow release: clean archive full suite passed at 75831f56; boundary
review returned SHIP. Fresh-machine acceptance remains pending.

Published v2.4.2 at 1e4e8b38; Homebrew tap 0b9d266. Verified public release
and exact remote formula bytes after publication.

### 2026-09-14 — operator acceptance and closure

Operator confirms: “I tested #247 enough, I think we can close it now.”
The tap/launcher, first-run preservation, VM recipe and release tooling have
shipped and passed automated checks; unchecked delivery rows were stale.
The public release is v2.4.2. Latest exact-source archive passed the full suite
and boundary review returned SHIP; PR #181 CI is green.

Acceptance revision: the operator's VM/fresh-machine/local testing and explicit
acceptance complete the release gate. This supersedes the earlier requirement
for an outcome=complete unattended VM manifest; no unobserved manual subtest is
claimed. Shared ~/.cli-proxy-api credentials intentionally survive app removal,
as agreed and documented, superseding the original “leaves no trace” wording.
