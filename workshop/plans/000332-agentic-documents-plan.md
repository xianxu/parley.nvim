# Agentic Markdown Documents Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to choose subagent-driven development or executing-plans. Steps use checkbox syntax. The SDLC gates own fresh-context reviews.

**Goal:** A named Markdown document in a Couch pane becomes a protected, owed-response input surface on its first Alt+Return, and retains that identity through supported file renames.

**Architecture:** Generalize admission and identity around the existing session-sync edit-turn implementation. Couch owns canonical registry identity/owner and the owed ledger; Parley owns editor attachment and filesystem effects. A pure lifecycle model drives admission/submission/migration; the IO shell cannot bypass its transitions. Keep the existing lock, autosave ordering, undo baseline and violation reconciliation as one implementation.

**Tech stack:** Lua/Neovim, existing Couch subprocess seam, filesystem-backed fake Couch, Plenary/native child-Neovim tests, optional isolated real Couch conformance.

## Inputs and approval

- parley.nvim#332 Spec and Done when; approved S1 design in ops `teams/devinfra/projects/universal-agent-input-interface/{project,design}.md` (read 2026-10-15).
- Agreed pair#573 contract: pair `atlas/couch-agentic-documents.md`, initially frozen at 432fab15c7f655d2392d823053e37b575638ee7b. Public implementation/live use still requires that item to land and the TL to rebuild Couch.
- #327 landed first, PR239 merge bf98edb0f6b86bc846a55f2d26b24d4313374dca; its stage was cleared.
- Full flow: this crosses registry, editor and filesystem lifecycles and exceeds the quick shell. One atomic close boundary; no artificial milestone tags. Estimate follows plan-quality admission, not this draft.
- **TL policy resolved (a70bb84a-9070-4d6b-a505-60f22af1a603, verified submitted):** never make a file read-only because Couch is unavailable. Bounded lookup on open; known-attached or cached-agentic retains the full edit lock; proven-plain stays plain; unknown/unavailable remains editable with the one-line band "Couch unavailable: agentic state unknown". Re-lookup when Couch returns and take the lock if operator edits are outstanding. Couch is crash-only and agent writes use its CAS surface, so an unreachable Couch cannot concurrently perform those writes. Durable forward-only rename recovery is approved.
- **Legacy adoption/isolation resolved by source inspection:** pair sessionsync/registry.go Register adopts the legacy State/shadow/path history; registry_model.go refuses rename for an unregistered source. Register OLD while it and its legacy companions still exist, before native rename. Standalone conformance requires COUCH_ISOLATED_ROOT plus an explicit isolated adopt-store preview/apply; HOME/XDG alone are insufficient. The candidate executable/public-verb readiness still gates real conformance and combined live acceptance, not independent fake-backed implementation.
- **TL design approval:** verified submitted dispatch f96cd3f0-f712-4ed6-917f-eb348dc75b8c approves the draft with the availability policy already folded into this revision. Save→register→submit and the forward-only journal are explicitly approved.

## Scope and alternatives

Recommend one admission coordinator feeding the existing session-sync turn engine. A separate agentic lock engine would isolate old entry points initially but duplicate the timing-sensitive fixes in #324/#330; reject that ownership split (ARCH-DRY). Frontmatter tagging is excluded by the approved requirement; no implicit process-instruction insertion on pane submits.

Couch pane eligibility reuses `couch.thread()` (COUCH_THREAD_SCOPE/TAG) and the existing own-actor resolution; no new inference from directory names. Named ordinary Markdown becomes shared only after confirmed registration. Existing typed session-sync files retain their established attachment, including outside Couch. Outside-pane ordinary review behavior and chat/visual key routing remain where they are. An explicit couch-owner overrides the pane's slot; plain business `owner` does not. Legacy owner is routing metadata only for type: session-sync. This intentionally replaces #316's same-slot refusal where the approved explicit override applies.

This slice includes moving an existing sibling `<stem>.side/` and its parent backlinks, not creating side conversations, section modes, new edit presentations, navigation history or lock-reminder UI. `project.md` → `project.side/` follows the approved examples. Native saveas leaves its old file intact but transfers registration; it must not delete that old copy. Unobserved external moves require the moving agent to perform the same declared effects; Parley observes buffer-name changes and its own move paths.

## Core concepts

