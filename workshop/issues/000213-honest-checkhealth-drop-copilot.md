---
id: 000213
status: open
deps: []
github_issue:
created: 2026-09-02
updated: 2026-09-11
estimate_hours:
---

# make checkhealth honest and remove the copilot adapter

## Problem

`:checkhealth parley` reports green on an install that cannot work, and the
plugin ships a GitHub Copilot adapter that poses as GitHub's own client.

`health.lua:7-42` checks `require`, `setup()`, `curl` and lualine. It misses
what actually goes wrong:

- no enabled provider has a secret that resolves;
- an agent names a provider that is not configured, and `init.lua:875-877`
  removes it from the roster without a word;
- a cliproxy agent is configured but the binary is missing (`cliproxy.lua:83`);
- a binary the plugin shells out to is missing: `git`
  (`git_markdown_source.lua:140`), `rg` (falls back to `grep`,
  `tools/builtin/grep.lua:11`), `pandoc` (`exporter.lua:930`), `sdlc`
  (`artifact_ref.lua:116`, `issues.lua:412`), and `lsof`/`ps`/`sha256sum` for
  managed cliproxy (`cliproxy.lua:749,953,1782`);
- the vocabulary JSON is missing, which hard-fails plugin load
  (`issue_vocabulary.lua:147`; B1, owned by #208).

The Copilot adapter fetches a bearer token from
`api.github.com/copilot_internal/v2/token`, an undocumented internal API, sending
`editor-plugin-version: copilot-chat/0.17.2024062801` and a `GitHubCopilotChat`
user agent (`vault.lua:187-199`). The audit rates it a ToS hazard. It is absent
from the default `config.providers` but still reachable: `init.lua:586` uses a
user's own `providers` table in place of the defaults, and `config.lua:38` ships
`api_keys.copilot = os.getenv("GITHUB_TOKEN")` ready for it.

## Spec

Make `:checkhealth parley` go red for the failures that happen, and stop shipping
the Copilot impersonation.

Health:

- One check per failure above. A missing requirement is an error; a missing
  optional tool is a warning naming what degrades (e.g. "`pandoc` not found —
  HTML export unavailable").
- Credentials: per enabled provider, report whether its secret resolves, never
  its value. Setup clears `config.api_keys` (`init.lua:597`), so the check goes
  through `vault` and reuses its resolver. #204 is reworking secret resolution;
  coordinate with it rather than add a second path (`ARCH-DRY`). A
  command-backed secret (`{ "bw", "get", ... }`) runs a password manager that
  may prompt; decide at plan time whether health resolves it or only checks
  that the command exists.
- Name each agent dropped at setup for an unconfigured provider.
- cliproxy binary: checked only when a cliproxy agent is configured, through the
  resolver at `cliproxy.lua:83`, not a copy of it.
- `sdlc`: checked only where #212's repo detection turns the ariadne surface on.
- Vocabulary: its shape follows #208. If #208 makes loading lazy and non-fatal,
  this becomes a warning; do this part after #208 lands.
- Every check must be seen failing for its intended reason (`ARCH-PURPOSE`: a
  health check that cannot go red is decoration).

Copilot:

- Remove the adapter and what exists only for it: `providers.lua:1023-1061` and
  its registry entry (`:1307`), `vault.refresh_copilot_bearer`
  (`vault.lua:159-216`), `provider_params.lua:62`, `tools/wire.lua:38`,
  `api_keys.copilot`, the copilot cases in `tests/unit/dispatcher_spec.lua` and
  `tests/unit/tool_wire_registry_spec.lua`, the copilot text in
  `atlas/infra/vault.md` and
  `atlas/providers/{architecture,cliproxy-managed,tool_use}.md`, and the
  comments that name it.
- Keep the dispatcher's `pre_query` seam; cliproxy uses it (`cliproxy.lua:9`).
- A config that still names a `copilot` provider gets a clear notice at setup.
  Without one, `providers.get` (`providers.lua:1327`) falls back to the OpenAI
  adapter (deliberately, for custom OpenAI-compatible providers), and requests
  then fail on auth with no hint why. So the fix is a named notice for
  `copilot`, not a change to the general fallback.
- azure is out of scope: undocumented but harmless. It goes with #236.

## Done when

- A deliberately broken install turns `:checkhealth parley` red, and each check
  has been seen failing for its intended reason; the Log records how each was
  broken.
- On a working install every check is ok, or a warning that names what degrades.
- `rg -i copilot lua/ tests/ atlas/` matches nothing but the removal notice and
  its test.
- A setup that still names a `copilot` provider shows the notice, pinned by a
  test.
- `make test` passes.

## Plan

- [ ] Rewrite `:checkhealth parley` with one check per failure; see each go red.
- [ ] Name agents dropped at setup for an unconfigured provider.
- [ ] Remove the copilot adapter, bearer refresh, config key, tests and atlas text; keep `pre_query`.
- [ ] Add the copilot notice at setup, with a test.

## Log

### 2026-09-02

Split out of the `workshop/plans/000206-shipping-surface-inventory.md` audit as Tier 4 plus blocker
B10. Grouped because both are the same debt: things that exist without doing
anything, including a health check that cannot report ill health.

### 2026-09-11

Checked against the code. Copilot is reachable through user config
(`init.lua:586`, `config.lua:38`), not "structurally unreachable" as the audit
said. Agents naming an unconfigured provider are dropped silently at
`init.lua:875-877` (the audit's `:754`). `providers.get` falls back to the
OpenAI adapter for unknown names, so the removal needs a named notice. The
corrections to the rows that moved out are recorded in #236.

## Revisions

### 2026-09-11 — narrowed to the v1 blockers; dead-code sweep split to #236

**Reason.** The operator ruled that the dead-code sweep should not block the
parley v1 release, and neither should #115. Unused modules cost users nothing.
An honest `:checkhealth` is v1 Requirement 4 ("`:checkhealth` can go red"), and
the Copilot impersonation is a ToS hazard on a public repo.

**Delta.**

- Kept: the `:checkhealth` rewrite (B10) and the copilot removal.
- Moved to #236, outside v1: `discovery/`, `spinner.lua`,
  `test_agent_picker.lua`, `google_drive.lua`, the `review.lua` shim, the two
  dead config keys, azure, the panvimdoc markers, and the reachability and
  coverage criteria.
- Moved to #211: `voice_apply`, which duplicated its voice-skill row.
- File renamed from `000213-dead-code-and-honest-health.md`, since the slug
  becomes the branch name.
