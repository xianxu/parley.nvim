-- Public Parley move doors also accept ordinary Markdown under a chat root.
-- Exercise those doors, rather than imitating a native saveas event sequence.
describe("registered ordinary Markdown through Parley move doors", function()
    local root, source, destination, file, buf, saved, p, document, registration
    local uv = vim.uv or vim.loop
    local function await(predicate)
        assert.is_true(vim.wait(4000, predicate, 10), "registered document operation did not finish")
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
            "FAKE_COUCH_REGISTRY", "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_EXIT", "FAKE_COUCH_SLEEP", "FAKE_COUCH_STATUS" }) do
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

    it("moves an unloaded registered ordinary file through the public tree door", function()
        seed_side()
        document.detach(buf)
        vim.api.nvim_buf_delete(buf, {force=true})
        local moved, err = p.move_chat_tree(file, destination)
        local new_path = destination .. "/ordinary.md"
        assert.equals(new_path, moved, tostring(err))
        assert.equals(0, vim.fn.filereadable(file))
        assert.equals(1, vim.fn.filereadable(destination .. "/ordinary.side/child.md"))
        local confirmed = lookup(new_path)
        assert.equals("registered", confirmed.kind)
        assert.equals(registration.ID, confirmed.registration.ID)
        local reopened = vim.fn.bufnr(new_path)
        assert.is_true(reopened > 0)
        assert.equals(new_path, document.identity(reopened).File)
        assert.equals(registration.ID, document.identity(reopened).ID)
    end)

    it("refuses unavailable membership before moving OLD or its side folder and leaves editing available", function()
        seed_side()
        local original = vim.fn.readfile(file)
        local child = vim.fn.readfile(source .. "/ordinary.side/child.md")
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local moved, err = p.move_chat(file, destination)
        assert.is_nil(moved)
        assert.is_true(type(err) == "string" and err ~= "")
        assert.same(original, vim.fn.readfile(file))
        assert.same(child, vim.fn.readfile(source .. "/ordinary.side/child.md"))
        assert.equals(0, vim.fn.filereadable(destination .. "/ordinary.md"))
        assert.equals(0, vim.fn.isdirectory(destination .. "/ordinary.side"))
        assert.equals(file, vim.api.nvim_buf_get_name(buf))
        assert.is_true(vim.bo[buf].modifiable)
        vim.api.nvim_buf_set_lines(buf,4,5,false,{"editable while Couch unavailable"})
        assert.is_true(vim.bo[buf].modified)
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
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
        local moved, err = p.move_chat(file,destination)
        local new_path = destination .. "/legacy.md"
        assert.equals(new_path,moved,tostring(err))
        assert.equals(0,vim.fn.filereadable(file))
        local confirmed = lookup(new_path)
        assert.equals("registered",confirmed.kind)
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
        vim.cmd("saveas " .. vim.fn.fnameescape(new_path))
        assert.same({actual_caller},vim.fn.readfile(registration_argv), "legacy state adoption must receive the actual pre-move buffer path")
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