| Entity | Kind | Location | Status |
|---|---|---|---|
| Document lifecycle and registry reply | PURE | lua/parley/document_session.lua | new |
| Migration/backlink projection | PURE | lua/parley/document_move_plan.lua | new |
| Couch process transport | INTEGRATION | lua/parley/couch.lua | modified |
| Registry client | INTEGRATION | lua/parley/document_registry.lua | new |
| Agentic buffer coordinator and bounded known-path cache | INTEGRATION | lua/parley/agentic_document.lua | new |
| File/side migration and journal | INTEGRATION | lua/parley/document_move.lua | new |
| Shared edit turn | INTEGRATION | lua/parley/session_sync.lua | modified |
| Atomic byte writer | INTEGRATION | lua/parley/helper.lua | modified |
| Stateful registry fake | INTEGRATION | tests/helpers/fake_couch.lua | modified |

The lifecycle owns one identity per buffer incarnation and one operation token at a time; registry ID is authoritative across paths. The coordinator owns the model and executes returned effects. The edit-turn engine receives a confirmed identity/path/owner and preserves its existing content baseline. Migrations reference that same ID and never re-register NEW as a new document after uncertainty. Pure projections receive path observations and text as values, with no editor/fs mocks. Filesystem and subprocess implementations sit behind explicit adapters; production and tests share them (ARCH-PURE/ARCH-MOCK).

## Registry boundary

Use the frozen CLI verb shapes: register FILE --owner SLOT --json; lookup FILE --json; rename OLD NEW --json. Consume the capitalized Code/Error envelope and Registration {ID, File, Owner, RegisteredOwner, RegisteredAt}; mutations also expose Changed. Preserve the same ID on retries and moves. Owner is the effective owner returned by Couch, not the list endpoint's fallback owner.

Expose a single scheduled raw process-result seam in couch.lua and derive existing send/query wrappers from it. The registry adapter uses that seam without the legacy query decoder's null normalization. Decode JSON null to an explicit sentinel and feed the pure reply classifier. Only exit0 + Code ok + explicit Registration:null proves absence for lookup. Missing fields, malformed JSON, older usage output, nonzero, mismatched path/ID and invalid field types are unavailable, never absence. Validate strings/types/canonical request identity before returning a typed registration. Preserve registry-uncertain distinctly so mutation completion is not fabricated. Existing query callers retain their normalization contract.

Use exact argv arrays; do not interpolate paths or owners into a shell. Capture buffer incarnation, namespace/thread, path, operation generation and saved content observation with each request. Every callback checks that witness before effects. A stale read is ignored; an already-issued mutation may still have happened and is reconciled, never undone by forgetting it.

## Internal function contracts

- document_session.classify_reply(operation, exit_code, decoded, null_sentinel) returns exactly absent/registered/unavailable/uncertain plus validated data. The explicit null sentinel is required; nil never stands for confirmed absence.
- document_session.new(context) returns a controller with dispatch(event)→effects and snapshot()→detached value. Authoritative phase/identity are private; only the transition function changes them. IO effects carry immutable operation witnesses; the shell returns outcomes as events.
- document_move_plan.project(OLD, NEW, observations) and rewrite_parent(bytes, child_paths, parent_paths) return ordered effects/text edits or an explicit refusal, without IO. Preserve unrelated bytes; do not invent missing backlinks.
- document_registry.request(operation, arguments, witness, callback) executes exact CLI argv through couch.run and returns a bounded cancellation handle. Canceling a child cannot retract an already-applied registration/move.
- agentic_document.attach/submit/identity/detach coordinate admission and return confirmed identity to the edit engine. Its bounded cache is knowledge, not a second registry authority.
- session_sync.attach(buf, identity) and its factored acquisition/reconciliation helpers receive stable path/owner and any observed unknown-period edit baseline. begin_move/finish_move suspend/resume the same turn state; they do not create another lock machine.
- document_move.begin/advance/recover implement the journaled effects through an injectable filesystem adapter and the pure lifecycle model. helper.write_file_atomic(text,path,adapter) is the canonical checked byte writer; table_to_file_atomic remains the encoding wrapper.

## Lifecycle and ordering (ARCH-ORDER)

Authoritative admission/operation state is a tagged value owned by document_session; callbacks return events to `step(state,event) -> next,effects`. The shell may not assign phase/identity directly. Keep independent ownership-turn data inside the existing edit engine, not duplicated in this model.

