local primary_dir = vim.fn.tempname() .. "-parley-chat-move-primary"
local secondary_dir = vim.fn.tempname() .. "-parley-chat-move-secondary"
vim.fn.mkdir(primary_dir, "p")
vim.fn.mkdir(secondary_dir, "p")
vim.g.parley_test_mode = true

local parley = require("parley")
parley.setup({
    chat_dir = primary_dir,
    chat_dirs = { secondary_dir },
    state_dir = primary_dir .. "/state",
    providers = {},
    api_keys = {},
})

local function create_chat(filename)
    local path = primary_dir .. "/" .. filename
    local lines = {
        "---",
        "topic: Move Test",
        "file: " .. filename,
        "model: test-model",
        "provider: openai",
        "---",
        "",
        "💬: Hello",
    }
    vim.fn.writefile(lines, path)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(buf)
    return buf, path
end

local function cleanup()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:match(vim.pesc(primary_dir)) or name:match(vim.pesc(secondary_dir)) then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end
    vim.fn.delete(primary_dir, "rf")
    vim.fn.delete(secondary_dir, "rf")
    vim.fn.mkdir(primary_dir, "p")
    vim.fn.mkdir(secondary_dir, "p")
    -- The movers refresh persisted state; the state dir lives under primary_dir.
    vim.fn.mkdir(primary_dir .. "/state", "p")
end

