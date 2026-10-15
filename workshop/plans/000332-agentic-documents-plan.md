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
| `classify_reply`, `new` — lifecycle and registry reply model | PURE | `lua/parley/document_session.lua` | new |
| `project`, `rewrite_parent`, `side_path`, `is_markdown_path` — migration, filenames and backlink projection | PURE | `lua/parley/document_move_plan.lua` | new |
| `run` — raw Couch process transport | INTEGRATION | `lua/parley/couch.lua` | modified |
| `request`, `shutdown` — typed registry client and request lifetime | INTEGRATION | `lua/parley/document_registry.lua` | new |
| `attach`, `identity`, `status`, `recheck`, `submit`, `detach`, `move_membership`, `move_path` — buffer admission and known-path cache | INTEGRATION | `lua/parley/agentic_document.lua` | new |
| `begin`, `advance`, `pending`, `recover` — file migration and journal recovery | INTEGRATION | `lua/parley/document_move.lua` | new |
| `acquire` — cross-editor operation lease | INTEGRATION | `lua/parley/document_lease.lua` | new |
| `attach`, `identity`, `is_session_sync`, `detach`, `acquire_observed` — stable attachment and observed edits | INTEGRATION | `lua/parley/session_sync.lua` | modified |
| `prepare_submit`, `send_registered`, `release_if_baseline` — shared save, send and turn release | INTEGRATION | `lua/parley/session_sync.lua` | modified |
| `begin_move`, `install_move_lock`, `finish_move`, `abort_move`, `restore_move` — turn-preserving migration handoff | INTEGRATION | `lua/parley/session_sync.lua` | modified |
| `write_file_atomic`, `table_to_file_atomic` — atomic byte writer and JSON wrapper | INTEGRATION | `lua/parley/helper.lua` | modified |
| `write` — stateful executable registry fake | INTEGRATION | `tests/helpers/fake_couch.lua` | modified |

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
- document_move.begin/advance/recover implement the journaled effects through an injectable filesystem adapter and the pure lifecycle model. document_lease.acquire(namespace,key) returns a nonblocking, kernel-owned exclusive handle or busy/unavailable; no filesystem effect is authorized without that handle. helper.write_file_atomic(text,path,adapter) is the canonical checked byte writer; table_to_file_atomic remains the encoding wrapper.

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

- Add coordinator attachment from setup_markdown_keymaps. Route the real review_next callback through the coordinator before legacy review prompting. Preserve registry configuration switches and journal-sidecar marker/review exclusions; pane Alt+Return itself still applies to any named Markdown, including a journal file, without invoking its excluded marker scan. Install the callback through the existing registry entry, not competing mappings.
- Typed legacy and valid cached-agentic attachment remain immediate. Ordinary files get only nonmutating lookup, not register on open/edit. Unknown files remain editable even on failure, with the approved band note; never install an unavailable-state modifiable/readonly barrier. New unnamed buffers retain the current save-first diagnostic; a named not-yet-written note can be authored and saved before registry admission, without creating registration as a side effect of editing.
- Keep a namespace-scoped known-agentic cache in configured state_dir using the shared atomic writer: schema version, canonical path, stable ID, effective/fallback owner and last-confirmed observation. Bound it to256 entries/1MiB with least-recently-confirmed eviction. Cache eviction/corruption is unknown, never proof of plain; no age expiry changes agentic truth. Confirmed lookup absence removes the cached binding, rename updates it after metadata confirmation. Cache writes are local knowledge, not the registry authority. Validate cache input before offline attachment.
- Observe edits while admission is unknown without creating a speculative lock. Preserve the pre-edit content hash and outstanding-edit state through auto-save; use that baseline if lookup later confirms registration. Check native modified=true too for preexisting unsaved edits. Reconcile any intervening foreign write/deletion through the existing preservation path before publishing release/reload. A plain result discards observation state and the unknown band without starting turn timers.
- A single coalesced retry timer (5s initial policy) handles loaded unresolved documents, with the existing bounded request concurrency/queue. Recheck on pane reentry/explicit submit too. Stop the timer when no unresolved loaded documents remain; late callbacks are generation-guarded. Known attached documents never drop protection because a retry fails.
- First submit saves the file without changing frontmatter or process-instruction. Resolve pane owner from the current actor binding and register with the same captured namespace/path. Explicit couch-owner is authoritative; registered response supplies the effective owner. For a typed source not yet registered, Register adopts its legacy ledger/state/shadow without rewriting Markdown. Keep existing typed operation without registration outside this pane-specific flow.
- Attach the known canonical identity/path once. Every owner use (band, ping, violation and submit) derives from this accessor. Body/header edits cannot remove attachment. Owner changes refresh through validated confirmation rather than ad-hoc per-consumer parsing.
- Refactor file_of/owner_of to use the attached stable identity and explicit migration phase, so a name change cannot silently switch disk operations to a free NEW path. Existing on_lines acquisition still runs before auto-save; saves never advance the acquisition baseline. Pending foreign write/deletion reconciliation still precedes every release or move.
- Registered reopens restore turn from disk. Successful null lookup can detach only after reconciling existing state and preserving any operator lock; a failed lookup never detaches. Restore window options/autoread only if this coordinator still owns the installed values.

