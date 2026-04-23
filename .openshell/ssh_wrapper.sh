#!/bin/bash
# SSH wrapper — delegates to system SSH which reads ~/.ssh/config.
# Kept for manual use; mutagen uses ssh-bin/ssh instead.
exec /usr/bin/ssh "$@"
