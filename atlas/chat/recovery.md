# Recover a replaced answer

Before regenerating an existing answer, Parley saves its exact previous text in a
private recovery folder under your profile’s state directory. If that snapshot
cannot be confirmed, replacement does not start. Retrying preserves the original
snapshot rather than replacing it with a partial answer.

Use `:ParleyAnswerRecovery` to inspect, export, restore, or discard a snapshot.
`:ParleyAnswerRestore` opens the restore picker directly. Inspection opens a
scratch buffer; export lets you save that original text elsewhere.

An unchanged, uniquely matched answer can be restored directly. If you edited the
replacement, select its answer first: Parley previews the current text and asks
before replacing it. Edits made while a picker is open invalidate its captured
target. Duplicate or ambiguous questions never resolve by their position alone.
Reload invalidates old write authority; retained snapshots remain available.

A successful replacement’s snapshot is removed only after a confirmed save and
matching saved-file contents. Failed cleanup stays visible and counts against the
storage limit. Confirmed chat deletion and explicit discard also remove snapshots;
closing a buffer does not. Failed or uncertain output keeps its recovery copy.

The limit is 16 MiB per serialized record and 256 MiB per profile, including failed
cleanup artifacts. A snapshot contains both text and association evidence, so
its serialized size can exceed the original answer’s size. Capacity failure
refuses a new replacement. No age-based cleanup deletes the only recovery copy.

## Implementation

[answer_recovery.lua](../../lua/parley/answer_recovery.lua) owns checked immutable
publication and recovery-file discovery. [response_recovery.lua](../../lua/parley/response_recovery.lua)
binds publication and restore to Document guards. Completion retains a regional
proof while structural repair confirms settlement, allowing unrelated draft edits.
Failed attempts keep at most 48 small retry associations per live document,
validated by context revision; reload and detach clear them. While structure is
still opaque, intervening edits conservatively prevent automatic retry. [chat_recovery.lua](../../lua/parley/chat_recovery.lua)
owns saved-file matching, profile integration, and captured UI actions. Renamed
chats use timestamp/root and exact question/predecessor/replacement evidence;
malformed records are unavailable rather than guessed. A corrupt record with
unknown association blocks new snapshots until storage is inspected; it cannot
turn a partial answer into a new original. Tool effects are not undone
by restoring transcript text.
