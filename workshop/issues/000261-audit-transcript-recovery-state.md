---
id: 000261
status: working
deps: [parley#266]
github_issue:
target: transcript-is-the-whole-truth
created: 2026-09-15
updated: 2026-09-17
estimate_hours: 30.07
started: 2026-09-17T08:07:29-07:00
flow: {kind: full, provenance: inferred}
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
- *(added 2026-09-18, see Revisions)* No on-disk store takes part in
  submission: the answer-recovery subsystem and its commands are deleted, and
  nothing reads `<state_dir>/answer-recovery/`.
- *(added 2026-09-18 — parley#255 folded in)* A request that captures context
  while an earlier exchange's regeneration is incomplete receives that
  exchange's previous complete answer, whole and never mixed with replacement
  fragments — in the same chat, and from a sub-chat whose ancestor chain
  includes it (read from the parent's live buffer when it is loaded). Several
  exchanges regenerating at once each use their own previous answer, in
  conversation order. Once that generation ends, later requests see what the
  transcript says; a request already captured is unaffected. An edit, deletion
  or reload that changes an exchange's identity never lets its previous answer
  reach another exchange.
- *(added 2026-09-18)* Stopping a generation — Stop, an edit that revokes it,
  reload or detach — ends every process it started (the whole process group,
  escalating to SIGKILL) and confirms every in-process wait on cancel, so no
  admission slot outlives it. A process that survives SIGKILL is named, with its
  pid, in the refusal it causes.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

Derived after the plan cleared plan-quality, against the durable plan's tasks.
Each task that produces code has at least one `item:`. Heavy tasks have two,
and sunk design has its own rows.

- **Design.** Every primitive is discounted ×0.2 (v2 Step 3), because the plan
  pre-resolves its decisions: each decision records the operator's answer, its
  rationale and its tests. The exception is `issue-spec` at 1.5, because its
  design *is* the audit, three rounds of operator decisions and two plan
  reviews. `sdlc actual` already reads **4.13 h** for that window.
- **Design buffer.** +15%, for a thorough plan (v3.1 rule 4).
- **Implementation.** Every value is 40% of the v2 table (v3.1 rule 5), and
  stays within the scaled range of its primitive.
- **Review tail.** Two `milestone-review` rows per milestone, plus one for the
  issue close. That follows the 2026-09-16 lesson: work across a shared seam
  budgets review as a multiple, not a single unit. #266, on the same seam, ran
  11 or more boundary rounds across its milestones and close, so 11 review rows
  match its count. At 0.2 h per round, including fixes, the tail is tight.
- **Familiarity 1.2.** This was 1.0 before the estimate-quality judge's
  2026-09-18 notes. M3 and M4 are novel-but-bounded (v2 Step 5: ×1.5): process
  groups, `setsid`, TERM→KILL, and live conformance against the kernel.
  Together they carry roughly 45% of the implementation hours. The grammar has
  one field, so the blend is about 1.2.
- **Sunk design is itemized.** `sdlc actual` read 4.13 h for the audit and
  planning. That time is carried by `issue-spec` plus two `scope-pivot` rows
  (the 09-17 withdrawal of the external-store bucket; the 09-18 reversal of the
  affordance and the #255 fold) and two `ux-rename-iteration` rows (the 09-18
  kill/group/deadline decisions; plan review round 1). With the buffer they
  come to 4.72 h, reconciling with the measurement instead of undershooting it.

**Read the total as a floor.** Every task is strict TDD red→green with
counterfactuals, which is near the worst case for v3.1's fan-out discount
(`baseline-v3.1.md` open question #3). On this repo, same-shape rows landed at
0.47–0.71 of actual: #266 0.67, #262 0.53, #263 0.47, #240 0.66, #206 0.71.
Heavy tasks (3.3, 3.4, 4.2) are split into two items each, rather than capped
at one feature ceiling.

```estimate
model: estimate-logic-v3.1
familiarity: 1.2
design-buffer: 0.15
item: issue-spec               design=1.5  impl=0.12
item: scope-pivot              design=0.5  impl=0.2
item: scope-pivot              design=0.5  impl=0.2
item: ux-rename-iteration      design=0.8  impl=0.04
item: ux-rename-iteration      design=0.8  impl=0.04
item: cross-cutting-refactor   design=0.1  impl=0.2
item: cross-cutting-refactor   design=0.1  impl=0.2
item: lua-neovim               design=0.2  impl=0.6
item: lua-neovim               design=0.2  impl=0.3
item: atlas-docs               design=0.04 impl=0.08
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
item: lua-neovim               design=0.2  impl=0.3
item: lua-neovim               design=0.2  impl=0.3
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.4  impl=0.6
item: lua-neovim               design=0.4  impl=0.4
item: lua-neovim               design=0.2  impl=0.4
item: atlas-docs               design=0.04 impl=0.08
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.2  impl=0.4
item: lua-neovim               design=0.4  impl=0.6
item: lua-neovim               design=0.2  impl=0.5
item: cross-cutting-refactor   design=0.2  impl=0.2
item: lua-neovim               design=0.2  impl=0.4
item: lua-neovim               design=0.2  impl=0.2
item: lua-neovim               design=0.2  impl=0.3
item: real-api-discovery       design=0    impl=0.24
item: atlas-docs               design=0.04 impl=0.08
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
item: lua-neovim               design=0.4  impl=0.6
item: lua-neovim               design=0.4  impl=0.6
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.2  impl=0.3
item: atlas-docs               design=0.04 impl=0.08
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
item: lua-neovim               design=0.2  impl=0.5
item: lua-neovim               design=0.2  impl=0.4
item: lua-neovim               design=0.2  impl=0.6
item: atlas-docs               design=0.2  impl=0.08
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
item: milestone-review         design=0    impl=0.2
total: 30.07
```

Item order, one line per item:

- issue-spec — the audit + spec
- scope-pivot — 09-17: external-store bucket withdrawn
- scope-pivot — 09-18: affordance reversed, #255 folded in
- ux-rename-iteration — 09-18: kill certainty, groups, deadlines
- ux-rename-iteration — plan review round 1 + dispositions
- cross-cutting-refactor — M1 1.2 store deletion
- cross-cutting-refactor — M1 1.3 tools carve-out
- lua-neovim — M1 1.4 sidecars degrade + census
- lua-neovim — M1 1.1 regression tests
- atlas-docs — M1 1.5
- milestone-review — M1
- milestone-review — M1
- lua-neovim — M2 2.1 State.holds
- lua-neovim — M2 2.2 previous_answer
- lua-neovim — M2 2.3 coordinator slot
- lua-neovim — M2 2.4 substitution
- lua-neovim — M2 2.5 staleness reversal
- lua-neovim — M2 2.6 live ancestors
- atlas-docs — M2 2.7
- milestone-review — M2
- milestone-review — M2
- lua-neovim — M3 3.1 fake groups
- lua-neovim — M3 3.2 escalation
- lua-neovim — M3 3.3a group kill + scopes
- lua-neovim — M3 3.3b deadlines, settling, kill report, tasker_run sweep
- cross-cutting-refactor — M3 3.4a 20-site deadlines
- lua-neovim — M3 3.4b callbacks read kills as failure
- lua-neovim — M3 3.5 VimLeavePre
- lua-neovim — M3 3.6 live conformance
- real-api-discovery — M3 3.6 real process-group semantics
- atlas-docs — M3 3.7
- milestone-review — M3
- milestone-review — M3
- lua-neovim — M4 4.1 runner
- lua-neovim — M4 4.2a session/provider/prep/completion
- lua-neovim — M4 4.2b topic/target/Deferred owners
- lua-neovim — M4 4.3 helpers
- lua-neovim — M4 4.4 tools/skills
- lua-neovim — M4 4.5 end to end
- atlas-docs — M4 4.6
- milestone-review — M4
- milestone-review — M4
- lua-neovim — M5 5.1 vocabulary
- lua-neovim — M5 5.2 arch scan
- lua-neovim — M5 5.3 routing
- atlas-docs — M5 5.4 inventory page
- milestone-review — M5
- milestone-review — M5
- milestone-review — issue close

Reconciliation: Σdesign 10.66 × 1.15 = 12.26, plus Σimpl 14.84 × 1.2 = 17.81, gives 30.07.

## Plan

- [x] Trace the recent document/generation refactor and inventory hidden state,
  ownership, invalidation and persistence paths.
- [x] Reproduce the reported edited-during-generation stuck transcript and
  compare same-process recovery with quit/reopen recovery. *(By code trace, in
  the audit Log; the executable reproduction is the regression test M1 adds.)*
- [x] ~~Define the transcript source-of-truth and explicit runtime/recovery state
  contract; fix any state that violates it.~~ *(superseded 2026-09-18 by M1–M5
  below — durable plan `workshop/plans/000261-transcript-is-the-whole-truth-plan.md`)*
- [x] ~~Add stateful integration coverage for interruption, edit conflicts,
  reload/reopen and subsequent successful submission.~~ *(superseded — folded into M1–M5)*
- [x] ~~Update atlas documentation and run the relevant full verification
  suite.~~ *(superseded — per milestone; the inventory page in M5)*
- [x] M1 — delete the on-disk answer-recovery store, its commands and the tools
  privacy carve-out; the #261 blocker as regression tests; guard: a
  `state_dir` reader declares why it cannot block.
- [x] M2 — `prev_answer` on the document coordinator (#255): same-chat and
  sub-chat context substitution; ancestors read the parent's live buffer.
- [x] M3 — processes die for certain: children lead their own process group
  (`detached`), Stop kills a generation's scope TERM→KILL, unscoped helpers get
  a deadline, every spawn settles, leaving Neovim kills every group.
- [x] M4 — every wait a generation holds settles (W1–W16); a stopped response
  never holds an admission slot, including across `:bd`/reopen.
- [ ] M5 — one refusal vocabulary: no silent refusal, no raw token; the
  inventory and restart invariant in `atlas/chat/transcript_truth.md`.

## Log

### 2026-09-15

Filed from an operator report after the recent generation refactor. Editing the
transcript during generation left a question unable to submit and showing an
error; the desired invariant is that quitting and reopening the transcript
reconstructs a healthy state from durable transcript/recovery data.

### 2026-09-17 — audit complete (plan step 1 + 2)

Four parallel fresh-context audits (durable on-disk state, runtime state
lifetime, refusal inventory, hand-edit round-trip), each finding verified
against the code before being recorded here.

**Headline: exactly one subsystem is authoritative over the chat file.**
No in-memory registry is keyed by absolute file path; `D.attach`
(`document/init.lua:236-246`) rebuilds structure from `opaque(rows,total)` with
zero grants and zero generations, and reload revokes everything
(`document/state.lua:353-356`). Nothing else is persisted — no lock file, no
generation journal, no transport PID file. The #254 architecture is sound; the
violations are at its edges.

#### Classification (Spec's three buckets)

**(c) External/durable state that is authoritative over the transcript — the violation**

`chat_respond.lua:1564-1576` makes a successful write to
`{state_dir}/answer-recovery/` a hard precondition for regenerating an answer.
There is no fallback branch:

```lua
if replacing_answer then
  if not recovery then ... error('Answer recovery unavailable: '..tostring(why), 0) end
  local published = Recovery.publish(recovery, ctx)
  if not published.ok then error('Answer recovery unavailable: '..tostring(published.reason), 0) end
end
```

*The #261 mechanism, confirmed.* `Store.resolve` (`answer_recovery.lua:250`)
requires the answer currently in the buffer to be byte-identical to the record:

```lua
and record.replacement.bytes==candidate.replacement.bytes then matches[#matches+1]=candidate end
```

Regenerate → record holds the **original** answer. Edit the transcript
mid-stream → grant revoked, runner stops, but partial new output is already
committed (`generation.lua:45-49` discards only the unwritten queue).
`Recovery.finish` on a non-success outcome deliberately keeps the record
(`chat_recovery.lua:271-306`). Retry → the in-memory retry cache is invalidated
by the edit (`chat_recovery.lua:134-136`) → falls through to on-disk matching →
record says *original*, buffer holds *partial* → refused at
`chat_recovery.lua:152` with `retained recovery requires inspection or explicit
restore`. **Quit and reopen does not clear it**: the epoch resets and grants are
wiped, but the record is on disk and re-enters through the same branch. This is
precisely the "did not reliably recover that way" report.

*Blast radius is profile-wide, not per-chat.* `answer_recovery.lua:214` checks
the global flag before the per-key one:

```lua
if s.unknown_association then return fail('recovery association unavailable; inspect quarantined snapshots') end
if s.blocked_keys[spec.key] then return fail('original recovery snapshot unavailable') end
```

`unknown_association` is set (`:119`) whenever a quarantined record has no
readable sibling of the same id — so one unreadable file blocks answer
regeneration in **every chat in the profile**. "Unreadable" is stricter than
corrupt: `:95` requires mode exactly `0600`, `:196` requires the directory
exactly `0700`, `:91-92` fails the whole scan on a symlink or subdirectory. So
`rsync` without `-p`, a restored backup, a cloud-sync folder, or `cp -r` under a
different umask silently poisons the store. Capacity is the same shape: 16 MiB
per record / 256 MiB per profile (`:4-5`, `:142-143`), counting `.quarantine`
and orphaned `.tmp`, with **no age-based GC** (ARCH-FUNERAL: the reader has a
cap, the writer has no bound — a cliff, not a bound).

The escape hatch cannot reach any of it: `M.list` returns only decodable records
(`:300-303`), so `:ParleyAnswerRecovery` reports "no recovery snapshots for this
chat" while every regeneration refuses; `discard_snapshot` → `Store.cleanup` →
`M.inspect` → nil → `'snapshot unavailable'` (`:230, :266`). No `:Parley*` purge
command exists. No message names the directory.

**(b) Disposable runtime state that is NOT invalidated on reload — second class**

Process-global scalars, cleared by nothing (`generation_runner.lua:8`):
`local serial,active,staged_total=0,0,0`. `active` is incremented at `:493` and
decremented **only** by the `terminal` effect (`:437`); 16 leaked runners →
`'process generation limit'` (`:462`) blocks submission in every chat until
Neovim restarts. `staged_total` is a global 16 MiB staging budget (`:75`) with
the same leak shape. `answer_recovery.pending_owners` (`:69`, a strong ref) is
the same pattern and its only reconciler (`:277`) is unreachable from any
command. ARCH-ORDER: extent is not lexically bounded — a spawned runner can
outlive every scope that could collect it.

Buffer-number-keyed registries outside the `on_detach` trunk (`editor.lua:171`),
where **buffer numbers are reused after `:bd`**, so close+reopen inherits the
block: `tasker.records/admissions` (zero registered autocmds — both `autocmd`
hits are `doautocmd User`; retains unresolved records *by design* at `:213-216`,
"resource ownership retained", and keys capacity on `state.buf==candidate.buf`
at `:55`, so a hung transport pins `is_busy(buf)` forever);
`chat_respond.responses` (`:1305`, cleared only by `release()` at `:1468`);
`skill_invoke._in_flight/_terminals` (`:23-30`).

Compounding: chat buffers have **no `bufhidden=wipe`**, so navigating to another
chat unloads nothing. Only `:bd`/`:bw`/`:e!` reset anything — the likely reason
the operator's quit-and-reopen attempt appeared not to work.

**(a) Durable state that correctly derives from, or never blocks, the transcript**

`state.json` (`last_chat`, self-heals), `file_access.json` (self-prunes),
`remote_reference_cache.json` (re-fetches on miss — but path-keyed and never
migrated on rename, so it silently orphans), query transport files
(`dispatcher.lua:672-674`, pruned >200→100), raw logs and the review journal
(both `pcall`/WARN only), per-chat asset folders (reads are pure text; a missing
folder degrades to a visible inline `[attachment … could not be read: ENOENT]`
and **never** blocks submission — the model the recovery store should follow).

#### Refusal inventory — authority classification

Every refusal reachable from `ChatRespond` / `ChatRespondAll` /
`ChatResumeBatch` / `ChatResumeResponse` was classified **T** (transcript-derived
— acceptable), **R** (runtime, clears on reload), or **X** (external durable).
All X-class refusals surface as `Response not started: Answer recovery
unavailable: <reason>` and fire only when the targeted exchange already has an
answer (`replacing_answer`, `chat_respond.lua:1404`) — so a fresh question never
touches the store, but *retrying a failed or cancelled response does*, because
that left answer text behind.

Two cross-cutting defects found alongside:

- **Six refusals are completely silent.** `chat_respond.lua:1400, 1929, 1932,
  1937, 1941, 1951` return `nil, reason`; the command wrappers discard it
  (`init.lua:1155, 4169, 1321`). The operator presses submit and *nothing
  happens*, with no message — worse than an opaque error.
- **Opaque authority tokens are surfaced verbatim** — `Response not started:
  overlap` / `capacity` / `unconfirmed entity` / `stale` / `target limit`
  (`chat_respond.lua:1673`). These do clear on reload, but nothing says so, so
  they read as permanent. `chat_respond.lua:1630` is the counter-example that
  names its exact recovery commands and is the model to follow.

#### Round-trip: the transcript is not sufficient to reproduce a chat

Separate from blocking, and in scope for "WYSIWYG":

- **Under stock config the file records no model, provider or system prompt.**
  `config.lua:300` selects `short_chat_template`, which (`defaults.lua:89-97`)
  has no `{{optional_headers}}` placeholder, so the values computed at
  `init.lua:3929` are substituted into nothing. Behavior comes from
  `_state.agent` in `state.json`; `_state.web_search` silently swaps the model
  (`providers.lua:329-331`); the on-screen badge shows `_state.agent`, not the
  header (`highlighter.lua:556-567`).
- **When the long template is configured, `new_chat` writes a header its own
  parser cannot read.** `init.lua:3939` runs `template:gsub("_","\\_")` over the
  rendered template; `chat_parser.lua:70` requires `[%w_%.%+]+`, which excludes
  backslash. Verified: `system\_prompt:` parses to `nil`. The operator sees a
  pinned prompt in the file that is not in effect. (`get_default_template` at
  `init.lua:5236-5287` does *not* escape — three creators, three behaviors.)
- **Copying a chat cross-contaminates three sidecars keyed on
  `(timestamp, dir)`**: deleting the copy `remove_tree`s the shared asset folder
  and destroys the original's images (`assets.lua:1249-1260`); the original's
  recovery snapshots are listed in, restorable into, and can hard-refuse
  regeneration in the copy (`chat_recovery.lua:146-148`).
- **No external-change detection at all** — `checktime`/`FileChangedShell`
  appear only in `tools/file_refresh.lua`; `buffer_lifecycle.lua:5` registers
  none. Combined with `noswapfile` (`init.lua:1754`) and a 1 s debounced
  `silent! write` (`:1760-1788`), a `git checkout` under a live buffer leaves
  only Neovim core's mtime guard, surfacing as a modal prompt from a background
  timer.

Lower-ranked, recorded for the sweep: hand-edited `🔧:`/`📎:` tool ids silently
substitute/drop what the model receives (`chat_parser.lua:515`,
`chat_respond.lua:636-644`); `strip_definition_footnote_footer` truncates
resubmitted context at any model-authored `[^1]:` line (`define.lua:167-169`);
`highlighter.lua:753-773,858-894` rewrites `🌿:` topics in the buffer on open and
`chat_parser.lua:673` doesn't strip the appended `⚠️`, so it leaks into exports.

### 2026-09-18 — audit re-verified on main after #266 merged

Three fresh-context explorations re-ran the audit against `ee0c5f6d`. Line
numbers above are pre-#266; these supersede them. The durable plan
(`workshop/plans/000261-transcript-is-the-whole-truth-plan.md`) carries the full
enumerations and the queries that produce them.

**Recovery subsystem — the removal map is larger than the audit said.**
- Four modules (`answer_recovery` 312, `chat_recovery` 553, `response_recovery`
  170, `recovery_paths` 31), four specs (not five —
  `cliproxy_recovery_e2e_spec.lua` is the unrelated #197 auth retry) plus
  `tests/helpers/fake_recovery_filesystem.lua`, and `atlas/chat/recovery.md`.
- The privacy carve-out spans the tools layer: `tools/traversal_policy.lua` (42)
  and its spec exist only for it, and `private_directory`/`state_dir` are
  threaded through `tools/dispatcher.lua`, `tools/async_builtin.lua`,
  `tools/filesystem.lua`, `response_session.lua:92`, `response_tools.lua:111`,
  `tools/producer.lua:98` and `skill_invoke.lua:397` for nothing else.
- `chat_respond.lua:1551-1564` (plus the `unproved` cancel at :1535) is a
  suspended-grant wait added only because the snapshot read the live answer.
- `init.lua:3694-3699` cleans the store on chat deletion.

**Runtime state — three corrections.**
- `tasker.is_busy` no longer gates submission. Its remaining readers are the
  jump-to-response, slug rename (a stuck record silently skips the rename after
  save), reference repair and lualine.
- `chat_respond.responses` refuses nothing. It keeps stuck runners reachable,
  and Stop/Resume filter it by the current epoch, so a pre-reload runner can
  never be selected again.
- Reload/detach reaches every runner, but only *stops* it. `active`
  (`generation_runner.lua:8`, refusal `:574`) drops only at `terminal`, which
  waits for every operation to confirm.
- **Root cause, verified:** `tasker.stop_matching` (`tasker.lua:262-285`) sends
  signal 15 to the direct pid only. `reconcile_step` (`:200-222`) probes with
  signal 0 and never escalates. There is no SIGKILL and no group kill, although
  every process is spawned `detach = true` (`:470-476`, so pgid == pid).
  Resolution requires exit plus both EOFs (`attempt.lua:12-16`), so a child
  ignoring TERM, or a grandchild holding the pipe, pins its slot forever.
  In-process waits (`pre_query`/vault callbacks, remote fetch, the
  preparation wait at `chat_respond.lua:1531-1536`) resolve only when a
  callback arrives.
- Buffer numbers are reused by `:e!` and by `:bd` + reopen (probed on nvim
  0.11.7), so tasker's per-buffer capacity and `skill_invoke._in_flight` carry
  over into the reopened buffer.
- `generation_runner.M.start` increments `active` at `:605`, before
  `G.new`/`sync`/`dispatch`, which can throw.

**Refusals — current inventory.**
- Silent returns (the caller drops `nil, reason`): `chat_respond.lua:1400`,
  `:1948`, `:1951`, `:1956`, `:1960` (`no questions selected` — the most common:
  the cursor is in the header). `response_session.lua:33-34` is unreachable.
- Silent non-success endings: the single-response `terminal` handler
  (`:1695-1717`) reports only a provider `failure_notice` and `overflow`.
  `revoked`, `uncertain`, `insert_failed`, `finalize_failed`, `round_capacity`,
  gap-write `prepare_failed` and `provider_failed` end with no message.
- Opaque tokens reach `Response not started: <reason>` through two channels
  with different behaviour: `:1691` (`logger.warning`) and `:1542`
  (`pcall(vim.notify)`, first line only, not logged). No refusal-to-message
  mapping exists anywhere. #265 owns `buffer_edit.replace_user_lines`, which is
  not on these paths, and should reuse whatever vocabulary this issue builds.
- Also on this path: the `!` force flag is passed as a 4th argument that
  `M.respond` never reads (`chat_respond.lua:2027-2031`), so its "Forcing
  response…" message is false. `init.lua:4171` calls a
  `chat_respond.resubmit_questions_recursively` that no longer exists.

### 2026-09-18 — M1 implementation notes (before milestone-close)

- **Red, then green.**
  - Task 1.1's four #261 cases (further edit, reload, close and reopen, legacy
    directory) failed on the unchanged code with exactly the reported
    refusals: three with `retained recovery requires inspection or explicit
    restore`, one with `recovery directory must be private (0700)`. The
    immediate-retry characterization passed on it.
  - All pass after the deletion (`chat_respond_spec` 31/31).
- **Deviation: `file_to_table` gained an optional schema, and a `conform`
  helper.** The degrade spec's wrongly typed bodies showed the class goes
  one step past syntax:
  - `refresh_state` compared `updated` as a number;
  - vault compared `expires_at` and indexed the bearer;
  - custom prompts passed a numeric `system_prompt` through;
  - the remote cache indexed `cache.chats[...]` as a table.

  Each reader now declares the fields it takes, one nested level deep where it
  indexes them. The type check sits at the read, per ARCH-SECURE: parse at the
  boundary.
- **Deviation: the `file_to_table` tests live in `tests/unit/helper_io_spec.lua`,
  not `helper_spec.lua`,** because that is where they already were. A JSON array
  is accepted, since it decodes to a table and rejecting it would also reject
  `{}`.
- **Counterfactuals.**
  - An unguarded decode fails 4 degrade cases.
  - An undeclared `state_dir` reader fails the census.
  - Both were restored clean.
- **Suite.** At `make test JOBS=4`, 372 spec files pass.
  `tests/integration/perf_ownership_spec.lua` dies at the harness's ~50 s
  per-file cap under load, on the base commit and on this branch alike.
  Alternating A/B runs alone gave base 50.24/50.23/25.74 s and branch
  32.84/26.00/26.10 s; the base died twice. At JOBS=8 a different spec
  (`document_dependencies_spec`) died once the same way, and passes alone.
  This is recorded on #267 as the same family. It is not M1's.

### 2026-09-19 — M1 boundary review, round 1: FIX-THEN-SHIP, and how each finding was disposed
- 2026-09-19: closed M4 — make test JOBS=4 unit stage 213/214 (document_semantic_spec passes 20/20 alone x2); make test-integration JOBS=4 168/169 (document_fold_uncertainty_retirement passes alone x2) - #267 family. make lint clean. Round 3: BR-48 W15 terminal-site test (red with only that site reverted); BR-61 dispatcher pre_query doc + recovery claim contract updated, guard that every pre_query takes on_error; topic cancel_through helper (throw / refused cancel / stop-then-throw), tests red on old code; tasker plan row; per-row seam ledger recorded in plan.; review verdict: FIX-THEN-SHIP
- 2026-09-19: closed M3 — make test JOBS=4: 381 files PASS, exit 0. make lint clean (637 files). Counterfactuals all red on revert: main detach key (3 live conformance cases), group target (8/12 sequence tests), kill code (content fetch), old oauth render, response_provider exit branch, topic merge, pid-0 guard, held deadline timer. Round 2: BR-45 failure.exit rendered once at the dispatcher + value-anchored guard; BR-46 derived spawn classification (sync/bounded/delegated/open) with per-class counts, helper and wrapper bounds checked; 3 untested Minors now tested.; review verdict: FIX-THEN-SHIP
- 2026-09-19: closed M2 — make test JOBS=4: 377 files pass + perf_document_spec which dies under load and passes alone 5/5 (#267). Rounds 1-3 disposed: buffer_for + guard; tree-move rewrite and ENOENT abort on #270 (contract updated); exemption boundary pinned (red on raw-owner counterfactual); did-it-happen rule enforced by ---@nodiscard guard (red on a planted bare call).; review verdict: FIX-THEN-SHIP
- 2026-09-19: closed M1 — make test JOBS=4: 372 files pass + 2 fold specs that die under load and pass alone (#267 family, logged). Rounds 1-3 fixed as classes with guards (census, worktree listing, write-result, json_decode, per-action warning bound, one atomic writer); every fix red on revert.; review verdict: FIX-THEN-SHIP

Each finding was swept as a class, not at the site it named (memory:
fix the class, not the site).

- **BR-5, `read-filter-destroys-source` (Important).** `custom_prompts.load()`
  pruned the map that `set`/`remove`/`rename` wrote back.
  - Class: every sidecar whose read filters and whose writes persist the
    result.
  - Fix: `custom_prompts` splits a filtered `load()` view from
    `read_authored()`, which returns the file as the user wrote it. A write
    refuses, with a warning, to replace a file it cannot read.
  - Enforcement: every sidecar in `tests/helpers/sidecars.lua` now declares
    `writes = "rewrite"` with a reason (app-owned state or a cache), or
    `writes = "preserve"` with a check the degrade spec runs. The census fails an
    entry that declares neither.
  - Counterfactual: reverting `set` to write `load()` fails A2b and A2c.
- **BR-6, `guard-scans-index-not-worktree` (Important).**
  - Class: every arch spec that lists files through the git index. There were
    six: the census, `superseded_comment_spec:40`, and
    `single_source_sweeps_spec:410,531,562,594`.
  - Fix: all six list through the new `arch_helper.worktree_files`, which uses
    tracked plus untracked files, minus ignored and deleted ones.
  - Enforcement: `tests/unit/arch_helper_spec.lua` fails any arch spec that uses
    `git ls-files` without `--others`, or `git grep` without `--untracked`. It
    also proves `worktree_files` lists an untracked file.
- **BR-7, `per-item-diagnostic-unbounded` (Important).**
  - Fix: `conform` takes nested schemas and emits one warning per call, with a
    count and a sample of up to five paths. Each reader declares its shape in a
    single call, which also removed the four hand-written nested levels the
    review's architecture note flagged.
  - Test: 300 bad leaves produce exactly one warning.
- **Minors fixed:**
  - the degrade spec reads the remote cache cold on the submission path;
  - its cases run in a stable order;
  - the vault exercise uses a fresh module instance and the stateful
    `fake_process` seam, so nothing leaks;
  - the census no longer depends on a stale shell exit code;
  - three `tool_execution.md` paragraphs are reflowed.
- **Minor deferred to M4:** the finalize adapter's `{cancel=…}` handle, which
  the runner discards, is now plan row W18. It belongs to "every wait a
  generation holds settles".
- **Lessons:** three rules added to `workshop/lessons.md`.
- **Suite:** `make test JOBS=4` passes, with 373 spec files and exit 0.

### 2026-09-19 — M1 boundary review, round 2: REWORK, and how each finding was disposed

Round 1's fix for BR-5 introduced a Critical, BR-14: the picker ignored
`set`'s new `false` return, reported "System prompt saved", and wiped the
edit. The gate said the review was not converging.
- **BR-14.** Each class was swept, and each has a guard; see the plan's
  Revisions (2026-09-19, round 2).
  - `table_to_file` reports whether it wrote, through `save`, `set`, `remove`
    and `rename`.
  - The picker announces a save only on success, and keeps the edit otherwise.
  - The dispatcher aborts a request whose body was not written.
  - A guard fails any sidecar write called as a bare statement unless it is
    declared.
- **BR-15.** The picker reads the prompt file once per build. The degrade
  spec now bounds warnings per user action.
- **BR-16.** The vault token decode is guarded, and a new
  `json_decode_spec` fails any unguarded `vim.json.decode`.
- **Counterfactuals.** Each fix, when reverted, turns its guard red.
- **Suite.** `make test JOBS=4` passes, with 373 files plus the table-row fix.
- **Lessons.** Four rules added.

### 2026-09-19 — M1 boundary review, round 3: FIX-THEN-SHIP (BR-19)

- **BR-19.** `table_to_file` dropped `close()`'s result: the third finding in
  the `returned-handle-has-no-consumer` family.
  - Fix: it now delegates to `table_to_file_atomic`, which checks every step
    and keeps the original file.
  - Tests: F3e (a flush that fails at close) and R1 (the dispatcher aborts on
    an unwritten body). Both go red when reverted.
- **Minors fixed:**
  - one shared bearer schema;
  - the decode guard also covers `vim.fn.json_decode`;
  - the declared exceptions are keyed by call.
- The plan's Revisions record the one-writer rule, and `workshop/lessons.md`
  has the rule.

### 2026-09-19 — M1 closed: round 4 (FIX-THEN-SHIP) fixes, bundled into the close commit

- **Fixed before the close commit** (#174 protocol; details in the plan's
  Revisions):
  - the writer keeps symlinks and modes and sweeps its own crash leftovers;
  - `file_access.json` joins the sidecar list, and the census selects by
    profile location;
  - the vault bearer's response schema has a test (V1).

  Each fix goes red when reverted.
- **Incident, not a code change.** During round 4 the reviewer agent's setup
  script failed to create a scratch directory and fell back to `git init -q`
  and `git add -A` in the operator's home directory, against the existing
  `~/.git`. It made no commit, and the index, HEAD and refs are untouched.
  - Verified read-only: 27,978 loose objects appeared after 00:59 today
    (3.66 GiB), plus a 1.89 GiB abandoned `tmp_pack`, in `~/.git/objects`.
  - Nothing was deleted; the cleanup is the operator's call.

### 2026-09-19 — M2 implementation notes (before milestone-close)

- **Tasks 2.1–2.6 landed as planned.** Each fix has a counterfactual that
  goes red: `holds`; the line_start rebase (2 tests); the finish-time removal;
  no substitution (3); substitution moved to `build()` (1: capture-then-late-
  build); the staleness rule (the tool-round continuation); a disk-only
  ancestor read (2).
- **Deviation: no `tests/helpers/parsed_chat.lua` lift.** The pure
  `previous_answer` tests use small literal exchanges. The two checks that need
  `build_messages` live in `build_messages_spec`, beside its existing
  content-block fixtures.
- **Deviation: the raw-payload read fixes a pre-existing batch-mode bug.** A
  batch leg builds from a copy of the input, so reading `question.raw_payload`
  dropped a typed raw request. Only the new batch-leg test pins this; the
  single-mode raw test is a characterization. Both stub `log_emit.parse_yaml`,
  because PyYAML is absent on this host and YAML parsing is not what they test.
- **`document_dependency_affinity_spec` asserted the reversed rule** ("another
  generation … stays stale"). It is updated, with the reason in the test.
- **Atlas.** `lifecycle.md` gains "Previous answer while regenerating", the one
  statement of the rule, and the ancestor paragraph. `document.md` and
  `ownership.md` link to it.

### 2026-09-19 — M2 boundary review round 1 (FIX-THEN-SHIP) and dispositions

- **BR-26.** `helper.buffer_for` now serves every `vim.fn.bufnr(<name>)`
  site, five of them, and a guard fails a new one. P4 pins the prompt-editor
  data loss the review reproduced.
- **BR-25.** The loaded-target tree-move bullet cannot be met: the rewrite
  branch never fires. That is filed as parley#270; a characterization test
  stands in.
- **The Log's earlier "Tasks 2.1–2.6 landed as planned" was wrong on two
  counts,** and both are now recorded in the plan's Revisions: the seam the
  sub-chat tests use, and this bullet.
- **Minors fixed.** The staleness rule's wording, a two-entry substitution
  test, and the stub restored under `pcall`.

### 2026-09-19 — M2 boundary review round 2 (BR-30): the stand-in is withdrawn

The characterization test that stood in for Task 2.6's loaded-target bullet is
deleted. It passed only because `chat_move_spec` builds chats as scratch
buffers; with a real file-backed buffer the move saves, slug-renames and aborts
with ENOENT. That is a pre-existing tree-move defect, reproduced by the review
and recorded on parley#270 with the fixture gap. The earlier Log line saying "a
characterization test stands in" no longer holds: Task 2.6's loaded-target
bullet is withdrawn outright, and parley#270 owns it. The buffer-lookup guard's
header now states its static-check limit.

### 2026-09-19 — M2 boundary review round 3 (FIX-THEN-SHIP): dispositions

- **BR-32.** Two boundary tests pin the staleness exemption's safety: a write
  outside its grant, and a write through a revoked grant, both stale the
  reader. The counterfactual turns both red.
- **Did-it-happen family.**
  - Fixed as a rule: `---@nodiscard` on the functions, and a guard that
    selects by the annotation. The counterfactual flags a planted bare call.
  - `set_previous_answer`'s drop is declared, with its reason.
- **parley#270's contract** now carries the deferred fixture obligation.
- **Recorded for the close:** the path-canonicalisation idiom has about ten
  copies (ARCH-DRY Minor), which is beyond #261's surface.

### 2026-09-19 — M3 Tasks 3.1–3.3: groups, escalation, scopes, deadlines

- **The spawn key.** `detach` became `detached`, set for scoped runs only
  (ARCH-SECURE). The fake now models groups, ignored signals and grandchildren.
- **Escalation lives in the pure reducer.** A stop opens a window: TERM, KILL at
  +2 s while unresolved, visible at +5 s. `kill_cause` names why Parley killed a
  run, and the callback then gets `code=nil, io_error='killed: <cause>'`.
- **The refusal of an unscoped run without `deadline_ms`** landed together with
  the deadlines at every production site (`tasker.deadline`, one table,
  ARCH-DRY), so no commit refuses a real spawn (plan Revisions).
- **The refusal found a latent test bug.** `chat_async_tools_spec`'s native
  wrapper forwarded `unpack(args)`, which stops at the first nil hole. It had
  been dropping `on_start_error` and the options, so its "native tool" ran
  unscoped. It now forwards with `select('#', ...)`.
- **Flakes under `make test JOBS=4`, pass alone** (#267 family):
  - `response_target_spec`, "cancels pending native targets", a weak-table GC
    count: 3 of 3 pass alone;
  - `perf_document_spec`, which died silently after 3 tests: passes alone.

  Neither touches tasker.
- **Task 3.7's final runs.** More flakes of the same family: each died silently
  under load and passes alone.
  - `document_dependencies_spec`: 13 of 13 pass alone, 3 times.
  - `tool_resources_spec`, the spec #267 is named for: 11 of 11.
  - `perf_chat_typing_spec`: 16 of 16, 2 times.

  A unit-stage death stops `make test` before its integration stage, so the
  integration stage was also run on its own (`make test-integration JOBS=4`).
  Every file passed there except `perf_chat_typing_spec`.

### 2026-09-19 — M3 boundary review round 1 (FIX-THEN-SHIP) and dispositions

The ledger reported "round 9, not converging: fix rules, not instances". So each
Important finding is fixed as its rule, with a guard.
- **BR-38** (`seam-change-collateral`): the enumeration of renderers →
  `tasker.exit_reason`, guarded. The counterfactual (old `oauth.lua`) turns
  the new assertion red.
- **BR-39** (`seam-change-collateral`): the superseded-claim sweep, run → the
  README statement is corrected.
- **BR-40** (`enumeration-claims-completeness`): the atlas is scoped to tasker's
  seam, plus `tests/arch/spawn_seam_spec.lua`, the reasoned, exact-count list
  of every out-of-seam spawn with a dead-entry check.
- **All five Minors fixed** (plan Revisions). Lessons were added to
  `workshop/lessons.md`.

### 2026-09-19 — M3 boundary review round 2 (FIX-THEN-SHIP) and dispositions

Round 1's three Importants were disposed as addressed. Two new Importants, both
about how far a rule was carried:
- **BR-45**: the render sweep was anchored on `tasker.run(` call sites, not on
  the value. The dispatcher's failure table carried the raw code one seam
  further. It now carries only `failure.exit`, rendered once, and the guard
  forbids reading the raw fields anywhere.
- **BR-46**: once the atlas deferred to the spawn list, its prose reasons became
  unchecked documentation, and two were wrong. Each entry's class is now derived
  from the call form, with counts per class, and prose only where no mechanical
  answer exists.
- Round 1's three untested Minors have tests, each red on revert; the process
  fake gained a `spawn_pid` seam.

### 2026-09-19 — M3 closed at the round cap; review round 3's findings fixed in the close

The gate finalized M3 after four rounds, at its round cap. Round 3's findings
are fixed in the close commit (FIX-THEN-SHIP, no re-run):
- **Critical (ARCH-SECURE), introduced by round 1.** The Copilot failure log
  began printing a `curl -v` stderr carrying the token. The class is swept:
  `-v` is gone, secret-bearing stdout and bodies are never shown, a
  verbose-argv guard is added, and there are three planted-secret regression
  tests.
- **Important.** `async_builtin` overwrote an inherited `io_error`, so an early
  Stop read "bootstrap failed". Fixed, with an overwrite guard and a live
  oracle (`killed: stop`).
- **Important.** Skill processes hand-built their scope key. They now use
  `scope_key`, with a producer census guard, and the atlas says a chat scope
  kill does not reach them.
- **Four Minors fixed**; lessons added.

### 2026-09-19 — M4 Tasks 4.1–4.4

- **4.1, the runner.** `stats`; W14 undoes a start that throws; the runner
  settles an operation whose start threw (keyed on "threw", not on "no handle",
  which a supervisor test showed is legitimate); `fault`; and a once-only scope
  kill at stopping or terminal.
- **4.2.** The session's `stopping` hook kills the scope. Cancels resolve at once
  where nothing more can come (W2, W3, W5), which changes three pinned
  "wait for a callback" contracts. W12/W18 finalize, W13 across four owners,
  W15 and W16.
- **4.3.** Content fetches take the generation's scope (W4), the Copilot
  refresh reports every failure (W6), a setup throw aborts (W7), and recovery
  runs only for a live owner (W8).
- **4.4.** A skill's in-flight guard is freed when its buffer unloads (W17). W9
  is covered by W1. W10 is unreachable through public events and is dropped
  (plan Revisions).

Every fix has a test that turns red on revert.
- **4.5–4.6.** The reported shape end to end: a SIGTERM-ignoring stream stopped
  5 times, 17 times across `:e!`, and after `:bd`, is admitted every time
  (red with escalation disabled). The invariant is stated in
  `atlas/chat/lifecycle.md`.
- **Flakes of the #267 family in the final run, all passing alone:**
  `document_append_extent_spec`, `highlighting_spec`, and
  `skill_invoke_spec`'s weak-table GC check ("physical cleanup must not retain
  UI callback captures").
  - The last one also failed once in four runs alone. A/B over ten runs on
    each side: 0/10 before W17, 0/10 after. It also failed under load in M3
    round 1, before W17 existed.

### 2026-09-19 — M4 boundary review round 1 (FIX-THEN-SHIP) and dispositions

Four Importants, each fixed as its rule:
- **I1:** the changed contract's restatements, prose and doubles alike. There is
  now one returning `stop_owner` double, guarded.
- **I2:** a red test per edited site. W15 (throwing callees), the Copilot
  forward, and the oauth scope tree, where each of 39 sites was mutated.
- **I3:** the end-to-end run over each stop cause: Stop, edit, `:e!`, `:bd`.
- **I4:** a `WAITS` evidence list checked against the specs it names.

The six Minors are fixed as well (plan Revisions). Two items are carried into
M5's inventory: `fault`, and the completion-not-started warning.

### 2026-09-19 — M4 boundary review round 2 (FIX-THEN-SHIP) and dispositions

Ten findings were disposed. The two new Importants were round 1's own changes,
missed by round 1's sweeps: the stopped-scope refusal had no atlas mention, and
the batch guard had no test. Both are fixed. Round 1's other production hunks
were swept too: W16 gained a stop-during-request test, and the temp-dir change
gained an assertion. The false claim that chat specs reach W5 is corrected.

### 2026-09-19 — M4 boundary review round 3 (FIX-THEN-SHIP) and dispositions

- **BR-48:** the W15 terminal site now has its own test, red with only that
  site reverted.
- **BR-61:** the two stale restatements are fixed: the dispatcher's `pre_query`
  doc, and the recovery claim contract. A guard now requires every `pre_query`
  to take its error callback. The per-row seam ledger is in the plan.
- **Minors:** the topic's two cancel copies are one helper, `cancel_through`,
  which retires on a throw or a refused cancel; the `tasker` row now carries
  the refusal.

### 2026-09-19 — M5 Tasks 5.1–5.3: every refusal in words, once

`lua/parley/refusal.lua` owns the words. Every submit and generation path
speaks through `chat_respond`'s `refuse`. `chat_refusal_spec` (15 cases)
drives each refusal through the real session and checks that it reaches the
user exactly once. Its first run found five defects the unit-level design had
missed:

- **`:e!` said nothing.** Neovim detaches the buffer on `:e!`, so the runner
  recorded `detach`, which is silent. The host now treats it as a reload when
  the chat is loaded again.
- **A user-stopped batch warned three times.** This is inherited from main,
  which warned on every paused `changed`.
- **A batch leg's failure was said twice.**
- **A reload ended a batch silently.**
- **A permanent blocker.** A paused batch that can never resume (its question
  was reworded) refused every later `:ParleyChatRespondAll`. It now gives way.

The vocabulary guard missed composed reasons (`question obsolete`) and the
`reject(owner, lit)` form. Both are now rules in the guard, and 11
counterfactuals are recorded in the plan.

The full suite then caught a sixth defect. The dispatcher's "query abort before
start" notice doubled every caller's own message, so it is now written to the
log only. First-use model setup's reasons now have words.
`response_tools_spec`'s silent mid-run death also happens on a clean HEAD, so it
belongs to the #267 family.

`make check-fresh-clone` explained `dispatcher_query_spec`'s flaky I2. It was
the only spec that wrote request bodies into the shared `stdpath('cache')`,
where a parallel spec removed the file ("rename failed: No such file"). Since M1,
an unwritten body aborts the query before curl starts, so the stubbed spawn
never ran. The spec now uses its own `tempname()` directory, like every other
spec. A guard in `single_source_sweeps_spec` fails any spec that writes into the
shared cache, and it goes red when the old line is restored.

## Revisions

### 2026-09-17 — scope and direction settled after the audit

**Reason.** The audit (see `## Log`) answered the inventory question, and the
operator rejected the framing the original Spec implied. The Spec's third bucket
("external/recovery state that needs an explicit durable artifact and clear
reconciliation rule") assumed a durable artifact was warranted. The operator's
position: *"what external store? there shouldn't be external store to begin with
and is the purpose of this audit."* That bucket is withdrawn.

**Delta.**

1. **The answer-recovery subsystem is deleted, not reconciled.** Its entire
   purpose was verified to be recording the previous answer's text before
   regeneration overwrites it (`response_recovery.lua:72-73`, payload is
   `read(s,s.original)` stored as both `bytes` and `replacement.bytes`), and every
   reader is `list`/`inspect`/`resolve`/`restore`/`cleanup`, reachable only from
   the recovery picker. No internal consumer exists — `generation_runner.resume_original`
   (`:520`) works purely from `s.pending` / `current.input_ref` / `s.grants` and
   never touches the store. Removing it: `answer_recovery.lua` (312),
   `chat_recovery.lua` (553), `response_recovery.lua` (170), `recovery_paths.lua`
   (31), five spec files plus `tests/helpers/fake_recovery_filesystem.lua`,
   `:ParleyAnswerRecovery` / `:ParleyAnswerRestore`, the `helper.lua:15` privacy
   predicate, and the `tools/dispatcher.lua:353` carve-out whose only job is
   hiding the store from tools.

2. **Replacement is in-session memory, not disk.** Operator decision: keep
   replaced answers in memory for the life of the nvim session, available across
   buffers so navigating away and back still offers them. Dies with the process.
   Quitting mid-generation leaves a partial answer in the transcript on next open,
   and that is an **accepted outcome, not a defect**. ARCH-FUNERAL: in-memory,
   process-scoped, needs a declared size bound and eviction rule, and — critically
   — it is advisory. It may never gate a submission; its absence degrades an
   affordance and nothing else.

3. **`undofile` is optional, not load-bearing.** Verified empirically that it
   recovers a replaced answer across processes (a fresh nvim opened the file and
   `u` restored the pre-regeneration text) and that an unwritable undodir does not
   block editing or saving. It satisfies the operator's second principle — prefer
   base vim mechanisms over our own — but with (2) in place nothing depends on it,
   so it is a separable nicety rather than part of this issue's spine.

4. **Serialized mutation split to parley#266, and this issue now depends on it.**
   The operator's point: undo is only a usable fallback if the history is linear.
   Concurrent generations and out-of-order tool-slot fills make it a tree the user
   cannot reason about. Deleting a targeted restore before the history is
   comprehensible would trade one confusing recovery story for another, so #266
   lands first or alongside.

5. **Target extracted.** `workshop/targets/transcript-is-the-whole-truth.md` now
   holds the invariant both issues serve; this issue references it via `target:`.

**Unchanged.** The runtime-leak class (process globals in `generation_runner.lua:8`,
`tasker.records`, `chat_respond.responses`, `skill_invoke._in_flight`) and the
refusal-message class (six silent returns, opaque authority tokens) stay in
scope here — they are the other two ways state outside the transcript can block
or confuse work on it.

**Deferred to a new issue.** Round-trip provenance — the stock template recording
no model/provider/system prompt, `init.lua:3939` writing a `system\_prompt:`
header its own parser rejects, `(timestamp, dir)` sidecar cross-contamination on
copy, and the absence of any external-change detection. Same target, different
axis: that is about handing the file to someone else and getting the same
answers, not about being blocked.

### 2026-09-18 — operator decisions after the post-#266 re-verification

**Reason.** The re-verification (Log, 2026-09-18) changed two findings (runtime
state, recovery removal map). The operator settled the open design points in
session.

**Delta.**

1. **No replaced-answer affordance.** This supersedes delta 2 of 2026-09-17
   ("keep replaced answers in memory for the life of the nvim session, available
   across buffers"). There is no picker and no restore command:
   `:ParleyAnswerRecovery` and `:ParleyAnswerRestore` go with the store. Native
   undo is the only way back to a replaced answer.
2. **`prev_answer` — parley#255 folded in.** Operator: *"while generation is
   going on, if user navigate to another chat, maybe subchat, and request
   generation from there, there is a chance answer in parent chat's not
   generated yet, and only in that case we should use cached answer … for each
   exchange, we should keep a slot called prev_answer, and prev_answer is set to
   nil when current answer finish generating."*
   - **Where it lives:** the slot belongs to the in-memory exchange structure,
     i.e. the per-buffer document coordinator. It is a table beside the index,
     because the index stores no transcript payload.
   - **Lifetime:** set when a regeneration removes the old answer from the
     buffer; cleared when that generation ends. Reload, detach and deleting the
     exchange also clear it.
   - **"Ends" means any outcome.** Operator: *"new answer will either success or
     fail, both are recorded on the transcript, and that's all."*
   - **Only consumer:** request context. Ancestor context reads a parent from its
     live buffer when loaded, not from disk, because the 1 s autosave means disk
     already holds the partial answer.
   - #255 closes with this issue; its Spec and Done-when are carried into ours.
3. **Legacy `<state_dir>/answer-recovery/` is left untouched.** No migration and
   no health check; nothing reads it.
4. **Runtime leaks: kill what we started, with certainty.** A proposed 5 s
   deadline hand-off to a residue list was withdrawn. Operator: *"we need to have
   100% confidence we can kill what we started."*
   - Processes: stop signals the whole process group and escalates SIGTERM to
     SIGKILL after a grace period.
   - In-process waits: confirmed on cancel; late callbacks are ignored.
   - The admission counters then drain as a consequence rather than by policy.
     The one residual is a process in uninterruptible kernel sleep; it stays
     counted, and its refusal names it.
5. **Unchanged:** the refusal-message class, now enumerated in the Log.

### 2026-09-18 — plan review round 1: two more operator decisions

**Reason.** Two fresh-context reviews of the durable plan (see its
`## Revisions`) raised two questions the operator settled.

**Delta.**

1. **Own process groups only for generation-owned processes.**
   - Why: `detached` implies `setsid()`, which would break terminal-prompting
     secret commands.
   - Generation-owned processes (provider, tools, per-request fetches, skill
     processes) lead their own group and are killed with the generation's scope,
     SIGTERM then SIGKILL.
   - Shared helpers (the vault secret command, keychain, OAuth token calls) stay
     attached to Neovim's terminal and are killed by pid at a deadline.
   - This narrows the Done-when bullet "ends every process it started (the whole
     process group…)". It holds as written for everything a *generation* starts.
     A shared helper's grandchild can outlive its deadline kill.
2. **Deadlines per kind** for processes nobody stops:
   - 600 s where a human may be answering a prompt;
   - 120 s for one HTTP call;
   - 60 s for a local conversion;
   - 900 s for a background LLM stream.

   Each is declared at its call site, and the tasker refuses a spawn with no end.
3. **Derived from the #255 Done-when ("an already captured request is
   unaffected"):** a generation's own writes no longer mark another
   generation's captured input stale; only human edits do. This reverses the
   "other owners … stay stale" clause from #254 (`document/state.lua:272-284`).

### 2026-09-18 — estimate revised after the estimate-quality judge (20.64 → 30.07)

**Reason.** `sdlc change-code` passed. The plan-quality judge passed with four
Minor findings, which are folded into the plan's Revisions. The estimate-quality
judge returned INFO with substantive notes:
- familiarity 1.0 contradicted the block's own "no recent issue exercised" line;
- `issue-spec` at 1.5 h undershot the 4.13 h already measured;
- heavy tasks were capped at one feature ceiling;
- two labels were swapped;
- there was no platform-discovery budget for the live conformance spec.

**Delta.**
- Familiarity 1.2.
- Sunk design itemized: two `scope-pivot` rows and two `ux-rename-iteration`
  rows.
- Tasks 2.1/2.2, 3.3, 3.4 and 4.2 each split into two items.
- `VimLeavePre` is now `lua-neovim`, and the 20-site sweep is
  `cross-cutting-refactor` plus `lua-neovim`.
- Added `real-api-discovery` for Task 3.6.
- The inventory page's design is undiscounted (0.2).
- The #266 review-round count is corrected to 11 or more.
- The total remains a floor. The ledger's same-shape parley rows landed at
  0.47–0.71 of actual.
