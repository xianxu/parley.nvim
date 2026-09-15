# Tool Execution and Cleanup

Tool execution has two independent outcomes: what happened to the requested
resource, and whether the process or filesystem operation has finished cleanup.
The response owns each tool's transcript slot; the execution service owns its
resource claims and outstanding physical work. See [Tool Use](tool_use.md) for
the chat loop and [Chat Write Ownership](../chat/ownership.md) for buffer grants.

## Captured authority and admission

`tools/dispatcher.lua` captures selected definitions, root policy, cwd, private
recovery directory, and presentation limits in an opaque profile. Preparation
copies validated input and resolves canonical resource claims before execution.
Native JSON empty-object markers become plain argument tables. JSON null values
are currently refused explicitly; preparation never silently drops them.
The scheduler captures each actual `execute_async` function and its config;
changing the registry, current buffer, cwd, or agent settings later does not
replace an admitted capability. Preparation receipts bind result normalization
to the captured call and paging policy.

`tools/operation.lua` identifies a call by generation, attempt, round, and provider
call ID. Acceptance records its copied arguments and capability before effects
can start. A duplicate with changed arguments or authority conflicts. A known
result is reused while its generation remains active; a partial or unknown
operation is never replayed automatically. Closing a generation retires its
admission handle and callbacks. Uncertain work remains retained; completed
records are pruned without accumulating tombstones.

`tools/resources.lua` admits all claims atomically or queues the operation.
Canonical file/subtree claims support shared reads and exclusive writes; a global
claim is exclusive. Queued conflicting requests keep FIFO order, and an older runnable waiter
gets available capacity first. Disjoint work, including in the same document,
may proceed around a blocked resource claim.
Cancellation removes queued work immediately. Running work retains its claims
until both effect certainty and physical completion are positive.

Builtin claim declarations live in `tools/async_builtin.lua`: reads use file or
subtree claims; edits claim the parent subtree for target and numbered backup;
`write_file` claims the write-root subtree because it may create missing parents.
Undeclared custom effects receive a conservative global claim. Canonicalization
and private-path checks belong to the dispatcher, not the pure overlap service.

## Effect evidence and physical completion

| Observation | Effect handling | Physical handling |
| --- | --- | --- |
| Known applied, not applied, or partial | Record and reuse the known result | Release only after explicit cleanup evidence |
| Unknown effect | Retain the operation and resource claims | A drained process alone does not determine the external effect |
| Cancellation request | Stop further admission; request owned cancellation | Wait for original callbacks and cleanup |
| Formatter failure | Preserve previously recorded effect evidence | Does not manufacture or revoke cleanup evidence |

Backend observations carry `certainty`, `effect`, `physical_resolved`, `result`,
and evidence. The scheduler records known effects before normalization, paging,
or callback delivery. A positive physical barrier can resolve the document's
child operation while an unknown external effect remains quarantined in the
process-scoped resource service. Callback delivery and new execution return to
Neovim's main loop.

Scheduler and Tasker reconciliation probe at 50ms initially, double the interval
up to 1000ms, and stop polling after five seconds with an unresolved diagnostic.
This is a diagnostic deadline, not fabricated completion. Resources and admission
capacity remain retained. Later original callbacks can still settle the work.
Ordinary running processes have no five-second execution deadline.

For explicit effect reconciliation, the internal API is
`service:reconcile(operation, {certainty='known', effect=..., result=...,
evidence=...})`. It requires a typed known effect and nonempty bounded evidence;
it never re-executes the effect. A caller-supplied `physical_resolved` cannot
replace backend cleanup evidence. `service:reconcile_step()` and handle probes
only inspect outstanding work. `ParleyToolOperations` presents this evidence and
accepts an explicit effect classification, as described below.

## Pure lifecycle authority

`tools/operation.lua` authorizes execution, claim release and record retirement.
Its transitions join known effect evidence with backend physical completion,
track generation closure and callback delivery, and determine probe deadlines.
The scheduler consumes those permissions; rejected transitions cannot launch a
tool, release a claim, or remove its retained record.

`tools/filesystem_operation.lua` owns request admission, unique completion IDs,
cancellation, effect certainty and cleanup/publication decisions. The filesystem
adapter retains descriptors, bytes and identity observations and performs only
authorized requests. `skill_source_read.lua` similarly owns the shared read pool,
logical completion, physical retirement and deadline decisions. The skill adapter
retains its source proof, UI callbacks, timer and read handle. Direct pure sequence
tests and adapter rejection controls defend each boundary.

