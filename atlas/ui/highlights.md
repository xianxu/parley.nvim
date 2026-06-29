# Spec: Syntax Highlighting

## Highlight Groups
Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md).

## Key Behaviors
- Applied via decoration providers with ephemeral extmarks per window viewport
- Multi-window safe: independent redraw cache per window
- `🌿:` lines auto-rendered with debounced topic lookup from referenced files
- `chat_conceal_model_params`: optional header param concealment
- UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
  diagnostics in Parley chat and markdown buffers. The pure parser/formatter
  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
  refreshes its separate diagnostic namespace on buffer enter/window enter and
  text changes. Its namespace explicitly enables virtual text and uses the
  concise message `local time: <converted local time>`. The buffer text is never
  rewritten.
