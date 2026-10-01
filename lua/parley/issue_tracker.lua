-- Read-only reader of ariadne#252 tracker cards (the IO shell around
-- parley.issue_cards).
--
-- A repository is tracked once its cutover marker exists. Cards are read from
-- the local remote-tracking ref `refs/remotes/<remote>/<tracker>`, which every
-- linked worktree shares, so any sdlc verb in any slot keeps it current.
-- `refresh` adds a throttled background fetch of just that branch. Every git
-- call is async (vim.system) and every callback runs on the main loop. State
-- is in memory per repository root. Each load prunes the blob cache to the
-- current tree, so it is bounded by the tracker's card count (ARCH-FUNERAL).

local issue_cards = require("parley.issue_cards")
local issue_vocabulary = require("parley.issue_vocabulary")
local logger = require("parley.logger")

local uv = vim.uv or vim.loop

local M = {}

-- ariadne#252's cutover marker; the binary keeps the legacy flow without it.
M.MARKER = "workshop/issue-tracker.json"
M.fetch_interval_s = 60
-- Specs never reach a real remote unless they opt in (their fixtures are local).
M.fetch_enabled = vim.env.PARLEY_TEST_MODE ~= "1"
M.fetch_timeout_ms = 15000
M.read_timeout_ms = 10000
M._on_git = nil -- test hook: observes each git argv before it runs

local states = {}

local function state(root)
    states[root] = states[root] or { gen = 0, blobs = {}, waiters = {} }
    return states[root]
end

M.reset_for_tests = function()
    states = {}
end

M._blob_count_for_tests = function(root)
    return vim.tbl_count(state(root).blobs)
end

M.ensure_highlight = function()
    vim.api.nvim_set_hl(0, issue_cards.HIGHLIGHT, { fg = "#FFBF00", default = true })
end

-- Card directory, tracker branch and card-owned field names, all from the
-- vocabulary; nil (feature off) when the vocabulary is unavailable.
local function discovery()
    local ok, model = pcall(issue_vocabulary.default)
    local raw = ok and type(model) == "table" and model.raw or nil
    local found = raw and raw.discovery
    local names = issue_cards.card_field_names(raw)
    if type(found) ~= "table" or type(found.cards) ~= "string" or type(found.tracker) ~= "string" or not names then
        return nil
    end
    return { cards = found.cards, tracker = found.tracker, names = names }
end

M.field_names = function()
    local found = discovery()
    return found and found.names
end

M.repo_root = function(path)
    return type(path) == "string" and vim.fs.root(path, ".git") or nil
end

local function tracked(root)
    return type(root) == "string" and uv.fs_stat(root .. "/" .. M.MARKER) ~= nil
end

local function git(root, args, opts, callback)
    local argv = { "git", "-C", root }
    vim.list_extend(argv, args)
    if M._on_git then
        M._on_git(argv)
    end
    local ok, err = pcall(vim.system, argv, {
        text = false, -- cat-file frames are byte-sized; no newline rewriting
        stdin = opts.stdin,
        timeout = opts.timeout or M.read_timeout_ms,
        env = { GIT_TERMINAL_PROMPT = "0" },
    }, function(result)
        vim.schedule(function()
            callback(result.code == 0, result.stdout or "", result.stderr or "")
        end)
    end)
    if not ok then
        vim.schedule(function()
            callback(false, "", tostring(err))
        end)
    end
end