## Checked filesystem transactions

`tools/filesystem.lua` supplies callback-based `stat`, `read`, `write_checked`,
and `ensure_dir`. Revision evidence includes existence, inode/device/type, size,
mode, and nanosecond mtime/ctime. Reads validate revisions around bounded IO.
An existing-file write follows this sequence:

1. Read the expected source and write a private exclusive backup temporary.
2. Check short writes, fsync, and close; publish the backup atomically without
   overwriting an existing destination, then sync its parent directory.
3. Revalidate both target path and opened descriptor before truncation.
4. Write bounded chunks, fsync, and check close.

New files use exclusive creation. Missing parents are created asynchronously
under an existing captured write root, with symlink/non-directory refusal and
parent fsync. Created directories remain recorded effects if later work fails.
The host holds the matching resource claim throughout; these checks do not
provide serialization with writers in other processes.

An ambiguous close is never retried solely by numeric descriptor. Reconciliation
uses `fstat`: `EBADF` establishes absence; a different identity establishes that
old ownership is gone without closing the reused descriptor. Same-inode reuse
cannot be distinguished safely and remains quarantined. Missing callbacks keep
the original request pending. Descriptor cleanup alone cannot resolve uncertain
target-write effects.

## Bounds and private data

The shared producer owns the `tool_execution` setup defaults below. Configuration
validates finite positive values and permits lowering these ceilings. It refuses
changes while producer clients, supervisor records or Tasker work remain active.

| Owner | Default bound |
| --- | --- |
| Operation/scheduler | 128 retained records; arguments 64KiB, 8192 nodes, depth 32 |
| Scheduler result retention | 512KiB per result; 16MiB aggregate content in the shared producer; truncation is marked |
| Resource admission | 16 running, 128 queued, 8 running/document, 4 running/generation, 32 queued/generation, 32 claims/call |
| Filesystem | 1MiB prior plus replacement bytes; chunks at most 64KiB; 32768 IO steps plus bounded cleanup allowance |
| Builtin transforms | 32768 lines, 128 proposed edits, 8MiB aggregate replacement work; directory depth 128 |
| Tasker admission | 16 provider attempts, 16 tool attempts, 32 total including utilities; 4 generations/document, 8 tools/document, 4 tools/generation |
| Tasker capture | 1MiB stdout, 64KiB stderr per attempt; 16MiB aggregate retained bytes |

Tasker permits only lowering its admission defaults. Per-stream capture has hard
ceilings of 16MiB stdout and 1MiB stderr. Provider transport explicitly disables
stdout retention and delivers chunks of at most 64KiB. Overflow cancels only the
owning attempt; capacity is freed after exit and both pipe EOF observations.
Diagnostic logs omit command arguments and raw tool errors.

