-- Executed by a real, profile-free Neovim; no Plenary or workspace runtime path.
local uv = vim.uv or vim.loop
local function check()
    local root = assert(uv.fs_realpath(vim.env.PARLEY_PROBE_ROOT))
    local function inside(path)
        return path == root or path:sub(1, #root + 1) == root .. '/'
    end
    local function scan(dir)
        local entries = assert(uv.fs_scandir(dir))
        while true do
            local name, kind = uv.fs_scandir_next(entries)
            if not name then break end
            local path = dir .. '/' .. name
            if kind == 'link' then
                -- realpath follows chains and rejects dangling links; accepting
                -- those would leave archive behavior dependent on its neighbors.
                local target = uv.fs_realpath(path)
                assert(target and inside(target), 'escaping symlink: ' .. path)
            elseif kind == 'directory' then
                scan(path)
            end
        end
    end
    scan(root)
    if vim.env.PARLEY_PROBE_MODE == 'guard' then return end
    assert(not uv.fs_stat(root .. '/.git'), 'runtime archive must have no .git')
    assert(uv.cwd() == root, 'runtime cwd must be the archive')
    vim.opt.runtimepath = { root, vim.env.VIMRUNTIME }
    vim.opt.packpath = {}
    vim.opt.swapfile = false
    -- Permit only the exact local tool-version probes used to build tool help;
    -- provider/auth/network process calls must fail rather than escape isolation.
    vim.system = function() error('unexpected subprocess during standalone smoke') end
    vim.fn.jobstart = function() error('unexpected job during standalone smoke') end
    local system = vim.fn.system
    local version_probes = {
        ['uname -s'] = true, ['ls --version 2>&1'] = true,
        ['rg --version'] = true, ['grep --version 2>&1'] = true,
        ['ack --version'] = true, ['find --version 2>&1'] = true,
    }
    vim.fn.system = function(command, ...)
        local key = type(command) == 'table' and table.concat(command, ' ') or command
        assert(version_probes[key], 'unexpected system: ' .. vim.inspect(command))
        return system(command, ...)
    end
    vim.fn.systemlist = function() error('unexpected systemlist during standalone smoke') end
    local parley = require('parley')
    local chat_dir = vim.env.TMPDIR .. '/chats-' .. vim.env.PARLEY_PROBE_VARIANT
    parley.setup({
        chat_dir = chat_dir,
        state_dir = vim.env.TMPDIR .. '/parley-state',
        providers = {},
        api_keys = {},
        cliproxy = { manage = false, auto_download = false },
    })
    parley.cmd.ChatNew({})
    local chats = vim.fn.glob(chat_dir .. '/*.md', false, true)
    assert(#chats == 1, 'new chat must create exactly one file')
    assert(table.concat(vim.fn.readfile(chats[1]), '\n'):find('💬:', 1, true))
    local vocabulary = require('parley.issue_vocabulary')
    local model, why = vocabulary.default()
    if vim.env.PARLEY_PROBE_VARIANT == 'intact' then
        assert(model, why)
    else
        assert(not model and why, 'unavailable data must not borrow workspace vocabulary')
        local issues = require('parley.issues')
        local warnings = {}
        parley.logger.warning = function(message) warnings[#warnings + 1] = message end
        local issue_file = vim.env.TMPDIR .. '/unchanged-issue.md'
        local original = { '---', 'id: 000001', 'status: custom', 'updated: 2000-01-01', '---', '# Unchanged' }
        vim.fn.writefile(original, issue_file)
        vim.cmd('edit ' .. vim.fn.fnameescape(issue_file))
        local before = uv.fs_stat(issue_file)
        issues.cmd_issue_status()
        issues.cmd_issue_new()
        local ok, diagnostic = issues.write_status(0, 'invented')
        assert(ok == false and diagnostic:find('unavailable', 1, true))
        assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(0, 0, -1, false)))
        assert(vim.deep_equal(original, vim.fn.readfile(issue_file)))
        assert(vim.deep_equal(before.mtime, uv.fs_stat(issue_file).mtime))
        assert(#warnings >= 2 and warnings[1]:find('unavailable', 1, true))
    end
    assert(not uv.fs_stat(vim.env.HOME .. '/.cli-proxy-api'), 'auth directory must not be created')
end
local ok, why = xpcall(check, debug.traceback)
if not ok then
    io.stderr:write(tostring(why) .. '\n')
    vim.cmd('cquit 1')
else
    vim.cmd('qa!')
end