describe("chat move", function()
    after_each(cleanup)

    it("moves the current chat to another registered chat directory", function()
        local buf, old_path = create_chat("2026-03-11-move-test.md")

        parley.cmd.ChatMove({ args = secondary_dir })

        local new_path = secondary_dir .. "/2026-03-11-move-test.md"
        assert.equals(0, vim.fn.filereadable(old_path))
        assert.equals(1, vim.fn.filereadable(new_path))
        assert.equals(vim.fn.resolve(new_path), vim.fn.resolve(vim.api.nvim_buf_get_name(buf)))
        assert.is_nil(parley.not_chat(buf, new_path))
    end)

    it("rejects moving chats to unregistered directories", function()
        local _, old_path = create_chat("2026-03-11-move-invalid.md")
        local target_dir = primary_dir .. "-other"

        local new_path, err = parley.move_chat(old_path, target_dir)

        assert.is_nil(new_path)
        assert.equals("target is not a registered chat directory: " .. target_dir, err)
        assert.equals(1, vim.fn.filereadable(old_path))
    end)
    -- #231: the assets folder follows the chat through both movers and is
    -- removed by every deleter. The scratch buffer is `nofile`, so the
    -- fixture appends with writefile(…, "a"), never :write.
    local assets = require("parley.assets")
    local chat_finder = require("parley.chat_finder")
    local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
    local PNG = assets.default_io.read(repo .. "/tests/fixtures/one_pixel.png", assets.MAX_BYTES + 1)
    local TS = "2026-09-10.14-20-03.112"
    local CHILD_TS = "2026-09-10.14-25-11.900"
    local REL = "assets/" .. TS .. "/a.png"
    -- The note as a Lua pattern: " and assets/<ts>/ (1 file)".
    local NOTE_PATTERN = " and assets/" .. TS:gsub("[%-%.]", "%%%0") .. "/ %(1 file%)"

    local function seed_assets(dir, ts)
        local folder = assets.folder_in(dir, ts or TS)
        vim.fn.mkdir(folder, "p")
        assert(assets.default_io.write(folder .. "/a.png", PNG))
        return folder
    end

    local function assert_same_path(expected, actual, msg)
        assert.equals(vim.fn.resolve(expected), vim.fn.resolve(actual), msg)
    end

    -- A two-file tree: the root (with the assets folder) branches to a child.
    local function create_tree()
        local _, root_path = create_chat(TS .. "_tree-root.md")
        local _, child_path = create_chat(CHILD_TS .. "_tree-child.md")
        vim.fn.writefile({ "🌿: " .. CHILD_TS .. "_tree-child.md: child" }, root_path, "a")
        vim.fn.writefile({ "![](" .. REL .. ")" }, root_path, "a")
        seed_assets(primary_dir)
        return root_path, child_path
    end

    it("ChatMove carries the tree's assets folder and the link still resolves", function()
        local _, old_path = create_chat(TS .. "_move-assets.md")
        vim.fn.writefile({ "![](" .. REL .. ")" }, old_path, "a")
        seed_assets(primary_dir)

        parley.cmd.ChatMove({ args = secondary_dir })

        local new_path = secondary_dir .. "/" .. TS .. "_move-assets.md"
        assert.equals(1, vim.fn.filereadable(new_path))
        assert.equals(0, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)), "folder left behind")
        assert.equals(PNG, assets.read_bounded(new_path, REL))
    end)

    it("the single-file mover carries the folder too", function()
        local _, old_path = create_chat(TS .. "_single.md")
        seed_assets(primary_dir)

        local new_path, err = parley.move_chat(old_path, secondary_dir)

        assert.is_not_nil(new_path, err)
        assert_same_path(secondary_dir .. "/" .. TS .. "_single.md", new_path)
        assert.equals(0, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)), "folder left behind")
        assert.equals(PNG, assets.read_bounded(new_path, REL))
    end)

    it("a tree move refuses when the target already has that assets folder, before moving anything", function()
        local root_path, child_path = create_tree()
        vim.fn.mkdir(assets.folder_in(secondary_dir, TS), "p")

        local new_path, err = parley.move_chat_tree(root_path, secondary_dir)

        assert.is_nil(new_path)
        assert.matches("asset folder already exists", err)
        assert.equals(1, vim.fn.filereadable(root_path), "root moved")
        assert.equals(1, vim.fn.filereadable(child_path), "child moved")
        assert.equals(1, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)), "folder moved")
    end)

    it("a failed folder move is reported after the .md moved and the 🌿 line was rewritten", function()
        local root_path = create_tree()
        -- A plain file where `assets/` must be created makes the mkdir fail.
        vim.fn.writefile({ "not a directory" }, secondary_dir .. "/assets")

        local new_path, err = parley.move_chat_tree(root_path, secondary_dir)

        assert.is_nil(new_path)
        assert.matches("moved the tree but not every assets folder", err)
        local moved_root = secondary_dir .. "/" .. TS .. "_tree-root.md"
        assert.equals(0, vim.fn.filereadable(root_path), "root still at the source")
        assert.equals(1, vim.fn.filereadable(moved_root), "root not moved")
        assert.equals(1, vim.fn.filereadable(secondary_dir .. "/" .. CHILD_TS .. "_tree-child.md"), "child not moved")
        local branch_line
        for _, line in ipairs(vim.fn.readfile(moved_root)) do
            if line:sub(1, #"🌿:") == "🌿:" then
                branch_line = line
            end
        end
        assert.equals("🌿: " .. CHILD_TS .. "_tree-child.md: child", branch_line)
        -- The 🌿 pass ran after the move: the moved root still spans the tree.
        local tree = vim.tbl_map(vim.fn.resolve, parley.get_chat_tree_files(moved_root))
        table.sort(tree)
        assert.same({
            vim.fn.resolve(moved_root),
            vim.fn.resolve(secondary_dir .. "/" .. CHILD_TS .. "_tree-child.md"),
        }, tree)
        assert.equals(1, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)), "stranded folder must stay put")
    end)

    it("deleting a tree removes its assets folders", function()
        local buf = create_chat(TS .. "_del.md")
        seed_assets(primary_dir)
        local confirm = vim.fn.confirm
        vim.fn.confirm = function() return 1 end
        local ok, err = pcall(parley.delete_chat_tree, buf)
        vim.fn.confirm = confirm
        assert.is_true(ok, err)
        assert.equals(0, vim.fn.filereadable(primary_dir .. "/" .. TS .. "_del.md"))
        assert.equals(0, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)))
    end)

    it(":ParleyChatDelete names the folder in its prompt and removes it with the file", function()
        local _, path = create_chat(TS .. "_cmd-del.md")
        seed_assets(primary_dir)
        local saved_confirm, saved_input = parley.config.chat_confirm_delete, vim.ui.input
        parley.config.chat_confirm_delete = true
        local prompt
        vim.ui.input = function(opts, on_done)
            prompt = opts.prompt
            on_done("y")
        end
        local ok, err = pcall(parley.cmd.ChatDelete)
        parley.config.chat_confirm_delete, vim.ui.input = saved_confirm, saved_input
        assert.is_true(ok, err)
        assert.matches(NOTE_PATTERN, prompt)
        assert.equals(0, vim.fn.filereadable(path))
        assert.equals(0, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)))
    end)

    it("the finder's tree delete removes the folder", function()
        local _, path = create_chat(TS .. "_finder-del.md")
        seed_assets(primary_dir)
        -- The handler ends by re-opening the finder on a timer
        -- (_reopen_chat_finder → vim.defer_fn); stub it as
        -- tests/unit/chat_finder_logic_spec.lua does so nothing outlives this case.
        local saved_reopen = parley._reopen_chat_finder
        parley._reopen_chat_finder = function() end
        local ok, err = pcall(chat_finder.handle_delete_tree_response, "y", path, { path }, 1, 1, nil, nil, nil)
        parley._reopen_chat_finder = saved_reopen
        assert.is_true(ok, err)
        assert.equals(0, vim.fn.filereadable(path))
        assert.equals(0, vim.fn.isdirectory(assets.folder_in(primary_dir, TS)))
    end)

    it("a folder that cannot be removed is notified and the chat file is still deleted", function()
        local _, path = create_chat(TS .. "_stuck.md")
        local folder = seed_assets(primary_dir)
        local saved_remove, saved_notify = assets.default_io.remove_tree, vim.notify
        local notices = {}
        assets.default_io.remove_tree = function() return nil, "EPERM" end
        vim.notify = function(msg, level) notices[#notices + 1] = { msg = msg, level = level } end
        local ok, err = pcall(parley.delete_chat_file, path)
        assets.default_io.remove_tree, vim.notify = saved_remove, saved_notify
        assert.is_true(ok, err)
        assert.equals(0, vim.fn.filereadable(path), "the .md must still be deleted")
        assert.equals(1, vim.fn.isdirectory(folder), "the folder stays for the next delete")
        assert.equals(1, #notices, vim.inspect(notices))
        assert.equals(vim.log.levels.WARN, notices[1].level)
        assert.matches(vim.pesc(folder), notices[1].msg)
        assert.matches("EPERM", notices[1].msg)
    end)
end)
