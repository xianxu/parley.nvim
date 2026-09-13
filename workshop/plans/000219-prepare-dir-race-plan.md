# Concurrent directory creation implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). Execute this atomic blocker fix in its isolated worktree.

**Goal:** Concurrent directory creation succeeds when the requested directory exists, and genuine failures remain visible.

**Architecture:** A dependency-free filesystem seam owns the literal-path mkdir postcondition. Existing helper.prepare_dir retains expansion, rejection, logging, and resolution; all directory writers share the seam without a logger/helper require cycle.

**Tech Stack:** Lua, Neovim, Plenary.

## Core concepts

There is no new pure entity: this operation is a thin filesystem integration.

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ensure_dir` | `lua/parley/fs.lua` | new | Neovim mkdir and isdirectory |

The seam takes a literal path, returns normally only for an existing directory, and raises the original mkdir failure otherwise (or a contextual error if mkdir returns without creating it). Callers own path policy. Assets preserves its boolean/error interface with pcall.

## Constraints and ordering

ARCH-DRY/PURE: centralize IO without introducing helper/logger cycles or a new path-expansion policy. ARCH-ORDER: absent path -> mkdir -> directory is success; another actor creates before/during mkdir -> directory is also success; file/permission failure -> non-directory is error. Concurrent deletion after return is outside any mkdir guarantee. ARCH-CONSTRAINTS: synchronous setup/write path, one bounded mkdir attempt and postcondition check, no retries or background processes. ARCH-SECURE: literal filenames retain their meaning, no shell expansion or credentials. ARCH-MOCK: deterministic injected interleaving performs a real competing mkdir on a temporary filesystem; no new external binary/service dependency. ARCH-FUNERAL: production creates only preexisting directory families; test temporary roots are removed after each case. ARCH-PURPOSE: sweep all mkdir writers, not only the reported helper.

## Plan

- [ ] Add `tests/unit/prepare_dir_spec.lua`: ensure_dir competing filesystem mutations and mkdir failures → deterministic injected interleaving on isolated temporary roots with postcondition/error assertions. helper.prepare_dir delegation → the same race through the existing path-policy boundary. Observe the race test red before implementation.
- [ ] Add `lua/parley/fs.lua` ensure_dir and delegate helper.prepare_dir's creation to it. Run the focused regression green.
- [ ] Route mkdir sites in `logger.lua`, `file_tracker.lua`, `notes.lua`, `tools/builtin/write_file.lua`, `raw_log.lua`, `issues.lua`, `cliproxy.lua`, and assets.lua through the literal seam. Keep caller return conventions. Test the seam directly and retain full-suite consumer coverage; add a source guard for the singleton mkdir boundary.
- [ ] Enumerate writefile guards: missing note templates and user-created files carry content policy, not directory postconditions; preserve these write semantics. Document every mkdir site in issue Log.
- [ ] Update `atlas/infra/test_harness.md` with regression coverage, run `make -f Makefile.parley test-spec SPEC=prepare_dir`, lint and the complete suite using a temporary forwarding Makefile if inherited peer symlinks are broken. Commit, close via SDLC review, PR and merge.

## Revisions

### 2026-09-13 — PQ-1

Compressed test inventory into named-function strategies; executable cases belong in tests.
