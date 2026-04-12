# Vault (Secret Management)

- Secrets stored internally, never exposed in public config table
- Retrieval methods: hardcoded string, env var (`os.getenv`), async shell command (table form)
- Secrets must not appear in logs unless `log_sensitive = true`
- Secrets passed securely to `curl` subprocess
- OAuth tokens (Google Drive) stored in platform-specific secure location; revoke via `:ParleyGdriveLogout`
- GitHub Copilot tokens cached with expiry, auto-renewed
