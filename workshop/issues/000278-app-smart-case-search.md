---
id: 000278
status: working
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T23:34:16-07:00
flow: {kind: quick, provenance: inferred, spec: "f0dd18db", done: "4f4e3c8d"}
---

# Enable smart case search in the app

## Problem

The app should use smart case for default text search.

## Spec

Enable Neovim ignorecase and smartcase in the packaged starter (ARCH-DRY).
Lowercase searches ignore case; searches containing uppercase match case.

## Done when

- App searches use smart case; lowercase and mixed-case searches are verified.

## Plan

- [ ] Set starter options, document behavior, and verify using Neovim search.

## Log

### 2026-09-25
