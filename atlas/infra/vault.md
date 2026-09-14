# Credentials and secret storage

The app normally connects model accounts through `:ParleyProxy connect`.
[Proxy setup](../providers/cliproxy-managed.md) describes model-account management.
Plugin users can also supply provider API keys as strings, `os.getenv(...)`
results, or argv tables for an asynchronously executed credential command.
Unresolved or empty credentials fail the request with diagnostic advice.

These credential stores have different owners:

- Provider API keys live in the private Lua vault and are removed from public
  setup configuration. They are resolved for provider requests, not stored in
  a general configuration dump.
- CLIProxyAPI account JSON lives in the explicit shared `~/.cli-proxy-api`
  directory. App profile isolation and uninstall do not remove those logins.
- Document-provider OAuth accounts use the OS credential store: macOS `security`
  or Linux `secret-tool`, under the `parley-nvim-google-oauth` service name.
  `:ParleyGdriveLogout` deletes the local OAuth store; it does not revoke access
  at the provider's website.
- Copilot bearer tokens are cached with expiry in `state_dir/vault_state.json`
  and refreshed when needed.

Vault debug messages are marked sensitive and follow `log_sensitive` (off by
default). Separate [raw/exchange logs](raw_logging.md) capture conversation
content; do not infer that all diagnostic output is sanitized by the vault.

Implementation: `lua/parley/vault.lua`, `oauth.lua`, `cliproxy.lua` and setup in
`init.lua`. Coverage: `tests/unit/vault_spec.lua`, `tests/unit/oauth_spec.lua`,
and `tests/integration/starter_auth_spec.lua`.
