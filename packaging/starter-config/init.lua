-- Copy this file to ~/.config/parley/init.lua and launch NVIM_APPNAME=parley nvim.
-- Edit this profile freely; ordinary Neovim configuration remains independent.
local extra_plugins = ... or {} -- Optional specs supplied by the checkout demo.
if vim.env.NVIM_APPNAME ~= "parley" then
    error("Parley starter requires NVIM_APPNAME=parley before startup")
end
if vim.env.PARLEY_RUNTIME and vim.env.PARLEY_RUNTIME ~= "" then
    vim.opt.runtimepath:prepend(vim.env.PARLEY_RUNTIME)
end

vim.g.mapleader = " "
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.showbreak = "↪ "
vim.opt.clipboard = "unnamedplus"
for lhs, rhs in pairs({ j = "gj", k = "gk", ["<Down>"] = "gj", ["<Up>"] = "gk" }) do
    vim.keymap.set({ "n", "x" }, lhs, function()
        return vim.v.count == 0 and rhs or lhs
    end, { expr = true, silent = true })
end

local uv = vim.uv or vim.loop
local deadline = uv.hrtime() + 300 * 1e9
local function remaining()
    return math.max(0, math.floor((deadline - uv.hrtime()) / 1e6))
end
local data = vim.fn.stdpath("data")
local lock = data .. "/initializer.lock"
local owned = false
local function cleanup()
    if owned then
        vim.fn.delete(lock, "rf")
        owned = false
    end
end
local function repair()
    error("Parley bootstrap lock requires repair: " .. lock
        .. "; close all Parley instances, remove that initializer directory and retry")
end
vim.fn.mkdir(data, "p", 448)
while not uv.fs_mkdir(lock, 448) do
    if not uv.fs_stat(lock) then
        error("Parley bootstrap cannot create initializer lock: " .. lock)
    end
    local fd = io.open(lock .. "/owner", "r")
    local owner = fd and fd:read(32)
    if fd then fd:close() end
    local pid = owner and tonumber(owner:match("^(%d+)%s*$"))
    if not pid or pid < 1 or not uv.kill(pid, 0) then repair() end
    if remaining() == 0 then
        error("Parley bootstrap initializer still active: " .. lock)
    end
    vim.wait(math.min(100, remaining()))