## Exclusive migration ownership and temporary cleanup

A namespace/registry-ID operation lease spans planning, filesystem execution, metadata confirmation and recovery. Acquire it before a native rename can cause filesystem effects or before reading a journal as recoverable. Its file descriptor remains held across async work; every declared effect carries the same lease generation. Another editor gets busy, may view the document, and cannot execute/recover/replace that journal. Under the lease, compare ID and the exact OLD→NEW tuple before effects; a different pending tuple refuses until the original finishes or a no-effect cancellation is proven.

Use the existing POSIX kernel flock facility through LuaJIT FFI over a libuv-opened private lock-file descriptor; no new service/install. Nonblocking exclusive acquisition plus close-on-exec is required. Process death releases ownership in the kernel, so recovery acquires normally; never steal based on an age timeout or PID probe. A live but slow editor retains ownership. On unsupported backends or unknown native errors, migration is unavailable; ordinary editing and registration still work. Current targets are macOS and Linux Neovim/LuaJIT; the local macOS runtime was probed for the exported flock symbol before choosing this backend.

Keep the lock inode stable during use. After acquisition compare the opened descriptor's device/inode with its named path; if unlink/replacement raced acquisition, close/retry before any effect. A GC operation also acquires the same lock and can remove a retired ID's file only after confirmed Couch absence, no pending journal and no cached/loaded owner. Descriptor/path revalidation prevents waiters on the retired inode from acting on a new lock file. Bound lease files to4096 IDs per namespace; cleanup is opportunistic on confirmed forgetting/completed recovery, never based on a failed registry probe. Overflow refuses a new migration before effects. Always release owned handles on completion/unload; keep an uncertain journal even when releasing its handle. A subsequent owner may only confirm/retry its exact tuple.

New raw-writer temporaries use explicit operation-owned names/paths recorded BEFORE creation, not the legacy generic temp glob. Journal/backlink temporary paths belong to the migration manifest and can be cleaned only while holding that document's lease after owner death/confirmed completion; validate every recorded path against its managed journal location or side-folder root. Cache writes/cleanup use a separate namespace cache lease and managed temporary bucket. Never scan/delete another editor's live temp, an unmanifested file, or an arbitrary sibling with a similar suffix. Immediate failures clean only the current writer's own temp. Recovery cleans declared leftovers under the acquired lease. Corrupt/unprovable leftovers remain visible for bounded manual recovery; do not claim the existing nonrecursive startup cleanup covers these new locations.

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

## Function-level verification strategy

| Risky function | Adversarial class and mechanical guard |
|---|---|
| document_session.classify_reply | Generate malformed envelopes/exit/null-presence combinations; only the exact absence witness may produce absent, and invalid responses produce no mutation effects. |
| document_session controller dispatch | Generate bounded event sequences with stale identities and uncertain outcomes; assert one operation, immutable identity, no stale send/unlock and no rollback of possibly completed effects. |
| document_registry.request / couch.run | Use the persisted executable fake with release barriers; independently assert argv, typed outcomes, bounds and callback consumption across process completion order. |
| agentic_document.attach/submit | Drive the actual Alt+Return mapping and native editor input with auto-save installed first; assert file bytes, registry/send order, owner routing and resumed lock/baseline behavior rather than mocked callback counts. |
| Cached admission/recovery | Restart the child editor across unavailable/available observations and native edit sequences; assert unknown remains editable and cached or recovered identity never loses required protection to auto-save. |
| document_move_plan.project | Generate path/entry observations at the trust boundary; assert only intended contained effects, no target overwrites and deterministic refusal of ambiguous input. |
| document_move_plan.rewrite_parent | Fuzz quoted/malformed frontmatter and Markdown spans from corpus seeds; assert unrelated bytes stay identical and the validated parent rewrite is idempotent. |
| document_lease.acquire | Controlled two-editor/process ordering proves exclusive execution, kernel release after process death and descriptor/path revalidation; unavailable acquisition authorizes no effects. |
| document_move.begin/advance/recover | Inject interruption after each effect with two editor owners and delayed metadata confirmation; assert stable ID/tuple, preserved partial progress, turn/baseline continuity and no destructive rollback. |
| helper.write_file_atomic / cleanup | Inject each IO-stage failure and overlap live writers; assert preservation of target content/mode, cleanup of only manifested owned temps and recovery of nested locations under their lease. |
| Real/fake conformance driver | Run both executables through production Lua transport in the supported isolated singleton; compare consumed protocol semantics and reject a deliberately mutated fake. |