| State/event | Next state and effects |
|---|---|
| Outside-pane ordinary Markdown | legacy review dispatch; no registry/lock attachment |
| Existing eligible file opened | probing with a request witness; cached/typed identity attaches immediately, otherwise keep editable and observe intervening edits |
| Lookup explicitly absent | plain; no turn timers, lock, band or registration |
| Lookup confirms registration | active(identity); attach the shared edit engine; if edits accumulated while unknown, acquire using the captured first-edit baseline before resuming reconciliation |
| Lookup unavailable | unresolved/editable with the one-line unknown-state band; preserve known/cached protection; schedule bounded re-lookup |
| Plain + explicit Alt+Return | submitting/save; validate named Markdown, pane identity and current origin; save successfully before register |
| Save/owner validation fails | plain or active as before; notify; no register/send/unlock |
| Register confirmed | active(identity); attach before send; clear only the submitted turn after disk reconciliation/save; send once to returned Owner |
| Register refused | retain pre-submit ownership/state; no send; expose exact error |
| Register outcome uncertain | reconciling exact operation; retry exact args/lookup within bounded policy; no fresh identity or blind rollback |
| Send confirmed/failed/uncertain | registration remains active; retain existing explicit-resubmit policy; never auto-resend an uncertain message |
| Duplicate Alt+Return while busy | coalesce/ignore; at most one save/register/send chain |
| Edit or owner/path/thread change during async work | invalidate witness; retain already-applied external registration; no stale send/unlock/attachment |
| Buffer unload/delete | invalidate model generation; close/cancel owned handles; late callbacks cannot act |
| Active + buffer rename | migrating(ID,OLD,NEW,steps); freeze old-path callbacks and turn reconciliation; preserve baseline |
| Filesystem partial success or metadata uncertain | migration remains pending with completed steps; expose progress; identical metadata retry only |
| Rename confirmed same ID | active at canonical NEW; establish NEW disk observation, retain acquisition baseline; remove only matching OLD lock; finish journal |
| Return to OLD before any filesystem effect | cancel planned migration safely; retain original identity/turn |
| Pending journal on reopen | recover same ID/OLD→NEW and validate observations; never interpret it as a plain new document |

The runtime may block local input while a submit/move is in progress; still test forced programmatic edits, external writes, renames, unloads, duplicate/late completions and namespace changes. A subprocess result is knowledge about its captured identity, not permanent permission. At most one operation per buffer; one bounded retry/confirmation attempt, then an explicit pending/error state for the operator to retry. Wipeout invalidates callbacks even if process cancellation cannot retract a mutation. Process death is covered by the migration journal and Couch's idempotent identity; no promise of atomic multi-file rollback or power-loss durability is invented.

## Admission, submit and existing turn engine

- Add coordinator attachment from setup_markdown_keymaps. Route the real review_next callback through the coordinator before legacy review prompting. Preserve registry configuration switches and journal-sidecar exclusions; do not install competing Alt+Return mappings.
- Typed legacy and valid cached-agentic attachment remain immediate. Ordinary files get only nonmutating lookup, not register on open/edit. Unknown files remain editable even on failure, with the approved band note; never install an unavailable-state modifiable/readonly barrier. New unnamed buffers retain the current save-first diagnostic; a named not-yet-written note can be authored and saved before registry admission, without creating registration as a side effect of editing.
- Keep a namespace-scoped known-agentic cache in configured state_dir using the shared atomic writer: schema version, canonical path, stable ID, effective/fallback owner and last-confirmed observation. Bound it to256 entries/1MiB with least-recently-confirmed eviction. Cache eviction/corruption is unknown, never proof of plain; no age expiry changes agentic truth. Confirmed lookup absence removes the cached binding, rename updates it after metadata confirmation. Cache writes are local knowledge, not the registry authority. Validate cache input before offline attachment.
- Observe edits while admission is unknown without creating a speculative lock. Preserve the pre-edit content hash and outstanding-edit state through auto-save; use that baseline if lookup later confirms registration. Check native modified=true too for preexisting unsaved edits. Reconcile any intervening foreign write/deletion through the existing preservation path before publishing release/reload. A plain result discards observation state and the unknown band without starting turn timers.
- A single coalesced retry timer (5s initial policy) handles loaded unresolved documents, with the existing bounded request concurrency/queue. Recheck on pane reentry/explicit submit too. Stop the timer when no unresolved loaded documents remain; late callbacks are generation-guarded. Known attached documents never drop protection because a retry fails.
- First submit saves the file without changing frontmatter or process-instruction. Resolve pane owner from the current actor binding and register with the same captured namespace/path. Explicit couch-owner is authoritative; registered response supplies the effective owner. For a typed source not yet registered, Register adopts its legacy ledger/state/shadow without rewriting Markdown. Keep existing typed operation without registration outside this pane-specific flow.
- Attach the known canonical identity/path once. Every owner use (band, ping, violation and submit) derives from this accessor. Body/header edits cannot remove attachment. Owner changes refresh through validated confirmation rather than ad-hoc per-consumer parsing.
- Refactor file_of/owner_of to use the attached stable identity and explicit migration phase, so a name change cannot silently switch disk operations to a free NEW path. Existing on_lines acquisition still runs before auto-save; saves never advance the acquisition baseline. Pending foreign write/deletion reconciliation still precedes every release or move.
- Registered reopens restore turn from disk. Successful null lookup can detach only after reconciling existing state and preserving any operator lock; a failed lookup never detaches. Restore window options/autoread only if this coordinator still owns the installed values.

