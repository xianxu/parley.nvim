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

Credential commands and OAuth keychain and token calls belong to no generation.
They stay in Neovim's session, so a command that prompts still works: pinentry,
a keychain dialog, or biometric unlock. Each has a deadline: 600 s for a
command that may prompt, and 120 s for a token request. Past it, the command is
killed and the request fails ([Stopping a
process](../providers/tool_execution.md#stopping-a-process)). An unfinished
keychain read is neither cached nor saved over the keychain.

Vault debug messages are marked sensitive and follow `log_sensitive` (off by
default). Separate [raw/exchange logs](raw_logging.md) capture conversation
content; do not infer that all diagnostic output is sanitized by the vault.

Implementation: `lua/parley/vault.lua`, `oauth.lua`, `cliproxy.lua` and setup in
`init.lua`. Coverage: `tests/unit/vault_spec.lua`, `tests/unit/oauth_spec.lua`,
and `tests/integration/starter_auth_spec.lua`.