-- One read of the tracker tip into st.cards; `done(cards|nil)` unless a newer
-- read superseded this one (then the newer read answers the waiters).
local function read(root, st, found)
    st.gen = st.gen + 1
    local gen = st.gen
    st.loading = true

    local function finish(cards)
        if gen ~= st.gen then
            return
        end
        st.loading = false
        st.cards = cards
        local waiters = st.waiters
        st.waiters = {}
        for _, waiter in ipairs(waiters) do
            waiter(cards)
        end
    end

    local function fail(step, err)
        logger.debug("issue tracker: " .. step .. " failed in " .. root .. ": " .. tostring(err))
        finish(nil)
    end

    local ref_pattern = "refs/remotes/*/" .. found.tracker
    git(root, { "for-each-ref", "--format=%(refname:lstrip=2) %(objectname)", ref_pattern }, {}, function(ok, out, err)
        if not ok then
            return fail("for-each-ref", err)
        end
        local tips, remotes = {}, {}
        for remote, oid in out:gmatch("([^\n]+)/" .. vim.pesc(found.tracker) .. " (%x+)") do
            tips[remote] = oid
            remotes[#remotes + 1] = remote
        end
        git(root, { "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}" }, {}, function(has_upstream, upstream)
            local remote = issue_cards.select_remote(has_upstream and upstream:match("^([^/\n]+)/") or nil, remotes)
            if not remote then
                return finish(nil)
            end
            if st.cards and st.tip == tips[remote] and st.remote == remote then
                return finish(st.cards)
            end
            local tip = tips[remote]
            git(root, { "ls-tree", tip, "--", found.cards .. "/" }, {}, function(listed, tree, lerr)
                if not listed then
                    return fail("ls-tree", lerr)
                end
                local entries = issue_cards.parse_tree(tree)
                local missing = {}
                for _, entry in ipairs(entries) do
                    if st.blobs[entry.oid] == nil then
                        missing[#missing + 1] = entry.oid
                    end
                end
                local function assemble(fresh)
                    local blobs, cards = {}, {}
                    for _, entry in ipairs(entries) do
                        local card = st.blobs[entry.oid]
                        if card == nil then
                            card = issue_cards.parse_card(fresh[entry.oid]) or false
                        end
                        blobs[entry.oid] = card
                        if card and card.id == entry.id then
                            cards[entry.id] = card
                        end
                    end
                    if gen ~= st.gen then
                        return
                    end
                    st.blobs, st.tip, st.remote = blobs, tip, remote
                    finish(cards)
                end
                if #missing == 0 then
                    return assemble({})
                end
                git(root, { "cat-file", "--batch" }, { stdin = table.concat(missing, "\n") .. "\n" },
                    function(catted, payload, cerr)
                        if not catted then
                            return fail("cat-file", cerr)
                        end
                        assemble(issue_cards.parse_batch(payload))
                    end)
            end)
        end)
    end)
end

-- Cards of the repository at `root`, keyed by id; `callback(nil)` when it is not
-- tracked, carries no tracker ref, or git fails. Concurrent loads share a read.
M.load = function(root, callback)
    local found = discovery()
    if not found or not tracked(root) then
        return vim.schedule(function()
            callback(nil)
        end)
    end
    local st = state(root)
    st.waiters[#st.waiters + 1] = callback
    if not st.loading then
        read(root, st, found)
    end
end

-- Fetch the tracker branch (at most once per fetch_interval_s per root), re-read
-- it, and call `on_moved(cards)` only when the tip changed. `on_settled` (optional)
-- runs once this refresh is finished or skipped.
M.refresh = function(root, on_moved, on_settled)
    on_settled = on_settled or function() end
    local found = discovery()
    local st = tracked(root) and found and states[root]
    local now = uv.now() / 1000
    if not M.fetch_enabled or not st or not st.remote or st.fetching
        or (st.fetched_at and now - st.fetched_at < M.fetch_interval_s) then
        return vim.schedule(on_settled)
    end
    st.fetching, st.fetched_at = true, now
    git(root, { "fetch", "--quiet", "--no-tags", "--no-write-fetch-head", st.remote, found.tracker },
        { timeout = M.fetch_timeout_ms }, function(ok, _, err)
            st.fetching = false
            if not ok then
                logger.debug("issue tracker: fetch failed in " .. root .. ": " .. tostring(err))
                return on_settled()
            end
            local before = st.tip
            st.waiters[#st.waiters + 1] = function(cards)
                if cards and st.tip ~= before then
                    on_moved(cards)
                end
                on_settled()
            end
            read(root, st, found) -- supersedes any read of the pre-fetch tip
        end)
end

return M
