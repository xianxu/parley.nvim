# Private editor endpoints

Registered live Markdown buffers advertise private Unix RPC listeners from ordinary
Neovim opens. Couch owns the current binding; Parley owns the listener and its
attachment lifetime. This supplies editor endpoints for a future remote adapter;
it does not add a remote interface or change submission.

In a Couch pane, session-sync hands off its confirmed registration, including a
later legacy-to-registered identity upgrade. Legacy headers alone cannot publish
an endpoint. Outside Couch, each named Markdown buffer incarnation gets one
read-only membership lookup. Only a confirmed Namespace, ID and canonical File
can start publication; null, malformed or unavailable discovery creates no
listener and never registers the document. Outside-pane Alt+Return retains its
existing review and typed legacy session-sync behavior.

`remote_session.attach` accepts a confirmed document identity with its canonical
Namespace, ID and File. One process incarnation and a decimal attachment counter
fence delayed replies and explicit reopens. The pure `remote_session_model`
validates complete acknowledgments and owns transitions. Only a matching
incarnation, attachment and generation retires a superseded view. A failed
publication leaves local editing and submission unchanged; reopen retries remote
availability. Supersession also needs an explicit reopen to take the view back.
Callbacks and notices use the pure owner's accepted outcome. A confirmation
whose canonical file or attachment tuple does not match is reported as uncertain
without owned binding evidence, even if it passed transport-level validation.
The same pure context validator checks every known attachment field before
runtime allocation, then the complete tuple including the allocated Socket.
Rejected construction reports unavailable, joins exact listener cleanup and
releases the shared queue so other attachments and teardown can proceed.

One native lifecycle subscription tracks per-buffer discovery witnesses.
Passive autoread/checktime and guarded session-sync rereads preserve the current
or superseded attachment; a passive BufReadPost never takes a superseded view
back. An unguarded unload, including explicit edit/edit!, retires the attachment.
Reopen can confirm membership and allocate a fresh AttachID. Saves, duplicate
open events and passive reads do not repeat discovery or publication.

The registered document mover pauses publication and listening before its
effects. Confirmed finalization resumes the same document ID at the new canonical
File with a fresh attachment. A pre-effect abort may resume the proven old
identity; an interrupted move stays unavailable remotely until forward recovery
confirms it. Neither spelling is advertised from an interrupted move.

The two fixed producer callbacks are `remote_session.endpoint(query)` (read-only
pending/current witness, nil for retired or renamed buffers) and
`remote_session.superseded(notice)` (advisory generation-fenced retirement).
Stopping a listener cannot revoke an established native RPC channel. The later
Couch adapter must fence every operation against the authoritative generation.

`document_registry.editor` shares the existing four-child/64-queued Couch
transport. Requests and replies have protocol byte bounds; the three-second
default child lifetime ends before cancellation/deadline callbacks. Exit requests
instead share an absolute deadline that includes queue time and is checked before
spawn and before accepting a late reply. A persisted CLI fake
qualifies retries, displacement, stale cleanup and uncertain replies. Real
producer conformance remains a separate requirement, with isolated namespaces
and actual editor listeners.

One runtime IO epoch counts consumers separately from records awaiting cleanup.
The last consumer cancels and joins startup and unstarted publication; an admitted
publication retains its observer for exact late-ack cleanup. After that epoch
drains, its runtime closes automatically. A new attachment waits for that exact
close before allocating fresh. Superseded or refused attachment history remains
available without retaining a listener; uncertain publication keeps its listener.
Cleanup failure retains ownership evidence and refuses remote availability;
an explicit reopen may retry cleanup, with no automatic loop.

Each consumer also owns its exact listener transaction handle, from marker
reservation through native listen and durable publication. Retirement cancels
and joins that transaction even when another buffer still needs the runtime.
Cleanup removes a proven reservation before its slot can be reused. Interrupted
marker writes retain an in-memory created-inode and intended-byte witness;
matching committed writes are recognized for cleanup only. Unpublished runtime
directories are removed only when their exact owned contents can be proved.
Foreign replacements remain untouched, and cleanup completes before the kernel
guard is released or a new runtime epoch is admitted.

