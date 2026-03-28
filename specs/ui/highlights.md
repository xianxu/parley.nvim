# Spec: Syntax Highlighting

## Highlight Groups
| Group | Link | Usage |
|---|---|---|
| `ParleyQuestion` | `Keyword` | User question area |
| `ParleyFileReference` | `WarningMsg` | `@@` file/dir refs |
| `ParleyChatReference` | `Special` | `🌿:` branch/parent links |
| `ParleyThinking` | `Comment` | `🧠:` thinking, `📝:` summary |
| `ParleyAnnotation` | `DiffAdd` | `@...@` inline annotations |
| `ParleyPickerApproximateMatch` | `IncSearch` | Picker typo-tolerance positions |
| `InterviewTimestamp` | `DiffAdd` | `:NNmin` timestamps |

## Key Behaviors
- Applied on `BufEnter`, `WinEnter`, `TextChanged`, `TextChangedI`
- Uses decoration providers with ephemeral extmarks per window viewport
- Multi-window: independent redraw cache per window (no cross-window clearing)
- Mid-buffer question recovery: scrolling away from `💬:` header must still highlight continuation lines
- `chat_conceal_model_params`: optional header param concealment

## Branch Reference Rendering
- `🌿:` lines auto-rendered with 500ms debounced timer
- Updates topic text from referenced file; shows `⚠️` if file missing

## Interview Mode
- `:NNmin` lines highlighted with `InterviewTimestamp`
