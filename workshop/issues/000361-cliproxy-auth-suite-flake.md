---
id: 000361
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'd5bd45bdce69dee55b9a5a4f1e90f8de3be6f86d' # card fields mirrored from issue-cards; edit via sdlc
---

# Cliproxy expired-token recovery intermittently retries instead of prompting

## Problem

tests/integration/cliproxy_auth_login_spec.lua intermittently fails “claims the #197 503, prompts the right login, and reports the real reason” at line128: expected settled=give_up for the fake expired OAuth credential and dismissed login, observed settled=retry. The whole spec passed on a focused run of the exact same head. This independently blocks #353's suite; it is not folded into the breadcrumb implementation.

First seen: 2026-10-16 during #353's final-head full suite. Head: f4239bccc3af35cd6fd0cbe65fafb1f128b45bb1. Failed run finished with446 spec files passing, two failing, lint749 clean and no surviving processes.

Retained failed-suite log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/bd9f02e9a941c6a23073857764765ecb.log (SHA256 3c666a396002ea5ad421f2d8042d2bb452182ddea7f675de21a3b2607d7a470a). Same-head focused rerun of both affected specs passed all43 cases: /tmp/parley353-cliproxy-repro.log. Earlier full suite on ed5af56cef2c8b6b917f0bd932eb18c1a36c0591 passed448/448; the only subsequent production change returns a snapshot failure reason in file_history.lua. Cliproxy source and these spec files are unchanged by #353.

## Spec

Determine why an expired-channel fake credential can take the retry branch under full-suite load instead of reaching its login prompt. Capture the real credential-health/request outcome before changing timing; distinguish unavailable HTTP evidence, state leakage and deliberate retry behavior. Do not suppress the assertion or raise a blind timeout.

## Done when

- A controlled adversary reproduces the wrong recovery decision and identifies its boundary evidence.
- Fix the causal fixture or production policy with a deterministic guard; preserve real healthy-credential retry behavior.
- Focused real-fake recovery tests and the declared suite pass with retained evidence.

## Plan

- [ ]

## Log

Filed under the test-economy flake rule after one failed full run and one same-head focused pass; root cause not yet established. No production fix or waiver claimed.