## Work steps (one close boundary)

### 1. Model, lease and registry boundary

Files: new document_session.lua, document_move_plan.lua, document_lease.lua and document_registry.lua; modify couch.lua and tests/helpers/fake_couch.lua. Tests: new unit document_session/document_move_plan specs, integration document_lease/document_registry specs; existing couch_spec.

- [x] Write the named function-strategy tests and observe expected missing-feature reds; record evidence before implementation.
- [x] Implement the pure controllers/projections and the one process seam, lease and typed client; preserve existing send/query characterization.
- [x] Extend the process fake with persisted identity/ledger state and controlled outcomes while preserving the current send-only log/env contract. Unknown verbs refuse.
- [x] Run focused model/client/lease tests green and commit the coherent change.

### 2. Admission and existing turn integration

Files: new agentic_document.lua; modify session_sync.lua, review_send.lua, init.lua and registry help descriptions. Tests: session-sync native/integration, review-send/keybinding specs and new agentic_document integration specs.

- [ ] Add the production-trigger acceptance checks described by attach/submit and cached-admission strategies; observe the red behavior with real auto-save ordering.
- [ ] Integrate the coordinator with the single edit-turn engine and normalized owner/path accessor, including the TL's editable-unknown policy.
- [ ] Preserve outside-pane behavior and update deliberately superseded pane routing expectations; run mapped session-sync/review/keybinding groups sequentially, then commit.

### 3. Filesystem migration/recovery

Files: new document_move.lua; modify helper.lua, agentic_document.lua, session_sync.lua and shared Parley-owned rename entry points. Tests: helper_io and new document_move specs plus the native production-trigger tests.

- [ ] Write the project/rewrite/acquire/recover strategy tests, including a controlled two-editor schedule, before implementing effects.
- [ ] Implement leased preflight, journaled filesystem effects, native-write ordering and confirmed metadata handoff as specified above.
- [ ] Run recovery/cleanup strategies and the real native saveas/file+write checks green; commit.

### 4. Conformance, docs and delivery

Files: existing session-sync/review atlas, traceability, README, TOOLING and new scripts/check-couch-registry-conformance.py/maintainer target.

- [ ] Add the isolated real/fake driver. Set an absolute COUCH_ISOLATED_ROOT, scrub inherited outside storage/identity overrides, and bootstrap --adopt-store ABS_STORE --pair-data ABS_PAIR --identity-dir ABS_IDENTITY preview then --apply DIGEST, with all paths inside the root. Never fall back to the OS account singleton; refuse unsupported binaries. Follow the function strategy and require the deliberately corrupted fake to fail. Run after seam/fake changes and before close. Pair's targeted tests complement this check; they are not editor acceptance.
- [ ] Update the existing atlas and adjacent README contract, including intentional owner routing and first-submit changes; map all new model/client/coordinator/lease/move tests. The TL owns the ops project.
- [ ] Run make -k test-spec for modes/session_sync, modes/review and ui/keybindings sequentially plus focused helper/move targets; lint and diff checks. Push PR and run sdlc local-check run --name suite before close, preserving every failure.
- [ ] Close through the mandatory fresh-context review and fix complete finding classes. After pair#573 lands and real conformance passes, obtain hub staging authorization and run sdlc stage --build for the combined live check. Land only after operator acceptance; clear stage and report verified PR/merge.

## Operating envelope, provenance and residue

ARCH-CONSTRAINTS: one-shot admission on named Markdown open, explicit submit and explicit rename, never IPC per keystroke. Ordinary proven-plain files have no lock/watch/probe timers. Unknown/unavailable files remain editable and share one bounded retry timer; a cache hit retains immediate protection. One mutation per buffer; bounded pending completion/confirmation and no recursive automatic retry. Initial workload assumption: at most32 loaded agentic documents per editor; at most4 concurrent registry queries, a bounded queue of64, and an explicit unavailable result on overflow. Child requests have a 2.5s client deadline against Couch's documented 2s registry budget. Existing watcher cadence stays unchanged. Registration refuses documents beyond Couch's 4MiB bound rather than silently falling back. Exercise queue/size bounds without timing assertions; confirm material budget changes with TL.

