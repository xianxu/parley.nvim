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
    states[root] = states[root] or { gen = 0, blobs = {}, waiters = {}, subscribers = {}, joiners = {} }
    return states[root]
end

M.reset_for_tests = function()
    states = {}
end

M._blob_count_for_tests = function(root)
    return vim.tbl_count(state(root).blobs)
end

M._busy_for_tests = function(root)
    local st = states[root]
    return st ~= nil and (st.fetching == true or st.loading == true)
end

-- Keep only subscribers whose view is still open, so the set is bounded by the
-- live views on a root rather than by how many were ever opened (ARCH-FUNERAL).
local function live(subscribers)
    local kept = {}
    for _, subscriber in ipairs(subscribers) do
        if subscriber.alive() then
            kept[#kept + 1] = subscriber
        end
    end
    return kept
end

-- Every open view of `root` registers here: `notify(cards)` runs whenever any
-- read (a load, or a refresh someone else triggered) finds a new tracker tip.
-- `alive()` returning false drops the subscriber.
M.subscribe = function(root, subscriber)
    local st = state(root)
    st.subscribers = live(st.subscribers)
    st.subscribers[#st.subscribers + 1] = subscriber
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
        -- A transient git failure keeps the last good cards.
        logger.debug("issue tracker: " .. step .. " failed in " .. root .. ": " .. tostring(err))
        finish(st.cards)
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
                    local moved = st.tip ~= tip
                    st.blobs, st.tip, st.remote = blobs, tip, remote
                    finish(cards)
                    if moved then
                        st.subscribers = live(st.subscribers)
                        for _, subscriber in ipairs(st.subscribers) do
                            subscriber.notify(cards)
                        end
                    end
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

-- The remote to fetch the tracker from when no read has found one yet (#309's
-- first-fetch bootstrap): the same choice the reader makes, over every remote.
local function resolve_remote(root, st, done)
    if st.remote then
        return done(st.remote)
    end
    git(root, { "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}" }, {}, function(has_upstream, upstream)
        git(root, { "remote" }, {}, function(ok, out)
            local remotes = ok and vim.split(vim.trim(out), "\n", { trimempty = true }) or {}
            done(issue_cards.select_remote(has_upstream and upstream:match("^([^/\n]+)/") or nil, remotes))
        end)
    end)
end

-- Fetch the tracker branch (at most once per fetch_interval_s per root) and
-- re-read it; a moved tip reaches every subscriber. A repository whose checkout
-- never fetched the tracker resolves a remote first. The explicit refspec also
-- serves single-branch clones. `on_settled` (optional) runs once this refresh
-- is finished or skipped.
M.refresh = function(root, on_settled)
    on_settled = on_settled or function() end
    local found = discovery()
    local st = tracked(root) and found and states[root]
    local now = uv.now() / 1000
    if st and st.fetching then
        -- Wait for the fetch in flight: settling now would let a view report
        -- "refreshing…" after it ends with an unchanged tip (no notify), and the
        -- caller may be asking for a change made after that fetch began.
        st.joiners[#st.joiners + 1] = on_settled
        return
    end
    if not M.fetch_enabled or not st
        or (st.fetched_at and now - st.fetched_at < M.fetch_interval_s) then
        return vim.schedule(on_settled)
    end
    -- Stamp before resolving: the bootstrap path is throttled too, and a
    -- concurrent refresh joins via `fetching`.
    st.fetching, st.fetched_at = true, now
    local function settle()
        st.fetching = false
        local joiners = st.joiners
        st.joiners = {}
        on_settled()
        if #joiners > 0 then
            -- They asked after this fetch began: give them a follow-up refresh
            -- (still throttled, so usually it settles at once).
            M.refresh(root, function()
                for _, joiner in ipairs(joiners) do
                    joiner()
                end
            end)
        end
    end
    resolve_remote(root, st, function(remote)
        if not remote then
            return settle()
        end
        local refspec = "+refs/heads/" .. found.tracker .. ":refs/remotes/" .. remote .. "/" .. found.tracker
        git(root, { "fetch", "--quiet", "--no-tags", "--no-write-fetch-head", remote, refspec },
            { timeout = M.fetch_timeout_ms }, function(ok, _, err)
                if not ok then
                    logger.debug("issue tracker: fetch failed in " .. root .. ": " .. tostring(err))
                    st.fetch_failed_at, st.fetch_error = os.time(), tostring(err)
                    return settle()
                end
                st.fetch_ok_at, st.fetch_failed_at, st.fetch_error = os.time(), nil, nil
                st.remote = st.remote or remote -- provisional until the read confirms it
                -- `fetching` stays set until the post-fetch read lands, so a
                -- joiner sees the new tip.
                st.waiters[#st.waiters + 1] = settle
                read(root, st, found) -- supersedes any read of the pre-fetch tip
            end)
    end)
end

-- How current this root's cards are, for views that must say so (#309): the
-- ref read (nil until a remote is known, e.g. during a first-fetch bootstrap),
-- its tip, and the last fetch outcome (wall-clock seconds). nil when the root
-- was never loaded or the vocabulary names no tracker.
M.status = function(root)
    local st = states[root]
    local found = discovery()
    if not st or not found then
        return nil
    end
    return {
        ref = st.remote and (st.remote .. "/" .. found.tracker) or nil,
        tip = st.tip,
        fetching = st.fetching == true,
        fetch_ok_at = st.fetch_ok_at,
        fetch_failed_at = st.fetch_failed_at,
        fetch_error = st.fetch_error,
    }
end

return M
