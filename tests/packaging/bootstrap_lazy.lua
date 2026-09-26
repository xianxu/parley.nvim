return {
    setup = function(spec, opts)
        if vim.env.BOOTSTRAP_HOLD then
            vim.fn.writefile({ 'ready' }, vim.env.BOOTSTRAP_HOLD .. '.ready')
            assert(vim.wait(10000, function()
                return vim.fn.filereadable(vim.env.BOOTSTRAP_HOLD .. '.release') == 1
            end, 10))
        end
        assert(vim.o.wrap and vim.o.linebreak and vim.o.breakindent)
        assert(vim.o.termguicolors)
        assert(vim.g.mapleader == ' ')
        assert(opts.checker.enabled == false)
        assert(spec[1].commit == '4ed07bc0c6083cdd547c63f5c245e02c068b0c45')
        local by_name = {}
        for _, plugin in ipairs(spec) do by_name[plugin[1] or plugin.name] = plugin end
        assert(by_name['nvim-lua/plenary.nvim'].commit == '74b06c6c75e4eeb3108ec01852001636d85a932b')
        assert(by_name['nvim-telescope/telescope.nvim'].commit == 'a0bbec21143c7bc5f8bb02e0005fa0b982edc026')
        for _, item in ipairs(require('parley.theme').items()) do
            local plugin = assert(by_name[item.plugin[1]], 'Missing theme dependency: ' .. item.id)
            assert(plugin.commit == item.plugin.commit)
            assert(plugin.lazy == false)
        end
        local preview
        for _, plugin in ipairs(spec) do
            if plugin[1] == 'iamcco/markdown-preview.nvim' then preview = plugin end
        end
        assert(preview, 'MarkdownPreview must ship in the app profile')
        assert(preview.commit == 'a923f5fc5ba36a3b17e289dc35dc17f66d0548ee')
        assert(vim.deep_equal(preview.cmd, {'MarkdownPreview', 'MarkdownPreviewToggle', 'MarkdownPreviewStop'}))
        preview.init()
        assert(vim.g.mkdp_auto_start == 0 and vim.g.mkdp_open_to_the_world == 0)
        assert(type(preview.build) == 'function')
        -- Stateful installer fixture: materialize the server, then verify
        -- failure is surfaced rather than accepting a missing download.
        local dir = vim.fn.stdpath('data') .. '/markdown-preview.nvim'
        vim.fn.mkdir(dir .. '/app/bin', 'p')
        vim.fn.writefile({'{"version":"0.0.10"}'}, dir .. '/package.json')
        local host = (vim.uv or vim.loop).os_uname()
        local platform = host.sysname == 'Darwin'
            and (host.machine == 'arm64' and 'macos-arm64' or 'macos') or 'linux'
        local binary = 'markdown-preview-' .. platform
        vim.fn.writefile({'#!/bin/sh', 'mkdir -p bin',
            "printf '#!/bin/sh\\necho 0.0.10\\n' > bin/" .. binary,
            'chmod +x bin/' .. binary}, dir .. '/app/install.sh')
        -- Build must work before plugin autoload functions are available.
        assert(vim.fn.exists('*mkdp#util#get_platform') == 0)
        local ok, err = pcall(preview.build, {dir = dir})
        assert(ok, err)
        vim.fn.writefile({'exit 7'}, dir .. '/app/install.sh')
        local failed, why = pcall(preview.build, {dir = dir})
        assert(not failed and tostring(why):find('install failed', 1, true))
        vim.fn.writefile({'exit 0'}, dir .. '/app/install.sh')
        vim.fn.writefile({'#!/bin/sh', 'echo 0.0.9'}, dir .. '/app/bin/' .. binary)
        local verified, verify_error = pcall(preview.build, {dir = dir})
        assert(not verified and tostring(verify_error):find('verification failed', 1, true))
        local runtime
        for _, plugin in ipairs(spec) do
            if plugin.dir then runtime = plugin.dir end
        end
        local installed = vim.fn.stdpath('data') .. '/fixture-installed'
        local install_win
        if vim.env.BOOTSTRAP_INSTALL_FLOAT and vim.fn.filereadable(installed) == 0 then
            local buf = vim.api.nvim_create_buf(false, true)
            install_win = vim.api.nvim_open_win(buf, true, {
                relative = 'editor', width = 40, height = 10, row = 2, col = 4,
            })
            -- Lazy closes its view on the scheduler, not synchronously.
            package.loaded['lazy.view'] = {
                visible = function() return vim.api.nvim_win_is_valid(install_win) end,
                view = { close = function()
                    vim.schedule(function() vim.api.nvim_win_close(install_win, true) end)
                end },
            }
            vim.fn.writefile({'installed'}, installed)
        end
        package.preload['parley.starter'] = function()
            return { start = function()
                local relative = vim.api.nvim_win_get_config(0).relative
                vim.wait(20)
                vim.fn.writefile({ vim.json.encode({ runtime = runtime, lockfile = opts.lockfile,
                    relative = relative, windows = #vim.api.nvim_list_wins() }) },
                    vim.env.BOOTSTRAP_RESULT)
            end }
        end
    end,
}
