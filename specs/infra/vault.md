# Spec: Vault (Secret Management)

## Overview
Parley's vault module securely manages API keys and OAuth tokens.

## Secret Storage
Secrets are stored internally and NOT exposed in the plugin's public configuration table.

### Key Retrieval Methods
- **Hardcoded String**: Used directly.
- **Environment Variable**: `os.getenv("VARIABLE")`.
- **Command (Table)**: Asynchronous execution of a shell command (e.g., `security`, `cat`, `bw`).

## OAuth Management
- Tokens for Google Drive are stored in a platform-specific secure location.
- Revocation and deletion through `:ParleyGdriveLogout`.

## Sensitive Data Handling
- Secrets MUST NOT be written to log files unless `log_sensitive` is `true`.
- Secrets MUST be passed securely to the `curl` subprocess.

## Copilot Token Cache
- GitHub Copilot tokens are cached with their expiry time.
- Automatic renewal before expiration.