Captured policy denies explicit access to the private answer-recovery subtree,
including aliases. Search adapters exclude that subtree before traversal;
recursive `ls` refuses an overlapping private subtree. Read roots do not widen
write authority. Help uses a captured installed-document catalog rather than
arbitrary model-supplied paths. See [Tool Use safety](tool_use.md#safety) for
structured argv and result paging.

## Implementation and verification

The execution path is `response_tools` or `skill_invoke` → `tools/producer` →
`tools/dispatcher` → `tools/scheduler` → captured
`tools/async_builtin` → `tasker` or `tools/filesystem`. Pure operation/resource
reducers carry identity and admission; stateful process/filesystem fakes exercise
missing, late, duplicate, cancellation, and uncertain callbacks. Native tests
check actual libuv filesystem writes and overlapping subprocesses with an editor
heartbeat. The canonical test list is `providers/tool_execution` in
`atlas/traceability.yaml`.

### Parent retirement and operator reconciliation

A cancelled response uses the distinct `operation_supervised` transition to hand
its tool ownership to the process supervisor. This permits local response and
Document retirement without asserting effect success or physical completion.
The supervisor severs parent callbacks, retains unknown claims and admits only
nonconflicting work. Normal child completion cannot request this transition.

`ParleyToolOperations` uses stable process-lifetime operation IDs, captured tool
names, document/generation scalars, claims and evidence. Operator-confirmed effect
classification goes through `tools/producer.reconcile`; only backend observations
can establish physical cleanup. IDs do not alias after idle reconfiguration.

`tool_execution` has `process` and `resources` subtables matching the table above,
plus `max_records`, `max_result_bytes`, `max_total_result_bytes`, `max_file_bytes`.
Per-agent result limits may be smaller. Confirmed backup footers count toward the
result budget; an unrepresentable footer produces a bounded error while the
independent operation evidence remains inspectable.

### Maximum-queue work check

The resource reducer caches exact component-ordered claim indexes and reuses the
blocked-prefix proof within one pump. A128-waiter/32-claim chain measured roughly
644ms before this change and at most13ms in five native samples after it. A
4000-byte shared component produced a similar13ms result; all-disjoint capacity
queues stayed below0.1ms. These are diagnostic timings, not latency guarantees.
A JIT-disabled VM-call regression bounds deterministic pump work; collision tests
ensure cached ordering never weakens exact path/ancestor conflicts.

## Effect-time paths and editor reconciliation

`tools/path_authority.lua` captures directory and resource identities alongside
canonical claims. Each path operation resolves components relative to pinned
parent descriptors with no-follow opens in a libuv worker. Renaming an admitted
ancestor cannot redirect a queued operation. Capabilities constrain subsequent
paths, including backup publication and missing-directory creation. The backend
requires LuaJIT plus POSIX descriptor-relative calls on macOS/Linux; unsupported
builds refuse protected execution. Native conformance was run on macOS.

Builtin traversal runs through `process_scope` and `process_bootstrap`: a clean
Neovim child imports the bounded authority, pins one target, then replaces itself
with the captured command. Directory targets become its pinned cwd; regular files
remain inherited descriptors. Multiple search targets run sequentially inside
one owned tool operation. No child-follow flags are accepted, and private-path
exclusions are translated before traversal. Tasker owns the same process through
bootstrap, exec, cancellation, exit and drain. A19-byte stderr handshake
distinguishes successful bootstrap from a search returning no matches; Tasker
accounts that bounded control metadata in addition to the body capture budget. This protects admitted path
identity; it does not serialize arbitrary external writers or sandbox custom
programs. Authority payloads are limited to64KiB, path depth128, captured identity
entries4096 and command targets32. Ambiguous intermediate descriptor closes stay
quarantined until positive probe evidence; they are never blindly retried.

`file_transform` owns pure edits, insertion and numbered-read policy for both
async and compatibility handlers. `file_refresh` captures open-buffer identity
and revision before IO. A confirmed write refreshes unchanged autoread buffers
from committed bytes, without reopening the pathname. Intervening edits, ABA,
rename, unsupported encoding or a refused Document grant preserve the buffer and
report reconciliation required. Only an unchanged post-apply tick and exact text
permit clearing modified state. Chat Document refresh retains the64KiB User-edit
bound; larger replacements require reconciliation.

`result_evidence` preserves incomplete-output and reconciliation evidence through
scheduler caps, paging, normalization, path-label expansion, serialization,
provider continuation and skill results. Body retention remains capped. Fixed
notices use at most72 metadata bytes per result (9216 across128 records), including
zero body capacity; they cannot disappear into an empty apparent success.

### Publication identity and final source ownership

A completed temporary pre-image keeps its descriptor-derived identity through
link publication and cleanup. The published backup is checked for exact bytes
and identity after directory sync; native truncation revalidates its revision.
Substituted temporary/backup leaves are not certified or deleted. Dynamic created
identities are bounded to256 entries/64KiB per authority. Uncertain artifact
obligations remain visible separately from unresolved descriptors.

`traversal_policy` applies mandatory exclusions after each target is expanded and
after optional filters. Literal-safe rg/grep/find patterns and exact ack directory
exclusion prevent globs, hidden/ignore flags or metacharacter names from widening
private access. Recursive ls still refuses overlap. Chat-history search shares
the same policy; there is no independent exclusion-string implementation.

Skills defer intermediate refresh only for their captured source buffer, leaving
other open buffers on the shared tool-refresh path. The skill owns the original
User proof and final identity-bound read; it cannot forgive its own or a human's
unrelated edit by recapturing authority. Up to16 final source reads retain at most
1MiB each. Cancellation revokes logical completion but retains the per-buffer
physical slot until cleanup is positive. Reconciliation stops polling after five
seconds and reports uncertainty; a late positive callback can still retire it.
