# Spec: Chat Parsing

## Overview
Parley parses chat buffers to identify conversation turns (questions and answers), metadata, and special segments.

## Buffer Segmentation
A chat buffer is divided into two primary sections:
1. **Header Section**:
   - Front matter format: lines between opening `---` and closing `---`.
   - Legacy format: lines before the first `---`.
2. **Transcript Section**: All lines after the header closing separator.

## Identifying Conversation Turns
- **Question (User)**: Begins with `chat_user_prefix` (default `💬:`). Ends at the next assistant prefix or end of file.
- **Answer (Assistant)**: Begins with `chat_assistant_prefix` (default `🤖:`). Ends at the next user prefix or end of file.

## Special Segment Parsing
### Reasoning and Summaries
- `🧠:` (Thinking): A single line within an assistant's answer for internal model reasoning.
- `📝:` (Summary): A single line within an assistant's answer used for memory management.

### Local Sections
- `🔒:`: Segments that are excluded from LLM context but remain in the transcript.

## Contextual Validation
The plugin performs a series of checks to validate a chat buffer:
1. Resolved path MUST be inside one configured chat root (`chat_dir` or an entry from `chat_dirs`).
2. Filename MUST follow the `YYYY-MM-DD` timestamp pattern.
3. Header MUST contain `topic`.
4. Header MUST contain `file`.