## Rename/filesystem protocol

Empirical native probe: saveas emits BufFilePre/Post for BOTH the live buffer and an alternate buffer, while NEW does not yet exist; BufWritePre/Post follow, and NEW exists only at post-write. Filter by the attached buffer identity. Do not call Couch rename merely because BufFilePost fired.

1. A typed legacy document may have no registry ID. Register OLD with the effective fallback owner while OLD and its companions are accessible, before permitting the native rename; the source implementation imports State/shadow/history. If this preflight cannot be confirmed, refuse the rename before filesystem effects while keeping normal editing available. Plain never-submitted files still must not register as a rename side effect. Capture OLD canonical identity and owned lock bytes in BufFilePre; invalidate probe/undo callbacks and suspend watch reconciliation. Do not change the buffer name from inside that autocmd.
2. When NEW is known, preflight side-directory, lock and registered-target collisions without overwriting them. Persist a forward-only journal before filesystem effects. For a Parley-owned move perform preflight/reconciliation before moving the document. Native saveas may already have changed the buffer name: preserve that partial progress explicitly.
3. If the operator turn is held, install NEW protection exclusively before the destination write and retain OLD protection until metadata confirmation. Never overwrite an existing different NEW lock. If native write fails, preserve the recorded migration/protection rather than announcing success.
4. Wait until NEW exists and the native save has succeeded. Move an existing `<stem>.side/` without merging a conflicting destination. Rewrite only validated parent backlinks inside that folder. Preserve all other bytes, quoting, fragments and unrelated links; use the existing frontmatter parser and canonical Markdown span scanner. Reject escaping symlinks, ambiguous/malformed backlink data and externally changed backlink files before overwriting them.
5. Extract a raw byte writer from helper.table_to_file_atomic; keep the existing JSON wrapper/API/tests. Reuse its checked write/close/mode/symlink/rename behavior for journal and backlink writes; do not copy a second fallible writer.
6. Record each completed effect and invoke metadata-only Couch rename OLD NEW. OLD may be absent or still present after saveas. Verify returned ID/path/Owner. A successful replay with Changed false is success. On nonzero/registry-uncertain retain completed filesystem work and retry the same tuple, never register NEW or blindly move things back.
7. Establish NEW's loaded disk observation without resetting the lock baseline. Clear OLD-specific foreign/unkept observations; remove only the captured/migrated OLD lock after confirmation. Resume watches and release UI barriers. Delete the completed journal.

Backlinks: `<name>.side/` uses the source filename without its Markdown extension, as in project.md/project.side. For existing children, support the S3 `parent:` frontmatter plus body Markdown links which resolve to that same parent. Compute paths relative to each moved child; preserve a destination fragment. Do not invent or add missing backlink fields. Leave unrelated content alone. S3 creation/inheritance remains separate.