end
owned = true
vim.api.nvim_create_autocmd("VimLeavePre", { once = true, callback = cleanup })
local timer = uv.new_timer()
timer:start(remaining(), 0, vim.schedule_wrap(function()
    cleanup()
    vim.api.nvim_err_writeln("Parley bootstrap exceeded five minutes; retry startup")
    vim.cmd("cquit")
end))
local ok, err = xpcall(function()
    local fd = assert(io.open(lock .. "/owner", "w"))
    fd:write(tostring(uv.os_getpid()), "\n")
    fd:close()
    local lazy = data .. "/lazy/lazy.nvim"
    local function git(args)
        local timeout = math.min(120000, remaining())
        if timeout == 0 then error("Parley bootstrap startup deadline exceeded") end
        local result = vim.system(vim.list_extend({ "git" }, args), { text = true })
            :wait(timeout)
        if result.code ~= 0 then
            error("Parley bootstrap git failed: " .. (result.stderr or "timeout"))
        end
        return result.stdout or ""
    end
    -- Check this starter's bootstrap module closure before publishing a release
    -- or loading from a user-owned cache. Lazy cannot repair an earlier failure.
    local function check_runtime(path, description, recovery)
        local missing = {}
        for _, name in ipairs({ "theme", "editor_dependencies", "editor_bundle" }) do
            local file = "lua/parley/" .. name .. ".lua"
            if vim.fn.filereadable(path .. "/" .. file) ~= 1 then missing[#missing + 1] = file end
        end
        assert(#missing == 0, "Parley bootstrap " .. description .. " is incompatible with this starter: "
            .. path .. "; missing required module(s): " .. table.concat(missing, ", ")
            .. ". " .. recovery .. ". Lazy is not loaded")
    end
    local runtime = vim.env.PARLEY_RUNTIME
    if not runtime or runtime == "" then
        runtime = data .. "/lazy/parley.nvim"
        if not uv.fs_stat(runtime) then
            local staging = lock .. "/parley-staging"
            git({ "clone", "--filter=blob:none", "--no-checkout",
                "https://github.com/xianxu/parley.nvim.git", staging })
            local tags = git({ "-C", staging, "tag", "--sort=-version:refname", "--list", "v*" })
            local release
            for tag in tags:gmatch("[^\r\n]+") do
                if tag:match("^v%d+%.%d+%.%d+$") then release = tag; break end
            end
            assert(release, "Parley bootstrap found no stable release")
            git({ "-C", staging, "checkout", "--detach", release })
            check_runtime(staging, "release " .. release,
                "Use init.lua from a matching published release, or set PARLEY_RUNTIME to a checkout matching this init.lua")
            vim.fn.mkdir(data .. "/lazy", "p", 448)
            assert(uv.fs_rename(staging, runtime))
        else
            check_runtime(runtime, "cached Parley release",
                "Set PARLEY_RUNTIME to a checkout matching this init.lua, or use Git from a terminal to inspect and "
                .. "preserve local changes, fetch tags, and check out the release matching this init.lua")
        end
        vim.opt.runtimepath:prepend(runtime)
    end
    local dependencies = require("parley.editor_dependencies")
    local pin = dependencies.plugin("lazy.nvim").commit
    local bundle = require("parley.editor_bundle").select()
    if bundle then lazy = bundle.lazy end
    local theme = require("parley.theme")
    if not uv.fs_stat(lazy) then
        local staging = lock .. "/staging"
        git({ "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/folke/lazy.nvim.git", staging })
        git({ "-C", staging, "checkout", "--detach", pin })
        if not uv.fs_stat(staging .. "/lua/lazy/init.lua") then
            error("Parley bootstrap checkout is incomplete: " .. staging)
        end
        vim.fn.mkdir(data .. "/lazy", "p", 448)
        assert(uv.fs_rename(staging, lazy))
    elseif not uv.fs_stat(lazy .. "/lua/lazy/init.lua") then
        error("Parley bootstrap installed checkout is incomplete: " .. lazy
            .. "; remove that directory and retry")
    end
    vim.opt.rtp:prepend(lazy)
    local parley = { "xianxu/parley.nvim", version = "*", lazy = false }
    if vim.env.PARLEY_RUNTIME and vim.env.PARLEY_RUNTIME ~= "" then
        parley = { dir = vim.env.PARLEY_RUNTIME, name = "parley.nvim", lazy = false }
    end
    local main_window = vim.api.nvim_get_current_win()
    local theme_plugins = theme.packaged_plugins()
    theme_plugins[1].config = function() vim.cmd.colorscheme("nordfox") end
    for i, plugin in ipairs(theme_plugins) do
        plugin.lazy = false
        plugin.priority = i == 1 and 1000 or 999
    end
    local additional_plugins = {
        { "nvim-lualine/lualine.nvim", commit = dependencies.plugin("lualine.nvim").commit,
            lazy = false,
            opts = {
                options = { theme = "auto", icons_enabled = false, globalstatus = true,
                    component_separators = "", section_separators = "" },
                sections = { lualine_a = { "mode" }, lualine_b = {},
                    lualine_c = { { "filename", path = 0 } },
                    lualine_x = {}, lualine_y = {}, lualine_z = { "location" } },
                inactive_sections = { lualine_a = {}, lualine_b = {}, lualine_c = {},
                    lualine_x = {}, lualine_y = {}, lualine_z = {} },
            } },
        { "nvim-lua/plenary.nvim", commit = dependencies.plugin("plenary.nvim").commit },
        -- `keys` would make Lazy defer loading; keep :Telescope available at startup.
        { "nvim-telescope/telescope.nvim", commit = dependencies.plugin("telescope.nvim").commit,
            lazy = false,
            keys = { { "<C-g>:", function() require("telescope.builtin").command_history() end,
                desc = "Search command history" } } },
        -- Fuzzy command-line and current-buffer word completion.
        -- Keep Enter available for Parley submission and ordinary newlines.
        { "saghen/blink.cmp", commit = dependencies.plugin("blink.cmp").commit, -- v1.10.2
            lazy = false,
            opts = {
                fuzzy = { implementation = "lua" },
                sources = {
                    default = { "buffer" },
                    providers = { buffer = {
                        min_keyword_length = 2,
                        opts = { get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end },
                    } },
                },
                completion = { list = { selection = { preselect = false, auto_insert = false } } },
                keymap = {
                    preset = "none",
                    ["<Tab>"] = { "select_next", "fallback" },
                    ["<Down>"] = { "select_next", "fallback" },
                    ["<Up>"] = { "select_prev", "fallback" },
                    ["<CR>"] = { "select_and_accept", "fallback" },
                    ["<Esc>"] = { "hide", "fallback" },
                    ["<C-n>"] = { "select_next", "fallback" },
                    ["<C-p>"] = { "select_prev", "fallback" },
                    ["<C-y>"] = { "accept", "fallback" },
                    ["<C-e>"] = { "hide", "fallback" },
                },
                cmdline = {
                    -- The preset would bind the arrows to menu selection; keep cursor movement.
                    keymap = { preset = "cmdline", ["<Left>"] = {}, ["<Right>"] = {} },
                    completion = { menu = { auto_show = true } },
                },
            } },
        { "iamcco/markdown-preview.nvim",
            commit = dependencies.plugin("markdown-preview.nvim").commit,
            cmd = { "MarkdownPreview", "MarkdownPreviewToggle", "MarkdownPreviewStop" },
            ft = { "markdown" },
            init = function()
                vim.g.mkdp_auto_start = 0
                vim.g.mkdp_open_to_the_world = 0
            end,
            build = function(plugin)
                local info = vim.json.decode(table.concat(vim.fn.readfile(plugin.dir .. "/package.json"), "\n"))
                local result = vim.system({ "bash", plugin.dir .. "/app/install.sh", "v" .. info.version },
                    { cwd = plugin.dir .. "/app", text = true }):wait(120000)
                assert(result.code == 0, "MarkdownPreview install failed: " .. (result.stderr or "timeout"))
                -- Lazy runs function builders before loading plugin autoload files.
                local host = (vim.uv or vim.loop).os_uname()
                local platform = host.sysname == "Darwin"
                    and (host.machine == "arm64" and "macos-arm64" or "macos") or "linux"
                local server = plugin.dir .. "/app/bin/markdown-preview-" .. platform
                assert(vim.fn.executable(server) == 1,
                    "MarkdownPreview server was not installed; retry with :Lazy build markdown-preview.nvim")
                local installed = vim.system({ server, "--version" }, { text = true }):wait(5000)
                assert(installed.code == 0 and vim.trim(installed.stdout or "") == info.version,
                    "MarkdownPreview server verification failed; retry with :Lazy build markdown-preview.nvim")
            end },
        parley,
    }
    for _, plugin in ipairs(additional_plugins) do theme_plugins[#theme_plugins + 1] = plugin end
    vim.list_extend(theme_plugins, extra_plugins)
    if bundle then theme_plugins = bundle:specs(theme_plugins) end
    require("lazy").setup(theme_plugins, {
        -- Neovim 0.11 encodes full source paths into cache filenames. Long
        -- manifest-addressed local paths can exceed the filesystem name limit.
        performance = { cache = { enabled = not bundle } },
        install = { missing = not bundle },
        pkg = { enabled = not bundle },
        rocks = { enabled = not bundle },
        local_spec = not bundle,
        root = data .. "/lazy",
        lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json",
        checker = { enabled = false },
        change_detection = { enabled = false },
        git = { timeout = math.min(120, math.max(1, math.floor(remaining() / 1000))) },
    })
    -- First-install setup leaves Lazy's floating progress window focused.
    -- Its close is scheduled, so restore our window before opening any chat.
    local installer = package.loaded["lazy.view"]
    if installer and installer.visible() then installer.view:close() end
    vim.api.nvim_set_current_win(main_window)
    theme.capture_startup()
    theme.apply(theme.load(data .. "/parley/persisted") or "startup")
    require("parley.starter").start()
end, debug.traceback)
timer:stop()
timer:close()
cleanup()
if not ok then error(err) end
