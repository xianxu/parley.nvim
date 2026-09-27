---
id: '000205'
status: done
started: 2026-08-31T18:19:21-07:00
created: 2026-08-31
updated: 2026-09-01
estimate_hours: 4.61
actual_hours: 15.44
---

# live cliproxy model picker; retire hardcoded model lists

## Problem

Every cliproxyapi model parley can reach is named twice in `lua/parley/config.lua`:
once in `cliproxy.config["oauth-model-alias"]` and once per agent entry. cliproxyapi
already advertises its catalog, and the per-model config parley adds is minimal
(a name, a tool set, a web-search strategy), so the duplication buys nothing and
rots: as of 2026-08-31 the block lists `claude-fable-5` twice and pins
`claude-opus-4-8` while the proxy advertises `claude-opus-5`, leaving all three
Opus agents a model generation behind without any visible signal.

Evidence gathered against the live proxy on 2026-08-31 (running parley's own
rendered config — wrong bearer → 401, `parley-local` → 200):

- **The alias block is not needed for routing.** `claude-opus-5` and `gpt-5.5`,
  neither listed, both answered normally. `gemini-3.1-pro-preview` (channel not
  declared at all) reached Google and returned an upstream *license* 403 — i.e.
  routing worked. The comment at `config.lua:133` ("Without this, cliproxyapi
  answers `unknown provider for model claude-…`") was verified against 7.1.71 and
  no longer holds; cliproxy resolves from its own registry.
- **The block has exactly one live job left in parley**: `cc.resolve_channel` at
  `cliproxy.lua:1236`, answering "which login does this model need" when a
  credential fails.
- **The catalog is self-updating.** An antigravity login registered mid-session
  through the proxy's own file watcher: 30 → 43 models, no restart.
