# Spec: Chat Parsing

## Overview
Parley parses chat buffers to identify conversation turns (questions and answers), metadata, and special segments.

## Buffer Segmentation
A chat buffer is divided into two primary sections:
1. **Header Section**: All lines before the first `---`.
2. **Transcript Section**: All lines after the first `---`.

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
1. Resolved path MUST start with `chat_dir`.
2. Filename MUST follow the `YYYY-MM-DD` timestamp pattern.
3. First line MUST start with `# topic:`.
4. Header MUST contain `- file: <filename>`.
