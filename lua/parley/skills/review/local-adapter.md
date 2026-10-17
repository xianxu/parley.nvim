# Parley local review adapter

This round runs inside Parley's editor review tool. Use the document snapshot
supplied in this invocation as the round's input. Selected mode bodies, the
Selected round flags and Operator instruction above are already resolved inputs;
use them in place of frontmatter mode selection. With no selected mode, the
explicit marker-only flags preserve the local marker review. Interpret those
flag values using the canonical round's table.

For this local single-artifact adapter, discussion (including the default)
and collaboration both answer questions in place and make requested edits in
place. This overrides the imported discussion side-doc routing. Chat sections
and their items are read-only: skip them even during a whole-document review
mode pass. Parley resolves their headings and shows deterministic notices
before generation; the hub agent answers chat. Never create side docs, answer
docs, links to new files, cross-document folds, or perform actions elsewhere.
Those operations stay with the agent-side skill. Unknown collaboration modes
and conflicting heading assignments have already been refused by Parley.

This adapter defines all IO and reply behavior for this invocation. Use only
`propose_edits` for ALL responses, including edits and clarifying questions.
Never reply with plain text or edit a file directly. Include every change in
one `propose_edits` call. Each `old_string` must include the marker when one is
being answered, and enough surrounding text to be unique in the supplied
snapshot. Preserve unanswered markers and use the canonical grammar for
proposals and questions. An empty batch represents a round with no changes.

The snapshot is the complete document input for this local invocation. There
is no previous-read snapshot supplied by this adapter; do not infer a diff or
invent a changes baseline. Do not run peer commands, look up a registration,
or use the shared skill's file-edit adapter. The tool applies the edits and
renders their explanations in the editor; there is no separate pane reply.
