# Google Drive Support via OAuth -- Design Document

## Problem

Parley.nvim supports including local files in chat via `@@/path/to/file` syntax. Users want to reference Google Docs and other Google Drive files the same way, enabling LLM critique and discussion of cloud-hosted documents.

## Solution

Extend the `@@` syntax to accept Google Drive URLs. When a user writes `@@https://docs.google.com/document/d/.../edit`, the plugin authenticates with Google via OAuth, fetches the document content, and injects it into the LLM prompt just like a local file.

## Architecture

### New Module: `lua/parley/google_drive.lua`

Single new module handling all Google-related functionality:

- **OAuth flow** -- localhost redirect with `vim.loop` TCP server
- **Token persistence** -- OS keychain (macOS `security`, Linux `secret-tool`)
- **Token refresh** -- automatic, using stored refresh_token
- **File fetching** -- Google Drive API v3 export/download
- **URL parsing** -- extract file ID and type from Google URLs

### Integration Points (minimal changes to existing code)

1. **`chat_parser.lua`** -- No changes. Already captures `@@<anything>` as a file reference path.
2. **`helper.lua`** -- Add URL detection: if path starts with `https://`, delegate to `google_drive.lua`.
3. **`init.lua` (_build_messages)** -- Handle async fetching for remote URLs (OAuth may require user interaction on first use).
4. **`config.lua`** -- Add `google_drive` config section with shipped client credentials.

## OAuth Flow

### First-time authentication

1. User submits a question with `@@https://docs.google.com/document/d/abc123/edit`
2. Plugin detects no cached token
3. Starts `vim.loop.new_tcp()` server on a random available port
4. Opens browser to Google OAuth consent page:
   - `redirect_uri = http://localhost:{port}/callback`
   - `scope = https://www.googleapis.com/auth/drive.readonly`
   - `access_type = offline` (to get refresh_token)
5. User consents; Google redirects to localhost with auth code
6. TCP server receives code, sends success HTML page, shuts down
7. Plugin exchanges auth code for access_token + refresh_token via curl
8. Tokens stored in OS keychain
9. Original request proceeds with fetched content

### Subsequent requests

1. Load tokens from OS keychain
2. If access_token expired, use refresh_token to get a new one
3. Fetch file content directly

### Token storage

- Service: `parley-nvim-google-oauth`
- Account: `default`
- Value: JSON `{access_token, refresh_token, expires_at}`
- macOS: `security add-generic-password` / `security find-generic-password`
- Linux: `secret-tool store` / `secret-tool lookup`

## File Fetching

### URL parsing

Extract file ID and determine type from Google URLs:

- `https://docs.google.com/document/d/{FILE_ID}/edit` -- Google Doc
- `https://docs.google.com/spreadsheets/d/{FILE_ID}/edit` -- Google Sheet
- `https://docs.google.com/presentation/d/{FILE_ID}/edit` -- Google Slides
- `https://drive.google.com/file/d/{FILE_ID}/view` -- Drive file (any type)

### Export formats

| Google File Type | Export Format | MIME Type |
|---|---|---|
| Google Docs | Markdown | `text/markdown` (fallback `text/plain`) |
| Google Sheets | CSV | `text/csv` |
| Google Slides | Plain text | `text/plain` |
| Other files in Drive | Download as-is | `files.get` with `alt=media` |

### API endpoints

- File metadata: `GET /drive/v3/files/{ID}?fields=mimeType,name`
- Export (native formats): `GET /drive/v3/files/{ID}/export?mimeType={MIME}`
- Download (regular files): `GET /drive/v3/files/{ID}?alt=media`

### Content formatting

Match existing `helper.format_file_content()` output:

```
File: Google Doc - "Document Title"
1| First line of content
2| Second line of content
```

## Configuration

```lua
google_drive = {
    client_id = "SHIPPED_CLIENT_ID.apps.googleusercontent.com",
    client_secret = "SHIPPED_CLIENT_SECRET",
    scopes = { "https://www.googleapis.com/auth/drive.readonly" },
},
```

Users can override with their own Google Cloud credentials in their setup call.

## Error Handling

- File not found / no permission: clear error message in chat buffer
- OAuth token expired + refresh fails: re-trigger full OAuth flow
- Network errors: error message, don't block the rest of the question
- Unsupported URL format: error message with supported formats

## Testing

- Unit tests for URL parsing (file ID extraction, type detection, export format selection)
- Unit tests for OAuth URL construction (scopes, redirect URI)
- Unit tests for token storage/retrieval helpers (mocked keychain commands)
- Unit tests for HTTP response parsing (token exchange, file metadata)
- Integration tests for `_build_messages` with remote `@@` references alongside local ones
- Manual testing for actual OAuth flow (requires browser interaction)

## Scope

- Read-only access to Google Drive (drive.readonly scope)
- No document modification or creation
- macOS and Linux keychain support (no Windows initially)
