-- A fake `couch` binary for specs (#313, #316). Queries answer from env:
-- `--actors` prints $FAKE_COUCH_ACTORS; `--session-sync` exits 2 unless
-- $FAKE_COUCH_STATUS is set (the verb before pair#437). Every send appends
-- one line `<to>|<first line of the message>` to `log_file`, writes its argv one per line to
-- `argv_file` (whole, then renamed: specs poll for it) and the message alone
-- to `log_file .. ".last"`. $FAKE_COUCH_SLEEP delays a send;
-- $FAKE_COUCH_EXIT fails it. $FAKE_COUCH_LOG_DELAY exposes an empty log before
-- appending the notification, to test complete-payload readiness across processes.
local M = {}

--- Write the fake into `root/bin/couch`; the caller puts `root/bin` on PATH.
function M.write(root, log_file, argv_file)
    local bin = root .. "/bin/couch"
    vim.fn.mkdir(root .. "/bin", "p")
    vim.fn.writefile({
        "#!/bin/sh",
        'if [ "$1" = "--session-sync" ] && [ -n "$FAKE_COUCH_REGISTRY" ]; then',
        '  exec python3 "' .. vim.fn.fnamemodify("tests/fixtures/fake_couch_registry.py", ":p") .. '" "$@"',
        'fi',
        'case "$1" in',
        '--actors) printf "%s" "$FAKE_COUCH_ACTORS"; exit 0;;',
        '--session-sync) [ -n "$FAKE_COUCH_STATUS" ] || exit 2; printf "%s" "$FAKE_COUCH_STATUS"; exit 0;;',
        'esac',
        'if [ -n "$FAKE_COUCH_SLEEP" ]; then sleep "$FAKE_COUCH_SLEEP"; fi',
        'if [ -n "$FAKE_COUCH_LOG_DELAY" ]; then : >> "' .. log_file .. '"; sleep "$FAKE_COUCH_LOG_DELAY"; fi',
        'printf "%s" "$4" > "' .. log_file .. '.last"',
        'printf "%s|%s\\n" "$2" "$(printf "%s\\n" "$4" | head -n 1)" >> "' .. log_file .. '"',
        'for a in "$@"; do printf "%s\\n" "$a"; done > "' .. argv_file .. '.tmp"',
        'mv "' .. argv_file .. '.tmp" "' .. argv_file .. '"',
        'if [ -n "$FAKE_COUCH_EXIT" ] && [ "$FAKE_COUCH_EXIT" != 0 ]; then echo "no such peer" >&2; exit "$FAKE_COUCH_EXIT"; fi',
    }, bin)
    assert((vim.uv or vim.loop).fs_chmod(bin, 493))
end

return M
