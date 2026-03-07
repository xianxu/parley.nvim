# Spec: Google Drive Context

## Overview
Parley can fetch content from Google Docs via its `@@` syntax.

## Syntax
- `@@https://docs.google.com/document/d/<document_id>/edit`.
- `@@google-drive://<document_id>`.

## Authentication (OAuth 2.0)
- Requires a Google Cloud Project with the Google Docs API enabled.
- OAuth tokens are stored securely (e.g., in the macOS Keychain or specified `state_dir`).
- `:ParleyGdriveLogout`: Revokes and deletes stored tokens.

## Content Fetching
- Google Doc content is fetched as plain text.
- Included in the LLM context with a clear reference header.

## State Management
- Authentication status MUST be tracked.
- Automatic re-authentication if tokens are expired.