Crash recovery journals live under configured state_dir, partitioned by the selected Couch namespace and stable registry ID. Store schema version, exact OLD/NEW tuple, content/path witnesses and completed step flags, not document contents or arbitrary snapshots. Recover on setup/affected-buffer open before normal admission. If a prepared journal cannot prove which filesystem effect completed, preserve it and show the concrete recovery needed rather than overwrite user data. Budget: at most32 pending journals/namespace, 256KiB each; refuse a new migration before effects when full. Scan at most4096 side-folder entries/512 Markdown backlinks; exceeding that bound stops with preserved progress. These are initial local workload bounds for TL review. Journals are removed on confirmed completion or a confirmed no-effect cancellation; unresolved journals are never aged out.

## Work and verification steps

### 1. Pure model, transport and stateful fake

Files: new document_session.lua, document_move_plan.lua, document_registry.lua; modify couch.lua and tests/helpers/fake_couch.lua. Tests: new tests/unit/document_session_spec.lua, tests/unit/document_move_plan_spec.lua, tests/integration/document_registry_spec.lua; existing tests/unit/couch_spec.lua.

- [ ] Write pure reply/state-sequence tests and observe expected missing-feature reds, emphasizing explicit null versus missing, stale/duplicate events and irreversible uncertain mutations.
- [ ] Add the raw Couch transport and typed registry adapter; keep existing send/query characterization green. All commands use the production argv/process seam.
- [ ] Extend fake_couch with a per-test persistent registry/ID/rename ledger, exact registry-request log, controlled release barriers, failures and applied-but-reply-lost operations. Preserve existing actors/status/send env modes and send-only logs. Unknown verbs must not masquerade as sends.
- [ ] Run the focused registry/model tests green, including fake self-conformance; commit the coherent change.

### 2. First-submit and shared-turn admission

Files: new agentic_document.lua; modify session_sync.lua, review_send.lua, init.lua and registry help descriptions. Tests: session_sync integration/native, review_send and keybinding specs; new tests/integration/agentic_document_spec.lua as needed.

- [ ] Drive the actual installed Alt+Return mapping red in a child Neovim with auto-save installed BEFORE opening/attachment. Pin first-submit disk bytes and register-before-send order, explicit owner priority, no-business-owner routing and never-submitted plain behavior. Exercise a known cached document reopened with Couch down, an uncached editable unknown document, and Couch recovery after edits auto-saved modified=false; verify the original edit baseline and resumed lock.
- [ ] Integrate the pure model/coordinator with the single existing edit engine; exercise real dd/x/p/u/dot/insert after new attachment and after an agent reload, baseline undo/redo under auto-save, pre-existing lock and explicit-save behavior.
- [ ] Control pending lookup/register completion across edit/rename/unload/repeat submit and actor changes. Assert no stale attachment/send/unlock and no automatic duplicate sends; exercise unsupported-binary and malformed envelopes.
- [ ] Preserve typed/outside-pane behavior and deliberately update superseded pane review-prompt/same-slot-refusal expectations. Run the mapped session-sync, review and keybinding groups sequentially; commit.

### 3. Migration and recovery

Files: new document_move.lua; modify helper.lua, agentic_document.lua, session_sync.lua and shared Parley-owned rename entry points. Tests: helper_io plus new document-move specs and native rename cases.

- [ ] Add red pure/path/backlink tests plus real saveas/file+write event-order tests with a held operator turn, pending foreign overwrite/deletion and delayed OLD callbacks.
- [ ] Implement preflight, exclusive NEW protection, journal, side-folder/backlink effects and confirmed metadata handoff. No destructive rollback of uncertain external effects.
- [ ] Inject target collision, absent OLD, retained OLD after saveas, missing NEW, EXDEV, failed backlink/journal write, unkeepable agent copy and undecided disk observation. Assert each partial effect and recovery path, not only final notifications.
- [ ] Restart the child editor at filesystem/metadata cut points; recover the same registry ID or retain a visible pending journal. Check no abandoned OLD lock or NEW protection gap on successful migration. Commit.

### 4. Conformance, docs and delivery

Files: atlas/modes/session_sync.md, atlas/modes/review.md, atlas/traceability.yaml, README.md, TOOLING.md and new scripts/check-couch-registry-conformance.py/maintainer target.

