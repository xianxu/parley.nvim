submitted: note.md
outcome: ok

Fill missing mode keys while preserving the existing chat choice and canonical instruction byte-for-byte.
The canonical instruction wins over legacy free text independently: the missing processing-mode still comes
from the legacy copy-edit prefix, and presentation-mode comes from presentation. Warn on deprecated aliases;
retain both alias lines unchanged.
