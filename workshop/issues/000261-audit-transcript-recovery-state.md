---
id: 000261
status: working
deps: []
github_issue:
created: 2026-09-15
updated: 2026-09-17
estimate_hours:
started: 2026-09-17T08:07:29-07:00
---

# Audit transcript as the complete recovery state

## Problem

After the recent generation/document refactor, a chat can become stuck in a
state that is not explained by its Markdown transcript. The observed case was a
question that could no longer be submitted and reported an error after the
transcript had been edited during generation. The intended recovery was simply
to quit Parley and reopen the transcript, but the current session did not
reliably recover that way.

This suggests that generation, pending-batch, document, or presentation state
can remain authoritative outside the transcript after an interrupted or
conflicting edit.

## Spec

Audit every state that can block submission, retain a generation, or surface a
failure after a user edits the transcript during generation. Classify each
piece as either:

- durable transcript state that must be reconstructible from the Markdown file;
- disposable runtime state that must be invalidated or recomputed on reload;
- external/recovery state that needs an explicit durable artifact and clear
  reconciliation rule.

The transcript is the source of truth for exchange identity, content,
completion/error markers and the next legal action. Quitting and reopening the
same transcript must discard stale in-memory authority and produce a usable
state, without silently losing authored text or completed output. If an
in-flight operation cannot be represented in the transcript, its interruption
must leave a deterministic recoverable outcome rather than a hidden blocker.

Cover edits during streaming, cancellation, failed submission, partial output,
reload/detach, and reopening after a process crash. Preserve the ability to
retain answer-recovery data where the transcript alone cannot yet contain the
bytes, but make that relationship explicit and restart-safe.

## Done when

- An inventory maps every submission-blocking or generation-related state to its
  durable transcript representation or explicit runtime invalidation rule.
- Editing the transcript during generation cannot leave a hidden stale state
  that survives quit/reopen or prevents a valid later submission.
- A quit-and-reopen cycle reconstructs exchange identity, pending/error outcome,
  and legal submission actions from the transcript and documented recovery data.
- Regression tests cover edits during generation, partial/failed output,
  cancellation, reload/detach, and reopen recovery.
- User-visible errors identify the recoverable action and do not leave an
  unexplained permanent blocker.
- Atlas documents the transcript/runtime/recovery boundary and the restart
  invariant.

## Plan

- [ ] Trace the recent document/generation refactor and inventory hidden state,
  ownership, invalidation and persistence paths.
- [ ] Reproduce the reported edited-during-generation stuck transcript and
  compare same-process recovery with quit/reopen recovery.
- [ ] Define the transcript source-of-truth and explicit runtime/recovery state
  contract; fix any state that violates it.
- [ ] Add stateful integration coverage for interruption, edit conflicts,
  reload/reopen and subsequent successful submission.
- [ ] Update atlas documentation and run the relevant full verification suite.

## Log

### 2026-09-15

Filed from an operator report after the recent generation refactor. Editing the
transcript during generation left a question unable to submit and showing an
error; the desired invariant is that quitting and reopening the transcript
reconstructs a healthy state from durable transcript/recovery data.
