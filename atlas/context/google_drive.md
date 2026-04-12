# Google Drive Context

## Syntax
- `@@https://docs.google.com/document/d/<document_id>/edit`
- `@@google-drive://<document_id>`

## Auth
- OAuth 2.0, requires Google Cloud Project with Docs API enabled
- Tokens stored in macOS Keychain or `state_dir`
- `:ParleyGdriveLogout` revokes and deletes tokens
- Auto re-authenticates on token expiry

## Behavior
- Fetches Google Doc as plain text, included with reference header
