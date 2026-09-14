# Google Drive Context

Include a Google document in a question with a closed reference:

```text
Summarize @@https://docs.google.com/document/d/DOCUMENT_ID/edit@@
```

Supported Google URL forms include Docs, Sheets, Slides, and Drive file links.
References use HTTP(S) URLs; `google-drive://` is not a supported inclusion
scheme. The original reference remains in the chat while fetched text is added
to the model's context with a file header and line numbers.

## Fetching and authentication

Parley first tries public access. An authentication-required response for a
recognized provider enters the OAuth flow. Configure `oauth.google.client_id`
and `oauth.google.client_secret`; the legacy `google_drive` configuration is
still accepted. The default scope is `drive.readonly`. Authenticated Google
fetches use the Drive API: Docs export as Markdown, Sheets as CSV, Slides as
plain text, and ordinary Drive files use download content.

OAuth accounts are stored in the operating-system credential store: macOS
`security`, or Linux `secret-tool`. There is no `state_dir` token-file fallback.
Expired access tokens are refreshed when a refresh token is available;
unrecoverable authentication requires signing in again.

`:ParleyGdriveLogout` removes the local OAuth account store. It does not send a
server-side grant-revocation request.

Only references in the current question are fetched anew. Earlier question
references use cached content; a missing earlier cache entry becomes a
placeholder rather than a new remote request.

## Implementation and verification

- `lua/parley/oauth.lua` — public fetch, provider URL parsing/export, account storage, refresh, and logout.
- `lua/parley/google_drive.lua` — compatibility alias to `oauth`.
- `lua/parley/init.lua`, `chat_respond.lua` — remote-reference caching and message assembly.
- `tests/unit/oauth_spec.lua`, `tests/unit/remote_references_spec.lua`, `tests/unit/build_messages_spec.lua`.