- [ ] Add an opt-in real/fake conformance driver through production Lua transport using pair's supported isolated temporary namespace. Set an absolute COUCH_ISOLATED_ROOT, scrub inherited outside Couch/store/pair-data/identity overrides, and keep every source/fixture within that root. Bootstrap the singleton with --adopt-store ABS_STORE --pair-data ABS_PAIR --identity-dir ABS_IDENTITY preview, then apply its digest with --apply; never fall back to the OS account singleton. Registry verbs need no live actors/server after this selection exists. Refuse unsupported binaries and prove a stray outside override cannot touch production. Cover register→lookup→repeat register→metadata rename→old/new lookup, legacy adoption, distinct owner and unavailable/malformed failures. Confirm a mutated fake fails. Never use the operator registry. Run on runner/fake changes and before close; pair's targeted tests are complementary evidence, not editor acceptance.
- [ ] Update the existing atlas pages and adjacent README behavior, with the intentional explicit-owner routing change and first-submit semantics. Map new model/client/coordinator/move tests; preserve index links. The TL owns the ops project file.
- [ ] Run make -k test-spec SPEC=modes/session_sync, SPEC=modes/review and SPEC=ui/keybindings sequentially, plus focused helper/move targets; lint and git diff --check. Push PR; run sdlc local-check run --name suite before close. Keep all failures, not just the first.
- [ ] Close through the one mandatory fresh-context review; fix each entire finding class and record evidence. After pair#573 lands and the real binary conformance passes, stage with sdlc stage --build on :0 only with hub authorization, for the combined operator check. Do not land before live acceptance. Land on SHIP, clear stage and report verified PR/merge to the hub.

## Operating envelope, provenance and residue

ARCH-CONSTRAINTS: one-shot admission on named Markdown open, explicit submit and explicit rename, never IPC per keystroke. Ordinary proven-plain files have no lock/watch/probe timers. Unknown/unavailable files remain editable and share one bounded retry timer; a cache hit retains immediate protection. One mutation per buffer; bounded pending completion/confirmation and no recursive automatic retry. Initial workload assumption: at most32 loaded agentic documents per editor; at most4 concurrent registry queries, a bounded queue of64, and an explicit unavailable result on overflow. Child requests have a 2.5s client deadline against Couch's documented 2s registry budget. Existing watcher cadence stays unchanged. Registration refuses documents beyond Couch's 4MiB bound rather than silently falling back. Exercise queue/size bounds without timing assertions; confirm material budget changes with TL.

ARCH-SECURE: CLI output, paths, edited frontmatter, journal files and side-document text are untrusted inputs. Parse at their boundaries; bad version/schema/identity is unavailable/pending, not a fabricated default. No credentials, new services or network needed. Portable fake state and real conformance storage live in per-test temporary directories; ensure fixture environment cannot reach production registry/ledger.

ARCH-FUNERAL: per-buffer models, barriers, callbacks and handles die on wipeout; generation guards prevent late effects. Couch owns bounded persistent registrations until forget. Parley owns a bounded cache (confirmed absence removes entries; eviction only loses offline knowledge) plus bounded pending migration journals and atomic-writer temporary files; completed journals are deleted, existing startup cleanup owns obsolete atomic temps, and uncertain journals remain explicitly recoverable. Existing `.lock`, `.clobbered` and `.side` lifecycles remain their documented owners; do not prune user side documents.

## Revisions

- 2026-10-15 — initial draft after #327 landing; agrees the pair#573 caller contract, separates typed legacy behavior from plain-file admission, and names the lookup/rename ordering hazards discovered in read-only exploration. TL failure-policy decision and pair legacy-adoption/isolation details remain open. No implementation/change-code/estimate yet.

- 2026-10-15 — TL availability decision supersedes the initial read-only proposal: all unknown/unavailable files stay editable because Couch is the exclusive CAS write path and cannot write while unreachable. Add a small bounded persistent known-agentic cache, unknown-state band, coalesced re-lookup and outstanding-edit observations that survive auto-save. A recovered registration acquires against the pre-edit baseline. Forward-only rename recovery is explicitly approved. No implementation yet.

- 2026-10-15 — verified TL approval f96cd3f0-f712-4ed6-917f-eb348dc75b8c. Bounded read-only peer-source exploration resolves typed legacy adoption and supported isolated singleton setup; do not wait on a queued peer answer to rediscover explicit source behavior. The executable and real integration remain unverified until pair#573 is ready. Freeze callable boundaries and pre-register a typed OLD before native rename; a failed preflight blocks only that unsafe migration, never ordinary editing.
