---
id: 000360
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'a75dc2b2555ad33d761d20e696c76c2055acd6fb' # card fields mirrored from issue-cards; edit via sdlc
---

# Cliproxy catalog joins-routes case intermittently returns empty under suite load

## Problem

tests/integration/cliproxy_catalog_spec.lua intermittently fails “joins both routes and caches the result to disk” at line75: fetch_catalog resolves to an empty model list after the process-level fake reports listening. The whole spec passed on a focused run of the exact same head. This independently blocks #353's suite; it is not folded into the breadcrumb implementation.

First seen: 2026-10-16 during #353's final-head full suite. Head: f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1. Failed run finished with446 spec files passing, two failing, lint749 clean and no surviving processes.

Retained failed-suite log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log (SHA256 3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a). Same-head focused rerun of both affected specs passed all43 cases: /tmp/parley353-cliproxy-repro.log. Earlier full suite on ed5af56cef2c8b6b917f0bd932eb18c1a36c0591 passed448/448; the only subsequent production change returns a snapshot failure reason in file_history.lua. Cliproxy source and these spec files are unchanged by #353.

## Spec

Determine why the ready fake/catalog HTTP routes can yield an empty catalog under parallel suite load. Capture request/result/timing evidence at the production seam; distinguish a readiness race from bounded HTTP request expiration or shared state. Keep operator endpoints and credentials isolated.

## Done when

- A controlled test reproduces the failing dependency state without relying on blind full-suite retries.
- Fix readiness/deadline/state ownership at its cause; preserve intentional unreachable-proxy behavior.
- Focused real-fake catalog tests and the declared suite pass with retained evidence.

## Plan

- [ ]

## Log

Filed under the test-economy flake rule after one failed full run and one same-head focused pass; root cause not yet established. No production fix or waiver claimed.
