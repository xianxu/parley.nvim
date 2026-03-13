# Spec: Syntax Highlighting

## Overview
Parley provides custom syntax highlighting for chat buffers to distinguish between roles, references, and special content.

## Highlight Groups
| Group | Default Link | Description |
|---|---|---|
| `ParleyQuestion` | `Keyword` | User's question area |
| `ParleyFileReference`| `WarningMsg` | `@@` file and directory references |
| `ParleyThinking` | `Comment` | `🧠:` thinking and `📝:` summary lines |
| `ParleyAnnotation` | `DiffAdd` | `@...@` inline annotations |
| `ParleyPickerApproximateMatch` | `IncSearch` | Picker positions that were accepted through typo-tolerance edit operations |
| `InterviewTimestamp` | `DiffAdd` | `:NNmin` interview timestamps |

## Highlighting Logic
- Applied on `BufEnter`, `WinEnter`, `TextChanged`, and `TextChangedI`.
- MUST be efficient to avoid lag in large chat files.
- **Header Concealment**: Model parameters in the header MAY be concealed if `chat_conceal_model_params` is `true`.

## Interview Mode
- In interview mode, lines starting with `:NNmin` MUST be highlighted with `InterviewTimestamp`.
