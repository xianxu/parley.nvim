-- The one list of profile sidecars — files under the state directory or
-- stdpath('data') that a chat action reads back (#261, target
-- transcript-is-the-whole-truth). Each entry names the module that reads it,
-- the file (`path` when it is not under state_dir), bodies whose fields hold the wrong type (every field its reader
-- takes, and the nested levels the reader indexes), how to make that reader
-- read it, and what its writes do with fields the read drops:
--
--   writes = "rewrite"   the file is app-owned state or a cache: a dropped
--                        field is re-derived or refetched, so rewriting the
--                        typed value is the recovery (`why` says which).
--   writes = "preserve"  the user wrote the file: the read filters a VIEW and
--                        the writes keep every entry. `preserve` proves it and
--                        sidecar_degrade_spec runs it (#261 M1 review BR-5).
--
-- tests/arch/sidecar_authority_spec.lua checks the readers against the tree and
-- that every entry declares `writes`; tests/integration/sidecar_degrade_spec.lua
-- writes every body, runs the reader, and submits a chat.
local FakeProcess = require("tests.helpers.fake_process")

local uv = vim.uv or vim.loop
local CACHE_SCOPE = "sidecar-cache-fixture"
local JOURNAL_NAMESPACE, JOURNAL_ID = "sidecar-journal-fixture", "sidecar-journal-id"
local LEASE_NAMESPACE, LEASE_ID = "sidecar-lease-fixture", "sidecar-lease-id"
local function digest(value) return vim.fn.sha256(value) end
local function bytes(path)
    local file = assert(io.open(path, "rb"))
    local value = file:read("*a"); assert(file:close())
    return value
end
local function cache_namespace(parley)
    return table.concat({ "", parley.config.state_dir .. "/sidecar-cache-store", CACHE_SCOPE }, "\n")
end
local function cache_path(parley)
    return parley.config.state_dir .. "/document-cache/" .. digest(cache_namespace(parley)) .. "/known.json"
end
local journal_file = "document-moves/" .. digest(JOURNAL_NAMESPACE) .. "/" .. digest(JOURNAL_ID) .. ".json"
local lease_file = "document-leases/" .. digest(LEASE_NAMESPACE) .. "/" .. digest(LEASE_ID) .. ".lock"

local function exercise_cache(parley)
    local registry = require("parley.document_registry")
    local documents = require("parley.agentic_document")
    local request, saved_env = registry.request, {}
    for _, name in ipairs({ "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "COUCH_STORE_DIR", "COUCH_ISOLATED_ROOT" }) do
        saved_env[name] = vim.env[name]
    end
    local path = parley.config.state_dir .. "/sidecar-cache-input.md"
    local buf, calls, reply = nil, 0, { kind = "unavailable", error = "fixture offline" }
    registry.request = function(operation, _, _, callback)
        assert(operation == "lookup", "cache corruption attempted a registry mutation")
        calls = calls + 1
        callback(vim.deepcopy(reply))
        return { cancel = function() end }
    end
    vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = CACHE_SCOPE, "sidecar-cache-slot"
    vim.env.COUCH_STORE_DIR, vim.env.COUCH_ISOLATED_ROOT = parley.config.state_dir .. "/sidecar-cache-store", nil
    local ok, err = pcall(function()
        vim.fn.writefile({ "plain document" }, path)
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, path)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain document" })
        assert(documents.attach(buf), "cache reader did not attach")
        assert(documents.status(buf).phase == "unknown", "corrupt cache fabricated admission")
        assert(documents.identity(buf) == nil, "corrupt cache fabricated a registration")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "editable while offline" })
        assert(uv.fs_lstat(path .. ".lock") == nil, "unknown cache created an edit-turn lock")
        reply = { kind = "absent" }
        documents.recheck(buf)
        assert(calls == 2 and documents.status(buf).phase == "plain", "confirmed absence did not settle admission")
        local rewritten = vim.json.decode(bytes(cache_path(parley)))
        assert(rewritten.version == 1 and type(rewritten.entries) == "table" and next(rewritten.entries) == nil,
            "confirmed absence did not rewrite the corrupt cache as typed empty knowledge")
    end)
    if buf then
        documents.detach(buf)
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end
    registry.request = request
    for _, name in ipairs({ "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "COUCH_STORE_DIR", "COUCH_ISOLATED_ROOT" }) do
        vim.env[name] = saved_env[name]
    end
    vim.fn.delete(path)
    assert(ok, err)
end

local function exercise_journal(parley, path)
    path = path or parley.config.state_dir .. "/" .. journal_file
    local before = bytes(path)
    local moves = require("parley.document_move")
    local summaries, scan_err = moves.pending(JOURNAL_NAMESPACE, { root = parley.config.state_dir })
    assert(summaries == nil and scan_err.kind == "pending", "corrupt intent was admitted as recoverable")
    local called = false
    local operation, recover_err = moves.recover(JOURNAL_NAMESPACE, JOURNAL_ID, { root = parley.config.state_dir },
        function() called = true end)
    if operation then operation.release() end
    assert(operation == nil and recover_err.kind == "pending" and not called, "corrupt intent authorized recovery effects")
    assert(bytes(path) == before, "corrupt journal was discarded or rewritten")
    local lease = assert(require("parley.document_lease").acquire(JOURNAL_NAMESPACE, JOURNAL_ID, { root = parley.config.state_dir }))
    assert(lease.release(), "failed recovery leaked its kernel lease")
end

local function exercise_lease(parley, path)
    path = path or parley.config.state_dir .. "/" .. lease_file
    local before, inode = bytes(path), assert(uv.fs_lstat(path)).ino
    local leases = require("parley.document_lease")
    local held = assert(leases.acquire(LEASE_NAMESPACE, LEASE_ID, { root = parley.config.state_dir }))
    local denied, err = leases.acquire(LEASE_NAMESPACE, LEASE_ID, { root = parley.config.state_dir })
    assert(denied == nil and err.kind == "busy", "opaque lease contents bypassed kernel ownership")
    assert(held.release()); assert(held.release())
    local again = assert(leases.acquire(LEASE_NAMESPACE, LEASE_ID, { root = parley.config.state_dir }))
    local unchanged = uv.fs_fstat(again.fd).ino == inode and bytes(path) == before
    assert(again.release())
    assert(unchanged and assert(uv.fs_lstat(path)).ino == inode, "lease lifecycle replaced the inode or interpreted corrupt bytes")
end

return {
    {
        reader = "lua/parley/agentic_document.lua",
        file = "known.json",
        path = cache_path,
        writes = "rewrite", why = "bounded app-owned knowledge; confirmed registry absence rewrites corrupt cache as typed empty knowledge",
        wrong_shapes = {
            { version = "1", entries = {} },
            { version = 1, entries = 3 },
            { version = 1, entries = { 3, { registration = 3, at = "x" },
                { registration = { ID = 3, File = 3, Owner = 3, RegisteredOwner = 3, RegisteredAt = 3 }, at = 3 } } },
            { version = 1, entries = { { registration = { ID = "fixture", File = "/fixture.md", Owner = "ops:0",
                RegisteredOwner = "ops:0", RegisteredAt = "now" }, at = "x" } } },
        },
        exercise = exercise_cache,
    },
    {
        reader = "lua/parley/document_move.lua",
        file = journal_file,
        -- An uncertain app-owned intent must remain available for manual
        -- recovery. Corruption disables migration, never ordinary submission.
        writes = "preserve",
        wrong_shapes = {
            { version = "1", namespace = 3, id = 3 },
            { version = 1, namespace = JOURNAL_NAMESPACE, id = JOURNAL_ID, registration = 3, entries = 3 },
            { version = 1, steps = { rewritten = 3, document_moved = "x" }, temps = { 3 }, protection = 3 },
        },
        exercise = exercise_journal,
        preserve = exercise_journal,
    },
    {
        reader = "lua/parley/document_lease.lua",
        file = lease_file,
        writes = "preserve",
        -- Kernel ownership uses only the inode/descriptor. There are no JSON
        -- fields to mistype; even invalid JSON stays opaque and untouched.
        wrong_shapes = {},
        exercise = exercise_lease,
        preserve = exercise_lease,
    },
    {
        reader = "lua/parley/theme.lua",
        file = "theme.json",
        writes = "rewrite", why = "app-owned theme preference; invalid ids fall back to startup",
        wrong_shapes = {
            { id = 3 },
            { id = "unknown" },
        },
        exercise = function(parley)
            local id = require("parley.theme").load(parley.config.state_dir)
            assert(id == nil or type(id) == "string")
        end,
    },
    {
        reader = "lua/parley/theme_picker.lua",
        file = "theme.json",
        writes = "rewrite", why = "picker reads the same validated app-owned preference",
        wrong_shapes = {
            { id = 3 },
            { id = "unknown" },
        },
        exercise = function(parley)
            local id = require("parley.theme").load(parley.config.state_dir)
            assert(id == nil or type(id) == "string")
        end,
    },
    {
        reader = "lua/parley/init.lua",
        file = "state.json",
        writes = "rewrite", why = "app-owned settings; refresh_state persists the typed state",
        wrong_shapes = {
            { updated = "x", agent = 3, system_prompt = 3, web_search = "x", claude_web_search = "x",
              follow_cursor = "x", last_chat = 3, live_agent = 3, note_dirs = 3, note_roots = 3,
              chat_dirs = 3, chat_roots = 3, repo_modes = 3, interview_mode = "x", interview_start_time = "x" },
            { note_roots = { 3 }, note_dirs = { 3 }, live_agent = { id = 3 } },
        },
        exercise = function(parley) parley.refresh_state() end,
    },
    {
        reader = "lua/parley/vault.lua",
        file = "vault_state.json",
        writes = "rewrite", why = "a cache of a fetched copilot bearer; a dropped token is fetched again",
        wrong_shapes = {
            { copilot_bearer = 3 },
            { copilot_bearer = { token = 3, expires_at = "x" } },
        },
        exercise = function(parley)
            -- A fresh vault instance, so the secret added here does not leak into
            -- the module other specs share; the bearer refresh spawns into the
            -- stateful process fake behind tasker's runtime seam.
            local tasker = require("parley.tasker")
            local shared, runtime = package.loaded["parley.vault"], tasker._uv
            package.loaded["parley.vault"] = nil
            local vault = require("parley.vault")
            tasker._uv = FakeProcess.new()
            local ok, err = pcall(function()
                vault.setup({ state_dir = parley.config.state_dir })
                vault.add_secret("copilot", "fixture-token")
                vault.refresh_copilot_bearer(function() end)
            end)
            tasker._uv = runtime
            package.loaded["parley.vault"] = shared
            assert(ok, err)
        end,
    },
    {
        reader = "lua/parley/custom_prompts.lua",
        file = "custom_system_prompts.json",
        writes = "preserve",
        wrong_shapes = {
            { fixture = 3 },
            { fixture = { system_prompt = 3 } },
        },
        -- One user action: building the prompt picker, the loop that once re-read
        -- the file per prompt. The spy calls through, so the view it records is
        -- the one the picker used.
        exercise = function()
            local prompts = require("parley.custom_prompts")
            local load, views = prompts.load, {}
            prompts.load = function() local view = load(); views[#views + 1] = view; return view end
            local names = {}
            for i = 1, 6 do names[i] = "p" .. i end
            local plugin = { _system_prompts = names, system_prompts = {}, _builtin_system_prompts = {},
                _state = { system_prompt = "p1" } }
            for _, name in ipairs(names) do plugin.system_prompts[name] = { system_prompt = name } end
            local ok, err = pcall(require("parley.system_prompt_picker")._build_items, plugin)
            prompts.load = load
            assert(ok, err)
            assert(#views == 1, "the picker read the prompt file " .. #views .. " times")
            for name, prompt in pairs(views[1]) do
                assert(type(prompt) == "table" and type(prompt.system_prompt) == "string",
                    "custom prompt " .. tostring(name) .. " reached a caller malformed")
            end
        end,
        -- A write through the module keeps the entry the view filtered out.
        preserve = function(_, path)
            local before = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
            assert(require("parley.custom_prompts").set("added", { system_prompt = "added" }), "set refused")
            local after = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
            assert(vim.deep_equal(before.fixture, after.fixture), "a write dropped the user's malformed entry")
        end,
    },
    {
        reader = "lua/parley/file_tracker.lua",
        file = "file_access.json",
        path = function() return require("parley.file_tracker").file_path() end,
        writes = "rewrite", why = "app-owned access history for finder sorting; a dropped entry starts again",
        wrong_shapes = {
            { ["/fixture.md"] = 3 },
            { ["/fixture.md"] = { last_accessed = "x", access_count = "y" } },
        },
        -- Opening a chat tracks it. Test mode makes the tracker's load and save
        -- no-ops, so the exercise turns it off for one tracked open.
        exercise = function()
            local tracker = require("parley.file_tracker")
            local test_mode = vim.g.parley_test_mode
            vim.g.parley_test_mode = false
            tracker._file_access = {}
            local ok, err = pcall(tracker.track_file_access, "/fixture.md")
            vim.g.parley_test_mode = test_mode
            tracker._file_access = {}
            assert(ok, err)
        end,
    },
    {
        reader = "lua/parley/chat_respond.lua",
        file = "remote_reference_cache.json",
        writes = "rewrite", why = "a cache of fetched references; a dropped entry is fetched again",
        wrong_shapes = {
            { chats = 3 },
            { chats = { fixture = 3 } },
            { chats = { fixture = { ["https://example.com/doc"] = 3 } } },
        },
        exercise = function(parley)
            parley._remote_reference_cache = nil
            local cache = require("parley.chat_respond").get_chat_remote_reference_cache("fixture")
            for url, content in pairs(cache) do
                assert(type(content) == "string", "cached reference " .. tostring(url) .. " is not text")
            end
        end,
    },
}
