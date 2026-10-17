-- Public Parley move doors also accept ordinary Markdown under a chat root.
-- Exercise those doors, rather than imitating a native saveas event sequence.
local arrival = require("tests.helpers.arrival")
describe("registered ordinary Markdown through Parley move doors", function()
    local root, source, destination, file, buf, saved, p, document, registration
    local uv = vim.uv or vim.loop
    local function await(predicate)
        assert.is_true(vim.wait(arrival.MS, predicate, 10), "registered document operation did not finish")
    end
    local function lookup(path)
        local result
        require("parley.document_registry").request("lookup", {path}, {}, function(value) result = value end)
        await(function() return result ~= nil end)
        return result
    end
    local function seed_side()
        vim.fn.mkdir(source .. "/ordinary.side", "p")
        vim.fn.writefile({ "---", "parent: '" .. file .. "'", "---", "[up](" .. file .. "#question)", "unrelated bytes" },
            source .. "/ordinary.side/child.md")
    end
    local function s3_parent()
        seed_side()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "---", "owner: business-team", "discussions:", "  - doc: 'ordinary.side/child.md' # retain",
            "---", "# Question", "original", "[side](ordinary.side/child.md#question)",
        })
        assert.is_true(document.submit(buf))
        await(function() return not document.status(buf).operation and vim.fn.filereadable(file .. ".lock") == 0 end)
        return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        source, destination = root .. "/source", root .. "/destination"
        vim.fn.mkdir(source, "p")
        vim.fn.mkdir(destination, "p")
        file = source .. "/ordinary.md"
        vim.fn.writefile({ "---", "owner: business-team", "---", "# Question", "original", "tail" }, file)
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        local previous_test_mode = vim.g.parley_test_mode
        vim.g.parley_test_mode = true
        p, document = require("parley"), require("parley.agentic_document")
        saved = { env = {}, config = {}, test_mode = previous_test_mode }
        for _, name in ipairs({ "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "COUCH_ISOLATED_ROOT",
            "FAKE_COUCH_REGISTRY", "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_STATUS",
            "FAKE_COUCH_REGISTRY_REPLY_DELAY", "FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS" }) do
            saved.env[name] = vim.env[name] or false
        end
        for _, name in ipairs({ "chat_dir", "chat_dirs", "chat_roots", "state_dir", "review_shortcut_next" }) do
            saved.config[name] = vim.deepcopy(p.config[name] or false)
        end
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "owned-move", "pane"
        vim.env.COUCH_ISOLATED_ROOT = root
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = root .. "/registry.json", nil
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP = "0", nil
        vim.env.FAKE_COUCH_STATUS = nil
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code="ok", Actors={
            { Binding={ Slot="ops:0", Scope="owned-move", Tag="pane" } },
        } })
        p.config.state_dir = root .. "/state"
        p.config.review_shortcut_next = { modes={"n","i"}, shortcut="<M-CR>" }
        assert(p.set_chat_dirs({source, destination}, false))
        local admitted
        require("parley.document_registry").request("register", {file,"ops:0"}, {}, function(value) admitted = value end)
        await(function() return admitted ~= nil end)
        assert.equals("registered", admitted.kind)
        registration = admitted.registration
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
        await(function() return document.identity(buf) ~= nil and document.status(buf).phase == "registered" end)
        assert.is_not_nil(p.not_chat(buf, file), "fixture must remain an ordinary non-chat document")
    end)
    after_each(function()
        for _, owned in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(owned) and vim.api.nvim_buf_get_name(owned):sub(1,#root+1) == root .. "/" then
                document.detach(owned)
                vim.api.nvim_buf_delete(owned, {force=true})
            end
        end
        require("parley.document_registry").shutdown()
        for name, value in pairs(saved.env) do vim.env[name] = value or nil end
        for name, value in pairs(saved.config) do p.config[name] = value or nil end
        vim.g.parley_test_mode = saved.test_mode
        vim.fn.delete(root, "rf")
    end)

    it("renames side references in disk and the loaded buffer before releasing a synthetic turn", function()
        local before = s3_parent()
        local target = destination .. "/spec.md"
        local called, handled, moved, err = pcall(document.move_path, file, target)
        assert.is_true(called, tostring(handled))
        assert.is_true(handled)
        assert.equals(target, moved, tostring(err))
        await(function() return document.identity(buf).File == target and not document.status(buf).operation end)
        local expected = {}
        for index, line in ipairs(before) do expected[index] = line:gsub("ordinary%.side", "spec.side") end
        assert.same(expected, vim.fn.readfile(target))
        assert.same(expected, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.equals(0, vim.fn.filereadable(target .. ".lock"), "mechanical references do not invent an operator turn")
        vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "edit after rewrite" })
        assert.equals(1, vim.fn.filereadable(target .. ".lock"), "read must retain native edit observers")
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
        assert.equals("edit after rewrite", vim.fn.readfile(target)[7])
    end)

    local function interrupted_editor_move()
        s3_parent()
        local target = destination .. "/spec.md"
        local mover = require("parley.document_move")
        local begin, injected = mover.begin, false
        mover.begin = function(namespace, identity, path, options)
            options.fs = setmetatable({ fs_rename = function(from, to)
                if not injected and from:find(".json", 1, true) and vim.fn.filereadable(from) == 1 then
                    local ok, record = pcall(vim.json.decode, table.concat(vim.fn.readfile(from), "\n"))
                    if ok and record.state and record.state.phase == "metadata" then
                        injected = true
                        return nil, "injected editor checkpoint failure"
                    end
                end
                return uv.fs_rename(from, to)
            end }, { __index = uv })
            return begin(namespace, identity, path, options)
        end
        local ok, handled, moved, err = pcall(document.move_path, file, target)
        mover.begin = begin
        assert.is_true(ok, tostring(handled)); assert.is_true(handled)
        assert.is_true(injected, "fault must intercept the editor-synced checkpoint")
        assert.is_nil(moved); assert.is_truthy(err)
        assert.same(vim.fn.readfile(target), vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        local journal_path = vim.fn.glob(root .. "/state/document-moves/*/*.json")
        assert.is_not.equals("", journal_path)
        local journal = vim.json.decode(table.concat(vim.fn.readfile(journal_path), "\n"))
        assert.equals("editor", journal.state.phase)
        assert.is_string(journal.parent.editor_before_hash)
        return target
    end

    it("recovers the mechanical baseline after the editor checkpoint cannot publish", function()
        local target = interrupted_editor_move()
        document.detach(buf)
        assert.is_true(document.attach(buf))
        await(function()
            local identity = document.identity(buf)
            return identity and identity.File == target and not document.status(buf).operation
        end)
        assert.equals(registration.ID, document.identity(buf).ID)
        assert.equals(0, vim.fn.filereadable(target .. ".lock"), "recovery must not invent an operator turn")
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    it("preserves an operator edit made during the recovered name read", function()
        local target = interrupted_editor_move()
        document.detach(buf)
        local edited = false
        vim.api.nvim_create_autocmd("BufReadPost", { buffer = buf, once = true, callback = function()
            edited = true
            vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "operator edit during recovered read" })
        end })
        assert.is_true(document.attach(buf))
        assert.is_true(edited, "recovery must cross the real name-read autocmd")
        assert.equals("operator edit during recovered read", vim.api.nvim_buf_get_lines(buf, 6, 7, false)[1])
        assert.is_true(vim.bo[buf].modified)
        assert.equals("original", vim.fn.readfile(target)[7])
        assert.equals("absent", lookup(target).kind, "interrupted editor read precedes registry rename")
        assert.equals(1, vim.fn.filereadable(target .. ".lock"))
        assert.is_not.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    it("preserves an operator edit made during a v1 recovered name read", function()
        local target = destination .. "/legacy.md"
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local handled, moved, err = document.move_path(file, target)
        assert.is_true(handled); assert.equals(target, moved, tostring(err))
        local journal_path = vim.fn.glob(root .. "/state/document-moves/*/*.json")
        assert.is_not.equals("", journal_path)
        await(function()
            local record = vim.json.decode(table.concat(vim.fn.readfile(journal_path), "\n"))
            return record.state.phase == "metadata" and not document.status(buf).operation
        end)
        document.detach(buf)
        local journal = vim.json.decode(table.concat(vim.fn.readfile(journal_path), "\n"))
        assert.equals(journal.old_hash, journal.new_witness.hash, "v1 fixture must retain unchanged document bytes")
        journal.version = 1
        journal.state, journal.parent, journal.captured, journal.editor_captured = nil, nil, nil, nil
        journal.orphan, journal.confirmation = nil, nil
        table.remove(journal.temps) -- v2's parent rewrite temp is absent from v1.
        journal.steps = { document_moved = true, side_moved = true, rewritten = {}, metadata = false }
        vim.fn.writefile({vim.json.encode(journal)}, journal_path)
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        local edited = false
        vim.api.nvim_create_autocmd("BufReadPost", { buffer = buf, once = true, callback = function()
            edited = true
            vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "operator edit during v1 recovery" })
        end })
        assert.is_true(document.attach(buf))
        assert.is_true(edited, "validated v1 recovery must cross the real name read")
        assert.equals("operator edit during v1 recovery", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1])
        assert.is_true(vim.bo[buf].modified)
        assert.equals("original", vim.fn.readfile(target)[5])
        assert.equals("absent", lookup(target).kind, "v1 read refusal must precede metadata publication")
        assert.equals(1, vim.fn.filereadable(target .. ".lock"))
        assert.equals(1, vim.fn.filereadable(journal_path))
    end)

    it("preserves an operator edit made during the rewritten parent read", function()
        s3_parent()
        local target = destination .. "/spec.md"
        local edited = false
        local autocmd = vim.api.nvim_create_autocmd("BufReadPost", { buffer = buf, callback = function()
            if vim.fn.filereadable(target) == 1
                and table.concat(vim.fn.readfile(target), "\n"):find("spec.side", 1, true) then
                edited = true
                vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "operator edit during parent read" })
            end
        end })
        local ok, handled, moved, err = pcall(document.move_path, file, target)
        vim.api.nvim_del_autocmd(autocmd)
        assert.is_true(ok, tostring(handled)); assert.is_true(handled)
        assert.is_true(edited, "the real rewritten parent read must cross the autocmd")
        assert.is_nil(moved); assert.is_truthy(err)
        assert.equals("operator edit during parent read", vim.api.nvim_buf_get_lines(buf, 6, 7, false)[1])
        assert.is_true(vim.bo[buf].modified)
        assert.equals("original", vim.fn.readfile(target)[7])
        assert.equals("absent", lookup(target).kind, "editor refusal precedes registry rename")
        assert.equals(1, vim.fn.filereadable(target .. ".lock"))
        assert.is_not.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    it("uses unsaved native saveas content and preserves an admitted orphan", function()
        local before = s3_parent()
        local target = destination .. "/spec.md"
        vim.fn.mkdir(destination .. "/spec.side", "p")
        vim.fn.writefile({ "orphan bytes" }, destination .. "/spec.side/older.md")
        vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "unsaved native content" })
        local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("saveas " .. vim.fn.fnameescape(target)) end)
        assert.is_true(ok, tostring(err))
        await(function() return document.identity(buf).File == target and not document.status(buf).operation end)
        local expected = {}
        for index, line in ipairs(before) do expected[index] = line:gsub("ordinary%.side", "spec.side") end
        expected[7] = "unsaved native content"
        assert.same(before, vim.fn.readfile(file), "native saveas retains OLD's saved preimage")
        assert.same(expected, vim.fn.readfile(target))
        assert.same(expected, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.same({ "orphan bytes" }, vim.fn.readfile(destination .. "/spec_1.side/older.md"))
        assert.equals(1, vim.fn.filereadable(target .. ".lock"), "unsent edit keeps its acquisition baseline")
        assert.is_truthy(vim.fn.readfile(destination .. "/spec.side/child.md")[2]:find("../spec.md", 1, true))
    end)

    it("records a later save against synchronized references while metadata is delayed", function()
        s3_parent()
        vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS, vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY = "rename", "0.8"
        local target = destination .. "/spec.md"
        local called, handled, moved, err = pcall(document.move_path, file, target)
        assert.is_true(called, tostring(handled)); assert.is_true(handled); assert.equals(target, moved, tostring(err))
        assert.truthy(vim.api.nvim_buf_get_lines(buf, 7, 8, false)[1]:find("spec.side", 1, true))
        vim.api.nvim_buf_set_lines(buf, 6, 7, false, { "saved during confirmation" })
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
        await(function() return document.identity(buf).File == target and not document.status(buf).operation end)
        assert.equals("saved during confirmation", vim.fn.readfile(target)[7])
        assert.equals(1, vim.fn.filereadable(target .. ".lock"))
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    it("aborts ambiguous native parent syntax before any filesystem move or write", function()
        s3_parent()
        vim.api.nvim_buf_set_lines(buf, 2, 4, false, { "discussions: *ambiguous" })
        local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local target = destination .. "/spec.md"
        local ok = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("saveas " .. vim.fn.fnameescape(target)) end)
        assert.is_false(ok)
        assert.equals(file, uv.fs_realpath(vim.api.nvim_buf_get_name(buf)))
        assert.same(before, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.is_true(vim.bo[buf].modified)
        assert.equals(0, vim.fn.filereadable(target))
        assert.equals(1, vim.fn.isdirectory(source .. "/ordinary.side"))
        assert.equals(0, vim.fn.filereadable(target .. ".lock"))
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    for _, door in ipairs({ "move_chat", "move_chat_tree" }) do
        for _, held in ipairs({false, true}) do
            it(door .. " preserves registered ID, side links and held=" .. tostring(held), function()
                seed_side()
                if held then
                    vim.api.nvim_buf_set_lines(buf,4,5,false,{"unsent edit"})
                    assert.equals(1, vim.fn.filereadable(file .. ".lock"))
                end
                local moved, err = p[door](file, destination)
                local new_path = destination .. "/ordinary.md"
                assert.equals(new_path, moved, tostring(err))
                await(function()
                    local identity = document.identity(buf)
                    return identity and identity.File == new_path and document.status(buf).phase == "registered"
                end)
                assert.equals(registration.ID, document.identity(buf).ID)
                assert.equals(0, vim.fn.filereadable(file), "owned move removes OLD, unlike native saveas")
                assert.equals(1, vim.fn.filereadable(new_path))
                assert.equals(new_path, uv.fs_realpath(vim.api.nvim_buf_get_name(buf)))
                assert.equals(0, vim.fn.isdirectory(source .. "/ordinary.side"))
                assert.same({ "---", "parent: '../ordinary.md'", "---", "[up](../ordinary.md#question)", "unrelated bytes" },
                    vim.fn.readfile(destination .. "/ordinary.side/child.md"))
                assert.equals(0, vim.fn.filereadable(file .. ".lock"))
                assert.equals(held and 1 or 0, vim.fn.filereadable(new_path .. ".lock"))
                assert.equals("absent", lookup(file).kind)
                local confirmed = lookup(new_path)
                assert.equals("registered", confirmed.kind)
                assert.equals(registration.ID, confirmed.registration.ID)
                assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
                if held then assert.equals("unsent edit", vim.fn.readfile(new_path)[5]) end
            end)
        end
    end

    for _, door in ipairs({ "move_chat", "move_chat_tree" }) do
        it(door .. " preserves the successful submit receipt through its controller rebuild", function()
            assert.is_true(document.submit(buf))
            await(function()
                local status = document.status(buf)
                return not status.operation and vim.fn.filereadable(root .. "/sent.last") == 1
            end)
            assert.equals(1, #vim.fn.readfile(root .. "/sent"))
            local moved, err = p[door](file, destination)
            assert.equals(destination .. "/ordinary.md", moved, tostring(err))
            -- #359: the move returns once the file moved; Couch confirms after.
            await(function()
                local identity = document.identity(buf)
                return identity and identity.File == moved and not document.status(buf).operation
            end)
            assert.is_true(document.submit(buf))
            await(function() return not document.status(buf).operation end)
            local bar = vim.wo[vim.fn.bufwinid(buf)].winbar
            assert.truthy(bar:find("nothing to submit: no changes since %d%d:%d%d"), bar)
            assert.equals(1, #vim.fn.readfile(root .. "/sent"))
            vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "first edit after acknowledged move" })
            assert.equals(1, vim.fn.filereadable(moved .. ".lock"), "native edit observer must survive acknowledgement")
            vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
            assert.equals("first edit after acknowledged move", vim.fn.readfile(moved)[5])
        end)
    end

    it("keeps an edit made during native name handoff and leaves forward recovery pending", function()
        local set_name = vim.api.nvim_buf_set_name
        local new = destination .. "/ordinary.md"
        vim.api.nvim_buf_set_name = function(target, path)
            set_name(target, path)
            if target == buf and path == new then
                vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "operator edit during handoff" })
            end
        end
        local ok, moved, err = pcall(p.move_chat, file, destination)
        vim.api.nvim_buf_set_name = set_name
        assert.is_true(ok, tostring(moved))
        assert.is_nil(moved)
        assert.truthy(err)
        assert.equals("operator edit during handoff", vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1])
        assert.is_true(vim.bo[buf].modified)
        assert.equals("original", vim.fn.readfile(new)[5], "non-bang acknowledgement never overwrites NEW")
        assert.equals(1, vim.fn.filereadable(new .. ".lock"))
        assert.is_not.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)

    -- #359 close review: a tree asks about every unknown document before it
    -- refuses, so one rerun moves the whole tree.
    it("asks about every unknown document of a tree before refusing, so one rerun moves it", function()
        local chat = source .. "/2026-09-10.14-20-03.112.md"
        local children = { source .. "/notes-one.md", source .. "/notes-two.md" }
        vim.fn.writefile({ "---", "topic: Tree", "file: 2026-09-10.14-20-03.112.md", "model: test-model",
            "provider: openai", "---", "", "💬: Hello", "",
            "🌿: " .. children[1] .. ": one", "🌿: " .. children[2] .. ": two" }, chat)
        for _, child in ipairs(children) do
            vim.fn.writefile({ "---", "topic: Child", "---", "", "💬: Hi" }, child)
        end
        local couch = require("parley.couch")
        local production_run, looked = couch.run, {}
        couch.run = function(argv, callback, options)
            if argv[2] == "--session-sync" and argv[3] == "lookup" then looked[argv[4]] = true end
            return production_run(argv, callback, options)
        end
        local moved, err = p.move_chat_tree(chat, destination)
        assert.is_nil(moved)
        assert.equals("move not confirmed: Couch hasn't confirmed this document yet; nothing moved. Run the move again", err)
        assert.equals(1, vim.fn.filereadable(chat))
        assert.is_true(looked[children[1]] and looked[children[2]], vim.inspect(looked))
        await(function()
            return document.move_membership(children[1]) == false and document.move_membership(children[2]) == false
        end)
        couch.run = production_run
        moved, err = p.move_chat_tree(chat, destination)
        assert.equals(destination .. "/2026-09-10.14-20-03.112.md", moved, tostring(err))
        assert.equals(1, vim.fn.filereadable(destination .. "/notes-one.md"))
        assert.equals(1, vim.fn.filereadable(destination .. "/notes-two.md"))
    end)

    -- #359 close review: a background "absent" is an answer for the rerun, not
    -- a standing permission. Past its expiry the file is unknown again, so a
    -- registration made since is asked about instead of moved past.
    it("lets a background absent answer expire, then asks again", function()
        local other = source .. "/notes-unloaded.md"
        vim.fn.writefile({ "---", "topic: Note", "---", "", "body" }, other)
        local ttl = document.ANSWER_TTL_MS
        document.ANSWER_TTL_MS = 200
        local member, err = document.move_membership(other)
        assert.is_nil(member)
        assert.truthy(tostring(err):find("hasn't confirmed this document yet", 1, true))
        await(function() return document.move_membership(other) == false end)
        vim.wait(300)
        member, err = document.move_membership(other)
        document.ANSWER_TTL_MS = ttl
        assert.is_nil(member, "an expired absence must not authorize a plain move")
        assert.truthy(tostring(err):find("hasn't confirmed this document yet", 1, true))
    end)

    it("moves an unloaded registered ordinary file through the public tree door", function()
        seed_side()
        -- #372: Couch publishes the rename before its reply reaches the editor,
        -- so the registry can say "registered at NEW" while the buffer still
        -- holds the old identity, with the rename operation in flight. The
        -- reply is held back here so the case always crosses that window,
        -- instead of reading the buffer whenever the race left it.
        vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY, vim.env.FAKE_COUCH_REGISTRY_REPLY_DELAY_OPS = "0.5", "rename"
        document.detach(buf)
        vim.api.nvim_buf_delete(buf, {force=true})
        local moved, err = p.move_chat_tree(file, destination)
        local new_path = destination .. "/ordinary.md"
        assert.equals(new_path, moved, tostring(err))
        assert.equals(0, vim.fn.filereadable(file))
        assert.equals(1, vim.fn.filereadable(destination .. "/ordinary.side/child.md"))
        -- #359: Couch's rename lands after the move returns. The editor's own
        -- confirmation is the buffer adopting NEW from the rename reply; the
        -- registry is a separate process and leads it by that reply (#372).
        local reopened = vim.fn.bufnr(new_path)
        assert.is_true(reopened > 0)
        await(function()
            local identity = document.identity(reopened)
            return identity ~= nil and identity.File == new_path
        end)
        assert.equals(registration.ID, document.identity(reopened).ID)
        local confirmed = lookup(new_path)
        assert.equals("registered", confirmed.kind)
        assert.equals(registration.ID, confirmed.registration.ID)
    end)

    -- #359: the identity is held, so the move needs no Couch round trip and
    -- lands even while Couch is down; the journal carries the rename (row 7),
    -- editing stays available, and reopening recovers it once Couch is back.
    it("moves on a held identity while Couch is unavailable; the journal carries the rename to a reopen", function()
        seed_side()
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local moved, err = p.move_chat(file, destination)
        local new_path = destination .. "/ordinary.md"
        assert.equals(new_path, moved, tostring(err))
        assert.equals(0, vim.fn.filereadable(file))
        assert.equals(1, vim.fn.filereadable(destination .. "/ordinary.side/child.md"))
        await(function()
            return vim.wo[vim.fn.bufwinid(buf)].winbar:find("move interrupted: reopen to finish", 1, true) ~= nil
        end)
        assert.is_true(vim.bo[buf].modifiable)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "editable while Couch unavailable" })
        assert.is_true(vim.bo[buf].modified)
        assert.is_not.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
        document.detach(buf)
        assert.is_true(document.attach(buf))
        await(function()
            local identity = document.identity(buf)
            return identity and identity.File == new_path and not document.status(buf).operation
        end)
        assert.equals("registered", lookup(new_path).kind)
    end)

    it("adopts unregistered typed OLD and its legacy owed ledger before a public move", function()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf, {force=true})
        file = source .. "/legacy.md"
        vim.fn.writefile({"---","type: session-sync","owner: ops:0","---","typed body"},file)
        local ledger = { Owed={{ ID="legacy-owed",Kind="delivery",At="2026-10-15T00:00:00Z" }},
            LastWrite="2026-10-15T01:00:00Z" }
        vim.env.FAKE_COUCH_STATUS = vim.json.encode({Code="ok",Status=ledger})
        local seed = vim.system({"couch","--session-sync","status",file,"--json"},{text=true}):wait(2000)
        assert.equals(0, seed.code)
        vim.env.FAKE_COUCH_STATUS = nil
        assert.equals("absent",lookup(file).kind)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
        await(function() return document.status(buf).phase == "plain" end)
        assert.is_true(require("parley.session_sync").is_session_sync(buf))
        -- #359: the move refuses at once while it registers in the background.
        local refused, refusal = p.move_chat(file,destination)
        assert.is_nil(refused)
        assert.equals("move not confirmed: registering this document first; nothing moved. Run the move again", refusal)
        assert.equals(1, vim.fn.filereadable(file))
        await(function() return document.move_membership(file) == true end)
        local moved, err = p.move_chat(file,destination)
        local new_path = destination .. "/legacy.md"
        assert.equals(new_path,moved,tostring(err))
        assert.equals(0,vim.fn.filereadable(file))
        local confirmed
        await(function() confirmed = lookup(new_path); return confirmed.kind == "registered" end)
        await(function() return not document.status(buf).operation end)
        assert.equals(confirmed.registration.ID,document.identity(buf).ID)
        assert.equals("ops:0",confirmed.registration.Owner)
        local restored = vim.system({"couch","--session-sync","status",new_path,"--json"},{text=true}):wait(2000)
        assert.equals(0,restored.code)
        assert.same(ledger,vim.json.decode(restored.stdout).Status)
    end)

    it("refuses an occupied destination before touching OLD, locks or side folders", function()
        seed_side()
        local target = destination .. "/ordinary.md"
        local target_side = destination .. "/ordinary.side"
        vim.fn.writefile({"destination belongs to someone else"},target)
        vim.fn.mkdir(target_side,"p")
        vim.fn.writefile({"destination child"},target_side .. "/child.md")
        vim.api.nvim_buf_set_lines(buf,4,5,false,{"held operator text"})
        local old_disk = vim.fn.readfile(file)
        local old_lock = vim.fn.readfile(file .. ".lock")
        local old_child = vim.fn.readfile(source .. "/ordinary.side/child.md")
        local moved, err = p.move_chat_tree(file,destination)
        assert.is_nil(moved)
        assert.is_true(type(err) == "string" and err ~= "")
        assert.same(old_disk,vim.fn.readfile(file))
        assert.same(old_lock,vim.fn.readfile(file .. ".lock"))
        assert.same(old_child,vim.fn.readfile(source .. "/ordinary.side/child.md"))
        assert.same({"destination belongs to someone else"},vim.fn.readfile(target))
        assert.same({"destination child"},vim.fn.readfile(target_side .. "/child.md"))
        assert.equals(file,document.identity(buf).File)
        assert.equals(1,vim.fn.filereadable(file .. ".lock"))
    end)


    it("registers the actual legacy buffer path after Neovim canonicalizes an alias", function()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf,{force=true})
        local alias_dir = root .. "/caller-alias"
        assert(uv.fs_symlink(source,alias_dir))
        local canonical_old = source .. "/alias-legacy.md"
        local lexical_old = alias_dir .. "/alias-legacy.md"
        vim.fn.writefile({"---","type: session-sync","owner: ops:0","---","legacy alias body"},canonical_old)
        -- Record the production register argv at the executable boundary, then
        -- transparently delegate all commands to the existing persisted fake.
        local executable, delegate = root .. "/bin/couch", root .. "/bin/couch-delegate"
        local registration_argv = root .. "/register-caller"
        assert(uv.fs_rename(executable,delegate))
        vim.fn.writefile({
            "#!/bin/sh",
            'if [ "$1" = "--session-sync" ] && [ "$2" = "register" ]; then',
            '  printf "%s\\n" "$3" > ' .. vim.fn.shellescape(registration_argv),
            'fi',
            'exec ' .. vim.fn.shellescape(delegate) .. ' "$@"',
        },executable)
        assert(uv.fs_chmod(executable,493))
        vim.cmd("edit " .. vim.fn.fnameescape(lexical_old))
        buf = vim.api.nvim_get_current_buf()
        -- Neovim resolves directory aliases both on edit and set_name; the
        -- adoption contract uses this observable caller path, not the typed
        -- command's spelling that no longer exists in editor state.
        vim.api.nvim_buf_set_name(buf,lexical_old)
        local actual_caller = vim.api.nvim_buf_get_name(buf)
        assert.equals(canonical_old,actual_caller)
        p.setup_markdown_keymaps(buf)
        await(function() return document.status(buf).phase == "plain" end)
        assert.equals("absent",lookup(canonical_old).kind)
        local new_path = destination .. "/alias-legacy.md"
        -- #359: the rename refuses at once while the legacy file registers in
        -- the background (row 4); the rerun renames the registered document.
        local ok, err = pcall(vim.cmd, "saveas " .. vim.fn.fnameescape(new_path))
        assert.is_false(ok)
        assert.truthy(tostring(err):find("registering this document first; nothing moved", 1, true), tostring(err))
        await(function() return document.identity(buf) ~= nil end)
        assert.same({actual_caller},vim.fn.readfile(registration_argv), "legacy state adoption must receive the actual pre-move buffer path")
        vim.cmd("saveas " .. vim.fn.fnameescape(new_path))
        await(function() local identity = document.identity(buf); return identity and identity.File == new_path end)
        local confirmed = lookup(new_path)
        assert.equals("registered",confirmed.kind)
        assert.equals(uv.fs_realpath(new_path),confirmed.registration.File)
        assert.equals(confirmed.registration.ID,document.identity(buf).ID)
    end)


    it("preserves registration for a dated ordinary note without chat metadata", function()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf,{force=true})
        file = source .. "/2026-10-15-question.md"
        vim.fn.writefile({"---","title: ordinary dated question","---","# Question","ordinary body"},file)
        local admitted
        require("parley.document_registry").request("register",{file,"ops:0"},{},function(value) admitted=value end)
        await(function() return admitted ~= nil end)
        assert.equals("registered",admitted.kind)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
        await(function() return document.identity(buf) ~= nil and document.status(buf).phase == "registered" end)
        assert.is_true(require("parley.chat_parser").is_chat_filename(vim.fs.basename(file)))
        assert.is_not_nil(p.not_chat(buf,file),"dated fixture must remain ordinary Markdown")
        local moved, err = p.move_chat(file,destination)
        local new_path = destination .. "/2026-10-15-question.md"
        assert.equals(new_path,moved,tostring(err))
        await(function() local identity=document.identity(buf); return identity and identity.File == new_path end)
        local confirmed=lookup(new_path)
        assert.equals("registered",confirmed.kind)
        assert.equals(admitted.registration.ID,confirmed.registration.ID)
        assert.equals(admitted.registration.ID,document.identity(buf).ID)
        assert.equals(0,vim.fn.filereadable(file))
    end)

    it("keeps a valid timestamp chat on its existing mover when the registry is unavailable", function()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf,{force=true})
        file=source .. "/2026-10-15-chat.md"
        vim.fn.writefile({"---","topic: Chat move","file: 2026-10-15-chat.md","model: test-model", "provider: openai", "---", "", "💬: chat content"},file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf=vim.api.nvim_get_current_buf()
        assert.is_nil(p.not_chat(buf,file),"fixture must pass the actual shared chat classifier")
        vim.env.FAKE_COUCH_REGISTRY_MODE="unsupported"
        local moved,err=p.move_chat(file,destination)
        local new_path=destination .. "/2026-10-15-chat.md"
        assert.equals(new_path,moved,tostring(err))
        assert.equals(0,vim.fn.filereadable(file))
        assert.equals(1,vim.fn.filereadable(new_path))
        assert.equals(new_path,vim.api.nvim_buf_get_name(buf))
        assert.is_nil(document.identity(buf))
        assert.is_nil(p.not_chat(buf,new_path))
    end)

end)
