---
id: 000418
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '245e69b1971000902b3c17d77f2a2f5f2912506a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T00:21:40-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# First Alt+Return on a file adds or merges the required front matter

## Problem

## Spec

Operator request (10-22): the **first time** the operator presses **Alt+Return** on a file (submitting it to the agent
in the same pair session), parley checks that the file has the front matter a submitted/registered document needs; if
it has none, parley adds it; if it already has front matter, parley **merges** the required fields into it (adding
missing keys, never overwriting or dropping the operator's existing keys or values).

- "Required" is whatever Couch's session-sync registration and the submit path need (today a plain side doc can be
  refused with "is not a session-sync file (frontmatter `type: session-sync`)"); derive the set from that contract,
  don't invent one. Where a value can't be inferred, leave the file unsubmitted and say which key is missing.
- Idempotent: later Alt+Returns on the same file change nothing if the fields are present.
- The front-matter edit is a normal buffer edit (undoable), done before the submit, and saved with the submit.
- Related: parley.nvim#410 (unregistered typed files show "not protected" until the first submit registers them).


**Operator addition (10-22, night):** whenever front matter is filled in for a document (a new session file or side doc, or the first Alt+Return adding missing front matter), it lists **all three mode keys with their default values written out** (`collaboration-mode: discussion`, `presentation-mode: highlight`, `processing-mode: free-form`), as a visible reminder that they can be changed. Merging into existing front matter adds any missing ones the same way and never changes values already set.

## Done when
- New or filled front matter lists all three mode keys with their defaults; existing values are untouched (test).

- Alt+Return on a file with no front matter adds the required fields and submits (test).
- Alt+Return on a file with partial front matter merges the missing fields, keeping existing keys and values exactly
  (test).
- A second Alt+Return makes no front-matter change (test).

## Plan

- [ ] Implement the approved shared [first-submit plan](../plans/000418-first-submit-frontmatter-plan.md), including canonical/legacy readers and additive undoable preparation before save/register/send.
- [ ] Prove this issue's Done-when and #322's separate visible-outcome acceptance on both runtimes, record the required check, obtain the binary-owned close review and complete live acceptance/landing after ariadne#562.

## Log

### 2026-10-22

### 2026-10-23 — claimed and planned with #322

TL dispatch 24886cea-c7ae-4329-a81f-ec5c69c35332 assigns #418 and #322 together, one plan with separate acceptance. Claimed #418 and started this main-based issue branch; #322 was a wontfix duplicate of #332 and is reopened through the status verb under this new assignment. Current `agentic_document` already saves/registers/submits plain named Markdown without front matter; it needs neither `type: session-sync` nor guessed owner metadata. Existing `review_send` outside-Couch path still requires legacy process-instruction, and `presentation.value` still reads only presentation. No implementation has started.

Coordinated with ariadne:5: #562 defines three canonical scalar defaults, optional processing-instruction, component-wise legacy fallback and whole-document multi-selector fill refusal. TL delivery da9d9e00 approves including existing-reader migration here and reserves section comments/typeahead for #419. #562 reference examples are source fixtures, not manifest exports; pinned-provenance copies are approved. Delivery 7106eb75 confirms TL's presentation policy: canonical presence wins; missing/empty/unknown means highlight, unknown warns without refusing. The [shared plan](../plans/000418-first-submit-frontmatter-plan.md) records the visible-state table, ownership, pure/IO split, alternatives, failure/retry tests and proposed interactive header envelope. Plan goes to TL before change-code; landing waits for #562's landed contract and fixtures, never an unlanded stack. ARCH-DRY and ARCH-EVOLVE require shared effective resolution and additive byte-preserving insertion rather than three literal defaults or YAML reserialization.

### 2026-10-23 — design approved; producer landing prerequisite

Authenticated TL approval 7acabe36-c3b8-4c2a-b70f-33d8f62d5788 accepts the shared resolver/insertion design, current save/submit owner, canonical reader migration, preserved legacy intent, atomic multi-mode refusal, warned highlight fallback and 8192-line/1-MiB header bounds. No new cache/watchers. Exact next step: wait for ariadne#562 to land; verify its landed revision, pin the reference fill fixtures/provenance from main, then run change-code before implementation. The hub will schedule live acceptance with the operator on a session document. No runtime/test implementation has begun.

### 2026-10-23 — producer landed; reference fixtures pinned

Authenticated TL delivery a5452e45-2afd-4b84-a9a1-a397a1f26214 confirms ariadne#562 landed and directs fixture pin/change-code. Git resolves its merge as `4f10a45d038acb2324c5a19e74a78f4a593571e6`, proven ancestor of freshly fetched producer main. Copied all 24 source files across eight editorial-fill cases into `tests/fixtures/editorial_fill/`; `provenance.json` records repository, exact commit, source path, byte length and SHA256 for each immutable oracle. Every copied byte digest verified against that pinned Git blob. These are source reference fixtures, not export-manifest members or an executable producer resolver. Next: full-flow change-code plan-quality gate, then its estimate gate before runtime implementation. No test/runtime code has changed.

## Revisions

### 2026-10-23 — canonical fill and current registration contract

Required submission metadata is the current registry contract, which does not require a type/owner header. The explicit new settings are collaboration-mode: discussion, presentation-mode: highlight and processing-mode: free-form when no current or legacy choice exists. Missing components materialize effective legacy choices instead of shadowing them; preserve existing canonical/alias lines, unknown metadata and body. Optional processing-instruction is filled only from legacy free text. Existing-reader migration is included so these keys work. Section comments, typeahead and external side-doc/session writers remain with #419/#562 as coordinated. Each issue keeps its own Done-when; one plan/branch is the TL's explicit combined-work exception.