ARCH-SECURE: CLI output, paths, edited frontmatter, journal files and side-document text are untrusted inputs. Parse at their boundaries; bad version/schema/identity is unavailable/pending, not a fabricated default. No credentials, new services or network needed. Portable fake state and real conformance storage live in per-test temporary directories; ensure fixture environment cannot reach production registry/ledger.

ARCH-FUNERAL: per-buffer models, barriers, callbacks and handles die on wipeout; generation guards prevent late effects. Couch owns bounded persistent registrations until forget. Parley owns a bounded cache (confirmed absence removes entries; eviction only loses offline knowledge) plus bounded pending migration journals and atomic-writer temporary files; completed journals and their manifested temps are removed under the lease, managed cache temps have their own lease-protected cleanup, and uncertain journals remain explicitly recoverable. Existing `.lock`, `.clobbered` and `.side` lifecycles remain their documented owners; do not prune user side documents.

## Revisions

- 2026-10-15 — pair:5's submitted answer a6560099-ad36-400f-83b2-1b8a32bf7ffb confirms source-derived adoption and pre-register-OLD ordering. Its candidate binary at pair-slot5/pair/bin/couch reports revision49c3285c847133f6f10005c12fee584bac30989a; pair#573 is not landed, full suite/review pending. The supplied isolated helper explicitly clears inherited namespace/storage identity and bootstraps the public adopt-store preview/apply under COUCH_ISOLATED_ROOT. Alias spelling registration may return Changed true once while preserving ID/time/state; exact replay is false. This refines conformance fixtures without changing the admitted design. change-code passed at3859cf1f; implementation starts with bounded pure-model/projection/lease tasks and the registry process seam.

- 2026-10-15 — initial draft after #327 landing; agrees the pair#573 caller contract, separates typed legacy behavior from plain-file admission, and names the lookup/rename ordering hazards discovered in read-only exploration. TL failure-policy decision and pair legacy-adoption/isolation details remain open. No implementation/change-code/estimate yet.

- 2026-10-15 — TL availability decision supersedes the initial read-only proposal: all unknown/unavailable files stay editable because Couch is the exclusive CAS write path and cannot write while unreachable. Add a small bounded persistent known-agentic cache, unknown-state band, coalesced re-lookup and outstanding-edit observations that survive auto-save. A recovered registration acquires against the pre-edit baseline. Forward-only rename recovery is explicitly approved. No implementation yet.

- 2026-10-15 — verified TL approval f96cd3f0-f712-4ed6-917f-eb348dc75b8c. Bounded read-only peer-source exploration resolves typed legacy adoption and supported isolated singleton setup; do not wait on a queued peer answer to rediscover explicit source behavior. The executable and real integration remain unverified until pair#573 is ready. Freeze callable boundaries and pre-register a typed OLD before native rename; a failed preflight blocks only that unsafe migration, never ordinary editing.

- 2026-10-15 — plan gate PQ-1/PQ-2/PQ-3: define cross-editor execution/recovery ownership with a kernel advisory lease and exact-tuple rejection, replace test inventories with named adversarial function strategies, and correct the false recursive-cleanup assumption using lease-owned temp manifests. Include the native backend/unsupported failure policy and real two-editor tests. Also distinguish journal review exclusion from the any-Markdown pane submit requirement. No implementation yet.

- 2026-10-15 21:08 UTC — architecture guard alignment after the mapped keybindings check found unnamed exported functions: expand the Core-concepts tables from module descriptions to the implemented public symbols and their module paths. This makes both code-to-table and table-to-definition sweeps cover the delivered surface; no feature or scope change.

- 2026-10-15 — keep the exported-function catalog authoritative in this durable plan; the issue table names modules and links here. Duplicating both catalogs made the reverse-definition guard run the same filesystem searches twice and hit its50s deadline; one representative grep took0.82s. The unchanged guard passes with one catalog. Also correct the implementation's accidental lowercase.md admission restriction: reuse Parley's existing Markdown classifier, the assets filename classifier for child files, and one shared side-path helper. Registered parent identity supplies the move's admission proof; .markdown, uppercase extensions and extensionless Markdown buffers retain their actual stems. The original any-Markdown scope is unchanged.

### 2026-10-15 — Public mover ordering

The actual move_chat and move_chat_tree doors accept ordinary Markdown and rename OLD before native buffer-name hooks run, with no subsequent write required. Route registered non-chat documents through the same durable migration executor before filesystem effects. Persist an owned-parent-rename intent, use atomic no-replace rename, and recover by captured inode/hash proof; native saveas retains its separate successful-write witness. Preflight tree membership before moving siblings. Regression tests exercise both real public doors, free and held locks, side/backlink preservation and restart cutpoints (ARCH-DRY, ARCH-MOCK).