`remote_runtime` serializes parent allocation and cleanup through the existing
`document_lease` kernel flock. One private parent holds at most 256 process
directories, including unknown residue. Startup reads bounded ownership markers
and one batch of PID/start-time evidence through `remote_process`; only positive
death permits cleanup of exact owned sockets and an empty directory. With 256
distinct marked PIDs, the own PID plus 255 others fill the inspection batch; any
uninspected marker stays unknown. Inspection gets one second and startup two
seconds from allocation through the first durable listener publication, without
resetting between those steps. Later listeners have their own operation budget.
Expiry leaves uncertain artifacts untouched and may refuse allocation.

A runtime marker records directory/socket identities before listener publication.
Cleanup revalidates the marker bytes and inode. Before `serverstop`, Parley checks
the exact socket identity because Neovim may unlink a replacement pathname. A
replacement is retained rather than passed to `serverstop`; Neovim's eventual
process-exit behavior is outside this ownership guarantee. There is no recursive
cleanup, polling watcher or automatic takeover loop.

The native `default_parent()` selects physical `/tmp/parley-rpc-UID`
(`/private/tmp` on macOS), keeping all 256 socket names within the Unix path
limit. A new parent is created exclusively as `0700`. An existing parent must be
a real directory owned by this UID with exact `0700` mode; a symlink, foreign
owner or wrong mode refuses remote availability without chmod/chown.
Tests inject a short disposable parent through the getter and guard acquisition
against the real native prefix. Clean embedded and zero-config processes use
the same fixture; default-selection controls restore the native getter only
with system-temp resolution redirected to their private tree.

VimLeavePre retires attachments and sends at most one generation-fenced
unregister batch per distinct Namespace under one shared absolute 500 ms client
wait. Neovim unloads buffers before that event; a numeric v:exiting (including
zero) reserves their bindings for this batch instead of starting individual
unregisters. Ordinary unload/reopen still retires immediately. The pure composer
groups known owned bindings and selects the greatest
canonical decimal AttachID for a repeated document, preserving that exact
BindingGeneration. Another namespace does not receive a fresh budget. Queued
intent is canceled at expiry; admitted CLI work keeps its existing owned/joined
observer. A missing or late acknowledgment remains uncertain, since killing the
CLI cannot prove that producer work was rolled back.

After that wait, Parley stops only exact owned native listeners without waiting
for the allocation guard or asynchronous marker cleanup. This kernel-only stop
does not rewrite markers or remove runtime directories. Remaining residue is
considered at a later startup and reclaimed only on positive native process
death with exact artifact ownership. Exit makes no promise that asynchronous
filesystem cleanup or native reap callbacks run after VimLeavePre returns;
ordinary detach and explicit close retain their joined cleanup lifetime.

Code: `lua/parley/remote_session*.lua`, `remote_runtime*.lua`,
`remote_process.lua`, and `document_registry.lua`. Pure, process, runtime and
transport specs live under `tests/unit/` and `tests/integration/`;
`remote_session_native_spec.lua` exercises the Markdown, read and move lifecycle.


Real endpoint conformance uses the supported Pair `couch-conformance-bridge` owner, not adopt-store or a Parley launcher. Run `python3 scripts/check-couch-registry-conformance.py --editor-endpoints --bridge /ABS/couch-conformance-bridge` with the desired native nvim first on the invocation PATH; `--couch /ABS/candidate/couch` optionally selects the Couch candidate. The bridge supplies the complete private environment and actual registered parent/side IDs. The consumer reads and verifies those registrations, qualifies two-editor takeover and per-file listeners in one editor, then closes its native clients before bridge EOF. `scripts/couch_bridge.py` continuously drains bounded pipe output and joins its owned probe/bridge under the fixed300/600/15s contract plus observation margin. Nonzero or unknown cleanup retains the exact parent paths and diagnostics; the driver never removes producer roots. Fake-only qualification and the deliberately corrupted identity control remain available without the bridge.
