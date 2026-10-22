# Private editor endpoints

The remote-session foundation gives each registered live buffer a private Unix
RPC listener. Couch owns the current binding; Parley owns the listener and its
attachment lifetime. Automatic session/Markdown-open wiring follows in #405 M2;
this foundation alone does not enable a remote interface or change submission.

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

The two fixed producer callbacks are `remote_session.endpoint(query)` (read-only
pending/current witness, nil for retired or renamed buffers) and
`remote_session.superseded(notice)` (advisory generation-fenced retirement).
Stopping a listener cannot revoke an established native RPC channel. The later
Couch adapter must fence every operation against the authoritative generation.

`document_registry.editor` shares the existing four-child/64-queued Couch
transport. Requests and replies have protocol byte bounds; the three-second
child lifetime ends before cancellation/deadline callbacks. A persisted CLI fake
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

Code: `lua/parley/remote_session*.lua`, `remote_runtime*.lua`,
`remote_process.lua`, and `document_registry.lua`. Pure, process, runtime and
transport specs live under `tests/unit/` and `tests/integration/`.
