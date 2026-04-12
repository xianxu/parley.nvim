# Spec: Key Bindings Help

## Command
`:ParleyKeyBindings` (`<C-g>?`): centered floating window showing context-scoped shortcuts.

## Context Scoping
Help content adapts to current buffer: chat, note, issue, markdown, finder, or other. Each context shows relevant shortcut sections. Auto-detected from buffer type; accepts optional explicit context parameter.

## Resolution
Shortcuts resolved from active runtime keymaps; fallback to configured defaults.
