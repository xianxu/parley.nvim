-- Copy this file to ~/.config/parley/init.lua and launch NVIM_APPNAME=parley nvim.
-- Edit this profile freely; ordinary Neovim configuration remains independent.
if vim.env.NVIM_APPNAME ~= "parley" then
    error("Parley starter requires NVIM_APPNAME=parley before startup")
end

vim.g.mapleader = " "
vim.opt.termguicolors = true
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
    local pin = "85c7ff3711b730b4030d03144f6db6375044ae82" -- Lazy v11.17.5
    local function git(args)
        local timeout = math.min(120000, remaining())
        if timeout == 0 then error("Parley bootstrap startup deadline exceeded") end
        local result = vim.system(vim.list_extend({ "git" }, args), { text = true })
            :wait(timeout)
        if result.code ~= 0 then
            error("Parley bootstrap git failed: " .. (result.stderr or "timeout"))
        end
    end
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
    require("lazy").setup({
        { "bluz71/vim-moonfly-colors", name = "moonfly", lazy = false, priority = 1000,
            commit = "4ed07bc0c6083cdd547c63f5c245e02c068b0c45",
            config = function() vim.cmd.colorscheme("moonfly") end },
        { "nvim-lua/plenary.nvim", commit = "74b06c6c75e4eeb3108ec01852001636d85a932b" },
        { "nvim-telescope/telescope.nvim", commit = "a0bbec21143c7bc5f8bb02e0005fa0b982edc026" },
        { "iamcco/markdown-preview.nvim",
            commit = "a923f5fc5ba36a3b17e289dc35dc17f66d0548ee",
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
    }, {
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
    require("parley.starter").start()
end, debug.traceback)
timer:stop()
timer:close()
cleanup()
if not ok then error(err) end
