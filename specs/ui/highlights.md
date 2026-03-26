# Spec: Syntax Highlighting

## Overview
Parley provides custom syntax highlighting for chat buffers to distinguish between roles, references, and special content.

## Highlight Groups
| Group | Default Link | Description |
|---|---|---|
| `ParleyQuestion` | `Keyword` | User's question area |
| `ParleyFileReference`| `WarningMsg` | `@@` file and directory references |
| `ParleyChatReference`| `Special` | `🌿:` chat branch/parent link lines |
| `ParleyThinking` | `Comment` | `🧠:` thinking and `📝:` summary lines |
| `ParleyAnnotation` | `DiffAdd` | `@...@` inline annotations |
| `ParleyPickerApproximateMatch` | `IncSearch` | Picker positions that were accepted through typo-tolerance edit operations |
| `InterviewTimestamp` | `DiffAdd` | `:NNmin` interview timestamps |

## Highlighting Logic
- Applied on `BufEnter`, `WinEnter`, `TextChanged`, and `TextChangedI`.
- MUST be efficient to avoid lag in large chat files.
- Redraw-time markdown/chat highlighting uses Neovim decoration providers with ephemeral extmarks scoped to each window viewport.
- When the same buffer is visible in multiple windows or splits, each window MUST keep independent redraw cache state so one viewport redraw does not clear or overwrite another window's highlights.
- Chat redraws that begin in the middle of a multi-line unanswered question MUST still recover question-block state, so scrolling away from the `💬:` header and back does not leave continuation lines in plain markdown colors.
- **Header Concealment**: Model parameters in the header MAY be concealed if `chat_conceal_model_params` is `true`.

## Branch Reference Rendering
- `🌿:` lines are auto-rendered with a 500ms debounced timer (same pattern as `@@` refs in markdown).
- The timer reads the referenced file's topic and updates the `🌿:` line's topic text.
- If the referenced file does not exist, `⚠️` is appended to the line as a visual warning.

## Interview Mode
- In interview mode, lines starting with `:NNmin` MUST be highlighted with `InterviewTimestamp`.
