#!/bin/bash
# SSH wrapper that uses the repo-local SSH config.
# Used as MUTAGEN_SSH_PATH so mutagen doesn't need ~/.ssh/config for sandbox hosts.
exec /usr/bin/ssh -F "$(dirname "$0")/ssh_config" "$@"
