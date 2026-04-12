# Spec: Syntax Highlighting

## Highlight Groups
Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`) linked to standard Neovim groups.

## Key Behaviors
- Applied via decoration providers with ephemeral extmarks per window viewport
- Multi-window safe: independent redraw cache per window
- `🌿:` lines auto-rendered with debounced topic lookup from referenced files
- `chat_conceal_model_params`: optional header param concealment
