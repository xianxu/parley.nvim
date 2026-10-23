---
id: 000422
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'ee498570148b26dc50d3d74d7d1baa96e3142303' # card fields mirrored from issue-cards; edit via sdlc
---

# Zero-config chat escapes scratch in review clones

## Problem

## Spec

The zero-config chat test must select its disposable scratch storage even in an SDLC review clone. During #405 M2 review it selected the clone's workshop/parley directory instead and created an untracked chat artifact, so the focused target failed despite passing endpoint tests. Determine which repository/config discovery input changes in a review clone and keep test state inside its owned scratch root.

## Done when

- Reproduce through the supported make target in a disposable review-style clone and ordinary checkout.
- A regression asserts chat output stays inside the harness-owned scratch root, with no checkout or operator-state artifact.
- Resolve the root discovery/isolation mismatch; keep real zero-config product behavior intact.

## Plan

- [ ]

## Log

Observed independently in #405 M2 R1 and R2. R2 reviewed head4508683883564bbd676e42c2ee50d15935a95454 against replayed base d4f332353feca049bb17eb68643b40a66176d25d. Its preferred focused mapping had275PASS/1FAIL/0ERROR; zero-config alone at base had8PASS/1FAIL/0ERROR, proving it predates the M2 changes. All process censuses were clean. R1 reported a chat created under workshop/parley in its disposable checkout; R2 removed disposable artifacts. This is review-clone context evidence, not yet an ordinary-checkout reproduction or an established timing flake. See #405's M2 review sidecar for the retained result. No operator file was changed.
