-- A fake `couch` binary for specs (#313, #316). Queries answer from env:
-- `--actors` prints $FAKE_COUCH_ACTORS; `--session-sync` exits 2 unless
-- $FAKE_COUCH_STATUS is set (the verb before pair#437). Every send appends
-- one line `<to>|<first line of the message>` to `log_file`, writes its argv one per line to
-- `argv_file` (whole, then renamed: specs poll for it) and the message alone
-- to `log_file .. ".last"`. $FAKE_COUCH_SLEEP delays a send and
-- $FAKE_COUCH_QUERY_SLEEP an `--actors` or `--session-sync` answer (#400);
-- $FAKE_COUCH_EXIT fails a send. $FAKE_COUCH_LOG_DELAY exposes an empty log before
-- appending the notification, to test complete-payload readiness across processes.
-- An accepted send prints couch's receipt, `msg-<n> parley.nvim:9 -> <to> queued`,
-- counting n in `log_file .. ".id"`. With $FAKE_COUCH_OWED and
-- $FAKE_COUCH_REGISTRY, a `submitted: PATH` send also adds its ID to PATH's
-- owed events in the registry, and `M.fold` removes one, as an agent's
-- `write --fold` does (#354). `M.round` seeds a file's round sidecar, which
-- `round PATH --json` answers, cleared by a later submit (#383).
local M = {}

--- Write the fake into `root/bin/couch`; the caller puts `root/bin` on PATH.
function M.write(root, log_file, argv_file)
    local bin = root .. "/bin/couch"
    vim.fn.mkdir(root .. "/bin", "p")
    local registry = vim.fn.fnamemodify("tests/fixtures/fake_couch_registry.py", ":p")
    vim.fn.writefile({
        "#!/bin/sh",
        'if [ "$1" = "--session-sync" ] && [ -n "$FAKE_COUCH_REGISTRY" ]; then',
        '  exec python3 "' .. registry .. '" "$@"',
        'fi',
        -- A nap a SIGTERM ends with the script, which then dies by that signal
        -- as couch would. An orphaned `sleep` would hold the stdio pipes, and
        -- vim.system reports an exit only once they close.
        'nap() { trap \'kill "$n" 2>/dev/null; trap - TERM; kill -TERM $$\' TERM; sleep "$1" & n=$!; wait "$n"; trap - TERM; }',
        'case "$1" in --actors|--session-sync) [ -n "$FAKE_COUCH_QUERY_SLEEP" ] && nap "$FAKE_COUCH_QUERY_SLEEP";; esac',
        'case "$1" in',
        '--actors) printf "%s" "$FAKE_COUCH_ACTORS"; exit 0;;',
        '--session-sync) [ -n "$FAKE_COUCH_STATUS" ] || exit 2; printf "%s" "$FAKE_COUCH_STATUS"; exit 0;;',
        'esac',
        'if [ -n "$FAKE_COUCH_SLEEP" ]; then nap "$FAKE_COUCH_SLEEP"; fi',
        'if [ -n "$FAKE_COUCH_LOG_DELAY" ]; then : >> "' .. log_file .. '"; sleep "$FAKE_COUCH_LOG_DELAY"; fi',
        'printf "%s" "$4" > "' .. log_file .. '.last"',
        'printf "%s|%s\\n" "$2" "$(printf "%s\\n" "$4" | head -n 1)" >> "' .. log_file .. '"',
        'for a in "$@"; do printf "%s\\n" "$a"; done > "' .. argv_file .. '.tmp"',
        'mv "' .. argv_file .. '.tmp" "' .. argv_file .. '"',
        'if [ -n "$FAKE_COUCH_EXIT" ] && [ "$FAKE_COUCH_EXIT" != 0 ]; then echo "no such peer" >&2; exit "$FAKE_COUCH_EXIT"; fi',
        -- The receipt couch prints for an accepted send (#354): `<ID> <from> -> <to> <status>`.
        'n=$(cat "' .. log_file .. '.id" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "' .. log_file .. '.id"',
        'if [ -n "$FAKE_COUCH_OWED" ] && [ -n "$FAKE_COUCH_REGISTRY" ]; then',
        '  python3 "' .. registry .. '" --owe "msg-$n" "$4" || exit 1',
        'fi',
        'printf "msg-%s parley.nvim:9 -> %s queued\\nposition 1\\n" "$n" "$2"',
    }, bin)
    assert((vim.uv or vim.loop).fs_chmod(bin, 493))
end

-- Edit the registry's ledger as the test side of the protocol: `--owe` records
-- a `submitted: PATH` send as owed, `--fold` removes it.
local function ledger(registry, verb, id, subject)
    local result = vim.system({ "python3", vim.fn.fnamemodify("tests/fixtures/fake_couch_registry.py", ":p"),
        verb, id, subject }, { text = true, env = { FAKE_COUCH_REGISTRY = registry } }):wait()
    assert(result.code == 0, "fake couch " .. verb .. " failed: " .. tostring(result.stderr))
end

--- Record message `id` as owed for `path` in the registry at `registry`.
function M.owe(registry, path, id)
    ledger(registry, "--owe", id, "submitted: " .. path)
end

--- Fold message `id` for `path` in the registry at `registry`: remove it from
--- the file's owed events.
function M.fold(registry, path, id)
    ledger(registry, "--fold", id, path)
end

--- Seed `path`'s round sidecar (#383): `round` is the table Couch's
--- `round --json` answers as `Round`.
function M.round(registry, path, round)
    ledger(registry, "--round", path, vim.json.encode(round))
end

--- Set the time of `path`'s last recorded submit to the RFC3339 stamp `at`,
--- which may carry a local offset, as the real ledger's does.
function M.submit_at(registry, path, at)
    ledger(registry, "--submit-at", path, at)
end

--- Why a document_registry request did not register (#382): its refusal code
--- and error, the child's exit status and stderr, and how long it queued and
--- ran. "unavailable" alone cannot tell a deadline from a malformed reply, a
--- failed spawn or a path mismatch.
--- @param result table a document_registry result
--- @return string
function M.explain(result)
    return vim.inspect({ kind = result.kind, code = result.code, error = result.error, exit = result.exit,
        stderr = result.stderr, queued_ms = result.queued_ms, ran_ms = result.ran_ms })
end

return M
