---
id: 000213
status: open
created: 2026-09-02
updated: 2026-09-11
estimate_hours:
github_issue:
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
