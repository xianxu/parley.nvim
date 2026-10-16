-- #233 over real files: the request context is the chat tree in depth-first
-- order, cut at the exchange being submitted. Files are read from their loaded
-- buffer when there is one, so an unsaved child is seen as the operator sees it.
local tmp_dir = vim.fn.tempname() .. "-parley-chat-tree"
local chat_dir = tmp_dir .. "/chats"
vim.fn.mkdir(chat_dir, "p")

local parley = require("parley")
parley.setup({ chat_dir = chat_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local chat_respond = require("parley.chat_respond")

local function write_chat(basename, body)
    local path = chat_dir .. "/" .. basename
    local lines = { "---", "topic: T", "file: " .. basename, "model: m", "provider: openai", "---", "" }
    vim.list_extend(lines, body)
    vim.fn.writefile(lines, path)
    return vim.fn.resolve(path)
end

local function parse(path)
    local lines = parley.helpers.chat_lines(path)
    return parley.chat_parser.parse_chat(lines, parley.chat_parser.find_header_end(lines), parley.config)
end

-- The questions of the context for submitting exchange `cut` of `path`.
local function questions(path, cut)
    local parsed = parse(path)
    local sequence = chat_respond._tree_sequence(path, parsed, cut, parsed)
    local out = {}
    for _, item in ipairs(sequence) do out[#out + 1] = vim.trim(item.exchange.question.content) end
    return out, sequence
end

describe("chat context over a real chat tree (#233)", function()
    local root, aside, nested, later
    before_each(function()
        -- root: R1, an inline <M-i> aside in R1's answer, then R2 with a 🌿: branch.
        root = write_chat("2026-10-16.09-00-00.001.md", {
            "💬: R1", "", "🤖:[A]", "answer one, see [🌿:aside](2026-10-16.09-01-00.002.md)", "",
            "💬: R2", "", "🤖:[A]", "answer two", "",
            "🌿: 2026-10-16.09-03-00.004.md: Later", "",
            "💬: R3", "",
        })
        aside = write_chat("2026-10-16.09-01-00.002.md", {
            "🌿: 2026-10-16.09-00-00.001.md: Root", "",
            "💬: A1", "", "🤖:[A]", "aside answer", "",
            "🌿: 2026-10-16.09-02-00.003.md: Nested", "",
        })
        nested = write_chat("2026-10-16.09-02-00.003.md", {
            "🌿: 2026-10-16.09-01-00.002.md: Aside", "",
            "💬: AA1", "", "🤖:[A]", "nested answer", "",
        })
        later = write_chat("2026-10-16.09-03-00.004.md", {
            "🌿: 2026-10-16.09-00-00.001.md: Root", "",
            "💬: L1", "",
        })
    end)
    after_each(function()
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_get_name(b):find(chat_dir, 1, true) then
                vim.api.nvim_buf_delete(b, { force = true })
            end
        end
    end)

    it("sends the aside, and its nested aside, to the next question in the root", function()
        assert.same({ "R1", "A1", "AA1", "R2" }, questions(root, 2))
    end)

    it("gives a later branch every subtree to its left", function()
        assert.same({ "R1", "A1", "AA1", "R2", "L1" }, questions(later, 1))
    end)

    it("sends nothing to the right of the cut", function()
        assert.same({ "R1", "A1" }, questions(aside, 1)) -- not AA1, R2 or the later branch
    end)

    local function messages_for(path, cut, opts)
        opts = opts or {}
        local parsed = parse(path)
        local input = opts.input or parsed
        local input_index = opts.input_index or cut
        local sequence, at = chat_respond._tree_sequence(path, parsed, cut, input, input_index)
        local config = vim.tbl_deep_extend("force", parley.config,
            { chat_memory = opts.memory or { enable = false } })
        local messages = chat_respond.build_messages({ parsed_chat = input, sequence = sequence,
            start_index = opts.start_index or 1, end_index = 100000, exchange_idx = at,
            agent = { name = "t", provider = "openai", model = "m", system_prompt = "S" },
            config = config, helpers = parley.helpers, logger = parley.logger, chat_path = path,
            resolved_remote_content = opts.remote })
        local out = {}
        for i = 2, #messages do out[#out + 1] = vim.trim(tostring(messages[i].content)) end
        return out, sequence, at
    end

    -- BR-2: a request that leaves an exchange out leaves out the asides off it.
    it("drops an aside with the batch leg's exchange it hangs off", function()
        local parsed = parse(root)
        local input = vim.deepcopy(parsed)
        table.remove(input.exchanges, 1) -- the leg keeps R2 and R3, not R1
        local _, sequence = messages_for(root, 2, { input = input, input_index = 1 })
        local qs = {}
        for i = 1, #sequence - 1 do qs[#qs + 1] = vim.trim(sequence[i].exchange.question.content) end
        assert.same({ "R2" }, qs) -- no A1/AA1: R1, the exchange they are about, is not sent
    end)

    it("drops an aside whose branch reference is outside the visual range", function()
        local r2_row = parse(root).exchanges[2].question.line_start
        local out = messages_for(root, 2, { start_index = r2_row })
        assert.same({ "R2" }, out)
    end)

    -- BR-3: the window counts back from the end of the current file, as it
    -- did for a single file, not from the cut.
    it("keeps the single-file window when resubmitting mid-chat", function()
        local body = {}
        for i = 1, 10 do vim.list_extend(body, { "💬: Q" .. i, "", "🤖:[A]", "a" .. i, "", "📝: s" .. i, "" }) end
        local single = write_chat("2026-10-16.10-00-00.010.md", body)
        local out = messages_for(single, 3, { memory = { enable = true, max_full_exchanges = 4 } })
        local omitted = parley.config.chat_memory.omit_user_text or "[Previous messages omitted]"
        assert.same({ omitted, "s1", omitted, "s2", "Q3" }, out)
    end)

    -- BR-1: a remote reference in another file of the tree reads that file's
    -- cache, so its content is sent instead of a "not cached" stub.
    it("resolves a remote reference in an ancestor from the ancestor's cache", function()
        local url = "https://example.com/tree-" .. math.random(1000000)
        local parent = write_chat("2026-10-16.11-00-00.020.md", {
            "💬: read @@" .. url .. "@@", "", "🤖:[A]", "read it", "",
            "🌿: 2026-10-16.11-01-00.021.md: Child", "",
        })
        local child = write_chat("2026-10-16.11-01-00.021.md", {
            "🌿: 2026-10-16.11-00-00.020.md: Parent", "", "💬: and then?", "",
        })
        chat_respond.get_chat_remote_reference_cache(parent)[url] = "the cached page"
        local parsed = parse(child)
        local sequence, at = chat_respond._tree_sequence(child, parsed, 1, parsed, 1)
        local resolved
        chat_respond.resolve_remote_references({ parsed_chat = parsed, config = parley.config,
            chat_file = child, exchange_idx = at, sequence = sequence }, function(value) resolved = value end)
        assert.is_true(vim.wait(2000, function() return resolved ~= nil end, 10), "remote resolution never finished")
        assert.equals("the cached page", resolved[url])
        local out = messages_for(child, 1, { remote = resolved })
        assert.is_truthy(table.concat(out, "\n"):find("the cached page", 1, true), table.concat(out, "\n"))
    end)

    -- Round 2: one file, however it is named. Under a symlinked chat dir the
    -- buffer name and the walk's resolved path name the same cache.
    it("reads the current file's cache through a symlinked chat dir", function()
        local real = tmp_dir .. "/real-" .. math.random(1000000)
        local link = tmp_dir .. "/link-" .. math.random(1000000)
        vim.fn.mkdir(real, "p")
        assert(vim.uv.fs_symlink(real, link))
        local url = "https://example.com/linked-" .. math.random(1000000)
        local named = link .. "/2026-10-16.12-00-00.030.md" -- the buffer's name
        vim.fn.writefile({ "---", "topic: T", "file: x.md", "model: m", "provider: openai", "---", "",
            "💬: read @@" .. url .. "@@", "", "🤖:[A]", "read it", "", "💬: and?", "" }, named)
        chat_respond.get_chat_remote_reference_cache(named)[url] = "CACHED"
        local parsed = parse(named)
        local sequence, at = chat_respond._tree_sequence(named, parsed, 2, parsed, 2)
        local resolved
        chat_respond.resolve_remote_references({ parsed_chat = parsed, config = parley.config,
            chat_file = named, exchange_idx = at, sequence = sequence }, function(value) resolved = value end)
        assert.is_true(vim.wait(5000, function() return resolved ~= nil end, 10), "remote resolution never finished")
        assert.equals("CACHED", resolved[url])
    end)

    it("looks up another file's cache without creating an entry for it", function()
        local parsed = parse(root)
        local sequence, at = chat_respond._tree_sequence(later, parse(later), 1, parse(later), 1)
        local resolved
        chat_respond.resolve_remote_references({ parsed_chat = parsed, config = parley.config,
            chat_file = later, exchange_idx = at, sequence = sequence }, function(value) resolved = value end)
        assert.is_true(vim.wait(2000, function() return resolved ~= nil end, 10))
        local chats = chat_respond.load_remote_reference_cache().chats
        for _, file in ipairs({ root, aside, nested }) do
            assert.is_nil(chats[file], "a lookup created a cache entry for " .. file)
        end
    end)

    -- Round 3: a fetch for another file's reference is saved under that file,
    -- where the next lookup reads it, so it is fetched once.
    it("caches an ancestor's fetched reference under the ancestor, once", function()
        local url = "https://example.com/once-" .. math.random(1000000)
        local parent = write_chat("2026-10-16.13-00-00.040.md", {
            "💬: read @@" .. url .. "@@", "", "🤖:[A]", "read it", "",
            "🌿: 2026-10-16.13-01-00.041.md: Child", "",
        })
        local child = write_chat("2026-10-16.13-01-00.041.md", {
            "🌿: 2026-10-16.13-00-00.040.md: Parent", "", "💬: and then?", "",
        })
        local drive = require("parley.oauth")
        local saved, calls = drive.fetch_content, 0
        drive.fetch_content = function(_, _, callback) calls = calls + 1; callback("fetched body") end
        local function resolve()
            local parsed = parse(child)
            local sequence, at = chat_respond._tree_sequence(child, parsed, 1, parsed, 1)
            local resolved
            chat_respond.resolve_remote_references({ parsed_chat = parsed, config = parley.config,
                chat_file = child, exchange_idx = at, sequence = sequence }, function(value) resolved = value end)
            assert.is_true(vim.wait(2000, function() return resolved ~= nil end, 10))
            return resolved
        end
        local ok, err = pcall(function()
            assert.is_truthy(resolve()[url]:find("fetched body", 1, true))
            assert.is_truthy(resolve()[url]:find("fetched body", 1, true))
        end)
        drive.fetch_content = saved
        assert(ok, err)
        assert.equals(1, calls, "the ancestor's reference was fetched again")
        assert.is_nil(chat_respond.peek_chat_remote_reference_cache(child)[url], "saved under the child")
    end)

    -- #352: side chats off the path to the root are sent as their summaries.
    describe("side chats off the path", function()
        local r, a, n
        before_each(function()
            r = write_chat("2026-10-16.14-00-00.050.md", {
                "💬: R1", "", "🤖:[A]", "root answer [🌿:aside](2026-10-16.14-01-00.051.md)", "📝: r1 sum", "",
                "💬: R2", "", "🤖:[A]", "root answer two", "📝: r2 sum", "",
                "💬: R3", "",
            })
            a = write_chat("2026-10-16.14-01-00.051.md", {
                "🌿: 2026-10-16.14-00-00.050.md: Root", "",
                "💬: A1", "", "🤖:[A]", "long aside answer", "📝: aside sum", "",
                "🌿: 2026-10-16.14-02-00.052.md: Nested", "",
                "💬: A2", "", "🤖:[A]", "aside answer two", "📝: a2 sum", "",
                "💬: A3", "",
            })
            n = write_chat("2026-10-16.14-02-00.052.md", {
                "🌿: 2026-10-16.14-01-00.051.md: Aside", "",
                "💬: AA1", "", "🤖:[A]", "nested answer", "📝: nested sum", "",
            })
        end)
        local omitted = "[Previous messages omitted]"
        local function has(out, text)
            for _, content in ipairs(out) do
                if content:find(text, 1, true) then return true end
            end
            return false
        end

        it("sends an aside and its nested aside as summaries to a later root question", function()
            local out = messages_for(r, 2)
            assert.equals("R1", out[1])
            assert.is_truthy(out[2]:find("root answer", 1, true)) -- the path is sent in full
            assert.same({ omitted, "aside sum", omitted, "nested sum", omitted, "a2 sum",
                "[A side chat question, with no summary] A3", "R2" },
                vim.list_slice(out, 3))
        end)

        it("sends the nested aside as its summary, and the on-path root in full, to the aside", function()
            local out = messages_for(a, 3)
            assert.same({ "R1", "A1", "A2", "A3" }, vim.tbl_filter(function(c) return c:match("^[RA]%d$") end, out))
            assert.is_true(has(out, "root answer"))
            assert.is_true(has(out, "long aside answer"))
            assert.is_true(has(out, "nested sum"))
            assert.is_false(has(out, "nested answer"))
        end)

        it("sends the whole path in full to the nested aside", function()
            local out = messages_for(n, 1)
            assert.is_true(has(out, "root answer"))
            assert.is_true(has(out, "long aside answer"))
            assert.equals("AA1", out[#out])
        end)

        it("renders side chats like any exchange under side_chats = full", function()
            local out = messages_for(r, 2, { memory = { enable = false, side_chats = "full" } })
            assert.is_true(has(out, "long aside answer"))
            assert.is_true(has(out, "nested answer"))
            assert.is_false(has(out, omitted))
        end)

        it("sends an exchange with no summary as its question alone, truncated and marked", function()
            local long = "B1 " .. string.rep("é", 400)
            local root = write_chat("2026-10-16.15-00-00.060.md", {
                "💬: R1", "", "🤖:[A]", "answer", "", "🌿: 2026-10-16.15-01-00.061.md: Side", "", "💬: R2", "",
            })
            write_chat("2026-10-16.15-01-00.061.md", {
                "🌿: 2026-10-16.15-00-00.060.md: Root", "", "💬: " .. long, "", "🤖:[A]", "unsummarized answer", "",
            })
            local out = messages_for(root, 2)
            local marked = "[A side chat question, with no summary] "
            assert.equals(marked .. vim.fn.strcharpart(long, 0, 300) .. "…", out[3])
            assert.equals("[Side chat answer omitted]", out[4])
            assert.is_false(has(out, "unsummarized answer"))
        end)

        it("sends no placeholder for a blank side-chat question, as the summarized branch", function()
            local exchange = { question = { content = "" }, answer = { content = "x" }, summary = { content = "s" } }
            assert.same({ { role = "assistant", content = "s" } }, chat_respond.side_chat_messages(exchange, " ", "P"))
            assert.same({ { role = "user", content = "P" }, { role = "assistant", content = "s" } },
                chat_respond.side_chat_messages(exchange, "q", "P"))
        end)

        it("neither fetches nor inlines a side chat's remote reference", function()
            local url = "https://example.com/side-" .. math.random(1000000)
            local root = write_chat("2026-10-16.16-00-00.070.md", {
                "💬: R1", "", "🤖:[A]", "answer", "", "🌿: 2026-10-16.16-01-00.071.md: Side", "", "💬: R2", "",
            })
            write_chat("2026-10-16.16-01-00.071.md", {
                "🌿: 2026-10-16.16-00-00.070.md: Root", "", "💬: read @@" .. url .. "@@", "",
                "🤖:[A]", "read it", "📝: read sum", "",
            })
            local oauth = require("parley.oauth")
            local saved, calls = oauth.fetch_content, 0
            oauth.fetch_content = function(_, _, callback) calls = calls + 1; callback("fetched body") end
            local parsed = parse(root)
            local sequence, at = chat_respond._tree_sequence(root, parsed, 2, parsed, 2)
            local resolved
            local ok, err = pcall(function()
                chat_respond.resolve_remote_references({ parsed_chat = parsed, config = parley.config,
                    chat_file = root, exchange_idx = at, sequence = sequence }, function(value) resolved = value end)
                assert.is_true(vim.wait(2000, function() return resolved ~= nil end, 10))
            end)
            oauth.fetch_content = saved
            assert(ok, err)
            assert.equals(0, calls)
            assert.is_nil(resolved[url])
            local out = messages_for(root, 2, { remote = resolved })
            assert.is_false(has(out, url))
            assert.is_true(has(out, "read sum"))
        end)

        it("counts only the path's exchanges in the memory window", function()
            -- Three path exchanges and a window of three: all in full, though
            -- the aside's three exchanges come before R3.
            local out = messages_for(r, 3, { memory = { enable = true, max_full_exchanges = 3 } })
            assert.equals("R1", out[1])
            assert.is_true(has(out, "root answer two"))
            assert.is_false(has(out, "long aside answer"))
        end)
    end)

    -- #349: delete-tree, move and export act on chat_tree's tree.
    it("gives delete-tree and move the whole tree from any of its files, depth-first", function()
        assert.same({ root, aside, nested, later }, parley.get_chat_tree_files(nested))
    end)

    it("makes an orphaned child its own tree: the parent no longer lists it", function()
        local parent = write_chat("2026-10-16.17-00-00.080.md", { "💬: P1", "", "🤖:[A]", "p", "" })
        local child = write_chat("2026-10-16.17-01-00.081.md", {
            "🌿: 2026-10-16.17-00-00.080.md: Parent", "", "💬: C1", "",
        })
        -- The old root finder followed the link anyway, and the parent's tree
        -- does not contain the child: delete-tree removed the parent, kept the child.
        assert.same({ child }, parley.get_chat_tree_files(child))
        assert.equals(child, require("parley.outline")._find_tree_root(child))
        assert.equals(child, require("parley.exporter")._find_tree_root(child))
        assert.is_true(vim.fn.filereadable(parent) == 1)
    end)

    it("reads an unsaved child from its buffer", function()
        vim.cmd("edit " .. vim.fn.fnameescape(aside))
        local buf = vim.api.nvim_get_current_buf()
        local row = vim.fn.search("aside answer")
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "edited, not saved" })
        vim.cmd("buffer #")
        local _, sequence = questions(root, 2)
        local answer = vim.trim(sequence[2].exchange.answer.content)
        assert.equals("edited, not saved", answer)
        assert.equals(nested, sequence[3].file)
    end)
end)
