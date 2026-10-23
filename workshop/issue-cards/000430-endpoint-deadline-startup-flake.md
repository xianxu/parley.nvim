---
id: 000430
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/editor_endpoint_registry_spec.lua#editor endpoint registry process boundary joins an admitted absolute deadline while retaining a possibly published binding]
---

# Endpoint deadline test races Python startup and registry publication

## Problem

The #405 endpoint absolute-deadline native test assumes the fake Python process has started and published within 200 ms. An admitted request may legitimately time out before main() writes its PID or before it publishes; the reply gate only holds acknowledgment after publication. This produces false test failures while testing retained possibly-published state.
